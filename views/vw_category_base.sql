CREATE VIEW vw_category_base AS
WITH category_base AS (
    SELECT
        p.product_id,
        c.category_id,
        oi.order_item_id,
        o.order_id,
        o.order_date,
        oi.quantity,
        oi.unit_price,
        oi.discount_pct,
        oi.tax_amount,
        p.cost_price,
        p.selling_price,
        p.brand
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p  ON oi.product_id = p.product_id
    join categories c on c.category_id=p.category_id
    WHERE o.order_status = 'Completed'
      AND o.payment_status = 'Paid'
),
revenue_by_category AS (
    SELECT
        category_id,
        count(DISTINCT order_id) AS NO_ORDERS,
        SUM(quantity * unit_price)                                                        AS gross,
        SUM((quantity * unit_price * discount_pct) / 100)                                 AS discount_amount,
        SUM((quantity * unit_price) - (quantity * unit_price * discount_pct) / 100)       AS netsales_bf_tax,
        SUM(tax_amount)                                                                   AS tax_amount,
        SUM((quantity * unit_price) - (quantity * unit_price * discount_pct) / 100
            + tax_amount)                                                                 AS netsales_af_tax,
        SUM(quantity)                                                                     AS quantity
    FROM category_base
    GROUP BY category_id
),
returns_by_category AS (
    SELECT
        c.category_id,
        SUM(r.return_quantity) AS return_quantity,
        SUM(r.refund_amount)   AS refund_amt
    FROM returns r
    JOIN order_items oi ON oi.order_item_id = r.order_item_id
    JOIN orders o       ON o.order_id = oi.order_id
    join products p on p.product_id=oi.product_id join categories c on c.category_id=p.category_id
    WHERE r.return_status = 'Approved'
      AND o.order_status = 'Completed'
      AND o.payment_status = 'Paid'
    GROUP BY c.category_id
),
category_performance AS (
    SELECT
        r.category_id,
        r.gross,
        r.discount_amount,
        r.netsales_bf_tax,
        r.netsales_af_tax,
        r.tax_amount,
        r.quantity,
        r.NO_ORDERS,
        ISNULL(rp.return_quantity, 0) AS return_quantity,
        ISNULL(rp.refund_amt, 0)      AS refund_amt
    FROM revenue_by_category r
    LEFT JOIN returns_by_category rp ON r.category_id = rp.category_id
)
SELECT
   c.category_id,
    c.category_name,
    cp.gross,
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
FROM category_performance cp join categories c on c.category_id=cp.category_id;
