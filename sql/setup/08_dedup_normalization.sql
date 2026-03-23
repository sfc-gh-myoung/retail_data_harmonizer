-- ============================================================================
-- sql/setup/08_dedup_normalization.sql
-- Retail Data Harmonizer - Enhanced Normalization Engine
--
-- Creates:
--   1. NORMALIZATION_RULES table with 50-100 seed rules
--   2. APPLY_NORMALIZATION_RULES() Python UDF
--   3. Rule management procedures
--
-- Prerequisites: 02_schema_and_tables.sql
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- NORMALIZATION_RULES: Configurable text normalization patterns
-- Rule types: ABBREVIATION, UNIT, BRAND, PUNCTUATION, CASE, WHITESPACE
-- ============================================================================
CREATE OR REPLACE TABLE HARMONIZER_DEMO.HARMONIZED.NORMALIZATION_RULES (
    RULE_ID                 VARCHAR(36)     NOT NULL,
    RULE_TYPE               VARCHAR(30)     NOT NULL,
    PATTERN                 VARCHAR(200)    NOT NULL,
    REPLACEMENT             VARCHAR(200)    NOT NULL,
    PRIORITY                INTEGER         DEFAULT 100,
    IS_REGEX                BOOLEAN         DEFAULT FALSE,
    IS_CASE_SENSITIVE       BOOLEAN         DEFAULT FALSE,
    IS_ACTIVE               BOOLEAN         DEFAULT TRUE,
    DESCRIPTION             VARCHAR(500),
    CREATED_AT              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT              TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_NORMALIZATION_RULES PRIMARY KEY (RULE_ID)
);

-- ============================================================================
-- Seed normalization rules (50-100 rules covering common patterns)
-- Note: Using INSERT...SELECT syntax because UUID_STRING() is not allowed in VALUES
-- ============================================================================

-- Abbreviation expansions (high priority - run first)
INSERT INTO HARMONIZER_DEMO.HARMONIZED.NORMALIZATION_RULES (RULE_ID, RULE_TYPE, PATTERN, REPLACEMENT, PRIORITY, IS_REGEX, DESCRIPTION)
SELECT UUID_STRING(), 'ABBREVIATION', '\\bOZ\\b', 'OUNCE', 10, TRUE, 'Expand OZ to OUNCE'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bPK\\b', 'PACK', 10, TRUE, 'Expand PK to PACK'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bCT\\b', 'COUNT', 10, TRUE, 'Expand CT to COUNT'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bBTL\\b', 'BOTTLE', 10, TRUE, 'Expand BTL to BOTTLE'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bCN\\b', 'CAN', 10, TRUE, 'Expand CN to CAN'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bCS\\b', 'CASE', 10, TRUE, 'Expand CS to CASE'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bLTR\\b', 'LITER', 10, TRUE, 'Expand LTR to LITER'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bGAL\\b', 'GALLON', 10, TRUE, 'Expand GAL to GALLON'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bLB\\b', 'POUND', 10, TRUE, 'Expand LB to POUND'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bKG\\b', 'KILOGRAM', 10, TRUE, 'Expand KG to KILOGRAM'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bML\\b', 'MILLILITER', 10, TRUE, 'Expand ML to MILLILITER'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bMG\\b', 'MILLIGRAM', 10, TRUE, 'Expand MG to MILLIGRAM'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bG\\b', 'GRAM', 10, TRUE, 'Expand G to GRAM'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bSM\\b', 'SMALL', 10, TRUE, 'Expand SM to SMALL'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bMED\\b', 'MEDIUM', 10, TRUE, 'Expand MED to MEDIUM'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bLG\\b', 'LARGE', 10, TRUE, 'Expand LG to LARGE'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bXL\\b', 'EXTRA LARGE', 10, TRUE, 'Expand XL to EXTRA LARGE'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bREG\\b', 'REGULAR', 10, TRUE, 'Expand REG to REGULAR'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bORG\\b', 'ORGANIC', 10, TRUE, 'Expand ORG to ORGANIC'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bNAT\\b', 'NATURAL', 10, TRUE, 'Expand NAT to NATURAL'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bFLVR\\b', 'FLAVOR', 10, TRUE, 'Expand FLVR to FLAVOR'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bASSTD\\b', 'ASSORTED', 10, TRUE, 'Expand ASSTD to ASSORTED'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bVAR\\b', 'VARIETY', 10, TRUE, 'Expand VAR to VARIETY'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bCHOC\\b', 'CHOCOLATE', 10, TRUE, 'Expand CHOC to CHOCOLATE'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bVAN\\b', 'VANILLA', 10, TRUE, 'Expand VAN to VANILLA'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bSTRW\\b', 'STRAWBERRY', 10, TRUE, 'Expand STRW to STRAWBERRY'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bBLU\\b', 'BLUE', 10, TRUE, 'Expand BLU to BLUE'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bGRN\\b', 'GREEN', 10, TRUE, 'Expand GRN to GREEN'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bYEL\\b', 'YELLOW', 10, TRUE, 'Expand YEL to YELLOW'
UNION ALL SELECT UUID_STRING(), 'ABBREVIATION', '\\bORNGE\\b', 'ORANGE', 10, TRUE, 'Expand ORNGE to ORANGE';

-- Unit standardization (normalize units to consistent format)
INSERT INTO HARMONIZER_DEMO.HARMONIZED.NORMALIZATION_RULES (RULE_ID, RULE_TYPE, PATTERN, REPLACEMENT, PRIORITY, IS_REGEX, DESCRIPTION)
SELECT UUID_STRING(), 'UNIT', '(\\d+)\\s*OUNCE', '$1OZ', 20, TRUE, 'Standardize X OUNCE to XOZ'
UNION ALL SELECT UUID_STRING(), 'UNIT', '(\\d+)\\s*PACK', '$1PK', 20, TRUE, 'Standardize X PACK to XPK'
UNION ALL SELECT UUID_STRING(), 'UNIT', '(\\d+)\\s*COUNT', '$1CT', 20, TRUE, 'Standardize X COUNT to XCT'
UNION ALL SELECT UUID_STRING(), 'UNIT', '(\\d+)\\s*LITER', '$1L', 20, TRUE, 'Standardize X LITER to XL'
UNION ALL SELECT UUID_STRING(), 'UNIT', '(\\d+)\\s*GALLON', '$1GAL', 20, TRUE, 'Standardize X GALLON to XGAL'
UNION ALL SELECT UUID_STRING(), 'UNIT', '(\\d+)\\s*POUND', '$1LB', 20, TRUE, 'Standardize X POUND to XLB'
UNION ALL SELECT UUID_STRING(), 'UNIT', '(\\d+)\\.(\\d+)OZ', '$1-$2OZ', 20, TRUE, 'Normalize 1.69OZ to 1-69OZ'
UNION ALL SELECT UUID_STRING(), 'UNIT', '(\\d+)/(\\d+)OZ', '$1PK $2OZ', 20, TRUE, 'Normalize 12/12OZ to 12PK 12OZ'
UNION ALL SELECT UUID_STRING(), 'UNIT', '(\\d+)\\s*-\\s*PACK', '$1PK', 20, TRUE, 'Normalize 12-PACK to 12PK'
UNION ALL SELECT UUID_STRING(), 'UNIT', '(\\d+)\\s*PC', '$1CT', 20, TRUE, 'Normalize 12PC to 12CT';

-- Brand name standardization
INSERT INTO HARMONIZER_DEMO.HARMONIZED.NORMALIZATION_RULES (RULE_ID, RULE_TYPE, PATTERN, REPLACEMENT, PRIORITY, IS_REGEX, DESCRIPTION)
SELECT UUID_STRING(), 'BRAND', 'COCA COLA', 'COCA-COLA', 30, FALSE, 'Standardize Coca Cola brand'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'COCA-COLA CLASSIC', 'COCA-COLA CLASSIC', 30, FALSE, 'Preserve Coca-Cola Classic'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'COKE CL', 'COCA-COLA CLASSIC', 30, FALSE, 'Expand COKE CL abbreviation'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'CC CLASSIC', 'COCA-COLA CLASSIC', 30, FALSE, 'Expand CC CLASSIC abbreviation'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'DR PEPPER', 'DR. PEPPER', 30, FALSE, 'Standardize Dr Pepper brand'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'DR.PEPPER', 'DR. PEPPER', 30, FALSE, 'Standardize Dr.Pepper variant'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'MTN DEW', 'MOUNTAIN DEW', 30, FALSE, 'Expand MTN DEW abbreviation'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'MT DEW', 'MOUNTAIN DEW', 30, FALSE, 'Expand MT DEW abbreviation'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'MNTN DEW', 'MOUNTAIN DEW', 30, FALSE, 'Expand MNTN DEW abbreviation'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'PPSI', 'PEPSI', 30, FALSE, 'Fix PPSI typo'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'PEPSI COLA', 'PEPSI', 30, FALSE, 'Standardize Pepsi Cola to Pepsi'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'PEPSI-COLA', 'PEPSI', 30, FALSE, 'Standardize Pepsi-Cola to Pepsi'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'FRITO LAY', 'FRITO-LAY', 30, FALSE, 'Standardize Frito Lay brand'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'FRTO LY', 'FRITO-LAY', 30, FALSE, 'Expand FRTO LY abbreviation'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'FL CLASSIC', 'FRITO-LAY CLASSIC', 30, FALSE, 'Expand FL CLASSIC abbreviation'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'DORITOS', 'DORITOS', 30, FALSE, 'Preserve Doritos brand'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'DRTS', 'DORITOS', 30, FALSE, 'Expand DRTS abbreviation'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'DORI', 'DORITOS', 30, FALSE, 'Expand DORI abbreviation'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'LAYS', 'LAY''S', 30, FALSE, 'Standardize Lays to Lay''s'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'LAY''S', 'LAY''S', 30, FALSE, 'Preserve Lay''s brand'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'LYS', 'LAY''S', 30, FALSE, 'Expand LYS abbreviation'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'GATORADE', 'GATORADE', 30, FALSE, 'Preserve Gatorade brand'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'GTRD', 'GATORADE', 30, FALSE, 'Expand GTRD abbreviation'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'GTRDE', 'GATORADE', 30, FALSE, 'Expand GTRDE abbreviation'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'AQUAFINA', 'AQUAFINA', 30, FALSE, 'Preserve Aquafina brand'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'AQF', 'AQUAFINA', 30, FALSE, 'Expand AQF abbreviation'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'AQUA', 'AQUAFINA', 30, FALSE, 'Expand AQUA abbreviation'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'NESTLE', 'NESTLE', 30, FALSE, 'Preserve Nestle brand'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'NSTL', 'NESTLE', 30, FALSE, 'Expand NSTL abbreviation'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'NESTLE PURE LIFE', 'NESTLE PURE LIFE', 30, FALSE, 'Preserve Nestle Pure Life'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'SNYDER''S', 'SNYDER''S', 30, FALSE, 'Preserve Snyder''s brand'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'SNYDERS', 'SNYDER''S', 30, FALSE, 'Standardize Snyders to Snyder''s'
UNION ALL SELECT UUID_STRING(), 'BRAND', 'SNDRS', 'SNYDER''S', 30, FALSE, 'Expand SNDRS abbreviation';

-- Punctuation and special character handling
INSERT INTO HARMONIZER_DEMO.HARMONIZED.NORMALIZATION_RULES (RULE_ID, RULE_TYPE, PATTERN, REPLACEMENT, PRIORITY, IS_REGEX, DESCRIPTION)
SELECT UUID_STRING(), 'PUNCTUATION', ',', ' ', 40, FALSE, 'Replace commas with spaces'
UNION ALL SELECT UUID_STRING(), 'PUNCTUATION', ';', ' ', 40, FALSE, 'Replace semicolons with spaces'
UNION ALL SELECT UUID_STRING(), 'PUNCTUATION', ':', ' ', 40, FALSE, 'Replace colons with spaces'
UNION ALL SELECT UUID_STRING(), 'PUNCTUATION', '/', ' ', 40, FALSE, 'Replace slashes with spaces'
UNION ALL SELECT UUID_STRING(), 'PUNCTUATION', '\\(', ' ', 40, TRUE, 'Remove opening parentheses'
UNION ALL SELECT UUID_STRING(), 'PUNCTUATION', '\\)', ' ', 40, TRUE, 'Remove closing parentheses'
UNION ALL SELECT UUID_STRING(), 'PUNCTUATION', '\\[', ' ', 40, TRUE, 'Remove opening brackets'
UNION ALL SELECT UUID_STRING(), 'PUNCTUATION', '\\]', ' ', 40, TRUE, 'Remove closing brackets'
UNION ALL SELECT UUID_STRING(), 'PUNCTUATION', '#', '', 40, FALSE, 'Remove hash symbols'
UNION ALL SELECT UUID_STRING(), 'PUNCTUATION', '\\*', '', 40, TRUE, 'Remove asterisks';

-- Whitespace normalization (run last)
INSERT INTO HARMONIZER_DEMO.HARMONIZED.NORMALIZATION_RULES (RULE_ID, RULE_TYPE, PATTERN, REPLACEMENT, PRIORITY, IS_REGEX, DESCRIPTION)
SELECT UUID_STRING(), 'WHITESPACE', '\\s+', ' ', 90, TRUE, 'Collapse multiple spaces to single'
UNION ALL SELECT UUID_STRING(), 'WHITESPACE', '^\\s+', '', 91, TRUE, 'Trim leading whitespace'
UNION ALL SELECT UUID_STRING(), 'WHITESPACE', '\\s+$', '', 92, TRUE, 'Trim trailing whitespace';

-- Category-specific rules
INSERT INTO HARMONIZER_DEMO.HARMONIZED.NORMALIZATION_RULES (RULE_ID, RULE_TYPE, PATTERN, REPLACEMENT, PRIORITY, IS_REGEX, DESCRIPTION)
SELECT UUID_STRING(), 'CATEGORY', 'BEVERAGE', 'BEVERAGES', 50, FALSE, 'Standardize category to plural'
UNION ALL SELECT UUID_STRING(), 'CATEGORY', 'SNACK', 'SNACKS', 50, FALSE, 'Standardize category to plural'
UNION ALL SELECT UUID_STRING(), 'CATEGORY', 'CONDIMENT', 'CONDIMENTS', 50, FALSE, 'Standardize category to plural'
UNION ALL SELECT UUID_STRING(), 'CATEGORY', 'PREP FOOD', 'PREPARED FOODS', 50, FALSE, 'Expand PREP FOOD'
UNION ALL SELECT UUID_STRING(), 'CATEGORY', 'PREP FD', 'PREPARED FOODS', 50, FALSE, 'Expand PREP FD'
UNION ALL SELECT UUID_STRING(), 'CATEGORY', 'BEV', 'BEVERAGES', 50, FALSE, 'Expand BEV abbreviation'
UNION ALL SELECT UUID_STRING(), 'CATEGORY', 'SNK', 'SNACKS', 50, FALSE, 'Expand SNK abbreviation';

-- Flavor and variant standardization
INSERT INTO HARMONIZER_DEMO.HARMONIZED.NORMALIZATION_RULES (RULE_ID, RULE_TYPE, PATTERN, REPLACEMENT, PRIORITY, IS_REGEX, DESCRIPTION)
SELECT UUID_STRING(), 'VARIANT', 'ORIG', 'ORIGINAL', 35, FALSE, 'Expand ORIG to ORIGINAL'
UNION ALL SELECT UUID_STRING(), 'VARIANT', 'ORGNL', 'ORIGINAL', 35, FALSE, 'Expand ORGNL to ORIGINAL'
UNION ALL SELECT UUID_STRING(), 'VARIANT', 'CLS', 'CLASSIC', 35, FALSE, 'Expand CLS to CLASSIC'
UNION ALL SELECT UUID_STRING(), 'VARIANT', 'CLSC', 'CLASSIC', 35, FALSE, 'Expand CLSC to CLASSIC'
UNION ALL SELECT UUID_STRING(), 'VARIANT', 'NCH', 'NACHO', 35, FALSE, 'Expand NCH to NACHO'
UNION ALL SELECT UUID_STRING(), 'VARIANT', 'CHS', 'CHEESE', 35, FALSE, 'Expand CHS to CHEESE'
UNION ALL SELECT UUID_STRING(), 'VARIANT', 'CHSE', 'CHEESE', 35, FALSE, 'Expand CHSE to CHEESE'
UNION ALL SELECT UUID_STRING(), 'VARIANT', 'FRT', 'FRUIT', 35, FALSE, 'Expand FRT to FRUIT'
UNION ALL SELECT UUID_STRING(), 'VARIANT', 'PNCH', 'PUNCH', 35, FALSE, 'Expand PNCH to PUNCH'
UNION ALL SELECT UUID_STRING(), 'VARIANT', 'HNY', 'HONEY', 35, FALSE, 'Expand HNY to HONEY'
UNION ALL SELECT UUID_STRING(), 'VARIANT', 'MSTRD', 'MUSTARD', 35, FALSE, 'Expand MSTRD to MUSTARD'
UNION ALL SELECT UUID_STRING(), 'VARIANT', 'PRTZL', 'PRETZEL', 35, FALSE, 'Expand PRTZL to PRETZEL'
UNION ALL SELECT UUID_STRING(), 'VARIANT', 'PTO', 'POTATO', 35, FALSE, 'Expand PTO to POTATO'
UNION ALL SELECT UUID_STRING(), 'VARIANT', 'CHP', 'CHIP', 35, FALSE, 'Expand CHP to CHIP'
UNION ALL SELECT UUID_STRING(), 'VARIANT', 'CHPS', 'CHIPS', 35, FALSE, 'Expand CHPS to CHIPS'
UNION ALL SELECT UUID_STRING(), 'VARIANT', 'WTR', 'WATER', 35, FALSE, 'Expand WTR to WATER'
UNION ALL SELECT UUID_STRING(), 'VARIANT', 'PUR', 'PURE', 35, FALSE, 'Expand PUR to PURE'
UNION ALL SELECT UUID_STRING(), 'VARIANT', 'LF', 'LIFE', 35, FALSE, 'Expand LF to LIFE'
UNION ALL SELECT UUID_STRING(), 'VARIANT', 'SPRNG', 'SPRING', 35, FALSE, 'Expand SPRNG to SPRING'
UNION ALL SELECT UUID_STRING(), 'VARIANT', 'MX', 'MIX', 35, FALSE, 'Expand MX to MIX';

-- ============================================================================
-- APPLY_NORMALIZATION_RULES: Python UDF that applies all active rules
-- Returns normalized string after applying rules in priority order
--
-- NOTE: Rules are embedded directly because Python UDFs cannot access
-- Snowpark sessions or execute SQL queries. To update rules, modify
-- the RULES list below and redeploy this function.
-- ============================================================================
CREATE OR REPLACE FUNCTION HARMONIZER_DEMO.HARMONIZED.APPLY_NORMALIZATION_RULES(INPUT_TEXT VARCHAR)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
HANDLER = 'apply_rules'
COMMENT = 'Applies text normalization rules: abbreviations, brand variations, whitespace cleanup'
AS
$$
import re

# Embedded normalization rules ordered by priority
# Format: (pattern, replacement, is_regex)
# All rules are case-insensitive (applied after UPPER())
RULES = [
    # === Priority 10: Abbreviation expansions (run first) ===
    (r'\bOZ\b', 'OUNCE', True),
    (r'\bPK\b', 'PACK', True),
    (r'\bCT\b', 'COUNT', True),
    (r'\bBTL\b', 'BOTTLE', True),
    (r'\bCN\b', 'CAN', True),
    (r'\bCS\b', 'CASE', True),
    (r'\bLTR\b', 'LITER', True),
    (r'\bGAL\b', 'GALLON', True),
    (r'\bLB\b', 'POUND', True),
    (r'\bKG\b', 'KILOGRAM', True),
    (r'\bML\b', 'MILLILITER', True),
    (r'\bMG\b', 'MILLIGRAM', True),
    (r'\bG\b', 'GRAM', True),
    (r'\bSM\b', 'SMALL', True),
    (r'\bMED\b', 'MEDIUM', True),
    (r'\bLG\b', 'LARGE', True),
    (r'\bXL\b', 'EXTRA LARGE', True),
    (r'\bREG\b', 'REGULAR', True),
    (r'\bORG\b', 'ORGANIC', True),
    (r'\bNAT\b', 'NATURAL', True),
    (r'\bFLVR\b', 'FLAVOR', True),
    (r'\bASSTD\b', 'ASSORTED', True),
    (r'\bVAR\b', 'VARIETY', True),
    (r'\bCHOC\b', 'CHOCOLATE', True),
    (r'\bVAN\b', 'VANILLA', True),
    (r'\bSTRW\b', 'STRAWBERRY', True),
    (r'\bBLU\b', 'BLUE', True),
    (r'\bGRN\b', 'GREEN', True),
    (r'\bYEL\b', 'YELLOW', True),
    (r'\bORNGE\b', 'ORANGE', True),

    # === Priority 20: Unit standardization ===
    (r'(\d+)\s*OUNCE', r'\1OZ', True),
    (r'(\d+)\s*PACK', r'\1PK', True),
    (r'(\d+)\s*COUNT', r'\1CT', True),
    (r'(\d+)\s*LITER', r'\1L', True),
    (r'(\d+)\s*GALLON', r'\1GAL', True),
    (r'(\d+)\s*POUND', r'\1LB', True),
    (r'(\d+)\.(\d+)OZ', r'\1-\2OZ', True),
    (r'(\d+)/(\d+)OZ', r'\1PK \2OZ', True),
    (r'(\d+)\s*-\s*PACK', r'\1PK', True),
    (r'(\d+)\s*PC', r'\1CT', True),

    # === Priority 12: Common typo corrections ===
    (r'\bSNICKRS\b', 'SNICKERS', True),
    (r'\bCHIKEN\b', 'CHICKEN', True),
    (r'\bTENDRS\b', 'TENDERS', True),
    (r'\bTNDRS\b', 'TENDERS', True),
    (r'\bCHEEZE\b', 'CHEESE', True),
    (r'\bCHILLI\b', 'CHILI', True),
    (r'\bDASANNI\b', 'DASANI', True),
    (r'\bCOCACOLA\b', 'COCA-COLA', True),
    (r'\bCOCA_COLA\b', 'COCA-COLA', True),

    # === Priority 30: Brand name standardization (with word boundaries to prevent double-expansion) ===
    (r'\bCOCA COLA\b', 'COCA-COLA', True),
    (r'\bCOKE CL\b', 'COCA-COLA CLASSIC', True),
    (r'\bCC CLASSIC\b', 'COCA-COLA CLASSIC', True),
    (r'\bDR PEPPER\b', 'DR. PEPPER', True),
    (r'\bDR\.PEPPER\b', 'DR. PEPPER', True),
    (r'\bMTN DEW\b', 'MOUNTAIN DEW', True),
    (r'\bMT DEW\b', 'MOUNTAIN DEW', True),
    (r'\bMNTN DEW\b', 'MOUNTAIN DEW', True),
    (r'\bPPSI\b', 'PEPSI', True),
    (r'\bPEPSI COLA\b', 'PEPSI', True),
    (r'\bPEPSI-COLA\b', 'PEPSI', True),
    (r'\bFRITO LAY\b', 'FRITO-LAY', True),
    (r'\bFRTO LY\b', 'FRITO-LAY', True),
    (r'\bFL CLASSIC\b', 'FRITO-LAY CLASSIC', True),
    (r'\bDRTS\b', 'DORITOS', True),
    (r'\bDORI\b', 'DORITOS', True),
    (r'\bLAYS\b', "LAY'S", True),
    (r'\bLYS\b', "LAY'S", True),
    (r'\bGTRD\b', 'GATORADE', True),
    (r'\bGTRDE\b', 'GATORADE', True),
    (r'\bAQF\b', 'AQUAFINA', True),
    (r'\bAQUA\b', 'AQUAFINA', True),
    (r'\bNSTL\b', 'NESTLE', True),
    (r'\bSNYDERS\b', "SNYDER'S", True),
    (r'\bSNDRS\b', "SNYDER'S", True),

    # === Priority 35: Flavor/variant standardization (with word boundaries) ===
    (r'\bORIG\b', 'ORIGINAL', True),
    (r'\bORGNL\b', 'ORIGINAL', True),
    (r'\bCLS\b', 'CLASSIC', True),
    (r'\bCLSC\b', 'CLASSIC', True),
    (r'\bNCH\b', 'NACHO', True),
    (r'\bCHS\b', 'CHEESE', True),
    (r'\bCHSE\b', 'CHEESE', True),
    (r'\bFRT\b', 'FRUIT', True),
    (r'\bPNCH\b', 'PUNCH', True),
    (r'\bHNY\b', 'HONEY', True),
    (r'\bMSTRD\b', 'MUSTARD', True),
    (r'\bPRTZL\b', 'PRETZEL', True),
    (r'\bPTO\b', 'POTATO', True),
    (r'\bCHP\b', 'CHIP', True),
    (r'\bCHPS\b', 'CHIPS', True),
    (r'\bWTR\b', 'WATER', True),
    (r'\bPUR\b', 'PURE', True),
    (r'\bLF\b', 'LIFE', True),
    (r'\bSPRNG\b', 'SPRING', True),
    (r'\bMX\b', 'MIX', True),

    # === Priority 40: Punctuation normalization ===
    (',', ' ', False),
    (';', ' ', False),
    (':', ' ', False),
    ('/', ' ', False),
    (r'\(', ' ', True),
    (r'\)', ' ', True),
    (r'\[', ' ', True),
    (r'\]', ' ', True),
    ('#', '', False),
    (r'\*', '', True),

    # === Priority 50: Category standardization (with word boundaries) ===
    (r'\bBEVERAGE\b', 'BEVERAGES', True),
    (r'\bSNACK\b', 'SNACKS', True),
    (r'\bCONDIMENT\b', 'CONDIMENTS', True),
    (r'\bPREP FOOD\b', 'PREPARED FOODS', True),
    (r'\bPREP FD\b', 'PREPARED FOODS', True),
    (r'\bBEV\b', 'BEVERAGES', True),
    (r'\bSNK\b', 'SNACKS', True),

    # === Priority 90-92: Whitespace normalization (run last) ===
    (r'\s+', ' ', True),
    (r'^\s+', '', True),
    (r'\s+$', '', True),
]

def apply_rules(input_text):
    """Apply normalization rules to input text."""
    if input_text is None:
        return None

    # Start with uppercase for consistent matching
    result = input_text.upper()

    # Apply each rule in priority order
    for rule in RULES:
        pattern, replacement, is_regex = rule
        try:
            if is_regex:
                result = re.sub(pattern, replacement, result, flags=re.IGNORECASE)
            else:
                # Case-insensitive literal replacement
                result = re.sub(re.escape(pattern), replacement, result, flags=re.IGNORECASE)
        except re.error:
            # Skip invalid regex patterns
            continue

    # Final cleanup: collapse spaces and trim
    return re.sub(r'\s+', ' ', result).strip()
$$;

-- ============================================================================
-- Rule management procedures
-- ============================================================================

-- Add a new normalization rule
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.ADD_NORMALIZATION_RULE(
    P_RULE_TYPE VARCHAR,
    P_PATTERN VARCHAR,
    P_REPLACEMENT VARCHAR,
    P_PRIORITY INTEGER,
    P_IS_REGEX BOOLEAN,
    P_DESCRIPTION VARCHAR
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Adds a new normalization rule to the NORMALIZATION_RULES table'
EXECUTE AS OWNER
AS
$$
BEGIN
    INSERT INTO HARMONIZER_DEMO.HARMONIZED.NORMALIZATION_RULES (
        RULE_ID, RULE_TYPE, PATTERN, REPLACEMENT, PRIORITY,
        IS_REGEX, IS_CASE_SENSITIVE, IS_ACTIVE, DESCRIPTION
    )
    SELECT UUID_STRING(), :P_RULE_TYPE, :P_PATTERN, :P_REPLACEMENT, :P_PRIORITY,
           :P_IS_REGEX, FALSE, TRUE, :P_DESCRIPTION;
    
    RETURN 'Rule added successfully';
END;
$$;

-- Toggle rule active status
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.TOGGLE_NORMALIZATION_RULE(
    P_RULE_ID VARCHAR,
    P_IS_ACTIVE BOOLEAN
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Activates or deactivates a normalization rule by RULE_ID'
EXECUTE AS OWNER
AS
$$
BEGIN
    UPDATE HARMONIZER_DEMO.HARMONIZED.NORMALIZATION_RULES
    SET IS_ACTIVE = :P_IS_ACTIVE,
        UPDATED_AT = CURRENT_TIMESTAMP()
    WHERE RULE_ID = :P_RULE_ID;
    
    IF (SQLROWCOUNT = 0) THEN
        RETURN 'Rule not found: ' || :P_RULE_ID;
    END IF;
    
    RETURN 'Rule ' || IFF(:P_IS_ACTIVE, 'activated', 'deactivated');
END;
$$;

-- Get rule statistics
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.GET_NORMALIZATION_STATS()
RETURNS TABLE (
    RULE_TYPE VARCHAR,
    TOTAL_RULES INTEGER,
    ACTIVE_RULES INTEGER,
    AVG_PRIORITY FLOAT
)
LANGUAGE SQL
COMMENT = 'Returns aggregated statistics for normalization rules by type'
EXECUTE AS OWNER
AS
$$
DECLARE
    res RESULTSET;
BEGIN
    res := (
        SELECT
            RULE_TYPE,
            COUNT(*) AS TOTAL_RULES,
            SUM(CASE WHEN IS_ACTIVE THEN 1 ELSE 0 END) AS ACTIVE_RULES,
            AVG(PRIORITY) AS AVG_PRIORITY
        FROM HARMONIZER_DEMO.HARMONIZED.NORMALIZATION_RULES
        GROUP BY RULE_TYPE
        ORDER BY RULE_TYPE
    );
    RETURN TABLE(res);
END;
$$;

-- Test normalization on sample text
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.TEST_NORMALIZATION(P_INPUT_TEXT VARCHAR)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Tests normalization rules against sample text and returns before/after comparison'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_normalized VARCHAR;
BEGIN
    SELECT HARMONIZER_DEMO.HARMONIZED.APPLY_NORMALIZATION_RULES(:P_INPUT_TEXT) INTO :v_normalized;
    RETURN 'Input: ' || :P_INPUT_TEXT || ' => Output: ' || :v_normalized;
END;
$$;

-- Export rules to JSON for backup/transfer
CREATE OR REPLACE PROCEDURE HARMONIZER_DEMO.HARMONIZED.EXPORT_NORMALIZATION_RULES()
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Exports all normalization rules as a JSON array for backup or transfer'
EXECUTE AS OWNER
AS
$$
DECLARE
    v_result VARIANT;
BEGIN
    SELECT ARRAY_AGG(
        OBJECT_CONSTRUCT(
            'rule_type', RULE_TYPE,
            'pattern', PATTERN,
            'replacement', REPLACEMENT,
            'priority', PRIORITY,
            'is_regex', IS_REGEX,
            'is_case_sensitive', IS_CASE_SENSITIVE,
            'is_active', IS_ACTIVE,
            'description', DESCRIPTION
        )
    ) INTO :v_result
    FROM HARMONIZER_DEMO.HARMONIZED.NORMALIZATION_RULES
    ORDER BY RULE_TYPE, PRIORITY;
    
    RETURN :v_result;
END;
$$;