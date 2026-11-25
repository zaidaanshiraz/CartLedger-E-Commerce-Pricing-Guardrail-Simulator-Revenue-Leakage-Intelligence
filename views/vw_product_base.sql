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
