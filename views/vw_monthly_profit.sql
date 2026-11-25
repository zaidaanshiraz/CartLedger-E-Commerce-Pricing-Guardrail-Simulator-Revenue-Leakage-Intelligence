/* =====================================================================
   VIEW: vw_monthly_profit
   Author: Mohammed Zaidaan Shiraz
   Purpose: Monthly Revenue, COGS, Gross Profit & Weighted Margin Rollup
   ===================================================================== */
CREATE OR ALTER VIEW vw_monthly_profit AS
WITH profit_base AS (
    SELECT
        p.product_id,
        c.category_id,
        oi.order_item_id,
        o.order_id,
        o.order_date,
        oi.quantity,
        oi.unit_price,
        oi.discount_pct,
        p.cost_price,
        p.brand
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p     ON oi.product_id = p.product_id
    JOIN categories c   ON c.category_id = p.category_id
    WHERE o.order_status   = 'Completed'
      AND o.payment_status = 'Paid'
),
profit_revenue AS (
    SELECT
        product_id,
        order_id,
        order_item_id,
        category_id,
        quantity,
        YEAR(order_date)  AS sales_year,
        MONTH(order_date) AS sales_month,
        unit_price,
        discount_pct,
        cost_price,
        quantity * unit_price AS gross_sales,
        (quantity * unit_price * discount_pct) / 100.0 AS discount_amount,
        (quantity * unit_price) - (quantity * unit_price * discount_pct) / 100.0 AS net_revenue,
        quantity * cost_price AS cost_amount,
        ((quantity * unit_price) - (quantity * unit_price * discount_pct) / 100.0) - (quantity * cost_price) AS gross_profit
    FROM profit_base
),
monthly_profit AS (
    SELECT
        sales_year,
        sales_month,
        COUNT(DISTINCT order_id) AS no_orders,
        SUM(gross_sales)         AS gross_sales,
        SUM(discount_amount)     AS discount_amount,
        SUM(net_revenue)         AS netsales_bf_tax,
        SUM(cost_amount)         AS cost_amount,
        SUM(gross_profit)        AS gross_profit,
        SUM(quantity)            AS quantity
    FROM profit_revenue
    GROUP BY sales_year, sales_month
)
SELECT
    *,
    ROUND((gross_profit * 100.0) / NULLIF(netsales_bf_tax, 0), 2) AS profit_margin_pct
FROM monthly_profit;
