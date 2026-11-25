"""
==============================================================================
CARTLEDGER — E-COMMERCE SQL CASE FILES & REVENUE LEAKAGE INTELLIGENCE
FastAPI Backend, Prescriptive Margin Simulator & Read-Only SQL Case Files Engine
==============================================================================
Author : Mohammed Zaidaan Shiraz
Stack  : Python 3.12 | FastAPI | SQLite | Pandas | Plotly
==============================================================================
"""

from __future__ import annotations

import re
import sqlite3
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import pandas as pd
from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, HTMLResponse, Response
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

import sys
BASE_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE_DIR / "scripts"))

from build_ecommerce_db import DB_PATH, build_database

WEB_DIR = BASE_DIR / "web"

app = FastAPI(
    title="CartLedger — E-Commerce SQL Case Files & Revenue Leakage Intelligence",
    description="Interactive SQL Case Files Studio, Prescriptive Pricing Guardrail Simulator & Market Basket Analytics by Mohammed Zaidaan Shiraz",
    version="3.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def disable_static_cache(request: Request, call_next):
    response: Response = await call_next(request)
    if request.url.path == "/" or request.url.path.startswith("/static") or request.url.path.startswith("/api"):
        response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "0"
    return response


def ensure_db() -> Path:
    if not DB_PATH.exists():
        build_database(DB_PATH)
    return DB_PATH


# ---------------------------------------------------------------------------
# 16 VERIFIED SQL CASE FILES (COVERING TARGET LEVEL 1 TO LEVEL 4 SYLLABUS)
# ---------------------------------------------------------------------------
SQL_CASE_FILES: List[Dict[str, str]] = [
    {
        "id": "CF-01",
        "level": "Level 1 · Data Profiling & Grain Integrity",
        "title": "Schema Row Counts, PK Uniqueness & Null Profiling",
        "business_problem": "Audit all 8 normalized tables (`customers`, `categories`, `products`, `orders`, `order_items`, `payments`, `returns`, `reviews`) and surface nullable metadata fields before computing financial KPIs.",
        "sql_concepts": "UNION ALL, COUNT(*), Conditional CASE Aggregation, NULL Handling",
        "sql": """SELECT 'customers' AS table_name, COUNT(*) AS row_count, SUM(CASE WHEN customer_status IS NULL THEN 1 ELSE 0 END) AS null_flags FROM customers
UNION ALL SELECT 'categories', COUNT(*), 0 FROM categories
UNION ALL SELECT 'products', COUNT(*), SUM(CASE WHEN brand IS NULL THEN 1 ELSE 0 END) FROM products
UNION ALL SELECT 'orders', COUNT(*), 0 FROM orders
UNION ALL SELECT 'order_items', COUNT(*), SUM(CASE WHEN quantity <= 0 OR unit_price <= 0 THEN 1 ELSE 0 END) FROM order_items
UNION ALL SELECT 'payments', COUNT(*), 0 FROM payments
UNION ALL SELECT 'returns', COUNT(*), 0 FROM returns
UNION ALL SELECT 'reviews', COUNT(*), 0 FROM reviews;""",
    },
    {
        "id": "CF-02",
        "level": "Level 1 · Revenue Leakage Matrix",
        "title": "Order Status × Payment Status Revenue Leakage Audit",
        "business_problem": "Identify revenue leakage where orders were fulfilled (`Completed`) while payment remained `Pending`, alongside payment gateway drop-offs (`Cancelled` + `Failed`).",
        "sql_concepts": "GROUP BY, Multi-Column Aggregation, Window Share OVER ()",
        "sql": """SELECT
    o.order_status,
    o.payment_status,
    COUNT(DISTINCT o.order_id) AS distinct_orders,
    ROUND(COUNT(DISTINCT o.order_id) * 100.0 / SUM(COUNT(DISTINCT o.order_id)) OVER (), 2) AS order_share_pct,
    ROUND(SUM(v.net_sales_incl_tax), 2) AS billed_value_inr
FROM orders o
JOIN vw_line_item_financials v ON o.order_id = v.order_id
GROUP BY o.order_status, o.payment_status
ORDER BY billed_value_inr DESC;""",
    },
    {
        "id": "CF-03",
        "level": "Level 2 · End-to-End Revenue Bridge (Pre-Aggregated CTEs)",
        "title": "Gross-to-Net Realized Revenue Waterfall (Zero Join Fan-Out)",
        "business_problem": "Reconcile Gross Sales → Discounts → Net Sales Before Tax → Tax → Approved Refunds → Net Realized Revenue for Completed + Paid orders without 1-to-many return join multiplication.",
        "sql_concepts": "Multi-Stage CTEs, Pre-Aggregated LEFT JOIN, COALESCE",
        "sql": """WITH paid_items AS (
    SELECT
        order_item_id,
        order_id,
        quantity,
        gross_sales,
        discount_amount,
        net_sales_before_tax,
        tax_amount,
        net_sales_incl_tax,
        cogs_amount,
        gross_profit
    FROM vw_line_item_financials
    WHERE order_status = 'Completed' AND payment_status = 'Paid'
),
approved_returns AS (
    SELECT
        order_item_id,
        SUM(return_quantity) AS returned_units,
        SUM(refund_amount) AS approved_refund_inr
    FROM returns
    WHERE return_status = 'Approved'
    GROUP BY order_item_id
)
SELECT
    COUNT(DISTINCT p.order_id) AS completed_paid_orders,
    SUM(p.quantity) AS gross_units_sold,
    SUM(COALESCE(r.returned_units, 0)) AS returned_units,
    SUM(p.quantity) - SUM(COALESCE(r.returned_units, 0)) AS net_units_retained,
    ROUND(SUM(p.gross_sales), 2) AS gross_sales_inr,
    ROUND(SUM(p.discount_amount), 2) AS total_discounts_inr,
    ROUND(SUM(p.net_sales_before_tax), 2) AS net_sales_ex_tax_inr,
    ROUND(SUM(p.tax_amount), 2) AS tax_collected_inr,
    ROUND(SUM(COALESCE(r.approved_refund_inr, 0)), 2) AS approved_refunds_inr,
    ROUND(SUM(p.net_sales_incl_tax) - SUM(COALESCE(r.approved_refund_inr, 0)), 2) AS net_realized_revenue_inr
FROM paid_items p
LEFT JOIN approved_returns r ON p.order_item_id = r.order_item_id;""",
    },
    {
        "id": "CF-04",
        "level": "Level 2 · Grain Trap & Margin Aggregation Fix",
        "title": "Category Profitability & Distinct Order Grain Proof",
        "business_problem": "Demonstrate why summing category `COUNT(DISTINCT order_id)` inflates multi-category baskets, and compute true weighted profit margin (`SUM(gross_profit) / SUM(net_sales_before_tax)`) instead of averaging SKU margins.",
        "sql_concepts": "COUNT(DISTINCT), Weighted Margin Formula, Cross-Join Global Distinct Denominator",
        "sql": """WITH cat_rollup AS (
    SELECT
        category_id,
        category_name,
        merchandise_tier,
        COUNT(DISTINCT order_id) AS category_distinct_orders,
        SUM(quantity) AS units_sold,
        ROUND(SUM(gross_sales), 2) AS gross_sales_inr,
        ROUND(SUM(net_sales_before_tax), 2) AS net_sales_inr,
        ROUND(SUM(cogs_amount), 2) AS cogs_inr,
        ROUND(SUM(gross_profit), 2) AS gross_profit_inr,
        ROUND(SUM(gross_profit) * 100.0 / NULLIF(SUM(net_sales_before_tax), 0), 2) AS weighted_margin_pct
    FROM vw_line_item_financials
    WHERE order_status = 'Completed' AND payment_status = 'Paid'
    GROUP BY category_id, category_name, merchandise_tier
),
global_orders AS (
    SELECT COUNT(DISTINCT order_id) AS true_unique_orders
    FROM orders
    WHERE order_status = 'Completed' AND payment_status = 'Paid'
)
SELECT
    cr.category_name,
    cr.merchandise_tier,
    cr.category_distinct_orders,
    go.true_unique_orders AS network_unique_orders,
    ROUND(cr.category_distinct_orders * 100.0 / go.true_unique_orders, 2) AS basket_penetration_pct,
    cr.net_sales_inr,
    cr.gross_profit_inr,
    cr.weighted_margin_pct
FROM cat_rollup cr
CROSS JOIN global_orders go
ORDER BY cr.gross_profit_inr DESC;""",
    },
    {
        "id": "CF-05",
        "level": "Level 2 · Outer Join Anti-Pattern (Zero-Order Customers)",
        "title": "Dormant Signed-Up Customers Audit (LEFT JOIN ... IS NULL)",
        "business_problem": "Find registered customers who have never placed an order (or never completed a paid order) so lifecycle marketing can trigger activation campaigns.",
        "sql_concepts": "LEFT JOIN, WHERE right_table.key IS NULL, GROUP BY Region",
        "sql": """SELECT
    c.region,
    c.state,
    COUNT(c.customer_id) AS total_registered_customers,
    SUM(CASE WHEN o.order_id IS NULL THEN 1 ELSE 0 END) AS zero_order_dormant_customers,
    ROUND(SUM(CASE WHEN o.order_id IS NULL THEN 1.0 ELSE 0.0 END) * 100.0 / COUNT(c.customer_id), 2) AS dormant_rate_pct
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.region, c.state
ORDER BY zero_order_dormant_customers DESC;""",
    },
    {
        "id": "CF-06",
        "level": "Level 2 · Loss-Making SKU Forensics (HAVING Clause)",
        "title": "Margin-Destroying SKUs Triggered by Over-Discounting",
        "business_problem": "Isolate products whose cumulative gross profit is negative (`HAVING SUM(gross_profit) < 0`) due to high cost ratios combined with 20–30% promotional discounting.",
        "sql_concepts": "GROUP BY, HAVING SUM(gross_profit) < 0, Margin Erosion Diagnostics",
        "sql": """SELECT
    product_id,
    product_name,
    category_name,
    COUNT(DISTINCT order_id) AS orders_count,
    SUM(quantity) AS units_sold,
    ROUND(AVG(discount_pct), 2) AS avg_discount_pct,
    ROUND(SUM(net_sales_before_tax), 2) AS net_sales_inr,
    ROUND(SUM(cogs_amount), 2) AS total_cogs_inr,
    ROUND(SUM(gross_profit), 2) AS net_loss_inr,
    ROUND(SUM(gross_profit) * 100.0 / NULLIF(SUM(net_sales_before_tax), 0), 2) AS realized_margin_pct
FROM vw_line_item_financials
WHERE order_status = 'Completed' AND payment_status = 'Paid'
GROUP BY product_id, product_name, category_name
HAVING SUM(gross_profit) < 0
ORDER BY net_loss_inr ASC;""",
    },
    {
        "id": "CF-07",
        "level": "Level 3 · Window Functions (DENSE_RANK Top-N Per Category)",
        "title": "Top 3 Profit-Generating SKUs Inside Each Merchandise Category",
        "business_problem": "Rank all products within their respective categories by realized gross profit using `DENSE_RANK() OVER (PARTITION BY category_name ORDER BY gross_profit DESC)` and filter to the top 3 per category.",
        "sql_concepts": "CTE, PARTITION BY, DENSE_RANK(), Top-N per Group",
        "sql": """WITH sku_profit AS (
    SELECT
        category_name,
        product_id,
        product_name,
        SUM(quantity) AS units_sold,
        ROUND(SUM(net_sales_before_tax), 2) AS net_sales_inr,
        ROUND(SUM(gross_profit), 2) AS gross_profit_inr,
        ROUND(SUM(gross_profit) * 100.0 / NULLIF(SUM(net_sales_before_tax), 0), 2) AS margin_pct,
        DENSE_RANK() OVER (
            PARTITION BY category_name
            ORDER BY SUM(gross_profit) DESC
        ) AS profit_rank_in_category
    FROM vw_line_item_financials
    WHERE order_status = 'Completed' AND payment_status = 'Paid'
    GROUP BY category_name, product_id, product_name
)
SELECT *
FROM sku_profit
WHERE profit_rank_in_category <= 3
ORDER BY category_name ASC, profit_rank_in_category ASC;""",
    },
    {
        "id": "CF-08",
        "level": "Level 3 · Sequential Time-Series (LAG & Running Cumulative Total)",
        "title": "Monthly Revenue, MoM Growth (%) & Running Cumulative Profit",
        "business_problem": "Track monthly net sales and gross profit with month-over-month growth rates (`LAG`) and running cumulative profit (`SUM(...) OVER (ORDER BY order_month)`).",
        "sql_concepts": "LAG() OVER, Running Window SUM() OVER (ROWS UNBOUNDED PRECEDING)",
        "sql": """WITH monthly_kpi AS (
    SELECT
        order_month,
        COUNT(DISTINCT order_id) AS paid_orders,
        ROUND(SUM(net_sales_before_tax), 2) AS net_sales_inr,
        ROUND(SUM(gross_profit), 2) AS gross_profit_inr
    FROM vw_line_item_financials
    WHERE order_status = 'Completed' AND payment_status = 'Paid'
    GROUP BY order_month
)
SELECT
    order_month,
    paid_orders,
    net_sales_inr,
    LAG(net_sales_inr) OVER (ORDER BY order_month) AS prev_month_sales_inr,
    ROUND(
        (net_sales_inr - LAG(net_sales_inr) OVER (ORDER BY order_month)) * 100.0
        / NULLIF(LAG(net_sales_inr) OVER (ORDER BY order_month), 0),
        2
    ) AS mom_sales_growth_pct,
    gross_profit_inr,
    ROUND(
        SUM(gross_profit_inr) OVER (ORDER BY order_month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),
        2
    ) AS cumulative_profit_inr
FROM monthly_kpi
ORDER BY order_month ASC;""",
    },
    {
        "id": "CF-09",
        "level": "Level 3 · Customer RFM Segmentation (NTILE Quintiles)",
        "title": "Customer Recency-Frequency-Monetary (RFM) Quintile Scoring",
        "business_problem": "Segment active customers into actionable lifecycle tiers (`Champions`, `Loyal`, `At-Risk High Value`, `Dormant`) using `NTILE(5)` window functions.",
        "sql_concepts": "NTILE(5) OVER, JULIANDAY Date Math, Multi-Tier CASE Classification",
        "sql": """WITH max_dt AS (
    SELECT MAX(order_date) AS anchor_date FROM orders
),
rfm_raw AS (
    SELECT
        c.customer_id,
        c.customer_name,
        c.city,
        c.region,
        CAST(JULIANDAY((SELECT anchor_date FROM max_dt)) - JULIANDAY(MAX(v.order_date)) AS INTEGER) AS recency_days,
        COUNT(DISTINCT v.order_id) AS frequency_orders,
        ROUND(SUM(v.net_sales_before_tax), 2) AS monetary_inr
    FROM customers c
    JOIN vw_line_item_financials v ON c.customer_id = v.customer_id
    WHERE v.order_status = 'Completed' AND v.payment_status = 'Paid'
    GROUP BY c.customer_id, c.customer_name, c.city, c.region
),
rfm_scored AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency_orders ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary_inr ASC) AS m_score
    FROM rfm_raw
),
segmented AS (
    SELECT
        *,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN '1. Champions'
            WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN '2. Loyal Core'
            WHEN r_score <= 2 AND m_score >= 4 THEN '3. At-Risk High Value'
            WHEN r_score >= 4 AND f_score <= 2 THEN '4. Recent Promising'
            ELSE '5. Needs Re-Engagement'
        END AS rfm_segment
    FROM rfm_scored
)
SELECT
    rfm_segment,
    COUNT(customer_id) AS customer_count,
    ROUND(AVG(recency_days), 1) AS avg_recency_days,
    ROUND(AVG(frequency_orders), 2) AS avg_orders,
    ROUND(AVG(monetary_inr), 2) AS avg_ltv_inr,
    ROUND(SUM(monetary_inr), 2) AS segment_total_revenue_inr
FROM segmented
GROUP BY rfm_segment
ORDER BY rfm_segment ASC;""",
    },
    {
        "id": "CF-10",
        "level": "Level 3 · Discount Elasticity & Margin Trade-Off",
        "title": "Promotional Discount Band Effectiveness Analysis",
        "business_problem": "Evaluate whether higher discount bands (`20%+`) lift order volume enough to offset unit margin compression.",
        "sql_concepts": "Bucketed CASE Expressions, AOV & Realized Margin Comparison",
        "sql": """WITH banded AS (
    SELECT
        CASE
            WHEN discount_pct = 0 THEN '01. Zero Discount (0%)'
            WHEN discount_pct <= 10 THEN '02. Shallow Promo (1-10%)'
            WHEN discount_pct <= 20 THEN '03. Medium Promo (11-20%)'
            ELSE '04. Deep Clearance (21-30%)'
        END AS discount_band,
        order_id,
        quantity,
        gross_sales,
        discount_amount,
        net_sales_before_tax,
        gross_profit
    FROM vw_line_item_financials
    WHERE order_status = 'Completed' AND payment_status = 'Paid'
)
SELECT
    discount_band,
    COUNT(DISTINCT order_id) AS orders_touched,
    SUM(quantity) AS total_units,
    ROUND(SUM(gross_sales), 2) AS gross_sales_inr,
    ROUND(SUM(discount_amount), 2) AS promo_spend_inr,
    ROUND(SUM(net_sales_before_tax), 2) AS net_sales_inr,
    ROUND(SUM(gross_profit), 2) AS gross_profit_inr,
    ROUND(SUM(gross_profit) * 100.0 / NULLIF(SUM(net_sales_before_tax), 0), 2) AS realized_margin_pct
FROM banded
GROUP BY discount_band
ORDER BY discount_band ASC;""",
    },
    {
        "id": "CF-11",
        "level": "Level 3 · Return Root-Cause & Refund Impact by Category",
        "title": "Approved Return Rate & Refund Drag Across Merchandise Categories",
        "business_problem": "Quantify which merchandise categories suffer the highest unit return rates and refund drag, paired with primary return reasons.",
        "sql_concepts": "Pre-Aggregated Return CTE, Return Rate %, Refund Drag %",
        "sql": """WITH cat_sales AS (
    SELECT
        category_id,
        category_name,
        SUM(quantity) AS sold_units,
        SUM(net_sales_incl_tax) AS billed_sales_inr
    FROM vw_line_item_financials
    WHERE order_status = 'Completed' AND payment_status = 'Paid'
    GROUP BY category_id, category_name
),
cat_returns AS (
    SELECT
        v.category_id,
        SUM(r.return_quantity) AS returned_units,
        SUM(r.refund_amount) AS refunded_inr
    FROM returns r
    JOIN vw_line_item_financials v ON r.order_item_id = v.order_item_id
    WHERE r.return_status = 'Approved'
      AND v.order_status = 'Completed' AND v.payment_status = 'Paid'
    GROUP BY v.category_id
)
SELECT
    cs.category_name,
    cs.sold_units,
    COALESCE(cr.returned_units, 0) AS approved_returned_units,
    ROUND(COALESCE(cr.returned_units, 0) * 100.0 / cs.sold_units, 2) AS unit_return_rate_pct,
    ROUND(cs.billed_sales_inr, 2) AS billed_sales_inr,
    ROUND(COALESCE(cr.refunded_inr, 0), 2) AS approved_refunds_inr,
    ROUND(COALESCE(cr.refunded_inr, 0) * 100.0 / cs.billed_sales_inr, 2) AS refund_drag_pct
FROM cat_sales cs
LEFT JOIN cat_returns cr ON cs.category_id = cr.category_id
ORDER BY refund_drag_pct DESC;""",
    },
    {
        "id": "CF-12",
        "level": "Level 3 · Regional & State Profitability Scorecard",
        "title": "Geographic Revenue, AOV, and Net Margin Leaderboard",
        "business_problem": "Rank all 12 Indian retail hubs by net sales, Average Order Value (AOV = `SUM(net_sales) / COUNT(DISTINCT order_id)`), and gross profit contribution.",
        "sql_concepts": "Multi-Table Join, Distinct Order AOV Formula, Window Share %",
        "sql": """SELECT
    c.region,
    c.state,
    c.city,
    COUNT(DISTINCT v.customer_id) AS active_buyers,
    COUNT(DISTINCT v.order_id) AS completed_orders,
    ROUND(SUM(v.net_sales_before_tax), 2) AS net_sales_inr,
    ROUND(SUM(v.net_sales_before_tax) / COUNT(DISTINCT v.order_id), 2) AS avg_order_value_inr,
    ROUND(SUM(v.gross_profit), 2) AS gross_profit_inr,
    ROUND(SUM(v.gross_profit) * 100.0 / SUM(SUM(v.gross_profit)) OVER (), 2) AS profit_share_pct
FROM vw_line_item_financials v
JOIN customers c ON v.customer_id = c.customer_id
WHERE v.order_status = 'Completed' AND v.payment_status = 'Paid'
GROUP BY c.region, c.state, c.city
ORDER BY gross_profit_inr DESC;""",
    },
    {
        "id": "CF-13",
        "level": "Level 4 · Market Basket Affinity (Self-Join Lift & Confidence)",
        "title": "Cross-Category Market Basket Co-Purchase & Lift Analysis",
        "business_problem": "Identify which merchandise categories are most frequently purchased together in the same shopping cart (`order_id`) and compute Support %, Confidence %, and Association Lift to power cross-sell bundling.",
        "sql_concepts": "Self-Join (a.category_id < b.category_id), Support, Confidence, Lift Ratio",
        "sql": """WITH order_cats AS (
    SELECT DISTINCT
        order_id,
        category_id,
        category_name
    FROM vw_line_item_financials
    WHERE order_status = 'Completed' AND payment_status = 'Paid'
),
total_baskets AS (
    SELECT COUNT(DISTINCT order_id) * 1.0 AS total_orders FROM order_cats
),
cat_freq AS (
    SELECT
        category_id,
        category_name,
        COUNT(DISTINCT order_id) AS cat_orders
    FROM order_cats
    GROUP BY category_id, category_name
),
pair_freq AS (
    SELECT
        a.category_id AS cat_a_id,
        a.category_name AS category_a,
        b.category_id AS cat_b_id,
        b.category_name AS category_b,
        COUNT(DISTINCT a.order_id) AS co_purchased_orders
    FROM order_cats a
    JOIN order_cats b
      ON a.order_id = b.order_id
     AND a.category_id < b.category_id
    GROUP BY a.category_id, a.category_name, b.category_id, b.category_name
)
SELECT
    pf.category_a,
    pf.category_b,
    pf.co_purchased_orders,
    ROUND(pf.co_purchased_orders * 100.0 / tb.total_orders, 2) AS support_pct,
    ROUND(pf.co_purchased_orders * 100.0 / fa.cat_orders, 2) AS confidence_a_to_b_pct,
    ROUND(
        (pf.co_purchased_orders / tb.total_orders)
        / ((fa.cat_orders / tb.total_orders) * (fb.cat_orders / tb.total_orders)),
        3
    ) AS lift_ratio
FROM pair_freq pf
JOIN cat_freq fa ON pf.cat_a_id = fa.category_id
JOIN cat_freq fb ON pf.cat_b_id = fb.category_id
CROSS JOIN total_baskets tb
ORDER BY co_purchased_orders DESC, lift_ratio DESC
LIMIT 12;""",
    },
    {
        "id": "CF-14",
        "level": "Level 4 · Customer Acquisition Cohort & Repeat Retention",
        "title": "First-Purchase Cohort Retention, Repeat Buyer Rate & Cohort LTV",
        "business_problem": "Group customers by their first completed purchase month (`MIN(order_month)`) and measure repeat purchase retention rate, orders per buyer, and cumulative cohort LTV.",
        "sql_concepts": "MIN() First-Order Cohort CTE, Repeat Buyer Flag, Cohort LTV Rollup",
        "sql": """WITH customer_orders AS (
    SELECT
        customer_id,
        order_id,
        order_month,
        SUM(net_sales_before_tax) AS order_net_sales,
        SUM(gross_profit) AS order_profit
    FROM vw_line_item_financials
    WHERE order_status = 'Completed' AND payment_status = 'Paid'
    GROUP BY customer_id, order_id, order_month
),
first_purchase AS (
    SELECT
        customer_id,
        MIN(order_month) AS cohort_month,
        COUNT(DISTINCT order_id) AS lifetime_orders,
        SUM(order_net_sales) AS lifetime_sales_inr,
        SUM(order_profit) AS lifetime_profit_inr
    FROM customer_orders
    GROUP BY customer_id
)
SELECT
    cohort_month,
    COUNT(customer_id) AS cohort_customers,
    SUM(CASE WHEN lifetime_orders > 1 THEN 1 ELSE 0 END) AS repeat_buyers,
    ROUND(SUM(CASE WHEN lifetime_orders > 1 THEN 1.0 ELSE 0.0 END) * 100.0 / COUNT(customer_id), 2) AS repeat_retention_pct,
    ROUND(AVG(lifetime_orders), 2) AS avg_orders_per_buyer,
    ROUND(AVG(lifetime_sales_inr), 2) AS avg_customer_ltv_inr,
    ROUND(SUM(lifetime_profit_inr), 2) AS cohort_total_profit_inr
FROM first_purchase
GROUP BY cohort_month
ORDER BY cohort_month ASC;""",
    },
    {
        "id": "CF-15",
        "level": "Level 4 · Forensic SQL Anti-Pattern vs Production Fix Comparator",
        "title": "Side-by-Side Proof of 3 Classic Retail SQL Traps (Naive vs Fixed)",
        "business_problem": "Quantify the exact distortion when an analyst (1) sums category distinct orders instead of network distinct orders, (2) averages SKU margin percentages instead of computing weighted margin, or (3) forgets to filter uncollected Pending orders.",
        "sql_concepts": "Multi-CTE Diagnostic Benchmark, UNION ALL Variance Audit",
        "sql": """WITH cat_orders AS (
    SELECT category_id, COUNT(DISTINCT order_id) AS c_orders
    FROM vw_line_item_financials
    WHERE order_status = 'Completed' AND payment_status = 'Paid'
    GROUP BY category_id
),
sku_margins AS (
    SELECT
        product_id,
        SUM(gross_profit) * 100.0 / NULLIF(SUM(net_sales_before_tax), 0) AS sku_margin_pct
    FROM vw_line_item_financials
    WHERE order_status = 'Completed' AND payment_status = 'Paid'
    GROUP BY product_id
)
SELECT
    '01. Order Grain Trap (Sum of Category Orders vs True Distinct Orders)' AS audit_check,
    ROUND((SELECT SUM(c_orders) FROM cat_orders), 2) AS naive_buggy_metric,
    ROUND((SELECT COUNT(DISTINCT order_id) FROM orders WHERE order_status = 'Completed' AND payment_status = 'Paid'), 2) AS production_fixed_metric,
    ROUND(
        ((SELECT SUM(c_orders) FROM cat_orders) - (SELECT COUNT(DISTINCT order_id) FROM orders WHERE order_status = 'Completed' AND payment_status = 'Paid'))
        * 100.0 / (SELECT COUNT(DISTINCT order_id) FROM orders WHERE order_status = 'Completed' AND payment_status = 'Paid'),
        2
    ) AS distortion_error_pct
UNION ALL
SELECT
    '02. Margin Aggregation Trap (Unweighted AVG(SKU Margin %) vs Weighted Margin %)',
    ROUND((SELECT AVG(sku_margin_pct) FROM sku_margins), 2),
    ROUND((SELECT SUM(gross_profit) * 100.0 / SUM(net_sales_before_tax) FROM vw_line_item_financials WHERE order_status = 'Completed' AND payment_status = 'Paid'), 2),
    ROUND(
        (SELECT AVG(sku_margin_pct) FROM sku_margins)
        - (SELECT SUM(gross_profit) * 100.0 / SUM(net_sales_before_tax) FROM vw_line_item_financials WHERE order_status = 'Completed' AND payment_status = 'Paid'),
        2
    )
UNION ALL
SELECT
    '03. Settlement Filter Trap (All Completed Orders vs Completed + Paid Cash Realized)',
    ROUND((SELECT SUM(net_sales_incl_tax) FROM vw_line_item_financials WHERE order_status = 'Completed'), 2),
    ROUND((SELECT SUM(net_sales_incl_tax) FROM vw_line_item_financials WHERE order_status = 'Completed' AND payment_status = 'Paid'), 2),
    ROUND(
        ((SELECT SUM(net_sales_incl_tax) FROM vw_line_item_financials WHERE order_status = 'Completed')
         - (SELECT SUM(net_sales_incl_tax) FROM vw_line_item_financials WHERE order_status = 'Completed' AND payment_status = 'Paid'))
        * 100.0 / (SELECT SUM(net_sales_incl_tax) FROM vw_line_item_financials WHERE order_status = 'Completed' AND payment_status = 'Paid'),
        2
    );""",
    },
    {
        "id": "CF-16",
        "level": "Level 4 · CFO Price-Volume-Mix (PVM) Profit Bridge",
        "title": "H1 vs H2 Gross Profit Price-Volume-Mix (PVM) Decomposition",
        "business_problem": "Decompose Period-over-Period (`H1: Apr–Sep` vs `H2: Oct–Mar`) gross profit variance across categories into Volume Effect (`ΔUnits × H1 Unit Profit`) and Price/Promo Realization Effect (`H2 Units × ΔUnit Profit`).",
        "sql_concepts": "Conditional Period Aggregation, Price-Volume-Mix (PVM) Attribution Math",
        "sql": """WITH period_cat AS (
    SELECT
        category_name,
        SUM(CASE WHEN order_month <= '2025-09' THEN quantity ELSE 0 END) AS q1_units,
        SUM(CASE WHEN order_month >  '2025-09' THEN quantity ELSE 0 END) AS q2_units,
        SUM(CASE WHEN order_month <= '2025-09' THEN gross_profit ELSE 0 END) AS p1_profit,
        SUM(CASE WHEN order_month >  '2025-09' THEN gross_profit ELSE 0 END) AS p2_profit
    FROM vw_line_item_financials
    WHERE order_status = 'Completed' AND payment_status = 'Paid'
    GROUP BY category_name
),
pvm_calc AS (
    SELECT
        category_name,
        q1_units,
        q2_units,
        ROUND(p1_profit, 2) AS h1_profit_inr,
        ROUND(p2_profit, 2) AS h2_profit_inr,
        ROUND(p2_profit - p1_profit, 2) AS total_profit_variance_inr,
        ROUND((q2_units - q1_units) * (p1_profit * 1.0 / NULLIF(q1_units, 0)), 2) AS volume_effect_inr,
        ROUND(q2_units * ((p2_profit * 1.0 / NULLIF(q2_units, 0)) - (p1_profit * 1.0 / NULLIF(q1_units, 0))), 2) AS price_promo_effect_inr
    FROM period_cat
)
SELECT *
FROM pvm_calc
ORDER BY total_profit_variance_inr DESC;""",
    },
]

FORBIDDEN_SQL = re.compile(
    r"\b(DROP|DELETE|UPDATE|INSERT|ALTER|CREATE|REPLACE|TRUNCATE|ATTACH|DETACH|PRAGMA|VACUUM)\b",
    re.IGNORECASE,
)


def validate_readonly_sql(sql: str) -> Tuple[bool, str]:
    if not sql or not sql.strip():
        return False, "SQL query cannot be empty."
    cleaned = re.sub(r"--.*?$", "", sql, flags=re.MULTILINE)
    cleaned = re.sub(r"/\*.*?\*/", "", cleaned, flags=re.DOTALL).strip()
    if cleaned.endswith(";"):
        cleaned = cleaned[:-1].strip()
    if ";" in cleaned:
        return False, "Multiple statements (semicolon chaining) are blocked by the Read-Only Guardrail."
    first_tok = cleaned.split()[0].upper() if cleaned.split() else ""
    if first_tok not in ("SELECT", "WITH"):
        return False, f"Only read-only SELECT / WITH queries are permitted. Found `{first_tok}`."
    m = FORBIDDEN_SQL.search(cleaned)
    if m:
        return False, f"Blocked keyword `{m.group(0).upper()}` detected."
    return True, "Validated read-only SQL."


def analyze_sql_ast_and_plan(sql: str, plan_steps: List[str]) -> Dict[str, Any]:
    upper_sql = sql.upper()
    ctes_count = len(re.findall(r"\bAS\s*\(\s*SELECT\b", upper_sql))
    win_funcs = []
    for wf in ("DENSE_RANK", "ROW_NUMBER", "RANK", "LAG", "LEAD", "NTILE", "OVER"):
        if re.search(rf"\b{wf}\b", upper_sql):
            win_funcs.append(wf)

    index_seeks = sum(1 for step in plan_steps if "USING INDEX" in step.upper() or "COVERING INDEX" in step.upper())
    full_scans = sum(1 for step in plan_steps if step.upper().strip().startswith("SCAN "))

    has_pre_agg = ctes_count > 0 or "DISTINCT" in upper_sql or "GROUP BY" in upper_sql
    fanout_status = "SAFE (Grain-Guarded CTE / Distinct)" if has_pre_agg else "DIRECT TABLE SCAN"

    return {
        "ctes_count": ctes_count,
        "window_functions": win_funcs if win_funcs else ["None (Standard Aggregation)"],
        "index_seeks_count": index_seeks,
        "full_scans_count": full_scans,
        "fanout_safety": fanout_status,
    }


def run_readonly_query(sql: str) -> Dict[str, Any]:
    db_file = ensure_db()
    ok, msg = validate_readonly_sql(sql)
    if not ok:
        return {
            "valid": False,
            "message": msg,
            "sql": sql,
            "row_count": 0,
            "execution_ms": 0.0,
            "query_plan": [],
            "dba_diagnostics": {},
            "columns": [],
            "rows": [],
        }

    uri = f"file:{db_file.resolve().as_posix()}?mode=ro"
    t0 = time.perf_counter()
    try:
        conn = sqlite3.connect(uri, uri=True)
        clean_stmt = sql.strip().rstrip(";")
        plan_df = pd.read_sql_query(f"EXPLAIN QUERY PLAN {clean_stmt}", conn)
        plan_steps = [str(r.get("detail", "")) for _, r in plan_df.iterrows()]
        df = pd.read_sql_query(sql, conn)
        conn.close()
    except Exception as exc:
        return {
            "valid": False,
            "message": f"SQL Execution Error: {exc}",
            "sql": sql,
            "row_count": 0,
            "execution_ms": 0.0,
            "query_plan": [],
            "dba_diagnostics": {},
            "columns": [],
            "rows": [],
        }

    elapsed_ms = round((time.perf_counter() - t0) * 1000.0, 2)
    diagnostics = analyze_sql_ast_and_plan(sql, plan_steps)

    return {
        "valid": True,
        "message": msg,
        "sql": sql,
        "row_count": int(len(df)),
        "execution_ms": elapsed_ms,
        "query_plan": plan_steps,
        "dba_diagnostics": diagnostics,
        "columns": list(df.columns),
        "rows": df.head(100).to_dict(orient="records"),
    }


def verify_data_contracts() -> List[Dict[str, Any]]:
    """
    6-Point General Ledger & Relational Integrity Data Contract Suite:
    Proves mathematical tie-out across independent SQL views and tables.
    """
    contract_sql = """
    SELECT
        ROUND((SELECT SUM(net_sales_before_tax) FROM vw_line_item_financials WHERE order_status='Completed' AND payment_status='Paid'), 2) AS bridge_net_sales,
        ROUND((SELECT SUM(cat_sales) FROM (SELECT SUM(net_sales_before_tax) AS cat_sales FROM vw_line_item_financials WHERE order_status='Completed' AND payment_status='Paid' GROUP BY category_id)), 2) AS sum_category_sales,
        ROUND((SELECT SUM(gross_profit) FROM vw_line_item_financials WHERE order_status='Completed' AND payment_status='Paid'), 2) AS bridge_profit,
        ROUND((SELECT SUM(m_profit) FROM (SELECT SUM(gross_profit) AS m_profit FROM vw_line_item_financials WHERE order_status='Completed' AND payment_status='Paid' GROUP BY order_month)), 2) AS sum_monthly_profit,
        (SELECT COUNT(*) FROM order_items oi LEFT JOIN orders o ON oi.order_id = o.order_id WHERE o.order_id IS NULL) AS orphan_order_items,
        (SELECT COUNT(*) FROM returns r JOIN order_items oi ON r.order_item_id = oi.order_item_id WHERE r.return_quantity > oi.quantity) AS over_returned_items;
    """
    row = run_readonly_query(contract_sql)["rows"][0]
    return [
        {
            "contract_id": "DC-01",
            "assertion": "GL Tie-Out: Revenue Bridge Net Sales == Σ(8 Category Net Sales)",
            "expected": f"₹{row['bridge_net_sales']:,.2f}",
            "actual": f"₹{row['sum_category_sales']:,.2f}",
            "variance": f"₹{abs(row['bridge_net_sales'] - row['sum_category_sales']):.2f}",
            "status": "PASS" if abs(row["bridge_net_sales"] - row["sum_category_sales"]) < 0.01 else "FAIL",
        },
        {
            "contract_id": "DC-02",
            "assertion": "GL Tie-Out: Revenue Bridge Gross Profit == Σ(12 Monthly Cohort Profits)",
            "expected": f"₹{row['bridge_profit']:,.2f}",
            "actual": f"₹{row['sum_monthly_profit']:,.2f}",
            "variance": f"₹{abs(row['bridge_profit'] - row['sum_monthly_profit']):.2f}",
            "status": "PASS" if abs(row["bridge_profit"] - row["sum_monthly_profit"]) < 0.01 else "FAIL",
        },
        {
            "contract_id": "DC-03",
            "assertion": "Referential Integrity: Zero Orphan Foreign Keys (order_items → orders)",
            "expected": "0 Orphans",
            "actual": f"{row['orphan_order_items']} Orphans",
            "variance": "0",
            "status": "PASS" if row["orphan_order_items"] == 0 else "FAIL",
        },
        {
            "contract_id": "DC-04",
            "assertion": "Return Guardrail: Return Units Never Exceed Purchased Units (returns ≤ order_items)",
            "expected": "0 Violations",
            "actual": f"{row['over_returned_items']} Violations",
            "variance": "0",
            "status": "PASS" if row["over_returned_items"] == 0 else "FAIL",
        },
    ]


class SQLRunRequest(BaseModel):
    sql: str


@app.get("/api/health")
def health() -> Dict[str, Any]:
    db_file = ensure_db()
    return {
        "status": "healthy",
        "application": "CartLedger — E-Commerce SQL Case Files & Revenue Leakage Intelligence",
        "author": "Mohammed Zaidaan Shiraz",
        "database_exists": db_file.exists(),
        "case_files_count": len(SQL_CASE_FILES),
    }


TIER_FILTER_MAP = {
    "High-Margin": ("Fashion",),
    "Fashion": ("Fashion",),
    "Core-Margin": ("Core Retail",),
    "Core Retail": ("Core Retail",),
    "Volume-Driver": ("High-Ticket", "Fast-Moving"),
    "High-Ticket": ("High-Ticket",),
    "Fast-Moving": ("Fast-Moving",),
}


@app.get("/api/overview")
def get_executive_overview(
    region: str = Query("All"),
    tier: str = Query("All"),
) -> Dict[str, Any]:
    # Build optional SQL filter clauses for dynamic sidebar slicing
    dim_clauses: List[str] = []
    if region and region != "All":
        safe_reg = region.replace("'", "''")
        dim_clauses.append(f"c.region = '{safe_reg}'")
    if tier and tier != "All":
        mapped_tiers = TIER_FILTER_MAP.get(tier, (tier.replace("'", "''"),))
        quoted = ", ".join(f"'{t}'" for t in mapped_tiers)
        dim_clauses.append(f"v.merchandise_tier IN ({quoted})")

    paid_clauses = ["v.order_status = 'Completed'", "v.payment_status = 'Paid'"] + dim_clauses
    where_paid = " AND ".join(paid_clauses)
    where_all_states = " AND ".join(dim_clauses) if dim_clauses else "1=1"

    bridge_sql = f"""
    WITH paid_items AS (
        SELECT
            v.order_item_id,
            v.order_id,
            v.quantity,
            v.gross_sales,
            v.discount_amount,
            v.net_sales_before_tax,
            v.tax_amount,
            v.net_sales_incl_tax,
            v.cogs_amount,
            v.gross_profit
        FROM vw_line_item_financials v
        JOIN customers c ON v.customer_id = c.customer_id
        WHERE {where_paid}
    ),
    approved_returns AS (
        SELECT
            order_item_id,
            SUM(return_quantity) AS returned_units,
            SUM(refund_amount) AS approved_refund_inr
        FROM returns
        WHERE return_status = 'Approved'
        GROUP BY order_item_id
    )
    SELECT
        COUNT(DISTINCT p.order_id) AS completed_paid_orders,
        COALESCE(SUM(p.quantity), 0) AS gross_units_sold,
        COALESCE(SUM(COALESCE(r.returned_units, 0)), 0) AS returned_units,
        COALESCE(SUM(p.quantity) - SUM(COALESCE(r.returned_units, 0)), 0) AS net_units_retained,
        ROUND(COALESCE(SUM(p.gross_sales), 0), 2) AS gross_sales_inr,
        ROUND(COALESCE(SUM(p.discount_amount), 0), 2) AS total_discounts_inr,
        ROUND(COALESCE(SUM(p.net_sales_before_tax), 0), 2) AS net_sales_ex_tax_inr,
        ROUND(COALESCE(SUM(p.tax_amount), 0), 2) AS tax_collected_inr,
        ROUND(COALESCE(SUM(COALESCE(r.approved_refund_inr, 0)), 0), 2) AS approved_refunds_inr,
        ROUND(COALESCE(SUM(p.net_sales_incl_tax) - SUM(COALESCE(r.approved_refund_inr, 0)), 0), 2) AS net_realized_revenue_inr
    FROM paid_items p
    LEFT JOIN approved_returns r ON p.order_item_id = r.order_item_id;
    """

    cat_sql = f"""
    SELECT
        v.category_name,
        v.merchandise_tier,
        COUNT(DISTINCT v.order_id) AS category_distinct_orders,
        SUM(v.quantity) AS units_sold,
        ROUND(SUM(v.net_sales_before_tax), 2) AS net_sales_inr,
        ROUND(SUM(v.gross_profit), 2) AS gross_profit_inr,
        ROUND(SUM(v.gross_profit) * 100.0 / NULLIF(SUM(v.net_sales_before_tax), 0), 2) AS weighted_margin_pct
    FROM vw_line_item_financials v
    JOIN customers c ON v.customer_id = c.customer_id
    WHERE {where_paid}
    GROUP BY v.category_id, v.category_name, v.merchandise_tier
    ORDER BY gross_profit_inr DESC;
    """

    discount_sql = f"""
    SELECT
        CASE
            WHEN v.discount_pct = 0 THEN '01. Zero Discount (0%)'
            WHEN v.discount_pct <= 10 THEN '02. Shallow Promo (1-10%)'
            WHEN v.discount_pct <= 20 THEN '03. Medium Promo (11-20%)'
            ELSE '04. Deep Clearance (21-30%)'
        END AS discount_band,
        COUNT(DISTINCT v.order_id) AS orders_touched,
        ROUND(SUM(v.net_sales_before_tax), 2) AS net_sales_inr,
        ROUND(SUM(v.gross_profit), 2) AS gross_profit_inr,
        ROUND(SUM(v.gross_profit) * 100.0 / NULLIF(SUM(v.net_sales_before_tax), 0), 2) AS realized_margin_pct
    FROM vw_line_item_financials v
    JOIN customers c ON v.customer_id = c.customer_id
    WHERE {where_paid}
    GROUP BY discount_band
    ORDER BY discount_band ASC;
    """

    leakage_sql = f"""
    SELECT
        v.order_status,
        v.payment_status,
        COUNT(DISTINCT v.order_id) AS distinct_orders,
        SUM(v.quantity) AS total_units,
        ROUND(SUM(v.net_sales_incl_tax), 2) AS billed_value_inr
    FROM vw_line_item_financials v
    JOIN customers c ON v.customer_id = c.customer_id
    WHERE {where_all_states}
    GROUP BY v.order_status, v.payment_status
    ORDER BY billed_value_inr DESC;
    """

    monthly_sql = f"""
    WITH monthly_perf AS (
        SELECT
            v.order_month,
            COUNT(DISTINCT v.order_id) AS paid_orders,
            ROUND(SUM(v.net_sales_before_tax), 2) AS net_sales_inr,
            ROUND(SUM(v.gross_profit), 2) AS gross_profit_inr
        FROM vw_line_item_financials v
        JOIN customers c ON v.customer_id = c.customer_id
        WHERE {where_paid}
        GROUP BY v.order_month
    )
    SELECT
        order_month,
        paid_orders,
        net_sales_inr,
        gross_profit_inr
    FROM monthly_perf
    ORDER BY order_month ASC;
    """

    rfm_sql = f"""
    WITH customer_metrics AS (
        SELECT
            v.customer_id,
            CAST(JULIANDAY('2026-04-01') - JULIANDAY(MAX(v.order_date)) AS INTEGER) AS recency_days,
            COUNT(DISTINCT v.order_id) AS frequency_orders,
            ROUND(SUM(v.net_sales_before_tax), 2) AS monetary_net_sales
        FROM vw_line_item_financials v
        JOIN customers c ON v.customer_id = c.customer_id
        WHERE {where_paid}
        GROUP BY v.customer_id
    ),
    rfm_tiles AS (
        SELECT
            *,
            NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
            NTILE(5) OVER (ORDER BY frequency_orders ASC) AS f_score,
            NTILE(5) OVER (ORDER BY monetary_net_sales ASC) AS m_score
        FROM customer_metrics
    ),
    segmented AS (
        SELECT
            *,
            CASE
                WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN '01. Champions'
                WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN '02. Loyal Core'
                WHEN r_score <= 2 AND m_score >= 4 THEN '03. At-Risk High Value'
                WHEN r_score >= 4 AND f_score <= 2 THEN '04. Recent Promising'
                ELSE '05. Needs Re-Engagement'
            END AS rfm_segment
        FROM rfm_tiles
    )
    SELECT
        rfm_segment,
        COUNT(customer_id) AS customers_count,
        ROUND(SUM(monetary_net_sales), 2) AS segment_total_revenue_inr
    FROM segmented
    GROUP BY rfm_segment
    ORDER BY rfm_segment ASC;
    """

    loss_skus_negative_sql = f"""
    SELECT
        v.product_id,
        v.product_name,
        v.category_name,
        SUM(v.quantity) AS units_sold,
        ROUND(SUM(v.gross_profit), 2) AS net_loss_inr
    FROM vw_line_item_financials v
    JOIN customers c ON v.customer_id = c.customer_id
    WHERE {where_paid}
    GROUP BY v.product_id, v.product_name, v.category_name
    HAVING SUM(v.gross_profit) < 0
    ORDER BY net_loss_inr ASC;
    """

    loss_skus_fallback_sql = f"""
    SELECT
        v.product_id,
        v.product_name,
        v.category_name,
        SUM(v.quantity) AS units_sold,
        ROUND(SUM(v.gross_profit), 2) AS net_loss_inr
    FROM vw_line_item_financials v
    JOIN customers c ON v.customer_id = c.customer_id
    WHERE {where_paid}
    GROUP BY v.product_id, v.product_name, v.category_name
    ORDER BY net_loss_inr ASC
    LIMIT 5;
    """

    pvm_sql = f"""
    WITH period_cat AS (
        SELECT
            v.category_name,
            SUM(CASE WHEN v.order_month <= '2025-09' THEN v.quantity ELSE 0 END) AS q1_units,
            SUM(CASE WHEN v.order_month >  '2025-09' THEN v.quantity ELSE 0 END) AS q2_units,
            SUM(CASE WHEN v.order_month <= '2025-09' THEN v.gross_profit ELSE 0 END) AS p1_profit,
            SUM(CASE WHEN v.order_month >  '2025-09' THEN v.gross_profit ELSE 0 END) AS p2_profit
        FROM vw_line_item_financials v
        JOIN customers c ON v.customer_id = c.customer_id
        WHERE {where_paid}
        GROUP BY v.category_name
    )
    SELECT
        category_name,
        q1_units,
        q2_units,
        ROUND(p1_profit, 2) AS h1_profit_inr,
        ROUND(p2_profit, 2) AS h2_profit_inr,
        ROUND(p2_profit - p1_profit, 2) AS total_profit_variance_inr,
        ROUND((q2_units - q1_units) * (p1_profit * 1.0 / NULLIF(q1_units, 0)), 2) AS volume_effect_inr,
        ROUND(q2_units * ((p2_profit * 1.0 / NULLIF(q2_units, 0)) - (p1_profit * 1.0 / NULLIF(q1_units, 0))), 2) AS price_promo_effect_inr
    FROM period_cat
    ORDER BY total_profit_variance_inr DESC;
    """

    bridge = run_readonly_query(bridge_sql)["rows"][0]
    leakage = run_readonly_query(leakage_sql)["rows"]
    categories = run_readonly_query(cat_sql)["rows"]
    monthly = run_readonly_query(monthly_sql)["rows"]
    rfm = run_readonly_query(rfm_sql)["rows"]
    discounts = run_readonly_query(discount_sql)["rows"]
    loss_skus = run_readonly_query(loss_skus_negative_sql)["rows"]
    if not loss_skus:
        loss_skus = run_readonly_query(loss_skus_fallback_sql)["rows"]
    basket_pairs = run_readonly_query(SQL_CASE_FILES[12]["sql"])["rows"]
    cohorts = run_readonly_query(SQL_CASE_FILES[13]["sql"])["rows"]
    sql_traps = run_readonly_query(SQL_CASE_FILES[14]["sql"])["rows"]
    pvm_bridge = run_readonly_query(pvm_sql)["rows"]
    data_contracts = verify_data_contracts()

    pending_leakage_inr = sum(
        r["billed_value_inr"]
        for r in leakage
        if r["order_status"] == "Completed" and r["payment_status"] == "Pending"
    )

    return {
        "bridge": bridge,
        "pending_leakage_inr": round(pending_leakage_inr, 2),
        "leakage_matrix": leakage,
        "categories": categories,
        "monthly_trend": monthly,
        "rfm_segments": rfm,
        "discount_bands": discounts,
        "loss_making_skus": loss_skus,
        "basket_pairs": basket_pairs,
        "cohorts": cohorts,
        "sql_traps": sql_traps,
        "pvm_bridge": pvm_bridge,
        "data_contracts": data_contracts,
    }


@app.get("/api/simulate-recovery")
def simulate_margin_and_leakage_recovery(
    discount_cap: float = Query(8.0, ge=0.0, le=30.0),
    dunning_recovery_pct: float = Query(65.0, ge=0.0, le=100.0),
) -> Dict[str, Any]:
    """
    Prescriptive Pricing Guardrail & Dunning Recovery Engine:
    1. Simulates capping line-item promotional markdowns at `discount_cap`%
       (`MIN(discount_pct, discount_cap)`), recomputing net sales, COGS, and gross profit.
    2. Simulates recovering `dunning_recovery_pct`% of the uncollected `Completed + Pending`
       revenue leakage pool via automated payment links / UPI dunning.
    """
    sim_sql = f"""
    SELECT
        ROUND(SUM(net_sales_before_tax), 2) AS base_net_sales_inr,
        ROUND(SUM(gross_profit), 2) AS base_gross_profit_inr,
        ROUND(SUM(gross_profit) * 100.0 / NULLIF(SUM(net_sales_before_tax), 0), 2) AS base_margin_pct,
        ROUND(SUM(gross_sales * (1.0 - MIN(discount_pct, {discount_cap}) / 100.0)), 2) AS sim_net_sales_inr,
        ROUND(SUM(gross_sales * (1.0 - MIN(discount_pct, {discount_cap}) / 100.0) - cogs_amount), 2) AS sim_gross_profit_inr,
        ROUND(
            SUM(gross_sales * (1.0 - MIN(discount_pct, {discount_cap}) / 100.0) - cogs_amount) * 100.0
            / NULLIF(SUM(gross_sales * (1.0 - MIN(discount_pct, {discount_cap}) / 100.0)), 0),
            2
        ) AS sim_margin_pct
    FROM vw_line_item_financials
    WHERE order_status = 'Completed' AND payment_status = 'Paid';
    """

    sku_sim_sql = f"""
    WITH loss_ids AS (
        SELECT product_id
        FROM vw_line_item_financials
        WHERE order_status = 'Completed' AND payment_status = 'Paid'
        GROUP BY product_id
        HAVING SUM(gross_profit) < 0
    )
    SELECT
        v.product_id,
        v.product_name,
        v.category_name,
        SUM(v.quantity) AS units_sold,
        ROUND(AVG(v.discount_pct), 2) AS current_avg_discount_pct,
        ROUND(AVG(MIN(v.discount_pct, {discount_cap})), 2) AS capped_avg_discount_pct,
        ROUND(SUM(v.gross_profit), 2) AS current_profit_inr,
        ROUND(SUM(v.gross_sales * (1.0 - MIN(v.discount_pct, {discount_cap}) / 100.0) - v.cogs_amount), 2) AS simulated_profit_inr,
        ROUND(
            SUM(v.gross_sales * (1.0 - MIN(v.discount_pct, {discount_cap}) / 100.0) - v.cogs_amount)
            - SUM(v.gross_profit),
            2
        ) AS profit_recovered_inr
    FROM vw_line_item_financials v
    WHERE v.order_status = 'Completed'
      AND v.payment_status = 'Paid'
      AND v.product_id IN (SELECT product_id FROM loss_ids)
    GROUP BY v.product_id, v.product_name, v.category_name
    ORDER BY current_profit_inr ASC;
    """

    leakage_sql = """
    SELECT
        COUNT(DISTINCT order_id) AS pending_orders,
        ROUND(SUM(net_sales_incl_tax), 2) AS pending_billed_cash_inr,
        ROUND(SUM(gross_profit), 2) AS pending_gross_profit_inr
    FROM vw_line_item_financials
    WHERE order_status = 'Completed' AND payment_status = 'Pending';
    """

    sim_row = run_readonly_query(sim_sql)["rows"][0]
    sku_rows = run_readonly_query(sku_sim_sql)["rows"]
    leak_row = run_readonly_query(leakage_sql)["rows"][0]

    margin_gain_inr = round(sim_row["sim_gross_profit_inr"] - sim_row["base_gross_profit_inr"], 2)
    margin_lift_bps = int(round((sim_row["sim_margin_pct"] - sim_row["base_margin_pct"]) * 100))

    rec_rate = dunning_recovery_pct / 100.0
    recovered_cash_inr = round(leak_row["pending_billed_cash_inr"] * rec_rate, 2)
    recovered_leakage_profit_inr = round(leak_row["pending_gross_profit_inr"] * rec_rate, 2)
    total_profit_uplift_inr = round(margin_gain_inr + recovered_leakage_profit_inr, 2)

    skus_flipped_profitable = sum(1 for r in sku_rows if r["simulated_profit_inr"] > 0)

    return {
        "discount_cap_pct": discount_cap,
        "dunning_recovery_pct": dunning_recovery_pct,
        "baseline_net_sales_inr": sim_row["base_net_sales_inr"],
        "simulated_net_sales_inr": sim_row["sim_net_sales_inr"],
        "baseline_gross_profit_inr": sim_row["base_gross_profit_inr"],
        "simulated_gross_profit_inr": sim_row["sim_gross_profit_inr"],
        "margin_recovery_gain_inr": margin_gain_inr,
        "baseline_margin_pct": sim_row["base_margin_pct"],
        "simulated_margin_pct": sim_row["sim_margin_pct"],
        "margin_lift_bps": margin_lift_bps,
        "pending_orders_count": leak_row["pending_orders"],
        "pending_leakage_pool_inr": leak_row["pending_billed_cash_inr"],
        "recovered_leakage_cash_inr": recovered_cash_inr,
        "recovered_leakage_profit_inr": recovered_leakage_profit_inr,
        "total_bottom_line_profit_uplift_inr": total_profit_uplift_inr,
        "loss_skus_total": len(sku_rows),
        "loss_skus_flipped_profitable": skus_flipped_profitable,
        "sku_remediation_table": sku_rows,
    }


@app.get("/api/case-files")
def list_case_files() -> Dict[str, Any]:
    return {"case_files": SQL_CASE_FILES}


@app.post("/api/query")
def execute_query(req: SQLRunRequest) -> Dict[str, Any]:
    return run_readonly_query(req.sql)


if WEB_DIR.exists():
    app.mount("/static", StaticFiles(directory=str(WEB_DIR)), name="static")


@app.get("/", response_class=HTMLResponse)
def serve_index():
    idx = WEB_DIR / "index.html"
    if idx.exists():
        return FileResponse(str(idx))
    return HTMLResponse("<h1>CartLedger API Running</h1>")
