# CartLedger — E-Commerce SQL Case Files, Pricing Guardrail Simulator & Revenue Leakage Intelligence

> **Portfolio Project:** Enterprise Retail SQL Case Files, Prescriptive Pricing Simulator, Market Basket Affinity & Margin Leakage Analytics  
> **Author:** **Mohammed Zaidaan Shiraz**  
> **Target Alignment:** Target India Retail & E-Commerce Business Intelligence / Merchandising & SQL Analytics  
> **Tech Stack:** SQL (8-Table Relational Schema, CTEs, Self-Joins, Window Functions `DENSE_RANK`, `LAG`, `NTILE(5)`, Running Totals), Python 3.12 (FastAPI, Pandas, SQLite), Modern Reactive Web SPA (Charcoal Slate & Warm Sand Enterprise BI Theme), Power BI (`powerbi/Ecom.pbix`), Pytest  
> **Dataset Classification:** **Synthetic Multi-Category Retail & E-Commerce Ledger** (`600` Customers, `8` Categories, `80` SKUs, `3,000` Orders, `5,813` Order Line Items, `3,000` Payments, `431` Returns, `1,715` Reviews)

[![Frontend](https://img.shields.io/badge/Frontend-FastAPI%20%2B%20Enterprise%20BI%20Studio-2C3137?logo=fastapi)](./app/api_server.py)
[![SQL Case Files](https://img.shields.io/badge/SQL-16%20Live%20Case%20Files%20%2B%20EXPLAIN%20PLAN-2B6E46?logo=sqlite)](./app/api_server.py)
[![Tests: 23 Passed](https://img.shields.io/badge/Tests-23%20Passed%20(100%25)-brightgreen?logo=pytest)](./tests/test_cartledger.py)
[![Power BI](https://img.shields.io/badge/Power%20BI-Retail%20Model-F59E0B?logo=powerbi)](./powerbi/)

---

## Resume-Ready Technical Overview & Impact Metrics

### Copy-Paste Resume Entry (Action $\rightarrow$ Technical Method $\rightarrow$ Quantified Business Impact)
> **CartLedger — E-Commerce SQL Case Files, Pricing Simulator & Revenue Leakage Intelligence** | *SQL (SQLite, T-SQL, CTEs, Window Functions, Self-Joins, EXPLAIN QUERY PLAN), Python (FastAPI, Pandas), Reactive JS (Plotly.js), Power BI, Pytest*
> - **8-Table Relational Schema, B-Tree Indexing & Zero-Fan-Out Revenue Bridge:** Engineered a reproducible 8-table e-commerce database (**3,000 orders, 5,813 line items, ₹17.15M gross sales**) with composite B-Tree indexes and multi-stage pre-aggregated CTE pipelines that eliminate 1-to-many return join fan-out and **79.36%** multi-category order-count inflation (**4,475** summed category orders vs **2,495** unique paid orders), reconciling **₹15.74M** net ex-tax sales, **₹1.11M** approved refunds, and **₹16.53M** net realized cash.
> - **CFO Price-Volume-Mix (PVM) Attribution, Market Basket Affinity & SQL Forensics:** Authored **16 executable SQL Case Files** (`DENSE_RANK`, `LAG`, `NTILE(5)` RFM, pairwise self-join Market Basket Lift, `MIN(order_month)` cohort retention, and H1-vs-H2 Price-Volume-Mix decomposition) that uncovered **₹1.37M** (`183` orders) in uncollected `Completed + Pending` revenue leakage and **5 margin-destroying SKUs** (`-₹124.8K` combined loss) triggered by 20–30% promotional discounting.
> - **Prescriptive Pricing Simulator, Live `EXPLAIN QUERY PLAN` Profiler & GL Data Contracts:** Built an interactive FastAPI + SQLite simulation engine and DBA Query Plan Inspector (`EXPLAIN QUERY PLAN` + sub-millisecond latency telemetry + 4 automated General Ledger tie-out contracts) proving that an **8% promotional discount cap** paired with **65% pending-payment dunning recovery** flips **all 5/5 loss-making SKUs to profitable**, lifts network gross margin by **+243 bps (32.39% $\rightarrow$ 34.82%)**, and generates **+₹848.5K (+16.64%)** in bottom-line gross profit uplift (**23/23 Pytest tests passing**).

### Key Financial & Operational Metrics (For Live Interview Defense)
| Metric / Audit Dimension | Verified Value | SQL / Business Logic Applied |
| :--- | :--- | :--- |
| **Gross Merchandise Sales (Paid Cohort)** | **₹17,146,852** (`2,495` distinct orders, `7,001` units) | Filtered to `order_status = 'Completed' AND payment_status = 'Paid'` |
| **Promotional Discount Spend** | **₹1,401,921** (`8.18%` effective markdown rate) | `SUM(quantity * unit_price * discount_pct / 100.0)` |
| **Net Merchandise Sales (Ex-Tax)** | **₹15,744,931** (`₹5,099,765` Gross Profit · `32.39%` Margin) | `Gross Sales - Promotional Discounts` |
| **Approved Customer Refunds** | **₹1,108,880** (`442` approved returned units) | Pre-aggregated in `approved_returns` CTE by `order_item_id` before `LEFT JOIN` |
| **Net Realized Cash Revenue** | **₹16,525,443** | `Net Sales Incl. Tax (₹17,634,323) - Approved Refunds (₹1,108,880)` |
| **Uncollected Revenue Leakage** | **₹1,372,054** (`183` distinct orders) | Fulfilled (`Completed`) orders where `payment_status = 'Pending'` |
| **Margin-Destroying SKUs Flagged** | **5 SKUs** (`SKU-007, 019, 031, 047, 063` · `-₹124,820` loss) | Isolated via `GROUP BY product_id HAVING SUM(gross_profit) < 0` |
| **Prescriptive Simulator P&L Uplift** | **+₹848,521 Net Profit Lift** (`+243 bps` margin expansion) | `8%` Promo Cap (`+₹586,738` profit) + `65%` Dunning Recovery (`+₹261,783` profit) |

---

## What Makes CartLedger Stand Out From Generic E-Commerce Projects

1. **Live Prescriptive Pricing Guardrail & Dunning Simulator (`/api/simulate-recovery`):**
   - Instead of stopping at descriptive charts, CartLedger lets interviewers drag two live sliders: **Max Promotional Discount Cap (`0%–30%`)** and **Pending Payment Dunning Recovery (`0%–100%`)**.
   - Every slider change runs a real-time read-only SQLite simulation showing how capping discounts at `8%` flips all **5 loss-making SKUs from `-₹124.8K` loss to `+₹61.5K` profit**, expands network margin by **`+243 bps`**, and combines with dunning recovery to add **`+₹848.5K`** to bottom-line profit.
2. **Cross-Category Market Basket Affinity Engine (`CF-13`):**
   - Uses an inequality self-join (`a.order_id = b.order_id AND a.category_id < b.category_id`) on `vw_line_item_financials` to compute pairwise **Support %**, **Confidence %**, and **Association Lift Ratio**, identifying which categories drive multi-item basket expansion.
3. **First-Purchase Cohort Retention & LTV Matrix (`CF-14`):**
   - Assigns each customer to their acquisition month (`MIN(order_month)`) and tracks repeat buyer conversion rate, average orders per buyer, and cumulative cohort LTV.
4. **Forensic SQL Anti-Pattern vs. Production Fix Comparator (`CF-15`):**
   - A live SQL benchmark query that proves side-by-side why naive retail SQL fails:
     - **Order Grain Trap:** Summing category distinct orders yields **`4,475`**, whereas true network distinct paid orders is **`2,495`** (**`+79.36%` overcount error**).
     - **Margin Aggregation Trap:** Unweighted `AVG(sku_margin_pct)` (`31.96%`) vs true weighted `SUM(gross_profit)/SUM(net_sales)` (`32.39%`).
     - **Settlement Filter Trap:** Counting all `Completed` orders (`₹19.01M`) vs `Completed + Paid` (`₹17.63M` — **`+7.78%` uncollected inflation**).

---

## The 16 Live SQL Case Files

| Case ID | Level | Title | Core SQL Techniques Demonstrated |
| :--- | :--- | :--- | :--- |
| **CF-01** | Level 1 | Schema Row Counts, PK Uniqueness & Null Profiling | `UNION ALL`, `COUNT(*)`, Conditional `CASE` Null Checks |
| **CF-02** | Level 1 | Order Status × Payment Status Revenue Leakage Matrix | `GROUP BY`, Window Share `SUM(COUNT(*)) OVER ()` |
| **CF-03** | Level 2 | Gross-to-Net Realized Revenue Waterfall (Zero Fan-Out) | Multi-Stage CTEs, Pre-Aggregated `LEFT JOIN`, `COALESCE` |
| **CF-04** | Level 2 | Category Profitability & Distinct Order Grain Proof | `COUNT(DISTINCT)`, Weighted Margin Formula, `CROSS JOIN` |
| **CF-05** | Level 2 | Dormant Signed-Up Customers Audit | `LEFT JOIN ... WHERE order_id IS NULL` |
| **CF-06** | Level 2 | Margin-Destroying SKUs Triggered by Over-Discounting | `GROUP BY`, `HAVING SUM(gross_profit) < 0` |
| **CF-07** | Level 3 | Top 3 Profit-Generating SKUs Inside Each Category | `DENSE_RANK() OVER (PARTITION BY category ORDER BY profit DESC)` |
| **CF-08** | Level 3 | Monthly Revenue, MoM Growth (%) & Running Total Profit | `LAG() OVER`, `SUM() OVER (ROWS UNBOUNDED PRECEDING)` |
| **CF-09** | Level 3 | Customer RFM Quintile Segmentation | `NTILE(5) OVER`, `JULIANDAY` Recency, Lifecycle Tiering |
| **CF-10** | Level 3 | Promotional Discount Band Elasticity vs Margin | Bucketed `CASE`, Promo Spend vs Realized Margin % |
| **CF-11** | Level 3 | Approved Return Rate & Refund Drag by Category | Pre-Aggregated Return CTE, Unit Return Rate %, Refund Drag % |
| **CF-12** | Level 3 | Geographic Revenue, True AOV & Profit Share Leaderboard | Multi-Table Join, `SUM(net_sales)/COUNT(DISTINCT order_id)` |
| **CF-13** | Level 4 | Cross-Category Market Basket Co-Purchase & Lift | Self-Join (`a.category_id < b.category_id`), Support, Confidence, Lift |
| **CF-14** | Level 4 | First-Purchase Cohort Retention & Repeat LTV Matrix | `MIN(order_month)` Cohort CTE, Repeat Rate %, Customer LTV |
| **CF-15** | Level 4 | Forensic SQL Anti-Pattern vs Production Fix Comparator | Multi-CTE Diagnostic Benchmark, `UNION ALL` Variance Proof |
| **CF-16** | Level 4 | CFO Price-Volume-Mix (PVM) Profit Decomposition Bridge | Period-over-Period Volume Effect vs Price/Promo Realization Effect |

---

## Quickstart

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Seed the 8-table SQLite database (data/cartledger_ecommerce.db)
python scripts/build_ecommerce_db.py

# 3. Run the 23 automated SQL, Simulator & API verification tests
pytest tests/ -v

# 4. Launch the CartLedger Interactive Web Application
uvicorn app.api_server:app --reload --port 8001
# Open http://127.0.0.1:8001 in your browser
```

---

## Disclaimer & Author
This repository uses a **synthetically generated multi-category retail ledger** engineered for analytical, SQL, and prescriptive pricing demonstration.

**Mohammed Zaidaan Shiraz**  
*B.E. CSE (Data Science) | SQL, Business Intelligence & Full-Stack Analytics Engineering*
