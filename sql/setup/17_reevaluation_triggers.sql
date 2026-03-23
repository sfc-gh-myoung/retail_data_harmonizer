-- ============================================================================
-- sql/setup/17_reevaluation_triggers.sql
-- Retail Data Harmonizer - Re-evaluation Procedures
--
-- Creates:
--   1. TRIGGER_REEVALUATION() procedure (4 criteria)
--   2. BULK_RECONFIRM() procedure
--   3. BULK_REEVALUATE() procedure
--   4. FORCE_REEVALUATE_SCORES() procedure - full score recalculation
--
-- Depends on: 02_schema_and_tables.sql, 11_matching/, 13_admin_utilities.sql
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- TRIGGER_REEVALUATION: Flag matches for re-evaluation based on criteria
--
-- Criteria:
--   THRESHOLD_CHANGE    - Flag AUTO_ACCEPTED items below current threshold
--   STANDARD_ITEM_CHANGE - Flag matches to recently modified standard items
--   THUMBS_DOWN         - Flag auto-accepted items with negative feedback
--   PERIODIC_AUDIT      - Flag oldest N auto-accepted for spot-check
-- ============================================================================
DROP PROCEDURE IF EXISTS HARMONIZER_DEMO.HARMONIZED.TRIGGER_REEVALUATION(VARCHAR);
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.TRIGGER_REEVALUATION(
    P_CRITERIA VARCHAR,
    P_RUN_ID VARCHAR DEFAULT NULL
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Flags items for re-evaluation based on criteria (THRESHOLD_CHANGE, CATEGORY_CHANGE, etc.)'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_run_id VARCHAR;
    v_started_at TIMESTAMP_NTZ;
    v_flagged INTEGER DEFAULT 0;
    v_threshold FLOAT;
BEGIN
    v_run_id := COALESCE(:P_RUN_ID, UUID_STRING());
    v_started_at := CURRENT_TIMESTAMP();

    -- Log step start
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'TRIGGER_REEVALUATION', 'STARTED',
        0, 0, 0, :v_started_at, NULL, :P_CRITERIA, 'SERIAL', NULL
    );

    IF (:P_CRITERIA = 'THRESHOLD_CHANGE') THEN
        -- Get current auto-accept threshold
        SELECT CONFIG_VALUE::FLOAT INTO :v_threshold
        FROM HARMONIZER_DEMO.ANALYTICS.CONFIG
        WHERE CONFIG_KEY = 'AUTO_ACCEPT_THRESHOLD';

        -- Flag AUTO_ACCEPTED items whose score is below the current threshold
        UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
        SET STATUS = 'PENDING_REVIEW',
            LLM_REASONING = COALESCE(LLM_REASONING, '') ||
                ' [RE-EVAL: score ' || ROUND(ENSEMBLE_SCORE, 3) ||
                ' below threshold ' || :v_threshold || ']'
        WHERE STATUS = 'AUTO_ACCEPTED'
          AND ENSEMBLE_SCORE < :v_threshold;

        v_flagged := SQLROWCOUNT;

        -- Update raw items status for flagged matches
        UPDATE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
        SET ri.MATCH_STATUS = 'PENDING_REVIEW'
        FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
        WHERE im.RAW_ITEM_ID = ri.ITEM_ID
          AND im.STATUS = 'PENDING_REVIEW'
          AND im.LLM_REASONING LIKE '%[RE-EVAL: score%'
          AND ri.MATCH_STATUS IN ('AUTO_ACCEPTED', 'AUTO_MATCHED');

    ELSEIF (:P_CRITERIA = 'STANDARD_ITEM_CHANGE') THEN
        -- Flag matches where the standard item was modified in the last 7 days
        -- (uses STANDARD_ITEMS.CREATED_AT as a proxy for last-modified)
        UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
        SET im.STATUS = 'PENDING_REVIEW',
            im.LLM_REASONING = COALESCE(im.LLM_REASONING, '') ||
                ' [RE-EVAL: standard item modified]'
        FROM HARMONIZER_DEMO.RAW.STANDARD_ITEMS si
        WHERE (im.SUGGESTED_STANDARD_ID = si.STANDARD_ITEM_ID
               OR im.CONFIRMED_STANDARD_ID = si.STANDARD_ITEM_ID)
          AND si.CREATED_AT >= DATEADD('day', -7, CURRENT_TIMESTAMP())
          AND im.STATUS IN ('AUTO_ACCEPTED', 'USER_CONFIRMED');

        v_flagged := SQLROWCOUNT;

        -- Update raw items status
        UPDATE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
        SET ri.MATCH_STATUS = 'PENDING_REVIEW'
        FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
        WHERE im.RAW_ITEM_ID = ri.ITEM_ID
          AND im.STATUS = 'PENDING_REVIEW'
          AND im.LLM_REASONING LIKE '%[RE-EVAL: standard item modified]%'
          AND ri.MATCH_STATUS NOT IN ('PENDING', 'PENDING_REVIEW');

    ELSEIF (:P_CRITERIA = 'THUMBS_DOWN') THEN
        -- Flag auto-accepted items that already have negative feedback tag
        -- These were tagged by SUBMIT_REVIEW but may need pipeline re-run
        UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
        SET STATUS = 'PENDING_REVIEW'
        WHERE STATUS = 'AUTO_ACCEPTED'
          AND LLM_REASONING LIKE '%[RE-EVAL: negative feedback]%';

        v_flagged := SQLROWCOUNT;

        -- Update raw items status
        UPDATE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
        SET ri.MATCH_STATUS = 'PENDING_REVIEW'
        FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
        WHERE im.RAW_ITEM_ID = ri.ITEM_ID
          AND im.STATUS = 'PENDING_REVIEW'
          AND im.LLM_REASONING LIKE '%[RE-EVAL: negative feedback]%'
          AND ri.MATCH_STATUS IN ('AUTO_ACCEPTED', 'AUTO_MATCHED');

    ELSEIF (:P_CRITERIA = 'PERIODIC_AUDIT') THEN
        -- Flag the oldest 50 auto-accepted matches for spot-check
        UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
        SET STATUS = 'PENDING_REVIEW',
            LLM_REASONING = COALESCE(LLM_REASONING, '') ||
                ' [RE-EVAL: periodic audit spot-check]'
        WHERE MATCH_ID IN (
            SELECT MATCH_ID
            FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
            WHERE STATUS = 'AUTO_ACCEPTED'
            ORDER BY CREATED_AT ASC
            LIMIT 50
        );

        v_flagged := SQLROWCOUNT;

        -- Update raw items status
        UPDATE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
        SET ri.MATCH_STATUS = 'PENDING_REVIEW'
        FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
        WHERE im.RAW_ITEM_ID = ri.ITEM_ID
          AND im.STATUS = 'PENDING_REVIEW'
          AND im.LLM_REASONING LIKE '%[RE-EVAL: periodic audit%'
          AND ri.MATCH_STATUS IN ('AUTO_ACCEPTED', 'AUTO_MATCHED');

    ELSE
        CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
            :v_run_id, 'TRIGGER_REEVALUATION', 'FAILED',
            0, 0, 1, :v_started_at, 'Unknown criteria: ' || :P_CRITERIA, NULL, 'SERIAL', NULL
        );
        RETURN '{"error": "Unknown criteria: ' || :P_CRITERIA ||
               '. Valid: THRESHOLD_CHANGE, STANDARD_ITEM_CHANGE, THUMBS_DOWN, PERIODIC_AUDIT"}';
    END IF;

    -- Log the re-evaluation action
    INSERT INTO HARMONIZER_DEMO.ANALYTICS.MATCH_AUDIT_LOG (
        AUDIT_ID, ACTION, REVIEWED_BY, CREATED_AT
    ) SELECT
        UUID_STRING(), 'RE_EVALUATION_' || :P_CRITERIA,
        CURRENT_USER(), CURRENT_TIMESTAMP();

    -- Log completion
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'TRIGGER_REEVALUATION', 'COMPLETED',
        :v_flagged, 0, 0, :v_started_at, NULL, :P_CRITERIA, 'SERIAL', NULL
    );

    RETURN '{"criteria": "' || :P_CRITERIA || '", "items_flagged": ' || :v_flagged || '}';
END;
$$;

-- ============================================================================
-- BULK_RECONFIRM: Restore re-evaluated items back to accepted state
-- Used when reviewer confirms original match is still correct
-- ============================================================================
DROP PROCEDURE IF EXISTS HARMONIZER_DEMO.HARMONIZED.BULK_RECONFIRM(ARRAY);
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.BULK_RECONFIRM(
    P_MATCH_IDS ARRAY,
    P_RUN_ID VARCHAR DEFAULT NULL
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Restores re-evaluated items back to accepted state in bulk'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_run_id VARCHAR;
    v_started_at TIMESTAMP_NTZ;
    v_confirmed INTEGER DEFAULT 0;
BEGIN
    v_run_id := COALESCE(:P_RUN_ID, UUID_STRING());
    v_started_at := CURRENT_TIMESTAMP();

    -- Log step start
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'BULK_RECONFIRM', 'STARTED',
        0, 0, 0, :v_started_at, NULL, NULL, 'SERIAL', NULL
    );

    -- Restore status and strip RE-EVAL tags from LLM_REASONING
    UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
    SET STATUS = 'USER_CONFIRMED',
        LLM_REASONING = REGEXP_REPLACE(LLM_REASONING, '\\s*\\[RE-EVAL:[^\\]]*\\]', ''),
        REVIEWED_BY = CURRENT_USER(),
        REVIEWED_AT = CURRENT_TIMESTAMP()
    WHERE MATCH_ID IN (SELECT VALUE::VARCHAR FROM TABLE(FLATTEN(INPUT => :P_MATCH_IDS)))
      AND STATUS = 'PENDING_REVIEW';

    v_confirmed := SQLROWCOUNT;

    -- Update corresponding raw items
    UPDATE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
    SET ri.MATCH_STATUS = 'CONFIRMED'
    FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
    WHERE im.RAW_ITEM_ID = ri.ITEM_ID
      AND im.MATCH_ID IN (SELECT VALUE::VARCHAR FROM TABLE(FLATTEN(INPUT => :P_MATCH_IDS)))
      AND im.STATUS = 'USER_CONFIRMED';

    -- Log bulk action
    INSERT INTO HARMONIZER_DEMO.ANALYTICS.MATCH_AUDIT_LOG (
        AUDIT_ID, ACTION, REVIEWED_BY, CREATED_AT
    ) SELECT
        UUID_STRING(),
        'BULK_RECONFIRM (' || :v_confirmed || ' items)',
        CURRENT_USER(), CURRENT_TIMESTAMP();

    -- Log completion
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'BULK_RECONFIRM', 'COMPLETED',
        :v_confirmed, 0, 0, :v_started_at, NULL, NULL, 'SERIAL', NULL
    );

    RETURN '{"action": "BULK_RECONFIRM", "items_confirmed": ' || :v_confirmed || '}';
END;
$$;

-- ============================================================================
-- BULK_REEVALUATE: Trigger re-evaluation in batches for large datasets
-- Wraps TRIGGER_REEVALUATION with batch size control
-- ============================================================================
DROP PROCEDURE IF EXISTS HARMONIZER_DEMO.HARMONIZED.BULK_REEVALUATE(VARCHAR, INT);
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.BULK_REEVALUATE(
    P_CRITERIA VARCHAR,
    P_BATCH_SIZE INT DEFAULT 100,
    P_RUN_ID VARCHAR DEFAULT NULL
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Triggers re-evaluation of matches in batches based on criteria (THRESHOLD_CHANGE, PERIODIC_AUDIT, etc.)'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_run_id VARCHAR;
    v_started_at TIMESTAMP_NTZ;
    v_total_eligible INTEGER DEFAULT 0;
    v_flagged INTEGER DEFAULT 0;
    v_threshold FLOAT;
BEGIN
    v_run_id := COALESCE(:P_RUN_ID, UUID_STRING());
    v_started_at := CURRENT_TIMESTAMP();

    -- Log step start
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'BULK_REEVALUATE', 'STARTED',
        0, 0, 0, :v_started_at, NULL, :P_CRITERIA, 'SERIAL', NULL
    );

    -- Count eligible items before applying batch limit
    IF (:P_CRITERIA = 'THRESHOLD_CHANGE') THEN
        SELECT CONFIG_VALUE::FLOAT INTO :v_threshold
        FROM HARMONIZER_DEMO.ANALYTICS.CONFIG
        WHERE CONFIG_KEY = 'AUTO_ACCEPT_THRESHOLD';

        SELECT COUNT(*) INTO :v_total_eligible
        FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
        WHERE STATUS = 'AUTO_ACCEPTED'
          AND ENSEMBLE_SCORE < :v_threshold;

        -- Apply batch-limited re-evaluation
        UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
        SET STATUS = 'PENDING_REVIEW',
            LLM_REASONING = COALESCE(LLM_REASONING, '') ||
                ' [RE-EVAL: score below threshold ' || :v_threshold || ']'
        WHERE MATCH_ID IN (
            SELECT MATCH_ID
            FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
            WHERE STATUS = 'AUTO_ACCEPTED'
              AND ENSEMBLE_SCORE < :v_threshold
            ORDER BY ENSEMBLE_SCORE ASC
            LIMIT :P_BATCH_SIZE
        );

        v_flagged := SQLROWCOUNT;

    ELSEIF (:P_CRITERIA = 'PERIODIC_AUDIT') THEN
        SELECT COUNT(*) INTO :v_total_eligible
        FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
        WHERE STATUS = 'AUTO_ACCEPTED';

        UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
        SET STATUS = 'PENDING_REVIEW',
            LLM_REASONING = COALESCE(LLM_REASONING, '') ||
                ' [RE-EVAL: periodic audit spot-check]'
        WHERE MATCH_ID IN (
            SELECT MATCH_ID
            FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
            WHERE STATUS = 'AUTO_ACCEPTED'
            ORDER BY CREATED_AT ASC
            LIMIT :P_BATCH_SIZE
        );

        v_flagged := SQLROWCOUNT;

    ELSE
        -- For other criteria, delegate to TRIGGER_REEVALUATION (no batch limit)
        CALL HARMONIZER_DEMO.HARMONIZED.TRIGGER_REEVALUATION(:P_CRITERIA, :v_run_id);
        CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
            :v_run_id, 'BULK_REEVALUATE', 'COMPLETED',
            0, 0, 0, :v_started_at, NULL, 'Delegated to TRIGGER_REEVALUATION', 'SERIAL', NULL
        );
        RETURN '{"criteria": "' || :P_CRITERIA || '", "delegated_to": "TRIGGER_REEVALUATION"}';
    END IF;

    -- Update corresponding raw items
    UPDATE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
    SET ri.MATCH_STATUS = 'PENDING_REVIEW'
    FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
    WHERE im.RAW_ITEM_ID = ri.ITEM_ID
      AND im.STATUS = 'PENDING_REVIEW'
      AND im.LLM_REASONING LIKE '%[RE-EVAL:%'
      AND ri.MATCH_STATUS IN ('AUTO_ACCEPTED', 'AUTO_MATCHED');

    -- Log action
    INSERT INTO HARMONIZER_DEMO.ANALYTICS.MATCH_AUDIT_LOG (
        AUDIT_ID, ACTION, REVIEWED_BY, CREATED_AT
    ) SELECT
        UUID_STRING(),
        'BULK_REEVALUATE ' || :P_CRITERIA || ' (batch ' || :v_flagged || '/' || :v_total_eligible || ')',
        CURRENT_USER(), CURRENT_TIMESTAMP();

    -- Log completion
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'BULK_REEVALUATE', 'COMPLETED',
        :v_flagged, 0, 0, :v_started_at, NULL, :P_CRITERIA, 'SERIAL', NULL
    );

    RETURN '{"criteria": "' || :P_CRITERIA ||
           '", "batch_size": ' || :P_BATCH_SIZE ||
           ', "items_flagged": ' || :v_flagged ||
           ', "total_eligible": ' || :v_total_eligible || '}';
END;
$$;

-- ============================================================================
-- FORCE_REEVALUATE_SCORES: Reset all scores and re-run matching pipeline
--
-- Clears all matching scores for specified items (or all items) and triggers
-- the normal matching pipeline. The pipeline will re-apply all matching methods
-- including the vector consensus early-exit logic where appropriate.
--
-- Parameters:
--   P_ITEM_IDS   - Array of RAW_ITEM_IDs to reset, or NULL for all items
--   P_BATCH_SIZE - Batch size for pipeline processing (default 100)
--   P_RUN_ID     - Optional run ID for traceability
-- ============================================================================
DROP PROCEDURE IF EXISTS HARMONIZER_DEMO.HARMONIZED.FORCE_REEVALUATE_SCORES(ARRAY, INT, VARCHAR);
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.FORCE_REEVALUATE_SCORES(
    P_ITEM_IDS ARRAY DEFAULT NULL,
    P_BATCH_SIZE INT DEFAULT 100,
    P_RUN_ID VARCHAR DEFAULT NULL
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Resets all matching scores and re-runs the matching pipeline for full recalculation'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_run_id VARCHAR;
    v_batch_id VARCHAR;
    v_started_at TIMESTAMP_NTZ;
    v_items_reset INTEGER DEFAULT 0;
BEGIN
    v_run_id := COALESCE(:P_RUN_ID, UUID_STRING());
    v_batch_id := UUID_STRING();
    v_started_at := CURRENT_TIMESTAMP();

    -- Validate batch size parameter
    IF (:P_BATCH_SIZE < 1 OR :P_BATCH_SIZE > 1000) THEN
        CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
            :v_run_id, 'FORCE_REEVALUATE_SCORES', 'FAILED',
            0, 0, 1, :v_started_at, 'Invalid batch size: ' || :P_BATCH_SIZE, NULL, 'SERIAL', NULL
        );
        RETURN '{"error": "P_BATCH_SIZE must be between 1 and 1000, got: ' || :P_BATCH_SIZE || '"}';
    END IF;

    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'FORCE_REEVALUATE_SCORES', 'STARTED',
        0, 0, 0, :v_started_at, NULL, NULL, 'SERIAL', NULL
    );

    IF (:P_ITEM_IDS IS NULL) THEN
        UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
        SET CORTEX_SEARCH_SCORE = NULL,
            COSINE_SCORE = NULL,
            EDIT_DISTANCE_SCORE = NULL,
            LLM_SCORE = NULL,
            ENSEMBLE_SCORE = NULL,
            SEARCH_MATCHED_ID = NULL,
            COSINE_MATCHED_ID = NULL,
            EDIT_DISTANCE_MATCHED_ID = NULL,
            LLM_MATCHED_ID = NULL,
            SUGGESTED_STANDARD_ID = NULL,
            IS_LLM_SKIPPED = FALSE,
            LLM_SKIP_REASON = NULL,
            LLM_REASONING = NULL,
            IS_CACHED = FALSE,
            STATUS = 'PENDING_REVIEW',
            MATCH_METHOD = NULL,
            REVIEWED_BY = NULL,
            REVIEWED_AT = NULL,
            UPDATED_AT = CURRENT_TIMESTAMP();

        v_items_reset := SQLROWCOUNT;

        UPDATE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS
        SET MATCH_STATUS = 'PENDING';

        TRUNCATE TABLE HARMONIZER_DEMO.HARMONIZED.CORTEX_SEARCH_STAGING;
        TRUNCATE TABLE HARMONIZER_DEMO.HARMONIZED.COSINE_MATCH_STAGING;
        TRUNCATE TABLE HARMONIZER_DEMO.HARMONIZED.EDIT_MATCH_STAGING;

    ELSE
        UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
        SET CORTEX_SEARCH_SCORE = NULL,
            COSINE_SCORE = NULL,
            EDIT_DISTANCE_SCORE = NULL,
            LLM_SCORE = NULL,
            ENSEMBLE_SCORE = NULL,
            SEARCH_MATCHED_ID = NULL,
            COSINE_MATCHED_ID = NULL,
            EDIT_DISTANCE_MATCHED_ID = NULL,
            LLM_MATCHED_ID = NULL,
            SUGGESTED_STANDARD_ID = NULL,
            IS_LLM_SKIPPED = FALSE,
            LLM_SKIP_REASON = NULL,
            LLM_REASONING = NULL,
            IS_CACHED = FALSE,
            STATUS = 'PENDING_REVIEW',
            MATCH_METHOD = NULL,
            REVIEWED_BY = NULL,
            REVIEWED_AT = NULL,
            UPDATED_AT = CURRENT_TIMESTAMP()
        WHERE RAW_ITEM_ID IN (SELECT VALUE::VARCHAR FROM TABLE(FLATTEN(INPUT => :P_ITEM_IDS)));

        v_items_reset := SQLROWCOUNT;

        UPDATE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS
        SET MATCH_STATUS = 'PENDING'
        WHERE ITEM_ID IN (SELECT VALUE::VARCHAR FROM TABLE(FLATTEN(INPUT => :P_ITEM_IDS)));

        DELETE FROM HARMONIZER_DEMO.HARMONIZED.CORTEX_SEARCH_STAGING
        WHERE RAW_ITEM_ID IN (SELECT VALUE::VARCHAR FROM TABLE(FLATTEN(INPUT => :P_ITEM_IDS)));

        DELETE FROM HARMONIZER_DEMO.HARMONIZED.COSINE_MATCH_STAGING
        WHERE RAW_ITEM_ID IN (SELECT VALUE::VARCHAR FROM TABLE(FLATTEN(INPUT => :P_ITEM_IDS)));

        DELETE FROM HARMONIZER_DEMO.HARMONIZED.EDIT_MATCH_STAGING
        WHERE RAW_ITEM_ID IN (SELECT VALUE::VARCHAR FROM TABLE(FLATTEN(INPUT => :P_ITEM_IDS)));
    END IF;

    INSERT INTO HARMONIZER_DEMO.HARMONIZED.PIPELINE_BATCH_STATE (BATCH_ID, ITEM_COUNT, STATUS)
    VALUES (:v_batch_id, :v_items_reset, 'ACTIVE');

    CALL HARMONIZER_DEMO.HARMONIZED.RUN_MATCHING_PIPELINE(:P_BATCH_SIZE, :v_run_id);

    UPDATE HARMONIZER_DEMO.HARMONIZED.PIPELINE_BATCH_STATE
    SET STATUS = 'COMPLETED', COMPLETED_AT = CURRENT_TIMESTAMP()
    WHERE BATCH_ID = :v_batch_id;

    INSERT INTO HARMONIZER_DEMO.ANALYTICS.MATCH_AUDIT_LOG (
        AUDIT_ID, ACTION, REVIEWED_BY, CREATED_AT
    ) VALUES (
        UUID_STRING(),
        'FORCE_REEVALUATE (' || :v_items_reset || ' items)',
        CURRENT_USER(),
        CURRENT_TIMESTAMP()
    );

    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'FORCE_REEVALUATE_SCORES', 'COMPLETED',
        :v_items_reset, 0, 0, :v_started_at, NULL, NULL, 'SERIAL', NULL
    );

    RETURN '{"items_reset": ' || :v_items_reset || ', "run_id": "' || :v_run_id || '"}';
END;
$$;