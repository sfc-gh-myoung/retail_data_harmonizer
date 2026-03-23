-- ============================================================================
-- sql/setup/18_api_views.sql
-- Retail Data Harmonizer - Performance Optimization Views
--
-- Purpose: Pre-aggregated views to eliminate expensive table scans on 
--          dashboard load. Reduces load time from 4+ seconds to <100ms.
--
-- Creates:
--   Tables:
--     - ANALYTICS.TASK_EXECUTION_CACHE (cached task history for fast queries)
--   Tasks:
--     - ANALYTICS.REFRESH_TASK_HISTORY_CACHE (refreshes cache every 2 min)
--     - ANALYTICS.CLEANUP_TASK_EXECUTION_CACHE (daily cleanup of old entries)
--   Views:
--     - ANALYTICS.V_DASHBOARD_KPIS (main dashboard metrics)
--     - ANALYTICS.V_MATCH_QUALITY_SUMMARY (match quality breakdown)
--     - ANALYTICS.V_SOURCE_SYSTEM_SUMMARY (per-source statistics)
--     - ANALYTICS.V_CATEGORY_DISTRIBUTION (category breakdown)
--     - ANALYTICS.V_RECENT_ACTIVITY (recent pipeline activity)
--     - ANALYTICS.V_DASHBOARD_CONFIDENCE_BEST (confidence by best match score)
--     - ANALYTICS.V_DASHBOARD_CONFIDENCE_ENSEMBLE (confidence by ensemble score)
--     - ANALYTICS.V_DASHBOARD_CONFIDENCE (legacy alias for ensemble)
--     - ANALYTICS.V_TASK_EXECUTION_HISTORY (reads from cache for fast queries)
--
-- Depends on:
--   - 02_schema_and_tables.sql (RAW_RETAIL_ITEMS, STANDARD_ITEMS)
--   - 11_matching/ (ITEM_MATCHES)
--   - 13_cost_and_analytics.sql (PIPELINE_RUNS, COST_TRACKING)
--   - 04_telemetry.sql (PIPELINE_EXECUTION_LOG)
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- Materialized view: Dashboard KPIs
-- ============================================================================
-- Replaces expensive COUNT(*) aggregations on RAW_RETAIL_ITEMS
-- Uses RAW_RETAIL_ITEMS.MATCH_STATUS as authoritative source (pipeline updates that table)
-- Falls back to ITEM_MATCHES.STATUS for items still in matching workflow
-- Maps USER_CONFIRMED -> CONFIRMED for consistency
CREATE OR REPLACE VIEW HARMONIZER_DEMO.ANALYTICS.V_DASHBOARD_KPIS AS
SELECT
    COUNT(*) AS total_items,
    SUM(CASE WHEN effective_status = 'AUTO_ACCEPTED' THEN 1 ELSE 0 END) AS auto_accepted,
    SUM(CASE WHEN effective_status IN ('CONFIRMED', 'USER_CONFIRMED') THEN 1 ELSE 0 END) AS confirmed,
    SUM(CASE WHEN effective_status = 'PENDING_REVIEW' THEN 1 ELSE 0 END) AS pending_review,
    SUM(CASE WHEN effective_status = 'PENDING' THEN 1 ELSE 0 END) AS pending,
    SUM(CASE WHEN effective_status = 'REJECTED' THEN 1 ELSE 0 END) AS rejected,
    CURRENT_TIMESTAMP() AS refreshed_at
FROM (
    SELECT 
        ri.ITEM_ID,
        -- Prioritize RAW_RETAIL_ITEMS.MATCH_STATUS when it indicates a final state
        CASE 
            WHEN ri.MATCH_STATUS IN ('AUTO_ACCEPTED', 'CONFIRMED', 'REJECTED') THEN ri.MATCH_STATUS
            ELSE COALESCE(im.STATUS, ri.MATCH_STATUS)
        END AS effective_status
    FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
    LEFT JOIN HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im ON ri.ITEM_ID = im.RAW_ITEM_ID
);

-- ============================================================================
-- Materialized view: Source system breakdown
-- ============================================================================
CREATE OR REPLACE VIEW HARMONIZER_DEMO.ANALYTICS.V_DASHBOARD_SOURCES AS
SELECT 
    ri.SOURCE_SYSTEM, 
    CASE 
        WHEN ri.MATCH_STATUS IN ('AUTO_ACCEPTED', 'CONFIRMED', 'REJECTED') THEN ri.MATCH_STATUS
        WHEN COALESCE(im.STATUS, ri.MATCH_STATUS) = 'USER_CONFIRMED' THEN 'CONFIRMED'
        ELSE COALESCE(im.STATUS, ri.MATCH_STATUS)
    END AS MATCH_STATUS, 
    COUNT(*) AS CNT
FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
LEFT JOIN HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im ON ri.ITEM_ID = im.RAW_ITEM_ID
GROUP BY ri.SOURCE_SYSTEM, 
    CASE 
        WHEN ri.MATCH_STATUS IN ('AUTO_ACCEPTED', 'CONFIRMED', 'REJECTED') THEN ri.MATCH_STATUS
        WHEN COALESCE(im.STATUS, ri.MATCH_STATUS) = 'USER_CONFIRMED' THEN 'CONFIRMED'
        ELSE COALESCE(im.STATUS, ri.MATCH_STATUS)
    END;

-- ============================================================================
-- Materialized view: Category match rates
-- Shows ALL taxonomy categories, including those with 0 items
-- ============================================================================
CREATE OR REPLACE VIEW HARMONIZER_DEMO.ANALYTICS.V_DASHBOARD_CATEGORIES AS
SELECT
    ct.CATEGORY,
    COALESCE(counts.TOTAL, 0) AS TOTAL,
    COALESCE(counts.MATCHED, 0) AS MATCHED
FROM (
    -- All active top-level categories from taxonomy
    SELECT DISTINCT CATEGORY 
    FROM HARMONIZER_DEMO.RAW.CATEGORY_TAXONOMY 
    WHERE SUBCATEGORY IS NULL 
      AND IS_ACTIVE = TRUE
) ct
LEFT JOIN (
    -- Actual item counts by inferred category
    SELECT
        COALESCE(ri.INFERRED_CATEGORY, 'Uncategorized') AS CATEGORY,
        COUNT(*) AS TOTAL,
        SUM(CASE 
            WHEN ri.MATCH_STATUS IN ('AUTO_ACCEPTED', 'CONFIRMED') THEN 1
            WHEN COALESCE(im.STATUS, ri.MATCH_STATUS) IN ('AUTO_ACCEPTED', 'CONFIRMED', 'USER_CONFIRMED') THEN 1
            ELSE 0 
        END) AS MATCHED
    FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
    LEFT JOIN HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im ON ri.ITEM_ID = im.RAW_ITEM_ID
    GROUP BY COALESCE(ri.INFERRED_CATEGORY, 'Uncategorized')
) counts ON ct.CATEGORY = counts.CATEGORY;

-- ============================================================================
-- Materialized view: Confidence distribution (Best Match Score)
-- Best Match Score = highest individual method score (search, cosine, edit)
-- ============================================================================
CREATE OR REPLACE VIEW HARMONIZER_DEMO.ANALYTICS.V_DASHBOARD_CONFIDENCE_BEST AS
SELECT
    CASE
        WHEN BEST_SCORE < 0.5 THEN '0.0 - 0.5'
        WHEN BEST_SCORE < 0.7 THEN '0.5 - 0.7'
        WHEN BEST_SCORE < 0.8 THEN '0.7 - 0.8'
        WHEN BEST_SCORE < 0.9 THEN '0.8 - 0.9'
        ELSE '0.9 - 1.0'
    END AS BUCKET,
    COUNT(*) AS CNT
FROM (
    SELECT 
        GREATEST(
            COALESCE(CORTEX_SEARCH_SCORE, 0),
            COALESCE(COSINE_SCORE, 0),
            COALESCE(EDIT_DISTANCE_SCORE, 0)
        ) AS BEST_SCORE
    FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
    WHERE CORTEX_SEARCH_SCORE IS NOT NULL 
       OR COSINE_SCORE IS NOT NULL 
       OR EDIT_DISTANCE_SCORE IS NOT NULL
)
GROUP BY BUCKET;

-- ============================================================================
-- Materialized view: Confidence distribution (Ensemble Score)
-- Ensemble Score = ENSEMBLE_SCORE (normalized weighted average × agreement multiplier)
-- Formula: base_score × agreement_multiplier (4-way=1.20, 3-way=1.15, 2-way=1.10)
-- Pure 4-method ensemble scoring: Cortex Search, Cosine, Edit Distance, Jaccard
-- ============================================================================
CREATE OR REPLACE VIEW HARMONIZER_DEMO.ANALYTICS.V_DASHBOARD_CONFIDENCE_ENSEMBLE AS
SELECT
    CASE
        WHEN ENSEMBLE_SCORE < 0.5 THEN '0.0 - 0.5'
        WHEN ENSEMBLE_SCORE < 0.7 THEN '0.5 - 0.7'
        WHEN ENSEMBLE_SCORE < 0.8 THEN '0.7 - 0.8'
        WHEN ENSEMBLE_SCORE < 0.9 THEN '0.8 - 0.9'
        ELSE '0.9 - 1.0'
    END AS BUCKET,
    COUNT(*) AS CNT
FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
WHERE ENSEMBLE_SCORE IS NOT NULL
GROUP BY BUCKET;

-- ============================================================================
-- Materialized view: Scale metrics
-- ============================================================================
CREATE OR REPLACE VIEW HARMONIZER_DEMO.ANALYTICS.V_DASHBOARD_SCALE AS
SELECT
    (SELECT COUNT(*) FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS) AS total_items,
    (SELECT COUNT(*) FROM HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS) AS unique_count,
    (SELECT COUNT(*) FROM HARMONIZER_DEMO.HARMONIZED.CONFIRMED_MATCHES) AS fast_path_count,
    CURRENT_TIMESTAMP() AS refreshed_at;

-- ============================================================================
-- Query Result Caching
-- ============================================================================
-- Note: Query result caching is enabled by default at the account level.
-- Snowflake automatically caches query results for 24 hours when:
--   1. The same query is executed
--   2. The underlying data hasn't changed
--   3. The USE_CACHED_RESULT session parameter is TRUE (default)
--
-- These views will benefit from automatic result caching without any
-- additional configuration. To disable caching for specific queries:
--   ALTER SESSION SET USE_CACHED_RESULT = FALSE;

-- ============================================================================
-- Optional: Create dynamic table for near-real-time updates
-- ============================================================================
-- Uncomment if you need sub-minute refresh rates
/*
CREATE OR REPLACE DYNAMIC TABLE HARMONIZER_DEMO.ANALYTICS.DT_DASHBOARD_KPIS
    TARGET_LAG = '1 minute'
    WAREHOUSE = HARMONIZER_DEMO_WH
AS
SELECT
    COUNT(*) AS total_items,
    SUM(CASE WHEN MATCH_STATUS = 'AUTO_ACCEPTED' THEN 1 ELSE 0 END) AS auto_accepted,
    SUM(CASE WHEN MATCH_STATUS = 'CONFIRMED' THEN 1 ELSE 0 END) AS confirmed,
    SUM(CASE WHEN MATCH_STATUS = 'PENDING_REVIEW' THEN 1 ELSE 0 END) AS pending_review,
    SUM(CASE WHEN MATCH_STATUS = 'PENDING' THEN 1 ELSE 0 END) AS pending,
    SUM(CASE WHEN MATCH_STATUS = 'REJECTED' THEN 1 ELSE 0 END) AS rejected
FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS;
*/

-- ============================================================================
-- Task Execution Cache: Fast-read table for task history queries
-- ============================================================================
-- Replaces slow INFORMATION_SCHEMA.TASK_HISTORY() table function with a
-- pre-cached table. Refreshed every 2 minutes by REFRESH_TASK_HISTORY_CACHE task.
-- This reduces /api/v2/pipeline/history response time from ~4s to <100ms.

CREATE TABLE IF NOT EXISTS HARMONIZER_DEMO.ANALYTICS.TASK_EXECUTION_CACHE (
    TASK_NAME           VARCHAR(256)    NOT NULL,
    DATABASE_NAME       VARCHAR(256),
    SCHEMA_NAME         VARCHAR(256),
    STATE               VARCHAR(50),
    SCHEDULED_TIME      TIMESTAMP_LTZ   NOT NULL,
    QUERY_START_TIME    TIMESTAMP_LTZ,
    COMPLETED_TIME      TIMESTAMP_LTZ,
    DURATION_SECONDS    NUMBER,
    ERROR_CODE          VARCHAR(50),
    ERROR_MESSAGE       VARCHAR(10000),
    RETURN_VALUE        VARCHAR(10000),
    -- Troubleshooting columns (added for enhanced debugging)
    QUERY_ID            VARCHAR(256),
    QUERY_TEXT          VARCHAR(4000),
    RUN_ID              VARCHAR(256),
    ATTEMPT_NUMBER      INTEGER,
    CAPTURED_AT         TIMESTAMP_LTZ   DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (TASK_NAME, SCHEDULED_TIME)
)
COMMENT = 'Cached task execution history for fast dashboard queries';

-- ============================================================================
-- REFRESH_TASK_HISTORY_CACHE: Refresh cache every 2 minutes
-- ============================================================================
CREATE OR REPLACE TASK HARMONIZER_DEMO.ANALYTICS.REFRESH_TASK_HISTORY_CACHE
    WAREHOUSE = HARMONIZER_DEMO_WH
    SCHEDULE = '2 MINUTE'
    COMMENT = 'Refreshes task execution cache from INFORMATION_SCHEMA.TASK_HISTORY()'
AS
MERGE INTO HARMONIZER_DEMO.ANALYTICS.TASK_EXECUTION_CACHE tgt
USING (
    SELECT 
        NAME AS TASK_NAME,
        DATABASE_NAME,
        SCHEMA_NAME,
        STATE,
        SCHEDULED_TIME,
        QUERY_START_TIME,
        COMPLETED_TIME,
        TIMESTAMPDIFF('second', QUERY_START_TIME, COMPLETED_TIME) AS DURATION_SECONDS,
        ERROR_CODE,
        ERROR_MESSAGE,
        RETURN_VALUE,
        -- Troubleshooting columns
        QUERY_ID,
        LEFT(QUERY_TEXT, 4000) AS QUERY_TEXT,
        RUN_ID::VARCHAR AS RUN_ID,
        ATTEMPT_NUMBER
    FROM TABLE(HARMONIZER_DEMO.INFORMATION_SCHEMA.TASK_HISTORY(
        SCHEDULED_TIME_RANGE_START => DATEADD('hour', -24, CURRENT_TIMESTAMP()),
        RESULT_LIMIT => 500
    ))
    WHERE DATABASE_NAME = 'HARMONIZER_DEMO'
      AND (SCHEMA_NAME = 'HARMONIZED' OR SCHEMA_NAME = 'ANALYTICS')
      AND NAME IN (
          -- Stream Pipeline DAG (8 tasks)
          'DEDUP_FASTPATH_TASK',
          'CLASSIFY_UNIQUE_TASK',
          'VECTOR_PREP_TASK',
          'CORTEX_SEARCH_TASK',
          'COSINE_MATCH_TASK',
          'EDIT_MATCH_TASK',
          'JACCARD_MATCH_TASK',
          'STAGING_MERGE_TASK',
          -- Decoupled Pipeline Tasks (2 tasks)
          'ENSEMBLE_SCORING_TASK',
          'ITEM_ROUTER_TASK',
          -- Maintenance Tasks
          'CLEANUP_COORDINATION_TASK',
          -- Analytics Maintenance Tasks
          'REFRESH_TASK_HISTORY_CACHE',
          'CLEANUP_TASK_EXECUTION_CACHE',
          'REFRESH_TASK_STATE_CACHE'
      )
) src
ON tgt.TASK_NAME = src.TASK_NAME AND tgt.SCHEDULED_TIME = src.SCHEDULED_TIME
WHEN MATCHED THEN UPDATE SET
    tgt.STATE = src.STATE,
    tgt.QUERY_START_TIME = src.QUERY_START_TIME,
    tgt.COMPLETED_TIME = src.COMPLETED_TIME,
    tgt.DURATION_SECONDS = src.DURATION_SECONDS,
    tgt.ERROR_CODE = src.ERROR_CODE,
    tgt.ERROR_MESSAGE = src.ERROR_MESSAGE,
    tgt.RETURN_VALUE = src.RETURN_VALUE,
    tgt.QUERY_ID = src.QUERY_ID,
    tgt.QUERY_TEXT = src.QUERY_TEXT,
    tgt.RUN_ID = src.RUN_ID,
    tgt.ATTEMPT_NUMBER = src.ATTEMPT_NUMBER,
    tgt.CAPTURED_AT = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    TASK_NAME, DATABASE_NAME, SCHEMA_NAME, STATE, SCHEDULED_TIME,
    QUERY_START_TIME, COMPLETED_TIME, DURATION_SECONDS, ERROR_CODE,
    ERROR_MESSAGE, RETURN_VALUE, QUERY_ID, QUERY_TEXT, RUN_ID, ATTEMPT_NUMBER, CAPTURED_AT
) VALUES (
    src.TASK_NAME, src.DATABASE_NAME, src.SCHEMA_NAME, src.STATE, src.SCHEDULED_TIME,
    src.QUERY_START_TIME, src.COMPLETED_TIME, src.DURATION_SECONDS, src.ERROR_CODE,
    src.ERROR_MESSAGE, src.RETURN_VALUE, src.QUERY_ID, src.QUERY_TEXT, src.RUN_ID, src.ATTEMPT_NUMBER, CURRENT_TIMESTAMP()
);

-- ============================================================================
-- CLEANUP_TASK_EXECUTION_CACHE: Daily cleanup of old entries (>7 days)
-- ============================================================================
CREATE OR REPLACE TASK HARMONIZER_DEMO.ANALYTICS.CLEANUP_TASK_EXECUTION_CACHE
    WAREHOUSE = HARMONIZER_DEMO_WH
    SCHEDULE = 'USING CRON 0 2 * * * America/New_York'
    COMMENT = 'Daily cleanup of task execution cache entries older than 7 days'
AS
DELETE FROM HARMONIZER_DEMO.ANALYTICS.TASK_EXECUTION_CACHE
WHERE SCHEDULED_TIME < DATEADD(day, -7, CURRENT_TIMESTAMP());

-- Resume the cache maintenance tasks
ALTER TASK HARMONIZER_DEMO.ANALYTICS.REFRESH_TASK_HISTORY_CACHE RESUME;
ALTER TASK HARMONIZER_DEMO.ANALYTICS.CLEANUP_TASK_EXECUTION_CACHE RESUME;

-- ============================================================================
-- Task State Cache: Fast-read table for SHOW TASKS results
-- ============================================================================
-- Replaces slow SHOW TASKS queries with a pre-cached table.
-- Refreshed every 30 seconds by REFRESH_TASK_STATE_CACHE task.
-- This reduces /api/v2/pipeline/tasks response time from ~2.4s to <100ms.

CREATE TABLE IF NOT EXISTS HARMONIZER_DEMO.ANALYTICS.TASK_STATE_CACHE (
    TASK_NAME           VARCHAR(256)    NOT NULL,
    DATABASE_NAME       VARCHAR(256),
    SCHEMA_NAME         VARCHAR(256),
    STATE               VARCHAR(50),
    SCHEDULE            VARCHAR(1000),
    PREDECESSORS        VARCHAR(4000),
    WAREHOUSE           VARCHAR(256),
    COMMENT             VARCHAR(4000),
    CAPTURED_AT         TIMESTAMP_LTZ   DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (SCHEMA_NAME, TASK_NAME)
)
COMMENT = 'Cached task state from SHOW TASKS for fast dashboard queries';

-- ============================================================================
-- REFRESH_TASK_STATE_CACHE: Refresh cache every 30 seconds
-- ============================================================================
-- Uses atomic swap pattern to prevent race conditions during refresh.
-- Queries are never exposed to partial/empty state during the refresh window.
-- Pattern: Build complete dataset in staging table, then atomic SWAP.
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.ANALYTICS.REFRESH_TASK_STATE_CACHE_PROC()
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Atomically refreshes task state cache using staging table swap'
EXECUTE AS OWNER
AS
$$
BEGIN
    -- Build new data in staging table (queries continue hitting main table)
    CREATE OR REPLACE TABLE HARMONIZER_DEMO.ANALYTICS.TASK_STATE_CACHE_STAGING (
        TASK_NAME           VARCHAR(256)    NOT NULL,
        DATABASE_NAME       VARCHAR(256),
        SCHEMA_NAME         VARCHAR(256),
        STATE               VARCHAR(50),
        SCHEDULE            VARCHAR(1000),
        PREDECESSORS        VARCHAR(4000),
        WAREHOUSE           VARCHAR(256),
        COMMENT             VARCHAR(4000),
        CAPTURED_AT         TIMESTAMP_LTZ   DEFAULT CURRENT_TIMESTAMP(),
        PRIMARY KEY (SCHEMA_NAME, TASK_NAME)
    );
    
    -- Collect HARMONIZED tasks
    SHOW TASKS IN SCHEMA HARMONIZER_DEMO.HARMONIZED;
    INSERT INTO HARMONIZER_DEMO.ANALYTICS.TASK_STATE_CACHE_STAGING
        (TASK_NAME, DATABASE_NAME, SCHEMA_NAME, STATE, SCHEDULE, PREDECESSORS, WAREHOUSE, COMMENT, CAPTURED_AT)
    SELECT "name", "database_name", "schema_name", "state", "schedule", 
           ARRAY_TO_STRING("predecessors", ','), "warehouse", "comment", CURRENT_TIMESTAMP()
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
    
    -- Collect ANALYTICS tasks
    SHOW TASKS IN SCHEMA HARMONIZER_DEMO.ANALYTICS;
    INSERT INTO HARMONIZER_DEMO.ANALYTICS.TASK_STATE_CACHE_STAGING
        (TASK_NAME, DATABASE_NAME, SCHEMA_NAME, STATE, SCHEDULE, PREDECESSORS, WAREHOUSE, COMMENT, CAPTURED_AT)
    SELECT "name", "database_name", "schema_name", "state", "schedule", 
           ARRAY_TO_STRING("predecessors", ','), "warehouse", "comment", CURRENT_TIMESTAMP()
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
    
    -- Atomic swap: instantaneous, zero-downtime (queries never see partial state)
    ALTER TABLE HARMONIZER_DEMO.ANALYTICS.TASK_STATE_CACHE_STAGING
        SWAP WITH HARMONIZER_DEMO.ANALYTICS.TASK_STATE_CACHE;
    
    -- Clean up the now-empty staging table (contains old data after swap)
    DROP TABLE IF EXISTS HARMONIZER_DEMO.ANALYTICS.TASK_STATE_CACHE_STAGING;
    
    RETURN 'Task state cache refreshed atomically';
END;
$$;

CREATE OR REPLACE TASK HARMONIZER_DEMO.ANALYTICS.REFRESH_TASK_STATE_CACHE
    WAREHOUSE = HARMONIZER_DEMO_WH
    SCHEDULE = '30 SECOND'
    COMMENT = 'Refreshes task state cache from SHOW TASKS every 30 seconds'
AS
CALL HARMONIZER_DEMO.ANALYTICS.REFRESH_TASK_STATE_CACHE_PROC();

-- Resume the task state cache refresh
ALTER TASK HARMONIZER_DEMO.ANALYTICS.REFRESH_TASK_STATE_CACHE RESUME;

-- ============================================================================
-- V_TASK_STATE_CACHE: Deduplicated view for API consumption
-- ============================================================================
-- Provides a defensive layer guaranteeing one row per TASK_NAME.
-- Uses QUALIFY ROW_NUMBER() per Snowflake best practices for deduplication.
-- Backend API queries this view instead of the table directly.
CREATE OR REPLACE VIEW HARMONIZER_DEMO.ANALYTICS.V_TASK_STATE_CACHE
COMMENT = 'Deduplicated task state for API consumption - guarantees one row per task name'
AS
SELECT
    TASK_NAME,
    DATABASE_NAME,
    SCHEMA_NAME,
    STATE,
    SCHEDULE,
    PREDECESSORS,
    WAREHOUSE,
    COMMENT,
    CAPTURED_AT
FROM HARMONIZER_DEMO.ANALYTICS.TASK_STATE_CACHE
QUALIFY ROW_NUMBER() OVER (PARTITION BY TASK_NAME ORDER BY CAPTURED_AT DESC) = 1;

-- ============================================================================
-- Task Execution History: Monitor scheduled task performance
-- ============================================================================
-- Reads from the cached table for fast queries (<100ms vs 4s from table function).
-- Cache is refreshed every 2 minutes by REFRESH_TASK_HISTORY_CACHE task.
CREATE OR REPLACE VIEW HARMONIZER_DEMO.ANALYTICS.V_TASK_EXECUTION_HISTORY
COMMENT = 'Task execution history for pipeline monitoring (reads from cache)'
AS
SELECT 
    TASK_NAME,
    DATABASE_NAME,
    SCHEMA_NAME,
    STATE,
    SCHEDULED_TIME,
    QUERY_START_TIME,
    COMPLETED_TIME,
    DURATION_SECONDS,
    ERROR_CODE,
    ERROR_MESSAGE,
    RETURN_VALUE,
    -- Troubleshooting columns
    QUERY_ID,
    QUERY_TEXT,
    RUN_ID,
    ATTEMPT_NUMBER
FROM HARMONIZER_DEMO.ANALYTICS.TASK_EXECUTION_CACHE
ORDER BY SCHEDULED_TIME DESC;

-- ============================================================================
-- Phase 7: Optimization Metrics View
-- ============================================================================
-- Tracks method agreement rates, cache hit rate, and 4-method ensemble effectiveness
CREATE OR REPLACE VIEW HARMONIZER_DEMO.ANALYTICS.V_OPTIMIZATION_METRICS
COMMENT = 'Optimization metrics: method agreement rates, cache hits, ensemble performance'
AS
WITH base_stats AS (
    SELECT
        COUNT(*) AS total_matches,
        SUM(CASE WHEN IS_CACHED = TRUE THEN 1 ELSE 0 END) AS cache_hits,
        -- 4-way agreement: all 4 methods agree
        SUM(CASE WHEN SEARCH_MATCHED_ID IS NOT NULL
                  AND SEARCH_MATCHED_ID = COSINE_MATCHED_ID
                  AND COSINE_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID
                  AND EDIT_DISTANCE_MATCHED_ID = JACCARD_MATCHED_ID
            THEN 1 ELSE 0 END) AS agreement_4way,
        -- 3-way agreement: at least 3 methods agree
        SUM(CASE WHEN SEARCH_MATCHED_ID IS NOT NULL
                  AND COSINE_MATCHED_ID IS NOT NULL
                  AND EDIT_DISTANCE_MATCHED_ID IS NOT NULL
                  AND JACCARD_MATCHED_ID IS NOT NULL
                  AND (
                      (SEARCH_MATCHED_ID = COSINE_MATCHED_ID AND COSINE_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID)
                      OR (SEARCH_MATCHED_ID = COSINE_MATCHED_ID AND COSINE_MATCHED_ID = JACCARD_MATCHED_ID)
                      OR (SEARCH_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID AND EDIT_DISTANCE_MATCHED_ID = JACCARD_MATCHED_ID)
                      OR (COSINE_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID AND EDIT_DISTANCE_MATCHED_ID = JACCARD_MATCHED_ID)
                  )
            THEN 1 ELSE 0 END) AS agreement_3way,
        -- 2-way agreement: at least 2 methods agree
        SUM(CASE WHEN (SEARCH_MATCHED_ID = COSINE_MATCHED_ID AND SEARCH_MATCHED_ID IS NOT NULL)
                  OR (SEARCH_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID AND SEARCH_MATCHED_ID IS NOT NULL)
                  OR (SEARCH_MATCHED_ID = JACCARD_MATCHED_ID AND SEARCH_MATCHED_ID IS NOT NULL)
                  OR (COSINE_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID AND COSINE_MATCHED_ID IS NOT NULL)
                  OR (COSINE_MATCHED_ID = JACCARD_MATCHED_ID AND COSINE_MATCHED_ID IS NOT NULL)
                  OR (EDIT_DISTANCE_MATCHED_ID = JACCARD_MATCHED_ID AND EDIT_DISTANCE_MATCHED_ID IS NOT NULL)
            THEN 1 ELSE 0 END) AS agreement_2way,
        AVG(ENSEMBLE_SCORE) AS avg_ensemble_score,
        AVG(CASE WHEN SEARCH_MATCHED_ID = COSINE_MATCHED_ID 
                  AND COSINE_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID 
                  AND EDIT_DISTANCE_MATCHED_ID = JACCARD_MATCHED_ID 
            THEN ENSEMBLE_SCORE END) AS avg_score_4way_agreement
    FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
    WHERE ENSEMBLE_SCORE IS NOT NULL
)
SELECT
    b.total_matches,
    b.cache_hits,
    ROUND(b.cache_hits::FLOAT / NULLIF(b.total_matches, 0) * 100, 2) AS cache_hit_rate_pct,
    b.agreement_4way AS agreement_4way_count,
    b.agreement_3way AS agreement_3way_count,
    b.agreement_2way AS agreement_2way_count,
    ROUND(b.agreement_4way::FLOAT / NULLIF(b.total_matches, 0) * 100, 2) AS agreement_4way_pct,
    ROUND(b.agreement_3way::FLOAT / NULLIF(b.total_matches, 0) * 100, 2) AS agreement_3way_pct,
    ROUND(b.agreement_2way::FLOAT / NULLIF(b.total_matches, 0) * 100, 2) AS agreement_2way_pct,
    ROUND(b.avg_ensemble_score, 4) AS avg_ensemble_score,
    ROUND(b.avg_score_4way_agreement, 4) AS avg_score_when_4way_agreement,
    CURRENT_TIMESTAMP() AS computed_at
FROM base_stats b;

-- ============================================================================
-- Phase 7: Method Accuracy View
-- ============================================================================
-- Compares each matching method's accuracy against confirmed matches
-- Pure 4-method ensemble: Cortex Search, Cosine, Edit Distance, Jaccard
CREATE OR REPLACE VIEW HARMONIZER_DEMO.ANALYTICS.V_METHOD_ACCURACY
COMMENT = 'Per-method accuracy compared to human-confirmed matches (4-method ensemble)'
AS
WITH confirmed_matches AS (
    SELECT 
        im.RAW_ITEM_ID,
        im.CONFIRMED_STANDARD_ID,
        im.SEARCH_MATCHED_ID,
        im.COSINE_MATCHED_ID,
        im.EDIT_DISTANCE_MATCHED_ID,
        im.JACCARD_MATCHED_ID,
        im.SUGGESTED_STANDARD_ID,
        im.CORTEX_SEARCH_SCORE,
        im.COSINE_SCORE,
        im.EDIT_DISTANCE_SCORE,
        im.JACCARD_SCORE,
        im.ENSEMBLE_SCORE
    FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
    WHERE im.STATUS = 'USER_CONFIRMED'
      AND im.CONFIRMED_STANDARD_ID IS NOT NULL
),
method_stats AS (
    SELECT
        COUNT(*) AS total_confirmed,
        -- Search accuracy
        SUM(CASE WHEN SEARCH_MATCHED_ID = CONFIRMED_STANDARD_ID THEN 1 ELSE 0 END) AS search_correct,
        AVG(CASE WHEN SEARCH_MATCHED_ID = CONFIRMED_STANDARD_ID THEN CORTEX_SEARCH_SCORE END) AS search_correct_avg_score,
        -- Cosine accuracy
        SUM(CASE WHEN COSINE_MATCHED_ID = CONFIRMED_STANDARD_ID THEN 1 ELSE 0 END) AS cosine_correct,
        AVG(CASE WHEN COSINE_MATCHED_ID = CONFIRMED_STANDARD_ID THEN COSINE_SCORE END) AS cosine_correct_avg_score,
        -- Edit distance accuracy
        SUM(CASE WHEN EDIT_DISTANCE_MATCHED_ID = CONFIRMED_STANDARD_ID THEN 1 ELSE 0 END) AS edit_correct,
        AVG(CASE WHEN EDIT_DISTANCE_MATCHED_ID = CONFIRMED_STANDARD_ID THEN EDIT_DISTANCE_SCORE END) AS edit_correct_avg_score,
        -- Jaccard accuracy
        SUM(CASE WHEN JACCARD_MATCHED_ID = CONFIRMED_STANDARD_ID THEN 1 ELSE 0 END) AS jaccard_correct,
        AVG(CASE WHEN JACCARD_MATCHED_ID = CONFIRMED_STANDARD_ID THEN JACCARD_SCORE END) AS jaccard_correct_avg_score,
        -- Ensemble accuracy (final 4-method score)
        SUM(CASE WHEN SUGGESTED_STANDARD_ID = CONFIRMED_STANDARD_ID THEN 1 ELSE 0 END) AS ensemble_correct,
        AVG(CASE WHEN SUGGESTED_STANDARD_ID = CONFIRMED_STANDARD_ID THEN ENSEMBLE_SCORE END) AS ensemble_correct_avg_score
    FROM confirmed_matches
)
SELECT
    total_confirmed,
    -- Search
    search_correct,
    ROUND(search_correct::FLOAT / NULLIF(total_confirmed, 0) * 100, 2) AS search_accuracy_pct,
    ROUND(search_correct_avg_score, 4) AS search_avg_score_when_correct,
    -- Cosine
    cosine_correct,
    ROUND(cosine_correct::FLOAT / NULLIF(total_confirmed, 0) * 100, 2) AS cosine_accuracy_pct,
    ROUND(cosine_correct_avg_score, 4) AS cosine_avg_score_when_correct,
    -- Edit Distance
    edit_correct,
    ROUND(edit_correct::FLOAT / NULLIF(total_confirmed, 0) * 100, 2) AS edit_accuracy_pct,
    ROUND(edit_correct_avg_score, 4) AS edit_avg_score_when_correct,
    -- Jaccard
    jaccard_correct,
    ROUND(jaccard_correct::FLOAT / NULLIF(total_confirmed, 0) * 100, 2) AS jaccard_accuracy_pct,
    ROUND(jaccard_correct_avg_score, 4) AS jaccard_avg_score_when_correct,
    -- Ensemble (final 4-method score)
    ensemble_correct,
    ROUND(ensemble_correct::FLOAT / NULLIF(total_confirmed, 0) * 100, 2) AS ensemble_accuracy_pct,
    ROUND(ensemble_correct_avg_score, 4) AS ensemble_avg_score_when_correct,
    CURRENT_TIMESTAMP() AS computed_at
FROM method_stats;

-- ============================================================================
-- V_TASK_EXECUTION_METRICS: Detailed task-level performance metrics
-- ============================================================================
-- More detailed than V_TASK_EXECUTION_HISTORY with duration display formatting
-- and task type classification for dashboard filtering
CREATE OR REPLACE VIEW HARMONIZER_DEMO.ANALYTICS.V_TASK_EXECUTION_METRICS
COMMENT = 'Task execution metrics with duration formatting and type classification'
AS
WITH task_history AS (
    SELECT 
        NAME AS TASK_NAME,
        STATE,
        SCHEDULED_TIME,
        COMPLETED_TIME,
        TIMESTAMPDIFF('second', SCHEDULED_TIME, COMPLETED_TIME) AS DURATION_SECONDS,
        ERROR_CODE,
        ERROR_MESSAGE,
        QUERY_ID
    FROM TABLE(HARMONIZER_DEMO.INFORMATION_SCHEMA.TASK_HISTORY(
        SCHEDULED_TIME_RANGE_START => DATEADD('day', -7, CURRENT_TIMESTAMP()),
        RESULT_LIMIT => 1000,
        TASK_NAME => NULL
    ))
    WHERE DATABASE_NAME = 'HARMONIZER_DEMO'
)
SELECT 
    TASK_NAME,
    STATE,
    SCHEDULED_TIME,
    COMPLETED_TIME,
    DURATION_SECONDS,
    CASE 
        WHEN DURATION_SECONDS < 60 THEN DURATION_SECONDS || 's'
        WHEN DURATION_SECONDS < 3600 THEN ROUND(DURATION_SECONDS / 60, 1) || 'm'
        ELSE ROUND(DURATION_SECONDS / 3600, 1) || 'h'
    END AS DURATION_DISPLAY,
    CASE 
        WHEN TASK_NAME = 'CORTEX_SEARCH_TASK' THEN 'cortex_search'
        WHEN TASK_NAME = 'COSINE_MATCH_TASK' THEN 'cosine'
        WHEN TASK_NAME = 'EDIT_MATCH_TASK' THEN 'edit_distance'
        WHEN TASK_NAME = 'JACCARD_MATCH_TASK' THEN 'jaccard'
        WHEN TASK_NAME = 'VECTOR_PREP_TASK' THEN 'prep'
        WHEN TASK_NAME = 'VECTOR_ENSEMBLE_TASK' THEN 'ensemble'
        WHEN TASK_NAME = 'DEDUP_FASTPATH_TASK' THEN 'dedup'
        ELSE 'other'
    END AS TASK_TYPE,
    ERROR_CODE,
    ERROR_MESSAGE,
    QUERY_ID
FROM task_history
ORDER BY SCHEDULED_TIME DESC;

-- ============================================================================
-- V_PIPELINE_LATENCY_SUMMARY: End-to-end pipeline latency per run
-- ============================================================================
-- Aggregates task execution times by run (same minute) to show total pipeline
-- latency and per-task breakdown. Key metric for 5-minute latency target.
CREATE OR REPLACE VIEW HARMONIZER_DEMO.ANALYTICS.V_PIPELINE_LATENCY_SUMMARY
COMMENT = 'End-to-end pipeline latency summary per run for latency monitoring'
AS
WITH run_batches AS (
    SELECT 
        DATE_TRUNC('minute', SCHEDULED_TIME) AS RUN_MINUTE,
        MIN(SCHEDULED_TIME) AS RUN_START,
        MAX(COMPLETED_TIME) AS RUN_END,
        SUM(CASE WHEN TASK_NAME = 'CORTEX_SEARCH_TASK' THEN DURATION_SECONDS ELSE 0 END) AS CORTEX_SEARCH_SECONDS,
        SUM(CASE WHEN TASK_NAME = 'COSINE_MATCH_TASK' THEN DURATION_SECONDS ELSE 0 END) AS COSINE_SECONDS,
        SUM(CASE WHEN TASK_NAME = 'EDIT_MATCH_TASK' THEN DURATION_SECONDS ELSE 0 END) AS EDIT_SECONDS,
        SUM(CASE WHEN TASK_NAME = 'JACCARD_MATCH_TASK' THEN DURATION_SECONDS ELSE 0 END) AS JACCARD_SECONDS,
        SUM(CASE WHEN TASK_NAME = 'VECTOR_PREP_TASK' THEN DURATION_SECONDS ELSE 0 END) AS PREP_SECONDS,
        SUM(CASE WHEN TASK_NAME = 'VECTOR_ENSEMBLE_TASK' THEN DURATION_SECONDS ELSE 0 END) AS ENSEMBLE_SECONDS,
        COUNT(DISTINCT QUERY_ID) AS TASK_COUNT,
        COUNT(CASE WHEN STATE = 'FAILED' THEN 1 END) AS FAILED_COUNT
    FROM HARMONIZER_DEMO.ANALYTICS.V_TASK_EXECUTION_METRICS
    WHERE STATE IN ('SUCCEEDED', 'FAILED')
    GROUP BY DATE_TRUNC('minute', SCHEDULED_TIME)
)
SELECT 
    RUN_MINUTE,
    RUN_START,
    RUN_END,
    TIMESTAMPDIFF('second', RUN_START, RUN_END) AS TOTAL_LATENCY_SECONDS,
    CASE 
        WHEN TIMESTAMPDIFF('second', RUN_START, RUN_END) < 60 THEN TIMESTAMPDIFF('second', RUN_START, RUN_END) || 's'
        WHEN TIMESTAMPDIFF('second', RUN_START, RUN_END) < 3600 THEN ROUND(TIMESTAMPDIFF('second', RUN_START, RUN_END) / 60.0, 1) || 'm'
        ELSE ROUND(TIMESTAMPDIFF('second', RUN_START, RUN_END) / 3600.0, 1) || 'h'
    END AS LATENCY_DISPLAY,
    CORTEX_SEARCH_SECONDS,
    COSINE_SECONDS,
    EDIT_SECONDS,
    JACCARD_SECONDS,
    PREP_SECONDS,
    ENSEMBLE_SECONDS,
    TASK_COUNT,
    FAILED_COUNT,
    CASE WHEN FAILED_COUNT = 0 THEN 'SUCCESS' ELSE 'PARTIAL_FAILURE' END AS RUN_STATUS
FROM run_batches
ORDER BY RUN_MINUTE DESC;

-- ============================================================================
-- V_PIPELINE_PHASE_STATUS: Enhanced phase progress with state indicators
-- ============================================================================
-- Provides explicit phase states (WAITING/PROCESSING/COMPLETE), dependency
-- tracking for ensemble phase, and pipeline funnel metrics for waterfall view.
-- Used by the improved Pipeline Progress UI to show clear phase progression.
-- ============================================================================
-- Pure 4-method ensemble pipeline: Cortex Search, Cosine, Edit Distance, Jaccard
CREATE OR REPLACE VIEW HARMONIZER_DEMO.ANALYTICS.V_PIPELINE_PHASE_STATUS
COMMENT = 'Enhanced pipeline phase progress with explicit state indicators (WAITING/PROCESSING/COMPLETE) and dependency tracking for 4-method ensemble'
AS
WITH base_counts AS (
    SELECT
        COUNT(*) AS total_eligible,
        COUNT(CASE WHEN im.CORTEX_SEARCH_SCORE IS NOT NULL THEN 1 END) AS search_done,
        COUNT(CASE WHEN im.COSINE_SCORE IS NOT NULL THEN 1 END) AS cosine_done,
        COUNT(CASE WHEN im.EDIT_DISTANCE_SCORE IS NOT NULL THEN 1 END) AS edit_done,
        COUNT(CASE WHEN im.JACCARD_SCORE IS NOT NULL THEN 1 END) AS jaccard_done,
        COUNT(CASE WHEN im.ENSEMBLE_SCORE IS NOT NULL THEN 1 END) AS ensemble_done
    FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
    JOIN HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri ON ri.ITEM_ID = im.RAW_ITEM_ID
    WHERE ri.INFERRED_CATEGORY IS NOT NULL
      AND UPPER(ri.INFERRED_CATEGORY) NOT IN ('UNKNOWN', 'NULL', 'NONE', '')
),
raw_counts AS (
    SELECT
        COUNT(*) AS total_raw,
        COUNT(CASE WHEN UPPER(COALESCE(INFERRED_CATEGORY, '')) IN ('UNKNOWN', 'NULL', 'NONE', '')
                    OR INFERRED_CATEGORY IS NULL THEN 1 END) AS excluded_category
    FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS
),
unique_desc_counts AS (
    SELECT COUNT(*) AS unique_descriptions
    FROM HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS
),
active_batch AS (
    SELECT BATCH_ID, CREATED_AT, STATUS
    FROM HARMONIZER_DEMO.HARMONIZED.PIPELINE_BATCH_STATE
    WHERE STATUS = 'ACTIVE'
    ORDER BY CREATED_AT DESC
    LIMIT 1
)
SELECT
    ab.BATCH_ID,
    ab.CREATED_AT AS BATCH_STARTED_AT,
    
    -- Funnel counts (waterfall visualization)
    rc.total_raw AS RAW_ITEMS,
    rc.total_raw - rc.excluded_category AS CATEGORIZED_ITEMS,
    rc.excluded_category AS BLOCKED_ITEMS,
    ud.unique_descriptions AS UNIQUE_DESCRIPTIONS,
    bc.total_eligible AS PIPELINE_ITEMS,
    
    -- Phase completion counts (4-method ensemble)
    bc.search_done,
    bc.cosine_done,
    bc.edit_done,
    bc.jaccard_done,
    bc.ensemble_done,
    
    -- Phase percentages (out of pipeline_items for consistent denominator)
    ROUND(bc.search_done::FLOAT / NULLIF(bc.total_eligible, 0) * 100, 1) AS search_pct,
    ROUND(bc.cosine_done::FLOAT / NULLIF(bc.total_eligible, 0) * 100, 1) AS cosine_pct,
    ROUND(bc.edit_done::FLOAT / NULLIF(bc.total_eligible, 0) * 100, 1) AS edit_pct,
    ROUND(bc.jaccard_done::FLOAT / NULLIF(bc.total_eligible, 0) * 100, 1) AS jaccard_pct,
    ROUND(bc.ensemble_done::FLOAT / NULLIF(bc.total_eligible, 0) * 100, 1) AS ensemble_pct,
    
    -- Phase states: WAITING (0%), PROCESSING (0-100%), COMPLETE (100%)
    CASE 
        WHEN bc.search_done = 0 THEN 'WAITING'
        WHEN bc.search_done >= bc.total_eligible THEN 'COMPLETE'
        ELSE 'PROCESSING'
    END AS search_state,
    CASE 
        WHEN bc.cosine_done = 0 THEN 'WAITING'
        WHEN bc.cosine_done >= bc.total_eligible THEN 'COMPLETE'
        ELSE 'PROCESSING'
    END AS cosine_state,
    CASE 
        WHEN bc.edit_done = 0 THEN 'WAITING'
        WHEN bc.edit_done >= bc.total_eligible THEN 'COMPLETE'
        ELSE 'PROCESSING'
    END AS edit_state,
    CASE 
        WHEN bc.jaccard_done = 0 THEN 'WAITING'
        WHEN bc.jaccard_done >= bc.total_eligible THEN 'COMPLETE'
        ELSE 'PROCESSING'
    END AS jaccard_state,
    
    -- Ensemble state depends on all 4 matchers completing
    CASE 
        WHEN bc.search_done < bc.total_eligible 
             OR bc.cosine_done < bc.total_eligible 
             OR bc.edit_done < bc.total_eligible 
             OR bc.jaccard_done < bc.total_eligible THEN 'WAITING'
        WHEN bc.ensemble_done >= bc.total_eligible THEN 'COMPLETE'
        ELSE 'PROCESSING'
    END AS ensemble_state,
    
    -- Dependency info: what is ensemble waiting for?
    CASE 
        WHEN bc.search_done < bc.total_eligible THEN 'Cortex Search (' || (bc.total_eligible - bc.search_done) || ' remaining)'
        WHEN bc.cosine_done < bc.total_eligible THEN 'Cosine (' || (bc.total_eligible - bc.cosine_done) || ' remaining)'
        WHEN bc.edit_done < bc.total_eligible THEN 'Edit Distance (' || (bc.total_eligible - bc.edit_done) || ' remaining)'
        WHEN bc.jaccard_done < bc.total_eligible THEN 'Jaccard (' || (bc.total_eligible - bc.jaccard_done) || ' remaining)'
        ELSE NULL
    END AS ensemble_waiting_for,
    
    -- Overall pipeline state
    CASE 
        WHEN bc.total_eligible = 0 THEN 'EMPTY'
        WHEN bc.ensemble_done >= bc.total_eligible THEN 'COMPLETE'
        WHEN bc.search_done = 0 AND bc.cosine_done = 0 AND bc.edit_done = 0 AND bc.jaccard_done = 0 THEN 'NOT_STARTED'
        ELSE 'PROCESSING'
    END AS pipeline_state,
    
    CURRENT_TIMESTAMP() AS computed_at
FROM base_counts bc
CROSS JOIN raw_counts rc
CROSS JOIN unique_desc_counts ud
LEFT JOIN active_batch ab ON 1=1;

-- ============================================================================
-- V_PIPELINE_ITEM_STATUS: Pipeline stage monitoring for 4-method ensemble
-- Shows item counts at each processing stage for pipeline health monitoring
-- Pure 4-method ensemble: Cortex Search, Cosine, Edit Distance, Jaccard
-- ============================================================================
CREATE OR REPLACE VIEW HARMONIZER_DEMO.HARMONIZED.V_PIPELINE_ITEM_STATUS AS
SELECT 
    CASE 
        WHEN CORTEX_SEARCH_SCORE IS NULL 
          OR COSINE_SCORE IS NULL 
          OR EDIT_DISTANCE_SCORE IS NULL 
          OR JACCARD_SCORE IS NULL 
        THEN '1_SCORES_PENDING'
        WHEN ENSEMBLE_SCORE IS NULL
        THEN '2_ENSEMBLE_READY'
        WHEN ENSEMBLE_SCORE IS NOT NULL AND STATUS NOT IN ('AUTO_ACCEPTED', 'CONFIRMED', 'PENDING_REVIEW', 'REJECTED')
        THEN '3_SCORED_UNROUTED'
        WHEN STATUS IN ('AUTO_ACCEPTED', 'CONFIRMED')
        THEN '4_ROUTED'
        WHEN STATUS = 'PENDING_REVIEW'
        THEN '4_PENDING_REVIEW'
        WHEN STATUS = 'REJECTED'
        THEN '4_REJECTED'
        ELSE '9_UNKNOWN'
    END AS PROCESSING_STAGE,
    COUNT(*) AS ITEM_COUNT,
    MIN(CREATED_AT) AS OLDEST_ITEM,
    MAX(UPDATED_AT) AS NEWEST_UPDATE,
    AVG(DATEDIFF('minute', CREATED_AT, CURRENT_TIMESTAMP())) AS AVG_AGE_MINUTES
FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
GROUP BY 1
ORDER BY 1;

COMMENT ON VIEW HARMONIZER_DEMO.HARMONIZED.V_PIPELINE_ITEM_STATUS IS 
    'Shows item counts at each processing stage for 4-method ensemble pipeline monitoring';
