"""Fixes from the independent Codex review (reset race, ETA overflow, body size, failed-auth throttle)."""
from conftest import plan, sellers
from test_api import api_client, headers  # noqa: F401  (fixture + helper reused)


def test_reset_only_deletes_orders_it_terminated(isolated_db):
    isolated_db.reserve_order("a", "inst")
    marked = isolated_db.mark_deleting("inst")          # reset snapshots order a ...
    isolated_db.reserve_order("b", "inst")              # ... a new order arrives while it runs
    isolated_db.delete_orders("inst", ids=[o["order_id"] for o in marked])
    assert [o["order_id"] for o in isolated_db.list_orders("inst")] == ["b"]


def test_absurd_eta_is_rejected(api_client):
    meta = sellers()
    meta[0]["etaMinutes"] = 10 ** 12
    r = api_client.client.post("/order", headers=headers(api_client), json={"plan": plan(), "sellers": meta})
    assert r.status_code == 422


def test_oversized_body_is_rejected_before_auth(api_client):
    r = api_client.client.post("/order", content=b"x" * 1_100_000, headers={"Content-Type": "application/json"})
    assert r.status_code == 413


def test_failed_auth_attempts_are_throttled(api_client):
    codes = [api_client.client.post("/order", headers={"X-Install-Key": "wrong"}, json={}).status_code for _ in range(61)]
    assert codes[:60] == [401] * 60 and codes[60] == 429
