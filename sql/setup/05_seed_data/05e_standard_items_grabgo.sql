-- ============================================================================
-- Retail Data Harmonization Demo
-- Script: sql/setup/05_seed_data/05e_standard_items_grabgo.sql
-- Purpose: Additional STANDARD_ITEMS - Grab-n-go, Breakfast, Healthy (~182 items)
-- Depends on: 02_schema_and_tables.sql
-- ============================================================================

USE ROLE HARMONIZER_DEMO_ROLE;
USE DATABASE HARMONIZER_DEMO;
USE WAREHOUSE HARMONIZER_DEMO_WH;

-- ============================================================================
-- STANDARD_ITEMS: Grab-n-Go Items (~50 items)
-- ============================================================================

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
SELECT UUID_STRING(), 'Turkey and Cheddar Protein Box', 'Grab-n-Go', 'Protein Box', 'Retail Fresh', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Ham and Swiss Protein Box', 'Grab-n-Go', 'Protein Box', 'Retail Fresh', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Salad Protein Box', 'Grab-n-Go', 'Protein Box', 'Retail Fresh', NULL, 9.49 UNION ALL
SELECT UUID_STRING(), 'Hummus and Veggie Snack Box', 'Grab-n-Go', 'Snack Box', 'Retail Fresh', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'Cheese and Crackers Snack Box', 'Grab-n-Go', 'Snack Box', 'Retail Fresh', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'PB&J Snack Box with Apple', 'Grab-n-Go', 'Snack Box', 'Retail Fresh', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Mediterranean Snack Box Feta Olives', 'Grab-n-Go', 'Snack Box', 'Retail Fresh', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Caprese Salad Cup Mozzarella Tomato Basil', 'Grab-n-Go', 'Fresh Salad', 'Retail Fresh', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'Quinoa Salad Cup with Vegetables', 'Grab-n-Go', 'Fresh Salad', 'Retail Fresh', NULL, 7.49 UNION ALL
SELECT UUID_STRING(), 'Pasta Salad Cup Italian', 'Grab-n-Go', 'Fresh Salad', 'Retail Fresh', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Salad Cup on Lettuce', 'Grab-n-Go', 'Fresh Salad', 'Retail Fresh', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Egg Salad Cup on Lettuce', 'Grab-n-Go', 'Fresh Salad', 'Retail Fresh', NULL, 6.49 UNION ALL
SELECT UUID_STRING(), 'Fresh Cut Fruit Cup Mixed 12oz', 'Grab-n-Go', 'Fresh Fruit', 'Retail Fresh', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Fresh Cut Melon Cup 12oz', 'Grab-n-Go', 'Fresh Fruit', 'Retail Fresh', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Fresh Berry Cup Strawberry Blueberry 8oz', 'Grab-n-Go', 'Fresh Fruit', 'Retail Fresh', NULL, 6.49 UNION ALL
SELECT UUID_STRING(), 'Apple Slices with Caramel Dip', 'Grab-n-Go', 'Fresh Fruit', 'Retail Fresh', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Celery Sticks with Peanut Butter Cup', 'Grab-n-Go', 'Fresh Veggie', 'Retail Fresh', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Carrot Sticks with Ranch Cup', 'Grab-n-Go', 'Fresh Veggie', 'Retail Fresh', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Veggie Snack Cup Carrots Celery Broccoli', 'Grab-n-Go', 'Fresh Veggie', 'Retail Fresh', NULL, 4.49 UNION ALL
SELECT UUID_STRING(), 'Hard Boiled Eggs 2 Pack', 'Grab-n-Go', 'Protein', 'Retail Fresh', NULL, 2.99 UNION ALL
SELECT UUID_STRING(), 'String Cheese 2 Pack', 'Grab-n-Go', 'Protein', 'Sargento', '046100001011', 2.49 UNION ALL
SELECT UUID_STRING(), 'Babybel Original Cheese 3 Pack', 'Grab-n-Go', 'Protein', 'Babybel', '041757000011', 3.99 UNION ALL
SELECT UUID_STRING(), 'Lunchables Turkey and Cheddar', 'Grab-n-Go', 'Lunchables', 'Oscar Mayer', '044700031483', 4.99 UNION ALL
SELECT UUID_STRING(), 'Lunchables Ham and American', 'Grab-n-Go', 'Lunchables', 'Oscar Mayer', '044700031490', 4.99 UNION ALL
SELECT UUID_STRING(), 'Lunchables Pizza Pepperoni', 'Grab-n-Go', 'Lunchables', 'Oscar Mayer', '044700031506', 4.99;

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
SELECT UUID_STRING(), 'Deli Turkey Breast Sliced 8oz', 'Grab-n-Go', 'Deli Meat', 'Retail Fresh', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'Deli Ham Sliced 8oz', 'Grab-n-Go', 'Deli Meat', 'Retail Fresh', NULL, 6.49 UNION ALL
SELECT UUID_STRING(), 'Deli Roast Beef Sliced 6oz', 'Grab-n-Go', 'Deli Meat', 'Retail Fresh', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Sushi California Roll 8pc', 'Grab-n-Go', 'Sushi', 'Retail Fresh', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'Sushi Spicy Tuna Roll 6pc', 'Grab-n-Go', 'Sushi', 'Retail Fresh', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'Sushi Vegetable Roll 8pc', 'Grab-n-Go', 'Sushi', 'Retail Fresh', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Sushi Combo Platter California Spicy Tuna', 'Grab-n-Go', 'Sushi', 'Retail Fresh', NULL, 14.99 UNION ALL
SELECT UUID_STRING(), 'Chicken Wrap Caesar To-Go', 'Grab-n-Go', 'Wrap', 'Retail Fresh', NULL, 8.49 UNION ALL
SELECT UUID_STRING(), 'Turkey Club Wrap To-Go', 'Grab-n-Go', 'Wrap', 'Retail Fresh', NULL, 8.49 UNION ALL
SELECT UUID_STRING(), 'Veggie Wrap Hummus Spinach To-Go', 'Grab-n-Go', 'Wrap', 'Retail Fresh', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'BLT Wrap To-Go', 'Grab-n-Go', 'Wrap', 'Retail Fresh', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Croissant Ham and Cheese', 'Grab-n-Go', 'Bakery', 'Retail Fresh', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Croissant Turkey and Swiss', 'Grab-n-Go', 'Bakery', 'Retail Fresh', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Croissant Butter Plain', 'Grab-n-Go', 'Bakery', 'Retail Fresh', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Croissant Chocolate Filled', 'Grab-n-Go', 'Bakery', 'Retail Fresh', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Pretzel Soft Salted', 'Grab-n-Go', 'Bakery', 'Retail Fresh', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Pretzel Soft with Cheese Cup', 'Grab-n-Go', 'Bakery', 'Retail Fresh', NULL, 4.99 UNION ALL
SELECT UUID_STRING(), 'Cookie Fresh Baked Chocolate Chip', 'Grab-n-Go', 'Bakery', 'Retail Fresh', NULL, 2.49 UNION ALL
SELECT UUID_STRING(), 'Cookie Fresh Baked Oatmeal Raisin', 'Grab-n-Go', 'Bakery', 'Retail Fresh', NULL, 2.49 UNION ALL
SELECT UUID_STRING(), 'Cookie Fresh Baked Double Chocolate', 'Grab-n-Go', 'Bakery', 'Retail Fresh', NULL, 2.49;

-- ============================================================================
-- STANDARD_ITEMS: Breakfast Items (~50 items)
-- ============================================================================

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
SELECT UUID_STRING(), 'Breakfast Platter Eggs Bacon Toast', 'Breakfast', 'Hot Breakfast', 'Retail Kitchen', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Breakfast Platter Eggs Sausage Hash Browns', 'Breakfast', 'Hot Breakfast', 'Retail Kitchen', NULL, 9.49 UNION ALL
SELECT UUID_STRING(), 'Pancake Stack 3 with Syrup and Butter', 'Breakfast', 'Hot Breakfast', 'Retail Kitchen', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'Waffle Belgian with Syrup and Butter', 'Breakfast', 'Hot Breakfast', 'Retail Kitchen', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'French Toast Sticks 5pc with Syrup', 'Breakfast', 'Hot Breakfast', 'Retail Kitchen', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Scrambled Eggs with Cheese', 'Breakfast', 'Hot Breakfast', 'Retail Kitchen', NULL, 4.99 UNION ALL
SELECT UUID_STRING(), 'Scrambled Eggs with Bacon', 'Breakfast', 'Hot Breakfast', 'Retail Kitchen', NULL, 6.49 UNION ALL
SELECT UUID_STRING(), 'Bacon Strip 3pc', 'Breakfast', 'Hot Breakfast', 'Retail Kitchen', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Sausage Links 3pc', 'Breakfast', 'Hot Breakfast', 'Retail Kitchen', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Sausage Patties 2pc', 'Breakfast', 'Hot Breakfast', 'Retail Kitchen', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Hash Browns Golden Crispy', 'Breakfast', 'Hot Breakfast', 'Retail Kitchen', NULL, 2.99 UNION ALL
SELECT UUID_STRING(), 'Home Fries Seasoned', 'Breakfast', 'Hot Breakfast', 'Retail Kitchen', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Toast White or Wheat 2 Slices', 'Breakfast', 'Hot Breakfast', 'Retail Kitchen', NULL, 1.99 UNION ALL
SELECT UUID_STRING(), 'Biscuit with Butter', 'Breakfast', 'Hot Breakfast', 'Retail Kitchen', NULL, 2.49 UNION ALL
SELECT UUID_STRING(), 'Biscuit with Sausage Gravy', 'Breakfast', 'Hot Breakfast', 'Retail Kitchen', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Breakfast Sandwich Egg Cheese Biscuit', 'Breakfast', 'Breakfast Sandwich', 'Retail Kitchen', NULL, 4.99 UNION ALL
SELECT UUID_STRING(), 'Breakfast Sandwich Egg Cheese English Muffin', 'Breakfast', 'Breakfast Sandwich', 'Retail Kitchen', NULL, 4.49 UNION ALL
SELECT UUID_STRING(), 'Breakfast Sandwich Sausage Egg Cheese Biscuit', 'Breakfast', 'Breakfast Sandwich', 'Retail Kitchen', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Breakfast Sandwich Bacon Egg Cheese Bagel', 'Breakfast', 'Breakfast Sandwich', 'Retail Kitchen', NULL, 6.49 UNION ALL
SELECT UUID_STRING(), 'Breakfast Wrap Scrambled Egg Cheese', 'Breakfast', 'Breakfast Wrap', 'Retail Kitchen', NULL, 5.49;

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
SELECT UUID_STRING(), 'Breakfast Wrap Bacon Egg Cheese', 'Breakfast', 'Breakfast Wrap', 'Retail Kitchen', NULL, 6.49 UNION ALL
SELECT UUID_STRING(), 'Breakfast Wrap Sausage Egg Cheese', 'Breakfast', 'Breakfast Wrap', 'Retail Kitchen', NULL, 6.49 UNION ALL
SELECT UUID_STRING(), 'Breakfast Wrap Veggie Egg White Spinach', 'Breakfast', 'Breakfast Wrap', 'Retail Kitchen', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'Bagel Plain', 'Breakfast', 'Bakery', 'Retail Kitchen', NULL, 2.49 UNION ALL
SELECT UUID_STRING(), 'Bagel Everything', 'Breakfast', 'Bakery', 'Retail Kitchen', NULL, 2.49 UNION ALL
SELECT UUID_STRING(), 'Bagel Cinnamon Raisin', 'Breakfast', 'Bakery', 'Retail Kitchen', NULL, 2.49 UNION ALL
SELECT UUID_STRING(), 'Bagel with Butter', 'Breakfast', 'Bakery', 'Retail Kitchen', NULL, 3.29 UNION ALL
SELECT UUID_STRING(), 'Bagel with Cream Cheese Plain', 'Breakfast', 'Bakery', 'Retail Kitchen', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Bagel with Cream Cheese Veggie', 'Breakfast', 'Bakery', 'Retail Kitchen', NULL, 4.49 UNION ALL
SELECT UUID_STRING(), 'Bagel with Lox and Cream Cheese', 'Breakfast', 'Bakery', 'Retail Kitchen', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Muffin Blueberry Large', 'Breakfast', 'Bakery', 'Retail Kitchen', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Muffin Banana Nut Large', 'Breakfast', 'Bakery', 'Retail Kitchen', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Muffin Corn Large', 'Breakfast', 'Bakery', 'Retail Kitchen', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Muffin Double Chocolate Large', 'Breakfast', 'Bakery', 'Retail Kitchen', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Muffin Lemon Poppy Seed Large', 'Breakfast', 'Bakery', 'Retail Kitchen', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Donut Glazed', 'Breakfast', 'Bakery', 'Retail Kitchen', NULL, 2.49 UNION ALL
SELECT UUID_STRING(), 'Donut Chocolate Frosted', 'Breakfast', 'Bakery', 'Retail Kitchen', NULL, 2.99 UNION ALL
SELECT UUID_STRING(), 'Donut Powdered Sugar', 'Breakfast', 'Bakery', 'Retail Kitchen', NULL, 2.49 UNION ALL
SELECT UUID_STRING(), 'Donut Cinnamon Sugar', 'Breakfast', 'Bakery', 'Retail Kitchen', NULL, 2.49 UNION ALL
SELECT UUID_STRING(), 'Donut Boston Cream', 'Breakfast', 'Bakery', 'Retail Kitchen', NULL, 3.49;

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
SELECT UUID_STRING(), 'Donut Jelly Filled', 'Breakfast', 'Bakery', 'Retail Kitchen', NULL, 2.99 UNION ALL
SELECT UUID_STRING(), 'Danish Apple', 'Breakfast', 'Bakery', 'Retail Kitchen', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Danish Cherry', 'Breakfast', 'Bakery', 'Retail Kitchen', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Scone Blueberry', 'Breakfast', 'Bakery', 'Retail Kitchen', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Scone Cranberry Orange', 'Breakfast', 'Bakery', 'Retail Kitchen', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Oatmeal Cup Instant Apple Cinnamon', 'Breakfast', 'Hot Cereal', 'Quaker', '030000010655', 2.99 UNION ALL
SELECT UUID_STRING(), 'Oatmeal Cup Instant Maple Brown Sugar', 'Breakfast', 'Hot Cereal', 'Quaker', '030000010662', 2.99 UNION ALL
SELECT UUID_STRING(), 'Greek Yogurt Cup Strawberry 5.3oz', 'Breakfast', 'Yogurt', 'Chobani', '818290011015', 2.49 UNION ALL
SELECT UUID_STRING(), 'Greek Yogurt Cup Blueberry 5.3oz', 'Breakfast', 'Yogurt', 'Chobani', '818290011022', 2.49 UNION ALL
SELECT UUID_STRING(), 'Greek Yogurt Cup Vanilla 5.3oz', 'Breakfast', 'Yogurt', 'Chobani', '818290011039', 2.49;

-- ============================================================================
-- STANDARD_ITEMS: Healthy Options (~50 items)
-- ============================================================================

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
SELECT UUID_STRING(), 'Acai Bowl with Granola and Berries', 'Healthy', 'Bowls', 'Retail Fresh', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'Smoothie Bowl Tropical Mango Coconut', 'Healthy', 'Bowls', 'Retail Fresh', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Grain Bowl Chicken Mediterranean', 'Healthy', 'Bowls', 'Retail Fresh', NULL, 11.99 UNION ALL
SELECT UUID_STRING(), 'Grain Bowl Salmon Teriyaki', 'Healthy', 'Bowls', 'Retail Fresh', NULL, 13.99 UNION ALL
SELECT UUID_STRING(), 'Grain Bowl Tofu Asian', 'Healthy', 'Bowls', 'Retail Fresh', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'Buddha Bowl Chickpea Vegetable', 'Healthy', 'Bowls', 'Retail Fresh', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'Poke Bowl Tuna Sesame', 'Healthy', 'Bowls', 'Retail Fresh', NULL, 14.99 UNION ALL
SELECT UUID_STRING(), 'Poke Bowl Salmon Avocado', 'Healthy', 'Bowls', 'Retail Fresh', NULL, 14.99 UNION ALL
SELECT UUID_STRING(), 'Salad Kale Caesar with Chicken', 'Healthy', 'Salads', 'Retail Fresh', NULL, 11.99 UNION ALL
SELECT UUID_STRING(), 'Salad Spinach Strawberry Goat Cheese', 'Healthy', 'Salads', 'Retail Fresh', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'Salad Power Greens Quinoa Avocado', 'Healthy', 'Salads', 'Retail Fresh', NULL, 11.49 UNION ALL
SELECT UUID_STRING(), 'Salad Superfood Kale Beet Chickpea', 'Healthy', 'Salads', 'Retail Fresh', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'Wrap Grilled Chicken Spinach', 'Healthy', 'Wraps', 'Retail Fresh', NULL, 9.49 UNION ALL
SELECT UUID_STRING(), 'Wrap Turkey Avocado Whole Wheat', 'Healthy', 'Wraps', 'Retail Fresh', NULL, 9.49 UNION ALL
SELECT UUID_STRING(), 'Wrap Veggie Rainbow Hummus', 'Healthy', 'Wraps', 'Retail Fresh', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Wrap Mediterranean Falafel', 'Healthy', 'Wraps', 'Retail Fresh', NULL, 9.49 UNION ALL
SELECT UUID_STRING(), 'Sandwich Turkey Avocado Whole Grain', 'Healthy', 'Sandwiches', 'Retail Fresh', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'Sandwich Grilled Chicken Pesto', 'Healthy', 'Sandwiches', 'Retail Fresh', NULL, 9.99 UNION ALL
SELECT UUID_STRING(), 'Sandwich Veggie Hummus Whole Wheat', 'Healthy', 'Sandwiches', 'Retail Fresh', NULL, 8.49 UNION ALL
SELECT UUID_STRING(), 'Soup Vegetable Minestrone 12oz', 'Healthy', 'Soups', 'Retail Kitchen', NULL, 5.49;

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
SELECT UUID_STRING(), 'Soup Lentil Vegetarian 12oz', 'Healthy', 'Soups', 'Retail Kitchen', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Soup Black Bean Low Sodium 12oz', 'Healthy', 'Soups', 'Retail Kitchen', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Soup Chicken Vegetable Low Sodium 12oz', 'Healthy', 'Soups', 'Retail Kitchen', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Smoothie Green Power Spinach Kale Banana', 'Healthy', 'Smoothies', 'Retail Fresh', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'Smoothie Berry Blast Mixed Berry', 'Healthy', 'Smoothies', 'Retail Fresh', NULL, 6.49 UNION ALL
SELECT UUID_STRING(), 'Smoothie Tropical Paradise Mango Pineapple', 'Healthy', 'Smoothies', 'Retail Fresh', NULL, 6.49 UNION ALL
SELECT UUID_STRING(), 'Smoothie Protein Chocolate Peanut Butter', 'Healthy', 'Smoothies', 'Retail Fresh', NULL, 7.49 UNION ALL
SELECT UUID_STRING(), 'Juice Fresh Pressed Orange 16oz', 'Healthy', 'Juices', 'Retail Fresh', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Juice Fresh Pressed Apple 16oz', 'Healthy', 'Juices', 'Retail Fresh', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Juice Fresh Pressed Carrot Ginger 16oz', 'Healthy', 'Juices', 'Retail Fresh', NULL, 6.49 UNION ALL
SELECT UUID_STRING(), 'Juice Fresh Pressed Green Detox 16oz', 'Healthy', 'Juices', 'Retail Fresh', NULL, 7.49 UNION ALL
SELECT UUID_STRING(), 'Protein Bar RXBAR Peanut Butter 1.83oz', 'Healthy', 'Protein Bars', 'RXBAR', '857777004027', 2.99 UNION ALL
SELECT UUID_STRING(), 'Protein Bar Perfect Bar Dark Chocolate 2.5oz', 'Healthy', 'Protein Bars', 'Perfect Bar', '854832005011', 3.49 UNION ALL
SELECT UUID_STRING(), 'Protein Bar Think Thin Brownie Crunch', 'Healthy', 'Protein Bars', 'Think Thin', '753656710112', 2.99 UNION ALL
SELECT UUID_STRING(), 'Protein Bar ONE Peanut Butter Pie', 'Healthy', 'Protein Bars', 'ONE', '788434101011', 2.99 UNION ALL
SELECT UUID_STRING(), 'Veggie Chips Sea Salt 1oz', 'Healthy', 'Chips', 'Terra', '728229010012', 2.49 UNION ALL
SELECT UUID_STRING(), 'Rice Cakes Lightly Salted 2pk', 'Healthy', 'Snacks', 'Quaker', '030000312100', 1.99 UNION ALL
SELECT UUID_STRING(), 'Seaweed Snack Wasabi 0.35oz', 'Healthy', 'Snacks', 'gimMe', '851093004011', 1.99 UNION ALL
SELECT UUID_STRING(), 'Edamame Cup Steamed Salted 4oz', 'Healthy', 'Snacks', 'Retail Fresh', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Cottage Cheese Cup Low Fat 5.3oz', 'Healthy', 'Dairy', 'Good Culture', '851420005001', 2.99;

-- ============================================================================
-- STANDARD_ITEMS: Additional Grab-n-Go and Convenience (~50 items)
-- ============================================================================

INSERT INTO HARMONIZER_DEMO.RAW.STANDARD_ITEMS (STANDARD_ITEM_ID, STANDARD_DESCRIPTION, CATEGORY, SUBCATEGORY, BRAND, UPC, SRP)
-- More Grab-n-Go Snack Packs
SELECT UUID_STRING(), 'Snack Pack Pretzels and Hummus', 'Grab-n-Go', 'Snack Box', 'Retail Fresh', NULL, 4.99 UNION ALL
SELECT UUID_STRING(), 'Snack Pack Apple Slices PB and Granola', 'Grab-n-Go', 'Snack Box', 'Retail Fresh', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Snack Pack Grapes Cheese and Crackers', 'Grab-n-Go', 'Snack Box', 'Retail Fresh', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Snack Pack Trail Mix and Dried Fruit', 'Grab-n-Go', 'Snack Box', 'Retail Fresh', NULL, 4.99 UNION ALL
SELECT UUID_STRING(), 'Snack Pack Veggies Ranch and Pretzels', 'Grab-n-Go', 'Snack Box', 'Retail Fresh', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Antipasto Cup Salami Cheese Olive', 'Grab-n-Go', 'Snack Box', 'Retail Fresh', NULL, 7.99 UNION ALL
-- Additional Sushi
SELECT UUID_STRING(), 'Sushi Dragon Roll 8pc', 'Grab-n-Go', 'Sushi', 'Retail Fresh', NULL, 12.99 UNION ALL
SELECT UUID_STRING(), 'Sushi Salmon Avocado Roll 6pc', 'Grab-n-Go', 'Sushi', 'Retail Fresh', NULL, 11.99 UNION ALL
SELECT UUID_STRING(), 'Sushi Shrimp Tempura Roll 6pc', 'Grab-n-Go', 'Sushi', 'Retail Fresh', NULL, 11.99 UNION ALL
SELECT UUID_STRING(), 'Sushi Rainbow Roll 8pc', 'Grab-n-Go', 'Sushi', 'Retail Fresh', NULL, 13.99 UNION ALL
SELECT UUID_STRING(), 'Sushi Spicy Salmon Roll 6pc', 'Grab-n-Go', 'Sushi', 'Retail Fresh', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'Sushi Edamame Side 4oz', 'Grab-n-Go', 'Sushi', 'Retail Fresh', NULL, 3.99 UNION ALL
-- Additional Breakfast
SELECT UUID_STRING(), 'Breakfast Croissant Egg and Cheese', 'Breakfast', 'Breakfast Sandwich', 'Retail Kitchen', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Breakfast Burrito Veggie Egg White', 'Breakfast', 'Breakfast Wrap', 'Retail Kitchen', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'Breakfast Bowl Scrambled Eggs Hash Browns Cheese', 'Breakfast', 'Hot Breakfast', 'Retail Kitchen', NULL, 7.49 UNION ALL
SELECT UUID_STRING(), 'Avocado Toast on Sourdough with Everything Seasoning', 'Breakfast', 'Hot Breakfast', 'Retail Kitchen', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Overnight Oats Strawberry 8oz', 'Breakfast', 'Hot Cereal', 'Retail Fresh', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Greek Yogurt Cup Peach 5.3oz', 'Breakfast', 'Yogurt', 'Chobani', '818290011046', 2.49 UNION ALL
SELECT UUID_STRING(), 'Greek Yogurt Cup Mango 5.3oz', 'Breakfast', 'Yogurt', 'Chobani', '818290011053', 2.49 UNION ALL
SELECT UUID_STRING(), 'Greek Yogurt Cup Plain Nonfat 5.3oz', 'Breakfast', 'Yogurt', 'Chobani', '818290011060', 2.49 UNION ALL
SELECT UUID_STRING(), 'Greek Yogurt Cup Mixed Berry 5.3oz', 'Breakfast', 'Yogurt', 'Fage', '689544001015', 2.79 UNION ALL
SELECT UUID_STRING(), 'Siggi Icelandic Yogurt Vanilla 5.3oz', 'Breakfast', 'Yogurt', 'Siggis', '898999010018', 2.99 UNION ALL
-- Additional Healthy
SELECT UUID_STRING(), 'Salad Asian Chicken Sesame Ginger', 'Healthy', 'Salads', 'Retail Fresh', NULL, 11.49 UNION ALL
SELECT UUID_STRING(), 'Salad Southwest Black Bean Corn Avocado', 'Healthy', 'Salads', 'Retail Fresh', NULL, 10.99 UNION ALL
SELECT UUID_STRING(), 'Salad Harvest Chicken Apple Walnut', 'Healthy', 'Salads', 'Retail Fresh', NULL, 11.49 UNION ALL
SELECT UUID_STRING(), 'Salad Cobb Avocado Egg Bacon', 'Healthy', 'Salads', 'Retail Fresh', NULL, 11.99 UNION ALL
SELECT UUID_STRING(), 'Wrap Thai Chicken Peanut', 'Healthy', 'Wraps', 'Retail Fresh', NULL, 9.49 UNION ALL
SELECT UUID_STRING(), 'Wrap Grilled Veggie Goat Cheese', 'Healthy', 'Wraps', 'Retail Fresh', NULL, 8.99 UNION ALL
SELECT UUID_STRING(), 'Soup Tomato Roasted Red Pepper 12oz', 'Healthy', 'Soups', 'Retail Kitchen', NULL, 5.49 UNION ALL
SELECT UUID_STRING(), 'Soup Thai Coconut Chicken 12oz', 'Healthy', 'Soups', 'Retail Kitchen', NULL, 6.49 UNION ALL
SELECT UUID_STRING(), 'Soup Butternut Squash 12oz', 'Healthy', 'Soups', 'Retail Kitchen', NULL, 5.99 UNION ALL
SELECT UUID_STRING(), 'Smoothie Acai Berry Banana', 'Healthy', 'Smoothies', 'Retail Fresh', NULL, 6.99 UNION ALL
SELECT UUID_STRING(), 'Smoothie PB Banana Protein', 'Healthy', 'Smoothies', 'Retail Fresh', NULL, 7.49 UNION ALL
SELECT UUID_STRING(), 'Juice Cold Pressed Beet Apple Ginger 16oz', 'Healthy', 'Juices', 'Retail Fresh', NULL, 7.49 UNION ALL
SELECT UUID_STRING(), 'Juice Cold Pressed Celery 16oz', 'Healthy', 'Juices', 'Retail Fresh', NULL, 7.99 UNION ALL
SELECT UUID_STRING(), 'Protein Bar KIND Protein Dark Chocolate Nut 1.76oz', 'Healthy', 'Protein Bars', 'KIND', '602652170041', 2.99 UNION ALL
SELECT UUID_STRING(), 'Protein Bar GoMacro Sunflower Butter Chocolate 2.3oz', 'Healthy', 'Protein Bars', 'GoMacro', '181945000118', 3.29 UNION ALL
SELECT UUID_STRING(), 'Protein Bar Aloha Chocolate Chip Cookie Dough 1.98oz', 'Healthy', 'Protein Bars', 'Aloha', '842096100015', 2.99 UNION ALL
SELECT UUID_STRING(), 'Turkey Jerky Original 1oz Bag', 'Healthy', 'Snacks', 'Country Archer', '853016002029', 3.99 UNION ALL
SELECT UUID_STRING(), 'Kale Chips Sea Salt and Vinegar 2oz', 'Healthy', 'Chips', 'Brad', '852079004015', 3.99 UNION ALL
SELECT UUID_STRING(), 'Coconut Chips Toasted Original 1.4oz', 'Healthy', 'Snacks', 'Dang', '859908003012', 2.99 UNION ALL
SELECT UUID_STRING(), 'Freeze Dried Fruit Strawberry 1oz', 'Healthy', 'Snacks', 'Natierra', '812907011016', 3.49 UNION ALL
SELECT UUID_STRING(), 'Dark Chocolate Almonds 1.5oz Bag', 'Healthy', 'Snacks', 'Skinny Dipped', '860003000018', 3.49 UNION ALL
SELECT UUID_STRING(), 'Energy Bites Chocolate PB 3 Pack', 'Healthy', 'Snacks', 'Retail Fresh', NULL, 4.49 UNION ALL
SELECT UUID_STRING(), 'Avocado Cup with Sea Salt 4oz', 'Healthy', 'Snacks', 'Retail Fresh', NULL, 3.99 UNION ALL
SELECT UUID_STRING(), 'Mixed Nuts Unsalted 1.5oz Bag', 'Healthy', 'Snacks', 'Retail Fresh', NULL, 3.49 UNION ALL
SELECT UUID_STRING(), 'Dried Mango Slices 2oz Bag', 'Healthy', 'Snacks', 'Retail Fresh', NULL, 3.99;
