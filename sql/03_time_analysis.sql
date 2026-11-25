/* ============================================================
   TIME & GROWTH ANALYSIS
   ============================================================ */

CREATE OR ALTER VIEW vw_monthly AS
WITH Sales_Base AS (
    SELECT
        oi.order_item_id,
        o.order_id,
        o.order_date,
        oi.quantity,
        oi.quantity * oi.unit_price AS gross_sales,
        oi.quantity * oi.unit_price * oi.discount_pct / 100.0 AS discount_amount,
        oi.quantity * oi.unit_price
            - oi.quantity * oi.unit_price * oi.discount_pct / 100.0 AS net_sales,
        oi.quantity * oi.unit_price
            - oi.quantity * oi.unit_price * oi.discount_pct / 100.0
            + oi.tax_amount AS net_sales_incl_tax,
        oi.tax_amount
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'Completed'
      AND o.payment_status = 'Paid'
),
Monthly_Sales AS (
    SELECT
        YEAR(order_date) AS sales_year,
        MONTH(order_date) AS sales_month,
        CONCAT(YEAR(order_date), '-', RIGHT('0' + CAST(MONTH(order_date) AS varchar(2)), 2)) AS year_month_key,
        SUM(quantity) AS monthly_original_units_sold,
        SUM(gross_sales) AS monthly_gross_sales,
        SUM(discount_amount) AS monthly_discount_amount,
        SUM(net_sales) AS monthly_net_sales,
        SUM(tax_amount) AS monthly_tax_amount,
        SUM(net_sales_incl_tax) AS monthly_net_sales_incl_tax
    FROM Sales_Base
    GROUP BY YEAR(order_date), MONTH(order_date)
),
Monthly_Returns AS (
    SELECT
        YEAR(o.order_date) AS sales_year,
        MONTH(o.order_date) AS sales_month,
        CONCAT(YEAR(o.order_date), '-', RIGHT('0' + CAST(MONTH(o.order_date) AS varchar(2)), 2)) AS year_month_key,
        SUM(r.return_quantity) AS monthly_units_returned,
        SUM(r.refund_amount) AS monthly_refund_amount
    FROM returns r
    JOIN order_items oi ON oi.order_item_id = r.order_item_id
    JOIN orders o ON o.order_id = oi.order_id
    WHERE r.return_status = 'Approved'
      AND o.order_status = 'Completed'
      AND o.payment_status = 'Paid'
    GROUP BY YEAR(o.order_date), MONTH(o.order_date)
),
Monthly_Orders AS (
    SELECT
        YEAR(order_date) AS sales_year,
        MONTH(order_date) AS sales_month,
        CONCAT(YEAR(order_date), '-', RIGHT('0' + CAST(MONTH(order_date) AS varchar(2)), 2)) AS year_month_key,
        COUNT(DISTINCT order_id) AS monthly_completed_paid_orders
    FROM orders
    WHERE order_status = 'Completed' AND payment_status = 'Paid'
    GROUP BY YEAR(order_date), MONTH(order_date)
)
SELECT
    s.sales_year,
    s.sales_month,
    s.year_month_key,
    s.monthly_gross_sales,
    s.monthly_discount_amount,
    s.monthly_net_sales,
    s.monthly_tax_amount,
    s.monthly_net_sales_incl_tax,
    ISNULL(r.monthly_refund_amount, 0) AS monthly_refund_amount,
    s.monthly_original_units_sold,
    ISNULL(r.monthly_units_returned, 0) AS monthly_units_returned,
    s.monthly_original_units_sold - ISNULL(r.monthly_units_returned, 0) AS monthly_net_units_sold,
    s.monthly_net_sales_incl_tax - ISNULL(r.monthly_refund_amount, 0) AS monthly_net_sales_after_refund,
    o.monthly_completed_paid_orders,
    CASE WHEN o.monthly_completed_paid_orders = 0 THEN 0
         ELSE (s.monthly_net_sales_incl_tax - ISNULL(r.monthly_refund_amount, 0))
              / o.monthly_completed_paid_orders END AS monthly_average_order_value
FROM Monthly_Sales s
LEFT JOIN Monthly_Returns r ON s.year_month_key = r.year_month_key
LEFT JOIN Monthly_Orders o ON s.year_month_key = o.year_month_key;

-- Monthly revenue growth
SELECT
    sales_year,
    sales_month,
    monthly_net_sales_after_refund,
    ROUND(
        (monthly_net_sales_after_refund - LAG(monthly_net_sales_after_refund)
            OVER (ORDER BY sales_year, sales_month)) * 100.0
        / NULLIF(LAG(monthly_net_sales_after_refund)
            OVER (ORDER BY sales_year, sales_month), 0), 2
    ) AS mom_revenue_growth_pct
FROM vw_monthly
ORDER BY sales_year, sales_month;

-- Annual revenue and YoY
SELECT
    sales_year,
    SUM(monthly_net_sales_after_refund) AS annual_net_sales,
    ROUND(
        (SUM(monthly_net_sales_after_refund) - LAG(SUM(monthly_net_sales_after_refund))
            OVER (ORDER BY sales_year)) * 100.0
        / NULLIF(LAG(SUM(monthly_net_sales_after_refund))
            OVER (ORDER BY sales_year), 0), 2
    ) AS yoy_growth_pct
FROM vw_monthly
GROUP BY sales_year
ORDER BY sales_year;
