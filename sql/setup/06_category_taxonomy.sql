-- ============================================================================
-- sql/setup/06_category_taxonomy.sql
-- Retail Data Harmonizer - Configurable Category Taxonomy
--
-- Creates:
--   1. CATEGORY_TAXONOMY table (hierarchical reference data)
--   2. Seed taxonomy data DYNAMICALLY from STANDARD_ITEMS (all categories)
--   3. GET_ACTIVE_CATEGORIES() function
--   4. GET_SUBCATEGORIES() function
--
-- Depends on: 01_roles_and_warehouse.sql, 05_seed_data/
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- CATEGORY_TAXONOMY: Multi-level configurable category hierarchy
-- Dynamically populated from STANDARD_ITEMS to ensure consistency
-- ============================================================================
CREATE OR REPLACE TABLE HARMONIZER_DEMO.RAW.CATEGORY_TAXONOMY (
    TAXONOMY_ID             VARCHAR(36)     NOT NULL,
    CATEGORY                VARCHAR(100)    NOT NULL,
    SUBCATEGORY             VARCHAR(100),
    SUB_SUBCATEGORY         VARCHAR(100),
    PARENT_TAXONOMY_ID      VARCHAR(36),
    IS_ACTIVE               BOOLEAN         DEFAULT TRUE,
    CREATED_AT              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_CATEGORY_TAXONOMY PRIMARY KEY (TAXONOMY_ID),
    CONSTRAINT FK_TAXONOMY_PARENT FOREIGN KEY (PARENT_TAXONOMY_ID)
        REFERENCES HARMONIZER_DEMO.RAW.CATEGORY_TAXONOMY(TAXONOMY_ID)
);

-- ============================================================================
-- Seed Data: Top-level categories (dynamically from STANDARD_ITEMS)
-- This ensures the classifier can assign any category that exists in the catalog
-- ============================================================================
INSERT INTO HARMONIZER_DEMO.RAW.CATEGORY_TAXONOMY (TAXONOMY_ID, CATEGORY, SUBCATEGORY, SUB_SUBCATEGORY, PARENT_TAXONOMY_ID, IS_ACTIVE)
SELECT DISTINCT UUID_STRING(), CATEGORY, NULL, NULL, NULL, TRUE
FROM HARMONIZER_DEMO.RAW.STANDARD_ITEMS
WHERE CATEGORY IS NOT NULL;

-- ============================================================================
-- Seed Data: Subcategories (dynamically from STANDARD_ITEMS)
-- Links subcategories to their parent category for hierarchical classification
-- Uses LEFT JOIN instead of correlated subquery (Snowflake limitation)
-- ============================================================================
INSERT INTO HARMONIZER_DEMO.RAW.CATEGORY_TAXONOMY (TAXONOMY_ID, CATEGORY, SUBCATEGORY, SUB_SUBCATEGORY, PARENT_TAXONOMY_ID, IS_ACTIVE)
SELECT DISTINCT 
    UUID_STRING(), 
    si.CATEGORY, 
    si.SUBCATEGORY, 
    NULL, 
    parent.TAXONOMY_ID,
    TRUE
FROM HARMONIZER_DEMO.RAW.STANDARD_ITEMS si
LEFT JOIN HARMONIZER_DEMO.RAW.CATEGORY_TAXONOMY parent 
    ON parent.CATEGORY = si.CATEGORY 
    AND parent.SUBCATEGORY IS NULL
WHERE si.SUBCATEGORY IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM HARMONIZER_DEMO.RAW.CATEGORY_TAXONOMY ct2
      WHERE ct2.CATEGORY = si.CATEGORY AND ct2.SUBCATEGORY = si.SUBCATEGORY
  );

-- ============================================================================
-- GET_ACTIVE_CATEGORIES: Returns array of top-level categories for AI_CLASSIFY
-- Usage: SELECT HARMONIZER_DEMO.RAW.GET_ACTIVE_CATEGORIES();
-- ============================================================================
CREATE OR REPLACE FUNCTION HARMONIZER_DEMO.RAW.GET_ACTIVE_CATEGORIES()
RETURNS ARRAY
LANGUAGE SQL
COMMENT = 'Returns all active top-level categories for AI_CLASSIFY. Dynamically populated from STANDARD_ITEMS.'
AS
$$
    SELECT ARRAY_AGG(DISTINCT CATEGORY)
    FROM HARMONIZER_DEMO.RAW.CATEGORY_TAXONOMY
    WHERE IS_ACTIVE = TRUE
      AND SUBCATEGORY IS NULL
$$;

-- ============================================================================
-- GET_SUBCATEGORIES: Returns subcategories for a given top-level category
-- Usage: SELECT HARMONIZER_DEMO.RAW.GET_SUBCATEGORIES('Beverages');
-- ============================================================================
CREATE OR REPLACE FUNCTION HARMONIZER_DEMO.RAW.GET_SUBCATEGORIES(P_CATEGORY VARCHAR)
RETURNS ARRAY
LANGUAGE SQL
COMMENT = 'Returns subcategories for a given top-level category'
AS
$$
    SELECT ARRAY_AGG(DISTINCT SUBCATEGORY)
    FROM HARMONIZER_DEMO.RAW.CATEGORY_TAXONOMY
    WHERE CATEGORY = P_CATEGORY
      AND SUBCATEGORY IS NOT NULL
      AND SUB_SUBCATEGORY IS NULL
      AND IS_ACTIVE = TRUE
$$;

-- ============================================================================
-- Verification: Show category counts
-- ============================================================================
-- SELECT 
--     'Top-level categories' AS level, 
--     COUNT(DISTINCT CATEGORY) AS count 
-- FROM HARMONIZER_DEMO.RAW.CATEGORY_TAXONOMY 
-- WHERE SUBCATEGORY IS NULL
-- UNION ALL
-- SELECT 
--     'Subcategories' AS level, 
--     COUNT(*) AS count 
-- FROM HARMONIZER_DEMO.RAW.CATEGORY_TAXONOMY 
-- WHERE SUBCATEGORY IS NOT NULL;
