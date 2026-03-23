-- ============================================================================
-- Retail Data Harmonization Demo
-- Script: sql/setup/05_seed_data/05a_standard_items_beverages.sql
-- Purpose: Seed STANDARD_ITEMS table with beverages (~243 items)
-- Depends on: 02_schema_and_tables.sql
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- STANDARD_ITEMS: Master Item List - BEVERAGES (~213 items)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- BEVERAGES (~150 items)
-- ----------------------------------------------------------------------------

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Carbonated Soft Drinks
SELECT UUID_STRING(), 'Coca-Cola Classic 20oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Coca-Cola', '049000042566', 2.49 UNION ALL
SELECT UUID_STRING(), 'Coca-Cola Classic 12oz Can', 'Beverages', 'Carbonated Soft Drinks', 'Coca-Cola', '049000006582', 1.49 UNION ALL
SELECT UUID_STRING(), 'Coca-Cola Classic 2 Liter Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Coca-Cola', '049000028911', 2.99 UNION ALL
SELECT UUID_STRING(), 'Coca-Cola Zero Sugar 20oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Coca-Cola', '049000042573', 2.49 UNION ALL
SELECT UUID_STRING(), 'Coca-Cola Zero Sugar 12oz Can', 'Beverages', 'Carbonated Soft Drinks', 'Coca-Cola', '049000006599', 1.49 UNION ALL
SELECT UUID_STRING(), 'Diet Coke 20oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Coca-Cola', '049000042580', 2.49 UNION ALL
SELECT UUID_STRING(), 'Diet Coke 12oz Can', 'Beverages', 'Carbonated Soft Drinks', 'Coca-Cola', '049000006605', 1.49 UNION ALL
SELECT UUID_STRING(), 'Coca-Cola Cherry 20oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Coca-Cola', '049000042597', 2.49 UNION ALL
SELECT UUID_STRING(), 'Sprite 20oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Coca-Cola', '049000042603', 2.49 UNION ALL
SELECT UUID_STRING(), 'Sprite 12oz Can', 'Beverages', 'Carbonated Soft Drinks', 'Coca-Cola', '049000006612', 1.49 UNION ALL
SELECT UUID_STRING(), 'Sprite Zero Sugar 20oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Coca-Cola', '049000042610', 2.49 UNION ALL
SELECT UUID_STRING(), 'Fanta Orange 20oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Coca-Cola', '049000042627', 2.49 UNION ALL
SELECT UUID_STRING(), 'Pepsi Cola 20oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Pepsi', '012000001536', 2.49 UNION ALL
SELECT UUID_STRING(), 'Pepsi Cola 12oz Can', 'Beverages', 'Carbonated Soft Drinks', 'Pepsi', '012000001000', 1.49 UNION ALL
SELECT UUID_STRING(), 'Diet Pepsi 20oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Pepsi', '012000001543', 2.49 UNION ALL
SELECT UUID_STRING(), 'Diet Pepsi 12oz Can', 'Beverages', 'Carbonated Soft Drinks', 'Pepsi', '012000001017', 1.49 UNION ALL
SELECT UUID_STRING(), 'Pepsi Zero Sugar 20oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Pepsi', '012000001550', 2.49 UNION ALL
SELECT UUID_STRING(), 'Mountain Dew 20oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Pepsi', '012000001567', 2.49 UNION ALL
SELECT UUID_STRING(), 'Mountain Dew 12oz Can', 'Beverages', 'Carbonated Soft Drinks', 'Pepsi', '012000001024', 1.49 UNION ALL
SELECT UUID_STRING(), 'Mountain Dew Zero Sugar 20oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Pepsi', '012000001574', 2.49 UNION ALL
SELECT UUID_STRING(), 'Dr Pepper 20oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Keurig Dr Pepper', '078000001136', 2.49 UNION ALL
SELECT UUID_STRING(), 'Dr Pepper 12oz Can', 'Beverages', 'Carbonated Soft Drinks', 'Keurig Dr Pepper', '078000001143', 1.49 UNION ALL
SELECT UUID_STRING(), 'Dr Pepper Zero Sugar 20oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Keurig Dr Pepper', '078000001150', 2.49 UNION ALL
SELECT UUID_STRING(), '7UP 20oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Keurig Dr Pepper', '078000001167', 2.29 UNION ALL
SELECT UUID_STRING(), 'Canada Dry Ginger Ale 20oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Keurig Dr Pepper', '078000001174', 2.29 UNION ALL
SELECT UUID_STRING(), 'A&W Root Beer 20oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Keurig Dr Pepper', '078000001181', 2.29 UNION ALL
SELECT UUID_STRING(), 'Sunkist Orange Soda 20oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Keurig Dr Pepper', '078000001198', 2.29;

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Water
SELECT UUID_STRING(), 'Dasani Purified Water 16.9oz Bottle', 'Beverages', 'Water', 'Dasani', '049000031348', 1.99 UNION ALL
SELECT UUID_STRING(), 'Dasani Purified Water 20oz Bottle', 'Beverages', 'Water', 'Dasani', '049000031355', 2.19 UNION ALL
SELECT UUID_STRING(), 'Aquafina Purified Water 16.9oz Bottle', 'Beverages', 'Water', 'Aquafina', '012000001581', 1.99 UNION ALL
SELECT UUID_STRING(), 'Aquafina Purified Water 20oz Bottle', 'Beverages', 'Water', 'Aquafina', '012000001598', 2.19 UNION ALL
SELECT UUID_STRING(), 'Smartwater Vapor Distilled Water 20oz Bottle', 'Beverages', 'Water', 'Smartwater', '786936001013', 2.69 UNION ALL
SELECT UUID_STRING(), 'Smartwater Vapor Distilled Water 1 Liter Bottle', 'Beverages', 'Water', 'Smartwater', '786936001020', 2.99 UNION ALL
SELECT UUID_STRING(), 'Evian Natural Spring Water 16.9oz Bottle', 'Beverages', 'Water', 'Evian', '079298000214', 2.49 UNION ALL
SELECT UUID_STRING(), 'FIJI Natural Artesian Water 16.9oz Bottle', 'Beverages', 'Water', 'FIJI', '632565000012', 2.79 UNION ALL
SELECT UUID_STRING(), 'Essentia Ionized Water 20oz Bottle', 'Beverages', 'Water', 'Essentia', '858606001019', 2.99 UNION ALL
SELECT UUID_STRING(), 'LIFEWTR Purified Water 20oz Bottle', 'Beverages', 'Water', 'LIFEWTR', '012000183638', 2.49 UNION ALL
SELECT UUID_STRING(), 'Poland Spring Water 16.9oz Bottle', 'Beverages', 'Water', 'Poland Spring', '075720004010', 1.79 UNION ALL
-- Sports and Energy Drinks
SELECT UUID_STRING(), 'Gatorade Thirst Quencher Fruit Punch 20oz Bottle', 'Beverages', 'Sports Drinks', 'Gatorade', '052000328011', 2.29 UNION ALL
SELECT UUID_STRING(), 'Gatorade Thirst Quencher Lemon Lime 20oz Bottle', 'Beverages', 'Sports Drinks', 'Gatorade', '052000328028', 2.29 UNION ALL
SELECT UUID_STRING(), 'Gatorade Thirst Quencher Cool Blue 20oz Bottle', 'Beverages', 'Sports Drinks', 'Gatorade', '052000328035', 2.29 UNION ALL
SELECT UUID_STRING(), 'Gatorade Thirst Quencher Orange 20oz Bottle', 'Beverages', 'Sports Drinks', 'Gatorade', '052000328042', 2.29 UNION ALL
SELECT UUID_STRING(), 'Gatorade Thirst Quencher Grape 20oz Bottle', 'Beverages', 'Sports Drinks', 'Gatorade', '052000328059', 2.29 UNION ALL
SELECT UUID_STRING(), 'Gatorade Zero Glacier Cherry 20oz Bottle', 'Beverages', 'Sports Drinks', 'Gatorade', '052000043013', 2.29 UNION ALL
SELECT UUID_STRING(), 'Gatorade Zero Lemon Lime 20oz Bottle', 'Beverages', 'Sports Drinks', 'Gatorade', '052000043020', 2.29 UNION ALL
SELECT UUID_STRING(), 'Powerade Mountain Berry Blast 20oz Bottle', 'Beverages', 'Sports Drinks', 'Powerade', '049000050103', 1.99 UNION ALL
SELECT UUID_STRING(), 'Powerade Fruit Punch 20oz Bottle', 'Beverages', 'Sports Drinks', 'Powerade', '049000050110', 1.99 UNION ALL
SELECT UUID_STRING(), 'BODYARMOR SuperDrink Strawberry Banana 16oz Bottle', 'Beverages', 'Sports Drinks', 'BODYARMOR', '858176002010', 2.99 UNION ALL
SELECT UUID_STRING(), 'Red Bull Energy Drink 8.4oz Can', 'Beverages', 'Energy Drinks', 'Red Bull', '611269991000', 3.49 UNION ALL
SELECT UUID_STRING(), 'Red Bull Energy Drink 12oz Can', 'Beverages', 'Energy Drinks', 'Red Bull', '611269991017', 4.29 UNION ALL
SELECT UUID_STRING(), 'Red Bull Sugar Free 8.4oz Can', 'Beverages', 'Energy Drinks', 'Red Bull', '611269991024', 3.49 UNION ALL
SELECT UUID_STRING(), 'Monster Energy Original 16oz Can', 'Beverages', 'Energy Drinks', 'Monster', '070847811725', 3.49 UNION ALL
SELECT UUID_STRING(), 'Monster Energy Zero Ultra 16oz Can', 'Beverages', 'Energy Drinks', 'Monster', '070847811732', 3.49 UNION ALL
SELECT UUID_STRING(), 'Monster Energy Ultra Paradise 16oz Can', 'Beverages', 'Energy Drinks', 'Monster', '070847811749', 3.49 UNION ALL
SELECT UUID_STRING(), 'Celsius Sparkling Orange 12oz Can', 'Beverages', 'Energy Drinks', 'Celsius', '889392000108', 2.99 UNION ALL
SELECT UUID_STRING(), 'Celsius Sparkling Wild Berry 12oz Can', 'Beverages', 'Energy Drinks', 'Celsius', '889392000115', 2.99 UNION ALL
SELECT UUID_STRING(), 'Rockstar Energy Original 16oz Can', 'Beverages', 'Energy Drinks', 'Rockstar', '818094006019', 2.99;

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Coffee and Tea
SELECT UUID_STRING(), 'Starbucks Frappuccino Mocha 13.7oz Bottle', 'Beverages', 'Coffee', 'Starbucks', '012000161438', 3.99 UNION ALL
SELECT UUID_STRING(), 'Starbucks Frappuccino Vanilla 13.7oz Bottle', 'Beverages', 'Coffee', 'Starbucks', '012000161445', 3.99 UNION ALL
SELECT UUID_STRING(), 'Starbucks Frappuccino Caramel 13.7oz Bottle', 'Beverages', 'Coffee', 'Starbucks', '012000161452', 3.99 UNION ALL
SELECT UUID_STRING(), 'Starbucks Doubleshot Espresso 6.5oz Can', 'Beverages', 'Coffee', 'Starbucks', '012000161469', 3.49 UNION ALL
SELECT UUID_STRING(), 'Starbucks Iced Coffee Unsweetened 11oz Bottle', 'Beverages', 'Coffee', 'Starbucks', '012000161476', 3.49 UNION ALL
SELECT UUID_STRING(), 'Dunkin Donuts Iced Coffee Original 13.7oz Bottle', 'Beverages', 'Coffee', 'Dunkin', '049000072136', 3.49 UNION ALL
SELECT UUID_STRING(), 'Java Monster Mean Bean 15oz Can', 'Beverages', 'Coffee', 'Monster', '070847020011', 3.99 UNION ALL
SELECT UUID_STRING(), 'Pure Leaf Iced Tea Unsweetened 18.5oz Bottle', 'Beverages', 'Tea', 'Pure Leaf', '012000164019', 2.49 UNION ALL
SELECT UUID_STRING(), 'Pure Leaf Iced Tea Sweet Tea 18.5oz Bottle', 'Beverages', 'Tea', 'Pure Leaf', '012000164026', 2.49 UNION ALL
SELECT UUID_STRING(), 'Pure Leaf Iced Tea Raspberry 18.5oz Bottle', 'Beverages', 'Tea', 'Pure Leaf', '012000164033', 2.49 UNION ALL
SELECT UUID_STRING(), 'Gold Peak Real Brewed Tea Sweet 18.5oz Bottle', 'Beverages', 'Tea', 'Gold Peak', '049000070019', 2.49 UNION ALL
SELECT UUID_STRING(), 'Arizona Green Tea with Honey 23oz Can', 'Beverages', 'Tea', 'Arizona', '613008700010', 1.29 UNION ALL
SELECT UUID_STRING(), 'Lipton Brisk Lemon Iced Tea 20oz Bottle', 'Beverages', 'Tea', 'Lipton', '012000194016', 1.99 UNION ALL
-- Juice
SELECT UUID_STRING(), 'Tropicana Pure Premium Orange Juice 12oz Bottle', 'Beverages', 'Juice', 'Tropicana', '048500012536', 2.99 UNION ALL
SELECT UUID_STRING(), 'Tropicana Pure Premium Apple Juice 12oz Bottle', 'Beverages', 'Juice', 'Tropicana', '048500012543', 2.99 UNION ALL
SELECT UUID_STRING(), 'Minute Maid Orange Juice 12oz Bottle', 'Beverages', 'Juice', 'Minute Maid', '025000044236', 2.79 UNION ALL
SELECT UUID_STRING(), 'Minute Maid Apple Juice 12oz Bottle', 'Beverages', 'Juice', 'Minute Maid', '025000044243', 2.79 UNION ALL
SELECT UUID_STRING(), 'Simply Orange Juice 11.5oz Bottle', 'Beverages', 'Juice', 'Simply', '025000044250', 3.29 UNION ALL
SELECT UUID_STRING(), 'Ocean Spray Cranberry Juice Cocktail 15.2oz Bottle', 'Beverages', 'Juice', 'Ocean Spray', '031200270016', 2.49 UNION ALL
SELECT UUID_STRING(), 'V8 Original Vegetable Juice 11.5oz Can', 'Beverages', 'Juice', 'V8', '051000122018', 2.29 UNION ALL
SELECT UUID_STRING(), 'Naked Juice Green Machine 15.2oz Bottle', 'Beverages', 'Juice', 'Naked', '082592720108', 4.99 UNION ALL
SELECT UUID_STRING(), 'Welchs Grape Juice 10oz Bottle', 'Beverages', 'Juice', 'Welchs', '041800324101', 2.19 UNION ALL
-- Milk and Dairy Drinks
SELECT UUID_STRING(), 'Fairlife Core Power Chocolate 14oz Bottle', 'Beverages', 'Dairy Drinks', 'Fairlife', '811620020119', 3.99 UNION ALL
SELECT UUID_STRING(), 'Fairlife Core Power Vanilla 14oz Bottle', 'Beverages', 'Dairy Drinks', 'Fairlife', '811620020126', 3.99 UNION ALL
SELECT UUID_STRING(), 'Horizon Organic 1% Lowfat Milk 8oz Carton', 'Beverages', 'Dairy Drinks', 'Horizon', '742365004537', 1.99 UNION ALL
SELECT UUID_STRING(), 'TruMoo Chocolate 1% Lowfat Milk 8oz Carton', 'Beverages', 'Dairy Drinks', 'TruMoo', '071510100128', 1.79 UNION ALL
SELECT UUID_STRING(), 'Nesquik Chocolate Milk 14oz Bottle', 'Beverages', 'Dairy Drinks', 'Nesquik', '028000100100', 2.79 UNION ALL
-- Smoothies and Kombucha
SELECT UUID_STRING(), 'Bolthouse Farms Berry Boost Smoothie 15.2oz Bottle', 'Beverages', 'Smoothies', 'Bolthouse Farms', '071464010218', 4.49 UNION ALL
SELECT UUID_STRING(), 'GT Kombucha Gingerade 16oz Bottle', 'Beverages', 'Kombucha', 'GTs', '722430200108', 4.29 UNION ALL
SELECT UUID_STRING(), 'Kevita Master Brew Pineapple Peach Kombucha 15.2oz Can', 'Beverages', 'Kombucha', 'Kevita', '853311003007', 3.49;

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- More Beverages to reach ~150
SELECT UUID_STRING(), 'Coca-Cola Caffeine Free 12oz Can', 'Beverages', 'Carbonated Soft Drinks', 'Coca-Cola', '049000006636', 1.49 UNION ALL
SELECT UUID_STRING(), 'Barqs Root Beer 20oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Coca-Cola', '049000042634', 2.29 UNION ALL
SELECT UUID_STRING(), 'Mello Yello 20oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Coca-Cola', '049000042641', 2.29 UNION ALL
SELECT UUID_STRING(), 'Pepsi Wild Cherry 20oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Pepsi', '012000001604', 2.49 UNION ALL
SELECT UUID_STRING(), 'Sierra Mist 20oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Pepsi', '012000001611', 2.29 UNION ALL
SELECT UUID_STRING(), 'Crush Orange 20oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Keurig Dr Pepper', '078000001204', 2.29 UNION ALL
SELECT UUID_STRING(), 'Gatorade Thirst Quencher Glacier Freeze 20oz Bottle', 'Beverages', 'Sports Drinks', 'Gatorade', '052000328066', 2.29 UNION ALL
SELECT UUID_STRING(), 'Gatorade Thirst Quencher Berry 20oz Bottle', 'Beverages', 'Sports Drinks', 'Gatorade', '052000328073', 2.29 UNION ALL
SELECT UUID_STRING(), 'BODYARMOR Lyte Peach Mango 16oz Bottle', 'Beverages', 'Sports Drinks', 'BODYARMOR', '858176002027', 2.99 UNION ALL
SELECT UUID_STRING(), 'Propel Electrolyte Water Berry 20oz Bottle', 'Beverages', 'Water', 'Propel', '052000215014', 1.99 UNION ALL
SELECT UUID_STRING(), 'Vitaminwater XXX Acai Blueberry Pomegranate 20oz Bottle', 'Beverages', 'Water', 'Vitaminwater', '786936400110', 2.49 UNION ALL
SELECT UUID_STRING(), 'Vitaminwater Power-C Dragonfruit 20oz Bottle', 'Beverages', 'Water', 'Vitaminwater', '786936400127', 2.49 UNION ALL
SELECT UUID_STRING(), 'Core Hydration Water 20oz Bottle', 'Beverages', 'Water', 'Core', '851766003010', 2.29 UNION ALL
SELECT UUID_STRING(), 'Monster Energy Java Loca Moca 15oz Can', 'Beverages', 'Energy Drinks', 'Monster', '070847020028', 3.99 UNION ALL
SELECT UUID_STRING(), 'Celsius Sparkling Watermelon 12oz Can', 'Beverages', 'Energy Drinks', 'Celsius', '889392000122', 2.99 UNION ALL
SELECT UUID_STRING(), 'Celsius Sparkling Kiwi Guava 12oz Can', 'Beverages', 'Energy Drinks', 'Celsius', '889392000139', 2.99 UNION ALL
SELECT UUID_STRING(), 'NOS Energy Drink Original 16oz Can', 'Beverages', 'Energy Drinks', 'NOS', '815154010016', 2.99 UNION ALL
SELECT UUID_STRING(), 'Bang Energy Rainbow Unicorn 16oz Can', 'Beverages', 'Energy Drinks', 'Bang', '610764863010', 2.99 UNION ALL
SELECT UUID_STRING(), 'Starbucks Refreshers Strawberry Lemonade 12oz Can', 'Beverages', 'Coffee', 'Starbucks', '012000161483', 3.49 UNION ALL
SELECT UUID_STRING(), 'International Delight Iced Coffee Mocha 15oz Bottle', 'Beverages', 'Coffee', 'International Delight', '041271029010', 2.99 UNION ALL
SELECT UUID_STRING(), 'Snapple Peach Tea 16oz Bottle', 'Beverages', 'Tea', 'Snapple', '076183263616', 2.29 UNION ALL
SELECT UUID_STRING(), 'Snapple Lemon Tea 16oz Bottle', 'Beverages', 'Tea', 'Snapple', '076183263623', 2.29 UNION ALL
SELECT UUID_STRING(), 'Honest Tea Organic Honey Green 16.9oz Bottle', 'Beverages', 'Tea', 'Honest Tea', '657622600103', 2.49 UNION ALL
SELECT UUID_STRING(), 'Bai Antioxidant Brasilia Blueberry 18oz Bottle', 'Beverages', 'Juice', 'Bai', '813694024012', 2.49 UNION ALL
SELECT UUID_STRING(), 'Bai Antioxidant Costa Rica Clementine 18oz Bottle', 'Beverages', 'Juice', 'Bai', '813694024029', 2.49 UNION ALL
SELECT UUID_STRING(), 'Yoo-hoo Chocolate Drink 6.5oz Box', 'Beverages', 'Dairy Drinks', 'Yoo-hoo', '072490000108', 1.29 UNION ALL
SELECT UUID_STRING(), 'Muscle Milk Genuine Chocolate 14oz Bottle', 'Beverages', 'Dairy Drinks', 'Muscle Milk', '876063002011', 3.99 UNION ALL
SELECT UUID_STRING(), 'Silk Almond Milk Original 8oz Carton', 'Beverages', 'Dairy Drinks', 'Silk', '025293001008', 1.99 UNION ALL
SELECT UUID_STRING(), 'Oatly Oat Milk Barista Edition 32oz Carton', 'Beverages', 'Dairy Drinks', 'Oatly', '757063643012', 5.99 UNION ALL
SELECT UUID_STRING(), 'San Pellegrino Sparkling Water 16.9oz Bottle', 'Beverages', 'Water', 'San Pellegrino', '041508800013', 2.49 UNION ALL
SELECT UUID_STRING(), 'Perrier Sparkling Water Original 16.9oz Bottle', 'Beverages', 'Water', 'Perrier', '074780378109', 2.29 UNION ALL
SELECT UUID_STRING(), 'LaCroix Sparkling Water Lime 12oz Can', 'Beverages', 'Water', 'LaCroix', '073360831126', 1.29 UNION ALL
SELECT UUID_STRING(), 'Topo Chico Mineral Water 12oz Bottle', 'Beverages', 'Water', 'Topo Chico', '021136070101', 2.29;

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Craft/Specialty Sodas
SELECT UUID_STRING(), 'Jarritos Mandarin 12.5oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Jarritos', '090478170121', 2.29 UNION ALL
SELECT UUID_STRING(), 'Jarritos Tamarind 12.5oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Jarritos', '090478170138', 2.29 UNION ALL
SELECT UUID_STRING(), 'Jarritos Lime 12.5oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Jarritos', '090478170145', 2.29 UNION ALL
SELECT UUID_STRING(), 'Jarritos Guava 12.5oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Jarritos', '090478170152', 2.29 UNION ALL
SELECT UUID_STRING(), 'Jarritos Pineapple 12.5oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Jarritos', '090478170169', 2.29 UNION ALL
SELECT UUID_STRING(), 'Boylan Cane Cola 12oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Boylan', '760712200012', 2.99 UNION ALL
SELECT UUID_STRING(), 'Boylan Black Cherry 12oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Boylan', '760712200029', 2.99 UNION ALL
SELECT UUID_STRING(), 'Jones Soda Berry Lemonade 12oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Jones Soda', '012000810015', 2.49 UNION ALL
SELECT UUID_STRING(), 'Jones Soda Green Apple 12oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Jones Soda', '012000810022', 2.49 UNION ALL
SELECT UUID_STRING(), 'Mexican Coca-Cola 355ml Glass Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Coca-Cola', '049000050158', 2.99 UNION ALL
SELECT UUID_STRING(), 'Fentimans Rose Lemonade 9.3oz Bottle', 'Beverages', 'Carbonated Soft Drinks', 'Fentimans', '812988020013', 3.49 UNION ALL
SELECT UUID_STRING(), 'Virgils Root Beer 12oz Can', 'Beverages', 'Carbonated Soft Drinks', 'Virgils', '072310000117', 2.49 UNION ALL
-- RTD Coffee
SELECT UUID_STRING(), 'Starbucks Frappuccino Coffee 13.7oz Bottle', 'Beverages', 'Coffee', 'Starbucks', '012000161490', 3.99 UNION ALL
SELECT UUID_STRING(), 'Starbucks Doubleshot Energy Mocha 15oz Can', 'Beverages', 'Coffee', 'Starbucks', '012000161506', 3.99 UNION ALL
SELECT UUID_STRING(), 'Starbucks Tripleshot Energy French Vanilla 15oz Can', 'Beverages', 'Coffee', 'Starbucks', '012000161513', 4.49 UNION ALL
SELECT UUID_STRING(), 'Dunkin Donuts Iced Coffee French Vanilla 13.7oz Bottle', 'Beverages', 'Coffee', 'Dunkin', '049000072143', 3.49 UNION ALL
SELECT UUID_STRING(), 'Dunkin Donuts Iced Coffee Mocha 13.7oz Bottle', 'Beverages', 'Coffee', 'Dunkin', '049000072150', 3.49 UNION ALL
SELECT UUID_STRING(), 'High Brew Cold Brew Double Espresso 8oz Can', 'Beverages', 'Coffee', 'High Brew', '864482000115', 3.49 UNION ALL
SELECT UUID_STRING(), 'High Brew Cold Brew Mexican Vanilla 8oz Can', 'Beverages', 'Coffee', 'High Brew', '864482000122', 3.49 UNION ALL
SELECT UUID_STRING(), 'La Colombe Draft Latte Triple 9oz Can', 'Beverages', 'Coffee', 'La Colombe', '855765007015', 3.99 UNION ALL
SELECT UUID_STRING(), 'La Colombe Draft Latte Vanilla 9oz Can', 'Beverages', 'Coffee', 'La Colombe', '855765007022', 3.99 UNION ALL
SELECT UUID_STRING(), 'Chameleon Cold Brew Black Coffee 10oz Bottle', 'Beverages', 'Coffee', 'Chameleon', '851220003012', 4.29 UNION ALL
-- Protein Drinks
SELECT UUID_STRING(), 'Muscle Milk Genuine Vanilla Creme 14oz Bottle', 'Beverages', 'Dairy Drinks', 'Muscle Milk', '876063002028', 3.99 UNION ALL
SELECT UUID_STRING(), 'Muscle Milk Pro Series Knockout Chocolate 14oz Bottle', 'Beverages', 'Dairy Drinks', 'Muscle Milk', '876063002035', 4.49 UNION ALL
SELECT UUID_STRING(), 'Core Power Elite Chocolate 14oz Bottle', 'Beverages', 'Dairy Drinks', 'Fairlife', '811620020133', 4.99 UNION ALL
SELECT UUID_STRING(), 'Core Power Elite Strawberry Banana 14oz Bottle', 'Beverages', 'Dairy Drinks', 'Fairlife', '811620020140', 4.99 UNION ALL
SELECT UUID_STRING(), 'Premier Protein Shake Chocolate 11.5oz Bottle', 'Beverages', 'Dairy Drinks', 'Premier Protein', '643843100118', 3.49 UNION ALL
SELECT UUID_STRING(), 'Premier Protein Shake Vanilla 11.5oz Bottle', 'Beverages', 'Dairy Drinks', 'Premier Protein', '643843100125', 3.49 UNION ALL
SELECT UUID_STRING(), 'Premier Protein Shake Caramel 11.5oz Bottle', 'Beverages', 'Dairy Drinks', 'Premier Protein', '643843100132', 3.49 UNION ALL
SELECT UUID_STRING(), 'Orgain Organic Protein Shake Creamy Chocolate 11oz Bottle', 'Beverages', 'Dairy Drinks', 'Orgain', '851770003018', 3.99 UNION ALL
-- Specialty Water
SELECT UUID_STRING(), 'Liquid Death Mountain Water 19.2oz Can', 'Beverages', 'Water', 'Liquid Death', '850003560001', 2.49 UNION ALL
SELECT UUID_STRING(), 'Liquid Death Sparkling Water 19.2oz Can', 'Beverages', 'Water', 'Liquid Death', '850003560018', 2.49 UNION ALL
SELECT UUID_STRING(), 'Liquid Death Severed Lime Sparkling 19.2oz Can', 'Beverages', 'Water', 'Liquid Death', '850003560025', 2.49 UNION ALL
SELECT UUID_STRING(), 'Hint Water Watermelon 16oz Bottle', 'Beverages', 'Water', 'Hint', '184739000118', 2.29 UNION ALL
SELECT UUID_STRING(), 'Hint Water Blackberry 16oz Bottle', 'Beverages', 'Water', 'Hint', '184739000125', 2.29 UNION ALL
SELECT UUID_STRING(), 'Hint Water Pineapple 16oz Bottle', 'Beverages', 'Water', 'Hint', '184739000132', 2.29 UNION ALL
SELECT UUID_STRING(), 'Essentia Ionized Water 1 Liter Bottle', 'Beverages', 'Water', 'Essentia', '858606001026', 3.49 UNION ALL
SELECT UUID_STRING(), 'Voss Still Water 16.9oz Bottle', 'Beverages', 'Water', 'Voss', '682430010017', 2.99 UNION ALL
SELECT UUID_STRING(), 'Voss Sparkling Water 12.7oz Bottle', 'Beverages', 'Water', 'Voss', '682430010024', 2.99 UNION ALL
-- Kombucha
SELECT UUID_STRING(), 'GT Kombucha Trilogy 16oz Bottle', 'Beverages', 'Kombucha', 'GTs', '722430200115', 4.29 UNION ALL
SELECT UUID_STRING(), 'GT Kombucha Multi-Green 16oz Bottle', 'Beverages', 'Kombucha', 'GTs', '722430200122', 4.29 UNION ALL
SELECT UUID_STRING(), 'GT Kombucha Mystic Mango 16oz Bottle', 'Beverages', 'Kombucha', 'GTs', '722430200139', 4.29 UNION ALL
SELECT UUID_STRING(), 'Health-Ade Kombucha Pink Lady Apple 16oz Bottle', 'Beverages', 'Kombucha', 'Health-Ade', '851861006018', 4.49 UNION ALL
SELECT UUID_STRING(), 'Health-Ade Kombucha Pomegranate 16oz Bottle', 'Beverages', 'Kombucha', 'Health-Ade', '851861006025', 4.49 UNION ALL
SELECT UUID_STRING(), 'Health-Ade Kombucha Bubbly Rose 16oz Bottle', 'Beverages', 'Kombucha', 'Health-Ade', '851861006032', 4.49 UNION ALL
-- Plant-Based Milks
SELECT UUID_STRING(), 'Oatly Oat Milk Original 8oz Carton', 'Beverages', 'Dairy Drinks', 'Oatly', '757063643029', 2.49 UNION ALL
SELECT UUID_STRING(), 'Oatly Oat Milk Chocolate 8oz Carton', 'Beverages', 'Dairy Drinks', 'Oatly', '757063643036', 2.49 UNION ALL
SELECT UUID_STRING(), 'Silk Almond Milk Unsweetened 8oz Carton', 'Beverages', 'Dairy Drinks', 'Silk', '025293001015', 1.99 UNION ALL
SELECT UUID_STRING(), 'Silk Oat Yeah Oatmilk Original 10oz Carton', 'Beverages', 'Dairy Drinks', 'Silk', '025293001022', 2.49 UNION ALL
SELECT UUID_STRING(), 'Almond Breeze Original 8oz Carton', 'Beverages', 'Dairy Drinks', 'Almond Breeze', '041570054215', 1.99 UNION ALL
SELECT UUID_STRING(), 'Almond Breeze Vanilla 8oz Carton', 'Beverages', 'Dairy Drinks', 'Almond Breeze', '041570054222', 1.99 UNION ALL
SELECT UUID_STRING(), 'Califia Farms Oat Barista Blend 32oz Carton', 'Beverages', 'Dairy Drinks', 'Califia Farms', '852909003010', 5.99 UNION ALL
SELECT UUID_STRING(), 'Ripple Plant-Based Milk Original 8oz Bottle', 'Beverages', 'Dairy Drinks', 'Ripple', '855643006015', 2.99 UNION ALL
-- Additional Energy Drinks
SELECT UUID_STRING(), 'Alani Nu Energy Drink Cosmic Stardust 12oz Can', 'Beverages', 'Energy Drinks', 'Alani Nu', '850030592010', 2.99 UNION ALL
SELECT UUID_STRING(), 'Alani Nu Energy Drink Hawaiian Shaved Ice 12oz Can', 'Beverages', 'Energy Drinks', 'Alani Nu', '850030592027', 2.99 UNION ALL
SELECT UUID_STRING(), 'Alani Nu Energy Drink Cherry Slush 12oz Can', 'Beverages', 'Energy Drinks', 'Alani Nu', '850030592034', 2.99 UNION ALL
SELECT UUID_STRING(), 'Ghost Energy Drink Sour Patch Redberry 16oz Can', 'Beverages', 'Energy Drinks', 'Ghost', '810044880014', 3.49 UNION ALL
SELECT UUID_STRING(), 'Ghost Energy Drink Warheads Sour Watermelon 16oz Can', 'Beverages', 'Energy Drinks', 'Ghost', '810044880021', 3.49 UNION ALL
SELECT UUID_STRING(), 'Celsius Sparkling Peach Vibe 12oz Can', 'Beverages', 'Energy Drinks', 'Celsius', '889392000146', 2.99 UNION ALL
SELECT UUID_STRING(), 'Celsius Sparkling Mango Passionfruit 12oz Can', 'Beverages', 'Energy Drinks', 'Celsius', '889392000153', 2.99 UNION ALL
SELECT UUID_STRING(), 'Monster Energy Ultra Gold 16oz Can', 'Beverages', 'Energy Drinks', 'Monster', '070847811756', 3.49 UNION ALL
SELECT UUID_STRING(), 'Monster Energy Ultra Rosa 16oz Can', 'Beverages', 'Energy Drinks', 'Monster', '070847811763', 3.49 UNION ALL
SELECT UUID_STRING(), 'Red Bull Tropical Edition 8.4oz Can', 'Beverages', 'Energy Drinks', 'Red Bull', '611269991031', 3.49 UNION ALL
SELECT UUID_STRING(), 'Red Bull Coconut Edition 8.4oz Can', 'Beverages', 'Energy Drinks', 'Red Bull', '611269991048', 3.49 UNION ALL
SELECT UUID_STRING(), 'ZOA Energy Drink Original 16oz Can', 'Beverages', 'Energy Drinks', 'ZOA', '850027672014', 2.99 UNION ALL
-- Additional Tea
SELECT UUID_STRING(), 'Snapple Diet Peach Tea 16oz Bottle', 'Beverages', 'Tea', 'Snapple', '076183263630', 2.29 UNION ALL
SELECT UUID_STRING(), 'Arizona Mucho Mango 23oz Can', 'Beverages', 'Tea', 'Arizona', '613008700027', 1.29 UNION ALL
SELECT UUID_STRING(), 'Arizona Arnold Palmer Half and Half 23oz Can', 'Beverages', 'Tea', 'Arizona', '613008700034', 1.29 UNION ALL
SELECT UUID_STRING(), 'Lipton Pure Leaf Sweet Tea Peach 18.5oz Bottle', 'Beverages', 'Tea', 'Pure Leaf', '012000164040', 2.49 UNION ALL
SELECT UUID_STRING(), 'Tejava Premium Iced Tea Unsweetened 16.9oz Bottle', 'Beverages', 'Tea', 'Tejava', '088211230015', 2.29 UNION ALL
SELECT UUID_STRING(), 'Ito En Green Tea Unsweetened 16.9oz Bottle', 'Beverages', 'Tea', 'Ito En', '835143001012', 2.49 UNION ALL
-- Additional Juice
SELECT UUID_STRING(), 'Naked Juice Mighty Mango 15.2oz Bottle', 'Beverages', 'Juice', 'Naked', '082592720115', 4.99 UNION ALL
SELECT UUID_STRING(), 'Naked Juice Blue Machine 15.2oz Bottle', 'Beverages', 'Juice', 'Naked', '082592720122', 4.99 UNION ALL
SELECT UUID_STRING(), 'Evolution Fresh Essential Greens 15.2oz Bottle', 'Beverages', 'Juice', 'Evolution Fresh', '098954510015', 5.99 UNION ALL
SELECT UUID_STRING(), 'Suja Organic Mighty Greens 12oz Bottle', 'Beverages', 'Juice', 'Suja', '818617020118', 5.49 UNION ALL
SELECT UUID_STRING(), 'Martinellis Apple Juice 10oz Bottle', 'Beverages', 'Juice', 'Martinellis', '041244100101', 2.99 UNION ALL
SELECT UUID_STRING(), 'Coconut Water Vita Coco Original 16.9oz Carton', 'Beverages', 'Juice', 'Vita Coco', '898999000118', 3.49 UNION ALL
SELECT UUID_STRING(), 'Coconut Water Harmless Harvest Organic 16oz Bottle', 'Beverages', 'Juice', 'Harmless Harvest', '859000003012', 5.49 UNION ALL
-- Lemonade
SELECT UUID_STRING(), 'Simply Lemonade 11.5oz Bottle', 'Beverages', 'Juice', 'Simply', '025000044267', 3.29 UNION ALL
SELECT UUID_STRING(), 'Simply Lemonade with Raspberry 11.5oz Bottle', 'Beverages', 'Juice', 'Simply', '025000044274', 3.29 UNION ALL
SELECT UUID_STRING(), 'Calypso Ocean Blue Lemonade 16oz Bottle', 'Beverages', 'Juice', 'Calypso', '091037501011', 2.99 UNION ALL
SELECT UUID_STRING(), 'Calypso Triple Melon Lemonade 16oz Bottle', 'Beverages', 'Juice', 'Calypso', '091037501028', 2.99 UNION ALL
SELECT UUID_STRING(), 'Hubert Lemonade Original 16oz Bottle', 'Beverages', 'Juice', 'Huberts', '049000072167', 2.79;

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Electrolyte/Hydration
SELECT UUID_STRING(), 'Pedialyte Electrolyte Solution Grape 16.9oz Bottle', 'Beverages', 'Sports Drinks', 'Pedialyte', '070074564012', 4.99 UNION ALL
SELECT UUID_STRING(), 'Liquid IV Hydration Multiplier Lemon Lime Stick', 'Beverages', 'Sports Drinks', 'Liquid IV', '851657006012', 2.49 UNION ALL
SELECT UUID_STRING(), 'PRIME Hydration Tropical Punch 16.9oz Bottle', 'Beverages', 'Sports Drinks', 'PRIME', '850003550510', 2.49 UNION ALL
SELECT UUID_STRING(), 'PRIME Hydration Blue Raspberry 16.9oz Bottle', 'Beverages', 'Sports Drinks', 'PRIME', '850003550527', 2.49 UNION ALL
SELECT UUID_STRING(), 'PRIME Hydration Ice Pop 16.9oz Bottle', 'Beverages', 'Sports Drinks', 'PRIME', '850003550534', 2.49 UNION ALL
SELECT UUID_STRING(), 'Electrolit Electrolyte Beverage Fruit Punch 21oz Bottle', 'Beverages', 'Sports Drinks', 'Electrolit', '754925001013', 2.99 UNION ALL
SELECT UUID_STRING(), 'Electrolit Electrolyte Beverage Coconut 21oz Bottle', 'Beverages', 'Sports Drinks', 'Electrolit', '754925001020', 2.99 UNION ALL
SELECT UUID_STRING(), 'BodyArmor Flash IV Strawberry Kiwi 20oz Bottle', 'Beverages', 'Sports Drinks', 'BODYARMOR', '858176002034', 2.49 UNION ALL
SELECT UUID_STRING(), 'Gatorade Gatorlyte Cherry Lime 20oz Bottle', 'Beverages', 'Sports Drinks', 'Gatorade', '052000043037', 2.79 UNION ALL
SELECT UUID_STRING(), 'Gatorade Fit Citrus Berry 16.9oz Bottle', 'Beverages', 'Sports Drinks', 'Gatorade', '052000043044', 2.49;

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Additional Specialty Beverages
SELECT UUID_STRING(), 'Poppi Prebiotic Soda Classic Cola 12oz Can', 'Beverages', 'Carbonated Soft Drinks', 'Poppi', '860002900011', 2.99 UNION ALL
SELECT UUID_STRING(), 'Poppi Prebiotic Soda Strawberry Lemon 12oz Can', 'Beverages', 'Carbonated Soft Drinks', 'Poppi', '860002900028', 2.99 UNION ALL
SELECT UUID_STRING(), 'Poppi Prebiotic Soda Orange 12oz Can', 'Beverages', 'Carbonated Soft Drinks', 'Poppi', '860002900035', 2.99 UNION ALL
SELECT UUID_STRING(), 'Olipop Vintage Cola 12oz Can', 'Beverages', 'Carbonated Soft Drinks', 'Olipop', '860002800012', 2.99 UNION ALL
SELECT UUID_STRING(), 'Olipop Strawberry Vanilla 12oz Can', 'Beverages', 'Carbonated Soft Drinks', 'Olipop', '860002800029', 2.99 UNION ALL
SELECT UUID_STRING(), 'Olipop Ginger Lemon 12oz Can', 'Beverages', 'Carbonated Soft Drinks', 'Olipop', '860002800036', 2.99 UNION ALL
SELECT UUID_STRING(), 'Spindrift Sparkling Water Raspberry Lime 12oz Can', 'Beverages', 'Water', 'Spindrift', '856579002117', 2.29 UNION ALL
SELECT UUID_STRING(), 'Spindrift Sparkling Water Lemon 12oz Can', 'Beverages', 'Water', 'Spindrift', '856579002124', 2.29 UNION ALL
SELECT UUID_STRING(), 'Spindrift Sparkling Water Grapefruit 12oz Can', 'Beverages', 'Water', 'Spindrift', '856579002131', 2.29 UNION ALL
SELECT UUID_STRING(), 'Waterloo Sparkling Water Black Cherry 12oz Can', 'Beverages', 'Water', 'Waterloo', '819215020012', 1.79 UNION ALL
SELECT UUID_STRING(), 'Waterloo Sparkling Water Grape 12oz Can', 'Beverages', 'Water', 'Waterloo', '819215020029', 1.79 UNION ALL
SELECT UUID_STRING(), 'LaCroix Sparkling Water Pamplemousse 12oz Can', 'Beverages', 'Water', 'LaCroix', '073360831133', 1.29 UNION ALL
SELECT UUID_STRING(), 'LaCroix Sparkling Water Passionfruit 12oz Can', 'Beverages', 'Water', 'LaCroix', '073360831140', 1.29 UNION ALL
SELECT UUID_STRING(), 'PRIME Energy Drink Tropical Punch 12oz Can', 'Beverages', 'Energy Drinks', 'PRIME', '850003550541', 2.99 UNION ALL
SELECT UUID_STRING(), 'PRIME Energy Drink Blue Raspberry 12oz Can', 'Beverages', 'Energy Drinks', 'PRIME', '850003550558', 2.99 UNION ALL
SELECT UUID_STRING(), 'Celsius Essentials Sparkling Cherry Limeade 16oz Can', 'Beverages', 'Energy Drinks', 'Celsius', '889392000160', 3.49 UNION ALL
SELECT UUID_STRING(), 'Celsius Essentials Sparkling Blue Crush 16oz Can', 'Beverages', 'Energy Drinks', 'Celsius', '889392000177', 3.49 UNION ALL
SELECT UUID_STRING(), 'Alani Nu Energy Drink Mimosa 12oz Can', 'Beverages', 'Energy Drinks', 'Alani Nu', '850030592041', 2.99 UNION ALL
SELECT UUID_STRING(), 'Alani Nu Energy Drink Tropsicle 12oz Can', 'Beverages', 'Energy Drinks', 'Alani Nu', '850030592058', 2.99 UNION ALL
SELECT UUID_STRING(), 'Monster Rehab Peach Tea 15.5oz Can', 'Beverages', 'Energy Drinks', 'Monster', '070847811770', 3.49 UNION ALL
SELECT UUID_STRING(), 'Monster Rehab Strawberry Lemonade 15.5oz Can', 'Beverages', 'Energy Drinks', 'Monster', '070847811787', 3.49 UNION ALL
SELECT UUID_STRING(), 'Kevita Master Brew Ginger Kombucha 15.2oz Can', 'Beverages', 'Kombucha', 'Kevita', '853311003014', 3.49 UNION ALL
SELECT UUID_STRING(), 'Remedy Kombucha Ginger Lemon 11oz Can', 'Beverages', 'Kombucha', 'Remedy', '860002500015', 3.29 UNION ALL
SELECT UUID_STRING(), 'Starbucks Cold Brew Black Unsweetened 11oz Bottle', 'Beverages', 'Coffee', 'Starbucks', '012000161520', 3.99 UNION ALL
SELECT UUID_STRING(), 'Starbucks Nitro Cold Brew Vanilla Sweet Cream 9.6oz Can', 'Beverages', 'Coffee', 'Starbucks', '012000161537', 4.49 UNION ALL
SELECT UUID_STRING(), 'Dunkin Donuts Iced Coffee Caramel 13.7oz Bottle', 'Beverages', 'Coffee', 'Dunkin', '049000072174', 3.49 UNION ALL
SELECT UUID_STRING(), 'Super Coffee Vanilla Bean 12oz Bottle', 'Beverages', 'Coffee', 'Super Coffee', '860002200013', 3.99 UNION ALL
SELECT UUID_STRING(), 'Oatly Barista Oat Latte Mocha 10oz Carton', 'Beverages', 'Dairy Drinks', 'Oatly', '757063643043', 3.49 UNION ALL
SELECT UUID_STRING(), 'Chobani Coffee Creamer Sweet Cream 24oz', 'Beverages', 'Dairy Drinks', 'Chobani', '818290011077', 4.99 UNION ALL
SELECT UUID_STRING(), 'Yoo-hoo Strawberry Drink 6.5oz Box', 'Beverages', 'Dairy Drinks', 'Yoo-hoo', '072490000115', 1.29;
