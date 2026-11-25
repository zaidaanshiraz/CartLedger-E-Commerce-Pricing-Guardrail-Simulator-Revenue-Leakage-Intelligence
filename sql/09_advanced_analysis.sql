/* ============================================================
   ADVANCED SQL ANALYSIS
   ============================================================
   Includes cohort, RFM, profit bridge, discount effectiveness,
   and revenue-leakage/payment analysis used in the project.
*/

-- 1. Customer cohort retention
WITH cohort AS (
    SELECT
        customer_id,
        MIN(order_date) AS first_order_date
    FROM orders
    WHERE order_status = 'Completed' AND payment_status = 'Paid'
    GROUP BY customer_id
),
cohort_activity AS (
    SELECT
        c.customer_id,
        CONCAT(YEAR(c.first_order_date), '-', MONTH(c.first_order_date)) AS cohort_month,
        DATEDIFF(MONTH, c.first_order_date, o.order_date) AS cohort_month_number
    FROM cohort c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'Completed' AND o.payment_status = 'Paid'
),
retention AS (
    SELECT cohort_month, cohort_month_number, COUNT(DISTINCT customer_id) AS active_customers
    FROM cohort_activity
    GROUP BY cohort_month, cohort_month_number
)
SELECT
    cohort_month,
    cohort_month_number,
    active_customers,
    active_customers * 100.0 /
        MAX(CASE WHEN cohort_month_number = 0 THEN active_customers END)
        OVER (PARTITION BY cohort_month) AS retention_pct
FROM retention
ORDER BY cohort_month, cohort_month_number;

-- 2. RFM segmentation
WITH rfm AS (
    SELECT
        c.customer_id,
        DATEDIFF(DAY, MAX(o.order_date), (SELECT MAX(order_date) FROM orders)) AS recency,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM((oi.quantity * oi.unit_price)
            - (oi.quantity * oi.unit_price * oi.discount_pct / 100.0)) AS monetary
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE c.customer_status = 'Active'
      AND o.order_status = 'Completed'
      AND o.payment_status = 'Paid'
    GROUP BY c.customer_id
),
rfm_scores AS (
    SELECT *,
        -- Order recency DESC so quintile 5 = lowest recency days (most recent buyers)
        NTILE(5) OVER (ORDER BY recency DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM rfm
)
SELECT *,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 4 AND f_score >= 3 AND m_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'New / Potential Customers'
        WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4 THEN 'At Risk High Value'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Lost / Low Value'
        ELSE 'Regular Customers'
    END AS customer_segment
FROM rfm_scores;

-- 3. Discount effectiveness
WITH discount_analysis AS (
    SELECT
        o.order_id,
        oi.quantity,
        oi.unit_price,
        oi.discount_pct,
        p.cost_price,
        CASE
            WHEN oi.discount_pct = 0 THEN '0%'
            WHEN oi.discount_pct <= 10 THEN '1-10%'
            WHEN oi.discount_pct <= 20 THEN '10-20%'
            ELSE '20%+'
        END AS discount_bucket,
        oi.quantity * oi.unit_price
            - oi.quantity * oi.unit_price * oi.discount_pct / 100.0 AS net_revenue,
        oi.quantity * oi.unit_price
            - oi.quantity * oi.unit_price * oi.discount_pct / 100.0
            - oi.quantity * p.cost_price AS gross_profit
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    WHERE o.order_status = 'Completed' AND o.payment_status = 'Paid'
)
SELECT
    discount_bucket,
    COUNT(DISTINCT order_id) AS orders,
    SUM(quantity) AS units_sold,
    SUM(net_revenue) AS net_revenue,
    SUM(gross_profit) AS gross_profit,
    SUM(gross_profit) * 1.0 / COUNT(DISTINCT order_id) AS profit_per_order,
    SUM(gross_profit) * 100.0 / NULLIF(SUM(net_revenue), 0) AS profit_margin
FROM discount_analysis
GROUP BY discount_bucket
ORDER BY CASE discount_bucket
    WHEN '0%' THEN 1 WHEN '1-10%' THEN 2 WHEN '10-20%' THEN 3 ELSE 4 END;

-- 4. Revenue leakage / potential sales value by payment method
WITH payment_per_order AS (
    SELECT order_id, MAX(payment_method) AS payment_method
    FROM payments
    GROUP BY order_id
)
SELECT
    p.payment_method,
    COUNT(DISTINCT o.order_id) AS unsuccessful_orders,
    SUM(oi.quantity * oi.unit_price) AS gross_order_value,
    SUM(
        oi.quantity * oi.unit_price
        - oi.quantity * oi.unit_price * oi.discount_pct / 100.0
        + oi.tax_amount
    ) AS potential_sales_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN payment_per_order p ON o.order_id = p.order_id
WHERE o.order_status = 'Cancelled'
   OR o.payment_status IN ('Failed', 'Pending')
GROUP BY p.payment_method
ORDER BY potential_sales_value DESC;

-- 5. Payment failure rate
SELECT
    p.payment_method,
    COUNT(DISTINCT o.order_id) AS total_transactions,
    COUNT(DISTINCT CASE WHEN o.payment_status = 'Failed' THEN o.order_id END) AS failed_transactions,
    COUNT(DISTINCT CASE WHEN o.payment_status = 'Failed' THEN o.order_id END) * 100.0
        / NULLIF(COUNT(DISTINCT o.order_id), 0) AS failure_rate_pct
FROM orders o
JOIN payments p ON p.order_id = o.order_id
GROUP BY p.payment_method
ORDER BY failure_rate_pct DESC;
