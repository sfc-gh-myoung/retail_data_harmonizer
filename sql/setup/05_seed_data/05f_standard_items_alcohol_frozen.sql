-- ============================================================================
-- Retail Data Harmonization Demo
-- Script: sql/setup/05_seed_data/05f_standard_items_alcohol_frozen.sql
-- Purpose: Seed STANDARD_ITEMS with alcohol, frozen, and bakery items (~205 items)
-- Depends on: 02_schema_and_tables.sql
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- STANDARD_ITEMS: Beer and Alcohol (~100 items)
-- ============================================================================

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Domestic Beer
SELECT UUID_STRING(), 'Budweiser Lager 12oz Can', 'Alcohol', 'Domestic Beer', 'Budweiser', '018200001017', 2.49 UNION ALL
SELECT UUID_STRING(), 'Budweiser Lager 16oz Can', 'Alcohol', 'Domestic Beer', 'Budweiser', '018200001024', 3.29 UNION ALL
SELECT UUID_STRING(), 'Budweiser Lager 25oz Can', 'Alcohol', 'Domestic Beer', 'Budweiser', '018200001031', 3.99 UNION ALL
SELECT UUID_STRING(), 'Bud Light Lager 12oz Can', 'Alcohol', 'Domestic Beer', 'Bud Light', '018200001048', 2.49 UNION ALL
SELECT UUID_STRING(), 'Bud Light Lager 16oz Can', 'Alcohol', 'Domestic Beer', 'Bud Light', '018200001055', 3.29 UNION ALL
SELECT UUID_STRING(), 'Bud Light Lager 25oz Can', 'Alcohol', 'Domestic Beer', 'Bud Light', '018200001062', 3.99 UNION ALL
SELECT UUID_STRING(), 'Miller Lite Lager 12oz Can', 'Alcohol', 'Domestic Beer', 'Miller Lite', '034100001018', 2.49 UNION ALL
SELECT UUID_STRING(), 'Miller Lite Lager 16oz Can', 'Alcohol', 'Domestic Beer', 'Miller Lite', '034100001025', 3.29 UNION ALL
SELECT UUID_STRING(), 'Miller High Life Lager 12oz Can', 'Alcohol', 'Domestic Beer', 'Miller High Life', '034100001032', 2.29 UNION ALL
SELECT UUID_STRING(), 'Coors Light Lager 12oz Can', 'Alcohol', 'Domestic Beer', 'Coors Light', '071990001018', 2.49 UNION ALL
SELECT UUID_STRING(), 'Coors Light Lager 16oz Can', 'Alcohol', 'Domestic Beer', 'Coors Light', '071990001025', 3.29 UNION ALL
SELECT UUID_STRING(), 'Coors Banquet Lager 12oz Can', 'Alcohol', 'Domestic Beer', 'Coors', '071990001032', 2.49 UNION ALL
SELECT UUID_STRING(), 'Michelob Ultra Light Lager 12oz Can', 'Alcohol', 'Domestic Beer', 'Michelob Ultra', '018200001079', 2.79 UNION ALL
SELECT UUID_STRING(), 'Michelob Ultra Light Lager 16oz Can', 'Alcohol', 'Domestic Beer', 'Michelob Ultra', '018200001086', 3.49 UNION ALL
SELECT UUID_STRING(), 'Pabst Blue Ribbon Lager 12oz Can', 'Alcohol', 'Domestic Beer', 'PBR', '068100001012', 2.29 UNION ALL
SELECT UUID_STRING(), 'Natural Light Lager 12oz Can', 'Alcohol', 'Domestic Beer', 'Natural Light', '018200001093', 1.99 UNION ALL
SELECT UUID_STRING(), 'Busch Light Lager 12oz Can', 'Alcohol', 'Domestic Beer', 'Busch', '018200001109', 1.99 UNION ALL
SELECT UUID_STRING(), 'Yuengling Traditional Lager 12oz Can', 'Alcohol', 'Domestic Beer', 'Yuengling', '082676001012', 2.79;

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Craft Beer
SELECT UUID_STRING(), 'Blue Moon Belgian White 12oz Bottle', 'Alcohol', 'Craft Beer', 'Blue Moon', '071990001049', 3.49 UNION ALL
SELECT UUID_STRING(), 'Blue Moon Mango Wheat 12oz Can', 'Alcohol', 'Craft Beer', 'Blue Moon', '071990001056', 3.49 UNION ALL
SELECT UUID_STRING(), 'Shock Top Belgian White 12oz Bottle', 'Alcohol', 'Craft Beer', 'Shock Top', '018200001116', 3.49 UNION ALL
SELECT UUID_STRING(), 'Sam Adams Boston Lager 12oz Bottle', 'Alcohol', 'Craft Beer', 'Sam Adams', '087644001012', 3.99 UNION ALL
SELECT UUID_STRING(), 'Sam Adams Seasonal Variety 12oz Bottle', 'Alcohol', 'Craft Beer', 'Sam Adams', '087644001029', 3.99 UNION ALL
SELECT UUID_STRING(), 'Lagunitas IPA 12oz Bottle', 'Alcohol', 'Craft Beer', 'Lagunitas', '054500001014', 3.99 UNION ALL
SELECT UUID_STRING(), 'Lagunitas Little Sumpin Sumpin Ale 12oz Bottle', 'Alcohol', 'Craft Beer', 'Lagunitas', '054500001021', 3.99 UNION ALL
SELECT UUID_STRING(), 'Sierra Nevada Pale Ale 12oz Bottle', 'Alcohol', 'Craft Beer', 'Sierra Nevada', '018752001016', 3.99 UNION ALL
SELECT UUID_STRING(), 'Sierra Nevada Hazy Little Thing IPA 12oz Can', 'Alcohol', 'Craft Beer', 'Sierra Nevada', '018752001023', 3.99 UNION ALL
SELECT UUID_STRING(), 'Dogfish Head 60 Minute IPA 12oz Bottle', 'Alcohol', 'Craft Beer', 'Dogfish Head', '089189001011', 4.29 UNION ALL
SELECT UUID_STRING(), 'New Belgium Fat Tire Amber Ale 12oz Bottle', 'Alcohol', 'Craft Beer', 'New Belgium', '072890001018', 3.79 UNION ALL
SELECT UUID_STRING(), 'New Belgium Voodoo Ranger IPA 12oz Can', 'Alcohol', 'Craft Beer', 'New Belgium', '072890001025', 3.79 UNION ALL
SELECT UUID_STRING(), 'Founders All Day IPA 12oz Can', 'Alcohol', 'Craft Beer', 'Founders', '020652001013', 3.79 UNION ALL
SELECT UUID_STRING(), 'Stone IPA 12oz Can', 'Alcohol', 'Craft Beer', 'Stone', '084024001010', 3.99 UNION ALL
SELECT UUID_STRING(), 'Bell Two Hearted Ale 12oz Can', 'Alcohol', 'Craft Beer', 'Bells', '078890001018', 3.99 UNION ALL
SELECT UUID_STRING(), 'Athletic Brewing Run Wild Non-Alcoholic IPA 12oz Can', 'Alcohol', 'Craft Beer', 'Athletic Brewing', '860002710013', 2.99;

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Import Beer
SELECT UUID_STRING(), 'Corona Extra Lager 12oz Bottle', 'Alcohol', 'Import Beer', 'Corona', '028656001019', 3.99 UNION ALL
SELECT UUID_STRING(), 'Corona Light Lager 12oz Bottle', 'Alcohol', 'Import Beer', 'Corona', '028656001026', 3.99 UNION ALL
SELECT UUID_STRING(), 'Modelo Especial Lager 12oz Can', 'Alcohol', 'Import Beer', 'Modelo', '028656001033', 3.49 UNION ALL
SELECT UUID_STRING(), 'Modelo Negra Dark Lager 12oz Bottle', 'Alcohol', 'Import Beer', 'Modelo', '028656001040', 3.79 UNION ALL
SELECT UUID_STRING(), 'Heineken Lager 12oz Bottle', 'Alcohol', 'Import Beer', 'Heineken', '087100001012', 3.99 UNION ALL
SELECT UUID_STRING(), 'Heineken 0.0 Non-Alcoholic 12oz Bottle', 'Alcohol', 'Import Beer', 'Heineken', '087100001029', 2.99 UNION ALL
SELECT UUID_STRING(), 'Stella Artois Lager 11.2oz Bottle', 'Alcohol', 'Import Beer', 'Stella Artois', '018200001123', 3.99 UNION ALL
SELECT UUID_STRING(), 'Guinness Draught Stout 14.9oz Can', 'Alcohol', 'Import Beer', 'Guinness', '008871001015', 4.49 UNION ALL
SELECT UUID_STRING(), 'Dos Equis Lager Especial 12oz Bottle', 'Alcohol', 'Import Beer', 'Dos Equis', '028656001057', 3.49 UNION ALL
SELECT UUID_STRING(), 'Pacifico Clara Lager 12oz Can', 'Alcohol', 'Import Beer', 'Pacifico', '028656001064', 3.49 UNION ALL
SELECT UUID_STRING(), 'Sapporo Premium Beer 22oz Can', 'Alcohol', 'Import Beer', 'Sapporo', '088510001017', 4.99 UNION ALL
SELECT UUID_STRING(), 'Asahi Super Dry 12oz Can', 'Alcohol', 'Import Beer', 'Asahi', '088510001024', 3.99 UNION ALL
SELECT UUID_STRING(), 'Newcastle Brown Ale 12oz Bottle', 'Alcohol', 'Import Beer', 'Newcastle', '087100001036', 3.79 UNION ALL
SELECT UUID_STRING(), 'Peroni Nastro Azzurro Lager 11.2oz Bottle', 'Alcohol', 'Import Beer', 'Peroni', '088510001031', 3.99;

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Hard Seltzer
SELECT UUID_STRING(), 'White Claw Hard Seltzer Black Cherry 12oz Can', 'Alcohol', 'Hard Seltzer', 'White Claw', '088004001013', 3.49 UNION ALL
SELECT UUID_STRING(), 'White Claw Hard Seltzer Mango 12oz Can', 'Alcohol', 'Hard Seltzer', 'White Claw', '088004001020', 3.49 UNION ALL
SELECT UUID_STRING(), 'White Claw Hard Seltzer Natural Lime 12oz Can', 'Alcohol', 'Hard Seltzer', 'White Claw', '088004001037', 3.49 UNION ALL
SELECT UUID_STRING(), 'White Claw Hard Seltzer Raspberry 12oz Can', 'Alcohol', 'Hard Seltzer', 'White Claw', '088004001044', 3.49 UNION ALL
SELECT UUID_STRING(), 'White Claw Hard Seltzer Watermelon 12oz Can', 'Alcohol', 'Hard Seltzer', 'White Claw', '088004001051', 3.49 UNION ALL
SELECT UUID_STRING(), 'Truly Hard Seltzer Wild Berry 12oz Can', 'Alcohol', 'Hard Seltzer', 'Truly', '087644001036', 3.29 UNION ALL
SELECT UUID_STRING(), 'Truly Hard Seltzer Pineapple 12oz Can', 'Alcohol', 'Hard Seltzer', 'Truly', '087644001043', 3.29 UNION ALL
SELECT UUID_STRING(), 'Truly Hard Seltzer Strawberry Lemonade 12oz Can', 'Alcohol', 'Hard Seltzer', 'Truly', '087644001050', 3.29 UNION ALL
SELECT UUID_STRING(), 'High Noon Sun Sips Watermelon Vodka Seltzer 12oz Can', 'Alcohol', 'Hard Seltzer', 'High Noon', '080632001011', 4.49 UNION ALL
SELECT UUID_STRING(), 'High Noon Sun Sips Pineapple Vodka Seltzer 12oz Can', 'Alcohol', 'Hard Seltzer', 'High Noon', '080632001028', 4.49 UNION ALL
SELECT UUID_STRING(), 'High Noon Sun Sips Peach Vodka Seltzer 12oz Can', 'Alcohol', 'Hard Seltzer', 'High Noon', '080632001035', 4.49 UNION ALL
SELECT UUID_STRING(), 'Vizzy Hard Seltzer Pineapple Mango 12oz Can', 'Alcohol', 'Hard Seltzer', 'Vizzy', '071990001063', 3.29 UNION ALL
SELECT UUID_STRING(), 'Topo Chico Hard Seltzer Strawberry Guava 12oz Can', 'Alcohol', 'Hard Seltzer', 'Topo Chico', '071990001070', 3.49 UNION ALL
-- Wine by the Glass
SELECT UUID_STRING(), 'House Red Wine Cabernet Sauvignon 6oz Glass', 'Alcohol', 'Wine', 'House Wine', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'House White Wine Chardonnay 6oz Glass', 'Alcohol', 'Wine', 'House Wine', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'House Rose Wine Provence Style 6oz Glass', 'Alcohol', 'Wine', 'House Wine', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'House Pinot Noir 6oz Glass', 'Alcohol', 'Wine', 'House Wine', NULL, 9.49 UNION ALL
SELECT UUID_STRING(), 'House Sauvignon Blanc 6oz Glass', 'Alcohol', 'Wine', 'House Wine', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'House Pinot Grigio 6oz Glass', 'Alcohol', 'Wine', 'House Wine', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Prosecco Sparkling Wine 6oz Glass', 'Alcohol', 'Wine', 'House Wine', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'Bota Box Cabernet Sauvignon 500ml Box', 'Alcohol', 'Wine', 'Bota Box', '085000003015', 7.99 UNION ALL
SELECT UUID_STRING(), 'Bota Box Chardonnay 500ml Box', 'Alcohol', 'Wine', 'Bota Box', '085000003022', 7.99 UNION ALL
SELECT UUID_STRING(), 'Kim Crawford Sauvignon Blanc 187ml Bottle', 'Alcohol', 'Wine', 'Kim Crawford', '091845001019', 6.99 UNION ALL
SELECT UUID_STRING(), 'Josh Cellars Cabernet Sauvignon 187ml Bottle', 'Alcohol', 'Wine', 'Josh Cellars', '091845001026', 5.99 UNION ALL
-- Cider and Malt
SELECT UUID_STRING(), 'Angry Orchard Crisp Apple Hard Cider 12oz Bottle', 'Alcohol', 'Cider', 'Angry Orchard', '087644001067', 3.49 UNION ALL
SELECT UUID_STRING(), 'Angry Orchard Rose Hard Cider 12oz Can', 'Alcohol', 'Cider', 'Angry Orchard', '087644001074', 3.49 UNION ALL
SELECT UUID_STRING(), 'Mike Hard Lemonade Original 11.2oz Bottle', 'Alcohol', 'Malt Beverage', 'Mikes', '089019001012', 3.29 UNION ALL
SELECT UUID_STRING(), 'Twisted Tea Original 12oz Can', 'Alcohol', 'Malt Beverage', 'Twisted Tea', '087644001081', 3.29 UNION ALL
SELECT UUID_STRING(), 'Smirnoff Ice Original 11.2oz Bottle', 'Alcohol', 'Malt Beverage', 'Smirnoff', '082000001013', 3.29;

-- ============================================================================
-- STANDARD_ITEMS: Frozen and Ice Cream (~50 items)
-- ============================================================================

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Ice Cream Bars
SELECT UUID_STRING(), 'Haagen-Dazs Vanilla Milk Chocolate Bar 3oz', 'Frozen', 'Ice Cream Bars', 'Haagen-Dazs', '074570001013', 4.49 UNION ALL
SELECT UUID_STRING(), 'Haagen-Dazs Vanilla Dark Chocolate Bar 3oz', 'Frozen', 'Ice Cream Bars', 'Haagen-Dazs', '074570001020', 4.49 UNION ALL
SELECT UUID_STRING(), 'Haagen-Dazs Coffee Almond Crunch Bar 3oz', 'Frozen', 'Ice Cream Bars', 'Haagen-Dazs', '074570001037', 4.49 UNION ALL
SELECT UUID_STRING(), 'Magnum Classic Ice Cream Bar 3.38oz', 'Frozen', 'Ice Cream Bars', 'Magnum', '077567001012', 4.29 UNION ALL
SELECT UUID_STRING(), 'Magnum Double Caramel Ice Cream Bar 3.04oz', 'Frozen', 'Ice Cream Bars', 'Magnum', '077567001029', 4.29 UNION ALL
SELECT UUID_STRING(), 'Magnum Double Chocolate Ice Cream Bar 3.04oz', 'Frozen', 'Ice Cream Bars', 'Magnum', '077567001036', 4.29 UNION ALL
SELECT UUID_STRING(), 'Dove Vanilla with Milk Chocolate Bar 2.89oz', 'Frozen', 'Ice Cream Bars', 'Dove', '040000501015', 3.99 UNION ALL
SELECT UUID_STRING(), 'Dove Dark Chocolate with Almonds Bar 2.89oz', 'Frozen', 'Ice Cream Bars', 'Dove', '040000501022', 3.99 UNION ALL
SELECT UUID_STRING(), 'Talenti Gelato Layers Vanilla Fudge Cookie Bar', 'Frozen', 'Ice Cream Bars', 'Talenti', '036632001014', 4.99 UNION ALL
-- Novelties
SELECT UUID_STRING(), 'Drumstick Classic Vanilla Cone', 'Frozen', 'Ice Cream Novelties', 'Drumstick', '072554001018', 3.49 UNION ALL
SELECT UUID_STRING(), 'Drumstick Vanilla Caramel Cone', 'Frozen', 'Ice Cream Novelties', 'Drumstick', '072554001025', 3.49 UNION ALL
SELECT UUID_STRING(), 'Klondike Original Vanilla Bar', 'Frozen', 'Ice Cream Novelties', 'Klondike', '075856001013', 3.29 UNION ALL
SELECT UUID_STRING(), 'Klondike Reeses Bar', 'Frozen', 'Ice Cream Novelties', 'Klondike', '075856001020', 3.49 UNION ALL
SELECT UUID_STRING(), 'Klondike Oreo Bar', 'Frozen', 'Ice Cream Novelties', 'Klondike', '075856001037', 3.49 UNION ALL
SELECT UUID_STRING(), 'Good Humor Strawberry Shortcake Bar', 'Frozen', 'Ice Cream Novelties', 'Good Humor', '077567001043', 3.29 UNION ALL
SELECT UUID_STRING(), 'Good Humor Chocolate Eclair Bar', 'Frozen', 'Ice Cream Novelties', 'Good Humor', '077567001050', 3.29 UNION ALL
SELECT UUID_STRING(), 'Good Humor Toasted Almond Bar', 'Frozen', 'Ice Cream Novelties', 'Good Humor', '077567001067', 3.29 UNION ALL
SELECT UUID_STRING(), 'Chipwich Vanilla Ice Cream Cookie Sandwich', 'Frozen', 'Ice Cream Novelties', 'Chipwich', '036632001021', 3.99 UNION ALL
SELECT UUID_STRING(), 'Its-It Ice Cream Sandwich Original', 'Frozen', 'Ice Cream Novelties', 'Its-It', '095474001011', 3.99 UNION ALL
SELECT UUID_STRING(), 'Snickers Ice Cream Bar 2oz', 'Frozen', 'Ice Cream Novelties', 'Snickers', '040000501039', 2.99 UNION ALL
SELECT UUID_STRING(), 'Twix Ice Cream Bar 1.93oz', 'Frozen', 'Ice Cream Novelties', 'Twix', '040000501046', 2.99 UNION ALL
SELECT UUID_STRING(), 'M&M Ice Cream Cookie Sandwich 4oz', 'Frozen', 'Ice Cream Novelties', 'M&Ms', '040000501053', 3.49;

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Frozen Treats
SELECT UUID_STRING(), 'Dippin Dots Cookies and Cream 3oz Cup', 'Frozen', 'Frozen Treats', 'Dippin Dots', '049263001019', 5.99 UNION ALL
SELECT UUID_STRING(), 'Dippin Dots Rainbow Ice 3oz Cup', 'Frozen', 'Frozen Treats', 'Dippin Dots', '049263001026', 5.99 UNION ALL
SELECT UUID_STRING(), 'Dippin Dots Banana Split 3oz Cup', 'Frozen', 'Frozen Treats', 'Dippin Dots', '049263001033', 5.99 UNION ALL
SELECT UUID_STRING(), 'Luigi Italian Ice Lemon 6oz Cup', 'Frozen', 'Frozen Treats', 'Luigis', '036632001038', 2.49 UNION ALL
SELECT UUID_STRING(), 'Luigi Italian Ice Cherry 6oz Cup', 'Frozen', 'Frozen Treats', 'Luigis', '036632001045', 2.49 UNION ALL
SELECT UUID_STRING(), 'Popsicle Original Orange Cherry Grape', 'Frozen', 'Frozen Treats', 'Popsicle', '077567001074', 1.99 UNION ALL
SELECT UUID_STRING(), 'Popsicle Firecracker Red White Blue', 'Frozen', 'Frozen Treats', 'Popsicle', '077567001081', 1.99 UNION ALL
SELECT UUID_STRING(), 'Outshine Fruit Bar Strawberry', 'Frozen', 'Frozen Treats', 'Outshine', '072554001032', 2.49 UNION ALL
SELECT UUID_STRING(), 'Outshine Fruit Bar Coconut', 'Frozen', 'Frozen Treats', 'Outshine', '072554001049', 2.49 UNION ALL
SELECT UUID_STRING(), 'Outshine Fruit Bar Mango', 'Frozen', 'Frozen Treats', 'Outshine', '072554001056', 2.49 UNION ALL
-- Ice Cream Pints
SELECT UUID_STRING(), 'Ben and Jerry Half Baked Pint', 'Frozen', 'Ice Cream Pints', 'Ben and Jerrys', '076840001017', 6.99 UNION ALL
SELECT UUID_STRING(), 'Ben and Jerry Cherry Garcia Pint', 'Frozen', 'Ice Cream Pints', 'Ben and Jerrys', '076840001024', 6.99 UNION ALL
SELECT UUID_STRING(), 'Ben and Jerry Tonight Dough Pint', 'Frozen', 'Ice Cream Pints', 'Ben and Jerrys', '076840001031', 6.99 UNION ALL
SELECT UUID_STRING(), 'Haagen-Dazs Vanilla Bean Pint', 'Frozen', 'Ice Cream Pints', 'Haagen-Dazs', '074570001044', 6.49 UNION ALL
SELECT UUID_STRING(), 'Haagen-Dazs Chocolate Peanut Butter Pint', 'Frozen', 'Ice Cream Pints', 'Haagen-Dazs', '074570001051', 6.49 UNION ALL
SELECT UUID_STRING(), 'Talenti Sea Salt Caramel Gelato Pint', 'Frozen', 'Ice Cream Pints', 'Talenti', '036632001052', 6.49 UNION ALL
SELECT UUID_STRING(), 'Talenti Mediterranean Mint Gelato Pint', 'Frozen', 'Ice Cream Pints', 'Talenti', '036632001069', 6.49 UNION ALL
SELECT UUID_STRING(), 'Halo Top Vanilla Bean Light Ice Cream Pint', 'Frozen', 'Ice Cream Pints', 'Halo Top', '852342003017', 5.49 UNION ALL
SELECT UUID_STRING(), 'Halo Top Peanut Butter Cup Light Ice Cream Pint', 'Frozen', 'Ice Cream Pints', 'Halo Top', '852342003024', 5.49;

-- ============================================================================
-- STANDARD_ITEMS: Bakery and Fresh (~50 items)
-- ============================================================================

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Pastries
SELECT UUID_STRING(), 'Croissant All Butter Large', 'Bakery', 'Pastries', 'Retail Bakery', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Croissant Almond Filled', 'Bakery', 'Pastries', 'Retail Bakery', NULL, 4.49 UNION ALL
SELECT UUID_STRING(), 'Pain au Chocolat', 'Bakery', 'Pastries', 'Retail Bakery', NULL, 4.29 UNION ALL
SELECT UUID_STRING(), 'Danish Cream Cheese', 'Bakery', 'Pastries', 'Retail Bakery', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Danish Raspberry', 'Bakery', 'Pastries', 'Retail Bakery', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Cinnamon Roll Iced Large', 'Bakery', 'Pastries', 'Retail Bakery', NULL, 4.49 UNION ALL
SELECT UUID_STRING(), 'Bear Claw Almond', 'Bakery', 'Pastries', 'Retail Bakery', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Apple Turnover', 'Bakery', 'Pastries', 'Retail Bakery', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Cheese Danish Pocket', 'Bakery', 'Pastries', 'Retail Bakery', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Scone Maple Oat', 'Bakery', 'Pastries', 'Retail Bakery', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Scone Chocolate Chip', 'Bakery', 'Pastries', 'Retail Bakery', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Muffin Pumpkin Spice Large', 'Bakery', 'Pastries', 'Retail Bakery', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Muffin Morning Glory Large', 'Bakery', 'Pastries', 'Retail Bakery', NULL, 3.49 UNION ALL
-- Cookies
SELECT UUID_STRING(), 'Cookie Snickerdoodle Fresh Baked', 'Bakery', 'Cookies', 'Retail Bakery', NULL, 2.99 UNION ALL
SELECT UUID_STRING(), 'Cookie White Chocolate Macadamia Fresh Baked', 'Bakery', 'Cookies', 'Retail Bakery', NULL, 2.99 UNION ALL
SELECT UUID_STRING(), 'Cookie Peanut Butter Fresh Baked', 'Bakery', 'Cookies', 'Retail Bakery', NULL, 2.99 UNION ALL
SELECT UUID_STRING(), 'Cookie Sugar Frosted Fresh Baked', 'Bakery', 'Cookies', 'Retail Bakery', NULL, 2.99 UNION ALL
SELECT UUID_STRING(), 'Cookie Red Velvet Fresh Baked', 'Bakery', 'Cookies', 'Retail Bakery', NULL, 3.29 UNION ALL
SELECT UUID_STRING(), 'Cookie M&M Fresh Baked', 'Bakery', 'Cookies', 'Retail Bakery', NULL, 2.99 UNION ALL
SELECT UUID_STRING(), 'Brownie Fudge Walnut Square', 'Bakery', 'Cookies', 'Retail Bakery', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Brownie Salted Caramel Square', 'Bakery', 'Cookies', 'Retail Bakery', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Blondie Chocolate Chip Square', 'Bakery', 'Cookies', 'Retail Bakery', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Lemon Bar Square', 'Bakery', 'Cookies', 'Retail Bakery', NULL, 3.49;

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Fresh Fruit and Snack Cups
SELECT UUID_STRING(), 'Fresh Fruit Cup Tropical Mix 12oz', 'Bakery', 'Fresh Cups', 'Retail Fresh', NULL, 6.49 UNION ALL
SELECT UUID_STRING(), 'Fresh Fruit Cup Pineapple Chunks 12oz', 'Bakery', 'Fresh Cups', 'Retail Fresh', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Fresh Fruit Cup Grapes and Cheese 8oz', 'Bakery', 'Fresh Cups', 'Retail Fresh', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Yogurt Parfait Strawberry Granola 12oz', 'Bakery', 'Fresh Cups', 'Retail Fresh', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Yogurt Parfait Blueberry Almond 12oz', 'Bakery', 'Fresh Cups', 'Retail Fresh', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Yogurt Parfait Tropical Coconut 12oz', 'Bakery', 'Fresh Cups', 'Retail Fresh', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Overnight Oats Blueberry Almond 8oz', 'Bakery', 'Fresh Cups', 'Retail Fresh', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Overnight Oats PB and Banana 8oz', 'Bakery', 'Fresh Cups', 'Retail Fresh', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Chia Pudding Mango Coconut 8oz', 'Bakery', 'Fresh Cups', 'Retail Fresh', NULL, 5.99 UNION ALL
-- Cheese and Deli Plates
SELECT UUID_STRING(), 'Cheese Plate Trio Cheddar Brie Gouda', 'Bakery', 'Deli Plates', 'Retail Fresh', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'Cheese Plate Italian Provolone Parmesan Mozzarella', 'Bakery', 'Deli Plates', 'Retail Fresh', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'Charcuterie Cup Salami Cheese Crackers', 'Bakery', 'Deli Plates', 'Retail Fresh', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Hummus Cup Classic with Pita Chips', 'Bakery', 'Deli Plates', 'Retail Fresh', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Hummus Cup Roasted Red Pepper with Veggies', 'Bakery', 'Deli Plates', 'Retail Fresh', NULL, 6.49 UNION ALL
SELECT UUID_STRING(), 'Guacamole Cup with Tortilla Chips', 'Bakery', 'Deli Plates', 'Retail Fresh', NULL, 6.49 UNION ALL
-- Bread and Rolls
SELECT UUID_STRING(), 'Sourdough Bread Loaf Fresh Baked', 'Bakery', 'Bread', 'Retail Bakery', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'French Baguette Fresh Baked', 'Bakery', 'Bread', 'Retail Bakery', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Ciabatta Roll Fresh Baked', 'Bakery', 'Bread', 'Retail Bakery', NULL, 2.49 UNION ALL
SELECT UUID_STRING(), 'Pretzel Roll Fresh Baked', 'Bakery', 'Bread', 'Retail Bakery', NULL, 2.49 UNION ALL
SELECT UUID_STRING(), 'Focaccia Rosemary Olive Oil Slice', 'Bakery', 'Bread', 'Retail Bakery', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Cornbread Muffin Fresh Baked', 'Bakery', 'Bread', 'Retail Bakery', NULL, 2.49;

-- ============================================================================
-- STANDARD_ITEMS: Additional Frozen Meals and Convenience (~50 items)
-- ============================================================================

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Frozen Meals
SELECT UUID_STRING(), 'DiGiorno Rising Crust Pepperoni Pizza Personal Size', 'Frozen', 'Frozen Meals', 'DiGiorno', '071921001015', 5.99 UNION ALL
SELECT UUID_STRING(), 'DiGiorno Rising Crust Four Cheese Pizza Personal Size', 'Frozen', 'Frozen Meals', 'DiGiorno', '071921001022', 5.99 UNION ALL
SELECT UUID_STRING(), 'Totino Party Pizza Pepperoni 10.2oz', 'Frozen', 'Frozen Meals', 'Totinos', '042800001015', 2.49 UNION ALL
SELECT UUID_STRING(), 'Totino Party Pizza Cheese 10.2oz', 'Frozen', 'Frozen Meals', 'Totinos', '042800001022', 2.49 UNION ALL
SELECT UUID_STRING(), 'Totino Pizza Rolls Pepperoni 15 Count', 'Frozen', 'Frozen Meals', 'Totinos', '042800001039', 3.99 UNION ALL
SELECT UUID_STRING(), 'El Monterey Beef and Bean Burrito 5oz', 'Frozen', 'Frozen Meals', 'El Monterey', '071007001012', 1.99 UNION ALL
SELECT UUID_STRING(), 'El Monterey Chicken and Cheese Chimichanga 5oz', 'Frozen', 'Frozen Meals', 'El Monterey', '071007001029', 1.99 UNION ALL
SELECT UUID_STRING(), 'Jimmy Dean Sausage Egg Cheese Croissant Sandwich', 'Frozen', 'Frozen Meals', 'Jimmy Dean', '077900001017', 3.49 UNION ALL
SELECT UUID_STRING(), 'Jimmy Dean Bacon Egg Cheese Biscuit Sandwich', 'Frozen', 'Frozen Meals', 'Jimmy Dean', '077900001024', 3.49 UNION ALL
SELECT UUID_STRING(), 'Eggo Homestyle Waffles 2 Pack', 'Frozen', 'Frozen Meals', 'Eggo', '038000001017', 2.49 UNION ALL
SELECT UUID_STRING(), 'Eggo Blueberry Waffles 2 Pack', 'Frozen', 'Frozen Meals', 'Eggo', '038000001024', 2.49 UNION ALL
-- Frozen Snacks
SELECT UUID_STRING(), 'Bagel Bites Three Cheese 9 Count', 'Frozen', 'Frozen Snacks', 'Bagel Bites', '043695001012', 4.49 UNION ALL
SELECT UUID_STRING(), 'Bagel Bites Pepperoni 9 Count', 'Frozen', 'Frozen Snacks', 'Bagel Bites', '043695001029', 4.49 UNION ALL
SELECT UUID_STRING(), 'TGI Fridays Mozzarella Sticks 7.6oz', 'Frozen', 'Frozen Snacks', 'TGI Fridays', '041269001016', 5.99 UNION ALL
SELECT UUID_STRING(), 'TGI Fridays Loaded Potato Skins 7.6oz', 'Frozen', 'Frozen Snacks', 'TGI Fridays', '041269001023', 5.99 UNION ALL
SELECT UUID_STRING(), 'Jose Ole Chicken Taquitos 10 Count', 'Frozen', 'Frozen Snacks', 'Jose Ole', '071007001036', 5.49 UNION ALL
SELECT UUID_STRING(), 'White Castle Cheeseburger Sliders 6 Count', 'Frozen', 'Frozen Snacks', 'White Castle', '058893001016', 6.49 UNION ALL
-- More Bakery Items
SELECT UUID_STRING(), 'Cake Slice Chocolate Layer', 'Bakery', 'Cakes', 'Retail Bakery', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Cake Slice Carrot with Cream Cheese Frosting', 'Bakery', 'Cakes', 'Retail Bakery', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Cake Slice Red Velvet', 'Bakery', 'Cakes', 'Retail Bakery', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Cake Slice New York Cheesecake', 'Bakery', 'Cakes', 'Retail Bakery', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Cake Slice Tiramisu', 'Bakery', 'Cakes', 'Retail Bakery', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Cake Slice Lemon Berry', 'Bakery', 'Cakes', 'Retail Bakery', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Cupcake Vanilla Buttercream', 'Bakery', 'Cakes', 'Retail Bakery', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Cupcake Chocolate Ganache', 'Bakery', 'Cakes', 'Retail Bakery', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Cupcake Red Velvet Cream Cheese', 'Bakery', 'Cakes', 'Retail Bakery', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Pie Slice Apple', 'Bakery', 'Pies', 'Retail Bakery', NULL, 4.99 UNION ALL
SELECT UUID_STRING(), 'Pie Slice Pecan', 'Bakery', 'Pies', 'Retail Bakery', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Pie Slice Key Lime', 'Bakery', 'Pies', 'Retail Bakery', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Pie Slice Pumpkin', 'Bakery', 'Pies', 'Retail Bakery', NULL, 4.99 UNION ALL
-- Packaged Bakery
SELECT UUID_STRING(), 'Entenmanns Rich Frosted Donuts 8 Count', 'Bakery', 'Packaged Bakery', 'Entenmanns', '072030001019', 5.99 UNION ALL
SELECT UUID_STRING(), 'Entenmanns Crumb Coffee Cake', 'Bakery', 'Packaged Bakery', 'Entenmanns', '072030001026', 5.99 UNION ALL
SELECT UUID_STRING(), 'Little Debbie Oatmeal Creme Pies 2 Pack', 'Bakery', 'Packaged Bakery', 'Little Debbie', '024300044144', 1.99 UNION ALL
SELECT UUID_STRING(), 'Little Debbie Honey Buns 2 Pack', 'Bakery', 'Packaged Bakery', 'Little Debbie', '024300044151', 1.99 UNION ALL
SELECT UUID_STRING(), 'Hostess Donettes Powdered 6 Count', 'Bakery', 'Packaged Bakery', 'Hostess', '888109011020', 3.49 UNION ALL
SELECT UUID_STRING(), 'Hostess CupCakes Chocolate 2 Pack', 'Bakery', 'Packaged Bakery', 'Hostess', '888109011037', 2.99 UNION ALL
SELECT UUID_STRING(), 'Pop-Tarts Frosted Strawberry 2 Count', 'Bakery', 'Packaged Bakery', 'Pop-Tarts', '038000001031', 2.49 UNION ALL
SELECT UUID_STRING(), 'Pop-Tarts Frosted Brown Sugar Cinnamon 2 Count', 'Bakery', 'Packaged Bakery', 'Pop-Tarts', '038000001048', 2.49 UNION ALL
SELECT UUID_STRING(), 'Pop-Tarts Frosted S mores 2 Count', 'Bakery', 'Packaged Bakery', 'Pop-Tarts', '038000001055', 2.49 UNION ALL
SELECT UUID_STRING(), 'Belvita Breakfast Biscuit Blueberry 1.76oz Pack', 'Bakery', 'Packaged Bakery', 'Belvita', '044000032210', 2.29 UNION ALL
SELECT UUID_STRING(), 'Belvita Breakfast Biscuit Cinnamon Brown Sugar 1.76oz', 'Bakery', 'Packaged Bakery', 'Belvita', '044000032227', 2.29 UNION ALL
SELECT UUID_STRING(), 'Nature Bakery Fig Bar Blueberry 2oz Twin Pack', 'Bakery', 'Packaged Bakery', 'Nature Bakery', '852799004017', 1.99 UNION ALL
SELECT UUID_STRING(), 'Nature Bakery Fig Bar Raspberry 2oz Twin Pack', 'Bakery', 'Packaged Bakery', 'Nature Bakery', '852799004024', 1.99;
