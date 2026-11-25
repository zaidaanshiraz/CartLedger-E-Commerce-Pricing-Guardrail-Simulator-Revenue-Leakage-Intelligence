CREATE VIEW vw_product_monthly AS
WITH item_refund AS (
    SELECT order_item_id, SUM(refund_amount) AS refund_amt
    FROM returns
    WHERE return_status = 'Approved'
    GROUP BY order_item_id
)
SELECT
    oi.product_id,
    YEAR(o.order_date)  AS order_year,
    MONTH(o.order_date) AS order_month,
    SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0) + oi.tax_amount)
        - SUM(ISNULL(ir.refund_amt, 0)) AS net_sales
FROM orders o
JOIN order_items oi     ON o.order_id = oi.order_id
LEFT JOIN item_refund ir ON ir.order_item_id = oi.order_item_id
WHERE o.order_status = 'Completed'
  AND o.payment_status = 'Paid'
GROUP BY oi.product_id, YEAR(o.order_date), MONTH(o.order_date);
