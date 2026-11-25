/* =====================================================================
   VIEW: vw_product_profitability
   Author: Mohammed Zaidaan Shiraz
   Purpose: Product-level & Category-level Gross Margin and COGS Analysis
   Note: Computes weighted profit margin as SUM(gross_profit) / SUM(netsales_bf_tax)
         and preserves true distinct order grain per category.
   ===================================================================== */
CREATE OR ALTER VIEW vw_product_profitability AS
WITH profit_base AS (
    SELECT
        p.product_id,
        p.product_name,
        p.category_id,
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
    WHERE o.order_status   = 'Completed'
      AND o.payment_status = 'Paid'
),
profit_revenue AS (
    SELECT
        product_id,
        product_name,
        category_id,
        order_id,
        order_item_id,
        quantity,
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
product_profit AS (
    SELECT
        product_id,
        product_name,
        category_id,
        COUNT(DISTINCT order_id) AS no_orders,
        SUM(gross_sales)         AS gross_sales,
        SUM(discount_amount)     AS discount_amount,
        SUM(net_revenue)         AS netsales_bf_tax,
        SUM(cost_amount)         AS cost_amount,
        SUM(gross_profit)        AS gross_profit,
        SUM(quantity)            AS quantity
    FROM profit_revenue
    GROUP BY product_id, product_name, category_id
)
SELECT
    *,
    ROUND((gross_profit * 100.0) / NULLIF(netsales_bf_tax, 0), 2) AS profit_margin_pct
FROM product_profit;
