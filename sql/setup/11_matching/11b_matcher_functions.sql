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
