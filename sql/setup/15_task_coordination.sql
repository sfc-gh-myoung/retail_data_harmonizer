-- ============================================================================
-- sql/setup/15_task_coordination.sql
-- Retail Data Harmonizer - Table-Based Task Coordination
--
-- Replaces SYSTEM$SET_RETURN_VALUE / SYSTEM$GET_PREDECESSOR_RETURN_VALUE with
-- a coordination table that acts like a lightweight Kafka message queue for
-- task-to-task communication.
--
-- Benefits over SYSTEM$SET_RETURN_VALUE:
--   - No context restrictions (works after EXECUTE IMMEDIATE, dynamic SQL)
--   - Full audit trail of every DAG run
--   - Easy debugging (query the table to see exact status)
--   - Graceful child task skipping when parent fails/skips
--   - Rich payload support via VARIANT column
--
-- Creates:
--   1. TASK_COORDINATION table (message queue)
--   2. Helper procedures (REGISTER_TASK_START, UPDATE_TASK_STATUS)
--   3. Helper functions (GET_PARENT_TASK_STATUS, GET_LATEST_RUN_ID)
--   4. Cleanup task (CLEANUP_COORDINATION_TASK)
--
-- Depends on: 01_roles_and_warehouse.sql (database, schemas, role)
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- TASK_COORDINATION Table
-- Acts like a Kafka topic for task-to-task communication within the DAG
-- ============================================================================
CREATE TABLE IF NOT EXISTS HARMONIZER_DEMO.HARMONIZED.TASK_COORDINATION (
    COORDINATION_ID     VARCHAR(36) DEFAULT UUID_STRING() PRIMARY KEY,
    RUN_ID              VARCHAR(36) NOT NULL,
    TASK_NAME           VARCHAR(100) NOT NULL,
    STATUS              VARCHAR(20) NOT NULL,
    PAYLOAD             VARIANT,
    CREATED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    
    UNIQUE (RUN_ID, TASK_NAME)
);

COMMENT ON TABLE HARMONIZER_DEMO.HARMONIZED.TASK_COORDINATION IS 
    'Message queue table for task-to-task coordination in the pipeline DAG. Replaces SYSTEM$SET_RETURN_VALUE.';

COMMENT ON COLUMN HARMONIZER_DEMO.HARMONIZED.TASK_COORDINATION.RUN_ID IS 
    'UUID grouping all tasks in a single DAG execution';
COMMENT ON COLUMN HARMONIZER_DEMO.HARMONIZED.TASK_COORDINATION.TASK_NAME IS 
    'Task identifier: DEDUP_FASTPATH, CLASSIFY_UNIQUE, VECTOR_PREP, CORTEX_SEARCH, COSINE_MATCH, EDIT_MATCH, JACCARD_MATCH, VECTOR_ENSEMBLE';
COMMENT ON COLUMN HARMONIZER_DEMO.HARMONIZED.TASK_COORDINATION.STATUS IS 
    'Task status: STARTED, COMPLETED, SKIPPED, FAILED';
COMMENT ON COLUMN HARMONIZER_DEMO.HARMONIZED.TASK_COORDINATION.PAYLOAD IS 
    'Task-specific metadata: counts, batch_id, error messages, timing, etc.';

-- ============================================================================
-- REGISTER_TASK_START: Called at beginning of each task procedure
-- Inserts a STARTED record into the coordination table
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.REGISTER_TASK_START(
    P_RUN_ID VARCHAR,
    P_TASK_NAME VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Registers task start in coordination table. Called at beginning of each task procedure.'
EXECUTE AS OWNER
AS
$$
BEGIN
    INSERT INTO HARMONIZER_DEMO.HARMONIZED.TASK_COORDINATION 
        (RUN_ID, TASK_NAME, STATUS, PAYLOAD, CREATED_AT, UPDATED_AT)
    VALUES 
        (:P_RUN_ID, :P_TASK_NAME, 'STARTED', NULL, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP());
    
    RETURN 'registered';
EXCEPTION
    WHEN OTHER THEN
        RETURN 'error: ' || SQLERRM;
END;
$$;

-- ============================================================================
-- UPDATE_TASK_STATUS: Called at end of each task procedure
-- Updates the task's status and payload in the coordination table
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
    P_RUN_ID VARCHAR,
    P_TASK_NAME VARCHAR,
    P_STATUS VARCHAR,
    P_PAYLOAD VARIANT
)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Updates task status in coordination table. Called at end of each task procedure.'
EXECUTE AS OWNER
AS
$$
BEGIN
    UPDATE HARMONIZER_DEMO.HARMONIZED.TASK_COORDINATION
    SET STATUS = :P_STATUS,
        PAYLOAD = :P_PAYLOAD,
        UPDATED_AT = CURRENT_TIMESTAMP()
    WHERE RUN_ID = :P_RUN_ID 
      AND TASK_NAME = :P_TASK_NAME;
    
    IF (SQLROWCOUNT = 0) THEN
        INSERT INTO HARMONIZER_DEMO.HARMONIZED.TASK_COORDINATION 
            (RUN_ID, TASK_NAME, STATUS, PAYLOAD, CREATED_AT, UPDATED_AT)
        VALUES 
            (:P_RUN_ID, :P_TASK_NAME, :P_STATUS, :P_PAYLOAD, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP());
    END IF;
    
    RETURN 'updated';
EXCEPTION
    WHEN OTHER THEN
        RETURN 'error: ' || SQLERRM;
END;
$$;

-- ============================================================================
-- UPDATE_TASK_STATUS (VARCHAR overload): For Python procedures using json.dumps()
-- Accepts JSON string and converts to VARIANT internally
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
    P_RUN_ID VARCHAR,
    P_TASK_NAME VARCHAR,
    P_STATUS VARCHAR,
    P_PAYLOAD_JSON VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Updates task status (VARCHAR overload). Accepts JSON string, converts to VARIANT.'
EXECUTE AS OWNER
AS
$$
BEGIN
    UPDATE HARMONIZER_DEMO.HARMONIZED.TASK_COORDINATION
    SET STATUS = :P_STATUS,
        PAYLOAD = TRY_PARSE_JSON(:P_PAYLOAD_JSON),
        UPDATED_AT = CURRENT_TIMESTAMP()
    WHERE RUN_ID = :P_RUN_ID 
      AND TASK_NAME = :P_TASK_NAME;
    
    IF (SQLROWCOUNT = 0) THEN
        INSERT INTO HARMONIZER_DEMO.HARMONIZED.TASK_COORDINATION 
            (RUN_ID, TASK_NAME, STATUS, PAYLOAD, CREATED_AT, UPDATED_AT)
        SELECT 
            :P_RUN_ID, :P_TASK_NAME, :P_STATUS, TRY_PARSE_JSON(:P_PAYLOAD_JSON), CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP();
    END IF;
    
    RETURN 'updated';
EXCEPTION
    WHEN OTHER THEN
        RETURN 'error: ' || SQLERRM;
END;
$$;

-- ============================================================================
-- GET_PARENT_TASK_STATUS: Check parent task status before proceeding
-- Returns the most recent status for a given parent task within max_age window
-- ============================================================================
CREATE OR REPLACE FUNCTION HARMONIZER_DEMO.HARMONIZED.GET_PARENT_TASK_STATUS(
    P_PARENT_TASK_NAME VARCHAR,
    P_MAX_AGE_MINUTES INTEGER
)
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Returns most recent parent task status within age window. Used by child tasks to check if they should proceed.'
AS
$$
    SELECT OBJECT_CONSTRUCT(
        'run_id', RUN_ID,
        'task_name', TASK_NAME,
        'status', STATUS,
        'payload', PAYLOAD,
        'created_at', CREATED_AT,
        'updated_at', UPDATED_AT
    )::VARIANT
    FROM HARMONIZER_DEMO.HARMONIZED.TASK_COORDINATION
    WHERE TASK_NAME = P_PARENT_TASK_NAME
      AND STATUS IN ('COMPLETED', 'SKIPPED', 'FAILED')
      AND CREATED_AT > DATEADD('minute', -P_MAX_AGE_MINUTES, CURRENT_TIMESTAMP())
    ORDER BY CREATED_AT DESC
    LIMIT 1
$$;

-- ============================================================================
-- GET_LATEST_RUN_ID: Get the most recent run_id for a given parent task
-- Useful for inheriting run_id from parent when child task starts
-- ============================================================================
CREATE OR REPLACE FUNCTION HARMONIZER_DEMO.HARMONIZED.GET_LATEST_RUN_ID(
    P_PARENT_TASK_NAME VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Returns the most recent run_id for a parent task. Used to inherit run_id in child tasks.'
AS
$$
    SELECT RUN_ID
    FROM HARMONIZER_DEMO.HARMONIZED.TASK_COORDINATION
    WHERE TASK_NAME = P_PARENT_TASK_NAME
    ORDER BY CREATED_AT DESC
    LIMIT 1
$$;

-- ============================================================================
-- CHECK_ALL_PARALLEL_TASKS_DONE: Check if all 4 parallel matchers completed
-- Used by VECTOR_ENSEMBLE_TASK to verify all siblings finished
-- ============================================================================
CREATE OR REPLACE FUNCTION HARMONIZER_DEMO.HARMONIZED.CHECK_ALL_PARALLEL_TASKS_DONE(
    P_RUN_ID VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Checks if all 4 parallel matching tasks completed for a given run_id. Returns status summary.'
AS
$$
    SELECT OBJECT_CONSTRUCT(
        'run_id', P_RUN_ID,
        'all_done', (COUNT(*) = 4),
        'completed_count', SUM(CASE WHEN STATUS = 'COMPLETED' THEN 1 ELSE 0 END),
        'skipped_count', SUM(CASE WHEN STATUS = 'SKIPPED' THEN 1 ELSE 0 END),
        'failed_count', SUM(CASE WHEN STATUS = 'FAILED' THEN 1 ELSE 0 END),
        'tasks', ARRAY_AGG(OBJECT_CONSTRUCT('task', TASK_NAME, 'status', STATUS))
    )::VARIANT
    FROM HARMONIZER_DEMO.HARMONIZED.TASK_COORDINATION
    WHERE RUN_ID = P_RUN_ID
      AND TASK_NAME IN ('CORTEX_SEARCH', 'COSINE_MATCH', 'EDIT_MATCH', 'JACCARD_MATCH')
      AND STATUS IN ('COMPLETED', 'SKIPPED', 'FAILED')
$$;

-- ============================================================================
-- CLEANUP_OLD_COORDINATION: Delete old coordination records
-- Retention policy to prevent unbounded table growth
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.CLEANUP_OLD_COORDINATION(
    P_RETENTION_DAYS INTEGER DEFAULT 7
)
RETURNS INTEGER
LANGUAGE SQL
COMMENT = 'Deletes coordination records older than retention period. Default: 7 days.'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_deleted INTEGER;
BEGIN
    DELETE FROM HARMONIZER_DEMO.HARMONIZED.TASK_COORDINATION
    WHERE CREATED_AT < DATEADD('day', -:P_RETENTION_DAYS, CURRENT_TIMESTAMP());
    
    v_deleted := SQLROWCOUNT;
    RETURN :v_deleted;
END;
$$;

-- ============================================================================
-- CLEANUP_COORDINATION_TASK: Scheduled task to clean up old records
-- Runs daily at 3 AM ET to delete records older than 7 days
-- ============================================================================
CREATE OR REPLACE TASK HARMONIZER_DEMO.HARMONIZED.CLEANUP_COORDINATION_TASK
    WAREHOUSE = HARMONIZER_DEMO_WH
    SCHEDULE = 'USING CRON 0 3 * * * America/New_York'
    COMMENT = 'Daily cleanup of coordination records older than 7 days'
AS
    CALL HARMONIZER_DEMO.HARMONIZED.CLEANUP_OLD_COORDINATION(7);

-- Enable cleanup task by default
ALTER TASK HARMONIZER_DEMO.HARMONIZED.CLEANUP_COORDINATION_TASK RESUME;

-- ============================================================================
-- Grant permissions
-- ============================================================================
GRANT SELECT ON HARMONIZER_DEMO.HARMONIZED.TASK_COORDINATION TO ROLE HARMONIZER_DEMO_ROLE;
