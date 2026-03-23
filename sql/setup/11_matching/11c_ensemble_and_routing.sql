-- ============================================================================
-- sql/setup/11_matching/11c_ensemble_and_routing.sql
-- Retail Data Harmonizer - Ensemble Scoring and Routing Procedures
--
-- Primary ensemble file with decoupled single-responsibility procedures.
--
-- Three single-responsibility procedures:
--   1. MERGE_STAGING_TABLES - Merge 4 staging tables into ITEM_MATCHES
--   2. COMPUTE_ENSEMBLE_SCORES_ONLY - Pure 4-method weighted ensemble scoring
--   3. ROUTE_MATCHED_ITEMS - Route to HARMONIZED_ITEMS or REVIEW_QUEUE
--
-- Benefits over monolithic approach:
--   - Each procedure does exactly one thing (easier to optimize/troubleshoot)
--   - Self-healing via WHEN clause triggers (no orphan states)
--   - Independent batch limits per responsibility
--   - Clear state progression visible in ITEM_MATCHES columns
--
-- Depends on: 11b_matcher_functions.sql, 15_task_coordination.sql
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- MERGE_STAGING_TABLES
-- Single Responsibility: Merge 4 staging tables into ITEM_MATCHES
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.MERGE_STAGING_TABLES()
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Merges 4 staging tables into ITEM_MATCHES. Single responsibility: staging → ITEM_MATCHES.'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_run_id VARCHAR;
    v_search_merged INTEGER := 0;
    v_cosine_merged INTEGER := 0;
    v_edit_merged INTEGER := 0;
    v_jaccard_merged INTEGER := 0;
BEGIN
    -- Generate or inherit run_id from active batch
    BEGIN
        SELECT RUN_ID INTO v_run_id
        FROM HARMONIZER_DEMO.HARMONIZED.TASK_COORDINATION
        WHERE TASK_NAME = 'VECTOR_PREP'
          AND STATUS = 'COMPLETED'
        ORDER BY UPDATED_AT DESC
        LIMIT 1;
    EXCEPTION
        WHEN OTHER THEN v_run_id := UUID_STRING();
    END;
    
    IF (v_run_id IS NULL) THEN
        v_run_id := UUID_STRING();
    END IF;
    
    -- Register task start in coordination table
    CALL HARMONIZER_DEMO.HARMONIZED.REGISTER_TASK_START(:v_run_id, 'STAGING_MERGE');
    
    -- =========================================================================
    -- Step 1: Merge Cortex Search staging (fan-out from UNIQUE_DESC_ID)
    -- =========================================================================
    MERGE INTO HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES tgt
    USING (
        SELECT rum.RAW_ITEM_ID, stg.SEARCH_MATCHED_ID, stg.SEARCH_SCORE
        FROM (
            SELECT RAW_ITEM_ID AS UNIQUE_DESC_ID, SEARCH_MATCHED_ID, SEARCH_SCORE,
                   ROW_NUMBER() OVER (PARTITION BY RAW_ITEM_ID ORDER BY PROCESSED_AT DESC) as rn
            FROM HARMONIZER_DEMO.HARMONIZED.CORTEX_SEARCH_STAGING
        ) stg
        JOIN HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rum ON rum.UNIQUE_DESC_ID = stg.UNIQUE_DESC_ID
        WHERE stg.rn = 1
    ) src
    ON tgt.RAW_ITEM_ID = src.RAW_ITEM_ID
    WHEN MATCHED AND tgt.CORTEX_SEARCH_SCORE IS NULL THEN UPDATE SET
        SEARCH_MATCHED_ID = src.SEARCH_MATCHED_ID,
        CORTEX_SEARCH_SCORE = src.SEARCH_SCORE,
        UPDATED_AT = CURRENT_TIMESTAMP();
    
    v_search_merged := SQLROWCOUNT;
    
    -- Clear processed Cortex Search staging
    DELETE FROM HARMONIZER_DEMO.HARMONIZED.CORTEX_SEARCH_STAGING
    WHERE RAW_ITEM_ID IN (
        SELECT UNIQUE_DESC_ID FROM HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rum
        JOIN HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im ON im.RAW_ITEM_ID = rum.RAW_ITEM_ID
        WHERE im.CORTEX_SEARCH_SCORE IS NOT NULL
    );
    
    -- =========================================================================
    -- Step 2: Merge Cosine staging
    -- =========================================================================
    MERGE INTO HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES tgt
    USING (
        SELECT rum.RAW_ITEM_ID, stg.COSINE_MATCHED_ID, stg.COSINE_SCORE
        FROM (
            SELECT RAW_ITEM_ID AS UNIQUE_DESC_ID, COSINE_MATCHED_ID, COSINE_SCORE,
                   ROW_NUMBER() OVER (PARTITION BY RAW_ITEM_ID ORDER BY PROCESSED_AT DESC) as rn
            FROM HARMONIZER_DEMO.HARMONIZED.COSINE_MATCH_STAGING
        ) stg
        JOIN HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rum ON rum.UNIQUE_DESC_ID = stg.UNIQUE_DESC_ID
        WHERE stg.rn = 1
    ) src
    ON tgt.RAW_ITEM_ID = src.RAW_ITEM_ID
    WHEN MATCHED AND tgt.COSINE_SCORE IS NULL THEN UPDATE SET
        COSINE_MATCHED_ID = src.COSINE_MATCHED_ID,
        COSINE_SCORE = src.COSINE_SCORE,
        UPDATED_AT = CURRENT_TIMESTAMP();
    
    v_cosine_merged := SQLROWCOUNT;
    
    DELETE FROM HARMONIZER_DEMO.HARMONIZED.COSINE_MATCH_STAGING
    WHERE RAW_ITEM_ID IN (
        SELECT UNIQUE_DESC_ID FROM HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rum
        JOIN HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im ON im.RAW_ITEM_ID = rum.RAW_ITEM_ID
        WHERE im.COSINE_SCORE IS NOT NULL
    );
    
    -- =========================================================================
    -- Step 3: Merge Edit Distance staging
    -- =========================================================================
    MERGE INTO HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES tgt
    USING (
        SELECT rum.RAW_ITEM_ID, stg.EDIT_MATCHED_ID, stg.EDIT_SCORE
        FROM (
            SELECT RAW_ITEM_ID AS UNIQUE_DESC_ID, EDIT_MATCHED_ID, EDIT_SCORE,
                   ROW_NUMBER() OVER (PARTITION BY RAW_ITEM_ID ORDER BY PROCESSED_AT DESC) as rn
            FROM HARMONIZER_DEMO.HARMONIZED.EDIT_MATCH_STAGING
        ) stg
        JOIN HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rum ON rum.UNIQUE_DESC_ID = stg.UNIQUE_DESC_ID
        WHERE stg.rn = 1
    ) src
    ON tgt.RAW_ITEM_ID = src.RAW_ITEM_ID
    WHEN MATCHED AND tgt.EDIT_DISTANCE_SCORE IS NULL THEN UPDATE SET
        EDIT_DISTANCE_MATCHED_ID = src.EDIT_MATCHED_ID,
        EDIT_DISTANCE_SCORE = src.EDIT_SCORE,
        UPDATED_AT = CURRENT_TIMESTAMP();
    
    v_edit_merged := SQLROWCOUNT;
    
    DELETE FROM HARMONIZER_DEMO.HARMONIZED.EDIT_MATCH_STAGING
    WHERE RAW_ITEM_ID IN (
        SELECT UNIQUE_DESC_ID FROM HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rum
        JOIN HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im ON im.RAW_ITEM_ID = rum.RAW_ITEM_ID
        WHERE im.EDIT_DISTANCE_SCORE IS NOT NULL
    );
    
    -- =========================================================================
    -- Step 4: Merge Jaccard staging
    -- =========================================================================
    MERGE INTO HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES tgt
    USING (
        SELECT rum.RAW_ITEM_ID, stg.JACCARD_MATCHED_ID, stg.JACCARD_SCORE, stg.JACCARD_REASONING
        FROM (
            SELECT RAW_ITEM_ID AS UNIQUE_DESC_ID, JACCARD_MATCHED_ID, JACCARD_SCORE, JACCARD_REASONING,
                   ROW_NUMBER() OVER (PARTITION BY RAW_ITEM_ID ORDER BY PROCESSED_AT DESC) as rn
            FROM HARMONIZER_DEMO.HARMONIZED.JACCARD_MATCH_STAGING
        ) stg
        JOIN HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rum ON rum.UNIQUE_DESC_ID = stg.UNIQUE_DESC_ID
        WHERE stg.rn = 1
    ) src
    ON tgt.RAW_ITEM_ID = src.RAW_ITEM_ID
    WHEN MATCHED AND tgt.JACCARD_SCORE IS NULL THEN UPDATE SET
        JACCARD_MATCHED_ID = src.JACCARD_MATCHED_ID,
        JACCARD_SCORE = src.JACCARD_SCORE,
        JACCARD_REASONING = src.JACCARD_REASONING,
        UPDATED_AT = CURRENT_TIMESTAMP();
    
    v_jaccard_merged := SQLROWCOUNT;
    
    DELETE FROM HARMONIZER_DEMO.HARMONIZED.JACCARD_MATCH_STAGING
    WHERE RAW_ITEM_ID IN (
        SELECT UNIQUE_DESC_ID FROM HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rum
        JOIN HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im ON im.RAW_ITEM_ID = rum.RAW_ITEM_ID
        WHERE im.JACCARD_SCORE IS NOT NULL
    );
    
    -- =========================================================================
    -- Step 5: Count items ready for ensemble scoring
    -- =========================================================================
    LET v_ready_for_ensemble INTEGER := 0;
    SELECT COUNT(*) INTO v_ready_for_ensemble
    FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
    WHERE CORTEX_SEARCH_SCORE IS NOT NULL
      AND COSINE_SCORE IS NOT NULL
      AND EDIT_DISTANCE_SCORE IS NOT NULL
      AND JACCARD_SCORE IS NOT NULL
      AND ENSEMBLE_SCORE IS NULL;
    
    -- Update coordination table with COMPLETED status
    CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
        :v_run_id, 
        'STAGING_MERGE', 
        'COMPLETED',
        OBJECT_CONSTRUCT(
            'search_merged', :v_search_merged,
            'cosine_merged', :v_cosine_merged,
            'edit_merged', :v_edit_merged,
            'jaccard_merged', :v_jaccard_merged,
            'ready_for_ensemble', :v_ready_for_ensemble
        )
    );
    
    RETURN OBJECT_CONSTRUCT(
        'status', 'complete',
        'run_id', :v_run_id,
        'search_merged', :v_search_merged,
        'cosine_merged', :v_cosine_merged,
        'edit_merged', :v_edit_merged,
        'jaccard_merged', :v_jaccard_merged,
        'ready_for_ensemble', :v_ready_for_ensemble
    );
    
EXCEPTION
    WHEN OTHER THEN
        LET err_msg VARCHAR := SQLERRM;
        -- Log error to coordination table for debugging
        CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
            :v_run_id, 'STAGING_MERGE', 'FAILED',
            OBJECT_CONSTRUCT('error', :err_msg)
        );
        -- Re-raise so task fails visibly
        RAISE;
END;
$$;

-- ============================================================================
-- COMPUTE_ENSEMBLE_SCORES_ONLY
-- Single Responsibility: Compute ensemble scores using pure 4-method ensemble
-- 
-- FORMULA:
--   ensemble_score = LEAST(1.0, base_score × agreement_multiplier)
-- 
-- Where:
--   base_score = normalized weighted average of 4 vector methods
--   agreement_multiplier = 1.20 (4-way), 1.15 (3-way), 1.10 (2-way), 1.00 (none)
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.COMPUTE_ENSEMBLE_SCORES_ONLY()
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Computes ensemble scores using pure 4-method weighted average with agreement multipliers.'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_run_id VARCHAR;
    v_scored INTEGER := 0;
    -- Weights for 4-method base score
    v_w_search NUMBER(5,2);
    v_w_cosine NUMBER(5,2);
    v_w_edit NUMBER(5,2);
    v_w_jaccard NUMBER(5,2);
    -- Agreement multipliers
    v_mult_4way NUMBER(5,2);
    v_mult_3way NUMBER(5,2);
    v_mult_2way NUMBER(5,2);
BEGIN
    v_run_id := UUID_STRING();
    
    -- Register task start
    CALL HARMONIZER_DEMO.HARMONIZED.REGISTER_TASK_START(:v_run_id, 'ENSEMBLE_SCORING');
    
    -- =========================================================================
    -- Load config: Weights for 4-method normalized average
    -- =========================================================================
    SELECT TO_NUMBER(CONFIG_VALUE, 10, 2) INTO v_w_search FROM HARMONIZER_DEMO.ANALYTICS.CONFIG WHERE CONFIG_KEY = 'ENSEMBLE_WEIGHT_SEARCH';
    SELECT TO_NUMBER(CONFIG_VALUE, 10, 2) INTO v_w_cosine FROM HARMONIZER_DEMO.ANALYTICS.CONFIG WHERE CONFIG_KEY = 'ENSEMBLE_WEIGHT_COSINE';
    SELECT TO_NUMBER(CONFIG_VALUE, 10, 2) INTO v_w_edit FROM HARMONIZER_DEMO.ANALYTICS.CONFIG WHERE CONFIG_KEY = 'ENSEMBLE_WEIGHT_EDIT';
    SELECT TO_NUMBER(CONFIG_VALUE, 10, 2) INTO v_w_jaccard FROM HARMONIZER_DEMO.ANALYTICS.CONFIG WHERE CONFIG_KEY = 'ENSEMBLE_WEIGHT_JACCARD';
    
    -- =========================================================================
    -- Load config: Agreement multipliers
    -- =========================================================================
    SELECT TO_NUMBER(CONFIG_VALUE, 10, 2) INTO v_mult_4way FROM HARMONIZER_DEMO.ANALYTICS.CONFIG WHERE CONFIG_KEY = 'AGREEMENT_MULTIPLIER_4WAY';
    SELECT TO_NUMBER(CONFIG_VALUE, 10, 2) INTO v_mult_3way FROM HARMONIZER_DEMO.ANALYTICS.CONFIG WHERE CONFIG_KEY = 'AGREEMENT_MULTIPLIER_3WAY';
    SELECT TO_NUMBER(CONFIG_VALUE, 10, 2) INTO v_mult_2way FROM HARMONIZER_DEMO.ANALYTICS.CONFIG WHERE CONFIG_KEY = 'AGREEMENT_MULTIPLIER_2WAY';
    
    -- Defaults if not in CONFIG
    v_mult_4way := COALESCE(v_mult_4way, 1.20);
    v_mult_3way := COALESCE(v_mult_3way, 1.15);
    v_mult_2way := COALESCE(v_mult_2way, 1.10);
    
    -- =========================================================================
    -- Compute ensemble scores using pure 4-method ensemble
    -- Formula: LEAST(1.0, base_score × agreement_multiplier)
    -- =========================================================================
    UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
    SET 
        ENSEMBLE_SCORE = LEAST(1.0,
            -- Normalized weighted average (base score)
            (
                (:v_w_search * COALESCE(CORTEX_SEARCH_SCORE, 0) +
                 :v_w_cosine * COALESCE(COSINE_SCORE, 0) +
                 :v_w_edit * COALESCE(EDIT_DISTANCE_SCORE, 0) +
                 :v_w_jaccard * COALESCE(JACCARD_SCORE, 0))
                / (:v_w_search + :v_w_cosine + :v_w_edit + :v_w_jaccard)
            )
            *
            -- Agreement multiplier (4-way/3-way/2-way/none) - excludes string 'None'
            CASE
                -- 4-way agreement: all 4 matchers agree
                WHEN SEARCH_MATCHED_ID = COSINE_MATCHED_ID 
                     AND COSINE_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID 
                     AND EDIT_DISTANCE_MATCHED_ID = JACCARD_MATCHED_ID 
                     AND SEARCH_MATCHED_ID IS NOT NULL AND SEARCH_MATCHED_ID != 'None' THEN :v_mult_4way
                -- 3-way agreement (any 3 of 4)
                WHEN SEARCH_MATCHED_ID = COSINE_MATCHED_ID AND COSINE_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID AND SEARCH_MATCHED_ID IS NOT NULL AND SEARCH_MATCHED_ID != 'None' THEN :v_mult_3way
                WHEN SEARCH_MATCHED_ID = COSINE_MATCHED_ID AND COSINE_MATCHED_ID = JACCARD_MATCHED_ID AND SEARCH_MATCHED_ID IS NOT NULL AND SEARCH_MATCHED_ID != 'None' THEN :v_mult_3way
                WHEN SEARCH_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID AND EDIT_DISTANCE_MATCHED_ID = JACCARD_MATCHED_ID AND SEARCH_MATCHED_ID IS NOT NULL AND SEARCH_MATCHED_ID != 'None' THEN :v_mult_3way
                WHEN COSINE_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID AND EDIT_DISTANCE_MATCHED_ID = JACCARD_MATCHED_ID AND COSINE_MATCHED_ID IS NOT NULL AND COSINE_MATCHED_ID != 'None' THEN :v_mult_3way
                -- 2-way agreement (any 2 of 4)
                WHEN SEARCH_MATCHED_ID = COSINE_MATCHED_ID AND SEARCH_MATCHED_ID IS NOT NULL AND SEARCH_MATCHED_ID != 'None' THEN :v_mult_2way
                WHEN SEARCH_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID AND SEARCH_MATCHED_ID IS NOT NULL AND SEARCH_MATCHED_ID != 'None' THEN :v_mult_2way
                WHEN SEARCH_MATCHED_ID = JACCARD_MATCHED_ID AND SEARCH_MATCHED_ID IS NOT NULL AND SEARCH_MATCHED_ID != 'None' THEN :v_mult_2way
                WHEN COSINE_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID AND COSINE_MATCHED_ID IS NOT NULL AND COSINE_MATCHED_ID != 'None' THEN :v_mult_2way
                WHEN COSINE_MATCHED_ID = JACCARD_MATCHED_ID AND COSINE_MATCHED_ID IS NOT NULL AND COSINE_MATCHED_ID != 'None' THEN :v_mult_2way
                WHEN EDIT_DISTANCE_MATCHED_ID = JACCARD_MATCHED_ID AND EDIT_DISTANCE_MATCHED_ID IS NOT NULL AND EDIT_DISTANCE_MATCHED_ID != 'None' THEN :v_mult_2way
                -- No agreement
                ELSE 1.0
            END
        ),
        
        -- Majority vote for suggested match (deterministic tiebreak: highest score)
        SUGGESTED_STANDARD_ID = CASE
            -- 4-way agreement
            WHEN SEARCH_MATCHED_ID = COSINE_MATCHED_ID 
                 AND COSINE_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID 
                 AND EDIT_DISTANCE_MATCHED_ID = JACCARD_MATCHED_ID 
                 AND SEARCH_MATCHED_ID IS NOT NULL THEN SEARCH_MATCHED_ID
            -- 3-way agreement: use unanimous winner
            WHEN SEARCH_MATCHED_ID = COSINE_MATCHED_ID AND SEARCH_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID THEN SEARCH_MATCHED_ID
            WHEN SEARCH_MATCHED_ID = COSINE_MATCHED_ID AND SEARCH_MATCHED_ID = JACCARD_MATCHED_ID THEN SEARCH_MATCHED_ID
            WHEN SEARCH_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID AND SEARCH_MATCHED_ID = JACCARD_MATCHED_ID THEN SEARCH_MATCHED_ID
            WHEN COSINE_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID AND COSINE_MATCHED_ID = JACCARD_MATCHED_ID THEN COSINE_MATCHED_ID
            -- 2-way agreement: use agreeing pair
            WHEN SEARCH_MATCHED_ID = COSINE_MATCHED_ID THEN SEARCH_MATCHED_ID
            WHEN SEARCH_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID THEN SEARCH_MATCHED_ID
            WHEN SEARCH_MATCHED_ID = JACCARD_MATCHED_ID THEN SEARCH_MATCHED_ID
            WHEN COSINE_MATCHED_ID = EDIT_DISTANCE_MATCHED_ID THEN COSINE_MATCHED_ID
            WHEN COSINE_MATCHED_ID = JACCARD_MATCHED_ID THEN COSINE_MATCHED_ID
            WHEN EDIT_DISTANCE_MATCHED_ID = JACCARD_MATCHED_ID THEN EDIT_DISTANCE_MATCHED_ID
            -- No agreement: highest individual score wins
            WHEN CORTEX_SEARCH_SCORE >= GREATEST(COSINE_SCORE, EDIT_DISTANCE_SCORE, JACCARD_SCORE) THEN SEARCH_MATCHED_ID
            WHEN COSINE_SCORE >= GREATEST(CORTEX_SEARCH_SCORE, EDIT_DISTANCE_SCORE, JACCARD_SCORE) THEN COSINE_MATCHED_ID
            WHEN EDIT_DISTANCE_SCORE >= GREATEST(CORTEX_SEARCH_SCORE, COSINE_SCORE, JACCARD_SCORE) THEN EDIT_DISTANCE_MATCHED_ID
            ELSE JACCARD_MATCHED_ID
        END,
        
        UPDATED_AT = CURRENT_TIMESTAMP()
    WHERE CORTEX_SEARCH_SCORE IS NOT NULL
      AND COSINE_SCORE IS NOT NULL
      AND EDIT_DISTANCE_SCORE IS NOT NULL
      AND JACCARD_SCORE IS NOT NULL
      AND ENSEMBLE_SCORE IS NULL;
    
    v_scored := SQLROWCOUNT;
    
    -- Update coordination
    CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
        :v_run_id, 'ENSEMBLE_SCORING', 'COMPLETED',
        OBJECT_CONSTRUCT(
            'scored', :v_scored
        )
    );
    
    RETURN OBJECT_CONSTRUCT(
        'status', 'complete',
        'run_id', :v_run_id,
        'scored', :v_scored
    );
    
EXCEPTION
    WHEN OTHER THEN
        LET err_msg VARCHAR := SQLERRM;
        -- Log error to coordination table for debugging
        CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
            :v_run_id, 'ENSEMBLE_SCORING', 'FAILED',
            OBJECT_CONSTRUCT('error', :err_msg)
        );
        -- Re-raise so task fails visibly
        RAISE;
END;
$$;

-- ============================================================================
-- ROUTE_MATCHED_ITEMS
-- Single Responsibility: Route scored items to final destinations
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.ROUTE_MATCHED_ITEMS()
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Routes scored items to HARMONIZED_ITEMS or REVIEW_QUEUE based on confidence. Single responsibility: item routing.'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_run_id VARCHAR;
    v_to_harmonized INTEGER := 0;
    v_to_harmonized_direct INTEGER := 0;
    v_to_review INTEGER := 0;
    v_to_rejected INTEGER := 0;
    v_remaining INTEGER := 0;
    v_promoted INTEGER := 0;
    v_auto_accept_threshold NUMBER(5,2) := 0.80;
    v_high_confidence_threshold NUMBER(5,2) := 0.90;
BEGIN
    v_run_id := UUID_STRING();
    
    -- Register task start
    CALL HARMONIZER_DEMO.HARMONIZED.REGISTER_TASK_START(:v_run_id, 'ITEM_ROUTER');
    
    -- Load threshold from config
    BEGIN
        SELECT TO_NUMBER(CONFIG_VALUE, 10, 2) INTO v_auto_accept_threshold
        FROM HARMONIZER_DEMO.ANALYTICS.CONFIG WHERE CONFIG_KEY = 'AUTO_ACCEPT_THRESHOLD';
    EXCEPTION
        WHEN OTHER THEN v_auto_accept_threshold := 0.60;
    END;
    v_auto_accept_threshold := COALESCE(v_auto_accept_threshold, 0.60);
    
    -- =========================================================================
    -- Step 0: PROMOTE items from REVIEW_QUEUE that now meet auto-accept threshold
    -- This handles items that were previously routed to review but now qualify
    -- =========================================================================
    INSERT INTO HARMONIZER_DEMO.HARMONIZED.HARMONIZED_ITEMS (
        RAW_ITEM_ID,
        MASTER_ITEM_ID,
        ENSEMBLE_CONFIDENCE_SCORE,
        MATCH_METHOD,
        MATCH_SOURCE,
        CREATED_AT,
        CREATED_BY
    )
    SELECT 
        im.RAW_ITEM_ID,
        COALESCE(im.CONFIRMED_STANDARD_ID, im.SUGGESTED_STANDARD_ID),
        im.ENSEMBLE_SCORE,
        'PROMOTED_FROM_REVIEW',
        'DECOUPLED_PIPELINE_V2',
        CURRENT_TIMESTAMP(),
        CURRENT_USER()
    FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
    JOIN HARMONIZER_DEMO.HARMONIZED.REVIEW_QUEUE rq ON rq.RAW_ITEM_ID = im.RAW_ITEM_ID
    WHERE im.ENSEMBLE_SCORE >= :v_auto_accept_threshold
      AND rq.QUEUE_STATUS = 'PENDING'
      AND COALESCE(im.CONFIRMED_STANDARD_ID, im.SUGGESTED_STANDARD_ID) IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM HARMONIZER_DEMO.HARMONIZED.HARMONIZED_ITEMS hi
          WHERE hi.RAW_ITEM_ID = im.RAW_ITEM_ID
      );
    
    v_promoted := SQLROWCOUNT;
    
    -- Remove promoted items from REVIEW_QUEUE
    DELETE FROM HARMONIZER_DEMO.HARMONIZED.REVIEW_QUEUE
    WHERE RAW_ITEM_ID IN (
        SELECT RAW_ITEM_ID FROM HARMONIZER_DEMO.HARMONIZED.HARMONIZED_ITEMS
    );
    
    -- Update status for promoted items
    UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
    SET STATUS = 'AUTO_ACCEPTED', UPDATED_AT = CURRENT_TIMESTAMP()
    WHERE RAW_ITEM_ID IN (
        SELECT RAW_ITEM_ID FROM HARMONIZER_DEMO.HARMONIZED.HARMONIZED_ITEMS
    )
    AND STATUS = 'PENDING_REVIEW';
    
    -- =========================================================================
    -- Step 1: Insert high-confidence items into HARMONIZED_ITEMS
    -- Routes items with ENSEMBLE_SCORE >= threshold
    -- =========================================================================
    INSERT INTO HARMONIZER_DEMO.HARMONIZED.HARMONIZED_ITEMS (
        RAW_ITEM_ID,
        MASTER_ITEM_ID,
        ENSEMBLE_CONFIDENCE_SCORE,
        MATCH_METHOD,
        MATCH_SOURCE,
        CREATED_AT,
        CREATED_BY
    )
    SELECT 
        im.RAW_ITEM_ID,
        COALESCE(im.CONFIRMED_STANDARD_ID, im.SUGGESTED_STANDARD_ID),
        im.ENSEMBLE_SCORE,
        'ENSEMBLE_AGREEMENT',
        'DECOUPLED_PIPELINE_V2',
        CURRENT_TIMESTAMP(),
        CURRENT_USER()
    FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
    WHERE im.ENSEMBLE_SCORE IS NOT NULL
      AND im.ENSEMBLE_SCORE >= :v_auto_accept_threshold
      AND im.STATUS = 'PENDING_REVIEW'
      AND COALESCE(im.CONFIRMED_STANDARD_ID, im.SUGGESTED_STANDARD_ID) IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM HARMONIZER_DEMO.HARMONIZED.HARMONIZED_ITEMS hi
          WHERE hi.RAW_ITEM_ID = im.RAW_ITEM_ID
      );
    
    v_to_harmonized := SQLROWCOUNT;
    
    -- =========================================================================
    -- Step 1b: Route VERY HIGH confidence items directly (score >= 0.90)
    -- Backup catch for items that might have been missed in Step 1
    -- =========================================================================
    INSERT INTO HARMONIZER_DEMO.HARMONIZED.HARMONIZED_ITEMS (
        RAW_ITEM_ID,
        MASTER_ITEM_ID,
        ENSEMBLE_CONFIDENCE_SCORE,
        MATCH_METHOD,
        MATCH_SOURCE,
        CREATED_AT,
        CREATED_BY
    )
    SELECT 
        im.RAW_ITEM_ID,
        COALESCE(im.CONFIRMED_STANDARD_ID, im.SUGGESTED_STANDARD_ID),
        im.ENSEMBLE_SCORE,
        'HIGH_CONFIDENCE_DIRECT',
        'DECOUPLED_PIPELINE_V2',
        CURRENT_TIMESTAMP(),
        CURRENT_USER()
    FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
    WHERE im.ENSEMBLE_SCORE IS NOT NULL
      AND im.ENSEMBLE_SCORE >= :v_high_confidence_threshold
      AND im.STATUS = 'PENDING_REVIEW'
      AND COALESCE(im.CONFIRMED_STANDARD_ID, im.SUGGESTED_STANDARD_ID) IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM HARMONIZER_DEMO.HARMONIZED.HARMONIZED_ITEMS hi
          WHERE hi.RAW_ITEM_ID = im.RAW_ITEM_ID
      );
    
    v_to_harmonized_direct := SQLROWCOUNT;
    v_to_harmonized := v_to_harmonized + v_to_harmonized_direct;
    
    -- =========================================================================
    -- Step 2: Mark routed items in ITEM_MATCHES
    -- =========================================================================
    UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
    SET 
        STATUS = 'AUTO_ACCEPTED',
        UPDATED_AT = CURRENT_TIMESTAMP()
    WHERE RAW_ITEM_ID IN (
        SELECT RAW_ITEM_ID FROM HARMONIZER_DEMO.HARMONIZED.HARMONIZED_ITEMS
    )
    AND STATUS = 'PENDING_REVIEW';
    
    -- =========================================================================
    -- Step 3: Route low-confidence items to REVIEW_QUEUE
    -- Items with scores below threshold need human review
    -- =========================================================================
    INSERT INTO HARMONIZER_DEMO.HARMONIZED.REVIEW_QUEUE (
        RAW_ITEM_ID,
        SUGGESTED_MASTER_ID,
        CONFIDENCE_SCORE,
        REVIEW_REASON,
        QUEUE_STATUS,
        CREATED_AT
    )
    SELECT 
        im.RAW_ITEM_ID,
        COALESCE(im.CONFIRMED_STANDARD_ID, im.SUGGESTED_STANDARD_ID),
        im.ENSEMBLE_SCORE,
        CASE 
            WHEN im.ENSEMBLE_SCORE < 0.40 THEN 'VERY_LOW_CONFIDENCE'
            ELSE 'LOW_CONFIDENCE'
        END as REVIEW_REASON,
        'PENDING',
        CURRENT_TIMESTAMP()
    FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
    WHERE im.ENSEMBLE_SCORE IS NOT NULL
      AND im.ENSEMBLE_SCORE < :v_auto_accept_threshold
      AND im.STATUS = 'PENDING_REVIEW'
      AND COALESCE(im.CONFIRMED_STANDARD_ID, im.SUGGESTED_STANDARD_ID) IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM HARMONIZER_DEMO.HARMONIZED.REVIEW_QUEUE rq
          WHERE rq.RAW_ITEM_ID = im.RAW_ITEM_ID
      )
      AND NOT EXISTS (
          SELECT 1 FROM HARMONIZER_DEMO.HARMONIZED.HARMONIZED_ITEMS hi
          WHERE hi.RAW_ITEM_ID = im.RAW_ITEM_ID
      );
    
    v_to_review := SQLROWCOUNT;
    
    -- =========================================================================
    -- Step 4: Route NO-MATCH items to REJECTED_ITEMS
    -- Items where ALL 4 matchers have completed but returned NULL or 'None'
    -- CRITICAL: Only reject AFTER all 4 matchers have run (all scores populated)
    -- =========================================================================
    INSERT INTO HARMONIZER_DEMO.HARMONIZED.REJECTED_ITEMS (
        RAW_ITEM_ID,
        REJECTION_REASON,
        REJECTION_DETAILS,
        SEARCH_MATCHED_ID,
        COSINE_MATCHED_ID,
        EDIT_DISTANCE_MATCHED_ID,
        JACCARD_MATCHED_ID,
        CREATED_AT,
        RESOLUTION_STATUS
    )
    SELECT 
        im.RAW_ITEM_ID,
        'NO_MATCHES_FOUND',
        'All 4 matchers (Search, Cosine, Edit Distance, Jaccard) returned no viable match candidate',
        im.SEARCH_MATCHED_ID,
        im.COSINE_MATCHED_ID,
        im.EDIT_DISTANCE_MATCHED_ID,
        im.JACCARD_MATCHED_ID,
        CURRENT_TIMESTAMP(),
        'PENDING'
    FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
    WHERE im.STATUS = 'PENDING_REVIEW'
      -- CRITICAL: Only reject AFTER all 4 matchers have completed (scores populated)
      AND im.CORTEX_SEARCH_SCORE IS NOT NULL
      AND im.COSINE_SCORE IS NOT NULL
      AND im.EDIT_DISTANCE_SCORE IS NOT NULL
      AND im.JACCARD_SCORE IS NOT NULL
      -- All matchers returned NULL or 'None' matched IDs (no viable candidate)
      AND (im.SEARCH_MATCHED_ID IS NULL OR im.SEARCH_MATCHED_ID = 'None')
      AND (im.COSINE_MATCHED_ID IS NULL OR im.COSINE_MATCHED_ID = 'None')
      AND (im.EDIT_DISTANCE_MATCHED_ID IS NULL OR im.EDIT_DISTANCE_MATCHED_ID = 'None')
      AND (im.JACCARD_MATCHED_ID IS NULL OR im.JACCARD_MATCHED_ID = 'None')
      -- Not already in any destination table
      AND NOT EXISTS (
          SELECT 1 FROM HARMONIZER_DEMO.HARMONIZED.REJECTED_ITEMS ri
          WHERE ri.RAW_ITEM_ID = im.RAW_ITEM_ID
      )
      AND NOT EXISTS (
          SELECT 1 FROM HARMONIZER_DEMO.HARMONIZED.HARMONIZED_ITEMS hi
          WHERE hi.RAW_ITEM_ID = im.RAW_ITEM_ID
      )
      AND NOT EXISTS (
          SELECT 1 FROM HARMONIZER_DEMO.HARMONIZED.REVIEW_QUEUE rq
          WHERE rq.RAW_ITEM_ID = im.RAW_ITEM_ID
      );
    
    v_to_rejected := SQLROWCOUNT;
    
    -- Update status for rejected items
    UPDATE HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
    SET 
        STATUS = 'REJECTED',
        UPDATED_AT = CURRENT_TIMESTAMP()
    WHERE RAW_ITEM_ID IN (
        SELECT RAW_ITEM_ID FROM HARMONIZER_DEMO.HARMONIZED.REJECTED_ITEMS
    )
    AND STATUS = 'PENDING_REVIEW';
    
    -- =========================================================================
    -- Step 5: Mark review-routed items
    -- Note: We keep them as PENDING_REVIEW since they're still pending human review
    -- =========================================================================
    -- Items routed to review queue remain PENDING_REVIEW until human action
    -- No status update needed here - the presence in REVIEW_QUEUE indicates review state
    
    -- =========================================================================
    -- Step 6: Count unrouted items (diagnostic)
    -- =========================================================================
    SELECT COUNT(*) INTO v_remaining
    FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES
    WHERE ENSEMBLE_SCORE IS NOT NULL
      AND STATUS = 'PENDING_REVIEW'
      AND NOT EXISTS (
          SELECT 1 FROM HARMONIZER_DEMO.HARMONIZED.HARMONIZED_ITEMS hi
          WHERE hi.RAW_ITEM_ID = ITEM_MATCHES.RAW_ITEM_ID
      )
      AND NOT EXISTS (
          SELECT 1 FROM HARMONIZER_DEMO.HARMONIZED.REVIEW_QUEUE rq
          WHERE rq.RAW_ITEM_ID = ITEM_MATCHES.RAW_ITEM_ID
      );
    
    -- Update coordination
    CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
        :v_run_id, 'ITEM_ROUTER', 'COMPLETED',
        OBJECT_CONSTRUCT(
            'promoted_from_review', :v_promoted,
            'to_harmonized', :v_to_harmonized,
            'to_review', :v_to_review,
            'to_rejected', :v_to_rejected,
            'unrouted', :v_remaining,
            'auto_accept_threshold', :v_auto_accept_threshold
        )
    );
    
    RETURN OBJECT_CONSTRUCT(
        'status', 'complete',
        'run_id', :v_run_id,
        'promoted_from_review', :v_promoted,
        'to_harmonized', :v_to_harmonized,
        'to_review', :v_to_review,
        'to_rejected', :v_to_rejected,
        'unrouted', :v_remaining
    );
    
EXCEPTION
    WHEN OTHER THEN
        LET err_msg VARCHAR := SQLERRM;
        -- Log error to coordination table for debugging
        CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
            :v_run_id, 'ITEM_ROUTER', 'FAILED',
            OBJECT_CONSTRUCT('error', :err_msg)
        );
        -- Re-raise so task fails visibly
        RAISE;
END;
$$;

-- ============================================================================
-- COMPUTE_ENSEMBLE_WITH_NOTIFICATION (Wrapper for backward compatibility)
-- Calls the decoupled procedures in sequence for manual/testing use
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.COMPUTE_ENSEMBLE_WITH_NOTIFICATION(
    P_BATCH_ID VARCHAR DEFAULT NULL
)
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Backward-compatible wrapper: calls decoupled procedures in sequence. For Task DAG, use individual tasks instead.'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_merge_result VARIANT;
    v_ensemble_result VARIANT;
    v_route_result VARIANT;
BEGIN
    -- Step 1: Merge staging tables
    CALL HARMONIZER_DEMO.HARMONIZED.MERGE_STAGING_TABLES();
    v_merge_result := SQLRESULT;
    
    -- Step 2: Compute ensemble scores (pure 4-method ensemble)
    CALL HARMONIZER_DEMO.HARMONIZED.COMPUTE_ENSEMBLE_SCORES_ONLY();
    v_ensemble_result := SQLRESULT;
    
    -- Step 3: Route items
    CALL HARMONIZER_DEMO.HARMONIZED.ROUTE_MATCHED_ITEMS();
    v_route_result := SQLRESULT;
    
    RETURN OBJECT_CONSTRUCT(
        'status', 'complete',
        'merge', v_merge_result,
        'ensemble', v_ensemble_result,
        'routing', v_route_result
    );
    
EXCEPTION
    WHEN OTHER THEN
        -- Re-raise so errors are visible (individual procedures log to coordination table)
        RAISE;
END;
$$;
