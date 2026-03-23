-- ============================================================================
-- sql/teardown/01_teardown.sql
-- Retail Data Harmonizer - Full Teardown
--
-- Purpose: Remove ALL demo objects including data
--
-- WARNING: This is a DESTRUCTIVE operation!
-- 
-- Objects removed:
--   - HARMONIZER_DEMO database (CASCADE removes all schemas, tables, views, tasks)
--   - HARMONIZER_DEMO_WH warehouse
--   - HARMONIZER_DEMO_ROLE role
--   - HARMONIZER_DEMO_CPU_POOL compute pool (if created)
--   - PYPI_ACCESS_INTEGRATION external access integration (if created)
--
-- Note: Tasks must be suspended before database DROP
-- ============================================================================

USE ROLE SYSADMIN;

-- ============================================================================
-- Suspend ALL pipeline tasks before dropping database
-- Independent scheduled tasks (no dependencies, can suspend in any order)
-- ============================================================================
ALTER TASK IF EXISTS HARMONIZER_DEMO.HARMONIZED.ENSEMBLE_SCORING_TASK SUSPEND;
ALTER TASK IF EXISTS HARMONIZER_DEMO.HARMONIZED.ITEM_ROUTER_TASK SUSPEND;
ALTER TASK IF EXISTS HARMONIZER_DEMO.HARMONIZED.CLEANUP_COORDINATION_TASK SUSPEND;

-- Stream-triggered DAG (suspend root first to prevent child execution)
ALTER TASK IF EXISTS HARMONIZER_DEMO.HARMONIZED.DEDUP_FASTPATH_TASK SUSPEND;

-- DAG children (suspend after root)
ALTER TASK IF EXISTS HARMONIZER_DEMO.HARMONIZED.CLASSIFY_UNIQUE_TASK SUSPEND;
ALTER TASK IF EXISTS HARMONIZER_DEMO.HARMONIZED.VECTOR_PREP_TASK SUSPEND;
ALTER TASK IF EXISTS HARMONIZER_DEMO.HARMONIZED.CORTEX_SEARCH_TASK SUSPEND;
ALTER TASK IF EXISTS HARMONIZER_DEMO.HARMONIZED.COSINE_MATCH_TASK SUSPEND;
ALTER TASK IF EXISTS HARMONIZER_DEMO.HARMONIZED.EDIT_MATCH_TASK SUSPEND;
ALTER TASK IF EXISTS HARMONIZER_DEMO.HARMONIZED.JACCARD_MATCH_TASK SUSPEND;
ALTER TASK IF EXISTS HARMONIZER_DEMO.HARMONIZED.STAGING_MERGE_TASK SUSPEND;

DROP DATABASE IF EXISTS HARMONIZER_DEMO;
DROP WAREHOUSE IF EXISTS HARMONIZER_DEMO_WH;

-- Drop compute pool (created by 00_compute_pool.sql; requires ACCOUNTADMIN)
USE ROLE ACCOUNTADMIN;
DROP COMPUTE POOL IF EXISTS HARMONIZER_DEMO_CPU_POOL;

-- Drop external access integration (created by 00_external_access.sql)
DROP INTEGRATION IF EXISTS PYPI_ACCESS_INTEGRATION;

-- Revoke account-level privilege granted in 21_grants.sql
REVOKE EXECUTE TASK ON ACCOUNT FROM ROLE HARMONIZER_DEMO_ROLE;

USE ROLE SECURITYADMIN;

DROP ROLE IF EXISTS HARMONIZER_DEMO_ROLE;
