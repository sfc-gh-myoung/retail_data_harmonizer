-- ============================================================================
-- Retail Data Harmonization Demo
-- Script: sql/setup/07_raw_items_stream.sql
-- Purpose: Create stream AFTER seed data is loaded
-- Depends on: 02_schema_and_tables.sql, 05_seed_data/*.sql
-- 
-- CRITICAL: This file MUST run AFTER all seed data files (05_seed_data/*.sql)
-- because SHOW_INITIAL_ROWS=TRUE only captures rows that exist at the time
-- the stream is created. Creating the stream before data insertion results
-- in an empty stream that misses all the seed data.
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- Backfill NORMALIZED_DESCRIPTION for performance optimization
-- This pre-computes the normalized description to avoid expensive REGEXP_REPLACE
-- in WHERE clauses during duplicate propagation queries
-- ============================================================================
UPDATE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS
SET NORMALIZED_DESCRIPTION = UPPER(TRIM(REGEXP_REPLACE(RAW_DESCRIPTION, '\\s+', ' ')))
WHERE NORMALIZED_DESCRIPTION IS NULL;

-- ============================================================================
-- Stream for Exactly-Once Processing
-- Tracks new raw items for parallel vector matching pipeline
-- Stream advances only when consumed in a DML operation (atomic exactly-once)
-- SHOW_INITIAL_ROWS ensures existing PENDING items are picked up on stream creation
-- ============================================================================
CREATE OR REPLACE STREAM HARMONIZER_DEMO.HARMONIZED.RAW_ITEMS_STREAM 
  ON TABLE HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS
  APPEND_ONLY = TRUE
  SHOW_INITIAL_ROWS = TRUE
  COMMENT = 'Tracks new raw items for exactly-once processing in parallel vector matching';
