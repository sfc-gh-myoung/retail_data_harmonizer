-- ============================================================================
-- Retail Data Harmonization Demo
-- Script: sql/setup/05_seed_data/05m_raw_items_corporate.sql
-- Purpose: Generate 1000+ POS_CORPORATE records using realistic naming patterns
-- ============================================================================
--
-- POS_CORPORATE Characteristics:
-- - Most formal, complete descriptions (Coca-Cola Classic 20oz Bottle)
-- - Professional corporate catering systems
-- - Premium products and catering-style items
-- - Structured item codes, consistent formatting
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

INSERT INTO HARMONIZER_DEMO.RAW.RAW_RETAIL_ITEMS 
    (ITEM_ID, RAW_DESCRIPTION, SOURCE_SYSTEM, SOURCE_ITEM_CODE, EVENT_ID, TRANSACTION_COUNT, TRANSACTION_DATE, REGISTER_ID, MATCH_STATUS)
SELECT 
    UUID_STRING(),
    CASE MOD(SEQ4(), 150)
        -- Soft Drinks (0-14)
        WHEN 0 THEN 'Coca-Cola Classic 20oz Bottle'
        WHEN 1 THEN 'Coca-Cola Original Taste 20oz'
        WHEN 2 THEN 'Diet Coca-Cola 20oz Bottle'
        WHEN 3 THEN 'Diet Coke 20 oz Bottle'
        WHEN 4 THEN 'Coca-Cola Zero Sugar 20oz Bottle'
        WHEN 5 THEN 'Coke Zero Sugar 20 oz'
        WHEN 6 THEN 'Sprite Lemon-Lime 20oz Bottle'
        WHEN 7 THEN 'Dr Pepper 20oz Bottle'
        WHEN 8 THEN 'Pepsi Cola 20oz Bottle'
        WHEN 9 THEN 'Diet Pepsi 20oz Bottle'
        WHEN 10 THEN 'Mountain Dew 20oz Bottle'
        WHEN 11 THEN 'Ginger Ale 20oz Bottle'
        WHEN 12 THEN 'Root Beer 20oz Bottle'
        WHEN 13 THEN 'Fanta Orange 20oz Bottle'
        WHEN 14 THEN 'Cherry Coca-Cola 20oz'
        -- Premium Water (15-27)
        WHEN 15 THEN 'Dasani Purified Drinking Water 20oz'
        WHEN 16 THEN 'Dasani Purified Water 20 oz Bottle'
        WHEN 17 THEN 'Smartwater Vapor Distilled 20oz'
        WHEN 18 THEN 'SmartWater 20 oz Bottle'
        WHEN 19 THEN 'Evian Natural Spring Water 16.9oz'
        WHEN 20 THEN 'FIJI Natural Artesian Water 16.9oz'
        WHEN 21 THEN 'Acqua Panna Natural Spring Water'
        WHEN 22 THEN 'San Pellegrino Sparkling 16.9oz'
        WHEN 23 THEN 'Perrier Sparkling Water 16.9oz'
        WHEN 24 THEN 'Aquafina Purified Water 20oz'
        WHEN 25 THEN 'Poland Spring Water 20oz'
        WHEN 26 THEN 'Voss Artesian Water 16.9oz'
        WHEN 27 THEN 'Core Hydration Water 20oz'
        -- Coffee/Tea (28-40)
        WHEN 28 THEN 'Starbucks Frappuccino Mocha 13.7oz Bottle'
        WHEN 29 THEN 'Starbucks Frappuccino Vanilla 13.7oz Bottle'
        WHEN 30 THEN 'Starbucks Caramel Frappuccino 13.7oz'
        WHEN 31 THEN 'Starbucks Cold Brew Black Coffee'
        WHEN 32 THEN 'Starbucks Nitro Cold Brew'
        WHEN 33 THEN 'Pure Leaf Unsweetened Iced Tea 18.5oz'
        WHEN 34 THEN 'Pure Leaf Sweet Tea 18.5oz Bottle'
        WHEN 35 THEN 'Gold Peak Real Brewed Tea 18.5oz'
        WHEN 36 THEN 'Honest Tea Organic Green Tea'
        WHEN 37 THEN 'Tazo Organic Iced Tea'
        WHEN 38 THEN 'Fresh Brewed Coffee Regular'
        WHEN 39 THEN 'Fresh Brewed Coffee Decaf'
        WHEN 40 THEN 'Hot Tea Assorted'
        -- Premium Juice (41-50)
        WHEN 41 THEN 'Tropicana Pure Premium Orange Juice 12oz'
        WHEN 42 THEN 'Simply Orange Juice with Pulp 11.5oz'
        WHEN 43 THEN 'Simply Apple Juice 11.5oz Bottle'
        WHEN 44 THEN 'Naked Juice Green Machine'
        WHEN 45 THEN 'Naked Juice Mighty Mango'
        WHEN 46 THEN 'Suja Organic Green Juice'
        WHEN 47 THEN 'Evolution Fresh Cold-Pressed'
        WHEN 48 THEN 'Ocean Spray Cranberry Juice 15oz'
        WHEN 49 THEN 'V8 Original Vegetable Juice 12oz'
        WHEN 50 THEN 'Minute Maid Apple Juice 12oz'
        -- Chips (51-62)
        WHEN 51 THEN 'Lays Classic Potato Chips 1oz'
        WHEN 52 THEN 'Lays Barbecue Chips 1oz'
        WHEN 53 THEN 'Lays Sour Cream and Onion 1oz'
        WHEN 54 THEN 'Baked Lays Original 1oz'
        WHEN 55 THEN 'Doritos Nacho Cheese 1oz'
        WHEN 56 THEN 'Doritos Cool Ranch 1oz'
        WHEN 57 THEN 'Cheetos Crunchy 1oz'
        WHEN 58 THEN 'SunChips Harvest Cheddar 1oz'
        WHEN 59 THEN 'Fritos Original Corn Chips 1oz'
        WHEN 60 THEN 'Kettle Brand Sea Salt Chips'
        WHEN 61 THEN 'PopCorners Kettle Corn'
        WHEN 62 THEN 'Ruffles Cheddar and Sour Cream'
        -- Premium Sandwiches (63-78)
        WHEN 63 THEN 'Premium Turkey Club Sandwich'
        WHEN 64 THEN 'Roasted Turkey Breast Sandwich'
        WHEN 65 THEN 'Ham and Swiss Cheese Sandwich'
        WHEN 66 THEN 'Black Forest Ham Sandwich'
        WHEN 67 THEN 'Grilled Chicken Caesar Wrap'
        WHEN 68 THEN 'Mediterranean Vegetable Wrap'
        WHEN 69 THEN 'Italian Sub Sandwich'
        WHEN 70 THEN 'Roast Beef and Cheddar Sandwich'
        WHEN 71 THEN 'Caprese Sandwich Fresh Mozzarella'
        WHEN 72 THEN 'Tuna Salad Sandwich on Wheat'
        WHEN 73 THEN 'Chicken Salad Croissant Sandwich'
        WHEN 74 THEN 'Avocado Turkey Sandwich'
        WHEN 75 THEN 'BLT Sandwich Premium Bacon'
        WHEN 76 THEN 'Egg Salad Sandwich'
        WHEN 77 THEN 'Veggie Deluxe Sandwich'
        WHEN 78 THEN 'Club Sandwich Triple Decker'
        -- Premium Salads (79-90)
        WHEN 79 THEN 'Garden Salad with Grilled Chicken Breast'
        WHEN 80 THEN 'Classic Caesar Salad'
        WHEN 81 THEN 'Caesar Salad with Grilled Chicken'
        WHEN 82 THEN 'Cobb Salad with Bacon and Avocado'
        WHEN 83 THEN 'Greek Salad with Feta Cheese'
        WHEN 84 THEN 'Spinach Salad with Strawberries'
        WHEN 85 THEN 'Asian Sesame Chicken Salad'
        WHEN 86 THEN 'Quinoa Power Bowl'
        WHEN 87 THEN 'Mediterranean Grain Bowl'
        WHEN 88 THEN 'Kale Superfood Salad'
        WHEN 89 THEN 'Southwest Chicken Salad'
        WHEN 90 THEN 'Chef Salad'
        -- Hot Entrees (91-104)
        WHEN 91 THEN 'Grilled Chicken Breast with Vegetables'
        WHEN 92 THEN 'Grilled Salmon Fillet with Rice'
        WHEN 93 THEN 'Pan-Seared Chicken Marsala'
        WHEN 94 THEN 'Chicken Piccata with Capers'
        WHEN 95 THEN 'Vegetable Lasagna'
        WHEN 96 THEN 'Penne Pasta with Marinara'
        WHEN 97 THEN 'Chicken Parmesan with Pasta'
        WHEN 98 THEN 'Beef Tenderloin with Roasted Potatoes'
        WHEN 99 THEN 'Cheeseburger'
        WHEN 100 THEN 'Bacon Cheeseburger'
        WHEN 101 THEN 'Hot Dog All Beef'
        WHEN 102 THEN 'Chicken Tenders 4 Piece'
        WHEN 103 THEN 'French Fries'
        WHEN 104 THEN 'Onion Rings'
        -- Premium Soup (105-112)
        WHEN 105 THEN 'Chicken Noodle Soup Cup'
        WHEN 106 THEN 'Tomato Basil Bisque'
        WHEN 107 THEN 'Butternut Squash Soup'
        WHEN 108 THEN 'French Onion Soup'
        WHEN 109 THEN 'Lobster Bisque Cup'
        WHEN 110 THEN 'Minestrone Soup'
        WHEN 111 THEN 'Broccoli Cheddar Soup'
        WHEN 112 THEN 'Clam Chowder'
        -- Premium Snacks (113-126)
        WHEN 113 THEN 'Fresh Fruit Cup Seasonal'
        WHEN 114 THEN 'Greek Yogurt Parfait with Granola'
        WHEN 115 THEN 'Acai Bowl'
        WHEN 116 THEN 'Kind Bar Dark Chocolate Almond'
        WHEN 117 THEN 'RXBar Chocolate Sea Salt'
        WHEN 118 THEN 'Mixed Nuts Premium'
        WHEN 119 THEN 'Cheese and Cracker Plate'
        WHEN 120 THEN 'Hummus with Pita Chips'
        WHEN 121 THEN 'Veggie Crudite Platter'
        WHEN 122 THEN 'Charcuterie Cup'
        WHEN 123 THEN 'Protein Box'
        WHEN 124 THEN 'Trail Mix Premium'
        WHEN 125 THEN 'Nature Valley Granola Bar'
        WHEN 126 THEN 'Clif Bar Energy'
        -- Candy (127-136)
        WHEN 127 THEN 'Snickers Bar Original'
        WHEN 128 THEN 'M&Ms Milk Chocolate'
        WHEN 129 THEN 'M&Ms Peanut'
        WHEN 130 THEN 'Reeses Peanut Butter Cups'
        WHEN 131 THEN 'Kit Kat Wafer Bar'
        WHEN 132 THEN 'Twix Caramel Cookie Bar'
        WHEN 133 THEN 'Milky Way Bar'
        WHEN 134 THEN 'Skittles Original'
        WHEN 135 THEN 'Starburst Original'
        WHEN 136 THEN 'Life Savers Gummies'
        -- Premium Bakery (137-145)
        WHEN 137 THEN 'Gourmet Cookie Assortment'
        WHEN 138 THEN 'Brownie Bite'
        WHEN 139 THEN 'Fresh Baked Croissant'
        WHEN 140 THEN 'Blueberry Scone'
        WHEN 141 THEN 'Almond Croissant'
        WHEN 142 THEN 'Cinnamon Roll'
        WHEN 143 THEN 'Lemon Poppy Muffin'
        WHEN 144 THEN 'Chocolate Chip Muffin'
        WHEN 145 THEN 'Bagel with Cream Cheese'
        -- Sports/Energy (146-149)
        WHEN 146 THEN 'Gatorade Lemon-Lime 20oz'
        WHEN 147 THEN 'Gatorade Fruit Punch 20oz'
        WHEN 148 THEN 'Red Bull Energy Drink 8.4oz'
        ELSE 'Monster Energy Original 16oz'
    END AS RAW_DESC,
    'POS_CORPORATE',
    'CRP-' || LPAD(MOD(SEQ4(), 100)::VARCHAR, 3, '0'),
    'EVT-CRP-' || LPAD((MOD(SEQ4(), 13) + 1)::VARCHAR, 3, '0'),
    UNIFORM(30, 250, RANDOM()),
    DATEADD(day, MOD(SEQ4(), 180), '2025-08-01')::DATE,
    'CORP-' || (MOD(SEQ4(), 3) + 1)::VARCHAR,
    'PENDING'
FROM TABLE(GENERATOR(ROWCOUNT => 1500));
