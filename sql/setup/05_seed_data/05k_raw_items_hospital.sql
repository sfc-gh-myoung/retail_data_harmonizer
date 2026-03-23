-- ============================================================================
-- Retail Data Harmonization Demo
-- Script: sql/setup/05_seed_data/05k_raw_items_hospital.sql
-- Purpose: Generate 1000+ POS_HOSPITAL records using realistic naming patterns
-- ============================================================================
--
-- POS_HOSPITAL Characteristics:
-- - Proper case, verbose descriptions (Coca-Cola Classic 20oz Bottle)
-- - Professional, healthcare-appropriate naming
-- - Weekly cafeteria operations
-- - Healthier options, premium water, grab-and-go items
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
        WHEN 1 THEN 'Coca-Cola 20 oz'
        WHEN 2 THEN 'Diet Coca-Cola 20oz Bottle'
        WHEN 3 THEN 'Diet Coke 20 oz'
        WHEN 4 THEN 'Coca-Cola Zero Sugar 20oz'
        WHEN 5 THEN 'Sprite 20oz Bottle'
        WHEN 6 THEN 'Pepsi Cola 20oz Bottle'
        WHEN 7 THEN 'Diet Pepsi 20oz'
        WHEN 8 THEN 'Mountain Dew 20oz Bottle'
        WHEN 9 THEN 'Dr Pepper 20oz Bottle'
        WHEN 10 THEN 'Ginger Ale 20oz'
        WHEN 11 THEN 'Root Beer 20oz'
        WHEN 12 THEN 'Fanta Orange 20oz'
        WHEN 13 THEN '7Up 20oz Bottle'
        WHEN 14 THEN 'Cherry Coca-Cola 20oz'
        -- Water (15-26)
        WHEN 15 THEN 'Dasani Purified Water 20oz'
        WHEN 16 THEN 'Dasani Water 20 oz Bottle'
        WHEN 17 THEN 'Aquafina Purified Water 20oz'
        WHEN 18 THEN 'Smartwater 20oz Bottle'
        WHEN 19 THEN 'Evian Natural Spring Water'
        WHEN 20 THEN 'Poland Spring Water 20oz'
        WHEN 21 THEN 'FIJI Natural Artesian Water'
        WHEN 22 THEN 'Perrier Sparkling Water'
        WHEN 23 THEN 'San Pellegrino Sparkling'
        WHEN 24 THEN 'Vitaminwater XXX'
        WHEN 25 THEN 'Propel Fitness Water'
        WHEN 26 THEN 'Core Hydration Water'
        -- Coffee/Tea (27-38)
        WHEN 27 THEN 'Starbucks Frappuccino Mocha 13.7oz'
        WHEN 28 THEN 'Starbucks Frappuccino Vanilla 13.7oz'
        WHEN 29 THEN 'Starbucks Cold Brew Coffee 11oz'
        WHEN 30 THEN 'Starbucks Doubleshot Espresso'
        WHEN 31 THEN 'Dunkin Iced Coffee Mocha'
        WHEN 32 THEN 'Pure Leaf Unsweetened Tea 18.5oz'
        WHEN 33 THEN 'Pure Leaf Sweet Tea 18.5oz'
        WHEN 34 THEN 'Gold Peak Sweet Tea 18.5oz'
        WHEN 35 THEN 'Lipton Green Tea 16.9oz'
        WHEN 36 THEN 'Arizona Green Tea 20oz'
        WHEN 37 THEN 'Honest Tea Organic Green'
        WHEN 38 THEN 'Tazo Iced Tea Passion'
        -- Juice (39-48)
        WHEN 39 THEN 'Tropicana Orange Juice 12oz'
        WHEN 40 THEN 'Simply Orange Juice 11.5oz'
        WHEN 41 THEN 'Simply Apple Juice 11.5oz'
        WHEN 42 THEN 'Minute Maid Apple Juice 12oz'
        WHEN 43 THEN 'Minute Maid Orange Juice 12oz'
        WHEN 44 THEN 'Naked Juice Green Machine'
        WHEN 45 THEN 'Naked Juice Mighty Mango'
        WHEN 46 THEN 'Ocean Spray Cranberry Juice'
        WHEN 47 THEN 'V8 Vegetable Juice 12oz'
        WHEN 48 THEN 'Apple and Eve Juice Box'
        -- Sports/Energy Drinks (49-56)
        WHEN 49 THEN 'Gatorade Fruit Punch 20oz'
        WHEN 50 THEN 'Gatorade Orange 20oz'
        WHEN 51 THEN 'Gatorade Lemon Lime 20oz'
        WHEN 52 THEN 'Powerade Mountain Berry Blast'
        WHEN 53 THEN 'Red Bull Energy 8.4oz'
        WHEN 54 THEN 'Monster Energy Original 16oz'
        WHEN 55 THEN 'Celsius Energy Drink'
        WHEN 56 THEN 'Body Armor Sports Drink'
        -- Chips (57-68)
        WHEN 57 THEN 'Lays Classic Chips 1oz'
        WHEN 58 THEN 'Lays Potato Chips'
        WHEN 59 THEN 'Lays BBQ Chips 1oz'
        WHEN 60 THEN 'Lays Sour Cream and Onion'
        WHEN 61 THEN 'Baked Lays Original'
        WHEN 62 THEN 'Doritos Nacho Cheese 1oz'
        WHEN 63 THEN 'Doritos Cool Ranch 1oz'
        WHEN 64 THEN 'Cheetos Crunchy 1oz'
        WHEN 65 THEN 'SunChips Harvest Cheddar'
        WHEN 66 THEN 'Fritos Original Corn Chips'
        WHEN 67 THEN 'Kettle Brand Sea Salt'
        WHEN 68 THEN 'PopCorners Kettle Corn'
        -- Sandwiches/Wraps (69-82)
        WHEN 69 THEN 'Turkey Club Sandwich'
        WHEN 70 THEN 'Turkey and Cheese Sandwich'
        WHEN 71 THEN 'Ham and Swiss Sandwich'
        WHEN 72 THEN 'Ham and Cheese Sandwich'
        WHEN 73 THEN 'Grilled Chicken Wrap'
        WHEN 74 THEN 'Chicken Caesar Wrap'
        WHEN 75 THEN 'Veggie Wrap'
        WHEN 76 THEN 'BLT Sandwich'
        WHEN 77 THEN 'Tuna Salad Sandwich'
        WHEN 78 THEN 'Egg Salad Sandwich'
        WHEN 79 THEN 'Roast Beef Sandwich'
        WHEN 80 THEN 'Italian Sub Sandwich'
        WHEN 81 THEN 'Caprese Sandwich'
        WHEN 82 THEN 'Chicken Salad Sandwich'
        -- Salads (83-92)
        WHEN 83 THEN 'Garden Salad with Grilled Chicken'
        WHEN 84 THEN 'Caesar Salad'
        WHEN 85 THEN 'Caesar Salad with Chicken'
        WHEN 86 THEN 'Side Garden Salad'
        WHEN 87 THEN 'Chef Salad'
        WHEN 88 THEN 'Cobb Salad'
        WHEN 89 THEN 'Greek Salad'
        WHEN 90 THEN 'Spinach Salad'
        WHEN 91 THEN 'Asian Chicken Salad'
        WHEN 92 THEN 'Southwest Chicken Salad'
        -- Hot Entrees (93-104)
        WHEN 93 THEN 'Grilled Chicken Breast Plate'
        WHEN 94 THEN 'Baked Fish Fillet Plate'
        WHEN 95 THEN 'Roasted Turkey Plate'
        WHEN 96 THEN 'Pasta Marinara'
        WHEN 97 THEN 'Chicken Parmesan'
        WHEN 98 THEN 'Meatloaf Dinner'
        WHEN 99 THEN 'Vegetable Lasagna'
        WHEN 100 THEN 'Cheeseburger'
        WHEN 101 THEN 'Hamburger'
        WHEN 102 THEN 'Hot Dog'
        WHEN 103 THEN 'Chicken Tenders 4 Piece'
        WHEN 104 THEN 'French Fries'
        -- Soup (105-111)
        WHEN 105 THEN 'Chicken Noodle Soup Cup'
        WHEN 106 THEN 'Tomato Basil Soup Cup'
        WHEN 107 THEN 'Vegetable Soup'
        WHEN 108 THEN 'Broccoli Cheddar Soup'
        WHEN 109 THEN 'Minestrone Soup'
        WHEN 110 THEN 'Cream of Mushroom Soup'
        WHEN 111 THEN 'Clam Chowder'
        -- Healthy Snacks (112-124)
        WHEN 112 THEN 'Fresh Fruit Cup'
        WHEN 113 THEN 'Greek Yogurt Parfait'
        WHEN 114 THEN 'Yogurt Parfait Strawberry'
        WHEN 115 THEN 'Kind Bar Almond'
        WHEN 116 THEN 'Kind Bar Dark Chocolate'
        WHEN 117 THEN 'Nature Valley Granola Bar'
        WHEN 118 THEN 'Clif Bar Chocolate Chip'
        WHEN 119 THEN 'RXBar Protein Bar'
        WHEN 120 THEN 'Pretzels Snack Bag'
        WHEN 121 THEN 'Trail Mix'
        WHEN 122 THEN 'Mixed Nuts'
        WHEN 123 THEN 'Apple Slices with Caramel'
        WHEN 124 THEN 'Hummus with Pretzels'
        -- Candy (125-134)
        WHEN 125 THEN 'Snickers Bar'
        WHEN 126 THEN 'M&Ms Milk Chocolate'
        WHEN 127 THEN 'M&Ms Peanut'
        WHEN 128 THEN 'Reeses Peanut Butter Cups'
        WHEN 129 THEN 'Kit Kat Bar'
        WHEN 130 THEN 'Twix Bar'
        WHEN 131 THEN 'Milky Way Bar'
        WHEN 132 THEN 'Skittles'
        WHEN 133 THEN 'Starburst'
        WHEN 134 THEN 'Life Savers Gummies'
        -- Bakery (135-144)
        WHEN 135 THEN 'Blueberry Muffin'
        WHEN 136 THEN 'Banana Nut Muffin'
        WHEN 137 THEN 'Bran Muffin'
        WHEN 138 THEN 'Chocolate Chip Cookie'
        WHEN 139 THEN 'Oatmeal Raisin Cookie'
        WHEN 140 THEN 'Brownie'
        WHEN 141 THEN 'Fresh Croissant'
        WHEN 142 THEN 'Bagel with Cream Cheese'
        WHEN 143 THEN 'Danish Pastry'
        WHEN 144 THEN 'Cinnamon Roll'
        -- Other (145-149)
        WHEN 145 THEN 'Ice Cream Cup Vanilla'
        WHEN 146 THEN 'Ice Cream Sandwich'
        WHEN 147 THEN 'Pudding Cup'
        WHEN 148 THEN 'Jello Cup'
        ELSE 'Rice Krispies Treat'
    END AS RAW_DESC,
    'POS_HOSPITAL',
    'HSP-' || LPAD(MOD(SEQ4(), 100)::VARCHAR, 3, '0'),
    'EVT-HSP-' || LPAD((MOD(SEQ4(), 5) + 1)::VARCHAR, 3, '0'),
    UNIFORM(50, 400, RANDOM()),
    DATEADD(day, MOD(SEQ4(), 100), '2025-09-01')::DATE,
    'CAF-' || (MOD(SEQ4(), 4) + 1)::VARCHAR,
    'PENDING'
FROM TABLE(GENERATOR(ROWCOUNT => 1500));
