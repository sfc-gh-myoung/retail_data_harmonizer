-- ============================================================================
-- sql/setup/14_cost_tracking.sql
-- Retail Data Harmonizer - Cost Tracking and Pipeline Monitoring
--
-- Creates:
--   1. PIPELINE_RUNS table (run history)
--   2. COST_TRACKING table (per-run cost metrics)
--   3. CONFIG entries for cost tracking
--   4. RECORD_PIPELINE_RUN() procedure
--   5. V_COST_COMPARISON view
--
-- Removed (unused):
--   - V_COST_COMPARISON_WEEKLY
--   - V_PIPELINE_HEALTH
--   - V_FEEDBACK_METRICS
--   - V_REVIEWER_PRODUCTIVITY
--   - V_CORTEX_CREDIT_CONSUMPTION
--   - V_PIPELINE_RUN_HISTORY
--
-- Depends on: 02_schema_and_tables.sql, 13_admin_utilities.sql (MATCH_AUDIT_LOG)
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- PIPELINE_RUNS: Track every pipeline execution
-- ============================================================================
CREATE OR REPLACE TABLE HARMONIZER_DEMO.ANALYTICS.PIPELINE_RUNS (
    RUN_ID                  VARCHAR(36)     NOT NULL,
    TRIGGER_TYPE            VARCHAR(20)     NOT NULL,
    STARTED_AT              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    COMPLETED_AT            TIMESTAMP_NTZ,
    STATUS                  VARCHAR(20)     DEFAULT 'RUNNING',
    ITEMS_PROCESSED         INTEGER         DEFAULT 0,
    ITEMS_FAST_PATHED       INTEGER         DEFAULT 0,
    ITEMS_AUTO_ACCEPTED     INTEGER         DEFAULT 0,
    ITEMS_PENDING_REVIEW    INTEGER         DEFAULT 0,
    ITEMS_DEDUPLICATED      INTEGER         DEFAULT 0,
    BATCH_SIZE              INTEGER,
    ERROR_MESSAGE           VARCHAR(2000),
    CONSTRAINT PK_PIPELINE_RUNS PRIMARY KEY (RUN_ID)
);

-- ============================================================================
-- COST_TRACKING: Per-run cost metrics and ROI calculations
-- ============================================================================
CREATE OR REPLACE TABLE HARMONIZER_DEMO.ANALYTICS.COST_TRACKING (
    COST_ID                 VARCHAR(36)     NOT NULL,
    RUN_ID                  VARCHAR(36)     NOT NULL,
    CREDITS_CONSUMED        FLOAT           DEFAULT 0,
    DURATION_SECONDS        INTEGER         DEFAULT 0,
    COST_PER_ITEM           FLOAT,
    ESTIMATED_USD           FLOAT,
    BASELINE_WEEKLY_COST    FLOAT           DEFAULT 16000.00,
    CUMULATIVE_SAVINGS      FLOAT           DEFAULT 0,
    CREATED_AT              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_COST_TRACKING PRIMARY KEY (COST_ID),
    CONSTRAINT FK_COST_RUN FOREIGN KEY (RUN_ID)
        REFERENCES HARMONIZER_DEMO.ANALYTICS.PIPELINE_RUNS(RUN_ID)
);

-- ============================================================================
-- Default configuration for cost tracking
-- ============================================================================
INSERT INTO HARMONIZER_DEMO.ANALYTICS.CONFIG (CONFIG_KEY, CONFIG_VALUE, DESCRIPTION) VALUES
    ('CREDIT_RATE_USD', '3.00', 'Snowflake credit cost in USD for cost estimation'),
    ('BASELINE_WEEKLY_COST', '16000.00', 'Customer current weekly cost for matching ($16K/week)'),
    ('BASELINE_ACCURACY', '0.75', 'Customer current matching accuracy (75%)'),
    ('MANUAL_HOURLY_RATE', '50.00', 'Manual labor hourly rate for ROI calculations'),
    ('MANUAL_MINUTES_PER_ITEM', '3.0', 'Minutes of manual effort per item for baseline comparison');

-- ============================================================================
-- Record pipeline run start/completion with cost tracking
-- P_ACTION: 'START' to begin tracking, 'COMPLETE' to finalize with metrics
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.ANALYTICS.RECORD_PIPELINE_RUN(
    P_RUN_ID VARCHAR,
    P_ACTION VARCHAR,
    P_TRIGGER_TYPE VARCHAR DEFAULT 'MANUAL',
    P_ITEMS_PROCESSED INT DEFAULT 0,
    P_ITEMS_FAST_PATHED INT DEFAULT 0,
    P_ITEMS_AUTO_ACCEPTED INT DEFAULT 0,
    P_ITEMS_PENDING_REVIEW INT DEFAULT 0,
    P_ITEMS_DEDUPLICATED INT DEFAULT 0,
    P_BATCH_SIZE INT DEFAULT 100,
    P_ERROR_MESSAGE VARCHAR DEFAULT NULL
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Records pipeline run metrics and cost tracking data'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_duration INTEGER;
    v_credit_rate FLOAT;
    v_baseline_cost FLOAT;
    v_credits FLOAT;
    v_estimated_usd FLOAT;
    v_cost_per_item FLOAT;
    v_prev_savings FLOAT;
    v_cumulative_savings FLOAT;
    v_status VARCHAR;
BEGIN
    IF (:P_ACTION = 'START') THEN
        -- Record pipeline run start
        INSERT INTO HARMONIZER_DEMO.ANALYTICS.PIPELINE_RUNS (
            RUN_ID, TRIGGER_TYPE, STARTED_AT, STATUS, BATCH_SIZE
        ) VALUES (
            :P_RUN_ID, :P_TRIGGER_TYPE, CURRENT_TIMESTAMP(), 'RUNNING', :P_BATCH_SIZE
        );
        RETURN '{"run_id": "' || :P_RUN_ID || '", "status": "RUNNING"}';

    ELSEIF (:P_ACTION = 'COMPLETE') THEN
        -- Determine final status
        v_status := CASE WHEN :P_ERROR_MESSAGE IS NOT NULL THEN 'FAILED' ELSE 'COMPLETED' END;

        -- Update pipeline run with results
        UPDATE HARMONIZER_DEMO.ANALYTICS.PIPELINE_RUNS
        SET COMPLETED_AT = CURRENT_TIMESTAMP(),
            STATUS = :v_status,
            ITEMS_PROCESSED = :P_ITEMS_PROCESSED,
            ITEMS_FAST_PATHED = :P_ITEMS_FAST_PATHED,
            ITEMS_AUTO_ACCEPTED = :P_ITEMS_AUTO_ACCEPTED,
            ITEMS_PENDING_REVIEW = :P_ITEMS_PENDING_REVIEW,
            ITEMS_DEDUPLICATED = :P_ITEMS_DEDUPLICATED,
            ERROR_MESSAGE = :P_ERROR_MESSAGE
        WHERE RUN_ID = :P_RUN_ID;

        -- Compute duration
        SELECT DATEDIFF('second', STARTED_AT, CURRENT_TIMESTAMP()) INTO :v_duration
        FROM HARMONIZER_DEMO.ANALYTICS.PIPELINE_RUNS
        WHERE RUN_ID = :P_RUN_ID;

        -- Load config values
        SELECT CONFIG_VALUE::FLOAT INTO :v_credit_rate
        FROM HARMONIZER_DEMO.ANALYTICS.CONFIG
        WHERE CONFIG_KEY = 'CREDIT_RATE_USD';

        SELECT CONFIG_VALUE::FLOAT INTO :v_baseline_cost
        FROM HARMONIZER_DEMO.ANALYTICS.CONFIG
        WHERE CONFIG_KEY = 'BASELINE_WEEKLY_COST';

        -- Estimate credits (rough: duration-based since QUERY_HISTORY has ~45min latency)
        v_credits := :v_duration * 0.001;
        v_estimated_usd := :v_credits * :v_credit_rate;
        v_cost_per_item := :v_estimated_usd / NULLIF(:P_ITEMS_PROCESSED, 0);

        -- Get previous cumulative savings
        SELECT COALESCE(MAX(CUMULATIVE_SAVINGS), 0) INTO :v_prev_savings
        FROM HARMONIZER_DEMO.ANALYTICS.COST_TRACKING;

        v_cumulative_savings := :v_prev_savings + (:v_baseline_cost - :v_estimated_usd);

        -- Record cost data
        INSERT INTO HARMONIZER_DEMO.ANALYTICS.COST_TRACKING (
            COST_ID, RUN_ID, CREDITS_CONSUMED, DURATION_SECONDS,
            COST_PER_ITEM, ESTIMATED_USD, BASELINE_WEEKLY_COST,
            CUMULATIVE_SAVINGS, CREATED_AT
        ) SELECT
            UUID_STRING(), :P_RUN_ID, :v_credits, :v_duration,
            :v_cost_per_item, :v_estimated_usd, :v_baseline_cost,
            :v_cumulative_savings, CURRENT_TIMESTAMP();

        RETURN '{"run_id": "' || :P_RUN_ID || '", "status": "' || :v_status ||
               '", "duration_seconds": ' || :v_duration ||
               ', "estimated_usd": ' || :v_estimated_usd ||
               ', "cumulative_savings": ' || :v_cumulative_savings || '}';
    ELSE
        RETURN '{"error": "Invalid action. Use START or COMPLETE."}';
    END IF;
END;
$$;

-- ============================================================================
-- V_COST_COMPARISON: Cumulative cost metrics for dashboard display
-- Returns a single row with overall totals matching template expectations
--
-- Data Sources (Task DAG-based):
--   - Credits: SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY (actual usage)
--   - Task Runs: SNOWFLAKE.ACCOUNT_USAGE.TASK_HISTORY (completed task DAG runs)
--   - Items: HARMONIZER_DEMO.HARMONIZED.PIPELINE_BATCH_STATE (completed batches)
--   - Fast-path: HARMONIZER_DEMO.HARMONIZED.CONFIRMED_MATCHES (cache hits)
-- ============================================================================
CREATE OR REPLACE VIEW HARMONIZER_DEMO.ANALYTICS.V_COST_COMPARISON AS
WITH config AS (
    SELECT
        MAX(CASE WHEN CONFIG_KEY = 'BASELINE_WEEKLY_COST' THEN CONFIG_VALUE::FLOAT END) AS BASELINE_WEEKLY_COST,
        MAX(CASE WHEN CONFIG_KEY = 'CREDIT_RATE_USD' THEN CONFIG_VALUE::FLOAT END) AS CREDIT_RATE_USD,
        COALESCE(MAX(CASE WHEN CONFIG_KEY = 'MANUAL_HOURLY_RATE' THEN CONFIG_VALUE::FLOAT END), 50.00) AS MANUAL_HOURLY_RATE,
        COALESCE(MAX(CASE WHEN CONFIG_KEY = 'MANUAL_MINUTES_PER_ITEM' THEN CONFIG_VALUE::FLOAT END), 3.0) AS MANUAL_MINUTES_PER_ITEM
    FROM HARMONIZER_DEMO.ANALYTICS.CONFIG
),
-- Get earliest batch creation to scope warehouse costs
batch_start AS (
    SELECT MIN(CREATED_AT) AS FIRST_BATCH_AT
    FROM HARMONIZER_DEMO.HARMONIZED.PIPELINE_BATCH_STATE
    WHERE STATUS = 'COMPLETED'
),
-- Actual warehouse credits from Snowflake metering (scoped to project warehouse and time range)
warehouse_costs AS (
    SELECT 
        COALESCE(SUM(wmh.CREDITS_USED), 0) AS TOTAL_CREDITS
    FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY wmh
    CROSS JOIN batch_start bs
    WHERE wmh.WAREHOUSE_NAME = 'HARMONIZER_DEMO_WH'
      AND wmh.START_TIME >= COALESCE(bs.FIRST_BATCH_AT, DATEADD('day', -30, CURRENT_TIMESTAMP()))
),
-- Count distinct Task DAG runs (using GRAPH_RUN_GROUP_ID for complete DAG executions)
task_runs AS (
    SELECT 
        COUNT(DISTINCT th.GRAPH_RUN_GROUP_ID) AS TOTAL_RUNS
    FROM SNOWFLAKE.ACCOUNT_USAGE.TASK_HISTORY th
    CROSS JOIN batch_start bs
    WHERE th.DATABASE_NAME = 'HARMONIZER_DEMO'
      AND th.STATE = 'SUCCEEDED'
      AND th.NAME IN ('DEDUP_FASTPATH_TASK', 'VECTOR_PREP_TASK', 'CORTEX_SEARCH_TASK', 
                      'COSINE_MATCH_TASK', 'EDIT_MATCH_TASK', 'VECTOR_ENSEMBLE_TASK')
      AND th.SCHEDULED_TIME >= COALESCE(bs.FIRST_BATCH_AT, DATEADD('day', -30, CURRENT_TIMESTAMP()))
),
-- Items processed from completed batches
batch_items AS (
    SELECT 
        COALESCE(SUM(ITEM_COUNT), 0) AS TOTAL_ITEMS,
        COUNT(*) AS BATCH_COUNT
    FROM HARMONIZER_DEMO.HARMONIZED.PIPELINE_BATCH_STATE
    WHERE STATUS = 'COMPLETED'
),
-- Fast-path items from confirmed matches cache
fast_path_items AS (
    SELECT COUNT(*) AS FAST_PATH_COUNT
    FROM HARMONIZER_DEMO.HARMONIZED.CONFIRMED_MATCHES
),
-- Combine all metrics
run_totals AS (
    SELECT
        tr.TOTAL_RUNS,
        bi.TOTAL_ITEMS,
        bi.TOTAL_ITEMS - fp.FAST_PATH_COUNT AS AI_MATCHED_ITEMS,
        fp.FAST_PATH_COUNT AS FAST_PATH_ITEMS,
        wc.TOTAL_CREDITS,
        cfg.CREDIT_RATE_USD,
        ROUND(wc.TOTAL_CREDITS * cfg.CREDIT_RATE_USD, 2) AS TOTAL_ESTIMATED_USD,
        cfg.MANUAL_HOURLY_RATE,
        cfg.MANUAL_MINUTES_PER_ITEM,
        ROUND(bi.TOTAL_ITEMS * (cfg.MANUAL_MINUTES_PER_ITEM / 60.0) * cfg.MANUAL_HOURLY_RATE, 2) AS TOTAL_BASELINE_COST
    FROM task_runs tr
    CROSS JOIN batch_items bi
    CROSS JOIN fast_path_items fp
    CROSS JOIN warehouse_costs wc
    CROSS JOIN config cfg
)
SELECT
    -- Core metrics
    rt.TOTAL_RUNS,
    rt.TOTAL_ITEMS,
    rt.AI_MATCHED_ITEMS,
    rt.FAST_PATH_ITEMS,
    
    -- Cost metrics (names match template expectations)
    ROUND(rt.TOTAL_CREDITS, 4)                               AS TOTAL_CREDITS_USED,
    ROUND(rt.TOTAL_ESTIMATED_USD, 2)                         AS TOTAL_ESTIMATED_USD,
    
    -- Cost per item: total USD spent / total items processed
    ROUND(rt.TOTAL_ESTIMATED_USD / NULLIF(rt.TOTAL_ITEMS, 0), 4) AS COST_PER_ITEM,
    
    -- Hours saved: (baseline cost - actual cost) / hourly rate
    -- Represents how many manual labor hours were avoided
    ROUND((rt.TOTAL_BASELINE_COST - rt.TOTAL_ESTIMATED_USD) / rt.MANUAL_HOURLY_RATE, 1) AS HOURS_SAVED,
    
    -- ROI percentage: (savings / investment) * 100
    -- Shows return on the Snowflake compute investment
    ROUND(
        CASE 
            WHEN rt.TOTAL_ESTIMATED_USD > 0 
            THEN ((rt.TOTAL_BASELINE_COST - rt.TOTAL_ESTIMATED_USD) / rt.TOTAL_ESTIMATED_USD) * 100
            ELSE 0
        END, 0
    )                                                        AS ROI_PERCENTAGE,
    
    -- Additional useful metrics
    ROUND(rt.TOTAL_BASELINE_COST, 2)                         AS BASELINE_WEEKLY_COST,
    ROUND(rt.TOTAL_BASELINE_COST - rt.TOTAL_ESTIMATED_USD, 2) AS CUMULATIVE_SAVINGS,
    ROUND(rt.FAST_PATH_ITEMS::FLOAT / NULLIF(rt.TOTAL_ITEMS, 0), 4) AS FAST_PATH_RATIO,
    
    -- Config values for display in UI
    rt.CREDIT_RATE_USD,
    rt.MANUAL_HOURLY_RATE,
    rt.MANUAL_MINUTES_PER_ITEM
FROM run_totals rt;
