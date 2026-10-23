from conftest import plan, sellers
from test_api import api_client, create  # noqa: F401  (fixture + helper reused)


def test_judge_orders_requires_admin_key(api_client):
    assert api_client.client.get("/judge/orders").status_code == 401
    assert api_client.client.get("/judge/orders", headers={"X-Install-Key": api_client.key}).status_code == 401


def test_judge_orders_lists_newest_with_sellers(api_client):
    oid = create(api_client).json()["orderID"]
    rows = api_client.client.get("/judge/orders", headers={"X-Admin-Key": "judge-secret"}).json()
    assert [r["orderID"] for r in rows] == [oid]
    assert rows[0]["state"] == "placed" and rows[0]["planVersion"] == 1
    assert rows[0]["sellers"] == [{"id": "s1", "status": "placed"}]
