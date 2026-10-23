"""R8/11: an owned order does not entitle its owner to rate unrelated sellers."""
import db
import v2_db
from test_true_price import client  # noqa: F401


def test_unrelated_seller_never_affects_published_prices(client):
    for n in range(3):
        oid = f"owned-{n}"
        db.reserve_order(oid, "phone-1")
        db.place_order(oid, "actual-seller", 1)
        response = client.post(f"/orders/{oid}/paid", json={
            "sellerID": "unrelated", "pincode": "560001", "paidPaise": 11000, "itemsPaise": 10000})
        assert response.status_code == 422
    assert v2_db.extras("unrelated", "560001") == []


def test_reserved_order_without_a_placement_cannot_report(client):
    db.reserve_order("reserved-only", "phone-1")
    response = client.post("/orders/reserved-only/paid", json={
        "sellerID": "s1", "pincode": "560001", "paidPaise": 11000})
    assert response.status_code == 422
