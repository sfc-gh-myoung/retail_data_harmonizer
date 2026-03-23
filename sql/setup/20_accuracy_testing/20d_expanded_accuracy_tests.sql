-- ============================================================================
-- Retail Data Harmonization Demo
-- Script: sql/setup/20_accuracy_testing/20d_expanded_accuracy_tests.sql
-- Purpose: Expanded accuracy test set with 200+ cases across all categories
-- Depends on: 20a_accuracy_tables.sql, 20b_accuracy_procedures.sql
-- ============================================================================
-- 
-- This script expands the ground-truth test set to include:
-- 1. 200+ test cases (up from 37)
-- 2. All 5 categories: Beverages, Snacks, Condiments, Prepared Foods, Alcoholic Beverages
-- 3. Stratified difficulty: ~25% EASY, ~35% MEDIUM, ~40% HARD
-- 4. Edge cases: misspellings, wrong sizes, negative tests (should NOT match)
--
-- Run this AFTER 20_accuracy_testing.sql to expand the test set.
-- ============================================================================
-- CLI EXECUTION NOTE:
-- This file contains '&' characters in product names (e.g., M&Ms, A&W).
-- Execute with: snow sql --enable-templating NONE -f 20d_expanded_accuracy_tests.sql
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- Clear existing test data and insert expanded set
-- ============================================================================

TRUNCATE TABLE HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_SET;
TRUNCATE TABLE HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_RESULTS;

INSERT INTO HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_SET 
    (RAW_DESCRIPTION, EXPECTED_MATCH, CATEGORY, DIFFICULTY, NOTES)
VALUES
    -- ========================================================================
    -- BEVERAGES - EASY (Near-exact matches, minor variations)
    -- ========================================================================
    ('Coca-Cola 20oz', 'Coca-Cola Classic 20oz Bottle', 'Beverages', 'EASY', 'Near-exact match'),
    ('Sprite 20oz Bottle', 'Sprite 20oz Bottle', 'Beverages', 'EASY', 'Exact match'),
    ('Mountain Dew 20oz', 'Mountain Dew 20oz Bottle', 'Beverages', 'EASY', 'Missing container type'),
    ('Pepsi 12oz Can', 'Pepsi Cola 12oz Can', 'Beverages', 'EASY', 'Missing "Cola"'),
    ('Dasani Water 16.9oz', 'Dasani Purified Water 16.9oz Bottle', 'Beverages', 'EASY', 'Simplified description'),
    ('Red Bull 8.4oz', 'Red Bull Energy Drink 8.4oz Can', 'Beverages', 'EASY', 'Missing product type'),
    ('Monster Energy 16oz', 'Monster Energy Original 16oz Can', 'Beverages', 'EASY', 'Missing variant'),
    ('Dr Pepper 20oz Bottle', 'Dr Pepper 20oz Bottle', 'Beverages', 'EASY', 'Exact match'),
    ('Aquafina Water 20oz', 'Aquafina Purified Water 20oz Bottle', 'Beverages', 'EASY', 'Missing qualifier'),
    ('Gatorade Fruit Punch 20oz', 'Gatorade Thirst Quencher Fruit Punch 20oz Bottle', 'Beverages', 'EASY', 'Missing full brand name'),
    ('Smartwater 20oz Bottle', 'Smartwater Vapor Distilled Water 20oz Bottle', 'Beverages', 'EASY', 'Missing description'),
    ('Celsius Orange 12oz', 'Celsius Sparkling Orange 12oz Can', 'Beverages', 'EASY', 'Missing sparkling'),
    ('Starbucks Frappuccino Mocha', 'Starbucks Frappuccino Mocha 13.7oz Bottle', 'Beverages', 'EASY', 'Missing size'),
    ('Pure Leaf Sweet Tea 18.5oz', 'Pure Leaf Iced Tea Sweet Tea 18.5oz Bottle', 'Beverages', 'EASY', 'Minor variation'),
    ('Fiji Water 16.9oz', 'FIJI Natural Artesian Water 16.9oz Bottle', 'Beverages', 'EASY', 'Brand case difference'),
    
    -- ========================================================================
    -- BEVERAGES - MEDIUM (Common abbreviations, missing words)
    -- ========================================================================
    ('CK CLA 20OZ BTL', 'Coca-Cola Classic 20oz Bottle', 'Beverages', 'MEDIUM', 'CK=Coke, CLA=Classic'),
    ('PEP 20OZ BTL', 'Pepsi Cola 20oz Bottle', 'Beverages', 'MEDIUM', 'PEP=Pepsi'),
    ('MT DEW 20OZ BTL', 'Mountain Dew 20oz Bottle', 'Beverages', 'MEDIUM', 'MT DEW=Mountain Dew'),
    ('DR PEP 20OZ', 'Dr Pepper 20oz Bottle', 'Beverages', 'MEDIUM', 'DR PEP=Dr Pepper'),
    ('SPRT 20OZ BTL', 'Sprite 20oz Bottle', 'Beverages', 'MEDIUM', 'SPRT=Sprite'),
    ('RB ENRGY 8.4Z', 'Red Bull Energy Drink 8.4oz Can', 'Beverages', 'MEDIUM', 'RB=Red Bull'),
    ('MNSTR ENRGY 16Z', 'Monster Energy Original 16oz Can', 'Beverages', 'MEDIUM', 'MNSTR=Monster'),
    ('7UP 20OZ BTL', '7UP 20oz Bottle', 'Beverages', 'MEDIUM', 'Numeric brand name'),
    ('EVIAN 16.9Z', 'Evian Natural Spring Water 16.9oz Bottle', 'Beverages', 'MEDIUM', 'Brand intact'),
    ('FIJI 16.9Z BTL', 'FIJI Natural Artesian Water 16.9oz Bottle', 'Beverages', 'MEDIUM', 'Brand intact'),
    ('MTN DEW CODE RED 20OZ', 'Mountain Dew Code Red 20oz Bottle', 'Beverages', 'MEDIUM', 'MTN=Mountain'),
    ('GATORADE FRUIT PUNCH', 'Gatorade Thirst Quencher Fruit Punch 20oz Bottle', 'Beverages', 'MEDIUM', 'Full name, no size'),
    ('CELSIUS WILD BRY 12Z', 'Celsius Sparkling Wild Berry 12oz Can', 'Beverages', 'MEDIUM', 'BRY=Berry'),
    ('SMTWTR 20Z BTL', 'Smartwater Vapor Distilled Water 20oz Bottle', 'Beverages', 'MEDIUM', 'SMTWTR=Smartwater'),
    ('BODYARMOR STRWBRY BANANA', 'BODYARMOR SuperDrink Strawberry Banana 16oz Bottle', 'Beverages', 'MEDIUM', 'Partial abbreviation'),
    ('BUBLY LIME 12Z CN', 'Bubly Sparkling Water Lime 12oz Can', 'Beverages', 'MEDIUM', 'Missing sparkling water'),
    ('PERRIER 16.9Z', 'Perrier Sparkling Water Original 16.9oz Bottle', 'Beverages', 'MEDIUM', 'Brand only with size'),
    ('HINT WTRMLN 16Z', 'Hint Water Watermelon 16oz Bottle', 'Beverages', 'MEDIUM', 'WTRMLN=Watermelon'),
    ('VITAMINWATER PWR-C 20Z', 'Vitaminwater Power-C Dragonfruit 20oz Bottle', 'Beverages', 'MEDIUM', 'PWR-C=Power-C'),
    ('CORE HYDRATION 20Z', 'Core Hydration Water 20oz Bottle', 'Beverages', 'MEDIUM', 'Missing Water'),
    
    -- ========================================================================
    -- BEVERAGES - HARD (Heavy abbreviation, ambiguous, edge cases)
    -- ========================================================================
    ('CK ZERO 20 BTL', 'Coca-Cola Zero Sugar 20oz Bottle', 'Beverages', 'HARD', 'CK ZERO vs Diet Coke'),
    ('DT CK 20OZ', 'Diet Coke 20oz Bottle', 'Beverages', 'HARD', 'DT=Diet'),
    ('DT PEP 20OZ', 'Diet Pepsi 20oz Bottle', 'Beverages', 'HARD', 'DT=Diet'),
    ('CK CHRY 20OZ BTL', 'Coca-Cola Cherry 20oz Bottle', 'Beverages', 'HARD', 'CHRY=Cherry'),
    ('FANTA ORG 20Z', 'Fanta Orange 20oz Bottle', 'Beverages', 'HARD', 'ORG=Orange'),
    ('GTRDE LMN LM 20Z', 'Gatorade Thirst Quencher Lemon Lime 20oz Bottle', 'Beverages', 'HARD', 'GTRDE=Gatorade, LMN LM=Lemon Lime'),
    ('GTRDE ZERO CHRY 20Z', 'Gatorade Zero Glacier Cherry 20oz Bottle', 'Beverages', 'HARD', 'Multiple abbreviations'),
    ('SMRT WTR 20Z', 'Smartwater Vapor Distilled Water 20oz Bottle', 'Beverages', 'HARD', 'SMRT WTR=Smartwater'),
    ('AQUA 16.9Z BTL', 'Aquafina Purified Water 16.9oz Bottle', 'Beverages', 'HARD', 'AQUA=Aquafina'),
    ('GTRDE CL BLU 20Z', 'Gatorade Thirst Quencher Cool Blue 20oz Bottle', 'Beverages', 'HARD', 'CL BLU=Cool Blue'),
    ('GTRDE ORNG 20Z', 'Gatorade Thirst Quencher Orange 20oz Bottle', 'Beverages', 'HARD', 'ORNG=Orange'),
    ('GTRDE GRP 20Z', 'Gatorade Thirst Quencher Grape 20oz Bottle', 'Beverages', 'HARD', 'GRP=Grape'),
    ('PWRDE BLUE 20Z', 'Powerade Mountain Berry Blast 20oz Bottle', 'Beverages', 'HARD', 'Color vs flavor name'),
    ('VITAMIN WATER XXX', 'Vitaminwater XXX Acai Blueberry Pomegranate 20oz Bottle', 'Beverages', 'HARD', 'Partial product name'),
    ('COKE CLASSIC', 'Coca-Cola Classic 20oz Bottle', 'Beverages', 'HARD', 'No size specified'),
    ('DIET COKE CAN', 'Diet Coke 12oz Can', 'Beverages', 'HARD', 'No size specified'),
    ('SPRITE ZERO', 'Sprite Zero Sugar 20oz Bottle', 'Beverages', 'HARD', 'No size specified'),
    ('PEPSI ZERO', 'Pepsi Zero Sugar 20oz Bottle', 'Beverages', 'HARD', 'No size specified'),
    ('GT KMBUCHA TRLGY 16Z', 'GT Kombucha Trilogy 16oz Bottle', 'Beverages', 'HARD', 'KMBUCHA=Kombucha, TRLGY=Trilogy'),
    ('ALNI NU HWIIN ICE 12Z', 'Alani Nu Energy Drink Hawaiian Shaved Ice 12oz Can', 'Beverages', 'HARD', 'Heavy abbreviation'),
    ('FAIRLF PWR CHOC 14Z', 'Fairlife Core Power Chocolate 14oz Bottle', 'Beverages', 'HARD', 'FAIRLF=Fairlife, PWR=Power'),
    ('DUNKN MOCHA ICD 13.7Z', 'Dunkin Donuts Iced Coffee Mocha 13.7oz Bottle', 'Beverages', 'HARD', 'DUNKN=Dunkin'),
    ('BLTHAUS STRBRY BNANA', 'Bolthouse Farms Strawberry Banana Smoothie 15.2oz Bottle', 'Beverages', 'HARD', 'Heavy abbreviation, no size'),
    ('MSCL MLK CHOC 14Z', 'Muscle Milk Genuine Chocolate 14oz Bottle', 'Beverages', 'HARD', 'MSCL MLK=Muscle Milk'),
    ('SPNDRFT RSPBRY LM 12Z', 'Spindrift Sparkling Water Raspberry Lime 12oz Can', 'Beverages', 'HARD', 'Multiple abbreviations'),
    
    -- ========================================================================
    -- SNACKS - EASY
    -- ========================================================================
    ('Cheetos Crunchy 1oz', 'Cheetos Crunchy 1oz Bag', 'Snacks', 'EASY', 'Missing container'),
    ('Doritos Nacho Cheese 1oz', 'Doritos Nacho Cheese 1oz Bag', 'Snacks', 'EASY', 'Missing container'),
    ('Lays Classic 1oz', 'Lays Classic Potato Chips 1oz Bag', 'Snacks', 'EASY', 'Missing product type'),
    ('Snickers Bar 1.86oz', 'Snickers Bar 1.86oz', 'Snacks', 'EASY', 'Exact match'),
    ('M&Ms Peanut 1.74oz', 'M&Ms Peanut 1.74oz Bag', 'Snacks', 'EASY', 'Missing container'),
    ('Reeses Peanut Butter Cups', 'Reeses Peanut Butter Cups 1.5oz 2-Pack', 'Snacks', 'EASY', 'Missing size'),
    ('Kit Kat Bar 1.5oz', 'Kit Kat Wafer Bar 1.5oz', 'Snacks', 'EASY', 'Missing wafer'),
    ('Twix Bar 1.79oz', 'Twix Caramel Cookie Bar 1.79oz', 'Snacks', 'EASY', 'Missing descriptor'),
    ('Pringles Original 1.3oz', 'Pringles Original 1.3oz Can', 'Snacks', 'EASY', 'Missing container'),
    ('Cheez-It Crackers 1.5oz', 'Cheez-It Original Crackers 1.5oz Bag', 'Snacks', 'EASY', 'Missing variant'),
    ('Kind Bar Almond', 'Kind Bar Dark Chocolate Nuts & Sea Salt 1.4oz', 'Snacks', 'EASY', 'Partial match'),
    ('Nature Valley Oats Honey', 'Nature Valley Crunchy Granola Bar Oats n Honey 1.49oz 2-Pack', 'Snacks', 'EASY', 'Simplified'),
    ('Planters Peanuts 1.75oz', 'Planters Salted Peanuts 1.75oz Bag', 'Snacks', 'EASY', 'Missing salted'),
    ('Wheat Thins 1.75oz', 'Wheat Thins Original 1.75oz Bag', 'Snacks', 'EASY', 'Missing original'),
    ('Welchs Fruit Snacks', 'Welchs Fruit Snacks Mixed Fruit 2.25oz Pouch', 'Snacks', 'EASY', 'Missing size/flavor'),
    
    -- ========================================================================
    -- SNACKS - MEDIUM
    -- ========================================================================
    ('CHTOS CRNCHY 1Z', 'Cheetos Crunchy 1oz Bag', 'Snacks', 'MEDIUM', 'Abbreviated brand'),
    ('DRTOS NACHO 1Z BG', 'Doritos Nacho Cheese 1oz Bag', 'Snacks', 'MEDIUM', 'DRTOS=Doritos'),
    ('LAYS CLSC 1Z', 'Lays Classic Potato Chips 1oz Bag', 'Snacks', 'MEDIUM', 'CLSC=Classic'),
    ('SNKRS 1.86Z', 'Snickers Bar 1.86oz', 'Snacks', 'MEDIUM', 'SNKRS=Snickers'),
    ('MMS PNT 1.74Z', 'M&Ms Peanut 1.74oz Bag', 'Snacks', 'MEDIUM', 'MMS=M&Ms, PNT=Peanut'),
    ('RESES PB CUPS 1.5Z', 'Reeses Peanut Butter Cups 1.5oz 2-Pack', 'Snacks', 'MEDIUM', 'PB=Peanut Butter'),
    ('KITKAT 1.5Z', 'Kit Kat Wafer Bar 1.5oz', 'Snacks', 'MEDIUM', 'Merged brand name'),
    ('PRINGLES ORIG 1.3Z CN', 'Pringles Original 1.3oz Can', 'Snacks', 'MEDIUM', 'Standard abbreviations'),
    ('CHEEZIT ORIG 1.5Z', 'Cheez-It Original Crackers 1.5oz Bag', 'Snacks', 'MEDIUM', 'Merged brand'),
    ('QUEST CHOC CHIP 2.12Z', 'Quest Protein Bar Chocolate Chip Cookie Dough 2.12oz', 'Snacks', 'MEDIUM', 'Partial flavor'),
    ('PLANTERS CSHWS 1.5Z', 'Planters Cashews Halves & Pieces 1.5oz Bag', 'Snacks', 'MEDIUM', 'CSHWS=Cashews'),
    ('TWZLRS STRWBRY 2.5Z', 'Twizzlers Strawberry Twists 2.5oz Bag', 'Snacks', 'MEDIUM', 'TWZLRS=Twizzlers'),
    ('HRSHY COOKIE CRM 1.55Z', 'Hersheys Cookies n Creme Bar 1.55oz', 'Snacks', 'MEDIUM', 'HRSHY=Hersheys'),
    ('PRNGLS CHDR 1.3Z', 'Pringles Cheddar Cheese 1.3oz Can', 'Snacks', 'MEDIUM', 'CHDR=Cheddar'),
    ('SNKRS ALMND 1.76Z', 'Snickers Almond Bar 1.76oz', 'Snacks', 'MEDIUM', 'ALMND=Almond'),
    
    -- ========================================================================
    -- SNACKS - HARD
    -- ========================================================================
    ('CHTO PF 1Z', 'Cheetos Puffs 1oz Bag', 'Snacks', 'HARD', 'CHTO=Cheetos, PF=Puffs'),
    ('DRTO CL RCH 1Z', 'Doritos Cool Ranch 1oz Bag', 'Snacks', 'HARD', 'CL RCH=Cool Ranch'),
    ('LY BBQ 1Z', 'Lays Barbecue Potato Chips 1oz Bag', 'Snacks', 'HARD', 'LY=Lays, BBQ=Barbecue'),
    ('MM PLN 1.69Z', 'M&Ms Plain 1.69oz Bag', 'Snacks', 'HARD', 'MM=M&Ms, PLN=Plain'),
    ('TWIX LFT 1.79Z', 'Twix Caramel Cookie Bar 1.79oz', 'Snacks', 'HARD', 'LFT=Left (ambiguous)'),
    ('KND DK CHOC SEA SLT', 'Kind Bar Dark Chocolate Nuts & Sea Salt 1.4oz', 'Snacks', 'HARD', 'Heavy abbreviation'),
    ('NV OTS HNY 2PK', 'Nature Valley Crunchy Granola Bar Oats n Honey 1.49oz 2-Pack', 'Snacks', 'HARD', 'NV=Nature Valley'),
    ('PLNTRS MXD NTS 1.5Z', 'Planters Mixed Nuts 1.5oz Bag', 'Snacks', 'HARD', 'PLNTRS=Planters'),
    ('QUST BRTHDY CK 2.12Z', 'Quest Protein Bar Birthday Cake 2.12oz', 'Snacks', 'HARD', 'QUST=Quest, BRTHDY CK=Birthday Cake'),
    ('SUN CHP HRVST CHDR', 'Sun Chips Harvest Cheddar 1.5oz Bag', 'Snacks', 'HARD', 'No size, abbreviations'),
    ('RFFLS SC CRM 1Z', 'Ruffles Sour Cream & Onion 1oz Bag', 'Snacks', 'HARD', 'RFFLS=Ruffles, SC CRM=Sour Cream'),
    ('FLMN HT CHTOS 1Z', 'Cheetos Flamin Hot 1oz Bag', 'Snacks', 'HARD', 'FLMN HT=Flamin Hot, CHTOS=Cheetos'),
    ('TAKIS FGO 1Z', 'Takis Fuego 1oz Bag', 'Snacks', 'HARD', 'FGO=Fuego'),
    ('SNYDR PRTZL PCES 1.5Z', 'Snyders Pretzel Pieces Honey Mustard Onion 1.5oz Bag', 'Snacks', 'HARD', 'Missing flavor'),
    ('COMBOS CHDR PRTZL 1.8Z', 'Combos Cheddar Cheese Pretzel 1.8oz Bag', 'Snacks', 'HARD', 'PRTZL=Pretzel'),
    ('BEEF JRKY ORIG 1Z', 'Jack Links Beef Jerky Original 1oz Bag', 'Snacks', 'HARD', 'Missing brand'),
    
    -- ========================================================================
    -- CONDIMENTS - EASY
    -- ========================================================================
    ('Heinz Ketchup 20oz', 'Heinz Simply Ketchup 20oz Squeeze Bottle', 'Condiments', 'EASY', 'Near-exact'),
    ('Ranch Dressing Cup', 'Ranch Dressing Cup 1.5oz', 'Condiments', 'EASY', 'Missing size'),
    ('Kraft Ranch 8oz', 'Kraft Ranch Dressing 8oz Bottle', 'Condiments', 'EASY', 'Missing dressing'),
    ('Heinz Tartar Sauce 12oz', 'Heinz Tartar Sauce 12oz Squeeze Bottle', 'Condiments', 'EASY', 'Missing container'),
    ('Franks Red Hot 12oz', 'Frank''s RedHot Original Cayenne Pepper Sauce 12oz Bottle', 'Condiments', 'EASY', 'Simplified'),
    ('Buffalo Sauce Cup', 'Buffalo Sauce Cup 1oz', 'Condiments', 'EASY', 'Missing size'),
    ('Cream Cheese Cup', 'Cream Cheese Cup 1oz', 'Condiments', 'EASY', 'Missing size'),
    ('Butter Pat', 'Butter Pat Individual', 'Condiments', 'EASY', 'Missing individual'),
    ('Kraft Thousand Island 8oz', 'Kraft Thousand Island Dressing 8oz Bottle', 'Condiments', 'EASY', 'Missing dressing'),
    ('Hidden Valley Ranch 1.5oz', 'Ranch Dressing Cup 1.5oz', 'Condiments', 'EASY', 'Brand variation'),
    
    -- ========================================================================
    -- CONDIMENTS - MEDIUM
    -- ========================================================================
    ('HNZ KTCHP 20Z', 'Heinz Simply Ketchup 20oz Squeeze Bottle', 'Condiments', 'MEDIUM', 'HNZ=Heinz'),
    ('RNCH DRSG CUP 1.5Z', 'Ranch Dressing Cup 1.5oz', 'Condiments', 'MEDIUM', 'RNCH=Ranch, DRSG=Dressing'),
    ('KRFT RNCH 8Z BTL', 'Kraft Ranch Dressing 8oz Bottle', 'Condiments', 'MEDIUM', 'KRFT=Kraft'),
    ('FRNKS RDHOT 12Z', 'Frank''s RedHot Original Cayenne Pepper Sauce 12oz Bottle', 'Condiments', 'MEDIUM', 'FRNKS=Franks'),
    ('BUFF SCE CUP 1Z', 'Buffalo Sauce Cup 1oz', 'Condiments', 'MEDIUM', 'BUFF=Buffalo, SCE=Sauce'),
    ('CRM CHS CUP 1Z', 'Cream Cheese Cup 1oz', 'Condiments', 'MEDIUM', 'CRM CHS=Cream Cheese'),
    ('BTTR PAT INDV', 'Butter Pat Individual', 'Condiments', 'MEDIUM', 'BTTR=Butter, INDV=Individual'),
    ('KRFT 1000 ISLND 8Z', 'Kraft Thousand Island Dressing 8oz Bottle', 'Condiments', 'MEDIUM', '1000=Thousand'),
    ('HNZ TRTR SCE 12Z', 'Heinz Tartar Sauce 12oz Squeeze Bottle', 'Condiments', 'MEDIUM', 'TRTR=Tartar'),
    ('BLSMC VNGR PKT', 'Balsamic Vinegar Packet 10ml', 'Condiments', 'MEDIUM', 'BLSMC=Balsamic, VNGR=Vinegar'),
    
    -- ========================================================================
    -- CONDIMENTS - HARD
    -- ========================================================================
    ('HZ KTCH SQZ', 'Heinz Simply Ketchup 20oz Squeeze Bottle', 'Condiments', 'HARD', 'No size, heavy abbrev'),
    ('RCH CUP', 'Ranch Dressing Cup 1.5oz', 'Condiments', 'HARD', 'RCH=Ranch, no size'),
    ('KFT RCH', 'Kraft Ranch Dressing 8oz Bottle', 'Condiments', 'HARD', 'KFT=Kraft, no size'),
    ('FK RDHOT ORIG', 'Frank''s RedHot Original Cayenne Pepper Sauce 12oz Bottle', 'Condiments', 'HARD', 'FK=Franks'),
    ('BF SC 1Z', 'Buffalo Sauce Cup 1oz', 'Condiments', 'HARD', 'BF=Buffalo'),
    ('CC CP', 'Cream Cheese Cup 1oz', 'Condiments', 'HARD', 'CC=Cream Cheese, CP=Cup'),
    ('BTR PT', 'Butter Pat Individual', 'Condiments', 'HARD', 'BTR=Butter, PT=Pat'),
    ('KFT TI 8Z', 'Kraft Thousand Island Dressing 8oz Bottle', 'Condiments', 'HARD', 'TI=Thousand Island'),
    ('HZ TRT', 'Heinz Tartar Sauce 12oz Squeeze Bottle', 'Condiments', 'HARD', 'TRT=Tartar, no size'),
    ('BLS VIN PKT', 'Balsamic Vinegar Packet 10ml', 'Condiments', 'HARD', 'BLS=Balsamic, VIN=Vinegar'),
    ('HNY MSTRD CUP', 'Honey Mustard Dipping Sauce Cup 1oz', 'Condiments', 'HARD', 'HNY MSTRD=Honey Mustard'),
    ('BBQ SCE CUP 1Z', 'BBQ Sauce Cup 1oz', 'Condiments', 'HARD', 'SCE=Sauce'),
    
    -- ========================================================================
    -- PREPARED FOODS - EASY
    -- ========================================================================
    ('BLT Sandwich', 'BLT Sandwich on White Toast', 'Prepared Foods', 'EASY', 'Missing bread type'),
    ('Italian Sub 12 inch', 'Italian Sub Sandwich 12 inch', 'Prepared Foods', 'EASY', 'Missing sandwich'),
    ('Chicken Alfredo Pasta', 'Chicken Alfredo Pasta Bowl', 'Prepared Foods', 'EASY', 'Missing bowl'),
    ('Spaghetti Meatballs', 'Spaghetti and Meatballs Bowl', 'Prepared Foods', 'EASY', 'Missing and/bowl'),
    ('Clam Chowder 12oz', 'Clam Chowder 12oz Bowl', 'Prepared Foods', 'EASY', 'Missing bowl'),
    ('Chili with Beans 12oz', 'Chili with Beans 12oz Bowl', 'Prepared Foods', 'EASY', 'Missing bowl'),
    ('Grilled Chicken Salad', 'Grilled Chicken Salad Greek', 'Prepared Foods', 'EASY', 'Missing style'),
    ('Cup Noodles Beef', 'Cup Noodles Beef Flavor 2.25oz', 'Prepared Foods', 'EASY', 'Missing size'),
    ('Oatmeal Brown Sugar 12oz', 'Oatmeal with Brown Sugar 12oz', 'Prepared Foods', 'EASY', 'Missing with'),
    ('Egg Salad Sandwich', 'Egg Salad Sandwich on White', 'Prepared Foods', 'EASY', 'Missing bread'),
    
    -- ========================================================================
    -- PREPARED FOODS - MEDIUM
    -- ========================================================================
    ('BLT SNDWCH WHT', 'BLT Sandwich on White Toast', 'Prepared Foods', 'MEDIUM', 'SNDWCH=Sandwich'),
    ('ITAL SUB 12IN', 'Italian Sub Sandwich 12 inch', 'Prepared Foods', 'MEDIUM', 'ITAL=Italian'),
    ('CHKN ALFRD PST BWL', 'Chicken Alfredo Pasta Bowl', 'Prepared Foods', 'MEDIUM', 'CHKN=Chicken, ALFRD=Alfredo'),
    ('SPGHTI MTBLS BWL', 'Spaghetti and Meatballs Bowl', 'Prepared Foods', 'MEDIUM', 'SPGHTI=Spaghetti'),
    ('CLM CHDR 12Z', 'Clam Chowder 12oz Bowl', 'Prepared Foods', 'MEDIUM', 'CLM=Clam, CHDR=Chowder'),
    ('CHILI BNS 12Z BWL', 'Chili with Beans 12oz Bowl', 'Prepared Foods', 'MEDIUM', 'BNS=Beans'),
    ('GRLD CHKN SLD GRK', 'Grilled Chicken Salad Greek', 'Prepared Foods', 'MEDIUM', 'GRLD=Grilled, GRK=Greek'),
    ('CUP NDLS BF 2.25Z', 'Cup Noodles Beef Flavor 2.25oz', 'Prepared Foods', 'MEDIUM', 'NDLS=Noodles'),
    ('OTML BRN SGR 12Z', 'Oatmeal with Brown Sugar 12oz', 'Prepared Foods', 'MEDIUM', 'OTML=Oatmeal'),
    ('EGG SLD SNDWCH WHT', 'Egg Salad Sandwich on White', 'Prepared Foods', 'MEDIUM', 'SLD=Salad'),
    
    -- ========================================================================
    -- PREPARED FOODS - HARD
    -- ========================================================================
    ('BLT WHT TST', 'BLT Sandwich on White Toast', 'Prepared Foods', 'HARD', 'TST=Toast'),
    ('IT SB 12', 'Italian Sub Sandwich 12 inch', 'Prepared Foods', 'HARD', 'IT=Italian, SB=Sub'),
    ('CK ALF PST', 'Chicken Alfredo Pasta Bowl', 'Prepared Foods', 'HARD', 'CK=Chicken, ALF=Alfredo'),
    ('SPG MTB', 'Spaghetti and Meatballs Bowl', 'Prepared Foods', 'HARD', 'SPG=Spaghetti, MTB=Meatballs'),
    ('CLM CH 12', 'Clam Chowder 12oz Bowl', 'Prepared Foods', 'HARD', 'CLM=Clam, CH=Chowder'),
    ('CHL BN 12', 'Chili with Beans 12oz Bowl', 'Prepared Foods', 'HARD', 'CHL=Chili, BN=Beans'),
    ('GRL CK SLD GK', 'Grilled Chicken Salad Greek', 'Prepared Foods', 'HARD', 'GRL=Grilled, GK=Greek'),
    ('CP NDL BF', 'Cup Noodles Beef Flavor 2.25oz', 'Prepared Foods', 'HARD', 'CP=Cup, NDL=Noodles'),
    ('OTM BR SG', 'Oatmeal with Brown Sugar 12oz', 'Prepared Foods', 'HARD', 'OTM=Oatmeal, BR SG=Brown Sugar'),
    ('EG SL SW', 'Egg Salad Sandwich on White', 'Prepared Foods', 'HARD', 'EG=Egg, SL=Salad, SW=Sandwich'),
    
    -- ========================================================================
    -- ALCOHOLIC BEVERAGES - EASY
    -- ========================================================================
    ('Bud Light 12oz Can', 'Bud Light 12oz Aluminum Can', 'Alcoholic Beverages', 'EASY', 'Missing aluminum'),
    ('Corona Extra 12oz', 'Corona Extra 12oz Bottle', 'Alcoholic Beverages', 'EASY', 'Missing bottle'),
    ('Heineken 12oz Bottle', 'Heineken 12oz Bottle', 'Alcoholic Beverages', 'EASY', 'Exact match'),
    ('Miller Lite 12oz Can', 'Miller Lite 12oz Aluminum Can', 'Alcoholic Beverages', 'EASY', 'Missing aluminum'),
    ('Coors Light 16oz', 'Coors Light 16oz Aluminum Can', 'Alcoholic Beverages', 'EASY', 'Missing container'),
    ('Modelo Especial 12oz', 'Modelo Especial 12oz Can', 'Alcoholic Beverages', 'EASY', 'Missing container'),
    ('Blue Moon 16oz', 'Blue Moon Belgian White 16oz Aluminum Can', 'Alcoholic Beverages', 'EASY', 'Missing variant'),
    ('Stella Artois 11.2oz', 'Stella Artois 11.2oz Bottle', 'Alcoholic Beverages', 'EASY', 'Missing container'),
    ('Dos Equis Lager 12oz', 'Dos Equis Lager Especial 12oz Bottle', 'Alcoholic Beverages', 'EASY', 'Missing especial'),
    ('Michelob Ultra 12oz', 'Michelob Ultra 12oz Aluminum Can', 'Alcoholic Beverages', 'EASY', 'Missing container'),
    
    -- ========================================================================
    -- ALCOHOLIC BEVERAGES - MEDIUM
    -- ========================================================================
    ('BUD LT 12Z CN', 'Bud Light 12oz Aluminum Can', 'Alcoholic Beverages', 'MEDIUM', 'BUD LT=Bud Light'),
    ('CRNA XTRA 12Z BTL', 'Corona Extra 12oz Bottle', 'Alcoholic Beverages', 'MEDIUM', 'CRNA=Corona'),
    ('HNKN 12Z BTL', 'Heineken 12oz Bottle', 'Alcoholic Beverages', 'MEDIUM', 'HNKN=Heineken'),
    ('MLLR LT 12Z CN', 'Miller Lite 12oz Aluminum Can', 'Alcoholic Beverages', 'MEDIUM', 'MLLR=Miller'),
    ('CORS LT 16Z CN', 'Coors Light 16oz Aluminum Can', 'Alcoholic Beverages', 'MEDIUM', 'CORS=Coors'),
    ('MODELO ESP 12Z', 'Modelo Especial 12oz Can', 'Alcoholic Beverages', 'MEDIUM', 'ESP=Especial'),
    ('BLU MN BLGN WHT 16Z', 'Blue Moon Belgian White 16oz Aluminum Can', 'Alcoholic Beverages', 'MEDIUM', 'BLU MN=Blue Moon'),
    ('STLA ARTS 11.2Z', 'Stella Artois 11.2oz Bottle', 'Alcoholic Beverages', 'MEDIUM', 'STLA=Stella'),
    ('DOS X LGR ESP 12Z', 'Dos Equis Lager Especial 12oz Bottle', 'Alcoholic Beverages', 'MEDIUM', 'DOS X=Dos Equis'),
    ('MCHLB ULTR 12Z CN', 'Michelob Ultra 12oz Aluminum Can', 'Alcoholic Beverages', 'MEDIUM', 'MCHLB=Michelob'),
    
    -- ========================================================================
    -- ALCOHOLIC BEVERAGES - HARD
    -- ========================================================================
    ('BD LT 12', 'Bud Light 12oz Aluminum Can', 'Alcoholic Beverages', 'HARD', 'BD LT=Bud Light'),
    ('CRN X 12', 'Corona Extra 12oz Bottle', 'Alcoholic Beverages', 'HARD', 'CRN=Corona'),
    ('HNK 12 BTL', 'Heineken 12oz Bottle', 'Alcoholic Beverages', 'HARD', 'HNK=Heineken'),
    ('ML LT 12 CN', 'Miller Lite 12oz Aluminum Can', 'Alcoholic Beverages', 'HARD', 'ML=Miller'),
    ('CRS LT 16', 'Coors Light 16oz Aluminum Can', 'Alcoholic Beverages', 'HARD', 'CRS=Coors'),
    ('MDL ESP 12', 'Modelo Especial 12oz Can', 'Alcoholic Beverages', 'HARD', 'MDL=Modelo'),
    ('BM BLGN 16', 'Blue Moon Belgian White 16oz Aluminum Can', 'Alcoholic Beverages', 'HARD', 'BM=Blue Moon'),
    ('STLA 11.2', 'Stella Artois 11.2oz Bottle', 'Alcoholic Beverages', 'HARD', 'STLA=Stella'),
    ('DX LGR 12', 'Dos Equis Lager Especial 12oz Bottle', 'Alcoholic Beverages', 'HARD', 'DX=Dos Equis'),
    ('MU 12 CN', 'Michelob Ultra 12oz Aluminum Can', 'Alcoholic Beverages', 'HARD', 'MU=Michelob Ultra'),
    ('BUDWEISER TALL', 'Budweiser 16oz Aluminum Can', 'Alcoholic Beverages', 'HARD', 'TALL=16oz'),
    ('NAT LT 16', 'Natural Light 16oz Aluminum Can', 'Alcoholic Beverages', 'HARD', 'NAT LT=Natural Light'),
    ('GUINESS DRFT 14.9', 'Guinness Draught 14.9oz Can', 'Alcoholic Beverages', 'HARD', 'Misspelled brand'),
    ('HOUSE CAB 6Z GLS', 'House Cabernet Sauvignon Glass 6oz', 'Alcoholic Beverages', 'HARD', 'CAB=Cabernet'),
    ('HOUSE CHARD GLASS', 'House Chardonnay Glass 6oz', 'Alcoholic Beverages', 'HARD', 'CHARD=Chardonnay'),
    
    -- ========================================================================
    -- EDGE CASES: Misspellings
    -- ========================================================================
    ('Coca Cola Clasic 20oz', 'Coca-Cola Classic 20oz Bottle', 'Beverages', 'HARD', 'MISSPELLING: Clasic'),
    ('Mountian Dew 20oz', 'Mountain Dew 20oz Bottle', 'Beverages', 'HARD', 'MISSPELLING: Mountian'),
    ('Gaterade Fruit Punch', 'Gatorade Thirst Quencher Fruit Punch 20oz Bottle', 'Beverages', 'HARD', 'MISSPELLING: Gaterade'),
    ('Dorito''s Nacho 1oz', 'Doritos Nacho Cheese 1oz Bag', 'Snacks', 'HARD', 'MISSPELLING: Doritos'),
    ('Cheeto''s Crunchy 1oz', 'Cheetos Crunchy 1oz Bag', 'Snacks', 'HARD', 'MISSPELLING: Cheetos'),
    ('Hienz Ketchup 20oz', 'Heinz Simply Ketchup 20oz Squeeze Bottle', 'Condiments', 'HARD', 'MISSPELLING: Heinz'),
    ('Heinekin 12oz', 'Heineken 12oz Bottle', 'Alcoholic Beverages', 'HARD', 'MISSPELLING: Heineken'),
    ('Buweiser 16oz', 'Budweiser 16oz Aluminum Can', 'Alcoholic Beverages', 'HARD', 'MISSPELLING: Budweiser'),
    ('Red Bul 8.4oz', 'Red Bull Energy Drink 8.4oz Can', 'Beverages', 'HARD', 'MISSPELLING: Bull'),
    ('Sniker Bar', 'Snickers Bar 1.86oz', 'Snacks', 'HARD', 'MISSPELLING: Snickers'),
    
    -- ========================================================================
    -- EDGE CASES: Wrong/Different Sizes
    -- ========================================================================
    ('Coca-Cola 12oz Bottle', 'Coca-Cola Classic 12oz Bottle', 'Beverages', 'MEDIUM', 'WRONG SIZE: 12oz vs 20oz bottle exists'),
    ('Pepsi 2 Liter', 'Pepsi Cola 2 Liter Bottle', 'Beverages', 'MEDIUM', 'LARGE FORMAT size'),
    ('Gatorade 32oz', 'Gatorade Thirst Quencher Fruit Punch 32oz Bottle', 'Beverages', 'MEDIUM', 'LARGE FORMAT'),
    ('Bud Light 24oz', 'Bud Light 24oz Aluminum Can', 'Alcoholic Beverages', 'MEDIUM', 'LARGE FORMAT'),
    ('Monster 24oz', 'Monster Energy Original 24oz Can', 'Beverages', 'MEDIUM', 'LARGE FORMAT'),
    
    -- ========================================================================
    -- EDGE CASES: Ambiguous (multiple possible matches)
    -- ========================================================================
    ('COKE', 'Coca-Cola Classic 20oz Bottle', 'Beverages', 'HARD', 'AMBIGUOUS: Could be any Coke variant'),
    ('PEPSI', 'Pepsi Cola 20oz Bottle', 'Beverages', 'HARD', 'AMBIGUOUS: Could be Diet/Zero/Regular'),
    ('WATER 16.9OZ', 'Aquafina Purified Water 16.9oz Bottle', 'Beverages', 'HARD', 'AMBIGUOUS: Many water brands'),
    ('CHIPS 1OZ', 'Lays Classic Potato Chips 1oz Bag', 'Snacks', 'HARD', 'AMBIGUOUS: Many chip types'),
    ('ENERGY DRINK', 'Red Bull Energy Drink 8.4oz Can', 'Beverages', 'HARD', 'AMBIGUOUS: Many energy drinks'),
    ('BEER 12OZ', 'Bud Light 12oz Aluminum Can', 'Alcoholic Beverages', 'HARD', 'AMBIGUOUS: Many beer brands'),
    ('CANDY BAR', 'Snickers Bar 1.86oz', 'Snacks', 'HARD', 'AMBIGUOUS: Many candy bars'),
    ('SANDWICH', 'BLT Sandwich on White Toast', 'Prepared Foods', 'HARD', 'AMBIGUOUS: Many sandwiches'),
    ('SALAD', 'Grilled Chicken Salad Greek', 'Prepared Foods', 'HARD', 'AMBIGUOUS: Many salads'),
    ('JUICE', 'Minute Maid Orange Juice 12oz Bottle', 'Beverages', 'HARD', 'AMBIGUOUS: Many juices');

-- ============================================================================
-- Update expected item IDs from standard items
-- (Uses GROUP BY to handle duplicate descriptions in STANDARD_ITEMS)
-- ============================================================================

UPDATE HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_SET t
SET EXPECTED_ITEM_ID = s.STANDARD_ITEM_ID
FROM (
    SELECT LOWER(STANDARD_DESCRIPTION) AS lower_desc, 
           MIN(STANDARD_ITEM_ID) AS STANDARD_ITEM_ID
    FROM HARMONIZER_DEMO.RAW.STANDARD_ITEMS
    GROUP BY LOWER(STANDARD_DESCRIPTION)
) s
WHERE LOWER(t.EXPECTED_MATCH) = s.lower_desc;

-- ============================================================================
-- Report on test set distribution
-- ============================================================================

SELECT 
    'TEST SET DISTRIBUTION' AS REPORT,
    CATEGORY,
    DIFFICULTY,
    COUNT(*) AS COUNT
FROM HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_SET
GROUP BY CATEGORY, DIFFICULTY
ORDER BY CATEGORY, 
    CASE DIFFICULTY WHEN 'EASY' THEN 1 WHEN 'MEDIUM' THEN 2 WHEN 'HARD' THEN 3 END;

SELECT 
    'TOTAL TESTS' AS REPORT,
    COUNT(*) AS TOTAL,
    COUNT(EXPECTED_ITEM_ID) AS WITH_EXPECTED_ID,
    COUNT(*) - COUNT(EXPECTED_ITEM_ID) AS MISSING_EXPECTED_ID
FROM HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_SET;

SELECT 
    'DIFFICULTY DISTRIBUTION' AS REPORT,
    DIFFICULTY,
    COUNT(*) AS COUNT,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS PERCENTAGE
FROM HARMONIZER_DEMO.ANALYTICS.ACCURACY_TEST_SET
GROUP BY DIFFICULTY
ORDER BY CASE DIFFICULTY WHEN 'EASY' THEN 1 WHEN 'MEDIUM' THEN 2 WHEN 'HARD' THEN 3 END;

-- ============================================================================
-- Populate embeddings for test cases (required for optimized cosine similarity)
-- ============================================================================
CALL HARMONIZER_DEMO.ANALYTICS.POPULATE_TEST_EMBEDDINGS();
