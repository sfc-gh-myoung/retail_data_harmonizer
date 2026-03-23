-- ============================================================================
-- sql/setup/09_fastpath_cache.sql
-- Retail Data Harmonizer - De-duplication and Fast-Path
--
-- Creates:
--   1. UNIQUE_DESCRIPTIONS table (de-duplicated lookup)
--   2. CONFIRMED_MATCHES table (fast-path cache)
--   3. DEDUPLICATE_RAW_ITEMS() procedure
--   4. RESOLVE_FAST_PATH() procedure
--
-- Depends on: 02_schema_and_tables.sql
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;


-- ============================================================================
-- CONFIRMED_MATCHES: Fast-path cache of human-confirmed mappings
-- Once a reviewer confirms a match, identical descriptions skip AI entirely
-- ============================================================================
CREATE OR REPLACE TABLE HARMONIZER_DEMO.HARMONIZED.CONFIRMED_MATCHES (
    CONFIRMED_MATCH_ID      VARCHAR(36)     NOT NULL,
    NORMALIZED_DESCRIPTION  VARCHAR(500)    NOT NULL,
    SUBCATEGORY             VARCHAR(100),                   -- Phase 2: Subcategory for filtered fast-path
    STANDARD_ITEM_ID        VARCHAR(36)     NOT NULL,
    CONFIDENCE_SCORE        FLOAT,
    CONFIRMED_BY            VARCHAR(100),
    CONFIRMATION_COUNT      INTEGER         DEFAULT 1,
    CREATED_AT              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    LAST_CONFIRMED_AT       TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_CONFIRMED_MATCHES PRIMARY KEY (CONFIRMED_MATCH_ID),
    CONSTRAINT FK_CONFIRMED_STANDARD FOREIGN KEY (STANDARD_ITEM_ID)
        REFERENCES HARMONIZER_DEMO.RAW.STANDARD_ITEMS(STANDARD_ITEM_ID)
) CLUSTER BY (NORMALIZED_DESCRIPTION);

-- ============================================================================
-- Step 0: De-duplicate raw items into unique normalized descriptions
-- Normalization: Uses APPLY_NORMALIZATION_RULES() UDF for enhanced normalization
-- Falls back to UPPER + TRIM + collapse spaces if UDF not available
-- Uses MERGE to handle incremental runs (new items added over time)
-- ============================================================================
-- Drop old signature to avoid overloading error
DROP PROCEDURE IF EXISTS HARMONIZER_DEMO.HARMONIZED.DEDUPLICATE_RAW_ITEMS();

CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.DEDUPLICATE_RAW_ITEMS(
    P_RUN_ID VARCHAR DEFAULT NULL
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Deduplicates raw items into unique normalized descriptions'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_run_id VARCHAR;
    v_started_at TIMESTAMP_NTZ;
    total_raw INTEGER;
    unique_count INTEGER;
    dedup_ratio FLOAT;
    use_enhanced_norm BOOLEAN DEFAULT TRUE;
    v_error_message VARCHAR;
BEGIN
    -- Initialize telemetry
    v_run_id := COALESCE(:P_RUN_ID, UUID_STRING());
    v_started_at := CURRENT_TIMESTAMP();
    
    -- Log start
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'DEDUPLICATE_RAW_ITEMS', 'STARTED',
        0, 0, 0, :v_started_at, NULL, NULL, 'SERIAL', NULL
    );

    -- Count pending raw items
    SELECT COUNT(*) INTO :total_raw
    FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS
    WHERE MATCH_STATUS = 'PENDING';

    -- Check if enhanced normalization UDF exists and has rules
    -- NOTE: Cannot use EXECUTE IMMEDIATE here because it taints the execution context,
    -- preventing the parent procedure (DEDUP_FASTPATH_BATCH) from calling SYSTEM$SET_RETURN_VALUE.
    -- Instead, use a direct SELECT with exception handling for when the table doesn't exist.
    BEGIN
        LET v_rule_count INTEGER;
        SELECT COUNT(*) INTO :v_rule_count
        FROM HARMONIZER_DEMO.HARMONIZED.NORMALIZATION_RULES
        WHERE IS_ACTIVE = TRUE;
        IF (:v_rule_count = 0) THEN
            use_enhanced_norm := FALSE;
        END IF;
    EXCEPTION
        WHEN OTHER THEN
            -- Table doesn't exist or other error - fall back to basic normalization
            use_enhanced_norm := FALSE;
    END;

    -- MERGE normalized descriptions into UNIQUE_DESCRIPTIONS
    -- Uses enhanced normalization UDF when available, fallback otherwise
    IF (:use_enhanced_norm) THEN
        MERGE INTO HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS tgt
        USING (
            SELECT
                HARMONIZER_DEMO.HARMONIZED.APPLY_NORMALIZATION_RULES(RAW_DESCRIPTION) AS NORMALIZED_DESCRIPTION,
                MIN(RAW_DESCRIPTION) AS RAW_DESCRIPTION_SAMPLE,
                COUNT(*) AS ITEM_COUNT,
                MIN(CREATED_AT) AS FIRST_SEEN_AT,
                MAX(CREATED_AT) AS LAST_SEEN_AT
            FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS
            WHERE MATCH_STATUS = 'PENDING'
            GROUP BY HARMONIZER_DEMO.HARMONIZED.APPLY_NORMALIZATION_RULES(RAW_DESCRIPTION)
        ) src
        ON tgt.NORMALIZED_DESCRIPTION = src.NORMALIZED_DESCRIPTION
        WHEN MATCHED THEN UPDATE SET
            tgt.ITEM_COUNT = tgt.ITEM_COUNT + src.ITEM_COUNT,
            tgt.LAST_SEEN_AT = src.LAST_SEEN_AT
        WHEN NOT MATCHED THEN INSERT (
            UNIQUE_DESC_ID, NORMALIZED_DESCRIPTION, RAW_DESCRIPTION_SAMPLE,
            ITEM_COUNT, FIRST_SEEN_AT, LAST_SEEN_AT, MATCH_STATUS
        ) VALUES (
            UUID_STRING(), src.NORMALIZED_DESCRIPTION, src.RAW_DESCRIPTION_SAMPLE,
            src.ITEM_COUNT, src.FIRST_SEEN_AT, src.LAST_SEEN_AT, 'PENDING'
        );
    ELSE
        -- Fallback: basic normalization (UPPER + TRIM + collapse spaces)
        MERGE INTO HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS tgt
        USING (
            SELECT
                UPPER(TRIM(REGEXP_REPLACE(RAW_DESCRIPTION, '\\s+', ' '))) AS NORMALIZED_DESCRIPTION,
                MIN(RAW_DESCRIPTION) AS RAW_DESCRIPTION_SAMPLE,
                COUNT(*) AS ITEM_COUNT,
                MIN(CREATED_AT) AS FIRST_SEEN_AT,
                MAX(CREATED_AT) AS LAST_SEEN_AT
            FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS
            WHERE MATCH_STATUS = 'PENDING'
            GROUP BY UPPER(TRIM(REGEXP_REPLACE(RAW_DESCRIPTION, '\\s+', ' ')))
        ) src
        ON tgt.NORMALIZED_DESCRIPTION = src.NORMALIZED_DESCRIPTION
        WHEN MATCHED THEN UPDATE SET
            tgt.ITEM_COUNT = tgt.ITEM_COUNT + src.ITEM_COUNT,
            tgt.LAST_SEEN_AT = src.LAST_SEEN_AT
        WHEN NOT MATCHED THEN INSERT (
            UNIQUE_DESC_ID, NORMALIZED_DESCRIPTION, RAW_DESCRIPTION_SAMPLE,
            ITEM_COUNT, FIRST_SEEN_AT, LAST_SEEN_AT, MATCH_STATUS
        ) VALUES (
            UUID_STRING(), src.NORMALIZED_DESCRIPTION, src.RAW_DESCRIPTION_SAMPLE,
            src.ITEM_COUNT, src.FIRST_SEEN_AT, src.LAST_SEEN_AT, 'PENDING'
        );
    END IF;

    -- Count unique descriptions (pending only)
    SELECT COUNT(*) INTO :unique_count
    FROM HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS
    WHERE MATCH_STATUS = 'PENDING';

    -- Compute de-duplication ratio
    dedup_ratio := CASE
        WHEN :total_raw > 0 THEN ROUND(:total_raw::FLOAT / NULLIF(:unique_count, 0), 2)
        ELSE 0
    END;

    -- Populate RAW_TO_UNIQUE_MAP junction table for item lineage (T86)
    -- This links each raw item to its normalized unique description
    IF (:use_enhanced_norm) THEN
        INSERT INTO HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP (
            MAP_ID, RAW_ITEM_ID, UNIQUE_DESC_ID, RAW_DESCRIPTION,
            NORMALIZED_DESCRIPTION, NORMALIZATION_METHOD, MAPPED_AT
        )
        SELECT
            UUID_STRING(),
            ri.ITEM_ID,
            ud.UNIQUE_DESC_ID,
            ri.RAW_DESCRIPTION,
            ud.NORMALIZED_DESCRIPTION,
            'ENHANCED',
            CURRENT_TIMESTAMP()
        FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
        JOIN HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS ud
            ON HARMONIZER_DEMO.HARMONIZED.APPLY_NORMALIZATION_RULES(ri.RAW_DESCRIPTION) = ud.NORMALIZED_DESCRIPTION
        WHERE NOT EXISTS (
            SELECT 1 FROM HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rtm
            WHERE rtm.RAW_ITEM_ID = ri.ITEM_ID
        );
    ELSE
        INSERT INTO HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP (
            MAP_ID, RAW_ITEM_ID, UNIQUE_DESC_ID, RAW_DESCRIPTION,
            NORMALIZED_DESCRIPTION, NORMALIZATION_METHOD, MAPPED_AT
        )
        SELECT
            UUID_STRING(),
            ri.ITEM_ID,
            ud.UNIQUE_DESC_ID,
            ri.RAW_DESCRIPTION,
            ud.NORMALIZED_DESCRIPTION,
            'BASIC',
            CURRENT_TIMESTAMP()
        FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
        JOIN HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS ud
            ON UPPER(TRIM(REGEXP_REPLACE(ri.RAW_DESCRIPTION, '\\s+', ' '))) = ud.NORMALIZED_DESCRIPTION
        WHERE NOT EXISTS (
            SELECT 1 FROM HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rtm
            WHERE rtm.RAW_ITEM_ID = ri.ITEM_ID
        );
    END IF;

    LET mappings_created INTEGER := SQLROWCOUNT;

    -- Log completion
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'DEDUPLICATE_RAW_ITEMS', 'COMPLETED',
        :unique_count, 0, 0, :v_started_at, NULL, NULL, 'SERIAL', NULL
    );

    RETURN '{"total_raw": ' || :total_raw || ', "unique_count": ' || :unique_count || ', "dedup_ratio": ' || :dedup_ratio || ', "enhanced_norm": ' || :use_enhanced_norm || ', "mappings_created": ' || :mappings_created || ', "run_id": "' || :v_run_id || '"}';
EXCEPTION
    WHEN OTHER THEN
        v_error_message := SQLERRM;
        -- Log failure
        CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
            :v_run_id, 'DEDUPLICATE_RAW_ITEMS', 'FAILED',
            0, 0, 1, :v_started_at, :v_error_message, NULL, 'SERIAL', NULL
        );
        RAISE;
END;
$$;

-- ============================================================================
-- Step 0.5: Resolve descriptions via confirmed-match fast-path
-- Checks CONFIRMED_MATCHES cache before running any AI matching
-- Zero-cost, instant resolution for previously confirmed descriptions
-- Phase 7: Supports subcategory-filtered matching with graceful fallback
-- ============================================================================
-- Drop old signature to avoid overloading error
DROP PROCEDURE IF EXISTS HARMONIZER_DEMO.HARMONIZED.RESOLVE_FAST_PATH();

CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.RESOLVE_FAST_PATH(
    P_RUN_ID VARCHAR DEFAULT NULL
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Zero-cost fast-path resolution using confirmed matches cache with subcategory support'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_run_id VARCHAR;
    v_started_at TIMESTAMP_NTZ;
    fast_pathed_count INTEGER DEFAULT 0;
    fast_pathed_with_subcat INTEGER DEFAULT 0;
    fast_pathed_fallback INTEGER DEFAULT 0;
    remaining_count INTEGER DEFAULT 0;
    v_error_message VARCHAR;
BEGIN
    -- Initialize telemetry
    v_run_id := COALESCE(:P_RUN_ID, UUID_STRING());
    v_started_at := CURRENT_TIMESTAMP();
    
    -- Log start
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'RESOLVE_FAST_PATH', 'STARTED',
        0, 0, 0, :v_started_at, NULL, NULL, 'SERIAL', NULL
    );

    -- Step 1: Mark unique descriptions that have confirmed matches
    UPDATE HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS ud
    SET ud.MATCH_STATUS = 'CONFIRMED'
    FROM HARMONIZER_DEMO.HARMONIZED.CONFIRMED_MATCHES cm
    WHERE ud.NORMALIZED_DESCRIPTION = cm.NORMALIZED_DESCRIPTION
      AND ud.MATCH_STATUS = 'PENDING';

    -- Step 2a: Create ITEM_MATCHES entries for fast-pathed raw items WITH subcategory match
    -- Prefer matches where subcategory also matches (higher confidence)
    INSERT INTO HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES (
        MATCH_ID, RAW_ITEM_ID, SUGGESTED_STANDARD_ID, CONFIRMED_STANDARD_ID,
        ENSEMBLE_SCORE, MATCH_METHOD, STATUS, IS_CACHED, CREATED_AT
    )
    SELECT
        UUID_STRING(),
        ri.ITEM_ID,
        cm.STANDARD_ITEM_ID,
        cm.STANDARD_ITEM_ID,
        cm.CONFIDENCE_SCORE,
        'FAST_PATH_SUBCATEGORY',
        'AUTO_ACCEPTED',
        TRUE,
        CURRENT_TIMESTAMP()
    FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
    JOIN HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS ud
        ON UPPER(TRIM(REGEXP_REPLACE(ri.RAW_DESCRIPTION, '\\s+', ' '))) = ud.NORMALIZED_DESCRIPTION
    JOIN HARMONIZER_DEMO.HARMONIZED.CONFIRMED_MATCHES cm
        ON ud.NORMALIZED_DESCRIPTION = cm.NORMALIZED_DESCRIPTION
        AND (cm.SUBCATEGORY IS NULL OR cm.SUBCATEGORY = ri.INFERRED_SUBCATEGORY)
    LEFT JOIN HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES existing
        ON ri.ITEM_ID = existing.RAW_ITEM_ID
    WHERE ri.MATCH_STATUS = 'PENDING'
      AND ud.MATCH_STATUS = 'CONFIRMED'
      AND existing.MATCH_ID IS NULL
      AND ri.INFERRED_SUBCATEGORY IS NOT NULL;

    fast_pathed_with_subcat := SQLROWCOUNT;

    -- Step 2b: Create ITEM_MATCHES entries for fast-pathed raw items WITHOUT subcategory info
    -- Fallback for items where subcategory is NULL or no subcategory-specific match exists
    INSERT INTO HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES (
        MATCH_ID, RAW_ITEM_ID, SUGGESTED_STANDARD_ID, CONFIRMED_STANDARD_ID,
        ENSEMBLE_SCORE, MATCH_METHOD, STATUS, IS_CACHED, CREATED_AT
    )
    SELECT
        UUID_STRING(),
        ri.ITEM_ID,
        cm.STANDARD_ITEM_ID,
        cm.STANDARD_ITEM_ID,
        cm.CONFIDENCE_SCORE * 0.95,  -- Slight penalty for no subcategory validation
        'FAST_PATH',
        'AUTO_ACCEPTED',
        TRUE,
        CURRENT_TIMESTAMP()
    FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
    JOIN HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS ud
        ON UPPER(TRIM(REGEXP_REPLACE(ri.RAW_DESCRIPTION, '\\s+', ' '))) = ud.NORMALIZED_DESCRIPTION
    JOIN HARMONIZER_DEMO.HARMONIZED.CONFIRMED_MATCHES cm
        ON ud.NORMALIZED_DESCRIPTION = cm.NORMALIZED_DESCRIPTION
    LEFT JOIN HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES existing
        ON ri.ITEM_ID = existing.RAW_ITEM_ID
    WHERE ri.MATCH_STATUS = 'PENDING'
      AND ud.MATCH_STATUS = 'CONFIRMED'
      AND existing.MATCH_ID IS NULL;

    fast_pathed_fallback := SQLROWCOUNT;
    fast_pathed_count := fast_pathed_with_subcat + fast_pathed_fallback;

    -- Step 3: Update raw items that were fast-pathed
    UPDATE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
    SET ri.MATCH_STATUS = 'AUTO_MATCHED'
    FROM HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS ud
    WHERE UPPER(TRIM(REGEXP_REPLACE(ri.RAW_DESCRIPTION, '\\s+', ' '))) = ud.NORMALIZED_DESCRIPTION
      AND ud.MATCH_STATUS = 'CONFIRMED'
      AND ri.MATCH_STATUS = 'PENDING';

    -- Count remaining pending items
    SELECT COUNT(*) INTO :remaining_count
    FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS
    WHERE MATCH_STATUS = 'PENDING';

    -- Log completion
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'RESOLVE_FAST_PATH', 'COMPLETED',
        :fast_pathed_count, 0, 0, :v_started_at, NULL, NULL, 'SERIAL', NULL
    );

    RETURN '{"fast_pathed": ' || :fast_pathed_count || 
           ', "with_subcategory": ' || :fast_pathed_with_subcat || 
           ', "fallback": ' || :fast_pathed_fallback || 
           ', "remaining": ' || :remaining_count || 
           ', "run_id": "' || :v_run_id || '"}';
EXCEPTION
    WHEN OTHER THEN
        v_error_message := SQLERRM;
        -- Log failure
        CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
            :v_run_id, 'RESOLVE_FAST_PATH', 'FAILED',
            0, 0, 1, :v_started_at, :v_error_message, NULL, 'SERIAL', NULL
        );
        RAISE;
END;
$$;
