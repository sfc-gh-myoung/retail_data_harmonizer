-- ============================================================================
-- Retail Data Harmonization Demo
-- Script: sql/setup/05_seed_data/05l_raw_items_university.sql
-- Purpose: Generate 1000+ POS_UNIVERSITY records using realistic naming patterns
-- ============================================================================
--
-- POS_UNIVERSITY Characteristics:
-- - Lowercase, casual descriptions (coke 20oz, hot dog reg)
-- - Student-entered, informal naming with typos/abbreviations
-- - High caffeine/energy drink consumption
-- - Fast food favorites, late night snacks
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

INSERT INTO HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS 
    (ITEM_ID, RAW_DESCRIPTION, SOURCE_SYSTEM, SOURCE_ITEM_CODE, EVENT_ID, TRANSACTION_COUNT, TRANSACTION_DATE, REGISTER_ID, MATCH_STATUS)
SELECT 
    UUID_STRING(),
    CASE MOD(SEQ4(), 150)
        -- Sodas - lowercase casual (0-14)
        WHEN 0 THEN 'coke 20oz'
        WHEN 1 THEN 'coca cola 20oz'
        WHEN 2 THEN 'coke classic'
        WHEN 3 THEN 'diet coke 20oz'
        WHEN 4 THEN 'diet coke'
        WHEN 5 THEN 'coke zero'
        WHEN 6 THEN 'sprite 20oz'
        WHEN 7 THEN 'pepsi 20oz'
        WHEN 8 THEN 'diet pepsi'
        WHEN 9 THEN 'mtn dew 20oz'
        WHEN 10 THEN 'mountain dew'
        WHEN 11 THEN 'dr pepper'
        WHEN 12 THEN 'root beer'
        WHEN 13 THEN 'fanta orange'
        WHEN 14 THEN 'cherry coke'
        -- Energy drinks - very popular (15-29)
        WHEN 15 THEN 'red bull 12oz'
        WHEN 16 THEN 'redbull'
        WHEN 17 THEN 'red bull'
        WHEN 18 THEN 'monster 16oz'
        WHEN 19 THEN 'monster energy'
        WHEN 20 THEN 'monster'
        WHEN 21 THEN 'monster zero ultra'
        WHEN 22 THEN 'monster ultra'
        WHEN 23 THEN 'bang energy'
        WHEN 24 THEN 'bang'
        WHEN 25 THEN 'celsius energy'
        WHEN 26 THEN 'celsius'
        WHEN 27 THEN 'rockstar energy'
        WHEN 28 THEN 'nos energy'
        WHEN 29 THEN 'reign energy'
        -- Coffee (30-38)
        WHEN 30 THEN 'starbucks frappuccino mocha'
        WHEN 31 THEN 'starbucks mocha'
        WHEN 32 THEN 'starbucks frappuccino vanilla'
        WHEN 33 THEN 'starbucks frapp'
        WHEN 34 THEN 'cold brew coffee'
        WHEN 35 THEN 'iced coffee'
        WHEN 36 THEN 'starbucks doubleshot'
        WHEN 37 THEN 'dunkin iced coffee'
        WHEN 38 THEN 'java monster'
        -- Water (39-44)
        WHEN 39 THEN 'dasani water 20oz'
        WHEN 40 THEN 'dasani'
        WHEN 41 THEN 'aquafina 20oz'
        WHEN 42 THEN 'aquafina'
        WHEN 43 THEN 'bottled water'
        WHEN 44 THEN 'smartwater'
        -- Chips - Big category (45-64)
        WHEN 45 THEN 'lays chips'
        WHEN 46 THEN 'lays classic'
        WHEN 47 THEN 'lays potato chips'
        WHEN 48 THEN 'lays bbq'
        WHEN 49 THEN 'lays sour cream onion'
        WHEN 50 THEN 'doritos nacho'
        WHEN 51 THEN 'doritos nacho cheese'
        WHEN 52 THEN 'doritos cool ranch'
        WHEN 53 THEN 'doritos'
        WHEN 54 THEN 'hot cheetos'
        WHEN 55 THEN 'cheetos'
        WHEN 56 THEN 'cheetos flamin hot'
        WHEN 57 THEN 'cheetos crunchy'
        WHEN 58 THEN 'takis'
        WHEN 59 THEN 'takis fuego'
        WHEN 60 THEN 'fritos'
        WHEN 61 THEN 'fritos corn chips'
        WHEN 62 THEN 'ruffles cheddar'
        WHEN 63 THEN 'pringles'
        WHEN 64 THEN 'funyuns'
        -- Pizza (65-74)
        WHEN 65 THEN 'pizza slice pepperoni'
        WHEN 66 THEN 'pepperoni pizza'
        WHEN 67 THEN 'pep pizza slice'
        WHEN 68 THEN 'pepperoni slice'
        WHEN 69 THEN 'cheese pizza'
        WHEN 70 THEN 'cheese slice'
        WHEN 71 THEN 'plain pizza'
        WHEN 72 THEN 'supreme pizza'
        WHEN 73 THEN 'meat lovers pizza'
        WHEN 74 THEN 'bbq chicken pizza'
        -- Burgers and Hot Dogs (75-86)
        WHEN 75 THEN 'cheeseburger'
        WHEN 76 THEN 'cheese burger'
        WHEN 77 THEN 'bacon cheeseburger'
        WHEN 78 THEN 'double cheeseburger'
        WHEN 79 THEN 'hamburger'
        WHEN 80 THEN 'veggie burger'
        WHEN 81 THEN 'hot dog'
        WHEN 82 THEN 'hotdog'
        WHEN 83 THEN 'jumbo hot dog'
        WHEN 84 THEN 'chili dog'
        WHEN 85 THEN 'corn dog'
        WHEN 86 THEN 'polish sausage'
        -- Fries and Sides (87-96)
        WHEN 87 THEN 'fries large'
        WHEN 88 THEN 'large fries'
        WHEN 89 THEN 'fries'
        WHEN 90 THEN 'french fries'
        WHEN 91 THEN 'curly fries'
        WHEN 92 THEN 'waffle fries'
        WHEN 93 THEN 'nachos cheese'
        WHEN 94 THEN 'nachos'
        WHEN 95 THEN 'loaded nachos'
        WHEN 96 THEN 'onion rings'
        -- Chicken (97-106)
        WHEN 97 THEN 'chicken tenders'
        WHEN 98 THEN 'chicken strips'
        WHEN 99 THEN 'chicken nuggets'
        WHEN 100 THEN 'chkn tenders 4pc'
        WHEN 101 THEN 'chicken tenders 6pc'
        WHEN 102 THEN 'chicken sandwich'
        WHEN 103 THEN 'spicy chicken sandwich'
        WHEN 104 THEN 'chicken wrap'
        WHEN 105 THEN 'buffalo chicken wrap'
        WHEN 106 THEN 'chicken wings'
        -- Candy (107-118)
        WHEN 107 THEN 'snickers'
        WHEN 108 THEN 'snickers bar'
        WHEN 109 THEN 'm&m peanut'
        WHEN 110 THEN 'm&ms'
        WHEN 111 THEN 'reeses'
        WHEN 112 THEN 'reeses cups'
        WHEN 113 THEN 'kit kat'
        WHEN 114 THEN 'twix'
        WHEN 115 THEN 'skittles'
        WHEN 116 THEN 'starburst'
        WHEN 117 THEN 'sour patch kids'
        WHEN 118 THEN 'swedish fish'
        -- Gatorade/Sports (119-124)
        WHEN 119 THEN 'gatorade orange'
        WHEN 120 THEN 'gatorade fruit punch'
        WHEN 121 THEN 'gatorade'
        WHEN 122 THEN 'gatorade cool blue'
        WHEN 123 THEN 'powerade'
        WHEN 124 THEN 'body armor'
        -- Late Night/Other (125-139)
        WHEN 125 THEN 'soft pretzel'
        WHEN 126 THEN 'pretzel bites'
        WHEN 127 THEN 'popcorn'
        WHEN 128 THEN 'mozzarella sticks'
        WHEN 129 THEN 'mac and cheese'
        WHEN 130 THEN 'quesadilla'
        WHEN 131 THEN 'burrito'
        WHEN 132 THEN 'taco'
        WHEN 133 THEN 'ramen'
        WHEN 134 THEN 'cup noodles'
        WHEN 135 THEN 'instant ramen'
        WHEN 136 THEN 'goldfish crackers'
        WHEN 137 THEN 'pretzels'
        WHEN 138 THEN 'trail mix'
        WHEN 139 THEN 'granola bar'
        -- Ice Cream/Desserts (140-149)
        WHEN 140 THEN 'ice cream cone'
        WHEN 141 THEN 'ice cream sandwich'
        WHEN 142 THEN 'ice cream sundae'
        WHEN 143 THEN 'frozen yogurt'
        WHEN 144 THEN 'milkshake'
        WHEN 145 THEN 'cookie'
        WHEN 146 THEN 'brownie'
        WHEN 147 THEN 'rice krispie treat'
        WHEN 148 THEN 'pop tart'
        ELSE 'oreos'
    END AS RAW_DESC,
    'POS_UNIVERSITY',
    'UNI-' || LPAD(MOD(SEQ4(), 100)::VARCHAR, 3, '0'),
    'EVT-UNI-' || LPAD((MOD(SEQ4(), 15) + 1)::VARCHAR, 3, '0'),
    UNIFORM(50, 500, RANDOM()),
    DATEADD(day, MOD(SEQ4(), 150), '2025-08-15')::DATE,
    'DH' || (MOD(SEQ4(), 4) + 1)::VARCHAR,
    'PENDING'
FROM TABLE(GENERATOR(ROWCOUNT => 1500));
