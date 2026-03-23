-- ============================================================================
-- Retail Data Harmonization Demo
-- Script: sql/setup/11_matching/11a_cortex_search_setup.sql
-- Purpose: Cortex Search service and pre-computed embeddings
-- Depends on: 02_schema_and_tables.sql
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- STEP 1: Create Cortex Search Service on standard items
-- NOTE: CHANGE_TRACKING is enabled at table creation in 02_schema_and_tables.sql
-- ============================================================================
CREATE OR REPLACE CORTEX SEARCH SERVICE HARMONIZER_DEMO.HARMONIZED.STANDARD_ITEM_SEARCH
    ON STANDARD_DESCRIPTION
    ATTRIBUTES STANDARD_ITEM_ID, CATEGORY, BRAND, SRP
    WAREHOUSE = HARMONIZER_DEMO_WH
    TARGET_LAG = '1 minute'
    EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
    AS (
        SELECT
            STANDARD_ITEM_ID,
            STANDARD_DESCRIPTION,
            CATEGORY,
            BRAND,
            COALESCE(SRP, 0) AS SRP
        FROM HARMONIZER_DEMO.RAW.STANDARD_ITEMS
    );

-- ============================================================================
-- STEP 2: Pre-compute embeddings for cosine similarity method
-- ============================================================================
TRUNCATE TABLE IF EXISTS HARMONIZER_DEMO.RAW.STANDARD_ITEMS_EMBEDDINGS;

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS_EMBEDDINGS (STANDARD_ITEM_ID, EMBEDDING)
SELECT
    STANDARD_ITEM_ID,
    SNOWFLAKE.CORTEX.EMBED_TEXT_1024('snowflake-arctic-embed-l-v2.0', STANDARD_DESCRIPTION)
FROM HARMONIZER_DEMO.RAW.STANDARD_ITEMS;
