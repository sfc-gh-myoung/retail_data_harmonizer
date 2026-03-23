-- ============================================================================
-- sql/setup/10_item_lineage.sql
-- Retail Data Harmonizer - Item Lineage Junction Table
--
-- Creates:
--   1. RAW_TO_UNIQUE_MAP junction table linking raw items to unique descriptions
--   2. POPULATE_RAW_TO_UNIQUE_MAP and GET_ITEM_TRACE procedures
--
-- Prerequisites: 02_schema_and_tables.sql, 09_fastpath_cache.sql
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;


-- ============================================================================
-- Procedure to populate RAW_TO_UNIQUE_MAP after deduplication
-- Called automatically by updated DEDUPLICATE_RAW_ITEMS or manually
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.POPULATE_RAW_TO_UNIQUE_MAP()
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Populates RAW_TO_UNIQUE_MAP junction table after deduplication'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_inserted INTEGER DEFAULT 0;
    v_use_enhanced BOOLEAN DEFAULT TRUE;
BEGIN
    -- Check if enhanced normalization is available
    BEGIN
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM HARMONIZER_DEMO.HARMONIZED.NORMALIZATION_RULES WHERE IS_ACTIVE = TRUE';
        IF (SQLROWCOUNT = 0) THEN
            v_use_enhanced := FALSE;
        END IF;
    EXCEPTION
        WHEN OTHER THEN
            v_use_enhanced := FALSE;
    END;

    -- Insert mappings for items not already mapped
    IF (:v_use_enhanced) THEN
        INSERT INTO HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP (
            MAP_ID, RAW_ITEM_ID, UNIQUE_DESC_ID, RAW_DESCRIPTION,
            NORMALIZED_DESCRIPTION, NORMALIZATION_METHOD, MAPPED_AT
        )
        SELECT
            UUID_STRING(),
            ri.ITEM_ID,
            ud.UNIQUE_DESC_ID,
            ri.RAW_DESCRIPTION,
            ud.NORMALIZED_DESCRIPTION,
            'ENHANCED',
            CURRENT_TIMESTAMP()
        FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
        JOIN HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS ud
            ON HARMONIZER_DEMO.HARMONIZED.APPLY_NORMALIZATION_RULES(ri.RAW_DESCRIPTION) = ud.NORMALIZED_DESCRIPTION
        WHERE NOT EXISTS (
            SELECT 1 FROM HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rtm
            WHERE rtm.RAW_ITEM_ID = ri.ITEM_ID
        );
    ELSE
        INSERT INTO HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP (
            MAP_ID, RAW_ITEM_ID, UNIQUE_DESC_ID, RAW_DESCRIPTION,
            NORMALIZED_DESCRIPTION, NORMALIZATION_METHOD, MAPPED_AT
        )
        SELECT
            UUID_STRING(),
            ri.ITEM_ID,
            ud.UNIQUE_DESC_ID,
            ri.RAW_DESCRIPTION,
            ud.NORMALIZED_DESCRIPTION,
            'BASIC',
            CURRENT_TIMESTAMP()
        FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
        JOIN HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS ud
            ON UPPER(TRIM(REGEXP_REPLACE(ri.RAW_DESCRIPTION, '\\s+', ' '))) = ud.NORMALIZED_DESCRIPTION
        WHERE NOT EXISTS (
            SELECT 1 FROM HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rtm
            WHERE rtm.RAW_ITEM_ID = ri.ITEM_ID
        );
    END IF;

    v_inserted := SQLROWCOUNT;

    RETURN '{"mappings_created": ' || :v_inserted || ', "normalization_method": "' || IFF(:v_use_enhanced, 'ENHANCED', 'BASIC') || '"}';
END;
$$;

-- ============================================================================
-- Procedure to get traceability for a specific raw item
-- ============================================================================
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.GET_ITEM_TRACE(P_RAW_ITEM_ID VARCHAR)
RETURNS TABLE (
    STEP VARCHAR,
    DESCRIPTION VARCHAR,
    VALUE VARCHAR,
    TIMESTAMP TIMESTAMP_NTZ
)
LANGUAGE SQL
COMMENT = 'Returns full traceability for a raw item: raw -> normalized -> unique -> match -> standard'
EXECUTE AS OWNER
AS
$$
DECLARE
    res RESULTSET;
BEGIN
    res := (
        SELECT
            '1. RAW_ITEM' AS STEP,
            'Original raw description' AS DESCRIPTION,
            ri.RAW_DESCRIPTION AS VALUE,
            ri.CREATED_AT AS TIMESTAMP
        FROM HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS ri
        WHERE ri.ITEM_ID = :P_RAW_ITEM_ID
        
        UNION ALL
        
        SELECT
            '2. NORMALIZED',
            'After normalization rules applied',
            rtm.NORMALIZED_DESCRIPTION,
            rtm.MAPPED_AT
        FROM HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rtm
        WHERE rtm.RAW_ITEM_ID = :P_RAW_ITEM_ID
        
        UNION ALL
        
        SELECT
            '3. UNIQUE_DESC',
            'Deduplicated unique description (item_count: ' || ud.ITEM_COUNT || ')',
            ud.UNIQUE_DESC_ID,
            ud.FIRST_SEEN_AT
        FROM HARMONIZER_DEMO.HARMONIZED.RAW_TO_UNIQUE_MAP rtm
        JOIN HARMONIZER_DEMO.HARMONIZED.UNIQUE_DESCRIPTIONS ud ON rtm.UNIQUE_DESC_ID = ud.UNIQUE_DESC_ID
        WHERE rtm.RAW_ITEM_ID = :P_RAW_ITEM_ID
        
        UNION ALL
        
        SELECT
            '4. MATCH_RESULT',
            'Match method: ' || im.MATCH_METHOD || ', Status: ' || im.STATUS,
            'Score: ' || ROUND(im.ENSEMBLE_SCORE, 3) || ', Standard: ' || COALESCE(im.SUGGESTED_STANDARD_ID, 'N/A'),
            im.CREATED_AT
        FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
        WHERE im.RAW_ITEM_ID = :P_RAW_ITEM_ID
        
        UNION ALL
        
        SELECT
            '5. STANDARD_ITEM',
            'Matched standard item',
            si.STANDARD_DESCRIPTION,
            NULL
        FROM HARMONIZER_DEMO.HARMONIZED.ITEM_MATCHES im
        JOIN HARMONIZER_DEMO.RAW.STANDARD_ITEMS si
            ON COALESCE(im.CONFIRMED_STANDARD_ID, im.SUGGESTED_STANDARD_ID) = si.STANDARD_ITEM_ID
        WHERE im.RAW_ITEM_ID = :P_RAW_ITEM_ID
        
        ORDER BY STEP
    );
    RETURN TABLE(res);
END;
$$;