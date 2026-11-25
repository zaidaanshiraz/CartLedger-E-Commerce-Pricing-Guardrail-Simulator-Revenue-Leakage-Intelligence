create view vw_product_profitability as
with profit_base as(
SELECT 
        p.product_id,
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
    JOIN products p ON oi.product_id = p.product_id
    WHERE o.order_status = 'Completed' 
      AND o.payment_status = 'Paid'
),profit_reenue as(
    select product_id,order_id,order_item_id
    ,quantity,
    unit_price,
    discount_pct,
    cost_price,
   quantity * unit_price as gross_sales,
   (quantity * unit_price * discount_pct) / 100 as discount_amount,
   (quantity * unit_price) - (quantity * unit_price * discount_pct) / 100 as net_revenue,
    quantity * cost_price as cost_amount,
   (((quantity * unit_price) - (quantity * unit_price * discount_pct) / 100) - quantity * cost_price) as gross_profit
        from profit_base
),producr_profit as(
SELECT 
        product_id,count(distinct order_id) as No_Orders,
        sum(gross_sales) AS gross,
        sum(discount_amount) AS discount_amount,
        sum(net_revenue) AS netsales_bf_tax,
        sum(cost_amount) as cost_amount ,
        sum(gross_profit) AS gross_profit,
        sum(quantity) as quantity
    FROM profit_reenue
    group by product_id
    ) select * ,(gross_profit*100.0)/netsales_bf_tax as profit_margin from producr_profit
/* =====================================================================
   PROFITABILITY & MARGIN EROSION ANALYSIS
   Author: Mohammed Zaidaan Shiraz
   Key Engineering Rules Enforced:
   1. Category order counts use COUNT(DISTINCT order_id) at category grain
      (never SUM(product_orders), which inflates multi-item carts).
   2. Category and monthly profit margins use weighted ratio
      SUM(gross_profit) * 100.0 / NULLIF(SUM(netsales_bf_tax), 0)
      (never AVG(product_margin) or SUM(product_margin)).
   ===================================================================== */


    select top 20 * from vw_product_profitability
    order by gross_profit desc

     select * from vw_product_profitability
    where gross_profit<0

    select top 20 * from vw_product_profitability
    order by profit_margin desc


    select c.category_id,sum(vp.cost_amount) as cost
    ,sum(vp.gross) as cost,sum(vp.gross_profit) as cost,sum(vp.discount_amount) as cost,sum(vp.No_Orders) as cost,sum(vp.netsales_bf_tax) as cost
    ,sum(vp.profit_margin) as cost,sum(vp.quantity) as cost
    from vw_product_profitability vp join products p on p.product_id=vp.product_id join categories c
    on c.category_id=p.category_id
    group by c.category_id

    select * from vw_product_profitability

    with profit_base as(
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
    JOIN products p ON oi.product_id = p.product_id join categories c on c.category_id=p.category_id
    WHERE o.order_status = 'Completed' 
      AND o.payment_status = 'Paid'
),profit_reenue as(
    select product_id,order_id,order_item_id,category_id
    ,quantity,
    unit_price,
    discount_pct,
    cost_price,
   quantity * unit_price as gross_sales,
   (quantity * unit_price * discount_pct) / 100 as discount_amount,
   (quantity * unit_price) - (quantity * unit_price * discount_pct) / 100 as net_revenue,
    quantity * cost_price as cost_amount,
   (((quantity * unit_price) - (quantity * unit_price * discount_pct) / 100) - quantity * cost_price) as gross_profit
        from profit_base
),producr_profit as(
SELECT 
        category_id,count(distinct order_id) as No_Orders,
        sum(gross_sales) AS gross,
        sum(discount_amount) AS discount_amount,
        sum(net_revenue) AS netsales_bf_tax,
        sum(cost_amount) as cost_amount ,
        sum(gross_profit) AS gross_profit,
        sum(quantity) as quantity
    FROM profit_reenue
    group by category_id
    ) select * ,(gross_profit*100.0)/netsales_bf_tax as profit_margin from producr_profit

    create view vw_monthly_profit as
        with profit_base as(
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
    JOIN products p ON oi.product_id = p.product_id join categories c on c.category_id=p.category_id
    WHERE o.order_status = 'Completed' 
      AND o.payment_status = 'Paid'
),profit_reenue as(
    select product_id,order_id,order_item_id,category_id
    ,quantity,
    year(order_date) as year,month(order_date) as month,
    unit_price,
    discount_pct,
    cost_price,
   quantity * unit_price as gross_sales,
   (quantity * unit_price * discount_pct) / 100 as discount_amount,
   (quantity * unit_price) - (quantity * unit_price * discount_pct) / 100 as net_revenue,
    quantity * cost_price as cost_amount,
   (((quantity * unit_price) - (quantity * unit_price * discount_pct) / 100) - quantity * cost_price) as gross_profit
        from profit_base
),producr_profit as(
SELECT 
        year,month,count(distinct order_id) as No_Orders,
        sum(gross_sales) AS gross,
        sum(discount_amount) AS discount_amount,
        sum(net_revenue) AS netsales_bf_tax,
        sum(cost_amount) as cost_amount ,
        sum(gross_profit) AS gross_profit,
        sum(quantity) as quantity
    FROM profit_reenue
    group by year,month
    ) select * ,(gross_profit*100.0)/netsales_bf_tax as profit_margin from producr_profit

    Month | Gross Profit | Previous Month Profit | MoM %
    select year,month,gross_profit,lag(gross_profit) over(order by year,month)as Previous_Month,
    (gross_profit-lag(gross_profit) over(order by year,month))*100.0/lag(gross_profit) over(order by year,month) as MOM
    from vw_monthly_profit

    year | month | net_revenue | gross_profit | profit_margin

    select year,month,gross_profit,netsales_bf_tax,lag(profit_margin) over(order by year,month)as Previous_Month,
    (profit_margin-lag(profit_margin) over(order by year,month))*100.0/lag(profit_margin) over(order by year,month) as MOM
    from vw_monthly_profit

    with segmentaion as(
SELECT 
    product_id,
    netsales_bf_tax,
    NO_ORDERS,
    profit_margin,
    gross_profit,
    CASE 
        WHEN netsales_bf_tax >= (select avg(netsales_bf_tax) from vw_product_profitability) AND profit_margin >= (select avg(profit_margin) from vw_product_profitability) 
            THEN 'high net revenue but high profit margin'
        WHEN netsales_bf_tax >= (select avg(netsales_bf_tax) from vw_product_profitability) AND profit_margin < (select avg(profit_margin) from vw_product_profitability)  
            THEN 'high net revenue but low profit margin'
        WHEN netsales_bf_tax < (select avg(netsales_bf_tax) from vw_product_profitability) AND profit_margin >= (select avg(profit_margin) from vw_product_profitability)  
            THEN 'low net revenue but high profit margin'
        WHEN netsales_bf_tax < (select avg(netsales_bf_tax) from vw_product_profitability) AND profit_margin < (select avg(profit_margin) from vw_product_profitability)  
            THEN 'low net revenue but low profit margin'
    END AS customer_segment
FROM vw_product_profitability)
select customer_segment,count(*) as product_count,sum(netsales_bf_tax) as netsales_bf_tax,sum(NO_ORDERS)as NO_ORDERS, 
sum(profit_margin) as profit_margin,sum(gross_profit) as gross_profit from segmentaion
group by customer_segment


with cort as(
SELECT 
c.customer_id,min(o.order_date) as first_order_date
       from customers c join orders o on c.customer_id=o.customer_id
    WHERE o.order_status = 'Completed' 
      AND o.payment_status = 'Paid'
      group by c.customer_id
      ),cortt as (select c.customer_id,concat(year(c.first_order_date),'-',month(c.first_order_date)) as cohrot,c.first_order_date
      ,CONCAT(YEAR(o.order_date), '-', MONTH(o.order_date)) as order_month, DATEDIFF(MM,c.first_order_date,o.order_date) as chorot_date from cort c left join 
      orders o on c.customer_id=o.customer_id
       WHERE o.order_status = 'Completed' 
      AND o.payment_status = 'Paid'),
      rot as 
      (
      select count(distinct customer_id) as corhtt,cohrot,chorot_date from cortt
      group by cohrot,chorot_date)
      select corhtt,cohrot,chorot_date,(corhtt*100.0)/( SELECT corhtt
    FROM rot r2
    WHERE r2.chorot_date = 0
      AND r2.cohrot = rot.cohrot) as perctage from rot


with rfm as(
select c.customer_id,DATEDIFF(day,max(o.order_date),(select top 1 max(o.order_date) from orders)) as recency,
count(distinct o.order_id) as frequency, sum(((oi.quantity*oi.unit_price)-(oi.quantity * oi.unit_price * oi.discount_pct) / 100.0)) as Monetary

from customers c join orders o on o.customer_id=c.customer_id join order_items oi on oi.order_id=o.order_id
where c.customer_status='Active' and o.order_status = 'Completed' 
      AND o.payment_status = 'Paid'
group by c.customer_id

),rfm_scores AS (
-- 1. Product-Level Profitability View
CREATE OR ALTER VIEW vw_product_profitability AS
WITH profit_base AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency DESC) AS R_score,
        NTILE(5) OVER (ORDER BY frequency DESC) AS F_score,
        NTILE(5) OVER (ORDER BY Monetary DESC) AS M_score
    FROM rfm
),rfm_segments AS(
SELECT *,CASE
    WHEN R_score >= 4 AND F_score >= 4 AND M_score >= 4
        THEN 'Champions'

    WHEN R_score >= 4 AND F_score >= 3 AND M_score >= 3
        THEN 'Loyal Customers'

    WHEN R_score >= 4 AND F_score <= 2
        THEN 'New / Potential Customers'

    WHEN R_score <= 2 AND F_score >= 4 AND M_score >= 4
        THEN 'At Risk High Value'

    WHEN R_score <= 2 AND F_score >= 3
        THEN 'At Risk'

    WHEN R_score <= 2 AND F_score <= 2 AND M_score <= 2
        THEN 'Lost / Low Value'

    ELSE 'Regular Customers'
END AS customer_segment
FROM rfm_scores)
select * from rfm_segments 

with profit_base as(
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
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    WHERE o.order_status = 'Completed' 
    JOIN products p     ON oi.product_id = p.product_id
    WHERE o.order_status   = 'Completed'
      AND o.payment_status = 'Paid'
),profit_reenue as(
    select product_id,order_id,order_item_id
    ,quantity,
    unit_price,
    discount_pct,
    YEAR(order_date) AS sales_year,
MONTH(order_date) AS sales_month,
    cost_price,
   quantity * unit_price as gross_sales,
   (quantity * unit_price * discount_pct) / 100 as discount_amount,
   (quantity * unit_price) - (quantity * unit_price * discount_pct) / 100 as net_revenue,
    quantity * cost_price as cost_amount,
   (((quantity * unit_price) - (quantity * unit_price * discount_pct) / 100) - quantity * cost_price) as gross_profit
        from profit_base
),producr_profit as(
SELECT 
        product_id,sales_year,sales_month,count(distinct order_id) as No_Orders,
        sum(gross_sales) AS gross,
        sum(discount_amount) AS discount_amount,
        sum(net_revenue) AS netsales_bf_tax,
        sum(cost_amount) as cost_amount ,
        sum(gross_profit) AS gross_profit,
        sum(quantity) as quantity,
        SUM(gross_sales) / SUM(quantity) AS selling_price_per_unit,
        SUM(discount_amount) / SUM(quantity) AS discount_per_unit,
        SUM(cost_amount) / SUM(quantity) AS cost_per_unit
    FROM profit_reenue
    group by product_id,sales_year,sales_month
    ),
bridge_base AS (
),
profit_revenue AS (
    SELECT
        *,

        LAG(quantity) OVER (
            PARTITION BY product_id
            ORDER BY sales_year, sales_month
        ) AS prev_quantity,

        LAG(selling_price_per_unit) OVER (
            PARTITION BY product_id
            ORDER BY sales_year, sales_month
        ) AS prev_price,

        LAG(discount_per_unit) OVER (
            PARTITION BY product_id
            ORDER BY sales_year, sales_month
        ) AS prev_discount,

        LAG(cost_per_unit) OVER (
            PARTITION BY product_id
            ORDER BY sales_year, sales_month
        ) AS prev_cost,

        LAG(gross_profit) OVER (
            PARTITION BY product_id
            ORDER BY sales_year, sales_month
        ) AS prev_profit

    FROM producr_profit
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
    product_id,
    sales_year,
    sales_month,
    *,
    ROUND((gross_profit * 100.0) / NULLIF(netsales_bf_tax, 0), 2) AS profit_margin_pct
FROM product_profit;
GO

    prev_quantity,
    quantity,
-- 2. Top 20 Most Profitable SKUs
SELECT TOP 20 *
FROM vw_product_profitability
ORDER BY gross_profit DESC;

    prev_price,
    selling_price_per_unit AS current_price,
-- 3. Loss-Making SKUs (Negative Realized Gross Profit due to Over-Discounting)
SELECT *
FROM vw_product_profitability
WHERE gross_profit < 0
ORDER BY gross_profit ASC;

    prev_discount,
    discount_per_unit AS current_discount,
-- 4. Top 20 SKUs by Weighted Profit Margin (%)
SELECT TOP 20 *
FROM vw_product_profitability
ORDER BY profit_margin_pct DESC;

    prev_cost,
    cost_per_unit AS current_cost,

    prev_profit,
    gross_profit AS current_profit,

    -- Actual change in profit
    gross_profit - prev_profit AS actual_profit_change,

    -- 1. Volume Effect
    (quantity - prev_quantity)
        * (prev_price - prev_discount - prev_cost)
        AS volume_effect,

    -- 2. Price Effect
    (selling_price_per_unit - prev_price)
        * quantity
        AS price_effect,

    -- 3. Discount Effect
    (prev_discount - discount_per_unit)
        * quantity
        AS discount_effect,

    -- 4. Cost Effect
    (prev_cost - cost_per_unit)
        * quantity
        AS cost_effect

FROM bridge_base

WHERE prev_profit IS NOT NULL

ORDER BY
    product_id,
    sales_year,
    sales_month;

    WITH discount_analysis AS (
-- 5. Category Profitability Rollup (True Distinct Order Grain & Weighted Margin)
WITH category_line_items AS (
    SELECT
        c.category_id,
        c.category_name,
        o.order_id,
        oi.order_item_id,
        oi.quantity,
        oi.unit_price,
        oi.discount_pct,
        p.cost_price,

        CASE
            WHEN oi.discount_pct = 0
                THEN '0%'

            WHEN oi.discount_pct > 0
                 AND oi.discount_pct <= 10
                THEN '1-10%'

            WHEN oi.discount_pct > 10
                 AND oi.discount_pct <= 20
                THEN '10-20%'

            ELSE '20%+'
        END AS discount_bucket,

        (oi.quantity * oi.unit_price)
            - (oi.quantity * oi.unit_price * oi.discount_pct / 100.0)
            AS net_revenue,

        (
            (oi.quantity * oi.unit_price)
            - (oi.quantity * oi.unit_price * oi.discount_pct / 100.0)
            - (oi.quantity * p.cost_price)
        ) AS gross_profit

        oi.quantity * oi.unit_price AS gross_sales,
        (oi.quantity * oi.unit_price * oi.discount_pct) / 100.0 AS discount_amount,
        (oi.quantity * oi.unit_price) * (1.0 - oi.discount_pct / 100.0) AS netsales_bf_tax,
        oi.quantity * p.cost_price AS cost_amount,
        (oi.quantity * oi.unit_price) * (1.0 - oi.discount_pct / 100.0) - (oi.quantity * p.cost_price) AS gross_profit
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    JOIN products p
        ON oi.product_id = p.product_id

    WHERE o.order_status = 'Completed'
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p     ON oi.product_id = p.product_id
    JOIN categories c   ON c.category_id = p.category_id
    WHERE o.order_status   = 'Completed'
      AND o.payment_status = 'Paid'
),
global_orders AS (
    SELECT COUNT(DISTINCT order_id) AS network_unique_orders
    FROM orders
    WHERE order_status = 'Completed' AND payment_status = 'Paid'
)

SELECT
    discount_bucket,
    COUNT(DISTINCT order_id) AS orders,
    SUM(quantity) AS units_sold,
    SUM(net_revenue) AS net_revenue,
    SUM(gross_profit) AS gross_profit,
    cli.category_id,
    cli.category_name,
    COUNT(DISTINCT cli.order_id) AS category_distinct_orders,
    go.network_unique_orders,
    ROUND(COUNT(DISTINCT cli.order_id) * 100.0 / NULLIF(go.network_unique_orders, 0), 2) AS basket_penetration_pct,
    SUM(cli.quantity)            AS units_sold,
    ROUND(SUM(cli.gross_sales), 2)     AS gross_sales,
    ROUND(SUM(cli.discount_amount), 2) AS discount_amount,
    ROUND(SUM(cli.netsales_bf_tax), 2) AS netsales_bf_tax,
    ROUND(SUM(cli.cost_amount), 2)     AS cost_amount,
    ROUND(SUM(cli.gross_profit), 2)    AS gross_profit,
    ROUND(SUM(cli.gross_profit) * 100.0 / NULLIF(SUM(cli.netsales_bf_tax), 0), 2) AS weighted_profit_margin_pct
FROM category_line_items cli
CROSS JOIN global_orders go
GROUP BY cli.category_id, cli.category_name, go.network_unique_orders
ORDER BY gross_profit DESC;

    SUM(gross_profit) * 1.0
        / COUNT(DISTINCT order_id) AS profit_per_order,

    SUM(gross_profit) * 100.0
        / SUM(net_revenue) AS profit_margin

FROM discount_analysis

GROUP BY discount_bucket

ORDER BY
    CASE discount_bucket
        WHEN '0%' THEN 1
        WHEN '1-10%' THEN 2
        WHEN '10-20%' THEN 3
        WHEN '20%+' THEN 4
    END;

-- 6. Monthly Profit, MoM Growth (%) & Running Cumulative Profit
WITH monthly_kpi AS (
    SELECT
    p.payment_method,
    COUNT(DISTINCT o.order_id) AS orders,
    SUM(oi.quantity * oi.unit_price) AS gross_order_value,
    SUM(
        (oi.quantity * oi.unit_price)
        - (oi.quantity * oi.unit_price * oi.discount_pct / 100.0)
        + oi.tax_amount
    ) AS potential_sales_value
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id join payments p on p.order_id=o.order_id
WHERE
    o.order_status = 'Cancelled'
    OR o.payment_status IN ('Failed', 'Pending')
GROUP BY
    p.payment_method
ORDER BY
    potential_sales_value DESC;

    WITH payment_per_order AS (
    SELECT
        order_id,
        MAX(payment_method) AS payment_method
    FROM payments
    GROUP BY order_id
        sales_year,
        sales_month,
        no_orders,
        netsales_bf_tax,
        cost_amount,
        gross_profit,
        profit_margin_pct
    FROM vw_monthly_profit
)

SELECT
    o.payment_status,
    p.payment_method,
    sales_year,
    sales_month,
    no_orders,
    netsales_bf_tax,
    gross_profit,
    profit_margin_pct,
    LAG(gross_profit) OVER (ORDER BY sales_year, sales_month) AS prev_month_profit,
    ROUND(
        (gross_profit - LAG(gross_profit) OVER (ORDER BY sales_year, sales_month)) * 100.0
        / NULLIF(LAG(gross_profit) OVER (ORDER BY sales_year, sales_month), 0),
        2
    ) AS mom_profit_growth_pct,
    SUM(gross_profit) OVER (
        ORDER BY sales_year, sales_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_cumulative_profit
FROM monthly_kpi
ORDER BY sales_year, sales_month;

    COUNT(DISTINCT o.order_id) AS orders,

    SUM(
        oi.quantity * oi.unit_price
    ) AS gross_order_value,

    SUM(
        (oi.quantity * oi.unit_price)
        - (oi.quantity * oi.unit_price * oi.discount_pct / 100.0)
        + oi.tax_amount
    ) AS potential_sales_value

FROM orders o

JOIN order_items oi
    ON o.order_id = oi.order_id

LEFT JOIN payment_per_order p
    ON o.order_id = p.order_id

WHERE o.payment_status IN ('Pending', 'Failed')

GROUP BY
    o.payment_status,
    p.payment_method

ORDER BY
    potential_sales_value DESC;


    

-- 7. Top 3 Profit-Generating SKUs Per Category (DENSE_RANK Window Function)
WITH ranked_skus AS (
    SELECT
    p.payment_method,

    -- ALL transactions
    COUNT(DISTINCT o.order_id) AS total_transactions,

    -- Failed transactions
    COUNT(DISTINCT CASE
        WHEN o.payment_status = 'Failed'
        THEN o.order_id
    END) AS failed_transactions,

    -- Failure rate
    COUNT(DISTINCT CASE
        WHEN o.payment_status = 'Failed'
        THEN o.order_id
    END) * 100.0
    / COUNT(DISTINCT o.order_id) AS failure_rate,

    -- Leakage metrics
    COUNT(DISTINCT CASE
        WHEN o.order_status = 'Cancelled'
          OR o.payment_status IN ('Failed', 'Pending')
        THEN o.order_id
    END) AS unsuccessful_orders,

    SUM(CASE
        WHEN o.order_status = 'Cancelled'
          OR o.payment_status IN ('Failed', 'Pending')
        THEN oi.quantity * oi.unit_price
        ELSE 0
    END) AS gross_leakage_value,

   SUM(CASE
    WHEN o.order_status = 'Cancelled'
      OR o.payment_status IN ('Failed', 'Pending')
    THEN
        (oi.quantity * oi.unit_price)
        - (oi.quantity * oi.unit_price * oi.discount_pct / 100.0)
        + oi.tax_amount
    ELSE 0
END) AS potential_sales_value
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
JOIN payments p
    ON p.order_id = o.order_id

GROUP BY p.payment_method

ORDER BY failure_rate DESC;
        c.category_name,
        vp.product_id,
        vp.product_name,
        vp.quantity,
        vp.netsales_bf_tax,
        vp.gross_profit,
        vp.profit_margin_pct,
        DENSE_RANK() OVER (
            PARTITION BY c.category_name
            ORDER BY vp.gross_profit DESC
        ) AS profit_rank_in_category
    FROM vw_product_profitability vp
    JOIN categories c ON vp.category_id = c.category_id
)
SELECT *
FROM ranked_skus
WHERE profit_rank_in_category <= 3
ORDER BY category_name ASC, profit_rank_in_category ASC;
