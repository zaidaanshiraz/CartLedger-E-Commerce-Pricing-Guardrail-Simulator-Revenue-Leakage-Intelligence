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
