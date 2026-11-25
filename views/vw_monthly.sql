CREATE VIEW vw_monthly AS
WITH Sales_Base AS (
    SELECT 
        oi.order_item_id,
        o.order_id,
        o.order_date,
        o.customer_id,
        oi.quantity,
        (oi.quantity * oi.unit_price) AS gross_sales,
        (oi.quantity * oi.unit_price * oi.discount_pct)/100 AS discount_amount,
        (oi.quantity * oi.unit_price) - ((oi.quantity * oi.unit_price * oi.discount_pct)/100) AS net_sales,
        ((oi.quantity * oi.unit_price) - ((oi.quantity * oi.unit_price * oi.discount_pct)/100)) + oi.tax_amount AS net_sales_incl_tax,
        oi.tax_amount AS tax_amount
    FROM orders o 
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'Completed' AND o.payment_status = 'Paid'
),
Monthly_Sales AS (
    SELECT 
        YEAR(c.order_date) AS sales_year,
        MONTH(c.order_date) AS sales_month,
        CONCAT(YEAR(c.order_date), MONTH(c.order_date)) AS year_month_key,
        SUM(c.quantity) AS monthly_original_units_sold,
        SUM(c.gross_sales) AS monthly_gross_sales,
        SUM(c.discount_amount) AS monthly_discount_amount,
        SUM(c.net_sales) AS monthly_net_sales,
        SUM(c.tax_amount) AS monthly_tax_amount,
        SUM(c.net_sales_incl_tax) AS monthly_net_sales_incl_tax
    FROM Sales_Base c
    GROUP BY YEAR(c.order_date), MONTH(c.order_date)
),
Monthly_Returns AS (
    SELECT
        YEAR(o.order_date) AS sales_year,
        MONTH(o.order_date) AS sales_month,
        CONCAT(YEAR(o.order_date), MONTH(o.order_date)) AS year_month_key,
        SUM(r.return_quantity) AS monthly_units_returned,
        SUM(r.refund_amount) AS monthly_refund_amount
    FROM returns r
    JOIN order_items oi
        ON r.order_item_id = oi.order_item_id
    JOIN orders o
        ON o.order_id = oi.order_id
    WHERE r.return_status = 'Approved'
      AND o.order_status = 'Completed'
      AND o.payment_status = 'Paid'
    GROUP BY
        YEAR(o.order_date),
        MONTH(o.order_date)
),
Monthly_Performance AS (
    SELECT 
        s.sales_year,
        s.sales_month,
        s.year_month_key,
        (s.monthly_original_units_sold - ISNULL(r.monthly_units_returned,0)) AS monthly_net_units_sold,
        (s.monthly_net_sales_incl_tax - ISNULL(r.monthly_refund_amount,0)) AS monthly_net_sales_after_refund,
        s.monthly_net_sales_incl_tax,
        s.monthly_tax_amount,
        s.monthly_discount_amount,
        s.monthly_net_sales,
        s.monthly_gross_sales,
        s.monthly_original_units_sold,
        ISNULL(r.monthly_units_returned,0) AS monthly_units_returned,
        ISNULL(r.monthly_refund_amount,0) AS monthly_refund_amount
    FROM Monthly_Sales s 
    LEFT JOIN Monthly_Returns r 
        ON s.year_month_key = r.year_month_key
),
Monthly_Orders AS (
    SELECT 
        CONCAT(YEAR(order_date), MONTH(order_date)) AS year_month_key,
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
    s.monthly_refund_amount,
    s.monthly_original_units_sold,
    s.monthly_units_returned,
    s.monthly_net_units_sold,
    s.monthly_net_sales_after_refund,
    m.monthly_completed_paid_orders,
    CASE 
        WHEN m.monthly_completed_paid_orders = 0 THEN 0
        ELSE s.monthly_net_sales_after_refund / m.monthly_completed_paid_orders 
    END AS monthly_average_order_value
FROM Monthly_Performance s 
LEFT JOIN Monthly_Orders m 
    ON s.year_month_key = m.year_month_key

------------------------------------------------------------------------------------------------------------------------------------------------
--MOM

SELECT sales_year,sales_month,monthly_net_sales_after_refund ,
round((monthly_net_sales_after_refund-lag(monthly_net_sales_after_refund) over(order by sales_year ,sales_month))
/(nullif(lag(monthly_net_sales_after_refund,1,0) over(order by sales_year ,sales_month),0))*100,2) as Mont__over__Month from vw_monthly
order by sales_year ,sales_month


SELECT sales_year,sales_month,monthly_completed_paid_orders ,
round((monthly_completed_paid_orders-lag(monthly_completed_paid_orders) over(order by sales_year ,sales_month))
/(nullif(lag(monthly_completed_paid_orders,1,0) over(order by sales_year ,sales_month),0))*100,2) as Mont_over_Month_order_growth from vw_monthly
order by sales_year ,sales_month


SELECT sales_year,sales_month,monthly_net_units_sold ,
round((monthly_net_units_sold-lag(monthly_net_units_sold) over(order by sales_year ,sales_month))
/(nullif(lag(monthly_net_units_sold,1,0) over(order by sales_year ,sales_month),0))*100,2) as Mont_over_Month_units_growthwth from vw_monthly
order by sales_year ,sales_month


SELECT sales_year,sales_month,monthly_units_returned ,
round((monthly_units_returned-lag(monthly_units_returned) over(order by sales_year ,sales_month))
/(nullif(lag(monthly_units_returned,1,0) over(order by sales_year ,sales_month),0))*100,2) as Mont_over_Month_units_returned from vw_monthly
order by sales_year ,sales_month



SELECT sales_year,sales_month,monthly_average_order_value ,
round((monthly_average_order_value-lag(monthly_average_order_value) over(order by sales_year ,sales_month))
/(nullif(lag(monthly_average_order_value,1,0) over(order by sales_year ,sales_month),0))*100,2) as Mont_over_Mont_AOV from vw_monthly
order by sales_year ,sales_month

SELECT sales_year,sales_month,monthly_refund_amount ,
round((monthly_refund_amount-lag(monthly_refund_amount) over(order by sales_year ,sales_month))
/(nullif(lag(monthly_refund_amount,1,0) over(order by sales_year ,sales_month),0))*100,2) as Mont_over_Month_units_amount from vw_monthly
order by sales_year ,sales_month

-------------------------------------------------------------------------------------------------------------------------------------------
---YOY

SELECT sales_year,sum(monthly_net_sales_after_refund) as YoY_net_sales,
round((sum(monthly_net_sales_after_refund)-lag(sum(monthly_net_sales_after_refund)) over(order by sales_year ))
/(nullif(lag(sum(monthly_net_sales_after_refund),1,0) over(order by sales_year ),0))*100,2) as Mont__over__Month from vw_monthly
group by sales_year
order by sales_year 


SELECT sales_year,sum(monthly_completed_paid_orders) as YoY_orders,
round((sum(monthly_completed_paid_orders)-lag(sum(monthly_completed_paid_orders)) over(order by sales_year ))
/(nullif(lag(sum(monthly_completed_paid_orders),1,0) over(order by sales_year ),0))*100,2) as Mont__over__Month from vw_monthly
group by sales_year
order by sales_year 


SELECT sales_year,sum(monthly_net_units_sold) as YoY_units_sold,
round((sum(monthly_net_units_sold)-lag(sum(monthly_net_units_sold)) over(order by sales_year ))
/(nullif(lag(sum(monthly_net_units_sold),1,0) over(order by sales_year ),0))*100,2) as Mont__over__Month from vw_monthly
group by sales_year
order by sales_year 


SELECT sales_year,sum(monthly_units_returned) as YoY_Uits_returnde,
round((sum(monthly_units_returned)-lag(sum(monthly_units_returned)) over(order by sales_year ))
/(nullif(lag(sum(monthly_units_returned),1,0) over(order by sales_year ),0))*100,2) as Mont__over__Month from vw_monthly
group by sales_year
order by sales_year 
 
 
SELECT sales_year,sum(monthly_net_sales_after_refund)/sum(monthly_completed_paid_orders) as AOV_Year,
(sum(monthly_net_sales_after_refund)/sum(monthly_completed_paid_orders)-lag(sum(monthly_net_sales_after_refund)
/sum(monthly_completed_paid_orders)) over(order by sales_year))/
nullif(
 lag(sum(monthly_net_sales_after_refund)/sum(monthly_completed_paid_orders))over(order by sales_year),0)*100 as YOY_AOV from vw_monthly
group by sales_year
order by sales_year


SELECT sales_year,sum(monthly_refund_amount) as YoY_refundamount,
round((sum(monthly_refund_amount)-lag(sum(monthly_refund_amount)) over(order by sales_year ))
/(nullif(lag(sum(monthly_refund_amount),1,0) over(order by sales_year ),0))*100,2) as Mont__over__Month from vw_monthly
group by sales_year
order by sales_year

-------------------------------------------------------------------------------------------------------------------------------------------

select top 1 sales_year,sales_month,monthly_net_sales from vw_monthly order by monthly_net_sales desc
 select top 1 sales_year,sales_month,monthly_net_sales from vw_monthly order by monthly_net_sales asc
 select top 1 sales_year,sales_month,monthly_completed_paid_orders from vw_monthly order by monthly_completed_paid_orders desc
  select top 1 sales_year,sales_month,monthly_completed_paid_orders from vw_monthly order by monthly_completed_paid_orders asc
select top 1 sales_year,sales_month,monthly_refund_amount from vw_monthly order by monthly_refund_amount desc
select top 1 sales_year,sales_month,monthly_refund_amount from vw_monthly order by monthly_refund_amount asc

select (cast(monthly_units_returned as decimal(10,2))/nullif((monthly_original_units_sold),0))*100 as return_rate from vw_monthly

select (cast(monthly_discount_amount as decimal(10,2)/nullif((monthly_gross_sales),0))*100 as discount_rate from vw_monthly
select sales_year,sales_month,sum(monthly_net_sales) over(order by sales_year,sales_month) as runnig_sales from vw_monthly
select sales_year,sales_month,sum(monthly_completed_paid_orders) over(order by sales_year,sales_month) as running_orders from vw_monthly

-----------------------------------------------------------------------------------------------------------------------------------------------------
ytd

SELECT sales_year,sales_month,monthly_net_sales,sum(monthly_net_sales) over(partition by sales_year order by sales_month) as running_sales from vw_monthly

SELECT sales_year,sales_month,monthly_completed_paid_orders,sum(monthly_completed_paid_orders) over(partition by sales_year order by sales_month) as running_sales from vw_monthly

SELECT sales_year,sales_month,monthly_original_units_sold,sum(monthly_original_units_sold) over(partition by sales_year order by sales_month) as running_sales from vw_monthly
SELECT sales_year,sales_month,monthly_refund_amount,sum(monthly_refund_amount) over(partition by sales_year order by sales_month) as running_sales from vw_monthly
SELECT 
    SUM(
        CASE 
            WHEN sales_year = (SELECT MAX(sales_year) FROM vw_monthly)
             AND sales_month <= (
                 SELECT MAX(sales_month) 
                 FROM vw_monthly
                 WHERE sales_year = (SELECT MAX(sales_year) FROM vw_monthly)
             )
            THEN monthly_net_sales_after_refund
            ELSE 0
        END
    ) AS ytd,
    SUM(
        CASE 
            WHEN sales_year = (SELECT MAX(sales_year) FROM vw_monthly)-1
             AND sales_month <= (
                 SELECT MAX(sales_month) 
                 FROM vw_monthly
                 WHERE sales_year = (SELECT MAX(sales_year) FROM vw_monthly)
             )
            THEN monthly_net_sales_after_refund
            ELSE 0
        END
    ) AS previous_sameperiod
FROM vw_monthly
group by sales_year

-------------------------------------------
----chceks/validation
select (select sum(monthly_net_sales_after_refund) from vw_monthly 
where sales_year=(Select MAX(sales_year) from vw_monthly)and sales_month<=(select max(sales_month) from vw_monthly where sales_year=(Select MAX(sales_year) from vw_monthly))) as current_year,(select sum(monthly_net_sales_after_refund) from vw_monthly 
where sales_year=(Select MAX(sales_year) from vw_monthly)-1 and sales_month<=(select max(sales_month) from vw_monthly where sales_year=(Select MAX(sales_year) from vw_monthly))) as prvious_year

select SUM(monthly_net_sales_after_refund),sum(monthly_completed_paid_orders)from vw_monthly
select max(sales_month)  from vw_monthly where sales_year='2026'


SELECT
    SUM(monthly_net_sales_incl_tax) AS sales_incl_tax,
    SUM(monthly_refund_amount) AS refunds,
    SUM(monthly_net_sales_after_refund) AS after_refund
FROM vw_monthly;
