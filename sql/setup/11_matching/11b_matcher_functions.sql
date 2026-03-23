-- ============================================================================
-- Retail Data Harmonization Demo
-- Script: sql/setup/11_matching/11b_matcher_functions.sql
-- Purpose: Core matching procedures (Edit Distance, Cortex Search, Cosine, LLM)
-- Depends on: 11a_cortex_search_setup.sql
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- Phase 1: Edit Distance Score Function
-- ============================================================================
-- Returns normalized edit distance similarity (1.0 = identical, 0.0 = completely different)
-- Catches typos that embeddings miss (e.g., "COKA COLA" vs "COCA COLA")
CREATE OR REPLACE FUNCTION HARMONIZER_DEMO.HARMONIZED.EDIT_DISTANCE_SCORE(str1 STRING, str2 STRING)
RETURNS FLOAT
LANGUAGE SQL
IMMUTABLE
COMMENT = 'Returns normalized edit distance similarity (1.0 = identical, 0.0 = completely different)'
AS
$$
    CASE 
        WHEN str1 IS NULL OR str2 IS NULL THEN 0.0
        WHEN LENGTH(TRIM(str1)) = 0 OR LENGTH(TRIM(str2)) = 0 THEN 0.0
        ELSE 1.0 - (
            EDITDISTANCE(UPPER(TRIM(str1)), UPPER(TRIM(str2)))::FLOAT 
            / GREATEST(LENGTH(TRIM(str1)), LENGTH(TRIM(str2)))::FLOAT
        )
    END
$$;

-- ============================================================================
-- Phase 2: Signal Agreement Detection Function (Updated for 4 signals)
-- ============================================================================
-- Counts how many signals agree on the same standard item ID
-- Used for early exit logic to skip LLM when vector methods reach consensus
CREATE OR REPLACE FUNCTION HARMONIZER_DEMO.HARMONIZED.COUNT_SIGNAL_AGREEMENT(
    search_id VARCHAR,
    cosine_id VARCHAR,
    edit_id VARCHAR,
    jaccard_id VARCHAR,
    llm_id VARCHAR
)
RETURNS INTEGER
LANGUAGE SQL
IMMUTABLE
AS
$$
    -- Count occurrences of most common non-null ID
    (SELECT MAX(cnt) FROM (
        SELECT COUNT(*) AS cnt FROM (
            SELECT search_id AS id WHERE search_id IS NOT NULL
            UNION ALL SELECT cosine_id WHERE cosine_id IS NOT NULL
            UNION ALL SELECT edit_id WHERE edit_id IS NOT NULL
            UNION ALL SELECT jaccard_id WHERE jaccard_id IS NOT NULL
            UNION ALL SELECT llm_id WHERE llm_id IS NOT NULL
        ) GROUP BY id
    ))
$$;

-- ============================================================================
-- Phase 2: Get Subcategories for Category Function
-- ============================================================================
-- Returns valid subcategories for a given category from CATEGORY_TAXONOMY
-- Used by CLASSIFY_SUBCATEGORY to get valid classification targets
CREATE OR REPLACE FUNCTION HARMONIZER_DEMO.HARMONIZED.GET_SUBCATEGORIES_FOR_CATEGORY(
    p_category VARCHAR
)
RETURNS ARRAY
LANGUAGE SQL
COMMENT = 'Returns array of valid subcategories for a given category from taxonomy'
AS
$$
    (SELECT ARRAY_AGG(DISTINCT SUBCATEGORY) 
     FROM HARMONIZER_DEMO.RAW.CATEGORY_TAXONOMY 
     WHERE CATEGORY = p_category 
       AND SUBCATEGORY IS NOT NULL 
       AND IS_ACTIVE = TRUE)
$$;

-- ============================================================================
-- STEP 4: Category classification using AI_CLASSIFY
-- Reads categories dynamically from CATEGORY_TAXONOMY; falls back to hardcoded
-- ============================================================================
-- Drop old signature to avoid overloading error
DROP PROCEDURE IF EXISTS HARMONIZER_DEMO.HARMONIZED.CLASSIFY_RAW_ITEMS(INT);

CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.CLASSIFY_RAW_ITEMS(
    BATCH_SIZE INT,
    P_RUN_ID VARCHAR DEFAULT NULL
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Classifies raw items into categories using AI_CLASSIFY with dynamic taxonomy'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_categories ARRAY;
    v_valid_categories ARRAY;
    v_cat_count INTEGER DEFAULT 0;
    v_run_id VARCHAR;
    v_started_at TIMESTAMP_NTZ;
    v_rows_updated INTEGER DEFAULT 0;
    v_rows_unknown INTEGER DEFAULT 0;
    v_result VARCHAR;
    v_error_message VARCHAR;
BEGIN
    -- Initialize telemetry
    v_run_id := COALESCE(:P_RUN_ID, UUID_STRING());
    v_started_at := CURRENT_TIMESTAMP();
    
    -- Log start
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'CLASSIFY_RAW_ITEMS', 'STARTED',
        0, 0, 0, :v_started_at, NULL, NULL, 'SERIAL', NULL
    );

    -- Attempt to load categories from taxonomy table
    BEGIN
        SELECT ARRAY_AGG(DISTINCT CATEGORY) INTO :v_categories
        FROM HARMONIZER_DEMO.RAW.CATEGORY_TAXONOMY
        WHERE IS_ACTIVE = TRUE
          AND SUBCATEGORY IS NULL;

        SELECT ARRAY_SIZE(:v_categories) INTO :v_cat_count;
    EXCEPTION
        WHEN OTHER THEN
            v_cat_count := 0;
    END;

    -- Fallback to hardcoded categories if taxonomy is empty or unavailable
    IF (:v_cat_count = 0 OR :v_categories IS NULL) THEN
        -- Try getting categories from STANDARD_ITEMS
        SELECT ARRAY_AGG(DISTINCT CATEGORY) INTO :v_categories
        FROM HARMONIZER_DEMO.RAW.STANDARD_ITEMS
        WHERE CATEGORY IS NOT NULL;
        
        -- Last resort hardcoded fallback
        IF (:v_categories IS NULL OR ARRAY_SIZE(:v_categories) = 0) THEN
            v_categories := ARRAY_CONSTRUCT('Beverages', 'Snacks', 'Condiments', 'Prepared Foods',
                'Hot Dogs & Sausages', 'Ice Cream & Frozen Treats', 'Stadium Classics', 'Burgers',
                'Chicken', 'Pizza', 'Breakfast', 'Bakery', 'Frozen', 'Alcohol', 'Healthy',
                'Grab-n-Go', 'Mexican & Tex-Mex', 'Nachos & Loaded Sides', 'Pretzels & Popcorn', 'Instant Meals');
        END IF;
    END IF;
    
    -- Store valid categories for validation (add UNKNOWN as valid output)
    v_valid_categories := ARRAY_CAT(:v_categories, ARRAY_CONSTRUCT('UNKNOWN'));

    -- Use a safer approach: classify into temp results, validate, then update
    -- This handles cases where AI_CLASSIFY returns explanatory text instead of a category
    CREATE OR REPLACE TEMPORARY TABLE HARMONIZER_DEMO.HARMONIZED._TMP_CLASSIFICATION AS
    SELECT 
        r.ITEM_ID,
        r.RAW_DESCRIPTION,
        SNOWFLAKE.CORTEX.AI_CLASSIFY(r.RAW_DESCRIPTION, :v_categories):labels[0]::VARCHAR AS RAW_CLASSIFICATION
    FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS r
    WHERE r.INFERRED_CATEGORY IS NULL
    LIMIT :BATCH_SIZE;
    
    -- Update with validated classification: use UNKNOWN if result is not a valid category
    -- or if it's too long (AI returned explanation text)
    UPDATE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS r
    SET INFERRED_CATEGORY = CASE
            WHEN t.RAW_CLASSIFICATION IS NULL THEN 'UNKNOWN'
            WHEN LENGTH(t.RAW_CLASSIFICATION) > 50 THEN 'UNKNOWN'
            WHEN NOT ARRAY_CONTAINS(t.RAW_CLASSIFICATION::VARIANT, :v_valid_categories) THEN 'UNKNOWN'
            ELSE t.RAW_CLASSIFICATION
        END,
        UPDATED_AT = CURRENT_TIMESTAMP()
    FROM HARMONIZER_DEMO.HARMONIZED._TMP_CLASSIFICATION t
    WHERE r.ITEM_ID = t.ITEM_ID;

    v_rows_updated := SQLROWCOUNT;
    
    -- Count how many were marked as UNKNOWN
    SELECT COUNT(*) INTO :v_rows_unknown
    FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS
    WHERE INFERRED_CATEGORY = 'UNKNOWN'
      AND UPDATED_AT >= :v_started_at;
    
    v_result := 'Classified ' || :v_rows_updated || ' items (' || :v_rows_unknown || ' as UNKNOWN) using ' || ARRAY_SIZE(:v_categories) || ' categories';
    
    -- Cleanup temp table
    DROP TABLE IF EXISTS HARMONIZER_DEMO.HARMONIZED._TMP_CLASSIFICATION;
    
    -- Phase 2: Chain subcategory classification for items with valid categories
    -- This enables finer-grained filtering in matching procedures
    LET v_subcat_result VARCHAR;
    CALL HARMONIZER_DEMO.HARMONIZED.CLASSIFY_SUBCATEGORY(:BATCH_SIZE, :v_run_id) INTO :v_subcat_result;
    v_result := :v_result || '; ' || :v_subcat_result;
    
    -- Log completion
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'CLASSIFY_RAW_ITEMS', 'COMPLETED',
        :v_rows_updated, 0, :v_rows_unknown, :v_started_at, NULL, NULL, 'SERIAL', NULL
    );
    
    RETURN :v_result;
EXCEPTION
    WHEN OTHER THEN
        v_error_message := SQLERRM;
        -- Cleanup temp table on error
        DROP TABLE IF EXISTS HARMONIZER_DEMO.HARMONIZED._TMP_CLASSIFICATION;
        -- Log failure
        CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
            :v_run_id, 'CLASSIFY_RAW_ITEMS', 'FAILED',
            0, 0, 1, :v_started_at, :v_error_message, NULL, 'SERIAL', NULL
        );
        RAISE;
END;
$$;

-- ============================================================================
-- CLASSIFY_UNIQUE_DESCRIPTIONS
-- ============================================================================
-- Dedicated DAG step: assigns INFERRED_CATEGORY and INFERRED_SUBCATEGORY to
-- every raw item by classifying at the unique-description level and fanning
-- the results out to all raw items that share each description.
--
-- Why a dedicated step?
--   - Classification is logically independent of embedding and matching.
--     Separating it lets the DAG express the true dependency: matching tasks
--     NEED category/subcategory, so they must wait; but embedding generation
--     (VECTOR_PREP) can start in parallel with classification because embeddings
--     are description-only and do not use category.
--   - Operating on UNIQUE_DESCRIPTIONS (one row per distinct normalized text)
--     instead of RAW_RETAIL_ITEMS eliminates N-to-1 redundant AI calls.
--     With avg 15 raw items per unique description this is a ~15x LLM cost
--     reduction for classification alone.
--   - Using AI_CLASSIFY (purpose-built multi-class classifier) instead of
--     CORTEX.COMPLETE is cheaper, faster, and always returns a valid label.
--   - Results are fanned out to RAW_RETAIL_ITEMS via RAW_TO_UNIQUE_MAP using
--     a single bulk UPDATE per classification type.
--
-- Idempotency:
--   Both category and subcategory classification are guarded with IS NULL checks
--   so re-running the procedure never overwrites existing classifications.
--
-- Task Coordination:
--   Uses TASK_COORDINATION table (message queue pattern) instead of
--   SYSTEM$SET_RETURN_VALUE / SYSTEM$GET_PREDECESSOR_RETURN_VALUE.
--
-- Parameters:
--   P_BATCH_SIZE  - max unique descriptions to classify per run (default 500)
--   P_RUN_ID      - optional correlation ID for telemetry (generated if NULL)
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.CLASSIFY_UNIQUE_DESCRIPTIONS(
    P_BATCH_SIZE  INT     DEFAULT 500,
    P_RUN_ID      VARCHAR DEFAULT NULL
)
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Classifies unique descriptions into category+subcategory using AI_CLASSIFY; fans results out to all raw items. Uses coordination table.'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_run_id            VARCHAR;
    v_started_at        TIMESTAMP_NTZ;
    v_categories        ARRAY;
    v_valid_categories  ARRAY;
    v_cat_count         INTEGER  DEFAULT 0;
    v_cat_updated       INTEGER  DEFAULT 0;
    v_cat_unknown       INTEGER  DEFAULT 0;
    v_subcat_updated    INTEGER  DEFAULT 0;
    v_subcat_skipped    INTEGER  DEFAULT 0;
    v_uniq_needing_cat  INTEGER  DEFAULT 0;
    v_uniq_needing_sub  INTEGER  DEFAULT 0;
    v_parent_status     VARIANT;
BEGIN
    -- Get run_id from parent task (DEDUP_FASTPATH) or use provided
    IF (:P_RUN_ID IS NOT NULL) THEN
        v_run_id := :P_RUN_ID;
    ELSE
        v_run_id := HARMONIZER_DEMO.HARMONIZED.GET_LATEST_RUN_ID('DEDUP_FASTPATH');
        IF (v_run_id IS NULL) THEN
            v_run_id := UUID_STRING();
        END IF;
    END IF;
    v_started_at := CURRENT_TIMESTAMP();
    
    -- Check parent task status - skip if parent skipped/failed
    v_parent_status := HARMONIZER_DEMO.HARMONIZED.GET_PARENT_TASK_STATUS('DEDUP_FASTPATH', 10);
    IF (v_parent_status IS NOT NULL AND v_parent_status:status::VARCHAR IN ('SKIPPED', 'FAILED')) THEN
        CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
            :v_run_id, 'CLASSIFY_UNIQUE', 'SKIPPED',
            OBJECT_CONSTRUCT('reason', 'Parent task DEDUP_FASTPATH was ' || v_parent_status:status::VARCHAR)
        );
        RETURN OBJECT_CONSTRUCT(
            'run_id', :v_run_id,
            'status', 'skipped',
            'reason', 'Parent task DEDUP_FASTPATH was ' || v_parent_status:status::VARCHAR
        );
    END IF;
    
    -- Register task start in coordination table
    CALL HARMONIZER_DEMO.HARMONIZED.REGISTER_TASK_START(:v_run_id, 'CLASSIFY_UNIQUE');

    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'CLASSIFY_UNIQUE_DESCRIPTIONS', 'STARTED',
        0, 0, 0, :v_started_at, NULL, NULL, 'SERIAL', NULL
    );

    -- =========================================================================
    -- Step 1: Determine valid top-level categories from taxonomy
    -- =========================================================================
    BEGIN
        SELECT ARRAY_AGG(DISTINCT CATEGORY) INTO :v_categories
        FROM HARMONIZER_DEMO.RAW.CATEGORY_TAXONOMY
        WHERE IS_ACTIVE = TRUE AND SUBCATEGORY IS NULL;

        SELECT ARRAY_SIZE(:v_categories) INTO :v_cat_count;
    EXCEPTION
        WHEN OTHER THEN v_cat_count := 0;
    END;

    IF (:v_cat_count = 0 OR :v_categories IS NULL) THEN
        -- Fallback: Get categories directly from STANDARD_ITEMS if taxonomy is empty
        SELECT ARRAY_AGG(DISTINCT CATEGORY) INTO :v_categories
        FROM HARMONIZER_DEMO.RAW.STANDARD_ITEMS
        WHERE CATEGORY IS NOT NULL;
        
        -- Last resort fallback if STANDARD_ITEMS is also empty
        IF (:v_categories IS NULL OR ARRAY_SIZE(:v_categories) = 0) THEN
            v_categories := ARRAY_CONSTRUCT('Beverages', 'Snacks', 'Condiments', 'Prepared Foods',
                'Hot Dogs & Sausages', 'Ice Cream & Frozen Treats', 'Stadium Classics', 'Burgers',
                'Chicken', 'Pizza', 'Breakfast', 'Bakery', 'Frozen', 'Alcohol', 'Healthy',
                'Grab-n-Go', 'Mexican & Tex-Mex', 'Nachos & Loaded Sides', 'Pretzels & Popcorn', 'Instant Meals');
        END IF;
    END IF;

    v_valid_categories := ARRAY_CAT(:v_categories, ARRAY_CONSTRUCT('UNKNOWN'));

    -- =========================================================================
    -- Step 2: Category classification for unique descriptions that have none
    -- One AI_CLASSIFY call per unique description (not per raw item).
    -- =========================================================================

    -- Count how many unique descriptions need category classification
    SELECT COUNT(*) INTO :v_uniq_needing_cat
    FROM HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS ud
    WHERE ud.MATCH_STATUS = 'PENDING'
      AND EXISTS (
          SELECT 1 FROM HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rum
          JOIN HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri ON ri.ITEM_ID = rum.RAW_ITEM_ID
          WHERE rum.UNIQUE_DESC_ID = ud.UNIQUE_DESC_ID
            AND (ri.INFERRED_CATEGORY IS NULL OR ri.INFERRED_CATEGORY = '')
      );

    IF (:v_uniq_needing_cat > 0) THEN

        -- Classify one representative description per unique group
        CREATE OR REPLACE TEMPORARY TABLE HARMONIZER_DEMO.HARMONIZED._TMP_UNIQ_CAT AS
        SELECT
            ud.UNIQUE_DESC_ID,
            CASE
                WHEN classified.RAW_CAT IS NULL                             THEN 'UNKNOWN'
                WHEN LENGTH(classified.RAW_CAT) > 50                        THEN 'UNKNOWN'
                WHEN NOT ARRAY_CONTAINS(classified.RAW_CAT::VARIANT, :v_valid_categories) THEN 'UNKNOWN'
                ELSE classified.RAW_CAT
            END AS INFERRED_CATEGORY
        FROM (
            SELECT
                ud2.UNIQUE_DESC_ID,
                SNOWFLAKE.CORTEX.AI_CLASSIFY(
                    ud2.NORMALIZED_DESCRIPTION, :v_categories
                ):labels[0]::VARCHAR AS RAW_CAT
            FROM HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS ud2
            JOIN HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rum ON rum.UNIQUE_DESC_ID = ud2.UNIQUE_DESC_ID
            JOIN HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri ON ri.ITEM_ID = rum.RAW_ITEM_ID
            WHERE ud2.MATCH_STATUS = 'PENDING'
              AND (ri.INFERRED_CATEGORY IS NULL OR ri.INFERRED_CATEGORY = '')
            QUALIFY ROW_NUMBER() OVER (PARTITION BY ud2.UNIQUE_DESC_ID ORDER BY ri.ITEM_ID) = 1
            LIMIT :P_BATCH_SIZE
        ) classified
        JOIN HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS ud ON ud.UNIQUE_DESC_ID = classified.UNIQUE_DESC_ID;

        -- Fan out category to all raw items sharing each unique description
        UPDATE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
        SET
            INFERRED_CATEGORY = src.INFERRED_CATEGORY,
            UPDATED_AT        = CURRENT_TIMESTAMP()
        FROM (
            SELECT rum.RAW_ITEM_ID, t.INFERRED_CATEGORY
            FROM HARMONIZER_DEMO.HARMONIZED._TMP_UNIQ_CAT t
            JOIN HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rum ON rum.UNIQUE_DESC_ID = t.UNIQUE_DESC_ID
        ) src
        WHERE ri.ITEM_ID = src.RAW_ITEM_ID
          AND (ri.INFERRED_CATEGORY IS NULL OR ri.INFERRED_CATEGORY = '');

        v_cat_updated := SQLROWCOUNT;

        SELECT COUNT(*) INTO :v_cat_unknown
        FROM HARMONIZER_DEMO.HARMONIZED._TMP_UNIQ_CAT
        WHERE INFERRED_CATEGORY = 'UNKNOWN';

        DROP TABLE IF EXISTS HARMONIZER_DEMO.HARMONIZED._TMP_UNIQ_CAT;

    END IF;

    -- =========================================================================
    -- Step 3: Subcategory classification for unique descriptions that have a
    -- valid category but no subcategory yet.
    -- =========================================================================

    SELECT COUNT(*) INTO :v_uniq_needing_sub
    FROM HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS ud
    WHERE ud.MATCH_STATUS = 'PENDING'
      AND EXISTS (
          SELECT 1 FROM HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rum
          JOIN HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri ON ri.ITEM_ID = rum.RAW_ITEM_ID
          WHERE rum.UNIQUE_DESC_ID = ud.UNIQUE_DESC_ID
            AND ri.INFERRED_CATEGORY IS NOT NULL
            AND ri.INFERRED_CATEGORY != 'UNKNOWN'
            AND ri.INFERRED_SUBCATEGORY IS NULL
      );

    IF (:v_uniq_needing_sub > 0) THEN

        -- Classify subcategory using per-category valid subcategory list
        CREATE OR REPLACE TEMPORARY TABLE HARMONIZER_DEMO.HARMONIZED._TMP_UNIQ_SUBCAT AS
        SELECT
            ud.UNIQUE_DESC_ID,
            ri_rep.INFERRED_CATEGORY,
            HARMONIZER_DEMO.HARMONIZED.GET_SUBCATEGORIES_FOR_CATEGORY(ri_rep.INFERRED_CATEGORY) AS VALID_SUBCATS,
            CASE
                WHEN HARMONIZER_DEMO.HARMONIZED.GET_SUBCATEGORIES_FOR_CATEGORY(ri_rep.INFERRED_CATEGORY) IS NULL
                  OR ARRAY_SIZE(HARMONIZER_DEMO.HARMONIZED.GET_SUBCATEGORIES_FOR_CATEGORY(ri_rep.INFERRED_CATEGORY)) = 0
                THEN NULL
                ELSE SNOWFLAKE.CORTEX.AI_CLASSIFY(
                    ud.NORMALIZED_DESCRIPTION,
                    HARMONIZER_DEMO.HARMONIZED.GET_SUBCATEGORIES_FOR_CATEGORY(ri_rep.INFERRED_CATEGORY)
                ):labels[0]::VARCHAR
            END AS RAW_SUBCAT
        FROM HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS ud
        JOIN (
            SELECT rum.UNIQUE_DESC_ID, ri2.INFERRED_CATEGORY, ri2.INFERRED_SUBCATEGORY
            FROM HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rum
            JOIN HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri2 ON ri2.ITEM_ID = rum.RAW_ITEM_ID
            WHERE ri2.INFERRED_CATEGORY IS NOT NULL
              AND ri2.INFERRED_CATEGORY != 'UNKNOWN'
              AND ri2.INFERRED_SUBCATEGORY IS NULL
            QUALIFY ROW_NUMBER() OVER (PARTITION BY rum.UNIQUE_DESC_ID ORDER BY ri2.ITEM_ID) = 1
        ) ri_rep ON ri_rep.UNIQUE_DESC_ID = ud.UNIQUE_DESC_ID
        WHERE ud.MATCH_STATUS = 'PENDING'
        LIMIT :P_BATCH_SIZE;

        SELECT COUNT(*) INTO :v_subcat_skipped
        FROM HARMONIZER_DEMO.HARMONIZED._TMP_UNIQ_SUBCAT
        WHERE VALID_SUBCATS IS NULL OR ARRAY_SIZE(VALID_SUBCATS) = 0;

        -- Fan out validated subcategory to all raw items sharing each unique description
        UPDATE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
        SET
            INFERRED_SUBCATEGORY = src.INFERRED_SUBCATEGORY,
            UPDATED_AT           = CURRENT_TIMESTAMP()
        FROM (
            SELECT rum.RAW_ITEM_ID,
                   CASE
                       WHEN t.RAW_SUBCAT IS NULL                             THEN NULL
                       WHEN LENGTH(t.RAW_SUBCAT) > 100                       THEN NULL
                       WHEN NOT ARRAY_CONTAINS(t.RAW_SUBCAT::VARIANT, t.VALID_SUBCATS) THEN NULL
                       ELSE t.RAW_SUBCAT
                   END AS INFERRED_SUBCATEGORY
            FROM HARMONIZER_DEMO.HARMONIZED._TMP_UNIQ_SUBCAT t
            JOIN HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rum ON rum.UNIQUE_DESC_ID = t.UNIQUE_DESC_ID
            WHERE t.VALID_SUBCATS IS NOT NULL AND ARRAY_SIZE(t.VALID_SUBCATS) > 0
        ) src
        WHERE ri.ITEM_ID = src.RAW_ITEM_ID
          AND ri.INFERRED_SUBCATEGORY IS NULL;

        v_subcat_updated := SQLROWCOUNT;

        DROP TABLE IF EXISTS HARMONIZER_DEMO.HARMONIZED._TMP_UNIQ_SUBCAT;

    END IF;

    -- =========================================================================
    -- Step 4: Update coordination table with completion status
    -- =========================================================================
    CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
        :v_run_id, 'CLASSIFY_UNIQUE', 'COMPLETED',
        OBJECT_CONSTRUCT(
            'cat_updated', :v_cat_updated,
            'cat_unknown', :v_cat_unknown,
            'subcat_updated', :v_subcat_updated,
            'subcat_skipped', :v_subcat_skipped
        )
    );

    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'CLASSIFY_UNIQUE_DESCRIPTIONS', 'COMPLETED',
        :v_cat_updated, 0, :v_cat_unknown, :v_started_at, NULL, NULL, 'SERIAL', NULL
    );

    RETURN OBJECT_CONSTRUCT(
        'run_id',           :v_run_id,
        'status',           'complete',
        'uniq_needed_cat',  :v_uniq_needing_cat,
        'uniq_needed_sub',  :v_uniq_needing_sub,
        'cat_updated',      :v_cat_updated,
        'cat_unknown',      :v_cat_unknown,
        'subcat_updated',   :v_subcat_updated,
        'subcat_skipped',   :v_subcat_skipped
    );

EXCEPTION
    WHEN OTHER THEN
        LET err_msg VARCHAR := SQLERRM;
        DROP TABLE IF EXISTS HARMONIZER_DEMO.HARMONIZED._TMP_UNIQ_CAT;
        DROP TABLE IF EXISTS HARMONIZER_DEMO.HARMONIZED._TMP_UNIQ_SUBCAT;
        -- Update coordination table with failure status
        CALL HARMONIZER_DEMO.HARMONIZED.UPDATE_TASK_STATUS(
            :v_run_id, 'CLASSIFY_UNIQUE', 'FAILED',
            OBJECT_CONSTRUCT('error', :err_msg)
        );
        CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
            :v_run_id, 'CLASSIFY_UNIQUE_DESCRIPTIONS', 'FAILED',
            0, 0, 1, :v_started_at, :err_msg, NULL, 'SERIAL', NULL
        );
        RETURN OBJECT_CONSTRUCT(
            'run_id', :v_run_id,
            'status', 'error',
            'error',  :err_msg
        );
END;
$$;

-- ============================================================================
-- STEP 4b: Subcategory classification using AI_CLASSIFY (Phase 2)
-- Two-phase classification: Category → Subcategory for finer-grained filtering
-- Only classifies items that have a valid category (not UNKNOWN)
-- ============================================================================
DROP PROCEDURE IF EXISTS HARMONIZER_DEMO.HARMONIZED.CLASSIFY_SUBCATEGORY(INT);

CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.CLASSIFY_SUBCATEGORY(
    BATCH_SIZE INT,
    P_RUN_ID VARCHAR DEFAULT NULL
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Phase 2 classification: assigns subcategories based on category using AI_CLASSIFY'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_run_id VARCHAR;
    v_started_at TIMESTAMP_NTZ;
    v_rows_updated INTEGER DEFAULT 0;
    v_rows_skipped INTEGER DEFAULT 0;
    v_result VARCHAR;
    v_error_message VARCHAR;
BEGIN
    -- Initialize telemetry
    v_run_id := COALESCE(:P_RUN_ID, UUID_STRING());
    v_started_at := CURRENT_TIMESTAMP();
    
    -- Log start
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'CLASSIFY_SUBCATEGORY', 'STARTED',
        0, 0, 0, :v_started_at, NULL, NULL, 'SERIAL', NULL
    );

    -- Create temp table with items needing subcategory classification
    -- Only process items with valid categories (not UNKNOWN) and no subcategory yet
    CREATE OR REPLACE TEMPORARY TABLE HARMONIZER_DEMO.HARMONIZED._TMP_SUBCAT_CLASSIFY AS
    SELECT 
        ri.ITEM_ID,
        ri.RAW_DESCRIPTION,
        ri.INFERRED_CATEGORY,
        HARMONIZER_DEMO.HARMONIZED.GET_SUBCATEGORIES_FOR_CATEGORY(ri.INFERRED_CATEGORY) AS VALID_SUBCATEGORIES
    FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
    WHERE ri.INFERRED_CATEGORY IS NOT NULL
      AND ri.INFERRED_CATEGORY != 'UNKNOWN'
      AND ri.INFERRED_SUBCATEGORY IS NULL
    LIMIT :BATCH_SIZE;

    -- Skip items where category has no subcategories defined
    SELECT COUNT(*) INTO :v_rows_skipped
    FROM HARMONIZER_DEMO.HARMONIZED._TMP_SUBCAT_CLASSIFY
    WHERE VALID_SUBCATEGORIES IS NULL OR ARRAY_SIZE(VALID_SUBCATEGORIES) = 0;

    -- Classify subcategories using AI_CLASSIFY with per-category subcategory lists
    CREATE OR REPLACE TEMPORARY TABLE HARMONIZER_DEMO.HARMONIZED._TMP_SUBCAT_RESULTS AS
    SELECT 
        t.ITEM_ID,
        t.INFERRED_CATEGORY,
        CASE 
            WHEN t.VALID_SUBCATEGORIES IS NULL OR ARRAY_SIZE(t.VALID_SUBCATEGORIES) = 0 
            THEN NULL  -- No subcategories available for this category
            ELSE SNOWFLAKE.CORTEX.AI_CLASSIFY(t.RAW_DESCRIPTION, t.VALID_SUBCATEGORIES):labels[0]::VARCHAR
        END AS RAW_SUBCATEGORY,
        t.VALID_SUBCATEGORIES
    FROM HARMONIZER_DEMO.HARMONIZED._TMP_SUBCAT_CLASSIFY t;

    -- Update raw items with validated subcategory
    UPDATE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS r
    SET INFERRED_SUBCATEGORY = CASE
            WHEN t.RAW_SUBCATEGORY IS NULL THEN NULL
            WHEN LENGTH(t.RAW_SUBCATEGORY) > 100 THEN NULL  -- AI returned explanation text
            WHEN NOT ARRAY_CONTAINS(t.RAW_SUBCATEGORY::VARIANT, t.VALID_SUBCATEGORIES) THEN NULL
            ELSE t.RAW_SUBCATEGORY
        END,
        UPDATED_AT = CURRENT_TIMESTAMP()
    FROM HARMONIZER_DEMO.HARMONIZED._TMP_SUBCAT_RESULTS t
    WHERE r.ITEM_ID = t.ITEM_ID;

    v_rows_updated := SQLROWCOUNT;
    
    -- Cleanup temp tables
    DROP TABLE IF EXISTS HARMONIZER_DEMO.HARMONIZED._TMP_SUBCAT_CLASSIFY;
    DROP TABLE IF EXISTS HARMONIZER_DEMO.HARMONIZED._TMP_SUBCAT_RESULTS;
    
    v_result := 'Subcategory classified ' || :v_rows_updated || ' items (' || :v_rows_skipped || ' skipped - no subcategories defined)';
    
    -- Log completion
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'CLASSIFY_SUBCATEGORY', 'COMPLETED',
        :v_rows_updated, 0, :v_rows_skipped, :v_started_at, NULL, NULL, 'SERIAL', NULL
    );
    
    RETURN :v_result;
EXCEPTION
    WHEN OTHER THEN
        v_error_message := SQLERRM;
        -- Cleanup temp tables on error
        DROP TABLE IF EXISTS HARMONIZER_DEMO.HARMONIZED._TMP_SUBCAT_CLASSIFY;
        DROP TABLE IF EXISTS HARMONIZER_DEMO.HARMONIZED._TMP_SUBCAT_RESULTS;
        -- Log failure
        CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
            :v_run_id, 'CLASSIFY_SUBCATEGORY', 'FAILED',
            0, 0, 1, :v_started_at, :v_error_message, NULL, 'SERIAL', NULL
        );
        RAISE;
END;
$$;

-- ============================================================================
-- STEP 5: Cortex Search matching procedure
-- ============================================================================
-- Drop old signature to avoid overloading error
DROP PROCEDURE IF EXISTS HARMONIZER_DEMO.HARMONIZED.MATCH_CORTEX_SEARCH(INT);

CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.MATCH_CORTEX_SEARCH(
    BATCH_SIZE INT,
    P_RUN_ID VARCHAR DEFAULT NULL
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run'
COMMENT = 'Matches raw items to standard items using Cortex Search Service'
EXECUTE AS OWNER
AS
$$
import json
import uuid
from datetime import datetime

def run(session, batch_size, p_run_id=None):
    db = "HARMONIZER_DEMO"
    run_id = p_run_id or str(uuid.uuid4())
    started_at = datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')
    
    # Log start
    try:
        session.sql(f"""
            CALL {db}.ANALYTICS.LOG_PIPELINE_STEP(
                '{run_id}', 'MATCH_CORTEX_SEARCH', 'STARTED',
                0, 0, 0, '{started_at}'::TIMESTAMP_NTZ, NULL, NULL, 'SERIAL', NULL
            )
        """).collect()
    except:
        pass  # Continue even if logging fails

    # Get unmatched items that have been classified
    items = session.sql(f"""
        SELECT ITEM_ID, RAW_DESCRIPTION, INFERRED_CATEGORY
        FROM {db}.RAW.RAW_RETAIL_ITEMS
        WHERE MATCH_STATUS = 'PENDING'
          AND INFERRED_CATEGORY IS NOT NULL
        LIMIT {batch_size}
    """).collect()

    if not items:
        # Log completion with 0 items
        try:
            session.sql(f"""
                CALL {db}.ANALYTICS.LOG_PIPELINE_STEP(
                    '{run_id}', 'MATCH_CORTEX_SEARCH', 'COMPLETED',
                    0, 0, 0, '{started_at}'::TIMESTAMP_NTZ, NULL, NULL, 'SERIAL', NULL
                )
            """).collect()
        except:
            pass
        return "No items to process"

    matched = 0
    failed = 0

    for item in items:
        item_id = item["ITEM_ID"]
        raw_desc = item["RAW_DESCRIPTION"]
        category = item["INFERRED_CATEGORY"]

        try:
            # Use Cortex Search Service (2-arg JSON syntax)
            safe_desc = raw_desc.replace("\\", "\\\\").replace('"', '\\"').replace("'", "''")
            safe_cat = category.replace("\\", "\\\\").replace('"', '\\"')
            query_json = (
                '{'
                f'"query": "{safe_desc}",'
                '"columns": ["STANDARD_ITEM_ID", "STANDARD_DESCRIPTION", "CATEGORY", "BRAND", "SRP"],'
                f'"filter": {{"@eq": {{"CATEGORY": "{safe_cat}"}}}},'
                '"limit": 5'
                '}'
            )
            results = session.sql(f"""
                SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
                    'HARMONIZER_DEMO.HARMONIZED.STANDARD_ITEM_SEARCH',
                    '{query_json}'
                ) AS results
            """).collect()

            if results and results[0]["RESULTS"]:
                search_results = json.loads(results[0]["RESULTS"]) if isinstance(results[0]["RESULTS"], str) else results[0]["RESULTS"]
                if "results" in search_results and search_results["results"]:
                    candidates = search_results["results"]
                    best = candidates[0]
                    
                    # Extract actual relevance score from @scores field (cosine_similarity ranges from -1 to 1)
                    # Normalize to 0-1 range: (score + 1) / 2
                    scores = best.get("@scores", {})
                    cosine_sim = scores.get("cosine_similarity", 0)
                    # Normalize from [-1, 1] to [0, 1]
                    best_score = (cosine_sim + 1) / 2 if cosine_sim else 0.5

                    # Insert top candidate as match
                    best_std_id = best.get("STANDARD_ITEM_ID", "")
                    safe_desc = best.get("STANDARD_DESCRIPTION", "").replace("'", "''")
                    match_id = str(uuid.uuid4())

                    session.sql(f"""
                        MERGE INTO {db}.HARMONIZED.ITEM_MATCHES tgt
                        USING (SELECT '{item_id}' AS RAW_ITEM_ID) src
                        ON tgt.RAW_ITEM_ID = src.RAW_ITEM_ID
                        WHEN MATCHED THEN UPDATE SET
                            CORTEX_SEARCH_SCORE = {best_score},
                            SEARCH_MATCHED_ID = '{best_std_id}',
                            UPDATED_AT = CURRENT_TIMESTAMP()
                        WHEN NOT MATCHED THEN INSERT
                            (MATCH_ID, RAW_ITEM_ID, SUGGESTED_STANDARD_ID, CORTEX_SEARCH_SCORE,
                             SEARCH_MATCHED_ID, ENSEMBLE_SCORE, MATCH_METHOD)
                        VALUES
                            ('{match_id}', '{item_id}', '{best_std_id}', {best_score},
                             '{best_std_id}', NULL, 'CORTEX_SEARCH')
                    """).collect()

                    # Insert all candidates
                    for rank, cand in enumerate(candidates):
                        cand_id = cand.get("STANDARD_ITEM_ID", "")
                        cand_desc = cand.get("STANDARD_DESCRIPTION", "").replace("'", "''")
                        
                        # Extract actual relevance score from @scores field
                        cand_scores = cand.get("@scores", {})
                        cand_cosine = cand_scores.get("cosine_similarity", 0)
                        # Normalize from [-1, 1] to [0, 1]
                        cand_score = (cand_cosine + 1) / 2 if cand_cosine else 0.5
                        
                        cand_uuid = str(uuid.uuid4())

                        session.sql(f"""
                            INSERT INTO {db}.HARMONIZED.MATCH_CANDIDATES
                                (CANDIDATE_ID, RAW_ITEM_ID, STANDARD_ITEM_ID,
                                 STANDARD_DESCRIPTION, MATCH_METHOD, CONFIDENCE_SCORE, RANK)
                            VALUES
                                ('{cand_uuid}', '{item_id}', '{cand_id}',
                                 '{cand_desc}', 'CORTEX_SEARCH', {cand_score}, {rank + 1})
                        """).collect()

                    matched += 1
        except Exception as e:
            failed += 1
            # Log error to PIPELINE_ERRORS table
            error_id = str(uuid.uuid4())
            error_msg = str(e).replace("'", "''")
            error_context = json.dumps({
                "item_id": item_id,
                "raw_description": raw_desc[:200],
                "category": category
            }).replace("'", "''")
            
            try:
                session.sql(f"""
                    INSERT INTO {db}.ANALYTICS.PIPELINE_ERRORS
                        (ERROR_ID, PROCEDURE_NAME, ERROR_MESSAGE, ERROR_CONTEXT)
                    SELECT
                        '{error_id}', 'MATCH_CORTEX_SEARCH', '{error_msg}', PARSE_JSON('{error_context}')
                """).collect()
            except:
                # If error logging fails, continue processing
                pass

    # Log completion
    try:
        session.sql(f"""
            CALL {db}.ANALYTICS.LOG_PIPELINE_STEP(
                '{run_id}', 'MATCH_CORTEX_SEARCH', 'COMPLETED',
                {matched}, 0, {failed}, '{started_at}'::TIMESTAMP_NTZ, NULL, NULL, 'SERIAL', NULL
            )
        """).collect()
    except:
        pass

    return f"Cortex Search matched {matched} of {len(items)} items"
$$;

-- ============================================================================
-- STEP 6: Cosine similarity + Edit Distance matching procedure (Phase 1 & 3)
-- ============================================================================
-- Computes both cosine similarity AND edit distance in parallel CTEs
-- Reduces round-trips and enables early exit logic
-- Drop old signature to avoid overloading error
DROP PROCEDURE IF EXISTS HARMONIZER_DEMO.HARMONIZED.MATCH_COSINE_SIMILARITY(INT);

CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.MATCH_COSINE_SIMILARITY(
    BATCH_SIZE INT,
    P_RUN_ID VARCHAR DEFAULT NULL
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Matches items using cosine similarity and edit distance'
EXECUTE AS OWNER
AS
$$
DECLARE
    rows_processed INT DEFAULT 0;
    embeddings_computed INT DEFAULT 0;
    v_run_id VARCHAR;
    v_started_at TIMESTAMP_NTZ;
    v_result VARCHAR;
    v_error_message VARCHAR;
BEGIN
    -- Initialize telemetry
    v_run_id := COALESCE(:P_RUN_ID, UUID_STRING());
    v_started_at := CURRENT_TIMESTAMP();
    
    -- Log start
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'MATCH_COSINE_SIMILARITY', 'STARTED',
        0, 0, 0, :v_started_at, NULL, NULL, 'SERIAL', NULL
    );

    -- Step 1: Populate embedding cache for items that don't have embeddings yet
    INSERT INTO HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS_EMBEDDINGS (ITEM_ID, RAW_DESCRIPTION, EMBEDDING)
    SELECT
        ri.ITEM_ID,
        ri.RAW_DESCRIPTION,
        SNOWFLAKE.CORTEX.EMBED_TEXT_1024('snowflake-arctic-embed-l-v2.0', ri.RAW_DESCRIPTION)
    FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
    WHERE ri.MATCH_STATUS = 'PENDING'
      AND ri.INFERRED_CATEGORY IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS_EMBEDDINGS re
          WHERE re.ITEM_ID = ri.ITEM_ID
      )
    LIMIT :BATCH_SIZE;
    
    embeddings_computed := SQLROWCOUNT;

    -- Step 2: Compute BOTH cosine similarity AND edit distance in parallel CTEs
    -- Phase 3: Method-level parallelization - single SQL statement computes both signals
    MERGE INTO HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES tgt
    USING (
        WITH raw_batch AS (
            SELECT
                ri.ITEM_ID,
                ri.RAW_DESCRIPTION,
                ri.INFERRED_CATEGORY,
                re.EMBEDDING AS raw_embedding
            FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
            JOIN HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS_EMBEDDINGS re ON ri.ITEM_ID = re.ITEM_ID
            WHERE ri.MATCH_STATUS = 'PENDING'
              AND ri.INFERRED_CATEGORY IS NOT NULL
            LIMIT :BATCH_SIZE
        ),
        -- Cosine similarity scoring (parallel CTE 1)
        cosine_scored AS (
            SELECT
                rb.ITEM_ID,
                se.STANDARD_ITEM_ID,
                VECTOR_COSINE_SIMILARITY(rb.raw_embedding, se.EMBEDDING) AS cosine_score,
                ROW_NUMBER() OVER (PARTITION BY rb.ITEM_ID ORDER BY VECTOR_COSINE_SIMILARITY(rb.raw_embedding, se.EMBEDDING) DESC) AS rn
            FROM raw_batch rb
            JOIN HARMONIZER_DEMO.RAW.STANDARD_ITEMS_EMBEDDINGS se ON 1=1
            JOIN HARMONIZER_DEMO.RAW.STANDARD_ITEMS si
                ON se.STANDARD_ITEM_ID = si.STANDARD_ITEM_ID
                AND si.CATEGORY = rb.INFERRED_CATEGORY
        ),
        -- Edit distance scoring (parallel CTE 2)
        edit_scored AS (
            SELECT
                rb.ITEM_ID,
                si.STANDARD_ITEM_ID,
                HARMONIZER_DEMO.HARMONIZED.EDIT_DISTANCE_SCORE(rb.RAW_DESCRIPTION, si.STANDARD_DESCRIPTION) AS edit_score,
                ROW_NUMBER() OVER (PARTITION BY rb.ITEM_ID ORDER BY HARMONIZER_DEMO.HARMONIZED.EDIT_DISTANCE_SCORE(rb.RAW_DESCRIPTION, si.STANDARD_DESCRIPTION) DESC) AS rn
            FROM raw_batch rb
            JOIN HARMONIZER_DEMO.RAW.STANDARD_ITEMS si ON si.CATEGORY = rb.INFERRED_CATEGORY
        ),
        -- Combine best matches from both methods
        combined AS (
            SELECT 
                COALESCE(c.ITEM_ID, e.ITEM_ID) AS ITEM_ID,
                c.STANDARD_ITEM_ID AS cosine_std_id,
                c.cosine_score,
                e.STANDARD_ITEM_ID AS edit_std_id,
                e.edit_score
            FROM cosine_scored c
            FULL OUTER JOIN edit_scored e ON c.ITEM_ID = e.ITEM_ID AND c.rn = 1 AND e.rn = 1
            WHERE (c.rn = 1 OR c.rn IS NULL) AND (e.rn = 1 OR e.rn IS NULL)
        )
        SELECT ITEM_ID, cosine_std_id, cosine_score, edit_std_id, edit_score
        FROM combined
    ) src
    ON tgt.RAW_ITEM_ID = src.ITEM_ID
    WHEN MATCHED THEN UPDATE SET
        COSINE_SCORE = src.cosine_score,
        COSINE_MATCHED_ID = src.cosine_std_id,
        EDIT_DISTANCE_SCORE = src.edit_score,
        EDIT_DISTANCE_MATCHED_ID = src.edit_std_id,
        UPDATED_AT = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT
        (MATCH_ID, RAW_ITEM_ID, SUGGESTED_STANDARD_ID, COSINE_SCORE, COSINE_MATCHED_ID,
         EDIT_DISTANCE_SCORE, EDIT_DISTANCE_MATCHED_ID, ENSEMBLE_SCORE, MATCH_METHOD)
    VALUES
        (UUID_STRING(), src.ITEM_ID, src.cosine_std_id, src.cosine_score, src.cosine_std_id,
         src.edit_score, src.edit_std_id, NULL, 'COSINE_EDIT');

    rows_processed := SQLROWCOUNT;

    -- Step 3: Insert top-5 candidates for BOTH methods
    INSERT INTO HARMONIZER_DEMO.HARMONIZED.MATCH_CANDIDATES
        (CANDIDATE_ID, RAW_ITEM_ID, STANDARD_ITEM_ID, STANDARD_DESCRIPTION,
         MATCH_METHOD, CONFIDENCE_SCORE, RANK)
    WITH raw_batch AS (
        SELECT
            ri.ITEM_ID,
            ri.RAW_DESCRIPTION,
            ri.INFERRED_CATEGORY,
            re.EMBEDDING AS raw_embedding
        FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
        JOIN HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS_EMBEDDINGS re ON ri.ITEM_ID = re.ITEM_ID
        JOIN HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im ON ri.ITEM_ID = im.RAW_ITEM_ID
        WHERE im.COSINE_MATCHED_ID IS NOT NULL
          AND im.UPDATED_AT >= DATEADD('minute', -60, CURRENT_TIMESTAMP())
        LIMIT :BATCH_SIZE
    ),
    -- Cosine candidates
    cosine_cands AS (
        SELECT
            rb.ITEM_ID,
            se.STANDARD_ITEM_ID,
            si.STANDARD_DESCRIPTION,
            'COSINE_SIMILARITY' AS method,
            VECTOR_COSINE_SIMILARITY(rb.raw_embedding, se.EMBEDDING) AS score,
            ROW_NUMBER() OVER (PARTITION BY rb.ITEM_ID ORDER BY VECTOR_COSINE_SIMILARITY(rb.raw_embedding, se.EMBEDDING) DESC) AS rn
        FROM raw_batch rb
        JOIN HARMONIZER_DEMO.RAW.STANDARD_ITEMS_EMBEDDINGS se ON 1=1
        JOIN HARMONIZER_DEMO.RAW.STANDARD_ITEMS si
            ON se.STANDARD_ITEM_ID = si.STANDARD_ITEM_ID
            AND si.CATEGORY = rb.INFERRED_CATEGORY
    ),
    -- Edit distance candidates
    edit_cands AS (
        SELECT
            rb.ITEM_ID,
            si.STANDARD_ITEM_ID,
            si.STANDARD_DESCRIPTION,
            'EDIT_DISTANCE' AS method,
            HARMONIZER_DEMO.HARMONIZED.EDIT_DISTANCE_SCORE(rb.RAW_DESCRIPTION, si.STANDARD_DESCRIPTION) AS score,
            ROW_NUMBER() OVER (PARTITION BY rb.ITEM_ID ORDER BY HARMONIZER_DEMO.HARMONIZED.EDIT_DISTANCE_SCORE(rb.RAW_DESCRIPTION, si.STANDARD_DESCRIPTION) DESC) AS rn
        FROM raw_batch rb
        JOIN HARMONIZER_DEMO.RAW.STANDARD_ITEMS si ON si.CATEGORY = rb.INFERRED_CATEGORY
    ),
    all_cands AS (
        SELECT * FROM cosine_cands WHERE rn <= 5
        UNION ALL
        SELECT * FROM edit_cands WHERE rn <= 5
    )
    SELECT UUID_STRING(), ITEM_ID, STANDARD_ITEM_ID, STANDARD_DESCRIPTION, method, score, rn
    FROM all_cands;

    v_result := 'Cosine+Edit: computed ' || :embeddings_computed || ' new embeddings, matched ' || :rows_processed || ' items';
    
    -- Log completion
    CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
        :v_run_id, 'MATCH_COSINE_SIMILARITY', 'COMPLETED',
        :rows_processed, 0, 0, :v_started_at, NULL, NULL, 'SERIAL', NULL
    );
    
    RETURN :v_result;
EXCEPTION
    WHEN OTHER THEN
        v_error_message := SQLERRM;
        -- Log failure
        CALL HARMONIZER_DEMO.ANALYTICS.LOG_PIPELINE_STEP(
            :v_run_id, 'MATCH_COSINE_SIMILARITY', 'FAILED',
            0, 0, 1, :v_started_at, :v_error_message, NULL, 'SERIAL', NULL
        );
        RAISE;
END;
$$;

-- ============================================================================
-- STEP 7: LLM semantic matching procedure (Phase 2 & 4: Early Exit + Caching)
-- ============================================================================
-- Includes:
--   - Phase 2: Early exit when 3+ vector signals agree with high confidence
--   - Phase 4: LLM response cache lookup before making LLM calls
-- Drop old signature to avoid overloading error
DROP PROCEDURE IF EXISTS HARMONIZER_DEMO.HARMONIZED.MATCH_LLM_SEMANTIC(INT);

CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.MATCH_LLM_SEMANTIC(
    BATCH_SIZE INT,
    P_RUN_ID VARCHAR DEFAULT NULL
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run'
COMMENT = 'LLM semantic matching with early exit and caching'
EXECUTE AS OWNER
AS
$$
import json
import uuid
import re
import hashlib
from datetime import datetime

def run(session, batch_size, p_run_id=None):
    db = "HARMONIZER_DEMO"
    run_id = p_run_id or str(uuid.uuid4())
    started_at = datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')
    
    # Log start
    try:
        session.sql(f"""
            CALL {db}.ANALYTICS.LOG_PIPELINE_STEP(
                '{run_id}', 'MATCH_LLM_SEMANTIC', 'STARTED',
                0, 0, 0, '{started_at}'::TIMESTAMP_NTZ, NULL, NULL, 'SERIAL', NULL
            )
        """).collect()
    except:
        pass

    # Get config values
    config = {}
    config_rows = session.sql(f"""
        SELECT CONFIG_KEY, CONFIG_VALUE FROM {db}.ANALYTICS.CONFIG
        WHERE CONFIG_KEY IN ('LLM_MODEL', 'EARLY_EXIT_ENABLED', 'EARLY_EXIT_3WAY_THRESHOLD', 'EARLY_EXIT_2WAY_THRESHOLD')
    """).collect()
    for row in config_rows:
        config[row["CONFIG_KEY"]] = row["CONFIG_VALUE"]
    
    model = config.get("LLM_MODEL", "mistral-large2")
    early_exit_enabled = config.get("EARLY_EXIT_ENABLED", "true").lower() == "true"
    threshold_3way = float(config.get("EARLY_EXIT_3WAY_THRESHOLD", "0.85"))
    threshold_2way = float(config.get("EARLY_EXIT_2WAY_THRESHOLD", "0.90"))

    # Get items that already have cosine/search/edit candidates but no LLM score
    items = session.sql(f"""
        SELECT DISTINCT
            ri.ITEM_ID,
            ri.RAW_DESCRIPTION,
            ri.INFERRED_CATEGORY,
            im.SEARCH_MATCHED_ID,
            im.COSINE_MATCHED_ID,
            im.EDIT_DISTANCE_MATCHED_ID,
            im.CORTEX_SEARCH_SCORE,
            im.COSINE_SCORE,
            im.EDIT_DISTANCE_SCORE
        FROM {db}.RAW.RAW_RETAIL_ITEMS ri
        JOIN {db}.HARMONIZED.ITEM_MATCHES im ON ri.ITEM_ID = im.RAW_ITEM_ID
        WHERE im.LLM_SCORE IS NULL
          AND im.IS_LLM_SKIPPED = FALSE
          AND (im.CORTEX_SEARCH_SCORE IS NOT NULL OR im.COSINE_SCORE IS NOT NULL)
        LIMIT {batch_size}
    """).collect()

    if not items:
        # Log completion with 0 items
        try:
            session.sql(f"""
                CALL {db}.ANALYTICS.LOG_PIPELINE_STEP(
                    '{run_id}', 'MATCH_LLM_SEMANTIC', 'COMPLETED',
                    0, 0, 0, '{started_at}'::TIMESTAMP_NTZ, NULL, NULL, 'SERIAL', NULL
                )
            """).collect()
        except:
            pass
        return "No items to process for LLM matching"

    matched = 0
    skipped = 0
    cache_hits = 0
    failed = 0

    for item in items:
        item_id = item["ITEM_ID"]
        raw_desc = item["RAW_DESCRIPTION"]
        category = item["INFERRED_CATEGORY"]
        
        search_id = item["SEARCH_MATCHED_ID"]
        cosine_id = item["COSINE_MATCHED_ID"]
        edit_id = item["EDIT_DISTANCE_MATCHED_ID"]
        search_score = item["CORTEX_SEARCH_SCORE"] or 0
        cosine_score = item["COSINE_SCORE"] or 0
        edit_score = item["EDIT_DISTANCE_SCORE"] or 0

        # Phase 2: Early Exit Logic
        if early_exit_enabled:
            # Count how many signals agree
            ids = [id for id in [search_id, cosine_id, edit_id] if id is not None]
            if ids:
                id_counts = {}
                for id in ids:
                    id_counts[id] = id_counts.get(id, 0) + 1
                max_agreement = max(id_counts.values())
                consensus_id = [k for k, v in id_counts.items() if v == max_agreement][0]
                
                # Get scores for agreeing signals
                agreeing_scores = []
                if search_id == consensus_id:
                    agreeing_scores.append(search_score)
                if cosine_id == consensus_id:
                    agreeing_scores.append(cosine_score)
                if edit_id == consensus_id:
                    agreeing_scores.append(edit_score)
                
                avg_score = sum(agreeing_scores) / len(agreeing_scores) if agreeing_scores else 0
                max_score = max(agreeing_scores) if agreeing_scores else 0
                
                # 3-way consensus with avg >= threshold
                if max_agreement >= 3 and avg_score >= threshold_3way:
                    session.sql(f"""
                        UPDATE {db}.HARMONIZED.ITEM_MATCHES
                        SET LLM_SCORE = {avg_score},
                            LLM_MATCHED_ID = '{consensus_id}',
                            IS_LLM_SKIPPED = TRUE,
                            LLM_SKIP_REASON = 'VECTOR_CONSENSUS_3WAY',
                            LLM_REASONING = 'Skipped: 3 signals agree with avg score {avg_score:.3f}',
                            UPDATED_AT = CURRENT_TIMESTAMP()
                        WHERE RAW_ITEM_ID = '{item_id}'
                    """).collect()
                    skipped += 1
                    continue
                
                # 2-way consensus with max >= higher threshold
                if max_agreement >= 2 and max_score >= threshold_2way:
                    session.sql(f"""
                        UPDATE {db}.HARMONIZED.ITEM_MATCHES
                        SET LLM_SCORE = {max_score},
                            LLM_MATCHED_ID = '{consensus_id}',
                            IS_LLM_SKIPPED = TRUE,
                            LLM_SKIP_REASON = 'VECTOR_CONSENSUS_2WAY',
                            LLM_REASONING = 'Skipped: 2 signals agree with max score {max_score:.3f}',
                            UPDATED_AT = CURRENT_TIMESTAMP()
                        WHERE RAW_ITEM_ID = '{item_id}'
                    """).collect()
                    skipped += 1
                    continue

        # Get top candidates from other methods
        candidates = session.sql(f"""
            SELECT DISTINCT
                mc.STANDARD_ITEM_ID,
                mc.STANDARD_DESCRIPTION,
                mc.CONFIDENCE_SCORE
            FROM {db}.HARMONIZED.MATCH_CANDIDATES mc
            WHERE mc.RAW_ITEM_ID = '{item_id}'
            ORDER BY mc.CONFIDENCE_SCORE DESC
            LIMIT 5
        """).collect()

        if not candidates:
            continue

        # Phase 4: LLM Cache Lookup
        normalized_desc = raw_desc.upper().strip()
        desc_hash = hashlib.sha256(normalized_desc.encode()).hexdigest()
        cand_ids = sorted([c["STANDARD_ITEM_ID"] for c in candidates])
        cand_hash = hashlib.sha256(",".join(cand_ids).encode()).hexdigest()
        
        cache_result = session.sql(f"""
            SELECT LLM_MATCHED_ID, LLM_CONFIDENCE, LLM_REASONING, CACHE_ID
            FROM {db}.HARMONIZED.LLM_RESPONSE_CACHE
            WHERE DESCRIPTION_HASH = '{desc_hash}'
              AND CANDIDATE_IDS_HASH = '{cand_hash}'
            LIMIT 1
        """).collect()
        
        if cache_result:
            # Cache hit - use cached response
            cached = cache_result[0]
            session.sql(f"""
                UPDATE {db}.HARMONIZED.ITEM_MATCHES
                SET LLM_SCORE = {cached['LLM_CONFIDENCE']},
                    LLM_MATCHED_ID = '{cached['LLM_MATCHED_ID']}',
                    LLM_REASONING = '{(cached['LLM_REASONING'] or '').replace("'", "''")} [CACHED]',
                    IS_CACHED = TRUE,
                    UPDATED_AT = CURRENT_TIMESTAMP()
                WHERE RAW_ITEM_ID = '{item_id}'
            """).collect()
            # Update cache hit counter
            session.sql(f"""
                UPDATE {db}.HARMONIZED.LLM_RESPONSE_CACHE
                SET HIT_COUNT = HIT_COUNT + 1, LAST_HIT_AT = CURRENT_TIMESTAMP()
                WHERE CACHE_ID = '{cached['CACHE_ID']}'
            """).collect()
            cache_hits += 1
            matched += 1
            continue

        # Build candidate list for LLM
        cand_list = []
        for i, c in enumerate(candidates):
            cand_list.append(f"{i}: {c['STANDARD_DESCRIPTION']}")
        cand_text = "\\n".join(cand_list)

        safe_raw = raw_desc.replace("'", "''").replace("\\", "\\\\")
        safe_cand = cand_text.replace("'", "''").replace("\\", "\\\\")

        prompt = f"""You are a retail item matching expert. Match the raw item description to the best candidate from the numbered list.

Raw item: {safe_raw}
Category: {category}

Candidates:
{safe_cand}

Respond with ONLY a JSON object (no markdown, no explanation): {{"match_index": <number>, "confidence": <0.0-1.0>, "reasoning": "<brief explanation>"}}"""

        try:
            # Use the simpler 2-argument form of COMPLETE
            result = session.sql(f"""
                SELECT SNOWFLAKE.CORTEX.COMPLETE('{model}', '{prompt}') AS llm_result
            """).collect()

            if result and result[0]["LLM_RESULT"]:
                llm_response = result[0]["LLM_RESULT"]
                # Extract JSON from response (handle markdown code blocks)
                json_match = re.search(r'\{[^{}]*"match_index"[^{}]*\}', llm_response, re.DOTALL)
                if json_match:
                    llm_json = json.loads(json_match.group())
                else:
                    llm_json = json.loads(llm_response)
                
                match_idx = int(llm_json.get("match_index", 0))
                confidence = float(llm_json.get("confidence", 0.0))
                reasoning = llm_json.get("reasoning", "")

                if 0 <= match_idx < len(candidates):
                    best_cand = candidates[match_idx]
                    best_std_id = best_cand["STANDARD_ITEM_ID"]
                    safe_reasoning = reasoning.replace("'", "''")

                    session.sql(f"""
                        UPDATE {db}.HARMONIZED.ITEM_MATCHES
                        SET LLM_SCORE = {confidence},
                            LLM_MATCHED_ID = '{best_std_id}',
                            LLM_REASONING = '{safe_reasoning}',
                            UPDATED_AT = CURRENT_TIMESTAMP()
                        WHERE RAW_ITEM_ID = '{item_id}'
                    """).collect()

                    # Phase 4: Store in LLM cache
                    cache_id = str(uuid.uuid4())
                    response_json = json.dumps(llm_json).replace("'", "''")
                    session.sql(f"""
                        INSERT INTO {db}.HARMONIZED.LLM_RESPONSE_CACHE
                            (CACHE_ID, DESCRIPTION_HASH, CANDIDATE_IDS_HASH, LLM_RESPONSE,
                             LLM_MATCHED_ID, LLM_CONFIDENCE, LLM_REASONING)
                        VALUES
                            ('{cache_id}', '{desc_hash}', '{cand_hash}', PARSE_JSON('{response_json}'),
                             '{best_std_id}', {confidence}, '{safe_reasoning}')
                    """).collect()

                    matched += 1
        except Exception as e:
            failed += 1
            # Log error to PIPELINE_ERRORS table
            error_id = str(uuid.uuid4())
            error_msg = str(e).replace("'", "''")
            error_context = json.dumps({
                "item_id": item_id,
                "raw_description": raw_desc[:200],
                "category": category,
                "num_candidates": len(candidates)
            }).replace("'", "''")
            
            try:
                session.sql(f"""
                    INSERT INTO {db}.ANALYTICS.PIPELINE_ERRORS
                        (ERROR_ID, PROCEDURE_NAME, ERROR_MESSAGE, ERROR_CONTEXT)
                    SELECT
                        '{error_id}', 'MATCH_LLM_SEMANTIC', '{error_msg}', PARSE_JSON('{error_context}')
                """).collect()
            except:
                # If error logging fails, continue processing
                pass

    # Log completion
    try:
        session.sql(f"""
            CALL {db}.ANALYTICS.LOG_PIPELINE_STEP(
                '{run_id}', 'MATCH_LLM_SEMANTIC', 'COMPLETED',
                {matched}, {skipped}, {failed}, '{started_at}'::TIMESTAMP_NTZ, NULL, NULL, 'SERIAL', NULL
            )
        """).collect()
    except:
        pass

    return f"LLM matched {matched} of {len(items)} items (skipped={skipped}, cache_hits={cache_hits})"
$$;
