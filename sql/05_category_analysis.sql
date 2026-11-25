/* =====================================================================
   Category performance analysis (SQL Server) - corrected version
   ===================================================================== */

-- CREATE VIEW must be the first statement in its batch
IF OBJECT_ID('vw_category_base', 'V') IS NOT NULL DROP VIEW vw_category_base;
GO

CREATE VIEW vw_category_base AS
WITH category_base AS (
    SELECT
        c.category_id,
        c.category_name,
        o.order_id,
        oi.order_item_id,
        oi.quantity,
        oi.unit_price,
        oi.discount_pct,
        oi.tax_amount
    FROM orders o
    JOIN order_items oi ON o.order_id    = oi.order_id
    JOIN products    p  ON oi.product_id = p.product_id
    JOIN categories  c  ON c.category_id = p.category_id
    WHERE o.order_status   = 'Completed'
      AND o.payment_status = 'Paid'
),
revenue_by_category AS (
    SELECT
        category_id,
        category_name,
        COUNT(DISTINCT order_id)                                              AS no_orders,
        SUM(quantity * unit_price)                                            AS gross,
        SUM(quantity * unit_price * discount_pct / 100.0)                     AS discount_amount,
        SUM(quantity * unit_price * (1 - discount_pct / 100.0))               AS netsales_bf_tax,
        SUM(tax_amount)                                                       AS tax_amount,
        SUM(quantity * unit_price * (1 - discount_pct / 100.0) + tax_amount)  AS netsales_af_tax,
        SUM(quantity)                                                         AS quantity
    FROM category_base
    GROUP BY category_id, category_name
),
returns_by_category AS (
    SELECT
        p.category_id,
        SUM(r.return_quantity) AS return_quantity,
        SUM(r.refund_amount)   AS refund_amt
    FROM returns r
    JOIN order_items oi ON oi.order_item_id = r.order_item_id
    JOIN orders      o  ON o.order_id       = oi.order_id
    JOIN products    p  ON p.product_id     = oi.product_id
    WHERE r.return_status  = 'Approved'
      AND o.order_status   = 'Completed'
      AND o.payment_status = 'Paid'
    GROUP BY p.category_id
),
category_performance AS (
    SELECT
        r.category_id,
        r.category_name,
        r.gross,
        r.discount_amount,
        r.netsales_bf_tax,
        r.netsales_af_tax,
        r.tax_amount,
        r.quantity,
        r.no_orders,
        ISNULL(rp.return_quantity, 0) AS return_quantity,
        ISNULL(rp.refund_amt, 0)      AS refund_amt
    FROM revenue_by_category r
    LEFT JOIN returns_by_category rp ON r.category_id = rp.category_id
)
SELECT
    cp.category_id,
    cp.category_name,
    cp.gross,
    cp.discount_amount,
    cp.netsales_bf_tax,
    cp.netsales_af_tax,
    cp.tax_amount,
    cp.no_orders,
    cp.quantity,
    cp.return_quantity,
    cp.refund_amt,
    cp.quantity - cp.return_quantity                       AS net_units_sold,
    cp.netsales_af_tax - cp.refund_amt                     AS net_sales_after_refund,
    cp.return_quantity * 100.0 / NULLIF(cp.quantity, 0)    AS return_rate,
    cp.discount_amount * 100.0 / NULLIF(cp.gross, 0)       AS discount_rate
FROM category_performance cp;
GO

/* ---------------------- Top / bottom 10 rankings ---------------------- */
SELECT TOP 10 category_id, category_name, net_sales_after_refund FROM vw_category_base ORDER BY net_sales_after_refund DESC;
SELECT TOP 10 category_id, category_name, net_sales_after_refund FROM vw_category_base ORDER BY net_sales_after_refund ASC;
SELECT TOP 10 category_id, category_name, net_units_sold         FROM vw_category_base ORDER BY net_units_sold DESC;
SELECT TOP 10 category_id, category_name, net_units_sold         FROM vw_category_base ORDER BY net_units_sold ASC;
SELECT TOP 10 category_id, category_name, refund_amt             FROM vw_category_base ORDER BY refund_amt DESC;
SELECT TOP 10 category_id, category_name, refund_amt             FROM vw_category_base ORDER BY refund_amt ASC;
SELECT TOP 10 category_id, category_name, return_quantity        FROM vw_category_base ORDER BY return_quantity DESC;
SELECT TOP 10 category_id, category_name, return_quantity        FROM vw_category_base ORDER BY return_quantity ASC;
SELECT TOP 10 category_id, category_name, no_orders              FROM vw_category_base ORDER BY no_orders DESC;
SELECT TOP 10 category_id, category_name, no_orders              FROM vw_category_base ORDER BY no_orders ASC;

/* ---------------------------- Ratios ---------------------------------- */
SELECT category_id, category_name,
       net_sales_after_refund / NULLIF(net_units_sold, 0)  AS avg_sales_per_unit
FROM vw_category_base;

SELECT category_id, category_name, discount_rate FROM vw_category_base;
SELECT category_id, category_name, return_rate   FROM vw_category_base;

SELECT category_id, category_name,
       net_units_sold * 1.0 / NULLIF(no_orders, 0)         AS units_per_order   -- 1.0 avoids integer division
FROM vw_category_base;

/* ------------------- Quadrants vs. average ---------------------------- */
WITH x AS (
    SELECT *,
           AVG(net_sales_after_refund) OVER () AS avg_sales,
           AVG(return_rate)            OVER () AS avg_return_rate,
           AVG(discount_rate)          OVER () AS avg_discount_rate
    FROM vw_category_base
)
SELECT category_id, category_name, net_sales_after_refund, return_rate, discount_rate,
       CASE WHEN net_sales_after_refund >  avg_sales AND return_rate >  avg_return_rate   THEN 'High sales / High returns'
            WHEN net_sales_after_refund >  avg_sales AND discount_rate > avg_discount_rate THEN 'High sales / High discount'
            WHEN net_sales_after_refund <= avg_sales AND return_rate >  avg_return_rate   THEN 'Low sales / High returns'
            WHEN net_sales_after_refund <= avg_sales AND return_rate <= avg_return_rate    THEN 'Low sales / Low returns'
       END AS segment   -- note: first match wins; run the original separate queries if you need overlaps
FROM x;

/* ----------------------------- Contribution --------------------------- */
SELECT category_id, category_name,
       net_sales_after_refund * 100.0 / SUM(net_sales_after_refund) OVER () AS sales_contribution_pct,
       net_units_sold         * 100.0 / SUM(net_units_sold)         OVER () AS units_contribution_pct
FROM vw_category_base;

/* ------------------------------ Pareto 80/20 -------------------------- */
WITH ranked AS (
    SELECT
        category_id,
        category_name,
        net_sales_after_refund,
        SUM(net_sales_after_refund) OVER (ORDER BY net_sales_after_refund DESC
                                          ROWS UNBOUNDED PRECEDING) AS cumulative_sales,
        ROW_NUMBER() OVER (ORDER BY net_sales_after_refund DESC)    AS rnk,
        SUM(net_sales_after_refund) OVER ()                         AS total_sales
    FROM vw_category_base
),
pareto AS (
    SELECT *, cumulative_sales * 100.0 / total_sales AS cumulative_pct
    FROM ranked
)
SELECT *
FROM pareto
WHERE rnk <= (SELECT MIN(rnk) FROM pareto WHERE cumulative_pct >= 80)
ORDER BY rnk;

/* ----------------------- Yearly net sales per category ---------------- */
SELECT
    c.category_id,
    c.category_name,
    YEAR(o.order_date) AS [year],
    SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0) + oi.tax_amount) AS net_sales
FROM orders o
JOIN order_items oi ON o.order_id    = oi.order_id
JOIN products    p  ON oi.product_id = p.product_id
JOIN categories  c  ON c.category_id = p.category_id
WHERE o.order_status = 'Completed' AND o.payment_status = 'Paid'
GROUP BY c.category_id, c.category_name, YEAR(o.order_date)
ORDER BY c.category_id, [year];

/* ------------------------------- YoY ---------------------------------- */
WITH yearly AS (
    SELECT
        c.category_id,
        c.category_name,
        YEAR(o.order_date) AS [year],
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0) + oi.tax_amount) AS net_sales
    FROM orders o
    JOIN order_items oi ON o.order_id    = oi.order_id
    JOIN products    p  ON oi.product_id = p.product_id
    JOIN categories  c  ON c.category_id = p.category_id
    WHERE o.order_status = 'Completed' AND o.payment_status = 'Paid'
    GROUP BY c.category_id, c.category_name, YEAR(o.order_date)
),
lagged AS (
    SELECT *, LAG(net_sales) OVER (PARTITION BY category_id ORDER BY [year]) AS previous_year_sales
    FROM yearly
)
SELECT *,
       net_sales - previous_year_sales                                  AS yoy_growth,
       (net_sales - previous_year_sales) * 100.0 / NULLIF(previous_year_sales, 0) AS yoy_pct
FROM lagged
ORDER BY category_id, [year];

/* ------------------------------- MoM ---------------------------------- */
-- LAG compares with the previous *row*; if a category has a month with no sales,
-- that month is missing and the comparison skips it. Build a calendar table if you need strict MoM.
WITH monthly AS (
    SELECT
        c.category_id,
        c.category_name,
        YEAR(o.order_date)  AS [year],
        MONTH(o.order_date) AS [month],
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0) + oi.tax_amount) AS net_sales
    FROM orders o
    JOIN order_items oi ON o.order_id    = oi.order_id
    JOIN products    p  ON oi.product_id = p.product_id
    JOIN categories  c  ON c.category_id = p.category_id
    WHERE o.order_status = 'Completed' AND o.payment_status = 'Paid'
    GROUP BY c.category_id, c.category_name, YEAR(o.order_date), MONTH(o.order_date)
),
lagged AS (
    SELECT *, LAG(net_sales) OVER (PARTITION BY category_id ORDER BY [year], [month]) AS previous_month_sales
    FROM monthly
)
SELECT *,
       net_sales - previous_month_sales                                  AS mom_growth,
       (net_sales - previous_month_sales) * 100.0 / NULLIF(previous_month_sales, 0) AS mom_pct
FROM lagged
ORDER BY [year], [month], category_id;