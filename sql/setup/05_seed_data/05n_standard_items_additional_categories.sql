-- ============================================================================
-- Retail Data Harmonization Demo
-- Script: sql/setup/05_seed_data/05n_standard_items_additional_categories.sql
-- Purpose: Seed STANDARD_ITEMS with additional categories for comprehensive POS coverage (~225 items)
-- Depends on: 02_schema_and_tables.sql
-- ============================================================================
--
-- New Categories Added:
-- 1. Hot Dogs & Sausages (~30 items) - Stadium/Arena staples
-- 2. Pizza (~25 items) - High-volume concession item
-- 3. Burgers (~25 items) - Grill items across all venues
-- 4. Chicken (~30 items) - Popular across all venues
-- 5. Stadium Classics (~20 items) - Iconic concession items
-- 6. Ice Cream & Frozen Treats (~25 items) - Dessert category
-- 7. Nachos & Loaded Sides (~20 items) - Stadium/Arena favorites
-- 8. Pretzels & Popcorn (~15 items) - Entertainment venue snacks
-- 9. Instant Meals (~15 items) - University convenience items
-- 10. Mexican & Tex-Mex (~20 items) - Complement existing Prepared Foods
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- STANDARD_ITEMS: Hot Dogs & Sausages (~30 items)
-- ============================================================================

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
SELECT UUID_STRING(), 'All Beef Hot Dog Regular', 'Hot Dogs & Sausages', 'Regular Hot Dog', 'Nathans Famous', '041419200017', 4.99 UNION ALL
SELECT UUID_STRING(), 'All Beef Hot Dog with Bun', 'Hot Dogs & Sausages', 'Regular Hot Dog', 'Hebrew National', '041419200024', 5.49 UNION ALL
SELECT UUID_STRING(), 'Hot Dog Regular with Bun', 'Hot Dogs & Sausages', 'Regular Hot Dog', 'Retail Grill', NULL, 4.49 UNION ALL
SELECT UUID_STRING(), 'Jumbo Hot Dog Quarter Pound', 'Hot Dogs & Sausages', 'Jumbo Hot Dog', 'Nathans Famous', '041419200031', 6.99 UNION ALL
SELECT UUID_STRING(), 'Jumbo All Beef Hot Dog', 'Hot Dogs & Sausages', 'Jumbo Hot Dog', 'Hebrew National', '041419200048', 6.49 UNION ALL
SELECT UUID_STRING(), 'Jumbo Hot Dog with Bun', 'Hot Dogs & Sausages', 'Jumbo Hot Dog', 'Retail Grill', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Footlong Hot Dog 12 inch', 'Hot Dogs & Sausages', 'Footlong Hot Dog', 'Retail Grill', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Footlong All Beef Hot Dog', 'Hot Dogs & Sausages', 'Footlong Hot Dog', 'Nathans Famous', '041419200055', 8.49 UNION ALL
SELECT UUID_STRING(), 'Polish Sausage with Peppers and Onions', 'Hot Dogs & Sausages', 'Specialty Sausage', 'Retail Grill', NULL, 7.49 UNION ALL
SELECT UUID_STRING(), 'Polish Sausage Grilled', 'Hot Dogs & Sausages', 'Specialty Sausage', 'Johnsonville', '041419200062', 6.99 UNION ALL
SELECT UUID_STRING(), 'Bratwurst Grilled with Bun', 'Hot Dogs & Sausages', 'Specialty Sausage', 'Johnsonville', '041419200079', 7.49 UNION ALL
SELECT UUID_STRING(), 'Bratwurst with Sauerkraut', 'Hot Dogs & Sausages', 'Specialty Sausage', 'Retail Grill', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Italian Sausage with Peppers', 'Hot Dogs & Sausages', 'Specialty Sausage', 'Retail Grill', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Italian Sausage Grilled', 'Hot Dogs & Sausages', 'Specialty Sausage', 'Johnsonville', '041419200086', 7.49 UNION ALL
SELECT UUID_STRING(), 'Corn Dog Battered on Stick', 'Hot Dogs & Sausages', 'Corn Dog', 'State Fair', '041419200093', 4.99 UNION ALL
SELECT UUID_STRING(), 'Corn Dog Regular', 'Hot Dogs & Sausages', 'Corn Dog', 'Retail Grill', NULL, 4.49 UNION ALL
SELECT UUID_STRING(), 'Mini Corn Dogs 6 Piece', 'Hot Dogs & Sausages', 'Corn Dog', 'State Fair', '041419200109', 5.99 UNION ALL
SELECT UUID_STRING(), 'Chili Cheese Dog', 'Hot Dogs & Sausages', 'Loaded Hot Dog', 'Retail Grill', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'Chili Dog with Onions', 'Hot Dogs & Sausages', 'Loaded Hot Dog', 'Retail Grill', NULL, 6.49 UNION ALL
SELECT UUID_STRING(), 'Chicago Style Hot Dog', 'Hot Dogs & Sausages', 'Loaded Hot Dog', 'Retail Grill', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'New York Style Hot Dog with Sauerkraut', 'Hot Dogs & Sausages', 'Loaded Hot Dog', 'Retail Grill', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Coney Island Hot Dog with Chili', 'Hot Dogs & Sausages', 'Loaded Hot Dog', 'Retail Grill', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'Bacon Wrapped Hot Dog', 'Hot Dogs & Sausages', 'Premium Hot Dog', 'Retail Grill', NULL, 7.49 UNION ALL
SELECT UUID_STRING(), 'Cheese Dog with Cheddar', 'Hot Dogs & Sausages', 'Loaded Hot Dog', 'Retail Grill', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Andouille Sausage Cajun Style', 'Hot Dogs & Sausages', 'Specialty Sausage', 'Retail Grill', NULL, 8.49 UNION ALL
SELECT UUID_STRING(), 'Kielbasa Smoked Sausage', 'Hot Dogs & Sausages', 'Specialty Sausage', 'Hillshire Farm', '041419200116', 7.49 UNION ALL
SELECT UUID_STRING(), 'Turkey Hot Dog All Natural', 'Hot Dogs & Sausages', 'Regular Hot Dog', 'Applegate', '041419200123', 5.49 UNION ALL
SELECT UUID_STRING(), 'Veggie Dog Plant Based', 'Hot Dogs & Sausages', 'Alternative', 'Lightlife', '041419200130', 5.99 UNION ALL
SELECT UUID_STRING(), 'Hot Dog Kids Meal with Fries', 'Hot Dogs & Sausages', 'Kids Meal', 'Retail Grill', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Sausage on a Stick', 'Hot Dogs & Sausages', 'Specialty Sausage', 'Retail Grill', NULL, 5.99;

-- ============================================================================
-- STANDARD_ITEMS: Pizza (~25 items)
-- ============================================================================

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
SELECT UUID_STRING(), 'Pepperoni Pizza Slice', 'Pizza', 'Slice', 'Retail Kitchen', NULL, 4.99 UNION ALL
SELECT UUID_STRING(), 'Pepperoni Pizza Large Slice', 'Pizza', 'Slice', 'Retail Kitchen', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Cheese Pizza Slice', 'Pizza', 'Slice', 'Retail Kitchen', NULL, 4.49 UNION ALL
SELECT UUID_STRING(), 'Cheese Pizza Large Slice', 'Pizza', 'Slice', 'Retail Kitchen', NULL, 4.99 UNION ALL
SELECT UUID_STRING(), 'Supreme Pizza Slice', 'Pizza', 'Specialty Slice', 'Retail Kitchen', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Meat Lovers Pizza Slice', 'Pizza', 'Specialty Slice', 'Retail Kitchen', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'BBQ Chicken Pizza Slice', 'Pizza', 'Specialty Slice', 'Retail Kitchen', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Veggie Pizza Slice', 'Pizza', 'Specialty Slice', 'Retail Kitchen', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Hawaiian Pizza Slice Ham and Pineapple', 'Pizza', 'Specialty Slice', 'Retail Kitchen', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Buffalo Chicken Pizza Slice', 'Pizza', 'Specialty Slice', 'Retail Kitchen', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Margherita Pizza Slice Fresh Basil', 'Pizza', 'Specialty Slice', 'Retail Kitchen', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'White Pizza Slice Ricotta Garlic', 'Pizza', 'Specialty Slice', 'Retail Kitchen', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Personal Pepperoni Pizza 7 inch', 'Pizza', 'Personal', 'Retail Kitchen', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Personal Cheese Pizza 7 inch', 'Pizza', 'Personal', 'Retail Kitchen', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Personal Supreme Pizza 7 inch', 'Pizza', 'Personal', 'Retail Kitchen', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'Whole Pepperoni Pizza 14 inch', 'Pizza', 'Whole', 'Retail Kitchen', NULL, 18.99 UNION ALL
SELECT UUID_STRING(), 'Whole Cheese Pizza 14 inch', 'Pizza', 'Whole', 'Retail Kitchen', NULL, 16.99 UNION ALL
SELECT UUID_STRING(), 'Pizza Combo Slice with Drink', 'Pizza', 'Combo', 'Retail Kitchen', NULL, 7.49 UNION ALL
SELECT UUID_STRING(), 'Pizza Combo Two Slices with Drink', 'Pizza', 'Combo', 'Retail Kitchen', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'Garlic Bread Side', 'Pizza', 'Side', 'Retail Kitchen', NULL, 2.99 UNION ALL
SELECT UUID_STRING(), 'Garlic Knots 4 Piece', 'Pizza', 'Side', 'Retail Kitchen', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Breadsticks with Marinara 4 Piece', 'Pizza', 'Side', 'Retail Kitchen', NULL, 4.49 UNION ALL
SELECT UUID_STRING(), 'Stuffed Pepperoni Pizza Slice', 'Pizza', 'Specialty Slice', 'Retail Kitchen', NULL, 6.49 UNION ALL
SELECT UUID_STRING(), 'Deep Dish Cheese Pizza Slice', 'Pizza', 'Specialty Slice', 'Retail Kitchen', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Flatbread Pizza Margherita', 'Pizza', 'Flatbread', 'Retail Kitchen', NULL, 7.99;

-- ============================================================================
-- STANDARD_ITEMS: Burgers (~25 items)
-- ============================================================================

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
SELECT UUID_STRING(), 'Hamburger Single Patty', 'Burgers', 'Classic', 'Retail Grill', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'Hamburger with Lettuce Tomato Onion', 'Burgers', 'Classic', 'Retail Grill', NULL, 7.49 UNION ALL
SELECT UUID_STRING(), 'Cheeseburger Single Patty', 'Burgers', 'Classic', 'Retail Grill', NULL, 7.49 UNION ALL
SELECT UUID_STRING(), 'Cheeseburger American Cheese', 'Burgers', 'Classic', 'Retail Grill', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Double Cheeseburger', 'Burgers', 'Double', 'Retail Grill', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'Double Hamburger', 'Burgers', 'Double', 'Retail Grill', NULL, 9.49 UNION ALL
SELECT UUID_STRING(), 'Bacon Cheeseburger', 'Burgers', 'Premium', 'Retail Grill', NULL, 9.49 UNION ALL
SELECT UUID_STRING(), 'Bacon Double Cheeseburger', 'Burgers', 'Premium', 'Retail Grill', NULL, 11.49 UNION ALL
SELECT UUID_STRING(), 'BBQ Bacon Burger', 'Burgers', 'Premium', 'Retail Grill', NULL, 10.49 UNION ALL
SELECT UUID_STRING(), 'Mushroom Swiss Burger', 'Burgers', 'Specialty', 'Retail Grill', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'Jalapeno Burger Spicy', 'Burgers', 'Specialty', 'Retail Grill', NULL, 9.49 UNION ALL
SELECT UUID_STRING(), 'Patty Melt on Rye with Grilled Onions', 'Burgers', 'Specialty', 'Retail Grill', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'Western Burger with Onion Ring', 'Burgers', 'Specialty', 'Retail Grill', NULL, 10.49 UNION ALL
SELECT UUID_STRING(), 'Veggie Burger Plant Based Patty', 'Burgers', 'Alternative', 'Impossible Foods', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'Veggie Burger Black Bean', 'Burgers', 'Alternative', 'Retail Grill', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Beyond Burger Plant Based', 'Burgers', 'Alternative', 'Beyond Meat', NULL, 10.49 UNION ALL
SELECT UUID_STRING(), 'Turkey Burger Lean', 'Burgers', 'Alternative', 'Retail Grill', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Slider Burger Mini 2 Pack', 'Burgers', 'Sliders', 'Retail Grill', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'Slider Cheeseburger Mini 2 Pack', 'Burgers', 'Sliders', 'Retail Grill', NULL, 7.49 UNION ALL
SELECT UUID_STRING(), 'Burger Combo with Fries and Drink', 'Burgers', 'Combo', 'Retail Grill', NULL, 12.99 UNION ALL
SELECT UUID_STRING(), 'Cheeseburger Combo with Fries and Drink', 'Burgers', 'Combo', 'Retail Grill', NULL, 13.49 UNION ALL
SELECT UUID_STRING(), 'Kids Hamburger with Fries', 'Burgers', 'Kids Meal', 'Retail Grill', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Kids Cheeseburger with Fries', 'Burgers', 'Kids Meal', 'Retail Grill', NULL, 8.49 UNION ALL
SELECT UUID_STRING(), 'Angus Beef Burger Premium', 'Burgers', 'Premium', 'Retail Grill', NULL, 11.99 UNION ALL
SELECT UUID_STRING(), 'Guacamole Bacon Burger', 'Burgers', 'Premium', 'Retail Grill', NULL, 11.49;

-- ============================================================================
-- STANDARD_ITEMS: Chicken (~30 items)
-- ============================================================================

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
SELECT UUID_STRING(), 'Chicken Tenders 3 Piece', 'Chicken', 'Tenders', 'Retail Grill', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Tenders 4 Piece', 'Chicken', 'Tenders', 'Retail Grill', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Tenders 6 Piece', 'Chicken', 'Tenders', 'Retail Grill', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Strips 3 Piece', 'Chicken', 'Tenders', 'Retail Grill', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Strips 5 Piece', 'Chicken', 'Tenders', 'Retail Grill', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Nuggets 6 Piece', 'Chicken', 'Nuggets', 'Retail Grill', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Nuggets 10 Piece', 'Chicken', 'Nuggets', 'Retail Grill', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Nuggets 20 Piece', 'Chicken', 'Nuggets', 'Retail Grill', NULL, 14.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Wings 6 Piece Original', 'Chicken', 'Wings', 'Retail Grill', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Wings 10 Piece Original', 'Chicken', 'Wings', 'Retail Grill', NULL, 14.99 UNION ALL
SELECT UUID_STRING(), 'Buffalo Chicken Wings 6 Piece', 'Chicken', 'Wings', 'Retail Grill', NULL, 10.49 UNION ALL
SELECT UUID_STRING(), 'Buffalo Chicken Wings 10 Piece', 'Chicken', 'Wings', 'Retail Grill', NULL, 15.99 UNION ALL
SELECT UUID_STRING(), 'BBQ Chicken Wings 6 Piece', 'Chicken', 'Wings', 'Retail Grill', NULL, 10.49 UNION ALL
SELECT UUID_STRING(), 'Hot Wings 6 Piece Spicy', 'Chicken', 'Wings', 'Retail Grill', NULL, 10.49 UNION ALL
SELECT UUID_STRING(), 'Garlic Parmesan Wings 6 Piece', 'Chicken', 'Wings', 'Retail Grill', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'Boneless Wings 6 Piece', 'Chicken', 'Wings', 'Retail Grill', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Sandwich Grilled', 'Chicken', 'Sandwich', 'Retail Grill', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Sandwich Crispy Fried', 'Chicken', 'Sandwich', 'Retail Grill', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Spicy Chicken Sandwich', 'Chicken', 'Sandwich', 'Retail Grill', NULL, 9.49 UNION ALL
SELECT UUID_STRING(), 'Buffalo Chicken Sandwich', 'Chicken', 'Sandwich', 'Retail Grill', NULL, 9.49 UNION ALL
SELECT UUID_STRING(), 'Chicken Club Sandwich with Bacon', 'Chicken', 'Sandwich', 'Retail Grill', NULL, 10.49 UNION ALL
SELECT UUID_STRING(), 'Chicken Tenders Combo with Fries', 'Chicken', 'Combo', 'Retail Grill', NULL, 11.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Nuggets Combo with Fries', 'Chicken', 'Combo', 'Retail Grill', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Sandwich Combo with Fries', 'Chicken', 'Combo', 'Retail Grill', NULL, 12.49 UNION ALL
SELECT UUID_STRING(), 'Kids Chicken Tenders 2 Piece with Fries', 'Chicken', 'Kids Meal', 'Retail Grill', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'Kids Chicken Nuggets 4 Piece with Fries', 'Chicken', 'Kids Meal', 'Retail Grill', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Fingers Basket 4 Piece', 'Chicken', 'Tenders', 'Retail Grill', NULL, 8.49 UNION ALL
SELECT UUID_STRING(), 'Popcorn Chicken 8oz', 'Chicken', 'Nuggets', 'Retail Grill', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Wrap Crispy', 'Chicken', 'Wrap', 'Retail Grill', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Wrap Buffalo Ranch', 'Chicken', 'Wrap', 'Retail Grill', NULL, 8.49;

-- ============================================================================
-- STANDARD_ITEMS: Stadium Classics (~20 items)
-- ============================================================================

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
SELECT UUID_STRING(), 'Peanuts Roasted Salted Bag', 'Stadium Classics', 'Nuts', 'Planters', '029000017146', 5.99 UNION ALL
SELECT UUID_STRING(), 'Peanuts In Shell Large Bag', 'Stadium Classics', 'Nuts', 'Retail Concession', NULL, 6.49 UNION ALL
SELECT UUID_STRING(), 'Peanuts Stadium Bag', 'Stadium Classics', 'Nuts', 'Retail Concession', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Cracker Jack Caramel Popcorn Box', 'Stadium Classics', 'Caramel Corn', 'Cracker Jack', '028400000017', 4.99 UNION ALL
SELECT UUID_STRING(), 'Cracker Jack Original', 'Stadium Classics', 'Caramel Corn', 'Cracker Jack', '028400000024', 4.49 UNION ALL
SELECT UUID_STRING(), 'Cotton Candy Pink Bag', 'Stadium Classics', 'Sweet Treats', 'Retail Concession', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'Cotton Candy Blue Bag', 'Stadium Classics', 'Sweet Treats', 'Retail Concession', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'Cotton Candy Tub Large', 'Stadium Classics', 'Sweet Treats', 'Retail Concession', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Churro Cinnamon Sugar', 'Stadium Classics', 'Sweet Treats', 'Retail Concession', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Churro with Chocolate Dipping Sauce', 'Stadium Classics', 'Sweet Treats', 'Retail Concession', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'Funnel Cake Powdered Sugar', 'Stadium Classics', 'Sweet Treats', 'Retail Concession', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Funnel Cake with Strawberries and Cream', 'Stadium Classics', 'Sweet Treats', 'Retail Concession', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'Funnel Cake with Chocolate Sauce', 'Stadium Classics', 'Sweet Treats', 'Retail Concession', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Caramel Apple on Stick', 'Stadium Classics', 'Sweet Treats', 'Retail Concession', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Candied Apple Red', 'Stadium Classics', 'Sweet Treats', 'Retail Concession', NULL, 4.99 UNION ALL
SELECT UUID_STRING(), 'Snow Cone Cherry', 'Stadium Classics', 'Frozen', 'Retail Concession', NULL, 4.49 UNION ALL
SELECT UUID_STRING(), 'Snow Cone Blue Raspberry', 'Stadium Classics', 'Frozen', 'Retail Concession', NULL, 4.49 UNION ALL
SELECT UUID_STRING(), 'Snow Cone Rainbow', 'Stadium Classics', 'Frozen', 'Retail Concession', NULL, 4.99 UNION ALL
SELECT UUID_STRING(), 'Fried Oreos 6 Piece', 'Stadium Classics', 'Sweet Treats', 'Retail Concession', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'Elephant Ear Cinnamon Sugar', 'Stadium Classics', 'Sweet Treats', 'Retail Concession', NULL, 6.99;

-- ============================================================================
-- STANDARD_ITEMS: Ice Cream & Frozen Treats (~25 items)
-- ============================================================================

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
SELECT UUID_STRING(), 'Soft Serve Ice Cream Vanilla Cone', 'Ice Cream & Frozen Treats', 'Soft Serve', 'Retail Concession', NULL, 4.49 UNION ALL
SELECT UUID_STRING(), 'Soft Serve Ice Cream Chocolate Cone', 'Ice Cream & Frozen Treats', 'Soft Serve', 'Retail Concession', NULL, 4.49 UNION ALL
SELECT UUID_STRING(), 'Soft Serve Ice Cream Twist Cone', 'Ice Cream & Frozen Treats', 'Soft Serve', 'Retail Concession', NULL, 4.49 UNION ALL
SELECT UUID_STRING(), 'Soft Serve Vanilla Cup', 'Ice Cream & Frozen Treats', 'Soft Serve', 'Retail Concession', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Soft Serve Chocolate Cup', 'Ice Cream & Frozen Treats', 'Soft Serve', 'Retail Concession', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Ice Cream Sundae Hot Fudge', 'Ice Cream & Frozen Treats', 'Sundae', 'Retail Concession', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Ice Cream Sundae Caramel', 'Ice Cream & Frozen Treats', 'Sundae', 'Retail Concession', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Ice Cream Sundae Strawberry', 'Ice Cream & Frozen Treats', 'Sundae', 'Retail Concession', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Ice Cream Sundae Banana Split', 'Ice Cream & Frozen Treats', 'Sundae', 'Retail Concession', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Dippin Dots Rainbow Ice Cup', 'Ice Cream & Frozen Treats', 'Novelty', 'Dippin Dots', '049263001040', 5.99 UNION ALL
SELECT UUID_STRING(), 'Dippin Dots Cookies and Cream Cup', 'Ice Cream & Frozen Treats', 'Novelty', 'Dippin Dots', '049263001057', 5.99 UNION ALL
SELECT UUID_STRING(), 'Dippin Dots Cotton Candy Cup', 'Ice Cream & Frozen Treats', 'Novelty', 'Dippin Dots', '049263001064', 5.99 UNION ALL
SELECT UUID_STRING(), 'Frozen Lemonade Large', 'Ice Cream & Frozen Treats', 'Frozen Beverage', 'Retail Concession', NULL, 4.99 UNION ALL
SELECT UUID_STRING(), 'Frozen Lemonade Regular', 'Ice Cream & Frozen Treats', 'Frozen Beverage', 'Retail Concession', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Frozen Strawberry Lemonade', 'Ice Cream & Frozen Treats', 'Frozen Beverage', 'Retail Concession', NULL, 4.99 UNION ALL
SELECT UUID_STRING(), 'Milkshake Chocolate', 'Ice Cream & Frozen Treats', 'Milkshake', 'Retail Concession', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Milkshake Vanilla', 'Ice Cream & Frozen Treats', 'Milkshake', 'Retail Concession', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Milkshake Strawberry', 'Ice Cream & Frozen Treats', 'Milkshake', 'Retail Concession', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Milkshake Oreo Cookie', 'Ice Cream & Frozen Treats', 'Milkshake', 'Retail Concession', NULL, 6.49 UNION ALL
SELECT UUID_STRING(), 'Ice Cream Float Root Beer', 'Ice Cream & Frozen Treats', 'Float', 'Retail Concession', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Ice Cream Float Coke', 'Ice Cream & Frozen Treats', 'Float', 'Retail Concession', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Frozen Yogurt Vanilla Cup', 'Ice Cream & Frozen Treats', 'Frozen Yogurt', 'Retail Concession', NULL, 4.99 UNION ALL
SELECT UUID_STRING(), 'Frozen Yogurt with Toppings', 'Ice Cream & Frozen Treats', 'Frozen Yogurt', 'Retail Concession', NULL, 6.49 UNION ALL
SELECT UUID_STRING(), 'Ice Cream Waffle Cone', 'Ice Cream & Frozen Treats', 'Scoop', 'Retail Concession', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Ice Cream Sugar Cone', 'Ice Cream & Frozen Treats', 'Scoop', 'Retail Concession', NULL, 4.99;

-- ============================================================================
-- STANDARD_ITEMS: Nachos & Loaded Sides (~20 items)
-- ============================================================================

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
SELECT UUID_STRING(), 'Nachos with Cheese Sauce', 'Nachos & Loaded Sides', 'Nachos', 'Retail Concession', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'Nachos with Cheese Large', 'Nachos & Loaded Sides', 'Nachos', 'Retail Concession', NULL, 8.49 UNION ALL
SELECT UUID_STRING(), 'Nachos Supreme with Beef and Jalapenos', 'Nachos & Loaded Sides', 'Loaded Nachos', 'Retail Concession', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'Loaded Nachos with Chicken', 'Nachos & Loaded Sides', 'Loaded Nachos', 'Retail Concession', NULL, 10.49 UNION ALL
SELECT UUID_STRING(), 'Nachos Grande Full Toppings', 'Nachos & Loaded Sides', 'Loaded Nachos', 'Retail Concession', NULL, 11.99 UNION ALL
SELECT UUID_STRING(), 'Nacho Chips with Cheese Dip Cup', 'Nachos & Loaded Sides', 'Nachos', 'Retail Concession', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Loaded Fries Cheese and Bacon', 'Nachos & Loaded Sides', 'Loaded Fries', 'Retail Concession', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Loaded Fries with Chili and Cheese', 'Nachos & Loaded Sides', 'Loaded Fries', 'Retail Concession', NULL, 9.49 UNION ALL
SELECT UUID_STRING(), 'Loaded Fries Ranch and Bacon', 'Nachos & Loaded Sides', 'Loaded Fries', 'Retail Concession', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Cheese Fries', 'Nachos & Loaded Sides', 'Loaded Fries', 'Retail Concession', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'Loaded Tater Tots with Cheese', 'Nachos & Loaded Sides', 'Loaded Tots', 'Retail Concession', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Loaded Tots Supreme', 'Nachos & Loaded Sides', 'Loaded Tots', 'Retail Concession', NULL, 9.49 UNION ALL
SELECT UUID_STRING(), 'Cheese Cup for Dipping', 'Nachos & Loaded Sides', 'Dip', 'Retail Concession', NULL, 1.99 UNION ALL
SELECT UUID_STRING(), 'Queso Dip Cup', 'Nachos & Loaded Sides', 'Dip', 'Retail Concession', NULL, 2.49 UNION ALL
SELECT UUID_STRING(), 'Jalapeno Cheese Dip Cup', 'Nachos & Loaded Sides', 'Dip', 'Retail Concession', NULL, 2.49 UNION ALL
SELECT UUID_STRING(), 'Chili Cheese Nachos', 'Nachos & Loaded Sides', 'Loaded Nachos', 'Retail Concession', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Walking Taco Doritos with Toppings', 'Nachos & Loaded Sides', 'Walking Taco', 'Retail Concession', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Walking Taco Fritos with Chili', 'Nachos & Loaded Sides', 'Walking Taco', 'Retail Concession', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Carne Asada Fries', 'Nachos & Loaded Sides', 'Loaded Fries', 'Retail Concession', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'BBQ Pulled Pork Nachos', 'Nachos & Loaded Sides', 'Loaded Nachos', 'Retail Concession', NULL, 10.99;

-- ============================================================================
-- STANDARD_ITEMS: Pretzels & Popcorn (~15 items)
-- ============================================================================

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
SELECT UUID_STRING(), 'Soft Pretzel with Salt', 'Pretzels & Popcorn', 'Soft Pretzel', 'Retail Concession', NULL, 4.99 UNION ALL
SELECT UUID_STRING(), 'Soft Pretzel with Cheese Dip', 'Pretzels & Popcorn', 'Soft Pretzel', 'Retail Concession', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Soft Pretzel Jumbo', 'Pretzels & Popcorn', 'Soft Pretzel', 'Retail Concession', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Pretzel Bites with Cheese 8 Piece', 'Pretzels & Popcorn', 'Pretzel Bites', 'Retail Concession', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Pretzel Bites with Mustard', 'Pretzels & Popcorn', 'Pretzel Bites', 'Retail Concession', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Cinnamon Sugar Pretzel', 'Pretzels & Popcorn', 'Soft Pretzel', 'Retail Concession', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Pretzel Dog', 'Pretzels & Popcorn', 'Pretzel Dog', 'Retail Concession', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'Popcorn Large Buttered', 'Pretzels & Popcorn', 'Popcorn', 'Retail Concession', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Popcorn Medium Buttered', 'Pretzels & Popcorn', 'Popcorn', 'Retail Concession', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Popcorn Small Buttered', 'Pretzels & Popcorn', 'Popcorn', 'Retail Concession', NULL, 4.49 UNION ALL
SELECT UUID_STRING(), 'Popcorn Refillable Souvenir Bucket', 'Pretzels & Popcorn', 'Popcorn', 'Retail Concession', NULL, 12.99 UNION ALL
SELECT UUID_STRING(), 'Kettle Corn Large', 'Pretzels & Popcorn', 'Kettle Corn', 'Retail Concession', NULL, 8.49 UNION ALL
SELECT UUID_STRING(), 'Kettle Corn Regular', 'Pretzels & Popcorn', 'Kettle Corn', 'Retail Concession', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Caramel Popcorn Bag', 'Pretzels & Popcorn', 'Kettle Corn', 'Retail Concession', NULL, 6.49 UNION ALL
SELECT UUID_STRING(), 'Chicago Mix Popcorn Cheese and Caramel', 'Pretzels & Popcorn', 'Kettle Corn', 'Retail Concession', NULL, 7.49;

-- ============================================================================
-- STANDARD_ITEMS: Instant Meals (~15 items)
-- ============================================================================

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
SELECT UUID_STRING(), 'Cup Noodles Chicken Flavor 2.25oz', 'Instant Meals', 'Cup Noodles', 'Nissin', '070662001035', 1.79 UNION ALL
SELECT UUID_STRING(), 'Cup Noodles Beef Flavor 2.25oz', 'Instant Meals', 'Cup Noodles', 'Nissin', '070662001042', 1.79 UNION ALL
SELECT UUID_STRING(), 'Cup Noodles Shrimp Flavor 2.25oz', 'Instant Meals', 'Cup Noodles', 'Nissin', '070662001059', 1.79 UNION ALL
SELECT UUID_STRING(), 'Cup Noodles Spicy Chicken 2.25oz', 'Instant Meals', 'Cup Noodles', 'Nissin', '070662001066', 1.79 UNION ALL
SELECT UUID_STRING(), 'Maruchan Instant Lunch Chicken 2.25oz', 'Instant Meals', 'Ramen', 'Maruchan', '041789002717', 1.49 UNION ALL
SELECT UUID_STRING(), 'Maruchan Instant Lunch Beef 2.25oz', 'Instant Meals', 'Ramen', 'Maruchan', '041789002724', 1.49 UNION ALL
SELECT UUID_STRING(), 'Maruchan Instant Lunch Lime Chili Shrimp', 'Instant Meals', 'Ramen', 'Maruchan', '041789002731', 1.49 UNION ALL
SELECT UUID_STRING(), 'Top Ramen Cup Chicken 2.25oz', 'Instant Meals', 'Ramen', 'Nissin', '070662001073', 1.29 UNION ALL
SELECT UUID_STRING(), 'Yakisoba Japanese Noodles Teriyaki', 'Instant Meals', 'Ramen', 'Maruchan', '041789002748', 2.29 UNION ALL
SELECT UUID_STRING(), 'Mac and Cheese Cup Instant Microwave', 'Instant Meals', 'Mac and Cheese', 'Kraft', '021000012145', 2.49 UNION ALL
SELECT UUID_STRING(), 'Easy Mac Cup Original', 'Instant Meals', 'Mac and Cheese', 'Kraft', '021000012152', 2.29 UNION ALL
SELECT UUID_STRING(), 'Velveeta Shells and Cheese Cup', 'Instant Meals', 'Mac and Cheese', 'Velveeta', '021000012169', 2.79 UNION ALL
SELECT UUID_STRING(), 'Annie Organic Mac and Cheese Cup', 'Instant Meals', 'Mac and Cheese', 'Annies', '013562302017', 2.99 UNION ALL
SELECT UUID_STRING(), 'Ramen Bowl Spicy Miso', 'Instant Meals', 'Ramen Bowl', 'Nongshim', '031146270019', 3.49 UNION ALL
SELECT UUID_STRING(), 'Shin Ramyun Cup Spicy', 'Instant Meals', 'Ramen Bowl', 'Nongshim', '031146270026', 2.99;

-- ============================================================================
-- STANDARD_ITEMS: Mexican & Tex-Mex (~20 items)
-- ============================================================================

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
SELECT UUID_STRING(), 'Beef Taco Hard Shell', 'Mexican & Tex-Mex', 'Tacos', 'Retail Kitchen', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Beef Taco Soft Shell', 'Mexican & Tex-Mex', 'Tacos', 'Retail Kitchen', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Taco Soft Shell', 'Mexican & Tex-Mex', 'Tacos', 'Retail Kitchen', NULL, 4.49 UNION ALL
SELECT UUID_STRING(), 'Carnitas Taco with Cilantro Onion', 'Mexican & Tex-Mex', 'Tacos', 'Retail Kitchen', NULL, 4.99 UNION ALL
SELECT UUID_STRING(), 'Fish Taco Baja Style', 'Mexican & Tex-Mex', 'Tacos', 'Retail Kitchen', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Taco Combo 2 Tacos with Rice and Beans', 'Mexican & Tex-Mex', 'Combo', 'Retail Kitchen', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'Taco Combo 3 Tacos with Chips', 'Mexican & Tex-Mex', 'Combo', 'Retail Kitchen', NULL, 11.99 UNION ALL
SELECT UUID_STRING(), 'Cheese Quesadilla', 'Mexican & Tex-Mex', 'Quesadilla', 'Retail Kitchen', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Quesadilla', 'Mexican & Tex-Mex', 'Quesadilla', 'Retail Kitchen', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Steak Quesadilla', 'Mexican & Tex-Mex', 'Quesadilla', 'Retail Kitchen', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'Bean and Cheese Burrito', 'Mexican & Tex-Mex', 'Burrito', 'Retail Kitchen', NULL, 6.49 UNION ALL
SELECT UUID_STRING(), 'Chicken Burrito', 'Mexican & Tex-Mex', 'Burrito', 'Retail Kitchen', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Beef Burrito', 'Mexican & Tex-Mex', 'Burrito', 'Retail Kitchen', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Carnitas Burrito', 'Mexican & Tex-Mex', 'Burrito', 'Retail Kitchen', NULL, 9.49 UNION ALL
SELECT UUID_STRING(), 'Burrito Bowl Chicken with Rice', 'Mexican & Tex-Mex', 'Bowl', 'Retail Kitchen', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'Burrito Bowl Steak with Rice', 'Mexican & Tex-Mex', 'Bowl', 'Retail Kitchen', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'Burrito Bowl Veggie with Black Beans', 'Mexican & Tex-Mex', 'Bowl', 'Retail Kitchen', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Enchiladas Cheese 2 Piece with Rice', 'Mexican & Tex-Mex', 'Enchiladas', 'Retail Kitchen', NULL, 9.49 UNION ALL
SELECT UUID_STRING(), 'Enchiladas Chicken 2 Piece with Rice', 'Mexican & Tex-Mex', 'Enchiladas', 'Retail Kitchen', NULL, 10.49 UNION ALL
SELECT UUID_STRING(), 'Tamale Chicken with Red Sauce', 'Mexican & Tex-Mex', 'Tamales', 'Retail Kitchen', NULL, 4.99;
