-- ============================================================================
-- Retail Data Harmonization Demo
-- Script: sql/setup/05_seed_data/05d_standard_items_prepared.sql
-- Purpose: Seed STANDARD_ITEMS table with prepared foods (~114 items)
-- Depends on: 02_schema_and_tables.sql
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- STANDARD_ITEMS: Master Item List - PREPARED FOODS (~100 items)
-- ============================================================================


INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Sandwiches and Wraps
SELECT UUID_STRING(), 'Turkey and Cheese Club Sandwich on Wheat', 'Prepared Foods', 'Sandwiches', 'Retail Fresh', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Ham and Swiss Sandwich on Rye', 'Prepared Foods', 'Sandwiches', 'Retail Fresh', NULL, 8.49 UNION ALL
SELECT UUID_STRING(), 'BLT Sandwich on White Toast', 'Prepared Foods', 'Sandwiches', 'Retail Fresh', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Caesar Wrap', 'Prepared Foods', 'Wraps', 'Retail Fresh', NULL, 9.49 UNION ALL
SELECT UUID_STRING(), 'Veggie Hummus Wrap', 'Prepared Foods', 'Wraps', 'Retail Fresh', NULL, 8.49 UNION ALL
SELECT UUID_STRING(), 'Buffalo Chicken Wrap', 'Prepared Foods', 'Wraps', 'Retail Fresh', NULL, 9.49 UNION ALL
SELECT UUID_STRING(), 'Italian Sub Sandwich 12 inch', 'Prepared Foods', 'Sandwiches', 'Retail Fresh', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'Grilled Chicken Breast Sandwich', 'Prepared Foods', 'Sandwiches', 'Retail Fresh', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'Tuna Salad Sandwich on Wheat', 'Prepared Foods', 'Sandwiches', 'Retail Fresh', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Egg Salad Sandwich on White', 'Prepared Foods', 'Sandwiches', 'Retail Fresh', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'PB&J Sandwich Grape on White', 'Prepared Foods', 'Sandwiches', 'Retail Fresh', NULL, 4.99 UNION ALL
SELECT UUID_STRING(), 'Philly Cheesesteak Sub 12 inch', 'Prepared Foods', 'Sandwiches', 'Retail Fresh', NULL, 11.99 UNION ALL
-- Salads
SELECT UUID_STRING(), 'Garden Side Salad with Ranch', 'Prepared Foods', 'Salads', 'Retail Fresh', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Caesar Salad with Croutons', 'Prepared Foods', 'Salads', 'Retail Fresh', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Grilled Chicken Caesar Salad', 'Prepared Foods', 'Salads', 'Retail Fresh', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'Cobb Salad with Turkey and Bacon', 'Prepared Foods', 'Salads', 'Retail Fresh', NULL, 11.49 UNION ALL
SELECT UUID_STRING(), 'Southwest Chicken Salad with Chipotle Ranch', 'Prepared Foods', 'Salads', 'Retail Fresh', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'Greek Salad with Feta and Olives', 'Prepared Foods', 'Salads', 'Retail Fresh', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'Asian Sesame Chicken Salad', 'Prepared Foods', 'Salads', 'Retail Fresh', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'Fruit Cup Mixed Seasonal 8oz', 'Prepared Foods', 'Salads', 'Retail Fresh', NULL, 4.99;

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Hot Entrees
SELECT UUID_STRING(), 'Pepperoni Pizza Slice', 'Prepared Foods', 'Pizza', 'Retail Kitchen', NULL, 4.99 UNION ALL
SELECT UUID_STRING(), 'Cheese Pizza Slice', 'Prepared Foods', 'Pizza', 'Retail Kitchen', NULL, 4.49 UNION ALL
SELECT UUID_STRING(), 'Supreme Pizza Slice', 'Prepared Foods', 'Pizza', 'Retail Kitchen', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Margherita Pizza Slice', 'Prepared Foods', 'Pizza', 'Retail Kitchen', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'BBQ Chicken Pizza Slice', 'Prepared Foods', 'Pizza', 'Retail Kitchen', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Cheeseburger with Fries', 'Prepared Foods', 'Burgers', 'Retail Grill', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'Hamburger with Fries', 'Prepared Foods', 'Burgers', 'Retail Grill', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Bacon Cheeseburger with Fries', 'Prepared Foods', 'Burgers', 'Retail Grill', NULL, 11.49 UNION ALL
SELECT UUID_STRING(), 'Veggie Burger with Fries', 'Prepared Foods', 'Burgers', 'Retail Grill', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Tenders 4pc with Fries', 'Prepared Foods', 'Fried', 'Retail Grill', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Tenders 6pc with Fries', 'Prepared Foods', 'Fried', 'Retail Grill', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'Mozzarella Sticks 6pc', 'Prepared Foods', 'Fried', 'Retail Grill', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'French Fries Large', 'Prepared Foods', 'Sides', 'Retail Grill', NULL, 4.49 UNION ALL
SELECT UUID_STRING(), 'French Fries Regular', 'Prepared Foods', 'Sides', 'Retail Grill', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Onion Rings', 'Prepared Foods', 'Sides', 'Retail Grill', NULL, 4.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Quesadilla', 'Prepared Foods', 'Mexican', 'Retail Kitchen', NULL, 9.49 UNION ALL
SELECT UUID_STRING(), 'Beef Burrito Bowl', 'Prepared Foods', 'Mexican', 'Retail Kitchen', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Burrito Bowl', 'Prepared Foods', 'Mexican', 'Retail Kitchen', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'Cheese Quesadilla', 'Prepared Foods', 'Mexican', 'Retail Kitchen', NULL, 7.49 UNION ALL
SELECT UUID_STRING(), 'Nachos with Cheese Sauce', 'Prepared Foods', 'Mexican', 'Retail Kitchen', NULL, 6.99;

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Soups and Bowls
SELECT UUID_STRING(), 'Chicken Noodle Soup 12oz Bowl', 'Prepared Foods', 'Soup', 'Retail Kitchen', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Tomato Basil Soup 12oz Bowl', 'Prepared Foods', 'Soup', 'Retail Kitchen', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Broccoli Cheddar Soup 12oz Bowl', 'Prepared Foods', 'Soup', 'Retail Kitchen', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Clam Chowder 12oz Bowl', 'Prepared Foods', 'Soup', 'Retail Kitchen', NULL, 6.49 UNION ALL
SELECT UUID_STRING(), 'Chili with Beans 12oz Bowl', 'Prepared Foods', 'Soup', 'Retail Kitchen', NULL, 6.99 UNION ALL
-- Breakfast
SELECT UUID_STRING(), 'Breakfast Burrito Sausage Egg Cheese', 'Prepared Foods', 'Breakfast', 'Retail Kitchen', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'Breakfast Sandwich Bacon Egg Cheese on Croissant', 'Prepared Foods', 'Breakfast', 'Retail Kitchen', NULL, 6.49 UNION ALL
SELECT UUID_STRING(), 'Breakfast Sandwich Ham Egg Cheese on English Muffin', 'Prepared Foods', 'Breakfast', 'Retail Kitchen', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Bagel with Cream Cheese', 'Prepared Foods', 'Breakfast', 'Retail Kitchen', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Oatmeal with Brown Sugar 12oz', 'Prepared Foods', 'Breakfast', 'Retail Kitchen', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Yogurt Parfait with Granola', 'Prepared Foods', 'Breakfast', 'Retail Kitchen', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Fresh Baked Blueberry Muffin', 'Prepared Foods', 'Breakfast', 'Retail Kitchen', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Fresh Baked Chocolate Chip Muffin', 'Prepared Foods', 'Breakfast', 'Retail Kitchen', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Danish Cheese', 'Prepared Foods', 'Breakfast', 'Retail Kitchen', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Cinnamon Roll', 'Prepared Foods', 'Breakfast', 'Retail Kitchen', NULL, 3.99 UNION ALL
-- Packaged Meals and Snacks
SELECT UUID_STRING(), 'Cup Noodles Chicken Flavor 2.25oz', 'Prepared Foods', 'Packaged Meals', 'Nissin', '070662001011', 1.79 UNION ALL
SELECT UUID_STRING(), 'Cup Noodles Beef Flavor 2.25oz', 'Prepared Foods', 'Packaged Meals', 'Nissin', '070662001028', 1.79 UNION ALL
SELECT UUID_STRING(), 'Maruchan Instant Lunch Chicken 2.25oz', 'Prepared Foods', 'Packaged Meals', 'Maruchan', '041789002700', 1.49 UNION ALL
SELECT UUID_STRING(), 'Chef Boyardee Beef Ravioli 7.5oz Can', 'Prepared Foods', 'Packaged Meals', 'Chef Boyardee', '064144044531', 2.49 UNION ALL
SELECT UUID_STRING(), 'Hormel Compleats Chicken Breast and Mashed Potatoes 10oz', 'Prepared Foods', 'Packaged Meals', 'Hormel', '037600170116', 4.99 UNION ALL
-- Desserts
SELECT UUID_STRING(), 'Chocolate Chip Cookie Fresh Baked', 'Prepared Foods', 'Desserts', 'Retail Kitchen', NULL, 2.49 UNION ALL
SELECT UUID_STRING(), 'Brownie Square', 'Prepared Foods', 'Desserts', 'Retail Kitchen', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Rice Krispies Treat 1.3oz', 'Prepared Foods', 'Desserts', 'Kelloggs', '038000317101', 1.99 UNION ALL
SELECT UUID_STRING(), 'Hostess Twinkies 2 Pack', 'Prepared Foods', 'Desserts', 'Hostess', '888109011013', 2.99 UNION ALL
SELECT UUID_STRING(), 'Little Debbie Cosmic Brownies 2 Pack', 'Prepared Foods', 'Desserts', 'Little Debbie', '024300044137', 1.99;

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- Bowls
SELECT UUID_STRING(), 'Poke Bowl Tuna Shoyu 12oz', 'Prepared Foods', 'Bowls', 'Retail Fresh', NULL, 14.99 UNION ALL
SELECT UUID_STRING(), 'Poke Bowl Salmon Spicy Mayo 12oz', 'Prepared Foods', 'Bowls', 'Retail Fresh', NULL, 14.99 UNION ALL
SELECT UUID_STRING(), 'Poke Bowl Veggie Tofu 12oz', 'Prepared Foods', 'Bowls', 'Retail Fresh', NULL, 12.99 UNION ALL
SELECT UUID_STRING(), 'Grain Bowl Chicken Fajita with Rice', 'Prepared Foods', 'Bowls', 'Retail Kitchen', NULL, 11.99 UNION ALL
SELECT UUID_STRING(), 'Grain Bowl Mediterranean Quinoa Feta', 'Prepared Foods', 'Bowls', 'Retail Kitchen', NULL, 11.49 UNION ALL
SELECT UUID_STRING(), 'Buddha Bowl Roasted Sweet Potato Black Bean', 'Prepared Foods', 'Bowls', 'Retail Kitchen', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'Buddha Bowl Thai Peanut Chicken', 'Prepared Foods', 'Bowls', 'Retail Kitchen', NULL, 11.99 UNION ALL
SELECT UUID_STRING(), 'Teriyaki Chicken Bowl with Steamed Rice', 'Prepared Foods', 'Bowls', 'Retail Kitchen', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'Bibimbap Bowl Korean Beef with Rice', 'Prepared Foods', 'Bowls', 'Retail Kitchen', NULL, 12.99 UNION ALL
-- Ethnic Foods
SELECT UUID_STRING(), 'Chicken Taco 2pc with Cilantro Lime', 'Prepared Foods', 'Mexican', 'Retail Kitchen', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Carnitas Taco 2pc with Salsa Verde', 'Prepared Foods', 'Mexican', 'Retail Kitchen', NULL, 8.49 UNION ALL
SELECT UUID_STRING(), 'Fish Taco 2pc Baja Style', 'Prepared Foods', 'Mexican', 'Retail Kitchen', NULL, 9.49 UNION ALL
SELECT UUID_STRING(), 'Chicken Burrito Grande with Rice and Beans', 'Prepared Foods', 'Mexican', 'Retail Kitchen', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'Steak Burrito Grande with Rice and Beans', 'Prepared Foods', 'Mexican', 'Retail Kitchen', NULL, 11.99 UNION ALL
SELECT UUID_STRING(), 'Veggie Burrito Black Bean and Rice', 'Prepared Foods', 'Mexican', 'Retail Kitchen', NULL, 9.49 UNION ALL
SELECT UUID_STRING(), 'Pad Thai Chicken 14oz', 'Prepared Foods', 'Asian', 'Retail Kitchen', NULL, 11.99 UNION ALL
SELECT UUID_STRING(), 'Pad Thai Shrimp 14oz', 'Prepared Foods', 'Asian', 'Retail Kitchen', NULL, 12.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Fried Rice 14oz', 'Prepared Foods', 'Asian', 'Retail Kitchen', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'Orange Chicken with Steamed Rice 14oz', 'Prepared Foods', 'Asian', 'Retail Kitchen', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'General Tso Chicken with Steamed Rice 14oz', 'Prepared Foods', 'Asian', 'Retail Kitchen', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Tikka Masala with Basmati Rice 14oz', 'Prepared Foods', 'Asian', 'Retail Kitchen', NULL, 11.99 UNION ALL
SELECT UUID_STRING(), 'Green Curry Chicken with Jasmine Rice 14oz', 'Prepared Foods', 'Asian', 'Retail Kitchen', NULL, 11.99 UNION ALL
SELECT UUID_STRING(), 'Beef Lo Mein 14oz', 'Prepared Foods', 'Asian', 'Retail Kitchen', NULL, 10.99 UNION ALL
-- Premium Sandwiches
SELECT UUID_STRING(), 'Cubano Pressed Sandwich Ham Pork Pickle', 'Prepared Foods', 'Sandwiches', 'Retail Fresh', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'Banh Mi Vietnamese Pork Sandwich', 'Prepared Foods', 'Sandwiches', 'Retail Fresh', NULL, 10.49 UNION ALL
SELECT UUID_STRING(), 'Reuben Sandwich Corned Beef Swiss Sauerkraut on Rye', 'Prepared Foods', 'Sandwiches', 'Retail Fresh', NULL, 11.49 UNION ALL
SELECT UUID_STRING(), 'Caprese Sandwich Fresh Mozzarella Tomato Basil', 'Prepared Foods', 'Sandwiches', 'Retail Fresh', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'French Dip Roast Beef Sandwich with Au Jus', 'Prepared Foods', 'Sandwiches', 'Retail Fresh', NULL, 11.99 UNION ALL
SELECT UUID_STRING(), 'Club Sandwich Triple Decker Turkey Ham Bacon', 'Prepared Foods', 'Sandwiches', 'Retail Fresh', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Parm Sandwich on Ciabatta', 'Prepared Foods', 'Sandwiches', 'Retail Fresh', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'BBQ Pulled Pork Sandwich with Coleslaw', 'Prepared Foods', 'Sandwiches', 'Retail Fresh', NULL, 10.99 UNION ALL
-- Additional Hot Items
SELECT UUID_STRING(), 'Rotisserie Chicken Half', 'Prepared Foods', 'Entrees', 'Retail Kitchen', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Rotisserie Chicken Whole', 'Prepared Foods', 'Entrees', 'Retail Kitchen', NULL, 12.99 UNION ALL
SELECT UUID_STRING(), 'Mac and Cheese Bowl 12oz', 'Prepared Foods', 'Sides', 'Retail Kitchen', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Loaded Baked Potato with Cheese Bacon Sour Cream', 'Prepared Foods', 'Sides', 'Retail Kitchen', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Mashed Potatoes and Gravy 8oz', 'Prepared Foods', 'Sides', 'Retail Kitchen', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Coleslaw Cup 8oz', 'Prepared Foods', 'Sides', 'Retail Kitchen', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Potato Salad Cup 8oz', 'Prepared Foods', 'Sides', 'Retail Kitchen', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Corn on the Cob Butter', 'Prepared Foods', 'Sides', 'Retail Kitchen', NULL, 2.99 UNION ALL
-- Additional Soups
SELECT UUID_STRING(), 'French Onion Soup 12oz Bowl', 'Prepared Foods', 'Soup', 'Retail Kitchen', NULL, 6.49 UNION ALL
SELECT UUID_STRING(), 'Chicken Tortilla Soup 12oz Bowl', 'Prepared Foods', 'Soup', 'Retail Kitchen', NULL, 6.49 UNION ALL
SELECT UUID_STRING(), 'Loaded Baked Potato Soup 12oz Bowl', 'Prepared Foods', 'Soup', 'Retail Kitchen', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Minestrone Soup 12oz Bowl', 'Prepared Foods', 'Soup', 'Retail Kitchen', NULL, 5.49 UNION ALL
-- Additional Packaged
SELECT UUID_STRING(), 'Amy Kitchen Cheese Enchilada Meal 10oz', 'Prepared Foods', 'Packaged Meals', 'Amys', '042272000128', 5.99 UNION ALL
SELECT UUID_STRING(), 'Healthy Choice Power Bowl Chicken Fajita 9.3oz', 'Prepared Foods', 'Packaged Meals', 'Healthy Choice', '072655001013', 4.99 UNION ALL
SELECT UUID_STRING(), 'Lean Cuisine Herb Roasted Chicken 8oz', 'Prepared Foods', 'Packaged Meals', 'Lean Cuisine', '013800150011', 4.49 UNION ALL
SELECT UUID_STRING(), 'Stouffer Mac and Cheese 12oz', 'Prepared Foods', 'Packaged Meals', 'Stouffers', '013800100018', 4.99 UNION ALL
SELECT UUID_STRING(), 'Hot Pocket Pepperoni Pizza 4.5oz', 'Prepared Foods', 'Packaged Meals', 'Hot Pockets', '043695072013', 3.49 UNION ALL
SELECT UUID_STRING(), 'Hot Pocket Ham and Cheese 4.5oz', 'Prepared Foods', 'Packaged Meals', 'Hot Pockets', '043695072020', 3.49;


