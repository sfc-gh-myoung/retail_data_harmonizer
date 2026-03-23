-- ============================================================================
-- Retail Data Harmonization Demo
-- Script: sql/setup/05_seed_data/05h_raw_items_duplicates.sql
-- Purpose: Generate 1000 intentional cross-system duplicates for testing
-- These are variations of the same items across different source systems
-- to simulate real-world data quality issues and test deduplication logic
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

INSERT INTO HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS 
    (ITEM_ID, RAW_DESCRIPTION, SOURCE_SYSTEM, SOURCE_ITEM_CODE, EVENT_ID, TRANSACTION_COUNT, TRANSACTION_DATE, REGISTER_ID, MATCH_STATUS)
SELECT 
    UUID_STRING(),
    CASE MOD(SEQ4(), 200)
        -- Coca-Cola variations across systems (0-9)
        WHEN 0 THEN 'CK CLS 20Z'
        WHEN 1 THEN 'Classic Coca-Cola 20oz Bottle'
        WHEN 2 THEN 'coca cola 20 oz'
        WHEN 3 THEN 'Coca-Cola Classic 20 Ounce'
        WHEN 4 THEN 'COKE CLSC 20OZ'
        WHEN 5 THEN 'CK ZERO 20Z'
        WHEN 6 THEN 'Zero Sugar Coca-Cola 20oz'
        WHEN 7 THEN 'coke zero 20oz'
        WHEN 8 THEN 'Coca-Cola Zero Sugar 20 Ounce'
        WHEN 9 THEN 'COKE ZRO 20OZ'
        -- Diet Coke variations (10-14)
        WHEN 10 THEN 'DT CK 20Z'
        WHEN 11 THEN 'Diet Coke Bottle 20oz'
        WHEN 12 THEN 'diet coke 20 oz btl'
        WHEN 13 THEN 'Diet Coke 20 Ounce Bottle'
        WHEN 14 THEN 'DT COKE 20OZ BTL'
        -- Sprite variations (15-19)
        WHEN 15 THEN 'SPRT 20Z BTL'
        WHEN 16 THEN 'Sprite Lemon-Lime 20oz'
        WHEN 17 THEN 'sprite 20oz bottl'
        WHEN 18 THEN 'Sprite 20 Ounce Bottle'
        WHEN 19 THEN 'SPRT LMN LM 20Z'
        -- Pepsi variations (20-24)
        WHEN 20 THEN 'PEP 20Z BTL'
        WHEN 21 THEN 'Pepsi Cola 20oz Bottle'
        WHEN 22 THEN 'pepsi 20 oz'
        WHEN 23 THEN 'Pepsi Cola 20 Ounce'
        WHEN 24 THEN 'PEPSI CLV 20OZ'
        -- Mountain Dew variations (25-29)
        WHEN 25 THEN 'MT DEW 20Z'
        WHEN 26 THEN 'Mountain Dew 20oz Bottle'
        WHEN 27 THEN 'mtn dew 20 oz'
        WHEN 28 THEN 'Mountain Dew 20 Ounce'
        WHEN 29 THEN 'MTN DEW ORIG 20Z'
        -- Dr Pepper variations (30-34)
        WHEN 30 THEN 'DR PEP 20Z'
        WHEN 31 THEN 'Dr Pepper 20oz Bottle'
        WHEN 32 THEN 'dr pepper 20 oz'
        WHEN 33 THEN 'Dr Pepper 20 Ounce'
        WHEN 34 THEN 'DR PPPR 20OZ BTL'
        -- Dasani variations (35-39)
        WHEN 35 THEN 'DASANI 16.9Z'
        WHEN 36 THEN 'Dasani Water 16.9oz Bottle'
        WHEN 37 THEN 'dasani water 16.9 oz'
        WHEN 38 THEN 'Dasani Purified Water 16.9 Ounce'
        WHEN 39 THEN 'DASNI WTR 16.9Z'
        -- Aquafina variations (40-44)
        WHEN 40 THEN 'AQUA 16.9Z'
        WHEN 41 THEN 'Aquafina Water 16.9oz'
        WHEN 42 THEN 'aquafina water 16.9'
        WHEN 43 THEN 'Aquafina Purified Water 16.9 Ounce'
        WHEN 44 THEN 'AQFNA WTR 16.9Z'
        -- Gatorade Fruit Punch (45-49)
        WHEN 45 THEN 'GTRDE FRT PNCH 20Z'
        WHEN 46 THEN 'Gatorade Fruit Punch 20oz'
        WHEN 47 THEN 'gatorade fruit punch 20 oz'
        WHEN 48 THEN 'Gatorade Fruit Punch 20 Ounce'
        WHEN 49 THEN 'GTRD FRT PCH 20OZ'
        -- Red Bull variations (50-54)
        WHEN 50 THEN 'RB 8.4Z'
        WHEN 51 THEN 'Red Bull Energy 8.4oz Can'
        WHEN 52 THEN 'redbull 8.4 oz'
        WHEN 53 THEN 'Red Bull Energy Drink 8.4 Ounce'
        WHEN 54 THEN 'RDBULL 8.4OZ CAN'
        -- Monster variations (55-59)
        WHEN 55 THEN 'MNSTR 16Z'
        WHEN 56 THEN 'Monster Energy Original 16oz'
        WHEN 57 THEN 'monster energy 16 oz'
        WHEN 58 THEN 'Monster Energy Original 16 Ounce'
        WHEN 59 THEN 'MNSTR ENRGY 16OZ'
        -- Lays Classic (60-64)
        WHEN 60 THEN 'LAY CLS 1Z'
        WHEN 61 THEN 'Lays Classic Chips 1oz'
        WHEN 62 THEN 'lays classic 1 oz'
        WHEN 63 THEN 'Lays Classic Potato Chips 1 Ounce'
        WHEN 64 THEN 'LAYS CLSC 1OZ'
        -- Lays BBQ (65-69)
        WHEN 65 THEN 'LAY BBQ 1Z'
        WHEN 66 THEN 'Lays BBQ Chips 1oz'
        WHEN 67 THEN 'lays bbq 1 oz'
        WHEN 68 THEN 'Lays Barbecue Chips 1 Ounce'
        WHEN 69 THEN 'LAYS BBQ 1OZ'
        -- Doritos Nacho (70-74)
        WHEN 70 THEN 'DRTS NCH 1Z'
        WHEN 71 THEN 'Doritos Nacho Cheese 1oz'
        WHEN 72 THEN 'doritos nacho 1 oz'
        WHEN 73 THEN 'Doritos Nacho Cheese 1 Ounce'
        WHEN 74 THEN 'DORTS NACHO 1OZ'
        -- Doritos Cool Ranch (75-79)
        WHEN 75 THEN 'DRTS CL RNCH 1Z'
        WHEN 76 THEN 'Doritos Cool Ranch 1oz'
        WHEN 77 THEN 'doritos cool ranch 1 oz'
        WHEN 78 THEN 'Doritos Cool Ranch 1 Ounce'
        WHEN 79 THEN 'DORTS CR 1OZ'
        -- Cheetos (80-84)
        WHEN 80 THEN 'CHTS CRNCHY 1Z'
        WHEN 81 THEN 'Cheetos Crunchy 1oz'
        WHEN 82 THEN 'cheetos crunchy 1 oz'
        WHEN 83 THEN 'Cheetos Crunchy 1 Ounce'
        WHEN 84 THEN 'CHTS CRNCH 1OZ'
        -- Snickers (85-89)
        WHEN 85 THEN 'SNKRS 1.86Z'
        WHEN 86 THEN 'Snickers Bar Original 1.86oz'
        WHEN 87 THEN 'snickers bar 1.86 oz'
        WHEN 88 THEN 'Snickers Original Bar 1.86 Ounce'
        WHEN 89 THEN 'SNKRS ORIG 1.86OZ'
        -- M&Ms (90-94)
        WHEN 90 THEN 'M&M MLK 1.69Z'
        WHEN 91 THEN 'M&Ms Milk Chocolate 1.69oz'
        WHEN 92 THEN 'm&ms milk choc 1.69 oz'
        WHEN 93 THEN 'M&Ms Milk Chocolate 1.69 Ounce'
        WHEN 94 THEN 'MMS MLK CHOC 1.69OZ'
        -- Reeses (95-99)
        WHEN 95 THEN 'REES PB 1.5Z'
        WHEN 96 THEN 'Reeses Peanut Butter Cups 1.5oz'
        WHEN 97 THEN 'reeses cups 1.5 oz'
        WHEN 98 THEN 'Reeses Peanut Butter Cups 1.5 Ounce'
        WHEN 99 THEN 'REESE PB CUP 1.5OZ'
        -- Hot Dog Plain (100-104)
        WHEN 100 THEN 'HT DOG PLN'
        WHEN 101 THEN 'Hot Dog All Beef Plain'
        WHEN 102 THEN 'hot dog plain'
        WHEN 103 THEN 'Hot Dog All Beef Plain'
        WHEN 104 THEN 'HTDOG PLAIN'
        -- Chili Cheese Dog (105-109)
        WHEN 105 THEN 'HT DOG CHLI CHS'
        WHEN 106 THEN 'Hot Dog Chili Cheese'
        WHEN 107 THEN 'chili cheese dog'
        WHEN 108 THEN 'Hot Dog Chili Cheese'
        WHEN 109 THEN 'CHLI CHS DOG'
        -- Hamburger (110-114)
        WHEN 110 THEN 'HMBRGR'
        WHEN 111 THEN 'Hamburger Single Patty'
        WHEN 112 THEN 'hamburger'
        WHEN 113 THEN 'Hamburger Single Patty'
        WHEN 114 THEN 'HAMBRGR SNGL'
        -- Cheeseburger (115-119)
        WHEN 115 THEN 'CHSBRGR'
        WHEN 116 THEN 'Cheeseburger Single'
        WHEN 117 THEN 'cheeseburger'
        WHEN 118 THEN 'Cheeseburger with American Cheese'
        WHEN 119 THEN 'CHZBRG SNGL'
        -- Bacon Cheeseburger (120-124)
        WHEN 120 THEN 'BCN CHSBRGR'
        WHEN 121 THEN 'Bacon Cheeseburger'
        WHEN 122 THEN 'bacon cheeseburger'
        WHEN 123 THEN 'Bacon Cheeseburger with Fries'
        WHEN 124 THEN 'BCN CHZBRG'
        -- Pepperoni Pizza (125-129)
        WHEN 125 THEN 'PEP PZA SLC'
        WHEN 126 THEN 'Pepperoni Pizza Slice'
        WHEN 127 THEN 'pepperoni pizza slice'
        WHEN 128 THEN 'Pepperoni Pizza Slice Fresh Baked'
        WHEN 129 THEN 'PPRNI PIZZA SLC'
        -- Cheese Pizza (130-134)
        WHEN 130 THEN 'CHS PZA SLC'
        WHEN 131 THEN 'Cheese Pizza Slice'
        WHEN 132 THEN 'cheese pizza slice'
        WHEN 133 THEN 'Cheese Pizza Slice Fresh Baked'
        WHEN 134 THEN 'CHS PIZZA SLC'
        -- Chicken Tenders (135-139)
        WHEN 135 THEN 'CHKN TNDR 4PC'
        WHEN 136 THEN 'Chicken Tenders 4 Piece'
        WHEN 137 THEN 'chicken tenders 4pc'
        WHEN 138 THEN 'Chicken Tenders 4 Piece with Fries'
        WHEN 139 THEN 'CHKN TNDRS 4PC'
        -- French Fries Large (140-144)
        WHEN 140 THEN 'FRY LG'
        WHEN 141 THEN 'French Fries Large'
        WHEN 142 THEN 'french fries large'
        WHEN 143 THEN 'French Fries Large Portion'
        WHEN 144 THEN 'LRG FRIES'
        -- Nachos (145-149)
        WHEN 145 THEN 'NACHOS'
        WHEN 146 THEN 'Nachos with Cheese'
        WHEN 147 THEN 'nachos cheese'
        WHEN 148 THEN 'Nachos with Cheese Sauce'
        WHEN 149 THEN 'NCHS W CHEESE'
        -- Bud Light (150-154)
        WHEN 150 THEN 'BUD LT 16Z'
        WHEN 151 THEN 'Bud Light 16oz Can'
        WHEN 152 THEN 'bud light 16oz'
        WHEN 153 THEN 'Bud Light 16 Ounce Can'
        WHEN 154 THEN 'BUDLT 16OZ CAN'
        -- Coors Light (155-159)
        WHEN 155 THEN 'CORS LT 16Z'
        WHEN 156 THEN 'Coors Light 16oz Can'
        WHEN 157 THEN 'coors light 16oz'
        WHEN 158 THEN 'Coors Light 16 Ounce Can'
        WHEN 159 THEN 'CRSLT 16OZ CAN'
        -- Miller Lite (160-164)
        WHEN 160 THEN 'MLR LT 16Z'
        WHEN 161 THEN 'Miller Lite 16oz Can'
        WHEN 162 THEN 'miller lite 16oz'
        WHEN 163 THEN 'Miller Lite 16 Ounce Can'
        WHEN 164 THEN 'MLLR LT 16OZ'
        -- Corona (165-169)
        WHEN 165 THEN 'CORONA'
        WHEN 166 THEN 'Corona Extra 12oz'
        WHEN 167 THEN 'corona 12oz'
        WHEN 168 THEN 'Corona Extra 12 Ounce Bottle'
        WHEN 169 THEN 'CRNA EXTRA 12OZ'
        -- Modelo (170-174)
        WHEN 170 THEN 'MODELO'
        WHEN 171 THEN 'Modelo Especial 12oz'
        WHEN 172 THEN 'modelo 12oz'
        WHEN 173 THEN 'Modelo Especial 12 Ounce Can'
        WHEN 174 THEN 'MDLO ESPECL 12OZ'
        -- White Claw (175-179)
        WHEN 175 THEN 'WHTE CLW'
        WHEN 176 THEN 'White Claw 12oz'
        WHEN 177 THEN 'white claw 12oz'
        WHEN 178 THEN 'White Claw Hard Seltzer 12 Ounce'
        WHEN 179 THEN 'WH CLAW SLTZR 12OZ'
        -- Truly (180-184)
        WHEN 180 THEN 'TRULY'
        WHEN 181 THEN 'Truly Seltzer 12oz'
        WHEN 182 THEN 'truly 12oz'
        WHEN 183 THEN 'Truly Hard Seltzer 12 Ounce'
        WHEN 184 THEN 'TRULY SLTZR 12OZ'
        -- Starbucks Frappuccino (185-189)
        WHEN 185 THEN 'STBX FRAP'
        WHEN 186 THEN 'Starbucks Frappuccino Mocha'
        WHEN 187 THEN 'starbucks frappuccino mocha'
        WHEN 188 THEN 'Starbucks Frappuccino Mocha 13.7 Ounce'
        WHEN 189 THEN 'STRBKS FRAP MOCHA'
        -- KitKat (190-194)
        WHEN 190 THEN 'KITKAT 1.5Z'
        WHEN 191 THEN 'Kit Kat Wafer Bar 1.5oz'
        WHEN 192 THEN 'kitkat bar 1.5 oz'
        WHEN 193 THEN 'Kit Kat Wafer Bar 1.5 Ounce'
        WHEN 194 THEN 'KIT KAT 1.5OZ'
        -- Twix (195-199)
        WHEN 195 THEN 'TWX 1.79Z'
        WHEN 196 THEN 'Twix Cookie Bar 1.79oz'
        WHEN 197 THEN 'twix bar 1.79 oz'
        WHEN 198 THEN 'Twix Caramel Cookie Bar 1.79 Ounce'
        ELSE 'TWIX COOKIE 1.79OZ'
    END AS RAW_DESC,
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'POS_STADIUM'
        WHEN 1 THEN 'POS_HOSPITAL'
        WHEN 2 THEN 'POS_UNIVERSITY'
        WHEN 3 THEN 'POS_CORPORATE'
        ELSE 'POS_ARENA'
    END AS SRC_SYS,
    'DUP-' || LPAD(MOD(SEQ4(), 500)::VARCHAR, 4, '0'),
    'EVT-DUP-' || LPAD((MOD(SEQ4(), 20) + 1)::VARCHAR, 3, '0'),
    UNIFORM(50, 500, RANDOM()),
    DATEADD(day, MOD(SEQ4(), 180), '2025-08-01')::DATE,
    'REG-DUP-' || LPAD((MOD(SEQ4(), 10) + 1)::VARCHAR, 2, '0'),
    'PENDING'
FROM TABLE(GENERATOR(ROWCOUNT => 2500));
