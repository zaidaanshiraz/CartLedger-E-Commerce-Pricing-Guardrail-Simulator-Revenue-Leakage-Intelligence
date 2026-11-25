"""
==============================================================================
CARTLEDGER — E-COMMERCE SQL CASE FILES & REVENUE LEAKAGE INTELLIGENCE
Database Builder & Deterministic Synthetic Data Seeder
==============================================================================
Author : Mohammed Zaidaan Shiraz
Target : Target India Retail & E-Commerce Business Intelligence Portfolio
==============================================================================
"""

from __future__ import annotations

import sqlite3
from pathlib import Path
import numpy as np
import pandas as pd

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
DB_PATH = DATA_DIR / "cartledger_ecommerce.db"


def build_database(db_path: Path = DB_PATH, seed: int = 42) -> dict:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    if db_path.exists():
        db_path.unlink()

    rng = np.random.default_rng(seed)

    # 1. CATEGORIES (8 categories)
    categories_data = [
        (1, "Electronics & Smart Tech", "High-Ticket"),
        (2, "Home & Kitchen Appliances", "Core Retail"),
        (3, "Apparel & Activewear", "Fashion"),
        (4, "Beauty & Personal Care", "Fast-Moving"),
        (5, "Grocery & Gourmet Essentials", "Fast-Moving"),
        (6, "Sports & Fitness Gear", "Core Retail"),
        (7, "Footwear & Accessories", "Fashion"),
        (8, "Smart Home & Decor", "High-Ticket"),
    ]
    df_categories = pd.DataFrame(
        categories_data, columns=["category_id", "category_name", "merchandise_tier"]
    )

    # 2. PRODUCTS (80 products across 8 categories, including 5 intentionally loss-making / over-discounted SKUs)
    brands = [
        "ApexPulse", "NovaCore", "UrbanCrest", "Veloce", "LuminaHome",
        "Pure Botanics", "TitanFit", "Zenith", "StrataWear", "Aura Luxe"
    ]
    products_rows = []
    for pid in range(1, 81):
        cat_id = ((pid - 1) % 8) + 1
        brand = brands[pid % len(brands)] if pid % 19 != 0 else None  # 4 NULL brands for data-profiling tests
        base_price = float(rng.integers(300, 4500))
        # Make 5 specific products have high cost ratio so heavy discounts push them into negative gross profit
        if pid in (7, 19, 31, 47, 63):
            cost_ratio = rng.uniform(0.84, 0.92)
        else:
            cost_ratio = rng.uniform(0.48, 0.72)
        cost_price = round(base_price * cost_ratio, 2)
        products_rows.append(
            (
                pid,
                f"SKU-{pid:03d} {df_categories.loc[cat_id - 1, 'category_name'].split()[0]} Item",
                cat_id,
                brand,
                base_price,
                cost_price,
            )
        )
    df_products = pd.DataFrame(
        products_rows,
        columns=["product_id", "product_name", "category_id", "brand", "list_price", "cost_price"],
    )

    # 3. CUSTOMERS (600 customers across 12 Indian cities & states)
    geo_hubs = [
        ("Bengaluru", "Karnataka", "South"),
        ("Mumbai", "Maharashtra", "West"),
        ("Delhi NCR", "Delhi", "North"),
        ("Hyderabad", "Telangana", "South"),
        ("Chennai", "Tamil Nadu", "South"),
        ("Pune", "Maharashtra", "West"),
        ("Kolkata", "West Bengal", "East"),
        ("Ahmedabad", "Gujarat", "West"),
        ("Jaipur", "Rajasthan", "North"),
        ("Kochi", "Kerala", "South"),
        ("Indore", "Madhya Pradesh", "Central"),
        ("Lucknow", "Uttar Pradesh", "North"),
    ]
    start_signup = pd.Timestamp("2025-01-01")
    customers_rows = []
    for cid in range(1, 601):
        city, state, region = geo_hubs[cid % len(geo_hubs)]
        signup_offset = int(rng.integers(0, 270))
        signup_dt = (start_signup + pd.Timedelta(days=signup_offset)).strftime("%Y-%m-%d")
        status = "Active" if cid % 25 != 0 else ("Churned" if cid % 50 != 0 else None)
        customers_rows.append(
            (
                cid,
                f"Customer_{cid:04d}",
                city,
                state,
                region,
                status,
                signup_dt,
            )
        )
    df_customers = pd.DataFrame(
        customers_rows,
        columns=["customer_id", "customer_name", "city", "state", "region", "customer_status", "signup_date"],
    )

    # 4. ORDERS (3,000 orders across 12 months: 2025-04-01 to 2026-03-31)
    # States:
    # - Completed + Paid (~82%) -> Recognized Revenue
    # - Completed + Pending (~6%) -> Revenue Leakage (Delivered before payment settled!)
    # - Cancelled + Failed (~8%) -> Payment Gateway Drop-off
    # - Cancelled + Refunded (~4%) -> Pre-dispatch cancellation
    orders_rows = []
    payments_rows = []
    order_start = pd.Timestamp("2025-04-01")
    payment_methods = ["UPI", "Credit Card", "Debit Card", "NetBanking", "COD"]

    for oid in range(1, 3001):
        cid = int(rng.choice(range(1, 560)))  # Leave ~40 customers with 0 orders for LEFT JOIN Case File!
        day_offset = int(rng.integers(0, 365))
        order_dt = (order_start + pd.Timedelta(days=day_offset)).strftime("%Y-%m-%d")

        r = rng.random()
        if r < 0.82:
            o_status, p_status = "Completed", "Paid"
        elif r < 0.88:
            o_status, p_status = "Completed", "Pending"
        elif r < 0.96:
            o_status, p_status = "Cancelled", "Failed"
        else:
            o_status, p_status = "Cancelled", "Refunded"

        orders_rows.append((oid, cid, order_dt, o_status, p_status))
        payments_rows.append(
            (
                oid,
                oid,
                payment_methods[oid % len(payment_methods)],
                p_status,
                order_dt,
            )
        )

    df_orders = pd.DataFrame(
        orders_rows, columns=["order_id", "customer_id", "order_date", "order_status", "payment_status"]
    )
    df_payments = pd.DataFrame(
        payments_rows, columns=["payment_id", "order_id", "payment_method", "payment_status", "payment_date"]
    )

    # 5. ORDER ITEMS (6,400 line items — multi-item baskets to demonstrate fan-out vs distinct order grain)
    order_items_rows = []
    returns_rows = []
    reviews_rows = []
    oi_id = 1
    ret_id = 1
    rev_id = 1

    prod_lookup = df_products.set_index("product_id").to_dict(orient="index")
    order_lookup = df_orders.set_index("order_id").to_dict(orient="index")

    # Symmetric complementary category pairs for realistic Market Basket Affinity (Lift > 1.4x)
    affinity_partner_cat = {1: 8, 8: 1, 3: 7, 7: 3, 4: 5, 5: 4, 2: 6, 6: 2}
    cat_to_pids = {
        cat_id: [pid for pid in range(1, 81) if ((pid - 1) % 8) + 1 == cat_id]
        for cat_id in range(1, 9)
    }

    for oid in range(1, 3001):
        n_items = int(rng.choice([1, 2, 3, 4], p=[0.35, 0.40, 0.18, 0.07]))
        first_pid = int(rng.integers(1, 81))
        chosen_pids = [first_pid]
        if n_items > 1:
            first_cat = ((first_pid - 1) % 8) + 1
            partner_cat = affinity_partner_cat[first_cat]
            if rng.random() < 0.65:
                partner_pid = int(rng.choice(cat_to_pids[partner_cat]))
                chosen_pids.append(partner_pid)
            remaining_needed = n_items - len(chosen_pids)
            if remaining_needed > 0:
                pool = [p for p in range(1, 81) if p not in chosen_pids]
                extra_pids = rng.choice(pool, size=remaining_needed, replace=False)
                chosen_pids.extend(int(x) for x in extra_pids)
        o_meta = order_lookup[oid]

        for pid in chosen_pids:
            pid = int(pid)
            p_meta = prod_lookup[pid]
            qty = int(rng.choice([1, 2, 3], p=[0.65, 0.25, 0.10]))
            unit_price = float(p_meta["list_price"])

            # High discount on loss-making SKUs to create negative margin case file
            if pid in (7, 19, 31, 47, 63):
                disc_pct = float(rng.choice([20.0, 25.0, 30.0]))
            else:
                disc_pct = float(rng.choice([0.0, 5.0, 10.0, 15.0, 25.0], p=[0.35, 0.25, 0.20, 0.12, 0.08]))

            net_line = qty * unit_price * (1.0 - disc_pct / 100.0)
            tax_amt = round(net_line * 0.12, 2)

            order_items_rows.append(
                (oi_id, oid, pid, qty, unit_price, disc_pct, tax_amt)
            )

            # Generate returns on ~9% of Completed + Paid items
            if o_meta["order_status"] == "Completed" and o_meta["payment_status"] == "Paid":
                if rng.random() < 0.095:
                    ret_qty = 1 if qty == 1 else int(rng.integers(1, qty + 1))
                    refund_amt = round((net_line + tax_amt) * (ret_qty / qty), 2)
                    ret_status = "Approved" if rng.random() < 0.85 else "Rejected"
                    returns_rows.append(
                        (
                            ret_id,
                            oi_id,
                            ret_qty,
                            refund_amt,
                            ret_status,
                            rng.choice(["Defective Item", "Size/Fit Issue", "Arrived Late", "Changed Mind"]),
                        )
                    )
                    ret_id += 1

                if rng.random() < 0.35:
                    rating = int(rng.choice([1, 2, 3, 4, 5], p=[0.06, 0.09, 0.18, 0.37, 0.30]))
                    reviews_rows.append((rev_id, oid, pid, o_meta["customer_id"], rating))
                    rev_id += 1

            oi_id += 1

    df_order_items = pd.DataFrame(
        order_items_rows,
        columns=["order_item_id", "order_id", "product_id", "quantity", "unit_price", "discount_pct", "tax_amount"],
    )
    df_returns = pd.DataFrame(
        returns_rows,
        columns=["return_id", "order_item_id", "return_quantity", "refund_amount", "return_status", "return_reason"],
    )
    df_reviews = pd.DataFrame(
        reviews_rows,
        columns=["review_id", "order_id", "product_id", "customer_id", "rating"],
    )

    # Save to SQLite with relational constraints and analytical views
    conn = sqlite3.connect(str(db_path))
    df_categories.to_sql("categories", conn, index=False, if_exists="replace")
    df_products.to_sql("products", conn, index=False, if_exists="replace")
    df_customers.to_sql("customers", conn, index=False, if_exists="replace")
    df_orders.to_sql("orders", conn, index=False, if_exists="replace")
    df_order_items.to_sql("order_items", conn, index=False, if_exists="replace")
    df_payments.to_sql("payments", conn, index=False, if_exists="replace")
    df_returns.to_sql("returns", conn, index=False, if_exists="replace")
    df_reviews.to_sql("reviews", conn, index=False, if_exists="replace")

    # Create composite B-Tree indexes and analytical views using standard SQLite/ANSI SQL
    conn.executescript(
        """
        CREATE INDEX IF NOT EXISTS idx_orders_status_payment ON orders(order_status, payment_status, order_id);
        CREATE INDEX IF NOT EXISTS idx_orders_customer_date ON orders(customer_id, order_date);
        CREATE INDEX IF NOT EXISTS idx_oi_order_product ON order_items(order_id, product_id, order_item_id);
        CREATE INDEX IF NOT EXISTS idx_returns_item_status ON returns(return_status, order_item_id);
        CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id, product_id);
        CREATE INDEX IF NOT EXISTS idx_customers_region ON customers(region, state, customer_id);

        CREATE VIEW vw_line_item_financials AS
        SELECT
            oi.order_item_id,
            o.order_id,
            o.customer_id,
            o.order_date,
            SUBSTR(o.order_date, 1, 7) AS order_month,
            o.order_status,
            o.payment_status,
            p.product_id,
            p.product_name,
            p.brand,
            c.category_id,
            c.category_name,
            c.merchandise_tier,
            oi.quantity,
            oi.unit_price,
            oi.discount_pct,
            p.cost_price,
            ROUND(oi.quantity * oi.unit_price, 2) AS gross_sales,
            ROUND(oi.quantity * oi.unit_price * (oi.discount_pct / 100.0), 2) AS discount_amount,
            ROUND(oi.quantity * oi.unit_price * (1.0 - oi.discount_pct / 100.0), 2) AS net_sales_before_tax,
            ROUND(oi.tax_amount, 2) AS tax_amount,
            ROUND(oi.quantity * oi.unit_price * (1.0 - oi.discount_pct / 100.0) + oi.tax_amount, 2) AS net_sales_incl_tax,
            ROUND(oi.quantity * p.cost_price, 2) AS cogs_amount,
            ROUND(oi.quantity * oi.unit_price * (1.0 - oi.discount_pct / 100.0) - (oi.quantity * p.cost_price), 2) AS gross_profit
        FROM order_items oi
        JOIN orders o ON o.order_id = oi.order_id
        JOIN products p ON p.product_id = oi.product_id
        JOIN categories c ON c.category_id = p.category_id;
        """
    )
    conn.commit()
    conn.close()

    return {
        "categories": len(df_categories),
        "products": len(df_products),
        "customers": len(df_customers),
        "orders": len(df_orders),
        "order_items": len(df_order_items),
        "payments": len(df_payments),
        "returns": len(df_returns),
        "reviews": len(df_reviews),
    }


if __name__ == "__main__":
    counts = build_database()
    print("CartLedger SQLite database initialized:", counts)

