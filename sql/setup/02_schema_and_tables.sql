-- ============================================================================
-- Retail Data Harmonization Demo
-- Script: sql/setup/02_schema_and_tables.sql
-- Purpose: All table DDL and default configuration
-- Depends on: 01_roles_and_warehouse.sql
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- RAW Schema Tables
-- ============================================================================

-- Master item list with standardized descriptions and SRP
CREATE OR REPLACE TABLE HARMONIZER_DEMO.RAW.STANDARD_ITEMS (
    STANDARD_ITEM_ID     VARCHAR(36)     NOT NULL,
    STANDARD_DESCRIPTION VARCHAR(500)    NOT NULL,
    CATEGORY             VARCHAR(100)    NOT NULL,
    SUBCATEGORY          VARCHAR(100),
    BRAND                VARCHAR(100),
    UPC                  VARCHAR(20),
    SRP                  FLOAT           NOT NULL,
    IS_ACTIVE            BOOLEAN         DEFAULT TRUE,
    CREATED_AT           TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_STANDARD_ITEMS PRIMARY KEY (STANDARD_ITEM_ID)
) CHANGE_TRACKING = TRUE;

-- ============================================================================
-- Events Reference Table
-- Represents venue events where POS transactions occur (stadium games, concerts)
-- Must be created BEFORE RAW_RETAIL_ITEMS for FK constraint
-- ============================================================================
CREATE OR REPLACE TABLE HARMONIZER_DEMO.RAW.EVENTS (
    EVENT_ID             VARCHAR(36)     NOT NULL,
    EVENT_NAME           VARCHAR(200)    NOT NULL,
    VENUE_CODE           VARCHAR(50)     NOT NULL,
    EVENT_TYPE           VARCHAR(50)     NOT NULL,
    EVENT_DATE           DATE            NOT NULL,
    EXPECTED_ATTENDANCE  INTEGER,
    ACTUAL_ATTENDANCE    INTEGER,
    CREATED_AT           TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_EVENTS PRIMARY KEY (EVENT_ID)
) COMMENT = 'Reference table for venue events that generate POS transaction data';

-- Unmapped retail items needing harmonization
CREATE OR REPLACE TABLE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS (
    ITEM_ID              VARCHAR(36)     NOT NULL,
    RAW_DESCRIPTION      VARCHAR(500)    NOT NULL,
    NORMALIZED_DESCRIPTION VARCHAR(500)  COMMENT 'Pre-computed UPPER(TRIM(REGEXP_REPLACE(RAW_DESCRIPTION))) for fast duplicate lookups',
    SOURCE_SYSTEM        VARCHAR(50)     NOT NULL,
    SOURCE_ITEM_CODE     VARCHAR(50),
    INFERRED_CATEGORY    VARCHAR(100),
    INFERRED_SUBCATEGORY VARCHAR(100),
    MATCHED_STANDARD_ID  VARCHAR(36),
    MATCH_STATUS         VARCHAR(20)     DEFAULT 'PENDING',
    EVENT_ID             VARCHAR(36)     COMMENT 'Reference to the event where this POS item was recorded',
    TRANSACTION_COUNT    INTEGER         DEFAULT 1 COMMENT 'Number of times this exact description appeared in the source batch',
    TRANSACTION_DATE     DATE            COMMENT 'Date when the transaction(s) occurred',
    REGISTER_ID          VARCHAR(20)     COMMENT 'POS register/terminal identifier',
    CREATED_AT           TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT           TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_RAW_RETAIL_ITEMS PRIMARY KEY (ITEM_ID),
    CONSTRAINT FK_RAW_ITEMS_EVENT FOREIGN KEY (EVENT_ID)
        REFERENCES HARMONIZER_DEMO.RAW.EVENTS(EVENT_ID)
) CLUSTER BY (MATCH_STATUS, NORMALIZED_DESCRIPTION)
COMMENT = 'Raw POS retail items from multiple source systems awaiting harmonization';

-- ============================================================================
-- Stream for Exactly-Once Processing
-- NOTE: The stream is created in 07_raw_items_stream.sql AFTER seed data is loaded.
-- This is critical because SHOW_INITIAL_ROWS=TRUE only captures rows existing at
-- stream creation time. Creating the stream here (before seed data) results in
-- an empty stream. Stream creation is in sql/setup/07_raw_items_stream.sql.
-- ============================================================================

-- ============================================================================
-- Stream staging table for safe batch processing
-- CRITICAL: Prevents data loss when stream has more rows than batch size
-- Items are staged here first, then processed in batches, then cleaned up
-- ============================================================================
CREATE OR REPLACE TABLE HARMONIZER_DEMO.HARMONIZED.STREAM_STAGING (
    ITEM_ID             VARCHAR(36)     NOT NULL,
    RAW_DESCRIPTION     VARCHAR(500)    NOT NULL,
    SOURCE_SYSTEM       VARCHAR(50),
    INFERRED_CATEGORY   VARCHAR(50),
    STAGED_AT           TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_STREAM_STAGING PRIMARY KEY (ITEM_ID),
    CONSTRAINT FK_STREAM_STAGING FOREIGN KEY (ITEM_ID)
        REFERENCES HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS(ITEM_ID)
);

-- Pre-computed embedding vectors for standard items
CREATE OR REPLACE TABLE HARMONIZER_DEMO.RAW.STANDARD_ITEMS_EMBEDDINGS (
    STANDARD_ITEM_ID     VARCHAR(36)     NOT NULL,
    EMBEDDING            VECTOR(FLOAT, 1024),
    MODEL_NAME           VARCHAR(100)    DEFAULT 'snowflake-arctic-embed-l-v2.0',
    COMPUTED_AT          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_STANDARD_ITEMS_EMB PRIMARY KEY (STANDARD_ITEM_ID),
    CONSTRAINT FK_STANDARD_ITEMS_EMB FOREIGN KEY (STANDARD_ITEM_ID)
        REFERENCES HARMONIZER_DEMO.RAW.STANDARD_ITEMS(STANDARD_ITEM_ID)
);

-- Pre-computed embeddings for raw retail items (persistent cache)
CREATE OR REPLACE TABLE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS_EMBEDDINGS (
    ITEM_ID             VARCHAR(36)     NOT NULL,
    RAW_DESCRIPTION     VARCHAR(500)    NOT NULL,
    EMBEDDING           VECTOR(FLOAT, 1024) NOT NULL,
    EMBEDDING_MODEL     VARCHAR(100)    DEFAULT 'snowflake-arctic-embed-l-v2.0',
    CREATED_AT          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_RAW_ITEMS_EMB PRIMARY KEY (ITEM_ID),
    CONSTRAINT FK_RAW_ITEMS_EMB FOREIGN KEY (ITEM_ID)
        REFERENCES HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS(ITEM_ID)
);

-- ============================================================================
-- UNIQUE_DESCRIPTIONS: Collapse raw items to unique normalized descriptions
-- At scale: 48M raw items → ~500K unique descriptions (96x cost reduction)
-- Must be created BEFORE UNIQUE_DESC_EMBEDDINGS for FK constraint
-- ============================================================================
CREATE OR REPLACE TABLE HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS (
    UNIQUE_DESC_ID          VARCHAR(36)     NOT NULL,
    NORMALIZED_DESCRIPTION  VARCHAR(500)    NOT NULL,
    RAW_DESCRIPTION_SAMPLE  VARCHAR(500),
    ITEM_COUNT              INTEGER         DEFAULT 0,
    FIRST_SEEN_AT           TIMESTAMP_NTZ,
    LAST_SEEN_AT            TIMESTAMP_NTZ,
    MATCH_STATUS            VARCHAR(20)     DEFAULT 'PENDING',
    CONSTRAINT PK_UNIQUE_DESCRIPTIONS PRIMARY KEY (UNIQUE_DESC_ID)
);

-- ============================================================================
-- RAW_TO_UNIQUE_MAP: Junction table for item lineage
-- Links every raw item to its normalized unique description
-- Enables auditing: "Which raw items mapped to this unique description?"
-- Must be created BEFORE UNIQUE_DESC_EMBEDDINGS procedures reference it
-- ============================================================================
CREATE OR REPLACE TABLE HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP (
    MAP_ID                  VARCHAR(36)     NOT NULL,
    RAW_ITEM_ID             VARCHAR(36)     NOT NULL,
    UNIQUE_DESC_ID          VARCHAR(36)     NOT NULL,
    RAW_DESCRIPTION         VARCHAR(500),
    NORMALIZED_DESCRIPTION  VARCHAR(500),
    NORMALIZATION_METHOD    VARCHAR(30)     DEFAULT 'ENHANCED',
    MAPPED_AT               TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_RAW_TO_UNIQUE_MAP PRIMARY KEY (MAP_ID),
    CONSTRAINT FK_RAW_UNIQUE_RAW FOREIGN KEY (RAW_ITEM_ID)
        REFERENCES HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS(ITEM_ID),
    CONSTRAINT FK_RAW_UNIQUE_UNIQUE FOREIGN KEY (UNIQUE_DESC_ID)
        REFERENCES HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS(UNIQUE_DESC_ID)
);

-- Pre-computed embeddings for unique normalized descriptions (96x cost reduction)
-- One vector per unique description instead of one per raw item.
CREATE OR REPLACE TABLE HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESC_EMBEDDINGS (
    UNIQUE_DESC_ID      VARCHAR(36)     NOT NULL,
    NORMALIZED_DESCRIPTION VARCHAR(500) NOT NULL,
    EMBEDDING           VECTOR(FLOAT, 1024) NOT NULL,
    EMBEDDING_MODEL     VARCHAR(100)    DEFAULT 'snowflake-arctic-embed-l-v2.0',
    CREATED_AT          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_UNIQUE_DESC_EMB PRIMARY KEY (UNIQUE_DESC_ID),
    CONSTRAINT FK_UNIQUE_DESC_EMB FOREIGN KEY (UNIQUE_DESC_ID)
        REFERENCES HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS(UNIQUE_DESC_ID)
);

-- ============================================================================
-- HARMONIZED Schema Tables
-- ============================================================================

-- Match results linking raw items to standard items
CREATE OR REPLACE TABLE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES (
    MATCH_ID                VARCHAR(36)     NOT NULL,
    RAW_ITEM_ID             VARCHAR(36)     NOT NULL,
    SUGGESTED_STANDARD_ID   VARCHAR(36),
    CONFIRMED_STANDARD_ID   VARCHAR(36),
    CORTEX_SEARCH_SCORE     FLOAT,
    COSINE_SCORE            FLOAT,
    EDIT_DISTANCE_SCORE     FLOAT,                      -- Phase 1: Edit distance signal
    JACCARD_SCORE           FLOAT,                      -- Phase 2: Jaccard token similarity
    ENSEMBLE_SCORE          FLOAT,
    MATCH_METHOD            VARCHAR(100),
    STATUS                  VARCHAR(20)     DEFAULT 'PENDING_REVIEW',
    SEARCH_MATCHED_ID       VARCHAR(36),
    COSINE_MATCHED_ID       VARCHAR(36),
    EDIT_DISTANCE_MATCHED_ID VARCHAR(36),               -- Phase 1: Edit distance match tracking
    JACCARD_MATCHED_ID      VARCHAR(36),                -- Phase 2: Jaccard match tracking
    JACCARD_REASONING       VARCHAR(500),               -- Phase 2: Jaccard match reasoning
    SUBCATEGORY_MATCH       BOOLEAN,                    -- Phase 2: True if subcategories match
    SIGNAL_AGREEMENT_COUNT  INTEGER,                    -- Phase 2: Count of agreeing signals (0-4)
    REVIEWED_BY             VARCHAR(100),
    REVIEWED_AT             TIMESTAMP_NTZ,
    LOCKED_BY               VARCHAR(100),
    LOCKED_AT               TIMESTAMP_NTZ,
    LOCK_EXPIRES_AT         TIMESTAMP_NTZ,
    IS_CACHED               BOOLEAN         DEFAULT FALSE,
    CREATED_AT              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_ITEM_MATCHES PRIMARY KEY (MATCH_ID),
    CONSTRAINT FK_MATCHES_RAW FOREIGN KEY (RAW_ITEM_ID)
        REFERENCES HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS(ITEM_ID),
    CONSTRAINT FK_MATCHES_SUGGESTED FOREIGN KEY (SUGGESTED_STANDARD_ID)
        REFERENCES HARMONIZER_DEMO.RAW.STANDARD_ITEMS(STANDARD_ITEM_ID),
    CONSTRAINT FK_MATCHES_CONFIRMED FOREIGN KEY (CONFIRMED_STANDARD_ID)
        REFERENCES HARMONIZER_DEMO.RAW.STANDARD_ITEMS(STANDARD_ITEM_ID)
) CLUSTER BY (RAW_ITEM_ID, STATUS);

-- Top-N candidate matches per method
CREATE OR REPLACE TABLE HARMONIZER_DEMO.HARMONIZED.MATCH_CANDIDATES (
    CANDIDATE_ID         VARCHAR(36)     NOT NULL,
    RAW_ITEM_ID          VARCHAR(36)     NOT NULL,
    STANDARD_ITEM_ID     VARCHAR(36)     NOT NULL,
    STANDARD_DESCRIPTION VARCHAR(500),
    RANK                 INTEGER         NOT NULL,
    CONFIDENCE_SCORE     FLOAT           NOT NULL,
    MATCH_METHOD         VARCHAR(100)    NOT NULL,
    CONSTRAINT PK_MATCH_CANDIDATES PRIMARY KEY (CANDIDATE_ID),
    CONSTRAINT FK_CANDIDATES_RAW FOREIGN KEY (RAW_ITEM_ID)
        REFERENCES HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS(ITEM_ID),
    CONSTRAINT FK_CANDIDATES_STANDARD FOREIGN KEY (STANDARD_ITEM_ID)
        REFERENCES HARMONIZER_DEMO.RAW.STANDARD_ITEMS(STANDARD_ITEM_ID)
);

-- ============================================================================
-- HARMONIZED_ITEMS: Final output table for high-confidence matches
-- Items routed here have passed the confidence threshold and are ready for use
-- ============================================================================
CREATE OR REPLACE TABLE HARMONIZER_DEMO.HARMONIZED.HARMONIZED_ITEMS (
    HARMONIZED_ITEM_ID      VARCHAR(36)     DEFAULT UUID_STRING() NOT NULL,
    RAW_ITEM_ID             VARCHAR(36)     NOT NULL,
    MASTER_ITEM_ID          VARCHAR(36)     NOT NULL,
    ENSEMBLE_CONFIDENCE_SCORE NUMBER(5,4),
    MATCH_METHOD            VARCHAR(50),
    MATCH_SOURCE            VARCHAR(100),
    CREATED_AT              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CREATED_BY              VARCHAR(100),
    CONSTRAINT PK_HARMONIZED_ITEMS PRIMARY KEY (HARMONIZED_ITEM_ID),
    CONSTRAINT UK_HARMONIZED_RAW_ITEM UNIQUE (RAW_ITEM_ID),
    CONSTRAINT FK_HARMONIZED_RAW FOREIGN KEY (RAW_ITEM_ID)
        REFERENCES HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS(ITEM_ID),
    CONSTRAINT FK_HARMONIZED_MASTER FOREIGN KEY (MASTER_ITEM_ID)
        REFERENCES HARMONIZER_DEMO.RAW.STANDARD_ITEMS(STANDARD_ITEM_ID)
) COMMENT = 'Final harmonized items that passed confidence threshold - ready for downstream use';

-- ============================================================================
-- REVIEW_QUEUE: Items requiring human review before acceptance
-- Low-confidence matches are routed here for manual verification
-- ============================================================================
CREATE OR REPLACE TABLE HARMONIZER_DEMO.HARMONIZED.REVIEW_QUEUE (
    REVIEW_ID               VARCHAR(36)     DEFAULT UUID_STRING() NOT NULL,
    RAW_ITEM_ID             VARCHAR(36)     NOT NULL,
    SUGGESTED_MASTER_ID     VARCHAR(36),
    CONFIDENCE_SCORE        NUMBER(5,4),
    REVIEW_REASON           VARCHAR(100),
    QUEUE_STATUS            VARCHAR(20)     DEFAULT 'PENDING',
    REVIEWED_BY             VARCHAR(100),
    REVIEWED_AT             TIMESTAMP_NTZ,
    REVIEW_NOTES            TEXT,
    CREATED_AT              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_REVIEW_QUEUE PRIMARY KEY (REVIEW_ID),
    CONSTRAINT UK_REVIEW_RAW_ITEM UNIQUE (RAW_ITEM_ID),
    CONSTRAINT FK_REVIEW_RAW FOREIGN KEY (RAW_ITEM_ID)
        REFERENCES HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS(ITEM_ID),
    CONSTRAINT FK_REVIEW_SUGGESTED FOREIGN KEY (SUGGESTED_MASTER_ID)
        REFERENCES HARMONIZER_DEMO.RAW.STANDARD_ITEMS(STANDARD_ITEM_ID)
) COMMENT = 'Low-confidence items awaiting human review and verification';

-- ============================================================================
-- REJECTED_ITEMS: Items with no viable matches (auto-rejected)
-- When all 4 matchers return NULL/'None', there is no valid match candidate
-- These items are routed here for manual data entry or source correction
-- ============================================================================
CREATE OR REPLACE TABLE HARMONIZER_DEMO.HARMONIZED.REJECTED_ITEMS (
    REJECTION_ID            VARCHAR(36)     DEFAULT UUID_STRING() NOT NULL,
    RAW_ITEM_ID             VARCHAR(36)     NOT NULL,
    REJECTION_REASON        VARCHAR(100)    NOT NULL,
    REJECTION_DETAILS       VARCHAR(500),
    SEARCH_MATCHED_ID       VARCHAR(36)     COMMENT 'NULL or None - no search match found',
    COSINE_MATCHED_ID       VARCHAR(36)     COMMENT 'NULL or None - no cosine match found',
    EDIT_DISTANCE_MATCHED_ID VARCHAR(36)    COMMENT 'NULL or None - no edit distance match found',
    JACCARD_MATCHED_ID      VARCHAR(36)     COMMENT 'NULL or None - no Jaccard match found',
    CREATED_AT              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    REVIEWED_BY             VARCHAR(100)    COMMENT 'User who reviewed/resolved this rejection',
    REVIEWED_AT             TIMESTAMP_NTZ   COMMENT 'When the rejection was reviewed/resolved',
    RESOLUTION_STATUS       VARCHAR(20)     DEFAULT 'PENDING' COMMENT 'PENDING, RESOLVED, MANUAL_ENTRY',
    RESOLUTION_NOTES        TEXT            COMMENT 'Notes from manual resolution',
    CONSTRAINT PK_REJECTED_ITEMS PRIMARY KEY (REJECTION_ID),
    CONSTRAINT UK_REJECTED_RAW_ITEM UNIQUE (RAW_ITEM_ID),
    CONSTRAINT FK_REJECTED_RAW FOREIGN KEY (RAW_ITEM_ID)
        REFERENCES HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS(ITEM_ID)
) COMMENT = 'Items with no viable matches from any matcher - require manual data entry or source correction';

-- ============================================================================
-- Phase 4: Staging Tables for Parallel Vector Matching
-- Each method writes to its own TRANSIENT table to avoid locking
-- Finalizer task joins all staging tables for ensemble scoring
-- ============================================================================

-- Cortex Search staging - semantic/contextual matches
CREATE OR REPLACE TRANSIENT TABLE HARMONIZER_DEMO.HARMONIZED.CORTEX_SEARCH_STAGING (
    RAW_ITEM_ID         VARCHAR(36)     NOT NULL,
    BATCH_ID            VARCHAR(36)     NOT NULL,
    SEARCH_MATCHED_ID   VARCHAR(36),
    SEARCH_SCORE        FLOAT,
    SEARCH_REASONING    VARCHAR(500),
    PROCESSED_AT        TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_CORTEX_SEARCH_STAGING PRIMARY KEY (RAW_ITEM_ID, BATCH_ID)
);

-- Cosine similarity staging - embedding vector matches
CREATE OR REPLACE TRANSIENT TABLE HARMONIZER_DEMO.HARMONIZED.COSINE_MATCH_STAGING (
    RAW_ITEM_ID         VARCHAR(36)     NOT NULL,
    BATCH_ID            VARCHAR(36)     NOT NULL,
    COSINE_MATCHED_ID   VARCHAR(36),
    COSINE_SCORE        FLOAT,
    COSINE_REASONING    VARCHAR(500),
    PROCESSED_AT        TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_COSINE_MATCH_STAGING PRIMARY KEY (RAW_ITEM_ID, BATCH_ID)
);

-- Edit distance staging - Levenshtein/fuzzy string matches
CREATE OR REPLACE TRANSIENT TABLE HARMONIZER_DEMO.HARMONIZED.EDIT_MATCH_STAGING (
    RAW_ITEM_ID         VARCHAR(36)     NOT NULL,
    BATCH_ID            VARCHAR(36)     NOT NULL,
    EDIT_MATCHED_ID     VARCHAR(36),
    EDIT_SCORE          FLOAT,
    EDIT_REASONING      VARCHAR(500),
    PROCESSED_AT        TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_EDIT_MATCH_STAGING PRIMARY KEY (RAW_ITEM_ID, BATCH_ID)
);

-- Jaccard token similarity staging - word overlap matches
CREATE OR REPLACE TRANSIENT TABLE HARMONIZER_DEMO.HARMONIZED.JACCARD_MATCH_STAGING (
    RAW_ITEM_ID         VARCHAR(36)     NOT NULL,
    BATCH_ID            VARCHAR(36)     NOT NULL,
    JACCARD_MATCHED_ID  VARCHAR(36),
    JACCARD_SCORE       FLOAT,
    JACCARD_REASONING   VARCHAR(500),
    PROCESSED_AT        TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_JACCARD_MATCH_STAGING PRIMARY KEY (RAW_ITEM_ID, BATCH_ID)
);

-- ============================================================================
-- Pipeline Batch State - Persistent replacement for session-scoped CURRENT_BATCH
-- This table survives across task sessions, enabling Task DAG coordination
-- ============================================================================
CREATE OR REPLACE TABLE HARMONIZER_DEMO.HARMONIZED.PIPELINE_BATCH_STATE (
    BATCH_ID            VARCHAR(36)     NOT NULL,
    ITEM_COUNT          INTEGER         DEFAULT 0,
    STATUS              VARCHAR(20)     DEFAULT 'ACTIVE',
    CREATED_AT          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    COMPLETED_AT        TIMESTAMP_NTZ,
    CONSTRAINT PK_PIPELINE_BATCH_STATE PRIMARY KEY (BATCH_ID)
);

-- ============================================================================
-- ANALYTICS Schema Tables
-- ============================================================================

-- Audit trail for match reviews
CREATE OR REPLACE TABLE HARMONIZER_DEMO.ANALYTICS.MATCH_AUDIT_LOG (
    AUDIT_ID                VARCHAR(36)     NOT NULL,
    MATCH_ID                VARCHAR(36)     NOT NULL,
    RAW_ITEM_ID             VARCHAR(36),
    RAW_DESCRIPTION         VARCHAR(500),
    SUGGESTED_DESCRIPTION   VARCHAR(500),
    SELECTED_DESCRIPTION    VARCHAR(500),
    ENSEMBLE_SCORE          FLOAT,
    USER_FEEDBACK           VARCHAR(20),
    FEEDBACK_COMMENT        VARCHAR(500),
    ACTION                  VARCHAR(20)     NOT NULL,
    OLD_STATUS              VARCHAR(20),
    NEW_STATUS              VARCHAR(20),
    NOTES                   VARCHAR(1000),
    REVIEWED_BY             VARCHAR(100),
    CREATED_AT              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_MATCH_AUDIT_LOG PRIMARY KEY (AUDIT_ID)
);

-- Pipeline error tracking for observability
CREATE OR REPLACE TABLE HARMONIZER_DEMO.ANALYTICS.PIPELINE_ERRORS (
    ERROR_ID                VARCHAR(36)     NOT NULL,
    PROCEDURE_NAME          VARCHAR(200)    NOT NULL,
    BATCH_ID                VARCHAR(36),
    ERROR_MESSAGE           VARCHAR(5000),
    ERROR_CODE              VARCHAR(50),
    ERROR_CONTEXT           VARIANT,
    CREATED_AT              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_PIPELINE_ERRORS PRIMARY KEY (ERROR_ID)
);

-- Pipeline execution progress tracking
CREATE OR REPLACE TABLE HARMONIZER_DEMO.ANALYTICS.PIPELINE_RUN_PROGRESS (
    RUN_ID                  VARCHAR(36)     NOT NULL,
    PROCEDURE_NAME          VARCHAR(200)    NOT NULL,
    BATCH_NUMBER            INTEGER,
    ITEMS_PROCESSED         INTEGER         DEFAULT 0,
    ITEMS_MATCHED           INTEGER         DEFAULT 0,
    ITEMS_FAILED            INTEGER         DEFAULT 0,
    START_TIME              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    END_TIME                TIMESTAMP_NTZ,
    STATUS                  VARCHAR(20)     DEFAULT 'RUNNING',
    RESULT_MESSAGE          VARCHAR(1000),
    CONSTRAINT PK_PIPELINE_RUN_PROGRESS PRIMARY KEY (RUN_ID, PROCEDURE_NAME)
);

-- ============================================================================
-- CONFIG: Unified application configuration table
-- ============================================================================
-- All application settings in one place. Categories help organize settings.
-- Use GET_CONFIG() function to retrieve values in procedures.
-- ============================================================================
CREATE OR REPLACE TABLE HARMONIZER_DEMO.ANALYTICS.CONFIG (
    CONFIG_KEY           VARCHAR(100)    NOT NULL,
    CONFIG_VALUE         VARCHAR(1000)   NOT NULL,
    DATA_TYPE            VARCHAR(20)     DEFAULT 'STRING',  -- STRING, NUMBER, BOOLEAN
    CATEGORY             VARCHAR(50)     DEFAULT 'GENERAL', -- MODEL, THRESHOLD, BATCH, SCORING, etc.
    DESCRIPTION          VARCHAR(500),
    IS_ACTIVE            BOOLEAN         DEFAULT TRUE,
    CREATED_AT           TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT           TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_CONFIG PRIMARY KEY (CONFIG_KEY)
) COMMENT = 'Unified application configuration. All settings in one table with categories.';

-- ============================================================================
-- Default Configuration (using MERGE for idempotent seeding)
-- ============================================================================
MERGE INTO HARMONIZER_DEMO.ANALYTICS.CONFIG AS target
USING (
    SELECT * FROM VALUES
        -- Threshold Configuration
        ('AUTO_ACCEPT_THRESHOLD', '0.80', 'NUMBER', 'THRESHOLD',
         'Hybrid score threshold for automatic acceptance'),
        ('REVIEW_THRESHOLD', '0.70', 'NUMBER', 'THRESHOLD',
         'Hybrid score threshold for human review queue'),
        ('MIN_CANDIDATE_SCORE', '0.50', 'NUMBER', 'THRESHOLD',
         'Minimum score to include a candidate in results'),
        ('CONFIDENCE_BOOST_THRESHOLD', '3', 'NUMBER', 'THRESHOLD',
         'Number of methods that must agree for confidence boost'),
        
        -- Scoring Weights (normalized at runtime to sum to 1.0)
        -- Weights based on raw score analysis: SEARCH dominates 88.5% of matches with highest avg score (0.73)
        ('ENSEMBLE_WEIGHT_SEARCH', '0.55', 'NUMBER', 'SCORING',
         'Weight for Cortex Search score (normalized at runtime)'),
        ('ENSEMBLE_WEIGHT_COSINE', '0.25', 'NUMBER', 'SCORING',
         'Weight for cosine similarity score (normalized at runtime)'),
        ('ENSEMBLE_WEIGHT_EDIT', '0.12', 'NUMBER', 'SCORING',
         'Weight for edit distance score (normalized at runtime)'),
        ('ENSEMBLE_WEIGHT_JACCARD', '0.18', 'NUMBER', 'SCORING',
         'Weight for Jaccard token similarity score (normalized at runtime)'),
        ('SUBCATEGORY_MISMATCH_PENALTY', '0.00', 'NUMBER', 'SCORING',
         'Score penalty when subcategories do not match (disabled: inference uses different naming than standard items)'),
        ('SUBCATEGORY_UNKNOWN_PENALTY', '0.00', 'NUMBER', 'SCORING',
         'Score penalty when subcategory is unknown/NULL (disabled: many valid items lack subcategory)'),
        
        -- Model Configuration
        ('EMBEDDING_MODEL', 'snowflake-arctic-embed-l-v2.0', 'STRING', 'MODEL',
         'Embedding model for cosine similarity'),
        ('CLASSIFICATION_MODEL', 'mistral-large2', 'STRING', 'MODEL',
         'Model for AI_CLASSIFY category classification'),
        
        -- Batch Configuration
        ('DEFAULT_BATCH_SIZE', '200', 'NUMBER', 'BATCH',
         'Default batch size for matching procedures'),
        ('BATCH_SIZE_CLASSIFY', '200', 'NUMBER', 'BATCH',
         'Batch size for classification procedure'),
        ('BATCH_SIZE_CORTEX_SEARCH', '500', 'NUMBER', 'BATCH',
         'Batch size for Cortex Search matching'),
        ('BATCH_SIZE_COSINE', '500', 'NUMBER', 'BATCH',
         'Batch size for cosine similarity matching'),
        ('BATCH_SIZE_EDIT_DISTANCE', '500', 'NUMBER', 'BATCH',
         'Batch size for edit distance matching'),
        ('BATCH_SIZE_JACCARD', '500', 'NUMBER', 'BATCH',
         'Batch size for Jaccard token similarity matching'),
        ('CLASSIFICATION_BATCH_SIZE', '500', 'NUMBER', 'BATCH',
         'Batch size for AI classification'),
        
        -- Parallelism Configuration
        ('CORTEX_PARALLEL_THREADS', '4', 'NUMBER', 'PARALLELISM',
         'Max concurrent Cortex Search API threads (1-6, default 4)'),
        ('PIPELINE_PARALLELISM_MODE', 'PARALLEL', 'STRING', 'PARALLELISM',
         'Pipeline execution mode: SERIAL or PARALLEL'),
        
        -- Agreement Multipliers
        ('AGREEMENT_MULTIPLIER_4WAY', '1.20', 'NUMBER', 'AGREEMENT',
         'Score boost when all 4 vector signals agree on same match'),
        ('AGREEMENT_MULTIPLIER_3WAY', '1.15', 'NUMBER', 'AGREEMENT',
         'Score boost when 3 signals agree'),
        ('AGREEMENT_MULTIPLIER_2WAY', '1.10', 'NUMBER', 'AGREEMENT',
         'Score boost when 2 signals agree'),
        
        -- Retry Configuration
        ('MAX_RETRY_COUNT', '3', 'NUMBER', 'RETRY',
         'Maximum retry attempts for transient failures'),
        ('RETRY_BASE_DELAY_MS', '1000', 'NUMBER', 'RETRY',
         'Base delay in milliseconds for exponential backoff'),
        ('RETRY_MAX_DELAY_MS', '30000', 'NUMBER', 'RETRY',
         'Maximum delay in milliseconds for exponential backoff'),
        
        -- Schedule Configuration
        ('TASK_TIMEZONE', 'America/New_York', 'STRING', 'SCHEDULE',
         'Timezone for scheduled tasks'),
        ('DAILY_TASK_HOUR', '2', 'NUMBER', 'SCHEDULE',
         'Hour (0-23) for daily matching task'),
        ('WEEKLY_DRIFT_DAY', '0', 'NUMBER', 'SCHEDULE',
         'Day of week (0=Sunday) for weekly drift check'),
        
        -- Drift Detection
        ('DRIFT_WARNING_THRESHOLD', '0.10', 'NUMBER', 'DRIFT',
         'Percentage change threshold for drift warning'),
        ('DRIFT_CRITICAL_THRESHOLD', '0.25', 'NUMBER', 'DRIFT',
         'Percentage change threshold for critical drift alert'),
        ('MODEL_DRIFT_WARNING_THRESHOLD', '0.05', 'NUMBER', 'DRIFT',
         'Accuracy drop threshold for model warning'),
        ('MODEL_DRIFT_CRITICAL_THRESHOLD', '0.10', 'NUMBER', 'DRIFT',
         'Accuracy drop threshold for critical model alert'),
        
        -- Dashboard Configuration
        ('DASHBOARD_AUTO_REFRESH', 'off', 'STRING', 'DASHBOARD',
         'Dashboard auto-refresh: on or off'),
        ('DASHBOARD_REFRESH_INTERVAL', '300', 'NUMBER', 'DASHBOARD',
         'Dashboard auto-refresh interval in seconds'),
        
        -- General Configuration
        ('LOCK_TIMEOUT_MINUTES', '15', 'NUMBER', 'GENERAL',
         'Minutes before a review lock expires'),
        ('MAX_CANDIDATES', '10', 'NUMBER', 'GENERAL',
         'Maximum number of candidates per match method')
         
    AS t(CONFIG_KEY, CONFIG_VALUE, DATA_TYPE, CATEGORY, DESCRIPTION)
) AS source
ON target.CONFIG_KEY = source.CONFIG_KEY
WHEN NOT MATCHED THEN
    INSERT (CONFIG_KEY, CONFIG_VALUE, DATA_TYPE, CATEGORY, DESCRIPTION)
    VALUES (source.CONFIG_KEY, source.CONFIG_VALUE, source.DATA_TYPE, source.CATEGORY, source.DESCRIPTION)
WHEN MATCHED THEN
    UPDATE SET 
        DATA_TYPE = source.DATA_TYPE,
        CATEGORY = source.CATEGORY,
        DESCRIPTION = source.DESCRIPTION,
        UPDATED_AT = CURRENT_TIMESTAMP();

-- ============================================================================
-- GET_CONFIG: Helper function to retrieve configuration values
-- ============================================================================
-- Usage examples:
--   SELECT HARMONIZER_DEMO.ANALYTICS.GET_CONFIG('EMBEDDING_MODEL');
--   SELECT HARMONIZER_DEMO.ANALYTICS.GET_CONFIG('AUTO_ACCEPT_THRESHOLD')::FLOAT;
-- ============================================================================
CREATE OR REPLACE FUNCTION HARMONIZER_DEMO.ANALYTICS.GET_CONFIG(P_KEY VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Retrieve a configuration value by key from CONFIG'
AS
$$
    SELECT CONFIG_VALUE 
    FROM HARMONIZER_DEMO.ANALYTICS.CONFIG 
    WHERE CONFIG_KEY = P_KEY 
      AND IS_ACTIVE = TRUE
$$;
