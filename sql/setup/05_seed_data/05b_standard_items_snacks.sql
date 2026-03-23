-- ============================================================================
-- Retail Data Harmonization Demo
-- Script: sql/setup/05_seed_data/05b_standard_items_snacks.sql
-- Purpose: Seed STANDARD_ITEMS table with snacks (~177 items)
-- Depends on: 02_schema_and_tables.sql
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- STANDARD_ITEMS: Master Item List - SNACKS (~151 items)
-- ============================================================================

-- SNACKS (~150 items)
-- Chips, candy, nuts, crackers, cookies, bars, and other grab-and-go snack items
-- covering sweet and savory options across multiple price points
-- ----------------------------------------------------------------------------

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Chips
SELECT UUID_STRING(), 'Lays Classic Potato Chips 1oz Bag', 'Snacks', 'Chips', 'Lays', '028400047708', 1.99 UNION ALL
SELECT UUID_STRING(), 'Lays Classic Potato Chips 2.625oz Bag', 'Snacks', 'Chips', 'Lays', '028400047715', 2.49 UNION ALL
SELECT UUID_STRING(), 'Lays Barbecue Potato Chips 1oz Bag', 'Snacks', 'Chips', 'Lays', '028400047722', 1.99 UNION ALL
SELECT UUID_STRING(), 'Lays Sour Cream & Onion Potato Chips 1oz Bag', 'Snacks', 'Chips', 'Lays', '028400047739', 1.99 UNION ALL
SELECT UUID_STRING(), 'Lays Salt & Vinegar Potato Chips 1oz Bag', 'Snacks', 'Chips', 'Lays', '028400047746', 1.99 UNION ALL
SELECT UUID_STRING(), 'Lays Cheddar & Sour Cream Potato Chips 1oz Bag', 'Snacks', 'Chips', 'Lays', '028400047753', 1.99 UNION ALL
SELECT UUID_STRING(), 'Doritos Nacho Cheese 1oz Bag', 'Snacks', 'Chips', 'Doritos', '028400090810', 1.99 UNION ALL
SELECT UUID_STRING(), 'Doritos Nacho Cheese 2.75oz Bag', 'Snacks', 'Chips', 'Doritos', '028400090827', 2.49 UNION ALL
SELECT UUID_STRING(), 'Doritos Cool Ranch 1oz Bag', 'Snacks', 'Chips', 'Doritos', '028400090834', 1.99 UNION ALL
SELECT UUID_STRING(), 'Doritos Spicy Sweet Chili 1oz Bag', 'Snacks', 'Chips', 'Doritos', '028400090841', 1.99 UNION ALL
SELECT UUID_STRING(), 'Doritos Flamin Hot Nacho 1oz Bag', 'Snacks', 'Chips', 'Doritos', '028400090858', 1.99 UNION ALL
SELECT UUID_STRING(), 'Cheetos Crunchy 1oz Bag', 'Snacks', 'Chips', 'Cheetos', '028400083614', 1.99 UNION ALL
SELECT UUID_STRING(), 'Cheetos Crunchy 2oz Bag', 'Snacks', 'Chips', 'Cheetos', '028400083621', 2.29 UNION ALL
SELECT UUID_STRING(), 'Cheetos Flamin Hot Crunchy 1oz Bag', 'Snacks', 'Chips', 'Cheetos', '028400083638', 1.99 UNION ALL
SELECT UUID_STRING(), 'Cheetos Puffs 1oz Bag', 'Snacks', 'Chips', 'Cheetos', '028400083645', 1.99 UNION ALL
SELECT UUID_STRING(), 'Fritos Original Corn Chips 1oz Bag', 'Snacks', 'Chips', 'Fritos', '028400060127', 1.99 UNION ALL
SELECT UUID_STRING(), 'Ruffles Original Potato Chips 1oz Bag', 'Snacks', 'Chips', 'Ruffles', '028400044608', 1.99 UNION ALL
SELECT UUID_STRING(), 'Ruffles Cheddar & Sour Cream 1oz Bag', 'Snacks', 'Chips', 'Ruffles', '028400044615', 1.99 UNION ALL
SELECT UUID_STRING(), 'Tostitos Scoops Tortilla Chips 1oz Bag', 'Snacks', 'Chips', 'Tostitos', '028400087612', 1.99 UNION ALL
SELECT UUID_STRING(), 'SunChips Harvest Cheddar 1oz Bag', 'Snacks', 'Chips', 'SunChips', '028400050128', 1.99 UNION ALL
SELECT UUID_STRING(), 'Pringles Original 1.3oz Can', 'Snacks', 'Chips', 'Pringles', '038000138416', 1.99 UNION ALL
SELECT UUID_STRING(), 'Pringles Sour Cream & Onion 1.3oz Can', 'Snacks', 'Chips', 'Pringles', '038000138423', 1.99 UNION ALL
SELECT UUID_STRING(), 'Pringles Cheddar Cheese 1.3oz Can', 'Snacks', 'Chips', 'Pringles', '038000138430', 1.99 UNION ALL
SELECT UUID_STRING(), 'Kettle Brand Sea Salt Potato Chips 1.5oz Bag', 'Snacks', 'Chips', 'Kettle Brand', '084114110015', 2.49 UNION ALL
SELECT UUID_STRING(), 'Cape Cod Original Kettle Cooked Chips 1.5oz Bag', 'Snacks', 'Chips', 'Cape Cod', '020712100104', 2.49;

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Candy and Chocolate
SELECT UUID_STRING(), 'Snickers Original Bar 1.86oz', 'Snacks', 'Candy', 'Snickers', '040000001027', 2.19 UNION ALL
SELECT UUID_STRING(), 'Snickers Almond Bar 1.76oz', 'Snacks', 'Candy', 'Snickers', '040000001034', 2.19 UNION ALL
SELECT UUID_STRING(), 'M&Ms Milk Chocolate 1.69oz Bag', 'Snacks', 'Candy', 'M&Ms', '040000424413', 2.19 UNION ALL
SELECT UUID_STRING(), 'M&Ms Peanut 1.74oz Bag', 'Snacks', 'Candy', 'M&Ms', '040000424420', 2.19 UNION ALL
SELECT UUID_STRING(), 'Reeses Peanut Butter Cups 1.5oz Pack', 'Snacks', 'Candy', 'Reeses', '034000006304', 2.19 UNION ALL
SELECT UUID_STRING(), 'Reeses Pieces 1.53oz Bag', 'Snacks', 'Candy', 'Reeses', '034000006311', 2.19 UNION ALL
SELECT UUID_STRING(), 'Kit Kat Wafer Bar 1.5oz', 'Snacks', 'Candy', 'Kit Kat', '034000002405', 2.19 UNION ALL
SELECT UUID_STRING(), 'Twix Caramel Cookie Bar 1.79oz', 'Snacks', 'Candy', 'Twix', '040000001041', 2.19 UNION ALL
SELECT UUID_STRING(), 'Milky Way Bar 1.84oz', 'Snacks', 'Candy', 'Milky Way', '040000001058', 2.19 UNION ALL
SELECT UUID_STRING(), '3 Musketeers Bar 1.92oz', 'Snacks', 'Candy', '3 Musketeers', '040000001065', 2.19 UNION ALL
SELECT UUID_STRING(), 'Butterfinger Bar 1.9oz', 'Snacks', 'Candy', 'Butterfinger', '028000101008', 2.19 UNION ALL
SELECT UUID_STRING(), 'Baby Ruth Bar 1.9oz', 'Snacks', 'Candy', 'Baby Ruth', '028000104009', 2.19 UNION ALL
SELECT UUID_STRING(), 'Hersheys Milk Chocolate Bar 1.55oz', 'Snacks', 'Candy', 'Hersheys', '034000002412', 2.19 UNION ALL
SELECT UUID_STRING(), 'Hersheys Cookies n Creme Bar 1.55oz', 'Snacks', 'Candy', 'Hersheys', '034000002429', 2.19 UNION ALL
SELECT UUID_STRING(), 'Skittles Original 2.17oz Bag', 'Snacks', 'Candy', 'Skittles', '022000009016', 2.19 UNION ALL
SELECT UUID_STRING(), 'Starburst Original 2.07oz Pack', 'Snacks', 'Candy', 'Starburst', '022000009023', 2.19 UNION ALL
SELECT UUID_STRING(), 'Sour Patch Kids 2oz Bag', 'Snacks', 'Candy', 'Sour Patch Kids', '070462431001', 2.49 UNION ALL
SELECT UUID_STRING(), 'Swedish Fish 2oz Bag', 'Snacks', 'Candy', 'Swedish Fish', '070462431018', 2.49 UNION ALL
SELECT UUID_STRING(), 'Haribo Goldbears 2oz Bag', 'Snacks', 'Candy', 'Haribo', '042238300019', 2.49 UNION ALL
-- Nuts and Trail Mix
SELECT UUID_STRING(), 'Planters Salted Peanuts 1oz Bag', 'Snacks', 'Nuts', 'Planters', '029000017108', 1.49 UNION ALL
SELECT UUID_STRING(), 'Planters Honey Roasted Peanuts 1oz Bag', 'Snacks', 'Nuts', 'Planters', '029000017115', 1.49 UNION ALL
SELECT UUID_STRING(), 'Planters Cashews Halves & Pieces 1.5oz Bag', 'Snacks', 'Nuts', 'Planters', '029000017122', 2.49 UNION ALL
SELECT UUID_STRING(), 'Planters Trail Mix Nuts & Chocolate 2oz Bag', 'Snacks', 'Nuts', 'Planters', '029000017139', 2.49 UNION ALL
SELECT UUID_STRING(), 'Blue Diamond Almonds Smokehouse 1.5oz Bag', 'Snacks', 'Nuts', 'Blue Diamond', '041570054116', 2.49 UNION ALL
SELECT UUID_STRING(), 'Blue Diamond Almonds Whole Natural 1.5oz Bag', 'Snacks', 'Nuts', 'Blue Diamond', '041570054123', 2.49;

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Crackers and Cookies
SELECT UUID_STRING(), 'Goldfish Cheddar Crackers 1.5oz Bag', 'Snacks', 'Crackers', 'Goldfish', '014100088615', 1.79 UNION ALL
SELECT UUID_STRING(), 'Cheez-It Original Crackers 1.5oz Bag', 'Snacks', 'Crackers', 'Cheez-It', '024100789016', 1.79 UNION ALL
SELECT UUID_STRING(), 'Cheez-It White Cheddar 1.5oz Bag', 'Snacks', 'Crackers', 'Cheez-It', '024100789023', 1.79 UNION ALL
SELECT UUID_STRING(), 'Ritz Crackers Original 1.38oz Sleeve', 'Snacks', 'Crackers', 'Ritz', '044000032135', 1.79 UNION ALL
SELECT UUID_STRING(), 'Wheat Thins Original 1.75oz Bag', 'Snacks', 'Crackers', 'Wheat Thins', '044000032142', 1.99 UNION ALL
SELECT UUID_STRING(), 'Oreo Cookies Original 2.4oz Pack', 'Snacks', 'Cookies', 'Oreo', '044000032159', 2.29 UNION ALL
SELECT UUID_STRING(), 'Chips Ahoy Chocolate Chip Cookies 2oz Pack', 'Snacks', 'Cookies', 'Chips Ahoy', '044000032166', 2.29 UNION ALL
SELECT UUID_STRING(), 'Nutter Butter Peanut Butter Cookies 1.9oz Pack', 'Snacks', 'Cookies', 'Nutter Butter', '044000032173', 2.29 UNION ALL
SELECT UUID_STRING(), 'Famous Amos Chocolate Chip Cookies 2oz Bag', 'Snacks', 'Cookies', 'Famous Amos', '030100030101', 1.99 UNION ALL
SELECT UUID_STRING(), 'Mrs Fields Chocolate Chip Cookie 2.1oz', 'Snacks', 'Cookies', 'Mrs Fields', '048154101011', 2.99 UNION ALL
-- Bars and Healthy Snacks
SELECT UUID_STRING(), 'KIND Dark Chocolate Nuts & Sea Salt Bar 1.4oz', 'Snacks', 'Bars', 'KIND', '602652170010', 2.49 UNION ALL
SELECT UUID_STRING(), 'KIND Peanut Butter Dark Chocolate Bar 1.4oz', 'Snacks', 'Bars', 'KIND', '602652170027', 2.49 UNION ALL
SELECT UUID_STRING(), 'KIND Caramel Almond and Sea Salt Bar 1.4oz', 'Snacks', 'Bars', 'KIND', '602652170034', 2.49 UNION ALL
SELECT UUID_STRING(), 'Clif Bar Chocolate Chip 2.4oz', 'Snacks', 'Bars', 'Clif Bar', '722252100108', 2.49 UNION ALL
SELECT UUID_STRING(), 'Clif Bar Crunchy Peanut Butter 2.4oz', 'Snacks', 'Bars', 'Clif Bar', '722252100115', 2.49 UNION ALL
SELECT UUID_STRING(), 'RXBAR Chocolate Sea Salt 1.83oz', 'Snacks', 'Bars', 'RXBAR', '857777004010', 2.99 UNION ALL
SELECT UUID_STRING(), 'Nature Valley Crunchy Oats n Honey Bar 1.49oz', 'Snacks', 'Bars', 'Nature Valley', '016000440012', 1.79 UNION ALL
SELECT UUID_STRING(), 'Nature Valley Sweet & Salty Nut Peanut Bar 1.2oz', 'Snacks', 'Bars', 'Nature Valley', '016000440029', 1.79 UNION ALL
SELECT UUID_STRING(), 'Larabar Apple Pie 1.6oz', 'Snacks', 'Bars', 'Larabar', '021908453019', 2.29 UNION ALL
SELECT UUID_STRING(), 'Quest Protein Bar Chocolate Chip Cookie Dough 2.12oz', 'Snacks', 'Bars', 'Quest', '888849000104', 3.29 UNION ALL
-- Other Snacks
SELECT UUID_STRING(), 'Chex Mix Traditional 1.75oz Bag', 'Snacks', 'Snack Mix', 'Chex Mix', '016000159105', 1.99 UNION ALL
SELECT UUID_STRING(), 'Gardetto Special Request Roasted Garlic Rye Chips 1.75oz', 'Snacks', 'Snack Mix', 'Gardettos', '016000174108', 1.99 UNION ALL
SELECT UUID_STRING(), 'PopCorners Sea Salt 1oz Bag', 'Snacks', 'Popcorn', 'PopCorners', '810607020017', 1.99 UNION ALL
SELECT UUID_STRING(), 'Skinny Pop Original Popcorn 1oz Bag', 'Snacks', 'Popcorn', 'SkinnyPop', '816925020010', 1.99 UNION ALL
SELECT UUID_STRING(), 'Smartfood White Cheddar Popcorn 1oz Bag', 'Snacks', 'Popcorn', 'Smartfood', '028400025010', 1.99 UNION ALL
SELECT UUID_STRING(), 'Beef Jerky Original Jack Links 1.25oz Bag', 'Snacks', 'Jerky', 'Jack Links', '017082877116', 3.99 UNION ALL
SELECT UUID_STRING(), 'Slim Jim Original Giant 0.97oz Stick', 'Snacks', 'Jerky', 'Slim Jim', '026200441016', 1.99 UNION ALL
SELECT UUID_STRING(), 'Takis Fuego Rolled Tortilla Chips 1oz Bag', 'Snacks', 'Chips', 'Takis', '757528008105', 1.99 UNION ALL
SELECT UUID_STRING(), 'Hot Cheetos Limon 1oz Bag', 'Snacks', 'Chips', 'Cheetos', '028400083652', 1.99 UNION ALL
SELECT UUID_STRING(), 'Munchies Cheese Fix Snack Mix 1.75oz', 'Snacks', 'Snack Mix', 'Munchies', '028400105408', 1.99;

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- International Snacks
SELECT UUID_STRING(), 'Pocky Chocolate Cream Sticks 1.41oz Box', 'Snacks', 'Candy', 'Pocky', '073141105019', 2.49 UNION ALL
SELECT UUID_STRING(), 'Pocky Strawberry Cream Sticks 1.41oz Box', 'Snacks', 'Candy', 'Pocky', '073141105026', 2.49 UNION ALL
SELECT UUID_STRING(), 'Hi-Chew Strawberry 1.76oz Stick', 'Snacks', 'Candy', 'Hi-Chew', '073141125011', 2.29 UNION ALL
SELECT UUID_STRING(), 'Hi-Chew Mango 1.76oz Stick', 'Snacks', 'Candy', 'Hi-Chew', '073141125028', 2.29 UNION ALL
SELECT UUID_STRING(), 'Hi-Chew Green Apple 1.76oz Stick', 'Snacks', 'Candy', 'Hi-Chew', '073141125035', 2.29 UNION ALL
SELECT UUID_STRING(), 'Kasugai Lychee Gummy Candy 1.76oz Bag', 'Snacks', 'Candy', 'Kasugai', '011152080017', 2.99 UNION ALL
SELECT UUID_STRING(), 'Kasugai Mango Gummy Candy 1.76oz Bag', 'Snacks', 'Candy', 'Kasugai', '011152080024', 2.99 UNION ALL
SELECT UUID_STRING(), 'Yan Yan Chocolate Creme Dip Sticks 2oz', 'Snacks', 'Candy', 'Meiji', '073141100014', 2.49 UNION ALL
SELECT UUID_STRING(), 'Botan Rice Candy 0.75oz Box', 'Snacks', 'Candy', 'Botan', '011600101018', 1.49 UNION ALL
SELECT UUID_STRING(), 'Shrimp Chips Original 1oz Bag', 'Snacks', 'Chips', 'Calbee', '075050250015', 2.49 UNION ALL
-- More Candy Varieties
SELECT UUID_STRING(), 'Sour Patch Kids Watermelon 2oz Bag', 'Snacks', 'Candy', 'Sour Patch Kids', '070462431025', 2.49 UNION ALL
SELECT UUID_STRING(), 'Trolli Sour Brite Crawlers 2oz Bag', 'Snacks', 'Candy', 'Trolli', '041420012013', 2.49 UNION ALL
SELECT UUID_STRING(), 'Nerds Gummy Clusters 3oz Bag', 'Snacks', 'Candy', 'Nerds', '079200300019', 2.99 UNION ALL
SELECT UUID_STRING(), 'Airheads Xtremes Bluest Raspberry 2oz', 'Snacks', 'Candy', 'Airheads', '073390014018', 1.99 UNION ALL
SELECT UUID_STRING(), 'Twizzlers Strawberry Twists 2.5oz Pack', 'Snacks', 'Candy', 'Twizzlers', '034000125012', 2.29 UNION ALL
SELECT UUID_STRING(), 'Mike and Ike Original Fruits 1.8oz Box', 'Snacks', 'Candy', 'Mike and Ike', '070970441011', 2.19 UNION ALL
SELECT UUID_STRING(), 'Hot Tamales Fierce Cinnamon 1.8oz Box', 'Snacks', 'Candy', 'Hot Tamales', '070970440014', 2.19 UNION ALL
SELECT UUID_STRING(), 'Jolly Rancher Hard Candy Assorted 1.9oz Bag', 'Snacks', 'Candy', 'Jolly Rancher', '034000003013', 2.19 UNION ALL
SELECT UUID_STRING(), 'Lifesavers Gummies 5 Flavors 3.22oz Bag', 'Snacks', 'Candy', 'Lifesavers', '022000012012', 2.49 UNION ALL
SELECT UUID_STRING(), 'Werther Original Caramel Hard Candies 2.65oz Bag', 'Snacks', 'Candy', 'Werthers', '072799300019', 3.49 UNION ALL
SELECT UUID_STRING(), 'PayDay Peanut Caramel Bar 1.85oz', 'Snacks', 'Candy', 'PayDay', '034000002504', 2.19 UNION ALL
SELECT UUID_STRING(), 'Almond Joy Coconut and Almond Bar 1.61oz', 'Snacks', 'Candy', 'Almond Joy', '034000004102', 2.19 UNION ALL
SELECT UUID_STRING(), 'Mounds Dark Chocolate Coconut Bar 1.75oz', 'Snacks', 'Candy', 'Mounds', '034000004201', 2.19 UNION ALL
SELECT UUID_STRING(), 'York Peppermint Pattie 1.4oz', 'Snacks', 'Candy', 'York', '034000005109', 2.19 UNION ALL
SELECT UUID_STRING(), 'Andes Creme De Menthe Thins 4.67oz Box', 'Snacks', 'Candy', 'Andes', '041186103109', 3.99 UNION ALL
-- Protein/Energy Bars
SELECT UUID_STRING(), 'RXBAR Blueberry 1.83oz', 'Snacks', 'Bars', 'RXBAR', '857777004034', 2.99 UNION ALL
SELECT UUID_STRING(), 'RXBAR Coconut Chocolate 1.83oz', 'Snacks', 'Bars', 'RXBAR', '857777004041', 2.99 UNION ALL
SELECT UUID_STRING(), 'Quest Bar Cookies and Cream 2.12oz', 'Snacks', 'Bars', 'Quest', '888849000111', 3.29 UNION ALL
SELECT UUID_STRING(), 'Quest Bar Birthday Cake 2.12oz', 'Snacks', 'Bars', 'Quest', '888849000128', 3.29 UNION ALL
SELECT UUID_STRING(), 'Perfect Bar Peanut Butter 2.5oz', 'Snacks', 'Bars', 'Perfect Bar', '854832005028', 3.49 UNION ALL
SELECT UUID_STRING(), 'Perfect Bar Dark Chocolate Almond 2.3oz', 'Snacks', 'Bars', 'Perfect Bar', '854832005035', 3.49 UNION ALL
SELECT UUID_STRING(), 'GoMacro MacroBar Peanut Butter Chocolate Chip 2.3oz', 'Snacks', 'Bars', 'GoMacro', '181945000101', 3.29 UNION ALL
SELECT UUID_STRING(), 'Built Bar Salted Caramel 1.73oz', 'Snacks', 'Bars', 'Built Bar', '860001631012', 2.99 UNION ALL
SELECT UUID_STRING(), 'Barebells Protein Bar Caramel Cashew 1.94oz', 'Snacks', 'Bars', 'Barebells', '735015220018', 3.29 UNION ALL
SELECT UUID_STRING(), 'ONE Bar Almond Bliss 2.12oz', 'Snacks', 'Bars', 'ONE', '788434101028', 2.99 UNION ALL
SELECT UUID_STRING(), 'Think Thin High Protein Bar Chunky Peanut Butter 2.1oz', 'Snacks', 'Bars', 'Think Thin', '753656710129', 2.99 UNION ALL
-- Healthier Chips
SELECT UUID_STRING(), 'Siete Grain Free Tortilla Chips Sea Salt 1oz Bag', 'Snacks', 'Chips', 'Siete', '851769007012', 2.99 UNION ALL
SELECT UUID_STRING(), 'Siete Grain Free Tortilla Chips Nacho 1oz Bag', 'Snacks', 'Chips', 'Siete', '851769007029', 2.99 UNION ALL
SELECT UUID_STRING(), 'Lesser Evil Paleo Puffs No Cheese Cheesiness 1oz Bag', 'Snacks', 'Chips', 'Lesser Evil', '855469006015', 2.49 UNION ALL
SELECT UUID_STRING(), 'Hippeas Organic Chickpea Puffs Vegan White Cheddar 1oz', 'Snacks', 'Chips', 'Hippeas', '818092021013', 2.49 UNION ALL
SELECT UUID_STRING(), 'Hippeas Organic Chickpea Puffs Bohemian BBQ 1oz', 'Snacks', 'Chips', 'Hippeas', '818092021020', 2.49 UNION ALL
SELECT UUID_STRING(), 'Beanitos Black Bean Chips Original 1.5oz Bag', 'Snacks', 'Chips', 'Beanitos', '812343010018', 2.49 UNION ALL
SELECT UUID_STRING(), 'Baked Lays Original 1.125oz Bag', 'Snacks', 'Chips', 'Lays', '028400047760', 1.99 UNION ALL
SELECT UUID_STRING(), 'Popchips Sea Salt 0.8oz Bag', 'Snacks', 'Chips', 'Popchips', '810093020010', 1.99 UNION ALL
SELECT UUID_STRING(), 'Harvest Snaps Green Pea Snack Crisps Lightly Salted 1oz', 'Snacks', 'Chips', 'Harvest Snaps', '071146003013', 2.29 UNION ALL
SELECT UUID_STRING(), 'Food Should Taste Good Multigrain Tortilla Chips 1.5oz', 'Snacks', 'Chips', 'Food Should Taste Good', '021908812014', 2.29 UNION ALL
-- Additional Crackers/Pretzels
SELECT UUID_STRING(), 'Snyder Pretzel Pieces Honey Mustard Onion 2.25oz Bag', 'Snacks', 'Crackers', 'Snyders', '077975092101', 2.29 UNION ALL
SELECT UUID_STRING(), 'Snyder Pretzel Rods 1.6oz Bag', 'Snacks', 'Crackers', 'Snyders', '077975092118', 1.99 UNION ALL
SELECT UUID_STRING(), 'Rold Gold Tiny Twists Pretzels 1oz Bag', 'Snacks', 'Crackers', 'Rold Gold', '028400015011', 1.79 UNION ALL
SELECT UUID_STRING(), 'Goldfish Pizza Crackers 1.5oz Bag', 'Snacks', 'Crackers', 'Goldfish', '014100088622', 1.79 UNION ALL
SELECT UUID_STRING(), 'Triscuit Original Crackers 2oz Pack', 'Snacks', 'Crackers', 'Triscuit', '044000032180', 2.29 UNION ALL
SELECT UUID_STRING(), 'Cheez-It Snap''d Cheddar Sour Cream 1.5oz Bag', 'Snacks', 'Crackers', 'Cheez-It', '024100789030', 2.29 UNION ALL
-- Additional Cookies
SELECT UUID_STRING(), 'Oreo Double Stuf Cookies 2.4oz Pack', 'Snacks', 'Cookies', 'Oreo', '044000032197', 2.49 UNION ALL
SELECT UUID_STRING(), 'Oreo Golden Cookies 2.4oz Pack', 'Snacks', 'Cookies', 'Oreo', '044000032203', 2.29 UNION ALL
SELECT UUID_STRING(), 'Lenny and Larrys Complete Cookie Chocolate Chip 4oz', 'Snacks', 'Cookies', 'Lenny and Larrys', '787692871018', 3.49 UNION ALL
SELECT UUID_STRING(), 'Lenny and Larrys Complete Cookie Peanut Butter 4oz', 'Snacks', 'Cookies', 'Lenny and Larrys', '787692871025', 3.49 UNION ALL
-- Additional Jerky/Meat Snacks
SELECT UUID_STRING(), 'Jack Links Beef Jerky Teriyaki 1.25oz Bag', 'Snacks', 'Jerky', 'Jack Links', '017082877123', 3.99 UNION ALL
SELECT UUID_STRING(), 'Jack Links Beef Jerky Peppered 1.25oz Bag', 'Snacks', 'Jerky', 'Jack Links', '017082877130', 3.99 UNION ALL
SELECT UUID_STRING(), 'Old Trapper Beef Jerky Old Fashioned 1.8oz Bag', 'Snacks', 'Jerky', 'Old Trapper', '079694112016', 4.49 UNION ALL
SELECT UUID_STRING(), 'Country Archer Grass Fed Beef Jerky Original 1oz Bag', 'Snacks', 'Jerky', 'Country Archer', '853016002012', 3.99 UNION ALL
SELECT UUID_STRING(), 'Slim Jim Monster Original 1.94oz Stick', 'Snacks', 'Jerky', 'Slim Jim', '026200441023', 2.49 UNION ALL
-- Additional Nuts
SELECT UUID_STRING(), 'Wonderful Pistachios Roasted Salted 1.5oz Bag', 'Snacks', 'Nuts', 'Wonderful', '014113503013', 2.99 UNION ALL
SELECT UUID_STRING(), 'Wonderful Pistachios No Shells Lightly Salted 1.25oz', 'Snacks', 'Nuts', 'Wonderful', '014113503020', 2.99 UNION ALL
SELECT UUID_STRING(), 'Sahale Snacks Glazed Mix Honey Almonds 1.5oz', 'Snacks', 'Nuts', 'Sahale', '893869001016', 2.99 UNION ALL
SELECT UUID_STRING(), 'Emerald Nuts Cashews Roasted and Salted 1.25oz', 'Snacks', 'Nuts', 'Emerald', '010300001012', 2.49 UNION ALL
-- Additional Popcorn
SELECT UUID_STRING(), 'Boom Chicka Pop Sweet and Salty Kettle Corn 1oz Bag', 'Snacks', 'Popcorn', 'Boom Chicka Pop', '849547002010', 1.99 UNION ALL
SELECT UUID_STRING(), 'Smartfood Movie Theater Butter Popcorn 1.75oz Bag', 'Snacks', 'Popcorn', 'Smartfood', '028400025027', 2.29 UNION ALL
SELECT UUID_STRING(), 'Pirate Booty Aged White Cheddar Puffs 1oz Bag', 'Snacks', 'Popcorn', 'Pirate Booty', '015665601014', 1.99 UNION ALL
-- Additional Snack Mix
SELECT UUID_STRING(), 'Chex Mix Bold Party Blend 1.75oz Bag', 'Snacks', 'Snack Mix', 'Chex Mix', '016000159112', 1.99 UNION ALL
SELECT UUID_STRING(), 'Chex Mix Cheddar 1.75oz Bag', 'Snacks', 'Snack Mix', 'Chex Mix', '016000159129', 1.99 UNION ALL
SELECT UUID_STRING(), 'Dot Pretzel Bites Original 1.5oz Bag', 'Snacks', 'Snack Mix', 'Dots Pretzels', '860002114019', 2.49;

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Additional Chips and Crisps
SELECT UUID_STRING(), 'Kettle Brand Sea Salt Potato Chips 2oz Bag', 'Snacks', 'Chips', 'Kettle Brand', '084114108012', 2.49 UNION ALL
SELECT UUID_STRING(), 'Kettle Brand Jalapeno Potato Chips 2oz Bag', 'Snacks', 'Chips', 'Kettle Brand', '084114108029', 2.49 UNION ALL
SELECT UUID_STRING(), 'Cape Cod Sea Salt Potato Chips 2oz Bag', 'Snacks', 'Chips', 'Cape Cod', '020712100013', 2.49 UNION ALL
SELECT UUID_STRING(), 'Cape Cod Sea Salt and Vinegar Chips 2oz Bag', 'Snacks', 'Chips', 'Cape Cod', '020712100020', 2.49 UNION ALL
SELECT UUID_STRING(), 'Ruffles Cheddar and Sour Cream 2.5oz Bag', 'Snacks', 'Chips', 'Ruffles', '028400055031', 2.49 UNION ALL
SELECT UUID_STRING(), 'Ruffles Flamin Hot BBQ 2.5oz Bag', 'Snacks', 'Chips', 'Ruffles', '028400055048', 2.49 UNION ALL
SELECT UUID_STRING(), 'Funyuns Flamin Hot Onion Rings 2.125oz Bag', 'Snacks', 'Chips', 'Funyuns', '028400016018', 2.29 UNION ALL
SELECT UUID_STRING(), 'Takis Fuego Hot Chili Pepper and Lime 4oz Bag', 'Snacks', 'Chips', 'Takis', '757528001012', 3.29 UNION ALL
SELECT UUID_STRING(), 'Takis Blue Heat 4oz Bag', 'Snacks', 'Chips', 'Takis', '757528001029', 3.29 UNION ALL
SELECT UUID_STRING(), 'Tostitos Hint of Lime Tortilla Chips 2oz Bag', 'Snacks', 'Chips', 'Tostitos', '028400039024', 2.29 UNION ALL
-- Additional Candy
SELECT UUID_STRING(), 'Haribo Goldbears Gummy Bears 5oz Bag', 'Snacks', 'Candy', 'Haribo', '042238302211', 2.99 UNION ALL
SELECT UUID_STRING(), 'Haribo Twin Snakes Gummy Candy 5oz Bag', 'Snacks', 'Candy', 'Haribo', '042238302228', 2.99 UNION ALL
SELECT UUID_STRING(), 'Swedish Fish Original 3.6oz Bag', 'Snacks', 'Candy', 'Swedish Fish', '070462035711', 2.49 UNION ALL
SELECT UUID_STRING(), 'Sour Punch Straws Strawberry 2oz Bag', 'Snacks', 'Candy', 'Sour Punch', '041364001012', 1.99 UNION ALL
SELECT UUID_STRING(), 'Skittles Wild Berry 2.17oz Bag', 'Snacks', 'Candy', 'Skittles', '040000001027', 1.79 UNION ALL
SELECT UUID_STRING(), 'Starburst FaveREDs 2.07oz Bag', 'Snacks', 'Candy', 'Starburst', '040000002017', 1.79 UNION ALL
SELECT UUID_STRING(), 'Reese Pieces 1.53oz Bag', 'Snacks', 'Candy', 'Reese', '034000002016', 1.99 UNION ALL
SELECT UUID_STRING(), 'Butterfinger 1.9oz Bar', 'Snacks', 'Candy', 'Butterfinger', '028000101015', 1.99 UNION ALL
-- Additional Granola and Trail Mix
SELECT UUID_STRING(), 'Nature Valley Crunchy Oats and Honey 2-Bar Pack', 'Snacks', 'Granola Bars', 'Nature Valley', '016000145016', 1.49 UNION ALL
SELECT UUID_STRING(), 'Nature Valley Protein Peanut Butter Dark Chocolate Bar', 'Snacks', 'Granola Bars', 'Nature Valley', '016000145023', 1.79 UNION ALL
SELECT UUID_STRING(), 'KIND Dark Chocolate Nuts and Sea Salt Bar', 'Snacks', 'Granola Bars', 'KIND', '602652171017', 2.29 UNION ALL
SELECT UUID_STRING(), 'Clif Bar Crunchy Peanut Butter 2.4oz Bar', 'Snacks', 'Granola Bars', 'Clif', '722252100115', 2.29 UNION ALL
SELECT UUID_STRING(), 'Clif Bar White Chocolate Macadamia 2.4oz Bar', 'Snacks', 'Granola Bars', 'Clif', '722252100122', 2.29 UNION ALL
SELECT UUID_STRING(), 'LARABAR Apple Pie 1.6oz Bar', 'Snacks', 'Granola Bars', 'LARABAR', '021908501017', 1.99 UNION ALL
SELECT UUID_STRING(), 'LARABAR Cashew Cookie 1.7oz Bar', 'Snacks', 'Granola Bars', 'LARABAR', '021908501024', 1.99 UNION ALL
SELECT UUID_STRING(), 'Trail Mix Classic Nut and Fruit 2oz Bag', 'Snacks', 'Nuts', 'Planters', '029000076815', 2.49;
