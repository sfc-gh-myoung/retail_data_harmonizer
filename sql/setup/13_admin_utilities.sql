-- ============================================================================
-- sql/setup/13_admin_utilities.sql
-- Retail Data Harmonizer - Utility Stored Procedures
--
-- Supporting procedures for the Streamlit app:
--   - Record locking for multi-user review
--   - Pipeline stats
--   - AI_SIMILARITY comparison
--   - Config management
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- Record locking for multi-user review (15-minute timeout)
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.ACQUIRE_LOCK(ITEM_ID VARCHAR, USER_NAME VARCHAR)
RETURNS BOOLEAN
LANGUAGE SQL
COMMENT = 'Acquires a 15-minute review lock on an item for multi-user coordination'
EXECUTE AS OWNER
AS
$$
DECLARE
    lock_acquired BOOLEAN DEFAULT FALSE;
BEGIN
    -- Release expired locks (15 min timeout)
    UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
    SET LOCKED_BY = NULL, LOCKED_AT = NULL
    WHERE LOCKED_AT < DATEADD('minute', -15, CURRENT_TIMESTAMP())
      AND LOCKED_BY IS NOT NULL;

    -- Try to acquire lock
    UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
    SET LOCKED_BY = :USER_NAME,
        LOCKED_AT = CURRENT_TIMESTAMP()
    WHERE RAW_ITEM_ID = :ITEM_ID
      AND (LOCKED_BY IS NULL OR LOCKED_BY = :USER_NAME);

    IF (SQLROWCOUNT > 0) THEN
        lock_acquired := TRUE;
    END IF;

    RETURN lock_acquired;
END;
$$;

CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.RELEASE_LOCK(ITEM_ID VARCHAR, USER_NAME VARCHAR)
RETURNS BOOLEAN
LANGUAGE SQL
COMMENT = 'Releases a review lock on an item'
EXECUTE AS OWNER
AS
$$
BEGIN
    UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
    SET LOCKED_BY = NULL, LOCKED_AT = NULL
    WHERE RAW_ITEM_ID = :ITEM_ID
      AND LOCKED_BY = :USER_NAME;

    RETURN TRUE;
END;
$$;

-- ============================================================================
-- Pipeline statistics for dashboard
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.ANALYTICS.GET_PIPELINE_STATS()
RETURNS TABLE (
    METRIC_NAME VARCHAR,
    METRIC_VALUE VARCHAR
)
LANGUAGE SQL
COMMENT = 'Returns pipeline statistics for the dashboard'
EXECUTE AS OWNER
AS
$$
DECLARE
    res RESULTSET;
BEGIN
    res := (
        SELECT 'total_raw_items' AS METRIC_NAME, COUNT(*)::VARCHAR AS METRIC_VALUE
        FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS
        UNION ALL
        SELECT 'total_standard_items', COUNT(*)::VARCHAR
        FROM HARMONIZER_DEMO.RAW.STANDARD_ITEMS
        UNION ALL
        SELECT 'total_matched', COUNT(*)::VARCHAR
        FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS WHERE MATCH_STATUS IN ('AUTO_ACCEPTED', 'CONFIRMED')
        UNION ALL
        SELECT 'pending_review', COUNT(*)::VARCHAR
        FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS WHERE MATCH_STATUS = 'PENDING_REVIEW'
        UNION ALL
        SELECT 'unprocessed', COUNT(*)::VARCHAR
        FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS WHERE MATCH_STATUS = 'PENDING'
        UNION ALL
        SELECT 'avg_confidence', ROUND(AVG(ENSEMBLE_SCORE), 4)::VARCHAR
        FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES WHERE ENSEMBLE_SCORE IS NOT NULL
        UNION ALL
        SELECT 'method_agreement_rate',
            ROUND(
                SUM(CASE WHEN SEARCH_MATCHED_ID = COSINE_MATCHED_ID
                              AND COSINE_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID
                              AND EDIT_DISTANCE_MATCHED_ID = JACCARD_MATCHED_ID
                              AND SEARCH_MATCHED_ID IS NOT NULL
                         THEN 1 ELSE 0 END)::FLOAT
                / NULLIF(COUNT(*), 0), 4
            )::VARCHAR
        FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
        WHERE CORTEX_SEARCH_SCORE IS NOT NULL AND COSINE_SCORE IS NOT NULL AND EDIT_DISTANCE_SCORE IS NOT NULL AND JACCARD_SCORE IS NOT NULL
    );
    RETURN TABLE(res);
END;
$$;

-- ============================================================================
-- STEP 9: Master orchestration procedure
-- Includes Step 0 (de-duplication) and Step 0.5 (fast-path) before AI matching
-- ============================================================================
-- Drop old signature to avoid overloading error
DROP PROCEDURE IF EXISTS HARMONIZER_DEMO.HARMONIZED.RUN_MATCHING_PIPELINE(INT);

CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.RUN_MATCHING_PIPELINE(
    BATCH_SIZE INT DEFAULT 100,
    P_RUN_ID VARCHAR DEFAULT NULL
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Master orchestration: deduplication, fast-path, classification, and multi-method matching'
EXECUTE AS OWNER
AS
-- NOTE: This procedure runs with AUTOCOMMIT=TRUE (default). Each step commits independently.
-- If atomicity is required, wrap the CALL in an explicit transaction.
$$
DECLARE
    v_run_id VARCHAR;
    v_started_at TIMESTAMP_NTZ;
    dedup_result STRING;
    fast_path_result STRING;
    result1 STRING;
    result2 STRING;
    result3 STRING;
    result4 STRING;
    dedup_count INTEGER DEFAULT 0;
    fast_path_count INTEGER DEFAULT 0;
    start_time TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
    v_error_message VARCHAR;
BEGIN
    -- Initialize telemetry
    v_run_id := COALESCE(:P_RUN_ID, UUID_STRING());
    v_started_at := CURRENT_TIMESTAMP();
    
    -- Log start
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'RUN_MATCHING_PIPELINE', 'STARTED',
        0, 0, 0, :v_started_at, NULL, NULL::VARIANT, 'SERIAL', NULL
    );

    -- Step -1: Release expired review locks before pipeline runs
    UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
    SET LOCKED_BY = NULL, LOCKED_AT = NULL, LOCK_EXPIRES_AT = NULL
    WHERE LOCK_EXPIRES_AT < CURRENT_TIMESTAMP()
      AND LOCKED_BY IS NOT NULL;

    -- Step 0: De-duplicate raw items into unique normalized descriptions
    CALL HARMONIZER_DEMO.HARMONIZED.DEDUPLICATE_RAW_ITEMS(:v_run_id);
    dedup_result := 'De-duplication complete';
    SELECT COUNT(*) INTO :dedup_count
    FROM HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS
    WHERE MATCH_STATUS = 'PENDING';

    -- Step 0.5: Resolve confirmed-match fast-path (zero-cost, instant)
    CALL HARMONIZER_DEMO.HARMONIZED.RESOLVE_FAST_PATH(:v_run_id);
    fast_path_result := 'Fast-path complete';
    SELECT COUNT(*) INTO :fast_path_count
    FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
    WHERE MATCH_METHOD = 'FAST_PATH'
      AND CREATED_AT >= :start_time;

    -- Step 1: Prepare batch (classify + generate embeddings)
    CALL HARMONIZER_DEMO.HARMONIZED.VECTOR_PREP_BATCH(:BATCH_SIZE);
    result1 := 'Batch prep complete';
    
    -- Get batch_id from persistent state table
    LET v_batch_id VARCHAR := (SELECT BATCH_ID FROM HARMONIZER_DEMO.HARMONIZED.PIPELINE_BATCH_STATE WHERE STATUS = 'ACTIVE' LIMIT 1);

    -- Step 2: Cortex Search matching (batch)
    CALL HARMONIZER_DEMO.HARMONIZED.MATCH_CORTEX_SEARCH_BATCH(:v_batch_id);
    result2 := 'Search matching complete';

    -- Step 3: Cosine similarity matching (batch)
    CALL HARMONIZER_DEMO.HARMONIZED.MATCH_COSINE_BATCH(:v_batch_id);
    result3 := 'Cosine matching complete';

    -- Step 4: Edit distance matching (batch)
    CALL HARMONIZER_DEMO.HARMONIZED.MATCH_EDIT_BATCH(:v_batch_id);
    result4 := 'Edit matching complete';

    -- Step 5: Jaccard token similarity matching (batch)
    CALL HARMONIZER_DEMO.HARMONIZED.MATCH_JACCARD_BATCH(:v_batch_id);

    -- Step 6: Merge staging tables, compute ensemble scores, and route items (decoupled procedures)
    CALL HARMONIZER_DEMO.HARMONIZED.MERGE_STAGING_TABLES();
    CALL HARMONIZER_DEMO.HARMONIZED.COMPUTE_ENSEMBLE_SCORES_ONLY();
    CALL HARMONIZER_DEMO.HARMONIZED.ROUTE_MATCHED_ITEMS();

    -- Log pipeline run
    INSERT INTO HARMONIZER_DEMO.ANALYTICS.MATCH_AUDIT_LOG
        (AUDIT_ID, MATCH_ID, ACTION, REVIEWED_BY, CREATED_AT)
    SELECT UUID_STRING(), UUID_STRING(), 'PIPELINE_RUN', CURRENT_USER(), CURRENT_TIMESTAMP();

    -- Log completion
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'RUN_MATCHING_PIPELINE', 'COMPLETED',
        :dedup_count + :fast_path_count, 0, 0, :v_started_at, NULL, NULL::VARIANT, 'SERIAL', NULL
    );

    RETURN OBJECT_CONSTRUCT(
        'status', 'complete',
        'run_id', :v_run_id,
        'dedup_count', :dedup_count,
        'fast_path_count', :fast_path_count,
        'steps', :dedup_result || ' | ' || :fast_path_result ||
                 ' | ' || :result1 || ' | ' || :result2 ||
                 ' | ' || :result3 || ' | ' || :result4
    )::VARCHAR;
EXCEPTION
    WHEN OTHER THEN
        LET err_code INTEGER := SQLCODE;
        LET err_message VARCHAR := SQLERRM;
        LET err_msg VARCHAR := 'Error: ' || err_code::VARCHAR || ' - ' || err_message;
        CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
            :v_run_id, 'RUN_MATCHING_PIPELINE', 'FAILED',
            0, 0, 1, :v_started_at, :err_msg, NULL::VARIANT, 'SERIAL', NULL
        );
        RAISE;
END;
$$;

-- ============================================================================
-- Batch AI_SIMILARITY for a set of matches
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.BATCH_AI_SIMILARITY(LIMIT_N INT DEFAULT 20)
RETURNS TABLE (
    ITEM_ID VARCHAR,
    RAW_DESCRIPTION VARCHAR,
    STANDARD_DESCRIPTION VARCHAR,
    CORTEX_SEARCH_SCORE FLOAT,
    COSINE_SCORE FLOAT,
    EDIT_DISTANCE_SCORE FLOAT,
    JACCARD_SCORE FLOAT,
    ENSEMBLE_SCORE FLOAT,
    AI_SIMILARITY_SCORE FLOAT
)
LANGUAGE SQL
COMMENT = 'Computes AI_SIMILARITY scores for top matches for comparison'
EXECUTE AS OWNER
AS
$$
DECLARE
    res RESULTSET;
BEGIN
    res := (
        SELECT
            ri.ITEM_ID,
            ri.RAW_DESCRIPTION,
            si.STANDARD_DESCRIPTION,
            im.CORTEX_SEARCH_SCORE,
            im.COSINE_SCORE,
            im.EDIT_DISTANCE_SCORE,
            im.JACCARD_SCORE,
            im.ENSEMBLE_SCORE,
            SNOWFLAKE.CORTEX.AI_SIMILARITY(ri.RAW_DESCRIPTION, si.STANDARD_DESCRIPTION) AS AI_SIMILARITY_SCORE
        FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
        JOIN HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im ON ri.ITEM_ID = im.RAW_ITEM_ID
        JOIN HARMONIZER_DEMO.RAW.STANDARD_ITEMS si ON im.SUGGESTED_STANDARD_ID = si.STANDARD_ITEM_ID
        WHERE im.ENSEMBLE_SCORE IS NOT NULL
        ORDER BY im.ENSEMBLE_SCORE DESC
        LIMIT :LIMIT_N
    );
    RETURN TABLE(res);
END;
$$;

-- ============================================================================
-- Update config setting
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.ANALYTICS.UPDATE_CONFIG(KEY_NAME VARCHAR, KEY_VALUE VARCHAR)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Updates or inserts a configuration setting'
EXECUTE AS OWNER
AS
$$
BEGIN
    -- Input validation
    IF (:KEY_NAME IS NULL OR TRIM(:KEY_NAME) = '') THEN
        RETURN 'Error: CONFIG_KEY cannot be null or empty';
    END IF;

    UPDATE HARMONIZER_DEMO.ANALYTICS.CONFIG
    SET CONFIG_VALUE = :KEY_VALUE,
        UPDATED_AT = CURRENT_TIMESTAMP()
    WHERE CONFIG_KEY = :KEY_NAME;

    IF (SQLROWCOUNT = 0) THEN
        INSERT INTO HARMONIZER_DEMO.ANALYTICS.CONFIG (CONFIG_KEY, CONFIG_VALUE)
        VALUES (:KEY_NAME, :KEY_VALUE);
    END IF;

    RETURN 'Config updated: ' || :KEY_NAME || ' = ' || :KEY_VALUE;
END;
$$;

-- ============================================================================
-- Submit a review action (confirm, change, reject, thumbs up/down)
-- Populates confirmed-match cache and ML training dataset
-- ============================================================================
-- Drop old signature to avoid overloading error
DROP PROCEDURE IF EXISTS HARMONIZER_DEMO.HARMONIZED.SUBMIT_REVIEW(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR);

CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.SUBMIT_REVIEW(
    P_MATCH_ID VARCHAR,
    P_ACTION VARCHAR,
    P_SELECTED_STANDARD_ID VARCHAR DEFAULT NULL,
    P_REVIEWER VARCHAR DEFAULT NULL,
    P_FEEDBACK VARCHAR DEFAULT NULL,
    P_COMMENT VARCHAR DEFAULT NULL,
    P_RUN_ID VARCHAR DEFAULT NULL
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Submits a review action (confirm, change, reject, thumbs up/down) and logs to audit trail'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_run_id VARCHAR;
    v_started_at TIMESTAMP_NTZ;
    v_raw_item_id VARCHAR;
    v_raw_description VARCHAR;
    v_normalized_desc VARCHAR;
    v_suggested_id VARCHAR;
    v_suggested_desc VARCHAR;
    v_selected_desc VARCHAR;
    v_ensemble_score FLOAT;
    v_reviewer VARCHAR;
    v_final_standard_id VARCHAR;
    v_error_message VARCHAR;
    v_rows_updated INTEGER DEFAULT 0;
    v_match_count INTEGER DEFAULT 0;
    v_propagated_items INTEGER DEFAULT 0;
BEGIN
    -- Initialize telemetry (removed STARTED log for performance - only log on completion/failure)
    v_run_id := COALESCE(:P_RUN_ID, UUID_STRING());
    v_started_at := CURRENT_TIMESTAMP();

    v_reviewer := COALESCE(:P_REVIEWER, CURRENT_USER());

    -- ========================================================================
    -- INPUT VALIDATION: Validate action is a known value
    -- ========================================================================
    IF (:P_ACTION IS NULL OR :P_ACTION NOT IN ('CONFIRM', 'CHANGE', 'REJECT', 'THUMBS_UP', 'THUMBS_DOWN')) THEN
        v_error_message := 'Invalid action: ' || COALESCE(:P_ACTION, 'NULL') || 
                          '. Valid actions: CONFIRM, CHANGE, REJECT, THUMBS_UP, THUMBS_DOWN';
        RETURN OBJECT_CONSTRUCT(
            'status', 'error',
            'error_type', 'INVALID_ACTION',
            'message', :v_error_message,
            'match_id', COALESCE(:P_MATCH_ID, 'NULL'),
            'run_id', :v_run_id
        )::VARCHAR;
    END IF;

    -- ========================================================================
    -- MATCH LOOKUP: Get match and raw item details
    -- ========================================================================
    -- First check if match exists
    SELECT COUNT(*) INTO :v_match_count
    FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
    WHERE MATCH_ID = :P_MATCH_ID;

    IF (:v_match_count = 0) THEN
        v_error_message := 'Match not found: ' || COALESCE(:P_MATCH_ID, 'NULL');
        RETURN OBJECT_CONSTRUCT(
            'status', 'error',
            'error_type', 'MATCH_NOT_FOUND',
            'message', :v_error_message,
            'match_id', COALESCE(:P_MATCH_ID, 'NULL'),
            'run_id', :v_run_id
        )::VARCHAR;
    END IF;

    -- Get match and raw item details (use pre-computed NORMALIZED_DESCRIPTION for performance)
    SELECT im.RAW_ITEM_ID, ri.RAW_DESCRIPTION,
           COALESCE(ri.NORMALIZED_DESCRIPTION, UPPER(TRIM(REGEXP_REPLACE(ri.RAW_DESCRIPTION, '\\s+', ' ')))),
           im.SUGGESTED_STANDARD_ID, im.ENSEMBLE_SCORE
    INTO :v_raw_item_id, :v_raw_description, :v_normalized_desc,
         :v_suggested_id, :v_ensemble_score
    FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
    JOIN HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri ON im.RAW_ITEM_ID = ri.ITEM_ID
    WHERE im.MATCH_ID = :P_MATCH_ID;

    -- Validate raw item was found (JOIN might fail if raw item deleted)
    IF (:v_raw_item_id IS NULL) THEN
        v_error_message := 'Raw item not found for match: ' || :P_MATCH_ID;
        RETURN OBJECT_CONSTRUCT(
            'status', 'error',
            'error_type', 'RAW_ITEM_NOT_FOUND',
            'message', :v_error_message,
            'match_id', :P_MATCH_ID,
            'run_id', :v_run_id
        )::VARCHAR;
    END IF;

    -- Determine which standard item was selected
    v_final_standard_id := COALESCE(:P_SELECTED_STANDARD_ID, :v_suggested_id);

    -- ========================================================================
    -- STANDARD ITEM LOOKUP: Get descriptions for audit log (with NULL handling)
    -- ========================================================================
    -- Get suggested description (may be NULL if no suggestion)
    SELECT STANDARD_DESCRIPTION INTO :v_suggested_desc
    FROM HARMONIZER_DEMO.RAW.STANDARD_ITEMS WHERE STANDARD_ITEM_ID = :v_suggested_id;

    -- Get selected description (may be NULL for REJECT action)
    IF (:v_final_standard_id IS NOT NULL) THEN
        SELECT STANDARD_DESCRIPTION INTO :v_selected_desc
        FROM HARMONIZER_DEMO.RAW.STANDARD_ITEMS WHERE STANDARD_ITEM_ID = :v_final_standard_id;
        
        -- Warn if selected standard item not found (for non-REJECT actions)
        IF (:v_selected_desc IS NULL AND :P_ACTION IN ('CONFIRM', 'CHANGE', 'THUMBS_UP')) THEN
            v_error_message := 'Selected standard item not found: ' || :v_final_standard_id;
            RETURN OBJECT_CONSTRUCT(
                'status', 'error',
                'error_type', 'STANDARD_ITEM_NOT_FOUND',
                'message', :v_error_message,
                'match_id', :P_MATCH_ID,
                'run_id', :v_run_id
            )::VARCHAR;
        END IF;
    END IF;

    -- ========================================================================
    -- UPDATE ITEM_MATCHES: Process action with row count tracking
    -- ========================================================================
    IF (:P_ACTION IN ('CONFIRM', 'THUMBS_UP')) THEN
        UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
        SET STATUS = 'USER_CONFIRMED',
            CONFIRMED_STANDARD_ID = :v_final_standard_id,
            REVIEWED_BY = :v_reviewer,
            REVIEWED_AT = CURRENT_TIMESTAMP()
        WHERE MATCH_ID = :P_MATCH_ID;
        v_rows_updated := SQLROWCOUNT;

        UPDATE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS
        SET MATCH_STATUS = 'CONFIRMED'
        WHERE ITEM_ID = :v_raw_item_id;

    ELSEIF (:P_ACTION = 'CHANGE') THEN
        UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
        SET STATUS = 'USER_CONFIRMED',
            CONFIRMED_STANDARD_ID = :v_final_standard_id,
            REVIEWED_BY = :v_reviewer,
            REVIEWED_AT = CURRENT_TIMESTAMP()
        WHERE MATCH_ID = :P_MATCH_ID;
        v_rows_updated := SQLROWCOUNT;

        UPDATE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS
        SET MATCH_STATUS = 'CONFIRMED'
        WHERE ITEM_ID = :v_raw_item_id;

    ELSEIF (:P_ACTION = 'REJECT') THEN
        UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
        SET STATUS = 'USER_REJECTED',
            REVIEWED_BY = :v_reviewer,
            REVIEWED_AT = CURRENT_TIMESTAMP()
        WHERE MATCH_ID = :P_MATCH_ID;
        v_rows_updated := SQLROWCOUNT;

        UPDATE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS
        SET MATCH_STATUS = 'REJECTED'
        WHERE ITEM_ID = :v_raw_item_id;

        -- ====================================================================
        -- SYNCHRONOUS PROPAGATION: Reject all items with same description
        -- Symmetric with CONFIRM propagation - "review once, apply to all"
        -- ====================================================================
        -- Step 1: Update ITEM_MATCHES for sibling items (same normalized description)
        UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
        SET im.STATUS = 'USER_REJECTED',
            im.MATCH_METHOD = COALESCE(im.MATCH_METHOD, '') || '+PROPAGATED',
            im.REVIEWED_BY = :v_reviewer,
            im.REVIEWED_AT = CURRENT_TIMESTAMP()
        FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
        WHERE im.RAW_ITEM_ID = ri.ITEM_ID
          AND ri.NORMALIZED_DESCRIPTION = :v_normalized_desc
          AND ri.MATCH_STATUS IN ('PENDING', 'MATCHED', 'PENDING_REVIEW')
          AND im.RAW_ITEM_ID != :v_raw_item_id
          AND im.STATUS NOT IN ('USER_CONFIRMED', 'USER_REJECTED');

        -- Step 2: Update RAW_RETAIL_ITEMS for propagated items
        UPDATE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS
        SET MATCH_STATUS = 'REJECTED',
            UPDATED_AT = CURRENT_TIMESTAMP()
        WHERE NORMALIZED_DESCRIPTION = :v_normalized_desc
          AND MATCH_STATUS IN ('PENDING', 'MATCHED', 'PENDING_REVIEW')
          AND ITEM_ID != :v_raw_item_id;

        v_propagated_items := SQLROWCOUNT;

    ELSEIF (:P_ACTION = 'THUMBS_DOWN') THEN
        -- Flag for re-evaluation, do NOT add to confirmed-match cache
        UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
        SET STATUS = 'PENDING_REVIEW',
            REVIEWED_BY = :v_reviewer,
            REVIEWED_AT = CURRENT_TIMESTAMP()
        WHERE MATCH_ID = :P_MATCH_ID;
        v_rows_updated := SQLROWCOUNT;
    END IF;

    -- Verify rows were updated (should always be 1 given earlier validation)
    IF (:v_rows_updated = 0) THEN
        v_error_message := 'No rows updated for match: ' || :P_MATCH_ID || ' with action: ' || :P_ACTION;
        RETURN OBJECT_CONSTRUCT(
            'status', 'error',
            'error_type', 'NO_ROWS_UPDATED',
            'message', :v_error_message,
            'match_id', :P_MATCH_ID,
            'run_id', :v_run_id
        )::VARCHAR;
    END IF;

    -- MERGE into CONFIRMED_MATCHES for CONFIRM, CHANGE, THUMBS_UP
    IF (:P_ACTION IN ('CONFIRM', 'CHANGE', 'THUMBS_UP')) THEN
        MERGE INTO HARMONIZER_DEMO.HARMONIZED.CONFIRMED_MATCHES tgt
        USING (
            SELECT :v_normalized_desc AS NORMALIZED_DESCRIPTION,
                   :v_final_standard_id AS STANDARD_ITEM_ID,
                   :v_ensemble_score AS CONFIDENCE_SCORE,
                   :v_reviewer AS CONFIRMED_BY
        ) src
        ON tgt.NORMALIZED_DESCRIPTION = src.NORMALIZED_DESCRIPTION
        WHEN MATCHED THEN UPDATE SET
            tgt.STANDARD_ITEM_ID = src.STANDARD_ITEM_ID,
            tgt.CONFIDENCE_SCORE = src.CONFIDENCE_SCORE,
            tgt.CONFIRMED_BY = src.CONFIRMED_BY,
            tgt.CONFIRMATION_COUNT = tgt.CONFIRMATION_COUNT + 1,
            tgt.LAST_CONFIRMED_AT = CURRENT_TIMESTAMP()
        WHEN NOT MATCHED THEN INSERT (
            CONFIRMED_MATCH_ID, NORMALIZED_DESCRIPTION, STANDARD_ITEM_ID,
            CONFIDENCE_SCORE, CONFIRMED_BY, CONFIRMATION_COUNT,
            CREATED_AT, LAST_CONFIRMED_AT
        ) VALUES (
            UUID_STRING(), src.NORMALIZED_DESCRIPTION, src.STANDARD_ITEM_ID,
            src.CONFIDENCE_SCORE, src.CONFIRMED_BY, 1,
            CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
        );

        -- ====================================================================
        -- SYNCHRONOUS PROPAGATION: Apply match to all duplicate items
        -- This implements "review once, apply to all" - when a reviewer confirms
        -- a match, all other pending items with the same normalized description
        -- are automatically resolved with the same match.
        -- PERF: Uses pre-computed NORMALIZED_DESCRIPTION column with clustering
        -- ====================================================================
        -- Step 1: Update ITEM_MATCHES for sibling items (same normalized description)
        UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
        SET im.STATUS = 'AUTO_ACCEPTED',
            im.CONFIRMED_STANDARD_ID = :v_final_standard_id,
            im.MATCH_METHOD = COALESCE(im.MATCH_METHOD, '') || '+PROPAGATED',
            im.REVIEWED_BY = :v_reviewer,
            im.REVIEWED_AT = CURRENT_TIMESTAMP()
        FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
        WHERE im.RAW_ITEM_ID = ri.ITEM_ID
          AND ri.NORMALIZED_DESCRIPTION = :v_normalized_desc
          AND ri.MATCH_STATUS IN ('PENDING', 'MATCHED', 'PENDING_REVIEW')
          AND im.RAW_ITEM_ID != :v_raw_item_id
          AND im.STATUS NOT IN ('USER_CONFIRMED', 'USER_REJECTED');

        -- Step 2: Update RAW_RETAIL_ITEMS for propagated items
        -- Use CONFIRMED status so propagated items are counted in the Confirmed KPI
        -- (customer cares about total matches confirmed, not just unique matches)
        -- NOTE: Cannot use table alias in single-table UPDATE in Snowflake scripting
        UPDATE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS
        SET MATCH_STATUS = 'CONFIRMED',
            UPDATED_AT = CURRENT_TIMESTAMP()
        WHERE NORMALIZED_DESCRIPTION = :v_normalized_desc
          AND MATCH_STATUS IN ('PENDING', 'MATCHED', 'PENDING_REVIEW')
          AND ITEM_ID != :v_raw_item_id;

        v_propagated_items := SQLROWCOUNT;
    END IF;

    -- Insert audit log record
    INSERT INTO HARMONIZER_DEMO.ANALYTICS.MATCH_AUDIT_LOG (
        AUDIT_ID, MATCH_ID, RAW_DESCRIPTION, SUGGESTED_DESCRIPTION,
        SELECTED_DESCRIPTION, ENSEMBLE_SCORE, USER_FEEDBACK,
        FEEDBACK_COMMENT, ACTION, REVIEWED_BY, CREATED_AT
    ) SELECT
        UUID_STRING(), :P_MATCH_ID, :v_raw_description, :v_suggested_desc,
        :v_selected_desc, :v_ensemble_score, :P_FEEDBACK,
        :P_COMMENT, :P_ACTION, :v_reviewer, CURRENT_TIMESTAMP();

    RETURN OBJECT_CONSTRUCT(
        'status', 'success',
        'match_id', :P_MATCH_ID,
        'action', :P_ACTION,
        'reviewer', :v_reviewer,
        'run_id', :v_run_id,
        'rows_updated', :v_rows_updated,
        'propagated_items', :v_propagated_items
    )::VARCHAR;
END;
$$;

-- ============================================================================
-- Bulk submit review actions (performance-optimized for multiple items)
-- Processes multiple items in a single call using set-based operations
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.BULK_SUBMIT_REVIEW(
    P_ITEMS VARIANT,
    P_REVIEWER VARCHAR DEFAULT NULL,
    P_RUN_ID VARCHAR DEFAULT NULL
)
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Bulk submit review actions - processes multiple items in a single call for better performance'
EXECUTE AS OWNER AS
$$
DECLARE
    v_run_id VARCHAR;
    v_started_at TIMESTAMP_NTZ;
    v_reviewer VARCHAR;
    v_total_items INTEGER := 0;
    v_success_count INTEGER := 0;
    v_error_count INTEGER := 0;
    v_propagated_total INTEGER := 0;
BEGIN
    v_run_id := COALESCE(:P_RUN_ID, UUID_STRING());
    v_started_at := CURRENT_TIMESTAMP();
    v_reviewer := COALESCE(:P_REVIEWER, CURRENT_USER());
    
    -- Get total items count
    SELECT COUNT(*) INTO :v_total_items
    FROM TABLE(FLATTEN(INPUT => :P_ITEMS));
    
    -- Create temp table with input items parsed
    CREATE OR REPLACE TEMPORARY TABLE _bulk_review_input AS
    SELECT 
        f.value:match_id::VARCHAR AS match_id,
        UPPER(f.value:action::VARCHAR) AS action,
        f.index AS item_order
    FROM TABLE(FLATTEN(INPUT => :P_ITEMS)) f
    WHERE f.value:match_id IS NOT NULL;
    
    -- Validate actions and get match details in one query
    CREATE OR REPLACE TEMPORARY TABLE _bulk_review_validated AS
    SELECT 
        bri.match_id,
        bri.action,
        bri.item_order,
        im.RAW_ITEM_ID,
        ri.RAW_DESCRIPTION,
        COALESCE(ri.NORMALIZED_DESCRIPTION, UPPER(TRIM(REGEXP_REPLACE(ri.RAW_DESCRIPTION, '\\s+', ' ')))) AS normalized_desc,
        im.SUGGESTED_STANDARD_ID,
        im.ENSEMBLE_SCORE,
        CASE 
            WHEN im.MATCH_ID IS NULL THEN 'MATCH_NOT_FOUND'
            WHEN bri.action NOT IN ('CONFIRM', 'REJECT') THEN 'INVALID_ACTION'
            ELSE 'VALID'
        END AS validation_status
    FROM _bulk_review_input bri
    LEFT JOIN HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im ON bri.match_id = im.MATCH_ID
    LEFT JOIN HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri ON im.RAW_ITEM_ID = ri.ITEM_ID;
    
    -- Count errors
    SELECT COUNT(*) INTO :v_error_count
    FROM _bulk_review_validated
    WHERE validation_status != 'VALID';
    
    -- Process CONFIRM actions - Update ITEM_MATCHES
    UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
    SET STATUS = 'USER_CONFIRMED',
        CONFIRMED_STANDARD_ID = im.SUGGESTED_STANDARD_ID,
        REVIEWED_BY = :v_reviewer,
        REVIEWED_AT = CURRENT_TIMESTAMP()
    FROM _bulk_review_validated bv
    WHERE im.MATCH_ID = bv.match_id
      AND bv.action = 'CONFIRM'
      AND bv.validation_status = 'VALID';
    
    -- Process CONFIRM actions - Update RAW_RETAIL_ITEMS
    UPDATE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
    SET MATCH_STATUS = 'CONFIRMED',
        MATCHED_STANDARD_ID = bv.SUGGESTED_STANDARD_ID,
        UPDATED_AT = CURRENT_TIMESTAMP()
    FROM _bulk_review_validated bv
    WHERE ri.ITEM_ID = bv.RAW_ITEM_ID
      AND bv.action = 'CONFIRM'
      AND bv.validation_status = 'VALID';
    
    -- Process REJECT actions - Update ITEM_MATCHES
    UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
    SET STATUS = 'USER_REJECTED',
        REVIEWED_BY = :v_reviewer,
        REVIEWED_AT = CURRENT_TIMESTAMP()
    FROM _bulk_review_validated bv
    WHERE im.MATCH_ID = bv.match_id
      AND bv.action = 'REJECT'
      AND bv.validation_status = 'VALID';
    
    -- Process REJECT actions - Update RAW_RETAIL_ITEMS
    UPDATE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
    SET MATCH_STATUS = 'REJECTED',
        UPDATED_AT = CURRENT_TIMESTAMP()
    FROM _bulk_review_validated bv
    WHERE ri.ITEM_ID = bv.RAW_ITEM_ID
      AND bv.action = 'REJECT'
      AND bv.validation_status = 'VALID';
    
    -- Add/update CONFIRMED_MATCHES for CONFIRM actions (for propagation)
    MERGE INTO HARMONIZER_DEMO.HARMONIZED.CONFIRMED_MATCHES tgt
    USING (
        SELECT DISTINCT
            bv.normalized_desc AS NORMALIZED_DESCRIPTION,
            bv.SUGGESTED_STANDARD_ID AS STANDARD_ITEM_ID,
            bv.ENSEMBLE_SCORE AS CONFIDENCE_SCORE,
            :v_reviewer AS CONFIRMED_BY
        FROM _bulk_review_validated bv
        WHERE bv.action = 'CONFIRM'
          AND bv.validation_status = 'VALID'
    ) src
    ON tgt.NORMALIZED_DESCRIPTION = src.NORMALIZED_DESCRIPTION
    WHEN MATCHED THEN UPDATE SET
        tgt.STANDARD_ITEM_ID = src.STANDARD_ITEM_ID,
        tgt.CONFIDENCE_SCORE = src.CONFIDENCE_SCORE,
        tgt.CONFIRMED_BY = src.CONFIRMED_BY,
        tgt.CONFIRMATION_COUNT = tgt.CONFIRMATION_COUNT + 1,
        tgt.LAST_CONFIRMED_AT = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (
        CONFIRMED_MATCH_ID, NORMALIZED_DESCRIPTION, STANDARD_ITEM_ID,
        CONFIDENCE_SCORE, CONFIRMED_BY, CONFIRMATION_COUNT,
        CREATED_AT, LAST_CONFIRMED_AT
    ) VALUES (
        UUID_STRING(), src.NORMALIZED_DESCRIPTION, src.STANDARD_ITEM_ID,
        src.CONFIDENCE_SCORE, src.CONFIRMED_BY, 1,
        CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
    );
    
    -- Propagate confirmations to sibling items (same normalized description)
    -- Update ITEM_MATCHES for siblings
    UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
    SET im.STATUS = 'AUTO_ACCEPTED',
        im.CONFIRMED_STANDARD_ID = bv.SUGGESTED_STANDARD_ID,
        im.MATCH_METHOD = COALESCE(im.MATCH_METHOD, '') || '+PROPAGATED',
        im.REVIEWED_BY = :v_reviewer,
        im.REVIEWED_AT = CURRENT_TIMESTAMP()
    FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
    JOIN _bulk_review_validated bv ON ri.NORMALIZED_DESCRIPTION = bv.normalized_desc
    WHERE im.RAW_ITEM_ID = ri.ITEM_ID
      AND ri.MATCH_STATUS IN ('PENDING', 'MATCHED', 'PENDING_REVIEW')
      AND im.RAW_ITEM_ID != bv.RAW_ITEM_ID
      AND im.STATUS NOT IN ('USER_CONFIRMED', 'USER_REJECTED')
      AND bv.action = 'CONFIRM'
      AND bv.validation_status = 'VALID';
    
    -- Update RAW_RETAIL_ITEMS for siblings
    UPDATE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
    SET ri.MATCH_STATUS = 'CONFIRMED',
        ri.UPDATED_AT = CURRENT_TIMESTAMP()
    FROM _bulk_review_validated bv
    WHERE ri.NORMALIZED_DESCRIPTION = bv.normalized_desc
      AND ri.MATCH_STATUS IN ('PENDING', 'MATCHED', 'PENDING_REVIEW')
      AND ri.ITEM_ID != bv.RAW_ITEM_ID
      AND bv.action = 'CONFIRM'
      AND bv.validation_status = 'VALID';
    
    v_propagated_total := SQLROWCOUNT;
    
    -- Propagate rejections to sibling items (same normalized description)
    -- Update ITEM_MATCHES for siblings - REJECT
    UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
    SET im.STATUS = 'USER_REJECTED',
        im.MATCH_METHOD = COALESCE(im.MATCH_METHOD, '') || '+PROPAGATED',
        im.REVIEWED_BY = :v_reviewer,
        im.REVIEWED_AT = CURRENT_TIMESTAMP()
    FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
    JOIN _bulk_review_validated bv ON ri.NORMALIZED_DESCRIPTION = bv.normalized_desc
    WHERE im.RAW_ITEM_ID = ri.ITEM_ID
      AND ri.MATCH_STATUS IN ('PENDING', 'MATCHED', 'PENDING_REVIEW')
      AND im.RAW_ITEM_ID != bv.RAW_ITEM_ID
      AND im.STATUS NOT IN ('USER_CONFIRMED', 'USER_REJECTED')
      AND bv.action = 'REJECT'
      AND bv.validation_status = 'VALID';
    
    -- Update RAW_RETAIL_ITEMS for siblings - REJECT
    UPDATE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
    SET ri.MATCH_STATUS = 'REJECTED',
        ri.UPDATED_AT = CURRENT_TIMESTAMP()
    FROM _bulk_review_validated bv
    WHERE ri.NORMALIZED_DESCRIPTION = bv.normalized_desc
      AND ri.MATCH_STATUS IN ('PENDING', 'MATCHED', 'PENDING_REVIEW')
      AND ri.ITEM_ID != bv.RAW_ITEM_ID
      AND bv.action = 'REJECT'
      AND bv.validation_status = 'VALID';
    
    -- Add rejected propagation count to total
    v_propagated_total := v_propagated_total + SQLROWCOUNT;
    
    -- Insert audit log entries in bulk
    INSERT INTO HARMONIZER_DEMO.ANALYTICS.MATCH_AUDIT_LOG (
        AUDIT_ID, MATCH_ID, RAW_DESCRIPTION, SUGGESTED_DESCRIPTION,
        ENSEMBLE_SCORE, ACTION, REVIEWED_BY, CREATED_AT
    )
    SELECT
        UUID_STRING(),
        bv.match_id,
        bv.RAW_DESCRIPTION,
        si.STANDARD_DESCRIPTION,
        bv.ENSEMBLE_SCORE,
        bv.action,
        :v_reviewer,
        CURRENT_TIMESTAMP()
    FROM _bulk_review_validated bv
    LEFT JOIN HARMONIZER_DEMO.RAW.STANDARD_ITEMS si ON bv.SUGGESTED_STANDARD_ID = si.STANDARD_ITEM_ID
    WHERE bv.validation_status = 'VALID';
    
    v_success_count := :v_total_items - :v_error_count;
    
    -- Log completion
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'BULK_SUBMIT_REVIEW', 'COMPLETED',
        :v_success_count, 0, :v_error_count, :v_started_at, NULL, 
        OBJECT_CONSTRUCT(
            'total_items', :v_total_items,
            'success_count', :v_success_count,
            'error_count', :v_error_count,
            'propagated_total', :v_propagated_total,
            'reviewer', :v_reviewer
        ), 
        'SERIAL', NULL
    );
    
    -- Clean up temp tables
    DROP TABLE IF EXISTS _bulk_review_input;
    DROP TABLE IF EXISTS _bulk_review_validated;
    
    -- Return summary
    RETURN OBJECT_CONSTRUCT(
        'status', 'success',
        'run_id', :v_run_id,
        'total_items', :v_total_items,
        'success_count', :v_success_count,
        'error_count', :v_error_count,
        'propagated_total', :v_propagated_total,
        'reviewer', :v_reviewer
    );

EXCEPTION
    WHEN OTHER THEN
        LET err_code INTEGER := SQLCODE;
        LET err_message VARCHAR := SQLERRM;
        LET err_msg VARCHAR := 'Error: ' || err_code::VARCHAR || ' - ' || err_message;
        
        CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
            :v_run_id, 'BULK_SUBMIT_REVIEW', 'FAILED',
            0, 0, :v_total_items, :v_started_at, :err_msg, 
            OBJECT_CONSTRUCT('error_code', :err_code, 'error_type', 'UNHANDLED_EXCEPTION'), 
            'SERIAL', NULL
        );
        
        -- Clean up on error
        DROP TABLE IF EXISTS _bulk_review_input;
        DROP TABLE IF EXISTS _bulk_review_validated;
        
        RETURN OBJECT_CONSTRUCT(
            'status', 'error',
            'run_id', :v_run_id,
            'error_code', :err_code,
            'error_message', :err_msg
        );
END;
$$;

-- ============================================================================
-- Reset pipeline (for demo reruns)
-- ============================================================================
-- Drop old signature to avoid overloading error
DROP PROCEDURE IF EXISTS HARMONIZER_DEMO.HARMONIZED.RESET_PIPELINE();

CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.RESET_PIPELINE(
    P_RUN_ID VARCHAR DEFAULT NULL
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Resets the pipeline for demo reruns - clears all matches, staging, coordination, and returns items to PENDING'
EXECUTE AS OWNER
AS
-- NOTE: This procedure runs with AUTOCOMMIT=TRUE. TRUNCATE operations are DDL and auto-commit.
-- The reset cannot be rolled back once started.
$$
DECLARE
    v_run_id VARCHAR;
    v_started_at TIMESTAMP_NTZ;
    v_rows_reset INTEGER DEFAULT 0;
    v_error_message VARCHAR;
BEGIN
    -- Initialize telemetry
    v_run_id := COALESCE(:P_RUN_ID, UUID_STRING());
    v_started_at := CURRENT_TIMESTAMP();
    
    -- Log start
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'RESET_PIPELINE', 'STARTED',
        0, 0, 0, :v_started_at, NULL, NULL::VARIANT, 'SERIAL', NULL
    );

    -- Reset all raw items to PENDING
    UPDATE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS
    SET MATCH_STATUS = 'PENDING',
        MATCHED_STANDARD_ID = NULL,
        INFERRED_CATEGORY = NULL,
        INFERRED_SUBCATEGORY = NULL,
        UPDATED_AT = CURRENT_TIMESTAMP();
    
    v_rows_reset := SQLROWCOUNT;

    -- Clear main match tables
    TRUNCATE TABLE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES;
    TRUNCATE TABLE HARMONIZER_DEMO.HARMONIZED.MATCH_CANDIDATES;

    -- Clear staging tables (matcher intermediate results)
    TRUNCATE TABLE HARMONIZER_DEMO.HARMONIZED.CORTEX_SEARCH_STAGING;
    TRUNCATE TABLE HARMONIZER_DEMO.HARMONIZED.COSINE_MATCH_STAGING;
    TRUNCATE TABLE HARMONIZER_DEMO.HARMONIZED.EDIT_MATCH_STAGING;
    TRUNCATE TABLE HARMONIZER_DEMO.HARMONIZED.JACCARD_MATCH_STAGING;

    -- Clear deduplication and batch processing tables
    TRUNCATE TABLE HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS;
    TRUNCATE TABLE HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP;
    TRUNCATE TABLE HARMONIZER_DEMO.HARMONIZED.BATCH_ITEMS;
    TRUNCATE TABLE HARMONIZER_DEMO.HARMONIZED.PIPELINE_BATCH_STATE;

    -- Clear task coordination (DAG run history)
    TRUNCATE TABLE HARMONIZER_DEMO.HARMONIZED.TASK_COORDINATION;

    -- Clear caches (confirmed matches)
    TRUNCATE TABLE HARMONIZER_DEMO.HARMONIZED.CONFIRMED_MATCHES;

    -- Clear audit log
    TRUNCATE TABLE HARMONIZER_DEMO.ANALYTICS.MATCH_AUDIT_LOG;

    -- Log completion
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'RESET_PIPELINE', 'COMPLETED',
        :v_rows_reset, 0, 0, :v_started_at, NULL, NULL::VARIANT, 'SERIAL', NULL
    );

    RETURN 'Pipeline reset complete. ' || :v_rows_reset || ' items returned to PENDING. Cleared: staging tables, task coordination, caches, audit logs.';
EXCEPTION
    WHEN OTHER THEN
        LET err_code INTEGER := SQLCODE;
        LET err_message VARCHAR := SQLERRM;
        LET err_msg VARCHAR := 'Error: ' || err_code::VARCHAR || ' - ' || err_message;
        CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
            :v_run_id, 'RESET_PIPELINE', 'FAILED',
            0, 0, 1, :v_started_at, :err_msg, NULL::VARIANT, 'SERIAL', NULL
        );
        RAISE;
END;
$$;
