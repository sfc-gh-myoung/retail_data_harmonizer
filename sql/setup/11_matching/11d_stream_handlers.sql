-- ============================================================================
-- Retail Data Harmonization Demo
-- Script: sql/setup/11_matching/11d_stream_handlers.sql
-- Purpose: Stream processing and orphan recovery (legacy single-pass alternative)
-- Depends on: 11c_ensemble_and_routing.sql
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- STEP 10: Stream-based Single-Pass Matching (Simplified Architecture)
-- ============================================================================
-- This procedure provides a simpler alternative to the Task DAG for cases
-- where true parallelism isn't needed. It processes items in a single pass:
--   1. Consumes stream atomically (or falls back to PENDING items)
--   2. Classifies items inline (NOTE: in the Task DAG, classification is a dedicated
--      CLASSIFY_UNIQUE_TASK step, not inline)
--   3. Computes all scores in parallel CTEs
--   4. Writes directly to ITEM_MATCHES via MERGE
--   5. Fully idempotent - safe to retry

CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.MATCH_ITEMS_STREAM(
    P_BATCH_SIZE INT DEFAULT 500,
    P_RUN_ID VARCHAR DEFAULT NULL
)
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Stream-based matching: single-pass, no staging tables, fully idempotent'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_run_id VARCHAR;
    v_started_at TIMESTAMP_NTZ;
    v_items_processed INT DEFAULT 0;
    v_items_classified INT DEFAULT 0;
    v_items_matched INT DEFAULT 0;
    v_has_stream_data VARCHAR;
BEGIN
    v_run_id := COALESCE(:P_RUN_ID, UUID_STRING());
    v_started_at := CURRENT_TIMESTAMP();
    
    SELECT SYSTEM$STREAM_HAS_DATA('HARMONIZER_DEMO.HARMONIZED.RAW_ITEMS_STREAM') INTO :v_has_stream_data;
    
    IF (v_has_stream_data != 'true') THEN
        LET v_pending_count INT := (
            SELECT COUNT(*) FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS 
            WHERE MATCH_STATUS = 'PENDING'
        );
        
        IF (v_pending_count = 0) THEN
            RETURN OBJECT_CONSTRUCT(
                'status', 'idle',
                'message', 'No new items in stream and no pending items',
                'run_id', :v_run_id
            );
        END IF;
    END IF;
    


    CREATE OR REPLACE TEMPORARY TABLE HARMONIZER_DEMO.HARMONIZED._WORK_ITEMS AS
    SELECT ITEM_ID, RAW_DESCRIPTION, INFERRED_CATEGORY, SOURCE_SYSTEM
    FROM (
        SELECT ITEM_ID, RAW_DESCRIPTION, INFERRED_CATEGORY, SOURCE_SYSTEM
        FROM HARMONIZER_DEMO.HARMONIZED.RAW_ITEMS_STREAM
        WHERE METADATA$ACTION = 'INSERT'
        
        UNION ALL
        
        SELECT ITEM_ID, RAW_DESCRIPTION, INFERRED_CATEGORY, SOURCE_SYSTEM
        FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS
        WHERE MATCH_STATUS = 'PENDING'
          AND NOT EXISTS (
              SELECT 1 FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
              WHERE im.RAW_ITEM_ID = RAW_RETAIL_ITEMS.ITEM_ID
                AND im.ENSEMBLE_SCORE IS NOT NULL
          )
    )
    LIMIT :P_BATCH_SIZE;
    
    SELECT COUNT(*) INTO :v_items_processed FROM HARMONIZER_DEMO.HARMONIZED._WORK_ITEMS;
    
    IF (:v_items_processed = 0) THEN
        RETURN OBJECT_CONSTRUCT(
            'status', 'idle',
            'message', 'No items to process',
            'run_id', :v_run_id
        );
    END IF;

    UPDATE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
    SET INFERRED_CATEGORY = CASE
            WHEN cat IN ('Beverages', 'Snacks', 'Condiments', 'Prepared Foods') THEN cat
            ELSE 'UNKNOWN'
        END,
        UPDATED_AT = CURRENT_TIMESTAMP()
    FROM (
        SELECT 
            wi.ITEM_ID,
            TRIM(TRY_CAST(SNOWFLAKE.CORTEX.COMPLETE(
                'mistral-large2',
                'Classify this retail item into exactly one category: Beverages, Snacks, Condiments, Prepared Foods, or UNKNOWN. Item: ' || wi.RAW_DESCRIPTION || '. Reply with ONLY the category name.'
            ) AS VARCHAR(100))) AS cat
        FROM HARMONIZER_DEMO.HARMONIZED._WORK_ITEMS wi
        WHERE wi.INFERRED_CATEGORY IS NULL OR wi.INFERRED_CATEGORY = ''
    ) classified
    WHERE ri.ITEM_ID = classified.ITEM_ID
      AND (ri.INFERRED_CATEGORY IS NULL OR ri.INFERRED_CATEGORY = '');
    
    v_items_classified := SQLROWCOUNT;
    
    UPDATE HARMONIZER_DEMO.HARMONIZED._WORK_ITEMS wi
    SET INFERRED_CATEGORY = ri.INFERRED_CATEGORY
    FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
    WHERE wi.ITEM_ID = ri.ITEM_ID;

    INSERT INTO HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS_EMBEDDINGS (ITEM_ID, RAW_DESCRIPTION, EMBEDDING)
    SELECT
        wi.ITEM_ID,
        wi.RAW_DESCRIPTION,
        SNOWFLAKE.CORTEX.EMBED_TEXT_1024('snowflake-arctic-embed-l-v2.0', wi.RAW_DESCRIPTION)
    FROM HARMONIZER_DEMO.HARMONIZED._WORK_ITEMS wi
    WHERE NOT EXISTS (
        SELECT 1 FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS_EMBEDDINGS re
        WHERE re.ITEM_ID = wi.ITEM_ID
    );

    MERGE INTO HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES tgt
    USING (
        WITH work_items AS (
            SELECT 
                wi.ITEM_ID,
                wi.RAW_DESCRIPTION,
                wi.INFERRED_CATEGORY,
                re.EMBEDDING AS raw_embedding
            FROM HARMONIZER_DEMO.HARMONIZED._WORK_ITEMS wi
            LEFT JOIN HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS_EMBEDDINGS re ON wi.ITEM_ID = re.ITEM_ID
        ),
        cosine_scored AS (
            SELECT
                wi.ITEM_ID,
                se.STANDARD_ITEM_ID AS cosine_std_id,
                VECTOR_COSINE_SIMILARITY(wi.raw_embedding, se.EMBEDDING) AS cosine_score,
                ROW_NUMBER() OVER (PARTITION BY wi.ITEM_ID ORDER BY VECTOR_COSINE_SIMILARITY(wi.raw_embedding, se.EMBEDDING) DESC) AS rn
            FROM work_items wi
            JOIN HARMONIZER_DEMO.RAW.STANDARD_ITEMS_EMBEDDINGS se ON 1=1
            JOIN HARMONIZER_DEMO.RAW.STANDARD_ITEMS si
                ON se.STANDARD_ITEM_ID = si.STANDARD_ITEM_ID
                AND si.CATEGORY = wi.INFERRED_CATEGORY
            WHERE wi.raw_embedding IS NOT NULL
        ),
        edit_scored AS (
            SELECT
                wi.ITEM_ID,
                si.STANDARD_ITEM_ID AS edit_std_id,
                HARMONIZER_DEMO.HARMONIZED.EDIT_DISTANCE_SCORE(wi.RAW_DESCRIPTION, si.STANDARD_DESCRIPTION) AS edit_score,
                ROW_NUMBER() OVER (PARTITION BY wi.ITEM_ID ORDER BY HARMONIZER_DEMO.HARMONIZED.EDIT_DISTANCE_SCORE(wi.RAW_DESCRIPTION, si.STANDARD_DESCRIPTION) DESC) AS rn
            FROM work_items wi
            JOIN HARMONIZER_DEMO.RAW.STANDARD_ITEMS si ON si.CATEGORY = wi.INFERRED_CATEGORY
        ),
        combined AS (
            SELECT 
                wi.ITEM_ID,
                wi.RAW_DESCRIPTION,
                wi.INFERRED_CATEGORY,
                c.cosine_std_id,
                c.cosine_score,
                e.edit_std_id,
                e.edit_score
            FROM work_items wi
            LEFT JOIN cosine_scored c ON wi.ITEM_ID = c.ITEM_ID AND c.rn = 1
            LEFT JOIN edit_scored e ON wi.ITEM_ID = e.ITEM_ID AND e.rn = 1
        )
        SELECT 
            ITEM_ID,
            cosine_std_id,
            cosine_score,
            edit_std_id,
            edit_score,
            COALESCE(
                CASE WHEN cosine_std_id = edit_std_id THEN cosine_std_id END,
                CASE WHEN COALESCE(cosine_score, 0) >= COALESCE(edit_score, 0) THEN cosine_std_id ELSE edit_std_id END
            ) AS suggested_std_id
        FROM combined
    ) src
    ON tgt.RAW_ITEM_ID = src.ITEM_ID
    WHEN MATCHED AND tgt.COSINE_SCORE IS NULL THEN UPDATE SET
        COSINE_MATCHED_ID = src.cosine_std_id,
        COSINE_SCORE = src.cosine_score,
        EDIT_DISTANCE_MATCHED_ID = src.edit_std_id,
        EDIT_DISTANCE_SCORE = src.edit_score,
        SUGGESTED_STANDARD_ID = src.suggested_std_id,
        UPDATED_AT = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT
        (MATCH_ID, RAW_ITEM_ID, COSINE_MATCHED_ID, COSINE_SCORE, 
         EDIT_DISTANCE_MATCHED_ID, EDIT_DISTANCE_SCORE,
         SUGGESTED_STANDARD_ID, MATCH_METHOD, CREATED_AT)
    VALUES
        (UUID_STRING(), src.ITEM_ID, src.cosine_std_id, src.cosine_score,
         src.edit_std_id, src.edit_score,
         src.suggested_std_id, 'ENSEMBLE', CURRENT_TIMESTAMP());
    
    v_items_matched := SQLROWCOUNT;

    DROP TABLE IF EXISTS HARMONIZER_DEMO.HARMONIZED._WORK_ITEMS;

    RETURN OBJECT_CONSTRUCT(
        'status', 'complete',
        'run_id', :v_run_id,
        'items_processed', :v_items_processed,
        'items_classified', :v_items_classified,
        'items_matched', :v_items_matched,
        'duration_seconds', TIMESTAMPDIFF('second', :v_started_at, CURRENT_TIMESTAMP())
    );
END;
$$;

-- ============================================================================
-- STEP 11: Recovery procedure for orphaned items
-- Call this to catch any items that were missed by stream processing
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.RECOVER_ORPHANED_ITEMS()
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Recovery for items that were missed by stream processing'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_orphaned_count INTEGER;
    v_recovered INTEGER DEFAULT 0;
BEGIN
    SELECT COUNT(*) INTO :v_orphaned_count
    FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
    WHERE ri.MATCH_STATUS = 'PENDING'
      AND NOT EXISTS (
          SELECT 1 FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
          WHERE im.RAW_ITEM_ID = ri.ITEM_ID
            AND im.ENSEMBLE_SCORE IS NOT NULL
      );
    
    IF (v_orphaned_count = 0) THEN
        RETURN 'No orphaned items found';
    END IF;
    
    WHILE (v_orphaned_count > 0) DO
        CALL HARMONIZER_DEMO.HARMONIZED.MATCH_ITEMS_STREAM(500, NULL);
        v_recovered := v_recovered + LEAST(500, v_orphaned_count);
        
        SELECT COUNT(*) INTO :v_orphaned_count
        FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
        WHERE ri.MATCH_STATUS = 'PENDING'
          AND NOT EXISTS (
              SELECT 1 FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
              WHERE im.RAW_ITEM_ID = ri.ITEM_ID
                AND im.ENSEMBLE_SCORE IS NOT NULL
          );
    END WHILE;
    
    RETURN 'Recovered ' || :v_recovered || ' orphaned items';
END;
$$;

-- NOTE: RUN_MATCHING_PIPELINE is defined in 13_admin_utilities.sql

-- ============================================================================
-- CLASSIFICATION_JOBS: Job tracking for classification operations
-- ============================================================================

CREATE OR REPLACE TABLE HARMONIZER_DEMO.ANALYTICS.CLASSIFICATION_JOBS (
    JOB_ID VARCHAR(36) PRIMARY KEY,
    STATUS VARCHAR(20) NOT NULL DEFAULT 'QUEUED',
    
    BATCH_SIZE INTEGER NOT NULL DEFAULT 500,
    ITEMS_TOTAL INTEGER DEFAULT 0,
    ITEMS_CLASSIFIED INTEGER DEFAULT 0,
    
    QUEUED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    STARTED_AT TIMESTAMP_NTZ,
    COMPLETED_AT TIMESTAMP_NTZ,
    LAST_UPDATE_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    
    TRIGGERED_BY VARCHAR(100) DEFAULT CURRENT_USER(),
    ERROR_MESSAGE VARCHAR(4000)
);

-- ============================================================================
-- START_CLASSIFICATION_JOB: Queue a classification job
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.START_CLASSIFICATION_JOB(
    P_BATCH_SIZE INTEGER DEFAULT 500
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Queues a new classification job for background execution'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_job_id VARCHAR;
    v_active_job_id VARCHAR;
    v_unclassified_count INTEGER;
BEGIN
    SELECT JOB_ID INTO :v_active_job_id
    FROM HARMONIZER_DEMO.ANALYTICS.CLASSIFICATION_JOBS
    WHERE STATUS IN ('QUEUED', 'RUNNING')
    ORDER BY QUEUED_AT DESC
    LIMIT 1;
    
    IF (v_active_job_id IS NOT NULL) THEN
        RETURN '{"status": "error", "message": "Classification job already running", "active_job_id": "' || :v_active_job_id || '"}';
    END IF;
    
    SELECT COUNT(*) INTO :v_unclassified_count
    FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS
    WHERE INFERRED_CATEGORY IS NULL;
    
    IF (v_unclassified_count = 0) THEN
        RETURN '{"status": "complete", "message": "No items to classify"}';
    END IF;
    
    v_job_id := UUID_STRING();
    
    INSERT INTO HARMONIZER_DEMO.ANALYTICS.CLASSIFICATION_JOBS (
        JOB_ID, STATUS, BATCH_SIZE, ITEMS_TOTAL
    ) VALUES (
        :v_job_id, 'QUEUED', :P_BATCH_SIZE, :v_unclassified_count
    );
    
    RETURN '{"status": "queued", "job_id": "' || :v_job_id || '", "items_total": ' || :v_unclassified_count || '}';
END;
$$;

-- ============================================================================
-- UPDATE_CLASSIFICATION_PROGRESS: Update classification job progress
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.UPDATE_CLASSIFICATION_PROGRESS(
    P_JOB_ID VARCHAR,
    P_ITEMS_CLASSIFIED INTEGER DEFAULT NULL
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Updates classification job progress for UI feedback'
EXECUTE AS OWNER
AS
$$
BEGIN
    UPDATE HARMONIZER_DEMO.ANALYTICS.CLASSIFICATION_JOBS
    SET ITEMS_CLASSIFIED = COALESCE(:P_ITEMS_CLASSIFIED, ITEMS_CLASSIFIED),
        LAST_UPDATE_AT = CURRENT_TIMESTAMP()
    WHERE JOB_ID = :P_JOB_ID;
    
    RETURN 'OK';
END;
$$;

-- ============================================================================
-- GET_CLASSIFICATION_JOB: Get currently active classification job
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.GET_CLASSIFICATION_JOB()
RETURNS TABLE (
    JOB_ID VARCHAR,
    STATUS VARCHAR,
    BATCH_SIZE INTEGER,
    ITEMS_TOTAL INTEGER,
    ITEMS_CLASSIFIED INTEGER,
    QUEUED_AT TIMESTAMP_NTZ,
    STARTED_AT TIMESTAMP_NTZ,
    TRIGGERED_BY VARCHAR
)
LANGUAGE SQL
COMMENT = 'Returns the currently active classification job if any'
EXECUTE AS OWNER
AS
$$
DECLARE
    res RESULTSET;
BEGIN
    res := (
        SELECT 
            JOB_ID, STATUS, BATCH_SIZE,
            ITEMS_TOTAL, ITEMS_CLASSIFIED,
            QUEUED_AT, STARTED_AT, TRIGGERED_BY
        FROM HARMONIZER_DEMO.ANALYTICS.CLASSIFICATION_JOBS
        WHERE STATUS IN ('QUEUED', 'RUNNING')
        ORDER BY QUEUED_AT DESC
        LIMIT 1
    );
    RETURN TABLE(res);
END;
$$;

-- ============================================================================
-- PROCESS_CLASSIFICATION_JOB: Process a classification job
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.PROCESS_CLASSIFICATION_JOB(
    P_JOB_ID VARCHAR
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Processes a classification job until completion'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_status VARCHAR;
    v_batch_size INTEGER;
    v_unclassified INTEGER;
    v_classified_total INTEGER DEFAULT 0;
    v_error_message VARCHAR;
BEGIN
    SELECT STATUS, BATCH_SIZE INTO :v_status, :v_batch_size
    FROM HARMONIZER_DEMO.ANALYTICS.CLASSIFICATION_JOBS
    WHERE JOB_ID = :P_JOB_ID;
    
    IF (v_status IS NULL) THEN
        RETURN '{"status": "error", "message": "Job not found"}';
    END IF;
    
    IF (v_status != 'QUEUED') THEN
        RETURN '{"status": "error", "message": "Job not in QUEUED status"}';
    END IF;
    
    UPDATE HARMONIZER_DEMO.ANALYTICS.CLASSIFICATION_JOBS
    SET STATUS = 'RUNNING',
        STARTED_AT = CURRENT_TIMESTAMP(),
        LAST_UPDATE_AT = CURRENT_TIMESTAMP()
    WHERE JOB_ID = :P_JOB_ID;
    
    LOOP
        SELECT COUNT(*) INTO :v_unclassified
        FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS
        WHERE INFERRED_CATEGORY IS NULL;
        
        IF (v_unclassified <= 0) THEN
            UPDATE HARMONIZER_DEMO.ANALYTICS.CLASSIFICATION_JOBS
            SET STATUS = 'COMPLETED',
                COMPLETED_AT = CURRENT_TIMESTAMP(),
                ITEMS_CLASSIFIED = :v_classified_total,
                LAST_UPDATE_AT = CURRENT_TIMESTAMP()
            WHERE JOB_ID = :P_JOB_ID;
            
            RETURN '{"status": "completed", "job_id": "' || :P_JOB_ID || '", "classified": ' || :v_classified_total || '}';
        END IF;
        
        BEGIN
            CALL HARMONIZER_DEMO.HARMONIZED.CLASSIFY_RAW_ITEMS(:v_batch_size, NULL);
            v_classified_total := v_classified_total + LEAST(:v_batch_size, :v_unclassified);
            
            CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_CLASSIFICATION_PROGRESS(:P_JOB_ID, :v_classified_total);
        EXCEPTION
            WHEN OTHER THEN
                v_error_message := SQLERRM;
                UPDATE HARMONIZER_DEMO.ANALYTICS.CLASSIFICATION_JOBS
                SET STATUS = 'FAILED',
                    COMPLETED_AT = CURRENT_TIMESTAMP(),
                    ERROR_MESSAGE = :v_error_message,
                    LAST_UPDATE_AT = CURRENT_TIMESTAMP()
                WHERE JOB_ID = :P_JOB_ID;
                
                RETURN '{"status": "failed", "job_id": "' || :P_JOB_ID || '", "error": "' || :v_error_message || '"}';
        END;
    END LOOP;
END;
$$;

-- ============================================================================
-- POLL_AND_PROCESS_CLASSIFICATION_JOBS: Process queued classification jobs
-- Can be called manually or by a scheduled task if needed
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.POLL_AND_PROCESS_CLASSIFICATION_JOBS()
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Polls for queued classification jobs and processes them'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_job_id VARCHAR;
BEGIN
    SELECT JOB_ID INTO :v_job_id
    FROM HARMONIZER_DEMO.ANALYTICS.CLASSIFICATION_JOBS
    WHERE STATUS = 'QUEUED'
    ORDER BY QUEUED_AT ASC
    LIMIT 1;
    
    IF (v_job_id IS NULL) THEN
        RETURN '{"status": "idle", "message": "No queued classification jobs"}';
    END IF;
    
    CALL HARMONIZER_DEMO.HARMONIZED.PROCESS_CLASSIFICATION_JOB(:v_job_id);
    
    RETURN '{"status": "processed", "job_id": "' || :v_job_id || '"}';
END;
$$;
