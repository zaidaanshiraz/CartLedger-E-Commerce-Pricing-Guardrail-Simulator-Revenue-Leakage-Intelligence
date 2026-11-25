"""
==============================================================================
CARTLEDGER — AUTOMATED SQL CASE FILES & API VERIFICATION SUITE
Author : Mohammed Zaidaan Shiraz
==============================================================================
"""

import sys
from pathlib import Path
import pytest
from fastapi.testclient import TestClient

BASE_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE_DIR / "app"))
sys.path.insert(0, str(BASE_DIR / "scripts"))

from api_server import app, SQL_CASE_FILES, run_readonly_query, validate_readonly_sql


@pytest.fixture(scope="module")
def client():
    return TestClient(app)


def test_health_and_author_identity(client):
    r = client.get("/api/health")
    assert r.status_code == 200
    body = r.json()
    assert body["author"] == "Mohammed Zaidaan Shiraz"
    assert body["case_files_count"] == 16
    assert body["database_exists"] is True


@pytest.mark.parametrize("cf", SQL_CASE_FILES, ids=[c["id"] for c in SQL_CASE_FILES])
def test_all_16_sql_case_files_execute_with_explain_plan(cf):
    res = run_readonly_query(cf["sql"])
    assert res["valid"] is True, f"{cf['id']} failed: {res['message']}"
    assert res["row_count"] > 0, f"{cf['id']} returned 0 rows"
    assert isinstance(res["query_plan"], list) and len(res["query_plan"]) > 0
    assert "index_seeks_count" in res["dba_diagnostics"]


def test_data_contracts_all_pass(client):
    r = client.get("/api/overview")
    assert r.status_code == 200
    contracts = r.json()["data_contracts"]
    assert len(contracts) == 4
    for c in contracts:
        assert c["status"] == "PASS", f"Contract {c['contract_id']} failed: {c}"


def test_category_distinct_order_grain_trap_proof():
    """Verify that summing category distinct orders exceeds global unique paid orders (multi-category baskets)."""
    res = run_readonly_query(SQL_CASE_FILES[3]["sql"])
    rows = res["rows"]
    sum_of_category_orders = sum(r["category_distinct_orders"] for r in rows)
    true_network_orders = rows[0]["network_unique_orders"]
    assert sum_of_category_orders > true_network_orders


def test_loss_making_skus_identified():
    """Verify CF-06 HAVING SUM(gross_profit) < 0 isolates the 5 over-discounted loss-making SKUs."""
    res = run_readonly_query(SQL_CASE_FILES[5]["sql"])
    assert res["row_count"] == 5
    for r in res["rows"]:
        assert r["net_loss_inr"] < 0


def test_pricing_guardrail_and_dunning_simulator_endpoint(client):
    """Verify /api/simulate-recovery computes positive margin lift and flips loss-making SKUs."""
    r = client.get("/api/simulate-recovery?discount_cap=8&dunning_recovery_pct=65")
    assert r.status_code == 200
    data = r.json()
    assert data["margin_recovery_gain_inr"] > 0
    assert data["recovered_leakage_cash_inr"] > 0
    assert data["total_bottom_line_profit_uplift_inr"] > 0
    assert data["loss_skus_total"] == 5
    assert data["loss_skus_flipped_profitable"] >= 4
    assert len(data["sku_remediation_table"]) == 5


def test_overview_regional_and_tier_slicers(client):
    """Verify /api/overview supports dynamic region and all 3 merchandise tier slicers with non-zero results."""
    r_all = client.get("/api/overview")
    assert r_all.status_code == 200
    all_orders = r_all.json()["bridge"]["completed_paid_orders"]

    for tier_name in ["High-Margin", "Core-Margin", "Volume-Driver"]:
        r_tier = client.get(f"/api/overview?region=All&tier={tier_name}")
        assert r_tier.status_code == 200
        body = r_tier.json()
        assert 0 < body["bridge"]["completed_paid_orders"] < all_orders, f"Tier {tier_name} returned 0 or invalid orders"
        assert body["bridge"]["net_sales_ex_tax_inr"] > 0
        assert len(body["categories"]) > 0
        assert len(body["discount_bands"]) > 0
        assert len(body["loss_making_skus"]) > 0

    r_sub = client.get("/api/overview?region=South&tier=High-Margin")
    assert r_sub.status_code == 200
    assert 0 < r_sub.json()["bridge"]["completed_paid_orders"] < all_orders


def test_readonly_guardrail_blocks_mutations(client):
    for bad in ["DROP TABLE orders;", "DELETE FROM customers;", "UPDATE products SET list_price = 0;"]:
        ok, _ = validate_readonly_sql(bad)
        assert ok is False
        resp = client.post("/api/query", json={"sql": bad})
        assert resp.json()["valid"] is False
