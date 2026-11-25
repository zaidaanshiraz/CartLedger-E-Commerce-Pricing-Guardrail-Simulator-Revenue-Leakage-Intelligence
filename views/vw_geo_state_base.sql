create view vw_geo_state_base as
with geo_base as(
	select 
	o.order_id,
	c.customer_id,
        oi.order_item_id,
        o.shipping_state,
        o.order_date,
        oi.quantity,
        oi.unit_price,
        oi.discount_pct,
        oi.tax_amount
	from orders o join order_items oi on o.order_id=oi.order_id join customers c on o.customer_id = c.customer_id
     WHERE o.order_status = 'Completed'
      AND o.payment_status = 'Paid'
	),revenue_by_customer AS (
    SELECT
        shipping_state,
        count(DISTINCT customer_id) AS NO_Customers,
        SUM(quantity * unit_price)                                                        AS gross,
        SUM((quantity * unit_price * discount_pct) / 100)                                 AS discount_amount,
        SUM((quantity * unit_price) - (quantity * unit_price * discount_pct) / 100)       AS netsales_bf_tax,
        SUM(tax_amount)                                                                   AS tax_amount,
        SUM((quantity * unit_price) - (quantity * unit_price * discount_pct) / 100
            + tax_amount)                                                                 AS netsales_af_tax,
        SUM(quantity)as quantity,
        count(DISTINCT order_id) AS NO_ORDERS
    FROM geo_base
    GROUP BY shipping_state
    ),returns_by_cutomer AS (
    SELECT
        o.shipping_state,
        SUM(r.return_quantity) AS return_quantity,
        SUM(r.refund_amount)   AS refund_amt
    FROM returns r
    JOIN order_items oi ON oi.order_item_id = r.order_item_id
    JOIN orders o       ON o.order_id = oi.order_id
    WHERE r.return_status = 'Approved'
      AND (o.order_status = 'Completed'
      AND o.payment_status = 'Paid')
    GROUP BY o.shipping_state
    ),customer_performance AS (
    SELECT
        r.gross,
        r.NO_Customers,
        r.shipping_state,
        r.discount_amount,
        r.netsales_bf_tax,
        r.netsales_af_tax,
        r.tax_amount,
        r.quantity,
        r.NO_ORDERS,
        ISNULL(rp.return_quantity, 0) AS return_quantity,
        ISNULL(rp.refund_amt, 0)      AS refund_amt
    FROM revenue_by_customer r
    LEFT JOIN returns_by_cutomer rp ON r.shipping_state = rp.shipping_state
)
SELECt
    cp.shipping_state,
    cp.gross,
    cp.NO_Customers,
    cp.discount_amount,
    cp.netsales_bf_tax,
    cp.netsales_af_tax,
    cp.tax_amount,
    cp.NO_ORDERS,
    cp.quantity,
    cp.return_quantity,
    cp.refund_amt,
    cp.quantity - return_quantity                AS net_units_sold,
    cp.netsales_af_tax - refund_amt              AS net_sales_after_refund,
    cp.return_quantity * 100.0 / quantity        AS return_rate,
    cp.discount_amount * 100.0 / gross           AS discount_rate
    from customer_performance cp
