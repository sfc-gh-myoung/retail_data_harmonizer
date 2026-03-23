-- ============================================================================
-- Retail Data Harmonization Demo
-- Script: sql/setup/05_seed_data/05c_standard_items_condiments.sql
-- Purpose: Seed STANDARD_ITEMS table with condiments (~80 items)
-- Depends on: 02_schema_and_tables.sql
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- STANDARD_ITEMS: Master Item List - CONDIMENTS (~80 items)
-- ============================================================================


INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Ketchup and Mustard
SELECT UUID_STRING(), 'Heinz Tomato Ketchup 14oz Squeeze Bottle', 'Condiments', 'Ketchup', 'Heinz', '013000001205', 4.49 UNION ALL
SELECT UUID_STRING(), 'Heinz Tomato Ketchup 20oz Squeeze Bottle', 'Condiments', 'Ketchup', 'Heinz', '013000001212', 5.99 UNION ALL
SELECT UUID_STRING(), 'Heinz Tomato Ketchup Packet 9g', 'Condiments', 'Ketchup', 'Heinz', '013000001229', 0.15 UNION ALL
SELECT UUID_STRING(), 'Heinz Simply Ketchup 20oz Squeeze Bottle', 'Condiments', 'Ketchup', 'Heinz', '013000001236', 6.49 UNION ALL
SELECT UUID_STRING(), 'Hunts Tomato Ketchup 14oz Squeeze Bottle', 'Condiments', 'Ketchup', 'Hunts', '027000379103', 3.99 UNION ALL
SELECT UUID_STRING(), 'Frenchs Classic Yellow Mustard 14oz Squeeze Bottle', 'Condiments', 'Mustard', 'Frenchs', '041500008103', 3.49 UNION ALL
SELECT UUID_STRING(), 'Frenchs Classic Yellow Mustard 20oz Squeeze Bottle', 'Condiments', 'Mustard', 'Frenchs', '041500008110', 4.49 UNION ALL
SELECT UUID_STRING(), 'Frenchs Classic Yellow Mustard Packet 5.5g', 'Condiments', 'Mustard', 'Frenchs', '041500008127', 0.10 UNION ALL
SELECT UUID_STRING(), 'Guldens Spicy Brown Mustard 12oz Squeeze Bottle', 'Condiments', 'Mustard', 'Guldens', '041500102104', 3.99 UNION ALL
SELECT UUID_STRING(), 'Grey Poupon Dijon Mustard 8oz Squeeze Bottle', 'Condiments', 'Mustard', 'Grey Poupon', '054100002108', 4.99 UNION ALL
-- Mayo and Dressings
SELECT UUID_STRING(), 'Hellmanns Real Mayonnaise 15oz Squeeze Bottle', 'Condiments', 'Mayonnaise', 'Hellmanns', '048001213623', 5.99 UNION ALL
SELECT UUID_STRING(), 'Hellmanns Real Mayonnaise 30oz Squeeze Bottle', 'Condiments', 'Mayonnaise', 'Hellmanns', '048001213630', 7.99 UNION ALL
SELECT UUID_STRING(), 'Hellmanns Light Mayonnaise 15oz Squeeze Bottle', 'Condiments', 'Mayonnaise', 'Hellmanns', '048001213647', 5.99 UNION ALL
SELECT UUID_STRING(), 'Hellmanns Real Mayonnaise Packet 12g', 'Condiments', 'Mayonnaise', 'Hellmanns', '048001213654', 0.15 UNION ALL
SELECT UUID_STRING(), 'Duke Mayonnaise Real 11.5oz Jar', 'Condiments', 'Mayonnaise', 'Dukes', '053800101011', 4.99 UNION ALL
SELECT UUID_STRING(), 'Kraft Ranch Dressing 8oz Bottle', 'Condiments', 'Dressing', 'Kraft', '021000012107', 3.99 UNION ALL
SELECT UUID_STRING(), 'Hidden Valley Ranch Dressing 8oz Bottle', 'Condiments', 'Dressing', 'Hidden Valley', '071100400108', 4.49 UNION ALL
SELECT UUID_STRING(), 'Hidden Valley Ranch Dressing Packet 1oz', 'Condiments', 'Dressing', 'Hidden Valley', '071100400115', 0.50 UNION ALL
SELECT UUID_STRING(), 'Ken Steak House Italian Dressing 8oz Bottle', 'Condiments', 'Dressing', 'Kens', '041335080108', 3.99 UNION ALL
SELECT UUID_STRING(), 'Newman Own Caesar Dressing 8oz Bottle', 'Condiments', 'Dressing', 'Newmans Own', '020662000108', 4.49;

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Hot Sauce and Sauces
SELECT UUID_STRING(), 'Tabasco Original Red Pepper Sauce 2oz Bottle', 'Condiments', 'Hot Sauce', 'Tabasco', '011210000513', 3.99 UNION ALL
SELECT UUID_STRING(), 'Tabasco Original Red Pepper Sauce 5oz Bottle', 'Condiments', 'Hot Sauce', 'Tabasco', '011210000520', 5.49 UNION ALL
SELECT UUID_STRING(), 'Frank''s RedHot Original Cayenne Pepper Sauce 5oz Bottle', 'Condiments', 'Hot Sauce', 'Frank''s RedHot', '041500000107', 4.49 UNION ALL
SELECT UUID_STRING(), 'Frank''s RedHot Original Cayenne Pepper Sauce 12oz Bottle', 'Condiments', 'Hot Sauce', 'Frank''s RedHot', '041500000114', 5.99 UNION ALL
SELECT UUID_STRING(), 'Cholula Original Hot Sauce 5oz Bottle', 'Condiments', 'Hot Sauce', 'Cholula', '049733500107', 4.99 UNION ALL
SELECT UUID_STRING(), 'Sriracha Hot Chili Sauce 9oz Bottle', 'Condiments', 'Hot Sauce', 'Huy Fong', '024463061095', 4.99 UNION ALL
SELECT UUID_STRING(), 'Sriracha Hot Chili Sauce 17oz Bottle', 'Condiments', 'Hot Sauce', 'Huy Fong', '024463061101', 6.99 UNION ALL
SELECT UUID_STRING(), 'Sweet Baby Rays BBQ Sauce Original 18oz Bottle', 'Condiments', 'BBQ Sauce', 'Sweet Baby Rays', '013409201018', 3.99 UNION ALL
SELECT UUID_STRING(), 'Heinz BBQ Sauce Original 18oz Bottle', 'Condiments', 'BBQ Sauce', 'Heinz', '013000001243', 4.49 UNION ALL
SELECT UUID_STRING(), 'Kraft Original BBQ Sauce 18oz Bottle', 'Condiments', 'BBQ Sauce', 'Kraft', '021000012114', 3.49 UNION ALL
SELECT UUID_STRING(), 'A1 Original Steak Sauce 10oz Bottle', 'Condiments', 'Steak Sauce', 'A1', '054100002115', 5.99 UNION ALL
SELECT UUID_STRING(), 'Heinz 57 Sauce 10oz Bottle', 'Condiments', 'Steak Sauce', 'Heinz', '013000001250', 4.99 UNION ALL
-- Soy and Asian Sauces
SELECT UUID_STRING(), 'Kikkoman Soy Sauce 10oz Bottle', 'Condiments', 'Soy Sauce', 'Kikkoman', '041390000119', 3.99 UNION ALL
SELECT UUID_STRING(), 'Kikkoman Soy Sauce Packet 6ml', 'Condiments', 'Soy Sauce', 'Kikkoman', '041390000126', 0.10 UNION ALL
SELECT UUID_STRING(), 'La Choy Soy Sauce 10oz Bottle', 'Condiments', 'Soy Sauce', 'La Choy', '044300061101', 2.99 UNION ALL
-- Relish and Pickles
SELECT UUID_STRING(), 'Heinz Sweet Relish 10oz Squeeze Bottle', 'Condiments', 'Relish', 'Heinz', '013000001267', 3.99 UNION ALL
SELECT UUID_STRING(), 'Vlasic Dill Pickle Spears 24oz Jar', 'Condiments', 'Pickles', 'Vlasic', '054100003108', 4.49 UNION ALL
SELECT UUID_STRING(), 'Claussen Kosher Dill Pickle Halves 32oz Jar', 'Condiments', 'Pickles', 'Claussen', '021000017102', 5.99 UNION ALL
-- Salsa and Dips
SELECT UUID_STRING(), 'Tostitos Medium Chunky Salsa 15.5oz Jar', 'Condiments', 'Salsa', 'Tostitos', '028400060134', 5.49 UNION ALL
SELECT UUID_STRING(), 'Pace Medium Chunky Salsa 16oz Jar', 'Condiments', 'Salsa', 'Pace', '041565000108', 4.49 UNION ALL
SELECT UUID_STRING(), 'Tostitos Queso Blanco Dip 15oz Jar', 'Condiments', 'Dip', 'Tostitos', '028400060141', 5.99 UNION ALL
SELECT UUID_STRING(), 'Sabra Classic Hummus 10oz Container', 'Condiments', 'Dip', 'Sabra', '040822011018', 5.49 UNION ALL
SELECT UUID_STRING(), 'Sabra Roasted Red Pepper Hummus 10oz Container', 'Condiments', 'Dip', 'Sabra', '040822011025', 5.49 UNION ALL
-- Misc Condiments
SELECT UUID_STRING(), 'Heinz Cocktail Sauce 12oz Bottle', 'Condiments', 'Seafood Sauce', 'Heinz', '013000001274', 4.49 UNION ALL
SELECT UUID_STRING(), 'Heinz Tartar Sauce 12oz Squeeze Bottle', 'Condiments', 'Seafood Sauce', 'Heinz', '013000001281', 4.49 UNION ALL
SELECT UUID_STRING(), 'Kraft Miracle Whip 15oz Squeeze Bottle', 'Condiments', 'Mayonnaise', 'Kraft', '021000012121', 5.49 UNION ALL
SELECT UUID_STRING(), 'Kraft Thousand Island Dressing 8oz Bottle', 'Condiments', 'Dressing', 'Kraft', '021000012138', 3.99 UNION ALL
SELECT UUID_STRING(), 'Wishbone Italian Dressing 8oz Bottle', 'Condiments', 'Dressing', 'Wishbone', '041000401010', 3.49 UNION ALL
SELECT UUID_STRING(), 'Marzetti Ranch Veggie Dip 14oz Tub', 'Condiments', 'Dip', 'Marzetti', '071828100102', 4.99 UNION ALL
SELECT UUID_STRING(), 'Jif Creamy Peanut Butter 16oz Jar', 'Condiments', 'Spreads', 'Jif', '051500024058', 4.99 UNION ALL
SELECT UUID_STRING(), 'Skippy Creamy Peanut Butter 16.3oz Jar', 'Condiments', 'Spreads', 'Skippy', '037600105002', 4.99 UNION ALL
SELECT UUID_STRING(), 'Smuckers Grape Jelly 12oz Squeeze Bottle', 'Condiments', 'Spreads', 'Smuckers', '051500028018', 3.99 UNION ALL
SELECT UUID_STRING(), 'Nutella Hazelnut Spread 13oz Jar', 'Condiments', 'Spreads', 'Nutella', '009800895007', 5.99 UNION ALL
SELECT UUID_STRING(), 'Maple Syrup Log Cabin Original 12oz Bottle', 'Condiments', 'Syrup', 'Log Cabin', '044300061125', 4.99 UNION ALL
SELECT UUID_STRING(), 'Mrs Butterworth Original Syrup 12oz Bottle', 'Condiments', 'Syrup', 'Mrs Butterworth', '026200341019', 4.99;

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Specialty Hot Sauces
SELECT UUID_STRING(), 'Cholula Chipotle Hot Sauce 5oz Bottle', 'Condiments', 'Hot Sauce', 'Cholula', '049733500114', 4.99 UNION ALL
SELECT UUID_STRING(), 'Cholula Green Pepper Hot Sauce 5oz Bottle', 'Condiments', 'Hot Sauce', 'Cholula', '049733500121', 4.99 UNION ALL
SELECT UUID_STRING(), 'Valentina Salsa Picante Hot Sauce 12.5oz Bottle', 'Condiments', 'Hot Sauce', 'Valentina', '074600000113', 2.49 UNION ALL
SELECT UUID_STRING(), 'Tapatio Hot Sauce 5oz Bottle', 'Condiments', 'Hot Sauce', 'Tapatio', '079345000106', 2.99 UNION ALL
SELECT UUID_STRING(), 'Crystal Hot Sauce Original 6oz Bottle', 'Condiments', 'Hot Sauce', 'Crystal', '073721000128', 2.99 UNION ALL
SELECT UUID_STRING(), 'Yellowbird Habanero Hot Sauce 2.2oz Bottle', 'Condiments', 'Hot Sauce', 'Yellowbird', '860002660011', 4.99 UNION ALL
SELECT UUID_STRING(), 'Secret Aardvark Habanero Hot Sauce 8oz Bottle', 'Condiments', 'Hot Sauce', 'Secret Aardvark', '859800004011', 7.99 UNION ALL
-- Asian Sauces
SELECT UUID_STRING(), 'Sriracha Mayo Sauce 8oz Squeeze Bottle', 'Condiments', 'Asian Sauce', 'Lee Kum Kee', '078895120011', 4.49 UNION ALL
SELECT UUID_STRING(), 'Ponzu Citrus Seasoned Soy Sauce 10oz Bottle', 'Condiments', 'Asian Sauce', 'Kikkoman', '041390000133', 4.49 UNION ALL
SELECT UUID_STRING(), 'Gochujang Korean Chili Paste 7.5oz Tub', 'Condiments', 'Asian Sauce', 'Chung Jung One', '880101301014', 5.99 UNION ALL
SELECT UUID_STRING(), 'Hoisin Sauce 8oz Bottle', 'Condiments', 'Asian Sauce', 'Lee Kum Kee', '078895120028', 3.99 UNION ALL
SELECT UUID_STRING(), 'Teriyaki Sauce 10oz Bottle', 'Condiments', 'Asian Sauce', 'Kikkoman', '041390000140', 3.99 UNION ALL
SELECT UUID_STRING(), 'Sweet Chili Sauce 10oz Bottle', 'Condiments', 'Asian Sauce', 'Mae Ploy', '044738200011', 3.99 UNION ALL
SELECT UUID_STRING(), 'Sambal Oelek Chili Paste 8oz Jar', 'Condiments', 'Asian Sauce', 'Huy Fong', '024463061118', 4.49 UNION ALL
SELECT UUID_STRING(), 'Sesame Oil Toasted 5oz Bottle', 'Condiments', 'Asian Sauce', 'Kadoya', '011152250014', 4.99 UNION ALL
SELECT UUID_STRING(), 'Rice Vinegar Seasoned 12oz Bottle', 'Condiments', 'Asian Sauce', 'Marukan', '070641000117', 3.49 UNION ALL
-- Gourmet Mustards and Aiolis
SELECT UUID_STRING(), 'Grey Poupon Country Dijon Mustard 8oz Jar', 'Condiments', 'Mustard', 'Grey Poupon', '054100002115', 5.49 UNION ALL
SELECT UUID_STRING(), 'Inglehoffer Stone Ground Mustard 4oz Squeeze', 'Condiments', 'Mustard', 'Inglehoffer', '071828510018', 3.49 UNION ALL
SELECT UUID_STRING(), 'Sir Kensington Spicy Brown Mustard 9oz Squeeze', 'Condiments', 'Mustard', 'Sir Kensington', '850551005019', 4.99 UNION ALL
SELECT UUID_STRING(), 'Stonewall Kitchen Garlic Aioli 10oz Jar', 'Condiments', 'Mayonnaise', 'Stonewall Kitchen', '711381006016', 7.99 UNION ALL
SELECT UUID_STRING(), 'Sir Kensington Chipotle Mayo 10oz Squeeze', 'Condiments', 'Mayonnaise', 'Sir Kensington', '850551005026', 5.99 UNION ALL
SELECT UUID_STRING(), 'Kewpie Japanese Mayo 12oz Squeeze Bottle', 'Condiments', 'Mayonnaise', 'Kewpie', '011152350018', 5.99 UNION ALL
SELECT UUID_STRING(), 'Primal Kitchen Avocado Oil Mayo 12oz Jar', 'Condiments', 'Mayonnaise', 'Primal Kitchen', '855232007019', 9.99 UNION ALL
-- Additional Dressings
SELECT UUID_STRING(), 'Tessemae Organic Ranch Dressing 10oz Bottle', 'Condiments', 'Dressing', 'Tessemae', '855235005012', 6.49 UNION ALL
SELECT UUID_STRING(), 'Primal Kitchen Caesar Dressing 8oz Bottle', 'Condiments', 'Dressing', 'Primal Kitchen', '855232007026', 7.49;

