-- ============================================================================
-- sql/setup/21_role_grants.sql
-- Retail Data Harmonizer - Role Grants
--
-- Purpose: Grant all necessary privileges to HARMONIZER_DEMO_ROLE
--          This ensures the role has explicit access to all demo objects.
--
-- Creates: No objects (grants only)
--
-- Depends on: All files 01-20 (all objects must exist before granting)
--
-- Note: Run this file after all other numbered files have been deployed.
--       Grants are idempotent - safe to re-run.
-- ============================================================================

USE ROLE ACCOUNTADMIN;  -- Need elevated role to grant on some objects

-- ============================================================================
-- Schema-level Grants
-- ============================================================================
GRANT USAGE ON DATABASE HARMONIZER_DEMO TO ROLE HARMONIZER_DEMO_ROLE;
GRANT USAGE ON SCHEMA HARMONIZER_DEMO.RAW TO ROLE HARMONIZER_DEMO_ROLE;
GRANT USAGE ON SCHEMA HARMONIZER_DEMO.HARMONIZED TO ROLE HARMONIZER_DEMO_ROLE;
GRANT USAGE ON SCHEMA HARMONIZER_DEMO.ANALYTICS TO ROLE HARMONIZER_DEMO_ROLE;

-- ============================================================================
-- Warehouse Grant
-- ============================================================================
GRANT USAGE ON WAREHOUSE HARMONIZER_DEMO_WH TO ROLE HARMONIZER_DEMO_ROLE;

-- ============================================================================
-- Table Grants - RAW Schema
-- ============================================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA HARMONIZER_DEMO.RAW 
    TO ROLE HARMONIZER_DEMO_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON FUTURE TABLES IN SCHEMA HARMONIZER_DEMO.RAW 
    TO ROLE HARMONIZER_DEMO_ROLE;

-- Specific tables for reference:
--   RAW.STANDARD_ITEMS
--   RAW.RAW_RETAIL_ITEMS
--   RAW.STANDARD_ITEMS_EMBEDDINGS

-- ============================================================================
-- Table Grants - HARMONIZED Schema
-- ============================================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA HARMONIZER_DEMO.HARMONIZED 
    TO ROLE HARMONIZER_DEMO_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON FUTURE TABLES IN SCHEMA HARMONIZER_DEMO.HARMONIZED 
    TO ROLE HARMONIZER_DEMO_ROLE;

-- Specific tables for reference:
--   HARMONIZED.ITEM_MATCHES
--   HARMONIZED.UNIQUE_DESCRIPTIONS
--   HARMONIZED.CONFIRMED_MATCHES
--   HARMONIZED.RAW_TO_UNIQUE_MAP
--   HARMONIZED.VENUE_PRODUCTS
--   HARMONIZED.PRICING_DECISIONS

-- ============================================================================
-- Table Grants - ANALYTICS Schema
-- ============================================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA HARMONIZER_DEMO.ANALYTICS 
    TO ROLE HARMONIZER_DEMO_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON FUTURE TABLES IN SCHEMA HARMONIZER_DEMO.ANALYTICS 
    TO ROLE HARMONIZER_DEMO_ROLE;

-- Specific tables for reference:
--   ANALYTICS.PIPELINE_EXECUTION_LOG
--   ANALYTICS.COST_TRACKING
--   ANALYTICS.PIPELINE_RUNS
--   ANALYTICS.CONFIG
--   ANALYTICS.ACCURACY_TEST_SET
--   ANALYTICS.ACCURACY_TEST_RESULTS
--   ANALYTICS.ACCURACY_TEST_JOBS
--   ANALYTICS.CLASSIFICATION_JOBS

-- ============================================================================
-- View Grants - All Schemas
-- ============================================================================
GRANT SELECT ON ALL VIEWS IN SCHEMA HARMONIZER_DEMO.RAW 
    TO ROLE HARMONIZER_DEMO_ROLE;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA HARMONIZER_DEMO.RAW 
    TO ROLE HARMONIZER_DEMO_ROLE;

GRANT SELECT ON ALL VIEWS IN SCHEMA HARMONIZER_DEMO.HARMONIZED 
    TO ROLE HARMONIZER_DEMO_ROLE;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA HARMONIZER_DEMO.HARMONIZED 
    TO ROLE HARMONIZER_DEMO_ROLE;

GRANT SELECT ON ALL VIEWS IN SCHEMA HARMONIZER_DEMO.ANALYTICS 
    TO ROLE HARMONIZER_DEMO_ROLE;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA HARMONIZER_DEMO.ANALYTICS 
    TO ROLE HARMONIZER_DEMO_ROLE;

-- Specific views for reference:
--   ANALYTICS.V_DASHBOARD_KPIS
--   ANALYTICS.V_ACCURACY_SUMMARY
--   ANALYTICS.V_ACCURACY_BY_DIFFICULTY

-- ============================================================================
-- Procedure Grants - HARMONIZED Schema
-- ============================================================================
GRANT USAGE ON ALL PROCEDURES IN SCHEMA HARMONIZER_DEMO.HARMONIZED 
    TO ROLE HARMONIZER_DEMO_ROLE;
GRANT USAGE ON FUTURE PROCEDURES IN SCHEMA HARMONIZER_DEMO.HARMONIZED 
    TO ROLE HARMONIZER_DEMO_ROLE;

-- Specific procedures for reference:
--   HARMONIZED.CLASSIFY_RAW_ITEMS
--   HARMONIZED.MATCH_CORTEX_SEARCH
--   HARMONIZED.MATCH_COSINE_SIMILARITY
--   HARMONIZED.MATCH_LLM_SEMANTIC
--   HARMONIZED.COMPUTE_ENSEMBLE_WITH_CONDITIONAL_LLM (self-contained finalizer)
--   HARMONIZED.RUN_MATCHING_PIPELINE
--   HARMONIZED.VECTOR_PREP_BATCH (stream consumer)
--   HARMONIZED.MATCH_CORTEX_SEARCH_BATCH (staging table writer)
--   HARMONIZED.MATCH_COSINE_BATCH (staging table writer)
--   HARMONIZED.MATCH_EDIT_BATCH (staging table writer)
--   HARMONIZED.MERGE_STAGING_TO_MATCHES (staging merger)
--   HARMONIZED.SUBMIT_REVIEW
--   HARMONIZED.FORCE_REEVALUATE_SCORES (full score recalculation)
--   HARMONIZED.ENABLE_PARALLEL_PIPELINE_TASKS
--   HARMONIZED.DISABLE_PARALLEL_PIPELINE_TASKS
--   HARMONIZED.GET_PIPELINE_STATUS
--   (Note: To trigger pipeline manually, use: EXECUTE TASK HARMONIZED.DEDUP_FASTPATH_TASK)
--   
--   Accuracy/Classification Job Tracking:
--   HARMONIZED.START_ACCURACY_TEST_JOB
--   HARMONIZED.UPDATE_ACCURACY_TEST_PROGRESS
--   HARMONIZED.GET_ACCURACY_TEST_JOB
--   HARMONIZED.START_CLASSIFICATION_JOB
--   HARMONIZED.UPDATE_CLASSIFICATION_PROGRESS
--   HARMONIZED.GET_CLASSIFICATION_JOB
--   HARMONIZED.PROCESS_CLASSIFICATION_JOB

-- ============================================================================
-- Procedure Grants - ANALYTICS Schema
-- ============================================================================
GRANT USAGE ON ALL PROCEDURES IN SCHEMA HARMONIZER_DEMO.ANALYTICS 
    TO ROLE HARMONIZER_DEMO_ROLE;
GRANT USAGE ON FUTURE PROCEDURES IN SCHEMA HARMONIZER_DEMO.ANALYTICS 
    TO ROLE HARMONIZER_DEMO_ROLE;

-- Specific procedures for reference:
--   ANALYTICS.LOG_PIPELINE_STEP
--   ANALYTICS.RUN_ACCURACY_TESTS
--   ANALYTICS.TEST_COSINE_ACCURACY
--   ANALYTICS.TEST_CORTEX_SEARCH_ACCURACY
--   ANALYTICS.TEST_EDIT_DISTANCE_ACCURACY
--   ANALYTICS.TEST_LLM_ACCURACY
--   ANALYTICS.DETECT_DATA_DRIFT
--   ANALYTICS.DETECT_MODEL_DRIFT
--   ANALYTICS.UPDATE_DRIFT_BASELINES

-- ============================================================================
-- Function Grants - All Schemas
-- ============================================================================
GRANT USAGE ON ALL FUNCTIONS IN SCHEMA HARMONIZER_DEMO.HARMONIZED 
    TO ROLE HARMONIZER_DEMO_ROLE;
GRANT USAGE ON FUTURE FUNCTIONS IN SCHEMA HARMONIZER_DEMO.HARMONIZED 
    TO ROLE HARMONIZER_DEMO_ROLE;

GRANT USAGE ON ALL FUNCTIONS IN SCHEMA HARMONIZER_DEMO.ANALYTICS 
    TO ROLE HARMONIZER_DEMO_ROLE;
GRANT USAGE ON FUTURE FUNCTIONS IN SCHEMA HARMONIZER_DEMO.ANALYTICS 
    TO ROLE HARMONIZER_DEMO_ROLE;

-- Specific functions for reference:
--   HARMONIZED.NORMALIZE_DESCRIPTION (Python UDF)
--   ANALYTICS.ESTIMATE_PIPELINE_COST

-- ============================================================================
-- Task Grants
-- ============================================================================
-- Grant ability to execute tasks on the account (required for task execution)
-- Note: This is an account-level privilege that must be granted by ACCOUNTADMIN
GRANT EXECUTE TASK ON ACCOUNT TO ROLE HARMONIZER_DEMO_ROLE;

-- Grant ability to operate tasks (view, resume, suspend)
GRANT MONITOR, OPERATE ON ALL TASKS IN SCHEMA HARMONIZER_DEMO.HARMONIZED 
    TO ROLE HARMONIZER_DEMO_ROLE;
GRANT MONITOR, OPERATE ON FUTURE TASKS IN SCHEMA HARMONIZER_DEMO.HARMONIZED 
    TO ROLE HARMONIZER_DEMO_ROLE;

GRANT MONITOR, OPERATE ON ALL TASKS IN SCHEMA HARMONIZER_DEMO.ANALYTICS 
    TO ROLE HARMONIZER_DEMO_ROLE;
GRANT MONITOR, OPERATE ON FUTURE TASKS IN SCHEMA HARMONIZER_DEMO.ANALYTICS 
    TO ROLE HARMONIZER_DEMO_ROLE;

-- Specific tasks for reference:
--   HARMONIZED.DEDUP_FASTPATH_TASK (root - stream-based)
--   HARMONIZED.VECTOR_PREP_TASK (after dedup)
--   HARMONIZED.CORTEX_SEARCH_TASK (sibling - parallel)
--   HARMONIZED.COSINE_MATCH_TASK (sibling - parallel)
--   HARMONIZED.EDIT_MATCH_TASK (sibling - parallel)
--   HARMONIZED.JACCARD_MATCH_TASK (sibling - parallel)
--   HARMONIZED.VECTOR_ENSEMBLE_TASK (finalizer)

-- ============================================================================
-- Stream Grants
-- ============================================================================
-- Grant usage on streams for parallel vector matching pipeline
GRANT SELECT ON ALL STREAMS IN SCHEMA HARMONIZER_DEMO.HARMONIZED 
    TO ROLE HARMONIZER_DEMO_ROLE;
GRANT SELECT ON FUTURE STREAMS IN SCHEMA HARMONIZER_DEMO.HARMONIZED 
    TO ROLE HARMONIZER_DEMO_ROLE;

-- Specific streams for reference:
--   HARMONIZED.RAW_ITEMS_STREAM (for exactly-once processing)

-- ============================================================================
-- Cortex Search Service Grant
-- ============================================================================
-- Grant usage on the Cortex Search service
GRANT USAGE ON CORTEX SEARCH SERVICE HARMONIZER_DEMO.HARMONIZED.STANDARD_ITEM_SEARCH 
    TO ROLE HARMONIZER_DEMO_ROLE;

-- ============================================================================
-- Sequence Grants (if any)
-- ============================================================================
GRANT USAGE ON ALL SEQUENCES IN SCHEMA HARMONIZER_DEMO.RAW 
    TO ROLE HARMONIZER_DEMO_ROLE;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA HARMONIZER_DEMO.HARMONIZED 
    TO ROLE HARMONIZER_DEMO_ROLE;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA HARMONIZER_DEMO.ANALYTICS 
    TO ROLE HARMONIZER_DEMO_ROLE;

-- ============================================================================
-- Stage Grants (for any file staging needs)
-- ============================================================================
GRANT READ, WRITE ON ALL STAGES IN SCHEMA HARMONIZER_DEMO.RAW 
    TO ROLE HARMONIZER_DEMO_ROLE;
GRANT READ, WRITE ON FUTURE STAGES IN SCHEMA HARMONIZER_DEMO.RAW 
    TO ROLE HARMONIZER_DEMO_ROLE;

GRANT READ, WRITE ON ALL STAGES IN SCHEMA HARMONIZER_DEMO.ANALYTICS 
    TO ROLE HARMONIZER_DEMO_ROLE;
GRANT READ, WRITE ON FUTURE STAGES IN SCHEMA HARMONIZER_DEMO.ANALYTICS 
    TO ROLE HARMONIZER_DEMO_ROLE;

-- ============================================================================
-- Verification
-- ============================================================================
-- Switch back to demo role and verify access
USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

SELECT 'Grants applied successfully' AS STATUS;

-- Quick verification queries
SELECT 
    'Tables' AS OBJECT_TYPE,
    COUNT(*) AS ACCESSIBLE_COUNT
FROM INFORMATION_SCHEMA.TABLE_PRIVILEGES
WHERE GRANTEE = 'HARMONIZER_DEMO_ROLE'
  AND TABLE_CATALOG = 'HARMONIZER_DEMO'

UNION ALL

SELECT 
    'Procedures',
    COUNT(*)
FROM HARMONIZER_DEMO.INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA IN ('HARMONIZED', 'ANALYTICS')

UNION ALL

SELECT 
    'Views',
    COUNT(*)
FROM HARMONIZER_DEMO.INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA IN ('RAW', 'HARMONIZED', 'ANALYTICS');
