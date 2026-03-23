-- ============================================================================
-- sql/setup/04_telemetry.sql
-- Retail Data Harmonizer - Pipeline Telemetry Foundation
--
-- Purpose: Core telemetry infrastructure for pipeline observability
--          This file is loaded early because LOG_PIPELINE_STEP is called
--          by procedures in files 09, 10, 11, 12, and beyond.
--
-- Creates:
--   Tables:
--     - ANALYTICS.PIPELINE_EXECUTION_LOG (step-by-step execution logging)
--   Procedures:
--     - ANALYTICS.LOG_PIPELINE_STEP() (helper to log pipeline steps)
--
-- Depends on: 01_roles_and_warehouse.sql (database, schemas, role, warehouse)
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- PIPELINE_EXECUTION_LOG: Detailed step-by-step execution logging
-- ============================================================================
-- This table captures granular telemetry for every pipeline step, enabling:
--   - Real-time pipeline status monitoring
--   - Performance analysis and bottleneck identification
--   - Error tracking and debugging
--   - Throughput and cost estimation
-- ============================================================================
CREATE OR REPLACE TABLE HARMONIZER_DEMO.ANALYTICS.PIPELINE_EXECUTION_LOG (
    LOG_ID              VARCHAR(36)     NOT NULL DEFAULT UUID_STRING(),
    RUN_ID              VARCHAR(36)     NOT NULL,
    STEP_NAME           VARCHAR(50)     NOT NULL,
    STEP_STATUS         VARCHAR(20)     NOT NULL,  -- STARTED, COMPLETED, FAILED, SKIPPED
    ITEMS_PROCESSED     INTEGER         DEFAULT 0,
    ITEMS_SKIPPED       INTEGER         DEFAULT 0,
    ITEMS_FAILED        INTEGER         DEFAULT 0,
    STARTED_AT          TIMESTAMP_NTZ,
    COMPLETED_AT        TIMESTAMP_NTZ,
    DURATION_MS         INTEGER,
    ERROR_MESSAGE       VARCHAR(4000),
    ERROR_CONTEXT       VARIANT,
    EXECUTION_MODE      VARCHAR(20),    -- SERIAL, PARALLEL, TASK
    CATEGORY            VARCHAR(50),    -- For parallel execution by category
    WAREHOUSE_NAME      VARCHAR(100),
    QUERY_ID            VARCHAR(100),
    TRACE_ID            VARCHAR(32),    -- Native telemetry correlation
    SPAN_ID             VARCHAR(16),    -- Native telemetry span correlation
    CREATED_AT          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_PIPELINE_EXECUTION_LOG PRIMARY KEY (LOG_ID)
)
COMMENT = 'Step-level telemetry for pipeline execution. Used by V_PIPELINE_STATUS_REALTIME and debugging.'
DATA_RETENTION_TIME_IN_DAYS = 90;

-- ============================================================================
-- LOG_PIPELINE_STEP: Helper procedure to log pipeline execution steps
-- ============================================================================
-- Called by matching procedures to record:
--   - Step start (P_STATUS = 'STARTED')
--   - Step completion (P_STATUS = 'COMPLETED') 
--   - Step failure (P_STATUS = 'FAILED')
--   - Step skip (P_STATUS = 'SKIPPED')
--
-- Duration is auto-calculated when P_STARTED_AT is provided and status is
-- COMPLETED or FAILED.
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
    P_RUN_ID VARCHAR,
    P_STEP_NAME VARCHAR,
    P_STATUS VARCHAR,
    P_ITEMS_PROCESSED INTEGER DEFAULT 0,
    P_ITEMS_SKIPPED INTEGER DEFAULT 0,
    P_ITEMS_FAILED INTEGER DEFAULT 0,
    P_STARTED_AT TIMESTAMP_NTZ DEFAULT NULL,
    P_ERROR_MESSAGE VARCHAR DEFAULT NULL,
    P_ERROR_CONTEXT VARIANT DEFAULT NULL,
    P_EXECUTION_MODE VARCHAR DEFAULT 'SERIAL',
    P_CATEGORY VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Log a pipeline execution step for observability. Called by matching procedures.'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_log_id VARCHAR;
    v_completed_at TIMESTAMP_NTZ;
    v_duration_ms INTEGER;
BEGIN
    v_log_id := UUID_STRING();
    
    -- Calculate completion time and duration for terminal states
    IF (P_STATUS IN ('COMPLETED', 'FAILED')) THEN
        v_completed_at := CURRENT_TIMESTAMP();
        IF (P_STARTED_AT IS NOT NULL) THEN
            v_duration_ms := DATEDIFF('millisecond', P_STARTED_AT, v_completed_at);
        END IF;
    END IF;
    
    -- Use INSERT SELECT instead of INSERT VALUES to avoid VARIANT binding issues
    INSERT INTO HARMONIZER_DEMO.ANALYTICS.PIPELINE_EXECUTION_LOG (
        LOG_ID, RUN_ID, STEP_NAME, STEP_STATUS,
        ITEMS_PROCESSED, ITEMS_SKIPPED, ITEMS_FAILED,
        STARTED_AT, COMPLETED_AT, DURATION_MS,
        ERROR_MESSAGE, ERROR_CONTEXT,
        EXECUTION_MODE, CATEGORY,
        WAREHOUSE_NAME, QUERY_ID
    ) 
    SELECT
        :v_log_id, :P_RUN_ID, :P_STEP_NAME, :P_STATUS,
        :P_ITEMS_PROCESSED, :P_ITEMS_SKIPPED, :P_ITEMS_FAILED,
        COALESCE(:P_STARTED_AT, CURRENT_TIMESTAMP()), :v_completed_at, :v_duration_ms,
        :P_ERROR_MESSAGE, :P_ERROR_CONTEXT,
        :P_EXECUTION_MODE, :P_CATEGORY,
        CURRENT_WAREHOUSE(), LAST_QUERY_ID();
    
    RETURN :v_log_id;
END;
$$;

-- ============================================================================
-- Verification
-- ============================================================================
SELECT 'Telemetry foundation created successfully' AS STATUS;
SELECT 
    'PIPELINE_EXECUTION_LOG' AS OBJECT_NAME,
    'TABLE' AS OBJECT_TYPE,
    'Ready' AS STATUS
UNION ALL
SELECT 
    'LOG_PIPELINE_STEP',
    'PROCEDURE',
    'Ready';
