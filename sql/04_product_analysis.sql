/* =====================================================================
   PRODUCT ANALYSIS  (Questions 45 - 85)
   Conventions: snake_case aliases, p = products, v = vw_product_base,
                po = vw_product_orders
   Logic is unchanged from the original except where marked [FIXED].
   ===================================================================== */


/* =====================================================================
   SETUP 1: BASE VIEW (one row per product)
   ===================================================================== */
CREATE VIEW vw_product_base AS
WITH sales_base AS (
    SELECT
        p.product_id,
        oi.order_item_id,
        o.order_id,
        o.order_date,
        oi.quantity,
        oi.unit_price,
        oi.discount_pct,
        oi.tax_amount,
        p.cost_price,
        p.selling_price,
        p.category_id,
        p.brand
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p     ON oi.product_id = p.product_id
    WHERE o.order_status = 'Completed'
      AND o.payment_status = 'Paid'
),
revenue AS (
    SELECT
        product_id,
        SUM(quantity * unit_price)                                                        AS gross,
        SUM((quantity * unit_price * discount_pct) / 100)                                 AS discount_amount,
        SUM((quantity * unit_price) - (quantity * unit_price * discount_pct) / 100)       AS netsales_bf_tax,
        SUM(tax_amount)                                                                   AS tax_amount,
        SUM((quantity * unit_price) - (quantity * unit_price * discount_pct) / 100
            + tax_amount)                                                                 AS netsales_af_tax,
        SUM(quantity)                                                                     AS quantity
    FROM sales_base
    GROUP BY product_id
),
returns_by_product AS (
    SELECT
        oi.product_id,
        SUM(r.return_quantity) AS return_quantity,
        SUM(r.refund_amount)   AS refund_amt
    FROM returns r
    JOIN order_items oi ON oi.order_item_id = r.order_item_id
    JOIN orders o       ON o.order_id = oi.order_id
    WHERE r.return_status = 'Approved'
      AND o.order_status = 'Completed'
      AND o.payment_status = 'Paid'
    GROUP BY oi.product_id
),
product_performance AS (
    SELECT
        r.product_id,
        r.gross,
        r.discount_amount,
        r.netsales_bf_tax,
        r.netsales_af_tax,
        r.tax_amount,
        r.quantity,
        ISNULL(rp.return_quantity, 0) AS return_quantity,
        ISNULL(rp.refund_amt, 0)      AS refund_amt
    FROM revenue r
    LEFT JOIN returns_by_product rp ON r.product_id = rp.product_id
)
SELECT
    product_id,
    gross,
    discount_amount,
    netsales_bf_tax,
    netsales_af_tax,
    tax_amount,
    quantity,
    return_quantity,
    refund_amt,
    quantity - return_quantity                AS net_units_sold,
    netsales_af_tax - refund_amt              AS net_sales_after_refund,
    return_quantity * 100.0 / quantity        AS return_rate,
    discount_amount * 100.0 / gross           AS discount_rate
FROM product_performance;
GO


/* =====================================================================
   SETUP 2: ORDERS PER PRODUCT
   (your repeated "orders containing product" subquery, saved once)
   ===================================================================== */
CREATE VIEW vw_product_orders AS
SELECT
    oi.product_id,
    COUNT(DISTINCT o.order_id) AS orders_containing_product
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'Completed'
  AND o.payment_status = 'Paid'
GROUP BY oi.product_id;
GO


/* =====================================================================
   SETUP 3: PRODUCT x MONTH VIEW (needed for 83, 84, 85)
   Refunds are attributed to the month of the original order so the
   totals match net_sales_after_refund in vw_product_base.
   ===================================================================== */
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
GO


/* =====================================================================
   A. PRODUCT PERFORMANCE
   ===================================================================== */

-- 45. Total sales by product
SELECT p.product_name, v.product_id, v.netsales_af_tax AS total_sales
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id;

-- 46. Orders containing each product
SELECT product_id, orders_containing_product
FROM vw_product_orders;

-- 47. Units sold by product
SELECT p.product_name, v.product_id, v.quantity AS units_sold, v.net_units_sold
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id;

-- 48. Gross sales by product
SELECT p.product_name, v.product_id, v.gross AS gross_sales
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id;

-- 49. Discount amount by product
SELECT p.product_name, v.product_id, v.discount_amount
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id;

-- 50. Refund amount by product
SELECT p.product_name, v.product_id, v.refund_amt AS refund_amount
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id;

-- 51. Returned units by product
SELECT p.product_name, v.product_id, v.return_quantity AS returned_units
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id;

-- 52. Net sales after returns by product
SELECT p.product_name, v.product_id, v.net_sales_after_refund
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id;

-- 53. AOV / order value contribution by product
SELECT
    v.product_id,
    v.net_sales_after_refund / po.orders_containing_product AS aov_product
FROM vw_product_base v
JOIN vw_product_orders po ON po.product_id = v.product_id;


/* =====================================================================
   B. PRODUCT RANKING
   ===================================================================== */

-- 54. Top 10 products by net sales
SELECT TOP 10 p.product_name, v.*
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id
ORDER BY v.net_sales_after_refund DESC;

-- 55. Bottom 10 products by net sales
SELECT TOP 10 p.product_name, v.*
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id
ORDER BY v.net_sales_after_refund ASC;

-- 56. Top 10 products by units sold
SELECT TOP 10 p.product_name, v.product_id, v.net_units_sold
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id
ORDER BY v.net_units_sold DESC;

-- 56 (extra). Bottom 10 products by units sold
SELECT TOP 10 p.product_name, v.product_id, v.net_units_sold
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id
ORDER BY v.net_units_sold ASC;

-- 57. Top 10 products by refund amount
SELECT TOP 10
    p.product_name, v.product_id, v.refund_amt, v.return_quantity,
    v.net_sales_after_refund, v.return_rate
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id
ORDER BY v.refund_amt DESC;

-- 57 (extra). Bottom 10 products by refund amount
SELECT TOP 10
    p.product_name, v.product_id, v.refund_amt, v.return_quantity,
    v.net_sales_after_refund, v.return_rate
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id
ORDER BY v.refund_amt ASC;

-- 58. Top 10 products by returned units (minimum 100 units sold)
SELECT TOP 10
    p.product_name, v.product_id, v.quantity AS original_units_sold,
    v.refund_amt, v.return_quantity, v.net_sales_after_refund, v.return_rate
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id
WHERE v.quantity >= 100
ORDER BY v.return_quantity DESC;

-- 58 (extra). Bottom 10 products by returned units (minimum 100 units sold)
SELECT TOP 10
    p.product_name, v.product_id, v.quantity AS original_units_sold,
    v.refund_amt, v.return_quantity, v.net_sales_after_refund, v.return_rate
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id
WHERE v.quantity >= 100
ORDER BY v.return_quantity ASC;

-- 59. Top products by number of orders
SELECT TOP 10 po.product_id, po.orders_containing_product AS no_of_orders
FROM vw_product_orders po
ORDER BY po.orders_containing_product DESC;


/* =====================================================================
   C. PRODUCT EFFICIENCY
   ===================================================================== */

-- 60. Average selling price by product
SELECT
    product_id,
    netsales_bf_tax / quantity AS avg_net_selling_price,
    gross / quantity           AS avg_gross_selling_price
FROM vw_product_base;

-- 61. Average discount % by product
SELECT product_id, discount_amount / gross * 100 AS avg_discount_pct
FROM vw_product_base;

-- 62. Return rate by product
SELECT p.product_name, v.product_id, v.return_rate
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id
ORDER BY v.return_rate DESC;

-- 62 (extra). Return rate range
SELECT
    MIN(return_rate) AS min_return_rate,
    MAX(return_rate) AS max_return_rate,
    AVG(return_rate) AS avg_return_rate
FROM vw_product_base;

-- 62 (extra). Highest return rate (minimum 100 units sold)
SELECT TOP 10
    p.product_name, v.product_id, v.quantity AS original_units_sold,
    v.refund_amt, v.return_quantity, v.net_sales_after_refund, v.return_rate
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id
WHERE v.quantity >= 100
ORDER BY v.return_rate DESC;

-- 62 (extra). Lowest return rate (minimum 100 units sold)
SELECT TOP 10
    p.product_name, v.product_id, v.quantity AS original_units_sold,
    v.refund_amt, v.return_quantity, v.net_sales_after_refund, v.return_rate
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id
WHERE v.quantity >= 100
ORDER BY v.return_rate ASC;

-- 63. Sales per unit by product   [FIXED: divide-by-zero safe]
SELECT
    product_id,
    net_sales_after_refund / NULLIF(net_units_sold, 0) AS sales_per_unit
FROM vw_product_base;

-- 64. Orders-to-units relationship   [FIXED: 1.0 stops integer truncation]
SELECT
    v.product_id,
    po.orders_containing_product,
    v.net_units_sold,
    v.net_units_sold * 1.0 / NULLIF(po.orders_containing_product, 0) AS units_per_order
FROM vw_product_base v
JOIN vw_product_orders po ON po.product_id = v.product_id;


/* =====================================================================
   D. PRODUCT LIFECYCLE
   ===================================================================== */

-- 65. Sales by product launch year
SELECT
    YEAR(p.launch_date)        AS launch_year,
    SUM(v.net_sales_after_refund) AS net_sales
FROM vw_product_base v
JOIN products p ON p.product_id = v.product_id
GROUP BY YEAR(p.launch_date)
ORDER BY YEAR(p.launch_date);

-- 66. Sales by product launch month (year + month)
SELECT
    YEAR(p.launch_date)        AS launch_year,
    MONTH(p.launch_date)       AS launch_month,
    SUM(v.net_sales_after_refund) AS net_sales
FROM vw_product_base v
JOIN products p ON p.product_id = v.product_id
GROUP BY YEAR(p.launch_date), MONTH(p.launch_date)
ORDER BY YEAR(p.launch_date), MONTH(p.launch_date);

-- 66 (extra). Sales by launch month across all years
SELECT
    MONTH(p.launch_date)       AS launch_month,
    SUM(v.net_sales_after_refund) AS net_sales
FROM vw_product_base v
JOIN products p ON p.product_id = v.product_id
GROUP BY MONTH(p.launch_date)
ORDER BY MONTH(p.launch_date);

-- 67. New vs older product performance
WITH product_age_cte AS (
    SELECT
        CASE WHEN YEAR(p.launch_date) = (SELECT MAX(YEAR(launch_date)) FROM products)
             THEN 'New' ELSE 'Old' END AS product_age,
        v.net_sales_after_refund,
        v.net_units_sold,
        v.refund_amt
    FROM vw_product_base v
    JOIN products p ON p.product_id = v.product_id
)
SELECT
    product_age,
    SUM(net_sales_after_refund) AS net_sales,
    SUM(net_units_sold)         AS net_units_sold,
    COUNT(*)                    AS product_count,
    SUM(refund_amt)             AS refunds
FROM product_age_cte
GROUP BY product_age;

-- 68. Products with high sales but high return rates
SELECT
    p.product_name, v.product_id, v.net_sales_after_refund,
    v.return_rate, v.net_units_sold, v.refund_amt
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id
WHERE v.net_sales_after_refund > (SELECT AVG(net_sales_after_refund) FROM vw_product_base)
  AND v.return_rate            > (SELECT AVG(return_rate) FROM vw_product_base)
ORDER BY v.net_sales_after_refund DESC;

-- 69. Products with high units but low sales
SELECT
    p.product_name, v.product_id, v.net_sales_after_refund,
    v.return_rate, v.net_units_sold, v.refund_amt
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id
WHERE v.net_units_sold         > (SELECT AVG(net_units_sold) FROM vw_product_base)
  AND v.net_sales_after_refund < (SELECT AVG(net_sales_after_refund) FROM vw_product_base)
ORDER BY v.net_units_sold DESC;

-- 70. Products with low units but high sales
SELECT
    p.product_name, v.product_id, v.net_sales_after_refund,
    v.return_rate, v.net_units_sold, v.refund_amt
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id
WHERE v.net_units_sold         < (SELECT AVG(net_units_sold) FROM vw_product_base)
  AND v.net_sales_after_refund > (SELECT AVG(net_sales_after_refund) FROM vw_product_base)
ORDER BY v.net_units_sold DESC;


/* =====================================================================
   E. PRODUCT BUSINESS INVESTIGATION
   ===================================================================== */

-- 71. Products contributing the most to total sales %
SELECT
    p.product_name, v.product_id,
    v.net_sales_after_refund * 100.0
        / (SELECT SUM(net_sales_after_refund) FROM vw_product_base) AS sales_contribution_pct
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id
ORDER BY sales_contribution_pct DESC;

-- 72. Products contributing the most to total units %
SELECT
    p.product_name, v.product_id,
    v.net_units_sold * 100.0
        / (SELECT SUM(net_units_sold) FROM vw_product_base) AS units_contribution_pct
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id
ORDER BY units_contribution_pct DESC;

-- 73. Products generating significant refunds relative to sales
--     [FIXED: net_sales_after_refund already has the refund removed,
--      so the refund is now divided by sales before refund]
SELECT
    p.product_name, v.product_id,
    v.refund_amt * 100.0 / NULLIF(v.netsales_af_tax, 0) AS refund_pct_of_sales
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id
ORDER BY refund_pct_of_sales DESC;

-- 74. Products with unusually high discounts
--     [FIXED: added a threshold (average + 1 standard deviation)
--      so "unusual" is actually defined]
WITH discount_cte AS (
    SELECT product_id, discount_amount * 100.0 / NULLIF(gross, 0) AS discount_rate
    FROM vw_product_base
)
SELECT p.product_name, d.product_id, d.discount_rate
FROM discount_cte d
JOIN products p ON p.product_id = d.product_id
WHERE d.discount_rate > (SELECT AVG(discount_rate) + STDEV(discount_rate) FROM discount_cte)
ORDER BY d.discount_rate DESC;

-- 75. Products with high sales + high discount dependence
SELECT
    p.product_name, v.product_id, v.net_sales_after_refund,
    v.discount_amount,
    v.discount_amount * 100.0 / NULLIF(v.gross, 0) AS discount_rate
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id
WHERE v.net_sales_after_refund > (SELECT AVG(net_sales_after_refund) FROM vw_product_base)
  AND v.discount_amount * 100.0 / NULLIF(v.gross, 0) >
      (SELECT AVG(discount_amount * 100.0 / NULLIF(gross, 0)) FROM vw_product_base)
ORDER BY v.net_sales_after_refund DESC;

-- 76. Products with high sales + low return rate   [NEW]
SELECT
    p.product_name, v.product_id, v.net_sales_after_refund, v.return_rate
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id
WHERE v.net_sales_after_refund > (SELECT AVG(net_sales_after_refund) FROM vw_product_base)
  AND v.return_rate            < (SELECT AVG(return_rate) FROM vw_product_base)
ORDER BY v.net_sales_after_refund DESC;

-- 77. Products with low sales + high return rate   [NEW]
SELECT
    p.product_name, v.product_id, v.net_sales_after_refund, v.return_rate
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id
WHERE v.net_sales_after_refund < (SELECT AVG(net_sales_after_refund) FROM vw_product_base)
  AND v.return_rate            > (SELECT AVG(return_rate) FROM vw_product_base)
ORDER BY v.return_rate DESC;


/* =====================================================================
   F. ADVANCED PRODUCT ANALYSIS
   ===================================================================== */

-- 78. Rank products by sales
SELECT
    RANK() OVER (ORDER BY v.net_sales_after_refund DESC) AS sales_rank,
    p.product_name,
    v.*
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id
ORDER BY sales_rank;

-- 79. Rank products within their category
SELECT
    RANK() OVER (PARTITION BY p.category_id ORDER BY v.net_sales_after_refund DESC) AS rank_in_category,
    p.category_id,
    p.product_id,
    p.product_name,
    v.net_sales_after_refund
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id
ORDER BY p.category_id, rank_in_category;

-- 80. Running sales contribution by product
--     [FIXED: ROWS frame + product_id tie-breaker so tied sales
--      do not share the same running total]
SELECT
    p.product_id,
    p.product_name,
    v.net_sales_after_refund AS sales,
    SUM(v.net_sales_after_refund) OVER (
        ORDER BY v.net_sales_after_refund DESC, v.product_id
        ROWS UNBOUNDED PRECEDING) AS running_sales
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id
ORDER BY sales DESC, p.product_id;

-- 81. Product cumulative % of total sales   [FIXED: same as 80]
SELECT
    p.product_id,
    p.product_name,
    v.net_sales_after_refund AS sales,
    SUM(v.net_sales_after_refund) OVER (
        ORDER BY v.net_sales_after_refund DESC, v.product_id
        ROWS UNBOUNDED PRECEDING) * 100.0
        / SUM(v.net_sales_after_refund) OVER () AS cumulative_pct
FROM vw_product_base v
JOIN products p ON v.product_id = p.product_id
ORDER BY sales DESC, p.product_id;

-- 82. Products contributing to the first 80% of sales
--     [FIXED: keeps the product that crosses 80% (previously dropped)]
WITH running_cte AS (
    SELECT
        p.product_id,
        p.product_name,
        v.net_sales_after_refund AS sales,
        SUM(v.net_sales_after_refund) OVER (
            ORDER BY v.net_sales_after_refund DESC, v.product_id
            ROWS UNBOUNDED PRECEDING) AS running_sales,
        SUM(v.net_sales_after_refund) OVER () AS total_sales
    FROM vw_product_base v
    JOIN products p ON v.product_id = p.product_id
)
SELECT
    product_id,
    product_name,
    sales,
    running_sales * 100.0 / total_sales AS cumulative_pct
FROM running_cte
WHERE (running_sales - sales) * 100.0 / total_sales < 80
ORDER BY sales DESC;

-- 83. Compare product sales across years   [NEW]
WITH yearly_cte AS (
    SELECT product_id, order_year, SUM(net_sales) AS net_sales
    FROM vw_product_monthly
    GROUP BY product_id, order_year
)
SELECT
    p.product_name,
    y.product_id,
    y.order_year,
    y.net_sales,
    LAG(y.net_sales) OVER (PARTITION BY y.product_id ORDER BY y.order_year) AS prev_year_sales,
    (y.net_sales - LAG(y.net_sales) OVER (PARTITION BY y.product_id ORDER BY y.order_year)) * 100.0
        / NULLIF(LAG(y.net_sales) OVER (PARTITION BY y.product_id ORDER BY y.order_year), 0) AS yoy_pct
FROM yearly_cte y
JOIN products p ON p.product_id = y.product_id
ORDER BY y.product_id, y.order_year;

-- 84. Compare product sales MoM   [NEW]
SELECT
    p.product_name,
    m.product_id,
    m.order_year,
    m.order_month,
    m.net_sales,
    LAG(m.net_sales) OVER (PARTITION BY m.product_id ORDER BY m.order_year, m.order_month) AS prev_month_sales,
    (m.net_sales - LAG(m.net_sales) OVER (PARTITION BY m.product_id ORDER BY m.order_year, m.order_month)) * 100.0
        / NULLIF(LAG(m.net_sales) OVER (PARTITION BY m.product_id ORDER BY m.order_year, m.order_month), 0) AS mom_pct
FROM vw_product_monthly m
JOIN products p ON p.product_id = m.product_id
ORDER BY m.product_id, m.order_year, m.order_month;

-- 85. Products whose sales are consistently declining (year over year)   [NEW]
--     If the latest year is only partly complete, exclude it or it will look like a decline.
WITH yearly_cte AS (
    SELECT product_id, order_year, SUM(net_sales) AS net_sales
    FROM vw_product_monthly
    GROUP BY product_id, order_year
),
change_cte AS (
    SELECT
        product_id,
        order_year,
        net_sales,
        LAG(net_sales) OVER (PARTITION BY product_id ORDER BY order_year) AS prev_sales
    FROM yearly_cte
)
SELECT
    p.product_name,
    c.product_id,
    COUNT(*) AS periods_compared
FROM change_cte c
JOIN products p ON p.product_id = c.product_id
WHERE c.prev_sales IS NOT NULL
GROUP BY p.product_name, c.product_id
HAVING COUNT(*) >= 2
   AND SUM(CASE WHEN c.net_sales < c.prev_sales THEN 1 ELSE 0 END) = COUNT(*);



