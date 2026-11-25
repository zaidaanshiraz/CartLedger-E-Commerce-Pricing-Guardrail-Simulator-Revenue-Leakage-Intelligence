/* ============================================================
   SALES KPI ANALYSIS
   Sale population: Completed + Paid orders
   ============================================================ */

WITH Sales_Base AS (
    SELECT
        oi.order_item_id,
        o.order_id,
        o.order_date,
        o.customer_id,
        oi.quantity,
        oi.quantity * oi.unit_price AS gross,
        oi.quantity * oi.unit_price * oi.discount_pct / 100.0 AS total_discount,
        oi.quantity * oi.unit_price
            - oi.quantity * oi.unit_price * oi.discount_pct / 100.0 AS net_sales,
        oi.quantity * oi.unit_price
            - oi.quantity * oi.unit_price * oi.discount_pct / 100.0
            + oi.tax_amount AS net_sales_including_tax,
        oi.tax_amount
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'Completed'
      AND o.payment_status = 'Paid'
),
Returns_By_Item AS (
    SELECT
        order_item_id,
        SUM(return_quantity) AS returned_units,
        SUM(refund_amount) AS refund_amount
    FROM returns
    WHERE return_status = 'Approved'
    GROUP BY order_item_id
),
Sales_KPIs AS (
    SELECT
        SUM(s.quantity) AS original_units,
        SUM(s.gross) AS gross_sales,
        SUM(s.total_discount) AS discount_amount,
        SUM(s.net_sales) AS net_sales_before_tax,
        SUM(s.tax_amount) AS tax_amount,
        SUM(s.net_sales_including_tax) AS net_sales_including_tax,
        SUM(ISNULL(r.returned_units, 0)) AS returned_units,
        SUM(ISNULL(r.refund_amount, 0)) AS refund_amount
    FROM Sales_Base s
    LEFT JOIN Returns_By_Item r ON s.order_item_id = r.order_item_id
)
SELECT
    gross_sales,
    discount_amount,
    net_sales_before_tax,
    tax_amount,
    net_sales_including_tax,
    returned_units,
    original_units - returned_units AS net_units_sold,
    refund_amount,
    net_sales_including_tax - refund_amount AS net_sales_after_refund,
    (SELECT COUNT(DISTINCT order_id)
     FROM orders
     WHERE order_status = 'Completed' AND payment_status = 'Paid') AS completed_paid_orders,
    (SELECT COUNT(DISTINCT order_id)
     FROM orders
     WHERE order_status = 'Cancelled' AND payment_status = 'Failed') AS cancelled_failed_orders,
    (SELECT COUNT(DISTINCT order_id)
     FROM orders
     WHERE order_status = 'Completed' AND payment_status = 'Pending') AS completed_pending_orders
FROM Sales_KPIs;
