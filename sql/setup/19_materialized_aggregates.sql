-- ============================================================================
-- sql/setup/19_materialized_aggregates.sql
-- Dynamic Tables for Dashboard Performance Optimization
-- 
-- Created: 2026-03-21
-- Purpose: Replace performance-critical views with Dynamic Tables
-- See: plans/dynamic-tables-clean-migration.plan.md
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- DT_DASHBOARD_KPIS: Main dashboard metrics (1-minute refresh)
-- ============================================================================
CREATE OR REPLACE DYNAMIC TABLE HARMONIZER_DEMO.ANALYTICS.DT_DASHBOARD_KPIS
    TARGET_LAG = '1 minute'
    WAREHOUSE = HARMONIZER_DEMO_WH
    REFRESH_MODE = INCREMENTAL
    COMMENT = 'Dashboard KPIs with 1-minute incremental refresh'
AS
SELECT
    COUNT(*) AS total_items,
    SUM(CASE WHEN effective_status = 'AUTO_ACCEPTED' THEN 1 ELSE 0 END) AS auto_accepted,
    SUM(CASE WHEN effective_status IN ('CONFIRMED', 'USER_CONFIRMED') THEN 1 ELSE 0 END) AS confirmed,
    SUM(CASE WHEN effective_status = 'PENDING_REVIEW' THEN 1 ELSE 0 END) AS pending_review,
    SUM(CASE WHEN effective_status = 'PENDING' THEN 1 ELSE 0 END) AS pending,
    SUM(CASE WHEN effective_status = 'REJECTED' THEN 1 ELSE 0 END) AS rejected
FROM (
    SELECT 
        ri.ITEM_ID,
        CASE 
            WHEN ri.MATCH_STATUS IN ('AUTO_ACCEPTED', 'CONFIRMED', 'REJECTED') THEN ri.MATCH_STATUS
            ELSE COALESCE(im.STATUS, ri.MATCH_STATUS)
        END AS effective_status
    FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
    LEFT JOIN HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im ON ri.ITEM_ID = im.RAW_ITEM_ID
);

-- ============================================================================
-- DT_DASHBOARD_SOURCES: Source system breakdown (5-minute refresh)
-- ============================================================================
CREATE OR REPLACE DYNAMIC TABLE HARMONIZER_DEMO.ANALYTICS.DT_DASHBOARD_SOURCES
    TARGET_LAG = '5 minutes'
    WAREHOUSE = HARMONIZER_DEMO_WH
    REFRESH_MODE = INCREMENTAL
    COMMENT = 'Source system status breakdown with 5-minute incremental refresh'
AS
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
-- DT_DASHBOARD_CATEGORIES: Category match rates (5-minute refresh)
-- Shows ALL taxonomy categories, including those with 0 items
-- ============================================================================
CREATE OR REPLACE DYNAMIC TABLE HARMONIZER_DEMO.ANALYTICS.DT_DASHBOARD_CATEGORIES
    TARGET_LAG = '5 minutes'
    WAREHOUSE = HARMONIZER_DEMO_WH
    REFRESH_MODE = AUTO
    COMMENT = 'Category match rates from taxonomy with 5-minute refresh'
AS
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
-- DT_DASHBOARD_CONFIDENCE_BEST: Best score distribution (5-minute refresh)
-- ============================================================================
CREATE OR REPLACE DYNAMIC TABLE HARMONIZER_DEMO.ANALYTICS.DT_DASHBOARD_CONFIDENCE_BEST
    TARGET_LAG = '5 minutes'
    WAREHOUSE = HARMONIZER_DEMO_WH
    REFRESH_MODE = INCREMENTAL
    COMMENT = 'Best match score distribution with 5-minute incremental refresh'
AS
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
-- DT_DASHBOARD_CONFIDENCE_ENSEMBLE: Ensemble score distribution (5-minute)
-- ============================================================================
CREATE OR REPLACE DYNAMIC TABLE HARMONIZER_DEMO.ANALYTICS.DT_DASHBOARD_CONFIDENCE_ENSEMBLE
    TARGET_LAG = '5 minutes'
    WAREHOUSE = HARMONIZER_DEMO_WH
    REFRESH_MODE = INCREMENTAL
    COMMENT = 'Ensemble score distribution with 5-minute incremental refresh'
AS
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
-- DT_DASHBOARD_SCALE: Scale metrics (5-minute refresh)
-- Requires FULL refresh due to nested scalar subqueries
-- ============================================================================
CREATE OR REPLACE DYNAMIC TABLE HARMONIZER_DEMO.ANALYTICS.DT_DASHBOARD_SCALE
    TARGET_LAG = '5 minutes'
    WAREHOUSE = HARMONIZER_DEMO_WH
    REFRESH_MODE = FULL
    COMMENT = 'Scale projection metrics with 5-minute refresh (FULL: nested subqueries)'
AS
SELECT
    (SELECT COUNT(*) FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS) AS total_items,
    (SELECT COUNT(*) FROM HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS) AS unique_count,
    (SELECT COUNT(*) FROM HARMONIZER_DEMO.HARMONIZED.CONFIRMED_MATCHES) AS fast_path_count;

-- ============================================================================
-- DT_METHOD_ACCURACY: Method accuracy metrics (1-hour refresh)
-- Requires FULL refresh due to complex CTEs
-- Pure 4-method ensemble: Cortex Search, Cosine, Edit Distance, Jaccard
-- ============================================================================
CREATE OR REPLACE DYNAMIC TABLE HARMONIZER_DEMO.ANALYTICS.DT_METHOD_ACCURACY
    TARGET_LAG = '1 hour'
    WAREHOUSE = HARMONIZER_DEMO_WH
    REFRESH_MODE = FULL
    COMMENT = 'Per-method accuracy vs confirmed matches with 1-hour refresh (FULL: complex CTEs)'
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
        SUM(CASE WHEN SEARCH_MATCHED_ID = CONFIRMED_STANDARD_ID THEN 1 ELSE 0 END) AS search_correct,
        SUM(CASE WHEN COSINE_MATCHED_ID = CONFIRMED_STANDARD_ID THEN 1 ELSE 0 END) AS cosine_correct,
        SUM(CASE WHEN EDIT_DISTANCE_MATCHED_ID = CONFIRMED_STANDARD_ID THEN 1 ELSE 0 END) AS edit_correct,
        SUM(CASE WHEN JACCARD_MATCHED_ID = CONFIRMED_STANDARD_ID THEN 1 ELSE 0 END) AS jaccard_correct,
        SUM(CASE WHEN SUGGESTED_STANDARD_ID = CONFIRMED_STANDARD_ID THEN 1 ELSE 0 END) AS ensemble_correct
    FROM confirmed_matches
)
SELECT
    total_confirmed,
    search_correct,
    ROUND(search_correct::FLOAT / NULLIF(total_confirmed, 0) * 100, 2) AS search_accuracy_pct,
    cosine_correct,
    ROUND(cosine_correct::FLOAT / NULLIF(total_confirmed, 0) * 100, 2) AS cosine_accuracy_pct,
    edit_correct,
    ROUND(edit_correct::FLOAT / NULLIF(total_confirmed, 0) * 100, 2) AS edit_accuracy_pct,
    jaccard_correct,
    ROUND(jaccard_correct::FLOAT / NULLIF(total_confirmed, 0) * 100, 2) AS jaccard_accuracy_pct,
    ensemble_correct,
    ROUND(ensemble_correct::FLOAT / NULLIF(total_confirmed, 0) * 100, 2) AS ensemble_accuracy_pct
FROM method_stats;

-- ============================================================================
-- DT_OPTIMIZATION_METRICS: Optimization stats (5-minute refresh)
-- Requires FULL refresh due to complex aggregations
-- Tracks method agreement rates and 4-method ensemble effectiveness
-- ============================================================================
CREATE OR REPLACE DYNAMIC TABLE HARMONIZER_DEMO.ANALYTICS.DT_OPTIMIZATION_METRICS
    TARGET_LAG = '5 minutes'
    WAREHOUSE = HARMONIZER_DEMO_WH
    REFRESH_MODE = FULL
    COMMENT = 'Method agreement rates, cache hits, ensemble metrics with 5-minute refresh'
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
    ROUND(b.agreement_4way::FLOAT / NULLIF(b.total_matches, 0) * 100, 2) AS agreement_4way_pct,
    ROUND(b.avg_ensemble_score, 4) AS avg_ensemble_score,
    ROUND(b.avg_score_4way_agreement, 4) AS avg_score_when_4way_agreement
FROM base_stats b;

-- ============================================================================
-- DT_PIPELINE_PHASE_STATUS: Pipeline progress (1-minute refresh)
-- Requires FULL refresh due to CROSS JOIN + complex CTEs
-- Pure 4-method ensemble pipeline: Cortex Search, Cosine, Edit Distance, Jaccard
-- ============================================================================
CREATE OR REPLACE DYNAMIC TABLE HARMONIZER_DEMO.ANALYTICS.DT_PIPELINE_PHASE_STATUS
    TARGET_LAG = '1 minute'
    WAREHOUSE = HARMONIZER_DEMO_WH
    REFRESH_MODE = FULL
    COMMENT = 'Pipeline phase progress with 1-minute refresh for active monitoring (FULL: CROSS JOIN + CTEs)'
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
    rc.total_raw AS RAW_ITEMS,
    rc.total_raw - rc.excluded_category AS CATEGORIZED_ITEMS,
    rc.excluded_category AS BLOCKED_ITEMS,
    ud.unique_descriptions AS UNIQUE_DESCRIPTIONS,
    bc.total_eligible AS PIPELINE_ITEMS,
    bc.search_done, bc.cosine_done, bc.edit_done, bc.jaccard_done, bc.ensemble_done,
    -- Percentages
    ROUND(bc.search_done::FLOAT / NULLIF(bc.total_eligible, 0) * 100, 1) AS search_pct,
    ROUND(bc.cosine_done::FLOAT / NULLIF(bc.total_eligible, 0) * 100, 1) AS cosine_pct,
    ROUND(bc.edit_done::FLOAT / NULLIF(bc.total_eligible, 0) * 100, 1) AS edit_pct,
    ROUND(bc.jaccard_done::FLOAT / NULLIF(bc.total_eligible, 0) * 100, 1) AS jaccard_pct,
    ROUND(bc.ensemble_done::FLOAT / NULLIF(bc.total_eligible, 0) * 100, 1) AS ensemble_pct,
    -- Phase states (4-method pipeline)
    CASE WHEN bc.search_done = 0 THEN 'WAITING' WHEN bc.search_done >= bc.total_eligible THEN 'COMPLETE' ELSE 'PROCESSING' END AS search_state,
    CASE WHEN bc.cosine_done = 0 THEN 'WAITING' WHEN bc.cosine_done >= bc.total_eligible THEN 'COMPLETE' ELSE 'PROCESSING' END AS cosine_state,
    CASE WHEN bc.edit_done = 0 THEN 'WAITING' WHEN bc.edit_done >= bc.total_eligible THEN 'COMPLETE' ELSE 'PROCESSING' END AS edit_state,
    CASE WHEN bc.jaccard_done = 0 THEN 'WAITING' WHEN bc.jaccard_done >= bc.total_eligible THEN 'COMPLETE' ELSE 'PROCESSING' END AS jaccard_state,
    CASE 
        WHEN bc.search_done < bc.total_eligible OR bc.cosine_done < bc.total_eligible 
             OR bc.edit_done < bc.total_eligible OR bc.jaccard_done < bc.total_eligible THEN 'WAITING'
        WHEN bc.ensemble_done >= bc.total_eligible THEN 'COMPLETE'
        ELSE 'PROCESSING'
    END AS ensemble_state,
    CASE 
        WHEN bc.total_eligible = 0 THEN 'EMPTY'
        WHEN bc.ensemble_done >= bc.total_eligible THEN 'COMPLETE'
        WHEN bc.search_done = 0 AND bc.cosine_done = 0 AND bc.edit_done = 0 AND bc.jaccard_done = 0 THEN 'NOT_STARTED'
        ELSE 'PROCESSING'
    END AS pipeline_state
FROM base_counts bc
CROSS JOIN raw_counts rc
CROSS JOIN unique_desc_counts ud
LEFT JOIN active_batch ab ON 1=1;

-- ============================================================================
-- NOTE: DT_PIPELINE_LATENCY_SUMMARY cannot be a Dynamic Table
-- Reason: It references V_TASK_EXECUTION_METRICS which uses 
-- TABLE(INFORMATION_SCHEMA.TASK_HISTORY()) with non-constant arguments.
-- Snowflake requires TASK_HISTORY arguments to be constants when used as a 
-- Dynamic Table source. Use V_PIPELINE_LATENCY_SUMMARY view instead
-- (defined in 18_api_views.sql).
-- ============================================================================

-- ============================================================================
-- Verification queries (run after creation)
-- ============================================================================
-- SHOW DYNAMIC TABLES IN SCHEMA HARMONIZER_DEMO.ANALYTICS;
-- 
-- SELECT name, scheduling_state, refresh_mode, target_lag_sec 
-- FROM SNOWFLAKE.ACCOUNT_USAGE.DYNAMIC_TABLES 
-- WHERE table_schema = 'ANALYTICS' AND name LIKE 'DT_%';
