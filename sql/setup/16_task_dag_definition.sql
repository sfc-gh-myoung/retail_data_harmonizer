-- ============================================================================
-- sql/setup/16_task_dag_definition.sql
-- Retail Data Harmonizer - Parallel Vector Matching Task DAG
--
-- Creates:
--   2. Method-Level Parallel Task DAG (TRUE parallel vector matching):
--      - DEDUP_FASTPATH_TASK (root) - dedup + fast-path resolution
--      - CLASSIFY_UNIQUE_TASK (child) - category+subcategory classification
--      - VECTOR_PREP_TASK (child) - consumes stream, generates embeddings
--      - CORTEX_SEARCH_TASK (sibling) - runs in parallel
--      - COSINE_MATCH_TASK (sibling) - runs in parallel
--      - EDIT_MATCH_TASK (sibling) - runs in parallel
--      - JACCARD_MATCH_TASK (sibling) - runs in parallel
--      - STAGING_MERGE_TASK (finalizer) - merges staging tables
--   3. DECOUPLED PROCESSING TASKS (independent, scheduled):
--      - ENSEMBLE_SCORING_TASK - weighted ensemble scoring (4-method pure ensemble)
--      - ITEM_ROUTER_TASK - route to HARMONIZED_ITEMS or REVIEW_QUEUE
--   4. Task Management Procedures (ENABLE/DISABLE/TRIGGER/GET_STATUS)
--
-- Architecture:
--   Stream (RAW_ITEMS_STREAM) -> DEDUP_FASTPATH_TASK (root)
--                             -> CLASSIFY_UNIQUE_TASK (category + subcategory)
--                             -> VECTOR_PREP_TASK (embeddings + batch staging)
--                             -> [4 parallel sibling tasks write to staging tables]
--                             -> STAGING_MERGE_TASK (finalizer: merge staging tables)
--                             -> ENSEMBLE_SCORING_TASK (scheduled, computes ENSEMBLE_SCORE)
--                             -> ITEM_ROUTER_TASK (scheduled, routes to final status)
--
-- Task Coordination:
--   Uses TASK_COORDINATION table (message queue pattern) instead of
--   SYSTEM$SET_RETURN_VALUE / SYSTEM$GET_PREDECESSOR_RETURN_VALUE.
--   Each task registers start/completion in the coordination table.
--   Child tasks check parent status by querying the table.
--
-- NOTE: All pipeline execution uses the Task DAG. There is no synchronous mode.
--       Use EXECUTE TASK HARMONIZER_DEMO.HARMONIZED.DEDUP_FASTPATH_TASK to start immediate execution.
--
-- Depends on: 11_matching/, 12_parallel_matchers.sql, 15_task_coordination.sql
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- Config entries for agentic workflow
-- (MERGE for idempotent re-run — matches pattern in 02_schema_and_tables.sql)
-- ============================================================================
MERGE INTO HARMONIZER_DEMO.ANALYTICS.CONFIG AS target
USING (
    SELECT * FROM VALUES
        ('AGENTIC_ENABLED',              'false',                            'Toggle agentic daily pipeline (true/false)'),
        ('AGENTIC_SCHEDULE',             '0 6 * * *',                       'CRON schedule for agentic runs (default: 6 AM ET daily)'),
        ('NOTIFICATIONS_ENABLED',        'false',                            'Enable email notifications after pipeline runs (true/false)'),
        ('NOTIFICATION_THRESHOLD',       '50',                               'Minimum PENDING_REVIEW items to trigger notification'),
        ('NOTIFICATION_RECIPIENTS',      '',                                 'Comma-separated email addresses for notifications'),
        ('NOTIFICATION_INTEGRATION',     'HARMONIZER_PRICING_NOTIFICATION',  'Email integration name for SYSTEM$SEND_EMAIL')
    AS t(CONFIG_KEY, CONFIG_VALUE, DESCRIPTION)
) AS source
ON target.CONFIG_KEY = source.CONFIG_KEY
WHEN NOT MATCHED THEN
    INSERT (CONFIG_KEY, CONFIG_VALUE, DESCRIPTION)
    VALUES (source.CONFIG_KEY, source.CONFIG_VALUE, source.DESCRIPTION)
WHEN MATCHED THEN
    UPDATE SET
        CONFIG_VALUE = source.CONFIG_VALUE,
        DESCRIPTION  = source.DESCRIPTION,
        UPDATED_AT   = CURRENT_TIMESTAMP();
-- ============================================================================
-- METHOD-LEVEL PARALLEL TASK DAG
-- Architecture: True parallel execution of vector matching methods
--
-- Flow:
--   DEDUP_FASTPATH_TASK (root, scheduled, stream-triggered)
--        |
--        v (AFTER clause)
--   CLASSIFY_UNIQUE_TASK (category + subcategory via AI_CLASSIFY)
--        |
--        v (AFTER clause)
--   VECTOR_PREP_TASK (embeddings only)
--        |
--        v (AFTER clause - triggers 4 sibling tasks in parallel)
--   +----+----+----+----+
--   |    |    |    |    |
--   v    v    v    v    |
--  CORTEX COSINE EDIT JACCARD
--  SEARCH MATCH  MATCH MATCH
--  TASK   TASK   TASK  TASK
--        |
--        v (FINALIZE clause - runs after ALL siblings complete)
--   STAGING_MERGE_TASK
--   (merges staging tables to ITEM_MATCHES)
--
--   [DECOUPLED SCHEDULED TASKS - run independently]
--   ENSEMBLE_SCORING_TASK -> ITEM_ROUTER_TASK
--
-- Key Features:
--   - Stream-based: RAW_ITEMS_STREAM provides exactly-once processing
--   - No table locking: Each method writes to its own TRANSIENT staging table
--   - Decoupled processing: LLM, scoring, routing run on independent schedules
--   - Dedup + Fast-path run FIRST for cost optimization
-- ============================================================================

-- ============================================================================
-- DEDUP_FASTPATH_BATCH: Wrapper procedure for dedup and fast-path resolution
-- Called by DEDUP_FASTPATH_TASK before vector matching begins
-- Uses TASK_COORDINATION table for task-to-task communication (replaces SYSTEM$SET_RETURN_VALUE)
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.DEDUP_FASTPATH_BATCH()
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Runs dedup (96x cost reduction) and fast-path (zero-cost confirmed matches) before vector matching. Uses coordination table for task communication.'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_run_id VARCHAR;
    v_dedup_result VARCHAR;
    v_fastpath_result VARCHAR;
    v_pending_before INTEGER;
    v_pending_after INTEGER;
    v_staging_count INTEGER;
    v_has_stream_data VARCHAR;
BEGIN
    -- Generate new run_id for this DAG execution
    v_run_id := UUID_STRING();
    
    -- Register task start in coordination table
    CALL HARMONIZER_DEMO.HARMONIZED.REGISTER_TASK_START(:v_run_id, 'DEDUP_FASTPATH');
    
    -- Count pending items before optimization
    SELECT COUNT(*) INTO :v_pending_before
    FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS
    WHERE MATCH_STATUS = 'PENDING';
    
    -- Early exit if no work to do (handles case where task runs on schedule with nothing pending)
    IF (:v_pending_before = 0) THEN
        -- Check STREAM_STAGING for leftover items from previous large batches
        SELECT COUNT(*) INTO :v_staging_count
        FROM HARMONIZER_DEMO.HARMONIZED.STREAM_STAGING;
        
        IF (:v_staging_count = 0) THEN
            -- Check stream for new data
            SELECT SYSTEM$STREAM_HAS_DATA('HARMONIZER_DEMO.HARMONIZED.RAW_ITEMS_STREAM') INTO :v_has_stream_data;
            IF (:v_has_stream_data = 'false') THEN
                -- Update coordination table with SKIPPED status
                CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
                    :v_run_id, 
                    'DEDUP_FASTPATH', 
                    'SKIPPED',
                    OBJECT_CONSTRUCT('reason', 'No pending items, no staged items, no stream data')
                );
                RETURN OBJECT_CONSTRUCT(
                    'run_id', :v_run_id,
                    'status', 'skipped',
                    'reason', 'No pending items, no staged items, no stream data'
                );
            END IF;
        END IF;
    END IF;
    
    -- Step 0: De-duplication (96x cost reduction)
    -- Normalizes descriptions and groups duplicates
    CALL HARMONIZER_DEMO.HARMONIZED.DEDUPLICATE_RAW_ITEMS(:v_run_id);
    v_dedup_result := 'completed';
    
    -- Step 0.5: Fast-path resolution (zero AI cost)
    -- Instantly resolves items matching confirmed mappings
    CALL HARMONIZER_DEMO.HARMONIZED.RESOLVE_FAST_PATH(:v_run_id);
    v_fastpath_result := 'completed';
    
    -- Count pending items after optimization
    SELECT COUNT(*) INTO :v_pending_after
    FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS
    WHERE MATCH_STATUS = 'PENDING';
    
    -- Update coordination table with COMPLETED status and payload
    CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
        :v_run_id, 
        'DEDUP_FASTPATH', 
        'COMPLETED',
        OBJECT_CONSTRUCT(
            'pending_before', :v_pending_before,
            'pending_after', :v_pending_after,
            'resolved_by_fastpath', :v_pending_before - :v_pending_after
        )
    );
    
    RETURN OBJECT_CONSTRUCT(
        'run_id', :v_run_id,
        'status', 'complete',
        'pending_before', :v_pending_before,
        'pending_after', :v_pending_after,
        'resolved_by_fastpath', :v_pending_before - :v_pending_after,
        'dedup', :v_dedup_result,
        'fastpath', :v_fastpath_result
    );
EXCEPTION
    WHEN OTHER THEN
        LET err_msg VARCHAR := SQLERRM;
        -- Update coordination table with FAILED status
        CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
            :v_run_id, 
            'DEDUP_FASTPATH', 
            'FAILED',
            OBJECT_CONSTRUCT('error', :err_msg)
        );
        RETURN OBJECT_CONSTRUCT(
            'run_id', :v_run_id,
            'status', 'error',
            'error', :err_msg
        );
END;
$$;

-- ============================================================================
-- DEDUP_FASTPATH_TASK: ROOT task - runs dedup and fast-path first
-- Runs on schedule; procedure handles empty states gracefully.
-- Writes status to TASK_COORDINATION table for child tasks to read.
-- ============================================================================
CREATE OR REPLACE TASK HARMONIZER_DEMO.HARMONIZED.DEDUP_FASTPATH_TASK
    WAREHOUSE = HARMONIZER_DEMO_WH
    SCHEDULE = 'USING CRON * * * * * America/New_York'
    COMMENT = 'Root task: dedup + fast-path. Writes status to TASK_COORDINATION table. Runs every minute for faster pipeline response.'
AS
    CALL HARMONIZER_DEMO.HARMONIZED.DEDUP_FASTPATH_BATCH();

-- ============================================================================
-- CLASSIFY_UNIQUE_TASK: Classifies unique descriptions into category + subcategory
-- Runs AFTER dedup/fast-path (which may have resolved some items via fast-path).
-- Category and subcategory results are fanned out to all raw items via
-- RAW_TO_UNIQUE_MAP so every downstream matcher has access to both fields.
-- Checks TASK_COORDINATION table for parent status (replaces WHEN clause).
-- ============================================================================
CREATE OR REPLACE TASK HARMONIZER_DEMO.HARMONIZED.CLASSIFY_UNIQUE_TASK
    WAREHOUSE = HARMONIZER_DEMO_WH
    COMMENT = 'Child task: classifies unique descriptions into category+subcategory. Checks coordination table for parent status.'
    AFTER HARMONIZER_DEMO.HARMONIZED.DEDUP_FASTPATH_TASK
AS
    CALL HARMONIZER_DEMO.HARMONIZED.CLASSIFY_UNIQUE_DESCRIPTIONS(500);

-- ============================================================================
-- VECTOR_PREP_TASK: Now runs AFTER the classification step
-- Consumes stream, generates embeddings for remaining items.
-- Classification is already done by CLASSIFY_UNIQUE_TASK; VECTOR_PREP only
-- handles stream ingestion, batch staging, and embedding generation.
-- Checks TASK_COORDINATION table for parent status (replaces WHEN clause).
-- ============================================================================
CREATE OR REPLACE TASK HARMONIZER_DEMO.HARMONIZED.VECTOR_PREP_TASK
    WAREHOUSE = HARMONIZER_DEMO_WH
    COMMENT = 'Child task: consumes stream, generates embeddings. Checks coordination table for parent status.'
    AFTER HARMONIZER_DEMO.HARMONIZED.CLASSIFY_UNIQUE_TASK
AS
    CALL HARMONIZER_DEMO.HARMONIZED.VECTOR_PREP_BATCH(500);

-- ============================================================================
-- CORTEX_SEARCH_TASK: Sibling task - Cortex Search matching
-- Runs in TRUE PARALLEL with COSINE_MATCH_TASK and EDIT_MATCH_TASK
-- Writes to CORTEX_SEARCH_STAGING table (no locking conflicts)
-- ============================================================================
CREATE OR REPLACE TASK HARMONIZER_DEMO.HARMONIZED.CORTEX_SEARCH_TASK
    WAREHOUSE = HARMONIZER_DEMO_WH
    COMMENT = 'Sibling task: Cortex Search matching (runs in parallel)'
    AFTER HARMONIZER_DEMO.HARMONIZED.VECTOR_PREP_TASK
AS
    CALL HARMONIZER_DEMO.HARMONIZED.MATCH_CORTEX_SEARCH_BATCH(
        (SELECT BATCH_ID FROM HARMONIZER_DEMO.HARMONIZED.PIPELINE_BATCH_STATE WHERE STATUS = 'ACTIVE' LIMIT 1)
    );

-- ============================================================================
-- COSINE_MATCH_TASK: Sibling task - Cosine similarity matching
-- Runs in TRUE PARALLEL with CORTEX_SEARCH_TASK and EDIT_MATCH_TASK
-- Writes to COSINE_MATCH_STAGING table (no locking conflicts)
-- ============================================================================
CREATE OR REPLACE TASK HARMONIZER_DEMO.HARMONIZED.COSINE_MATCH_TASK
    WAREHOUSE = HARMONIZER_DEMO_WH
    COMMENT = 'Sibling task: Cosine similarity matching (runs in parallel)'
    AFTER HARMONIZER_DEMO.HARMONIZED.VECTOR_PREP_TASK
AS
    CALL HARMONIZER_DEMO.HARMONIZED.MATCH_COSINE_BATCH(
        (SELECT BATCH_ID FROM HARMONIZER_DEMO.HARMONIZED.PIPELINE_BATCH_STATE WHERE STATUS = 'ACTIVE' LIMIT 1)
    );

-- ============================================================================
-- EDIT_MATCH_TASK: Sibling task - Edit distance matching
-- Runs in TRUE PARALLEL with CORTEX_SEARCH_TASK, COSINE_MATCH_TASK, JACCARD_MATCH_TASK
-- Writes to EDIT_MATCH_STAGING table (no locking conflicts)
-- ============================================================================
CREATE OR REPLACE TASK HARMONIZER_DEMO.HARMONIZED.EDIT_MATCH_TASK
    WAREHOUSE = HARMONIZER_DEMO_WH
    COMMENT = 'Sibling task: Edit distance matching (runs in parallel)'
    AFTER HARMONIZER_DEMO.HARMONIZED.VECTOR_PREP_TASK
AS
    CALL HARMONIZER_DEMO.HARMONIZED.MATCH_EDIT_BATCH(
        (SELECT BATCH_ID FROM HARMONIZER_DEMO.HARMONIZED.PIPELINE_BATCH_STATE WHERE STATUS = 'ACTIVE' LIMIT 1)
    );

-- ============================================================================
-- JACCARD_MATCH_TASK: Sibling task - Jaccard token similarity matching
-- Runs in TRUE PARALLEL with CORTEX_SEARCH_TASK, COSINE_MATCH_TASK, EDIT_MATCH_TASK
-- Writes to JACCARD_MATCH_STAGING table (no locking conflicts)
-- ============================================================================
CREATE OR REPLACE TASK HARMONIZER_DEMO.HARMONIZED.JACCARD_MATCH_TASK
    WAREHOUSE = HARMONIZER_DEMO_WH
    COMMENT = 'Sibling task: Jaccard token similarity matching (runs in parallel)'
    AFTER HARMONIZER_DEMO.HARMONIZED.VECTOR_PREP_TASK
AS
    CALL HARMONIZER_DEMO.HARMONIZED.MATCH_JACCARD_BATCH(
        (SELECT BATCH_ID FROM HARMONIZER_DEMO.HARMONIZED.PIPELINE_BATCH_STATE WHERE STATUS = 'ACTIVE' LIMIT 1)
    );

-- ============================================================================
-- DECOUPLED ENSEMBLE PIPELINE (Replaces monolithic VECTOR_ENSEMBLE_TASK)
--
-- Three independent tasks with scheduled execution:
--   1. STAGING_MERGE_TASK - FINALIZE from parallel matchers, merge to ITEM_MATCHES
--   2. ENSEMBLE_SCORING_TASK - Compute weighted ensemble scores (pure 4-method)
--   3. ITEM_ROUTER_TASK - Route to HARMONIZED_ITEMS or REVIEW_QUEUE
--
-- Benefits:
--   - Each task does exactly one thing (easier to troubleshoot/optimize)
--   - Self-healing: procedures check for work internally and exit early if none
--   - No orphan states: clear progression visible in ITEM_MATCHES columns
--   - Independent batch limits per responsibility
-- ============================================================================

-- ============================================================================
-- Task 1: STAGING_MERGE_TASK (FINALIZE from parallel matchers)
-- Triggers after all 4 vector matching tasks complete
-- ============================================================================
-- Drop any existing finalizer first (Snowflake only allows one finalizer per root task)
DROP TASK IF EXISTS HARMONIZER_DEMO.HARMONIZED.STAGING_MERGE_TASK;

CREATE OR REPLACE TASK HARMONIZER_DEMO.HARMONIZED.STAGING_MERGE_TASK
    WAREHOUSE = HARMONIZER_DEMO_WH
    COMMENT = 'Decoupled Pipeline: Merges staging tables to ITEM_MATCHES. FINALIZE task for parallel matchers.'
    FINALIZE = 'HARMONIZER_DEMO.HARMONIZED.DEDUP_FASTPATH_TASK'
AS
    CALL HARMONIZER_DEMO.HARMONIZED.MERGE_STAGING_TABLES();

-- ============================================================================
-- Task 2: ENSEMBLE_SCORING_TASK (Scheduled with internal work check)
-- Runs on schedule, checks for items ready for scoring internally
-- ============================================================================
CREATE OR REPLACE TASK HARMONIZER_DEMO.HARMONIZED.ENSEMBLE_SCORING_TASK
    WAREHOUSE = HARMONIZER_DEMO_WH
    SCHEDULE = '1 MINUTE'
    ALLOW_OVERLAPPING_EXECUTION = FALSE
    COMMENT = 'Decoupled Pipeline: Compute weighted ensemble scores. Checks for work internally.'
AS
    CALL HARMONIZER_DEMO.HARMONIZED.COMPUTE_ENSEMBLE_SCORES_ONLY();

-- ============================================================================
-- Task 3: ITEM_ROUTER_TASK (Scheduled with internal work check)
-- Triggers when items have ensemble scores but aren't routed yet
-- ============================================================================
CREATE OR REPLACE TASK HARMONIZER_DEMO.HARMONIZED.ITEM_ROUTER_TASK
    WAREHOUSE = HARMONIZER_DEMO_WH
    SCHEDULE = '1 MINUTE'
    ALLOW_OVERLAPPING_EXECUTION = FALSE
    COMMENT = 'Decoupled Pipeline: Routes scored items to final destinations. Checks for work internally.'
AS
    CALL HARMONIZER_DEMO.HARMONIZED.ROUTE_MATCHED_ITEMS();

-- All tasks created SUSPENDED by default
-- Decoupled pipeline tasks
ALTER TASK HARMONIZER_DEMO.HARMONIZED.STAGING_MERGE_TASK SUSPEND;
ALTER TASK HARMONIZER_DEMO.HARMONIZED.ENSEMBLE_SCORING_TASK SUSPEND;
ALTER TASK HARMONIZER_DEMO.HARMONIZED.ITEM_ROUTER_TASK SUSPEND;
-- Vector matching tasks
ALTER TASK HARMONIZER_DEMO.HARMONIZED.CORTEX_SEARCH_TASK SUSPEND;
ALTER TASK HARMONIZER_DEMO.HARMONIZED.COSINE_MATCH_TASK SUSPEND;
ALTER TASK HARMONIZER_DEMO.HARMONIZED.EDIT_MATCH_TASK SUSPEND;
ALTER TASK HARMONIZER_DEMO.HARMONIZED.JACCARD_MATCH_TASK SUSPEND;
ALTER TASK HARMONIZER_DEMO.HARMONIZED.VECTOR_PREP_TASK SUSPEND;
ALTER TASK HARMONIZER_DEMO.HARMONIZED.CLASSIFY_UNIQUE_TASK SUSPEND;
ALTER TASK HARMONIZER_DEMO.HARMONIZED.DEDUP_FASTPATH_TASK SUSPEND;

-- ============================================================================
-- To enable the DECOUPLED pipeline (recommended), run these commands:
--   -- Decoupled tasks (self-triggering via schedule)
--   ALTER TASK HARMONIZER_DEMO.HARMONIZED.STAGING_MERGE_TASK RESUME;
--   ALTER TASK HARMONIZER_DEMO.HARMONIZED.ENSEMBLE_SCORING_TASK RESUME;
--   ALTER TASK HARMONIZER_DEMO.HARMONIZED.ITEM_ROUTER_TASK RESUME;
--   -- Vector matching tasks
--   ALTER TASK HARMONIZER_DEMO.HARMONIZED.CORTEX_SEARCH_TASK RESUME;
--   ALTER TASK HARMONIZER_DEMO.HARMONIZED.COSINE_MATCH_TASK RESUME;
--   ALTER TASK HARMONIZER_DEMO.HARMONIZED.EDIT_MATCH_TASK RESUME;
--   ALTER TASK HARMONIZER_DEMO.HARMONIZED.JACCARD_MATCH_TASK RESUME;
--   ALTER TASK HARMONIZER_DEMO.HARMONIZED.VECTOR_PREP_TASK RESUME;
--   ALTER TASK HARMONIZER_DEMO.HARMONIZED.CLASSIFY_UNIQUE_TASK RESUME;
--   ALTER TASK HARMONIZER_DEMO.HARMONIZED.DEDUP_FASTPATH_TASK RESUME;
-- Or use: CALL HARMONIZER_DEMO.HARMONIZED.ENABLE_PARALLEL_PIPELINE_TASKS();
-- ============================================================================

-- ============================================================================
-- TASK MANAGEMENT PROCEDURES
-- ============================================================================
-- These wrapper procedures provide several benefits over direct ALTER TASK:
--
-- 1. DEPENDENCY ORDER: Snowflake requires tasks to be enabled/disabled in a
--    specific order. Enable: leaf tasks first, root last. Disable: root first,
--    leaf tasks last. These procedures encode the correct order for all 8 tasks.
--
-- 2. ATOMIC OPERATIONS: One procedure call handles all 8 tasks instead of 8
--    separate ALTER TASK statements that must be executed in correct order.
--
-- 3. ERROR HANDLING: Procedures catch exceptions and return structured JSON
--    errors instead of failing with raw SQL errors.
--
-- 4. API INTEGRATION: JSON return format ({"status": "enabled", "tasks": [...]})
--    is designed for the FastAPI dashboard to parse and display.
--
-- 5. PERMISSION ENCAPSULATION: EXECUTE AS OWNER allows users with USAGE on
--    the procedure to manage tasks without needing OPERATE privilege on each task.
--
-- You CAN call ALTER TASK directly if you prefer, but you must follow the
-- correct ordering. See comments on each procedure for the required sequence.
-- ============================================================================

-- ============================================================================
-- ENABLE_PARALLEL_PIPELINE_TASKS: Resume all parallel Task DAG tasks
-- Order: leaf tasks first (STAGING_MERGE + decoupled tasks), then siblings, then root (DEDUP_FASTPATH)
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.ENABLE_PARALLEL_PIPELINE_TASKS()
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Resumes all parallel Task DAG tasks in correct dependency order (decoupled architecture)'
EXECUTE AS OWNER
AS
$$
BEGIN
    -- Enable FINALIZE task (STAGING_MERGE replaces legacy VECTOR_ENSEMBLE)
    ALTER TASK HARMONIZER_DEMO.HARMONIZED.STAGING_MERGE_TASK RESUME;
    
    -- Enable self-triggering decoupled tasks (pure ensemble scoring)
    ALTER TASK HARMONIZER_DEMO.HARMONIZED.ENSEMBLE_SCORING_TASK RESUME;
    ALTER TASK HARMONIZER_DEMO.HARMONIZED.ITEM_ROUTER_TASK RESUME;
    
    -- Enable maintenance tasks (independent, scheduled)
    ALTER TASK HARMONIZER_DEMO.HARMONIZED.CLEANUP_COORDINATION_TASK RESUME;
    ALTER TASK HARMONIZER_DEMO.ANALYTICS.REFRESH_TASK_HISTORY_CACHE RESUME;
    ALTER TASK HARMONIZER_DEMO.ANALYTICS.CLEANUP_TASK_EXECUTION_CACHE RESUME;
    ALTER TASK HARMONIZER_DEMO.ANALYTICS.REFRESH_TASK_STATE_CACHE RESUME;
    
    -- Enable sibling tasks (depend on prep task)
    ALTER TASK HARMONIZER_DEMO.HARMONIZED.CORTEX_SEARCH_TASK RESUME;
    ALTER TASK HARMONIZER_DEMO.HARMONIZED.COSINE_MATCH_TASK RESUME;
    ALTER TASK HARMONIZER_DEMO.HARMONIZED.EDIT_MATCH_TASK RESUME;
    ALTER TASK HARMONIZER_DEMO.HARMONIZED.JACCARD_MATCH_TASK RESUME;
    
    -- Enable vector prep task (depends on classify step)
    ALTER TASK HARMONIZER_DEMO.HARMONIZED.VECTOR_PREP_TASK RESUME;

    -- Enable classify task (depends on dedup/fastpath)
    ALTER TASK HARMONIZER_DEMO.HARMONIZED.CLASSIFY_UNIQUE_TASK RESUME;
    
    -- Enable root task last (triggers the DAG on schedule)
    ALTER TASK HARMONIZER_DEMO.HARMONIZED.DEDUP_FASTPATH_TASK RESUME;
    
    RETURN '{"status": "enabled", "tasks": ["DEDUP_FASTPATH_TASK", "CLASSIFY_UNIQUE_TASK", "VECTOR_PREP_TASK", "CORTEX_SEARCH_TASK", "COSINE_MATCH_TASK", "EDIT_MATCH_TASK", "JACCARD_MATCH_TASK", "STAGING_MERGE_TASK", "ENSEMBLE_SCORING_TASK", "ITEM_ROUTER_TASK", "CLEANUP_COORDINATION_TASK", "REFRESH_TASK_HISTORY_CACHE", "CLEANUP_TASK_EXECUTION_CACHE", "REFRESH_TASK_STATE_CACHE"]}';
EXCEPTION
    WHEN OTHER THEN
        LET err_code INTEGER := SQLCODE;
        LET err_msg VARCHAR := SQLERRM;
        LET enable_err VARCHAR := 'Error: ' || :err_code || ' - ' || :err_msg;
        RETURN '{"status": "error", "message": "' || :enable_err || '"}';
END;
$$;

-- ============================================================================
-- DISABLE_PARALLEL_PIPELINE_TASKS: Suspend all parallel Task DAG tasks
-- Must disable in dependency order (root task first, then children)
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.DISABLE_PARALLEL_PIPELINE_TASKS()
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Suspends all parallel Task DAG tasks in correct dependency order (decoupled architecture)'
EXECUTE AS OWNER
AS
$$
BEGIN
    -- Disable root task first (stops new DAG runs from starting)
    ALTER TASK HARMONIZER_DEMO.HARMONIZED.DEDUP_FASTPATH_TASK SUSPEND;

    -- Disable classify task (depends on dedup/fastpath)
    ALTER TASK HARMONIZER_DEMO.HARMONIZED.CLASSIFY_UNIQUE_TASK SUSPEND;
    
    -- Disable vector prep task
    ALTER TASK HARMONIZER_DEMO.HARMONIZED.VECTOR_PREP_TASK SUSPEND;
    
    -- Disable sibling tasks
    ALTER TASK HARMONIZER_DEMO.HARMONIZED.CORTEX_SEARCH_TASK SUSPEND;
    ALTER TASK HARMONIZER_DEMO.HARMONIZED.COSINE_MATCH_TASK SUSPEND;
    ALTER TASK HARMONIZER_DEMO.HARMONIZED.EDIT_MATCH_TASK SUSPEND;
    ALTER TASK HARMONIZER_DEMO.HARMONIZED.JACCARD_MATCH_TASK SUSPEND;
    
    -- Disable finalizer
    ALTER TASK HARMONIZER_DEMO.HARMONIZED.STAGING_MERGE_TASK SUSPEND;
    
    -- Disable decoupled tasks (pure ensemble scoring)
    ALTER TASK HARMONIZER_DEMO.HARMONIZED.ENSEMBLE_SCORING_TASK SUSPEND;
    ALTER TASK HARMONIZER_DEMO.HARMONIZED.ITEM_ROUTER_TASK SUSPEND;
    
    -- Disable maintenance tasks
    ALTER TASK HARMONIZER_DEMO.HARMONIZED.CLEANUP_COORDINATION_TASK SUSPEND;
    ALTER TASK HARMONIZER_DEMO.ANALYTICS.REFRESH_TASK_HISTORY_CACHE SUSPEND;
    ALTER TASK HARMONIZER_DEMO.ANALYTICS.CLEANUP_TASK_EXECUTION_CACHE SUSPEND;
    ALTER TASK HARMONIZER_DEMO.ANALYTICS.REFRESH_TASK_STATE_CACHE SUSPEND;
    
    RETURN '{"status": "disabled", "tasks": ["DEDUP_FASTPATH_TASK", "CLASSIFY_UNIQUE_TASK", "VECTOR_PREP_TASK", "CORTEX_SEARCH_TASK", "COSINE_MATCH_TASK", "EDIT_MATCH_TASK", "JACCARD_MATCH_TASK", "STAGING_MERGE_TASK", "ENSEMBLE_SCORING_TASK", "ITEM_ROUTER_TASK", "CLEANUP_COORDINATION_TASK", "REFRESH_TASK_HISTORY_CACHE", "CLEANUP_TASK_EXECUTION_CACHE", "REFRESH_TASK_STATE_CACHE"]}';
EXCEPTION
    WHEN OTHER THEN
        LET err_code INTEGER := SQLCODE;
        LET err_msg VARCHAR := SQLERRM;
        LET disable_err VARCHAR := 'Error: ' || :err_code || ' - ' || :err_msg;
        RETURN '{"status": "error", "message": "' || :disable_err || '"}';
END;
$$;

-- ============================================================================
-- TRIGGER_PIPELINE_RUN: Manually trigger immediate pipeline execution
-- NOTE: This procedure is provided for completeness. The CLI uses
--       EXECUTE TASK directly which is simpler and has fewer failure modes.
--       Use: EXECUTE TASK HARMONIZER_DEMO.HARMONIZED.DEDUP_FASTPATH_TASK;
-- ============================================================================

-- ============================================================================
-- GET_PIPELINE_STATUS: Return comprehensive pipeline status for CLI/UI
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.GET_PIPELINE_STATUS()
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Returns current pipeline status including task states and item counts'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_pending INTEGER;
    v_matched INTEGER;
    v_review INTEGER;
    v_auto_accepted INTEGER;
    v_fast_path INTEGER;
    v_stream_pending INTEGER DEFAULT 0;
    v_active_batch_items INTEGER DEFAULT 0;
    v_active_batch_id VARCHAR DEFAULT NULL;
    v_tasks_enabled BOOLEAN DEFAULT FALSE;
    v_root_state VARCHAR DEFAULT 'unknown';
BEGIN
    -- Item counts using effective_status logic (matches V_DASHBOARD_KPIS for consistency)
    -- Prioritizes RAW_RETAIL_ITEMS.MATCH_STATUS for final states, falls back to ITEM_MATCHES.STATUS
    SELECT 
        SUM(CASE WHEN effective_status = 'PENDING' THEN 1 ELSE 0 END),
        SUM(CASE WHEN effective_status = 'PENDING_REVIEW' THEN 1 ELSE 0 END),
        SUM(CASE WHEN effective_status IN ('AUTO_ACCEPTED', 'AUTO_MATCHED') THEN 1 ELSE 0 END)
    INTO :v_pending, :v_review, :v_auto_accepted
    FROM (
        SELECT 
            CASE 
                WHEN ri.MATCH_STATUS IN ('AUTO_ACCEPTED', 'CONFIRMED', 'REJECTED') THEN ri.MATCH_STATUS
                ELSE COALESCE(im.STATUS, ri.MATCH_STATUS)
            END AS effective_status
        FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
        LEFT JOIN HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im ON ri.ITEM_ID = im.RAW_ITEM_ID
    );
    SELECT COUNT(*) INTO :v_matched FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES WHERE SUGGESTED_STANDARD_ID IS NOT NULL;
    SELECT COUNT(*) INTO :v_fast_path FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES WHERE MATCH_METHOD = 'FAST_PATH';
    
    -- Stream pending count - use SYSTEM$STREAM_HAS_DATA to avoid consuming stream
    -- Returns 1 if stream has data, 0 otherwise (exact count would consume stream)
    BEGIN
        LET has_data VARCHAR;
        SELECT SYSTEM$STREAM_HAS_DATA('HARMONIZER_DEMO.HARMONIZED.RAW_ITEMS_STREAM') INTO :has_data;
        IF (:has_data = 'true') THEN
            v_stream_pending := 1;
        ELSE
            v_stream_pending := 0;
        END IF;
    EXCEPTION
        WHEN OTHER THEN
            v_stream_pending := 0;
    END;
    
    -- Active batch info from PIPELINE_BATCH_STATE
    BEGIN
        SELECT BATCH_ID, ITEM_COUNT INTO :v_active_batch_id, :v_active_batch_items
        FROM HARMONIZER_DEMO.HARMONIZED.PIPELINE_BATCH_STATE
        WHERE STATUS = 'ACTIVE'
        ORDER BY CREATED_AT DESC
        LIMIT 1;
    EXCEPTION
        WHEN OTHER THEN
            v_active_batch_id := NULL;
            v_active_batch_items := 0;
    END;
    
    -- Check root task state from cache (avoids slow SHOW TASKS)
    BEGIN
        SELECT STATE INTO :v_root_state 
        FROM HARMONIZER_DEMO.ANALYTICS.TASK_STATE_CACHE 
        WHERE TASK_NAME = 'DEDUP_FASTPATH_TASK' AND SCHEMA_NAME = 'HARMONIZED'
        LIMIT 1;
        v_tasks_enabled := (:v_root_state = 'started');
    EXCEPTION
        WHEN OTHER THEN
            v_root_state := 'error';
    END;
    
    -- Return with UPPERCASE keys to match template expectations
    RETURN OBJECT_CONSTRUCT(
        'TASKS_ENABLED', :v_tasks_enabled,
        'ROOT_TASK_STATE', :v_root_state,
        'PENDING_ITEMS', :v_pending,
        'PENDING_REVIEW', :v_review,
        'AUTO_ACCEPTED', :v_auto_accepted,
        'MATCHED_ITEMS', :v_matched,
        'FAST_PATH_ITEMS', :v_fast_path,
        'STREAM_PENDING', :v_stream_pending,
        'ACTIVE_BATCH_ITEMS', :v_active_batch_items,
        'ACTIVE_BATCH_ID', :v_active_batch_id,
        'CHECKED_AT', CURRENT_TIMESTAMP()
    );
END;
$$;