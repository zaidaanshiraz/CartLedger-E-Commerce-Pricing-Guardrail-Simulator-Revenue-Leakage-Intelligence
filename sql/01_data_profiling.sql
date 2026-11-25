/* ============================================================
   E-COMMERCE ANALYTICS - DATA PROFILING & QUALITY CHECKS
   SQL Server
   ============================================================ */

-- Row counts
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'categories', COUNT(*) FROM categories
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'payments', COUNT(*) FROM payments
UNION ALL SELECT 'returns', COUNT(*) FROM returns
UNION ALL SELECT 'reviews', COUNT(*) FROM reviews;

-- Order status / payment status validation
SELECT order_status, payment_status, COUNT(*) AS orders
FROM orders
GROUP BY order_status, payment_status
ORDER BY order_status, payment_status;

-- Duplicate primary-key checks
SELECT order_id, COUNT(*) AS duplicate_count
FROM orders GROUP BY order_id HAVING COUNT(*) > 1;

SELECT order_item_id, COUNT(*) AS duplicate_count
FROM order_items GROUP BY order_item_id HAVING COUNT(*) > 1;

SELECT customer_id, COUNT(*) AS duplicate_count
FROM customers GROUP BY customer_id HAVING COUNT(*) > 1;

-- Order-item validity checks
SELECT
    SUM(CASE WHEN quantity <= 0 THEN 1 ELSE 0 END) AS invalid_quantity,
    SUM(CASE WHEN unit_price <= 0 THEN 1 ELSE 0 END) AS invalid_unit_price,
    SUM(CASE WHEN discount_pct < 0 THEN 1 ELSE 0 END) AS invalid_discount,
    SUM(CASE WHEN tax_amount <= 0 THEN 1 ELSE 0 END) AS invalid_tax
FROM order_items;

-- Important nullable fields found during profiling
SELECT COUNT(*) AS customer_status_nulls
FROM customers
WHERE customer_status IS NULL;

SELECT COUNT(*) AS product_brand_nulls
FROM products
WHERE brand IS NULL;
