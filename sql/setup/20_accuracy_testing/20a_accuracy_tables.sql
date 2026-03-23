-- ============================================================================
-- Retail Data Harmonization Demo
-- Script: sql/setup/20_accuracy_testing/20a_accuracy_tables.sql
-- Purpose: Test tables and job tracking for accuracy testing framework
-- Depends on: 02_schema_and_tables.sql
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- Accuracy Test Tables
-- ============================================================================

-- Ground truth test set with known correct matches
CREATE OR REPLACE TABLE HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_SET (
    TEST_ID             INT AUTOINCREMENT,
    RAW_DESCRIPTION     VARCHAR(500) NOT NULL,
    EXPECTED_MATCH      VARCHAR(500) NOT NULL,
    EXPECTED_ITEM_ID    VARCHAR(36),
    CATEGORY            VARCHAR(100),
    DIFFICULTY          VARCHAR(20),  -- EASY, MEDIUM, HARD
    NOTES               VARCHAR(500),
    IS_ACTIVE           BOOLEAN DEFAULT TRUE,
    CREATED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    EMBEDDING           VECTOR(FLOAT, 1024),
    CONSTRAINT PK_ACCURACY_TEST PRIMARY KEY (TEST_ID)
)
COMMENT = 'Ground truth test set with known correct matches for accuracy testing';

-- Results from accuracy test runs
CREATE OR REPLACE TABLE HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_RESULTS (
    RESULT_ID           INT AUTOINCREMENT,
    TEST_ID             INT NOT NULL,
    METHOD              VARCHAR(50) NOT NULL,
    TOP1_MATCH_ID       VARCHAR(36),
    TOP1_DESCRIPTION    VARCHAR(500),
    TOP1_SCORE          FLOAT,
    IS_CORRECT          BOOLEAN,
    TOP3_CONTAINS       BOOLEAN,
    TOP5_CONTAINS       BOOLEAN,
    RUN_ID              VARCHAR(36),
    RUN_TIMESTAMP       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_ACCURACY_RESULTS PRIMARY KEY (RESULT_ID)
)
COMMENT = 'Results from accuracy test runs including top-N matches and scores';

-- Summary of accuracy test runs
CREATE OR REPLACE TABLE HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_RUNS (
    RUN_ID              VARCHAR(36) NOT NULL,
    RUN_TIMESTAMP       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    TOTAL_TESTS         INT,
    METHODS_TESTED      VARCHAR(500),
    NOTES               VARCHAR(1000),
    CONSTRAINT PK_ACCURACY_RUNS PRIMARY KEY (RUN_ID)
)
COMMENT = 'Summary metadata for each accuracy test execution run';

-- ============================================================================
-- Job Tracking for Accuracy Testing
-- ============================================================================

CREATE OR REPLACE TABLE HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_JOBS (
    JOB_ID VARCHAR(36) PRIMARY KEY,
    STATUS VARCHAR(20) NOT NULL DEFAULT 'QUEUED',
    
    INCLUDE_CORTEX_SEARCH BOOLEAN DEFAULT TRUE,
    
    TOTAL_TESTS INTEGER DEFAULT 0,
    TESTS_COMPLETED INTEGER DEFAULT 0,
    CURRENT_METHOD VARCHAR(50),
    
    QUEUED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    STARTED_AT TIMESTAMP_NTZ,
    COMPLETED_AT TIMESTAMP_NTZ,
    LAST_UPDATE_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    
    TRIGGERED_BY VARCHAR(100) DEFAULT CURRENT_USER(),
    ERROR_MESSAGE VARCHAR(4000),
    RESULT_RUN_ID VARCHAR(36)
)
COMMENT = 'Job tracking for background accuracy test execution';

-- ============================================================================
-- Procedure to populate test embeddings
-- ============================================================================

CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.ANALYTICS.POPULATE_TEST_EMBEDDINGS()
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Pre-computes embeddings for all active test cases to optimize accuracy testing'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_count INTEGER;
BEGIN
    UPDATE HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_SET
    SET EMBEDDING = SNOWFLAKE.CORTEX.EMBED_TEXT_1024(
        'snowflake-arctic-embed-l-v2.0', 
        RAW_DESCRIPTION
    )
    WHERE IS_ACTIVE = TRUE;
    
    v_count := SQLROWCOUNT;
    RETURN 'Populated embeddings for ' || :v_count || ' test cases';
END;
$$;

