CREATE VIEW vw_product_orders AS
SELECT
    oi.product_id,
    COUNT(DISTINCT o.order_id) AS orders_containing_product
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'Completed'
  AND o.payment_status = 'Paid'
GROUP BY oi.product_id;
