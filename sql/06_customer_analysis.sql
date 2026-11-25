CREATE OR ALTER VIEW vw_customer_base AS
WITH Custo_base AS (
    SELECT
        c.customer_id,
        oi.order_item_id,
        o.order_id,
        o.order_date,
        oi.quantity,
        oi.unit_price,
        oi.discount_pct,
        oi.tax_amount
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'Completed'
      AND o.payment_status = 'Paid'
),
revenue_by_customer AS (
    SELECT
        customer_id,
        SUM(quantity * unit_price)                                                        AS gross,
        SUM((quantity * unit_price * discount_pct) / 100)                                 AS discount_amount,
        SUM((quantity * unit_price) - (quantity * unit_price * discount_pct) / 100)       AS netsales_bf_tax,
        SUM(tax_amount)                                                                   AS tax_amount,
        SUM((quantity * unit_price) - (quantity * unit_price * discount_pct) / 100
            + tax_amount)                                                                 AS netsales_af_tax,
        SUM(quantity) AS quantity,
        COUNT(DISTINCT order_id) AS NO_ORDERS,
        MAX(order_date) AS last_order_date
    FROM Custo_base
    GROUP BY customer_id
),
returns_by_customer AS (
    SELECT
        o.customer_id,
        SUM(r.return_quantity) AS return_quantity,
        SUM(r.refund_amount)   AS refund_amt
    FROM returns r
    JOIN order_items oi ON oi.order_item_id = r.order_item_id
    JOIN orders o       ON o.order_id = oi.order_id
    WHERE r.return_status = 'Approved'
      AND o.order_status = 'Completed'
      AND o.payment_status = 'Paid'
    GROUP BY o.customer_id
),
customer_performance AS (
    SELECT
        r.customer_id,
        r.gross,
        r.discount_amount,
        r.netsales_bf_tax,
        r.netsales_af_tax,
        r.tax_amount,
        r.quantity,
        r.NO_ORDERS,
        r.last_order_date,
        ISNULL(rp.return_quantity, 0) AS return_quantity,
        ISNULL(rp.refund_amt, 0)      AS refund_amt
    FROM revenue_by_customer r
    LEFT JOIN returns_by_customer rp ON r.customer_id = rp.customer_id
)
SELECT
    c.customer_id,
    c.customer_name,
    c.customer_status,
    c.signup_date,
    cp.gross,
    cp.discount_amount,
    cp.netsales_bf_tax,
    cp.netsales_af_tax,
    cp.tax_amount,
    cp.NO_ORDERS,
    cp.quantity,
    cp.return_quantity,
    cp.refund_amt,
    cp.quantity - cp.return_quantity                AS net_units_sold,
    cp.netsales_af_tax - cp.refund_amt              AS net_sales_after_refund,
    cp.return_quantity * 100.0 / cp.quantity        AS return_rate,
    cp.discount_amount * 100.0 / cp.gross           AS discount_rate,
    -- RFM metrics
    DATEDIFF(DAY, cp.last_order_date, (SELECT MAX(order_date) FROM orders)) AS recency,
    cp.NO_ORDERS AS frequency,
    cp.netsales_af_tax - cp.refund_amt AS monetary
FROM customer_performance cp
JOIN customers c ON c.customer_id = cp.customer_id;

SELECT TOP 10 customer_id, customer_name, net_sales_after_refund FROM vw_customer_base ORDER BY net_sales_after_refund DESC;
SELECT TOP 10 customer_id, customer_name, net_sales_after_refund FROM vw_customer_base ORDER BY net_sales_after_refund ASC;
SELECT TOP 10 customer_id, customer_name, NO_ORDERS FROM vw_customer_base ORDER BY NO_ORDERS DESC;
SELECT TOP 10 customer_id, customer_name, net_units_sold FROM vw_customer_base ORDER BY net_units_sold DESC;
SELECT TOP 10 customer_id, customer_name, refund_amt FROM vw_customer_base ORDER BY refund_amt DESC;
SELECT TOP 10 customer_id, customer_name, return_quantity FROM vw_customer_base ORDER BY return_quantity DESC;


select customer_id,customer_name,(net_units_sold*1.0)/NO_ORDERS as avg from vw_customer_base
select customer_id,customer_name,(net_sales_after_refund*1.0)/NO_ORDERS as avg from vw_customer_base
select customer_id,customer_name,(net_sales_after_refund*1.0)/NO_ORDERS as avg,return_rate from vw_customer_base
select customer_id,customer_name,(discount_amount*100.0)/net_sales_after_refund as avg from vw_customer_base
select customer_id,customer_name,(discount_amount*100.0)/net_sales_after_refund as avg from vw_customer_base
order by avg desc

with segmentaion as(
SELECT 
    customer_id,
    customer_name,
    net_sales_after_refund,
    NO_ORDERS,
    CASE 
        WHEN net_sales_after_refund >= 100000 AND NO_ORDERS >= 50 
            THEN 'High Spending & High Frequency'
        WHEN net_sales_after_refund >= 100000 AND NO_ORDERS < 50 
            THEN 'High Spending & Low Frequency'
        WHEN net_sales_after_refund < 100000 AND NO_ORDERS >= 50 
            THEN 'Low Spending & High Frequency'
        WHEN net_sales_after_refund < 100000 AND NO_ORDERS < 50 
            THEN 'Low Spending & Low Frequency'
    END AS customer_segment
FROM vw_customer_base)
select * from segmentaion


select sum(case buyers when 'one' then no_orders else 0 end) as oncebuy,
sum(case buyers when 'more' then no_orders else 0 end) as morethanonce,(sum(case buyers when 'one' then no_orders else 0 end)*100.0)/
sum(no_orders) as oncebuy,
(sum(case buyers when 'more' then no_orders else 0 end)*100.0)/sum(no_orders) as morethanonce 
from(select customer_id,case when no_orders=1 then 'one' else 'more' end as buyers,no_orders from vw_customer_base) s 

select year(o.order_date) as year,month(o.order_date) as month,count(vc.customer_id) as count 
from vw_customer_base vc left join orders o on vc.customer_id=o.customer_id
where customer_status='Active'
group by year(o.order_date),month(o.order_date)
order by year,month

with new_vs_old_segment as(select  CASE 
        WHEN year(vc.signup_date) =2026 
            THEN 'New customer'
        else 'old customer'
    END AS customer_segment,net_sales_after_refund from vw_customer_base vc left join orders o on vc.customer_id=o.customer_id
    )select sum(net_sales_after_refund) as sales,customer_segment from new_vs_old_segment group by customer_segment

 with count as(select
       year(vc.signup_date) as year,count(vc.customer_id) as countof from vw_customer_base vc left join orders o on vc.customer_id=o.customer_id
       group by year(vc.signup_date)
    )select year,countof,lag(countof,1,0) over(order by year) as previous,countof-lag(countof) over(order by year) as chnage from count

select customer_id,customer_name,no_orders*1.0/(select sum(no_orders) from vw_customer_base) from vw_customer_base
select customer_id,customer_name,sum(net_sales_after_refund)over(order by net_sales_after_refund) from vw_customer_base
order by net_sales_after_refund desc

WITH cumulative_sales AS (
    SELECT
        customer_id,
        customer_name,
        net_sales_after_refund,
        SUM(net_sales_after_refund) OVER (
            ORDER BY net_sales_after_refund DESC
        ) AS cumulative_sales,
        ROW_NUMBER() OVER (
            ORDER BY net_sales_after_refund DESC
        ) AS rank
    FROM vw_customer_base
),
pareto AS (
    SELECT
        customer_id,
        customer_name,
        net_sales_after_refund,
        cumulative_sales,
        rank,
        cumulative_sales * 100.0 /
            NULLIF((SELECT SUM(net_sales_after_refund)
                    FROM vw_customer_base), 0) AS pareto
    FROM cumulative_sales
)
SELECT *
FROM pareto
WHERE rank <= (
    SELECT MIN(rank)
    FROM pareto
    WHERE pareto >= 80
);

SELECT c.customer_id, MIN(o.order_date) AS first_order_date, MAX(o.order_date) AS last_order_date
FROM vw_customer_base c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id;

CREATE OR ALTER VIEW vw_customer_rfm AS
SELECT
    vc.customer_id,
    vc.customer_name,
    vc.recency,
    vc.frequency,
    vc.monetary,
    NTILE(5) OVER (ORDER BY vc.recency DESC)   AS recency_score,
    NTILE(5) OVER (ORDER BY vc.frequency ASC)  AS frequency_score,
    NTILE(5) OVER (ORDER BY vc.monetary ASC)   AS monetary_score
FROM vw_customer_base vc;


