import pytest
from fastapi import FastAPI, Header
from fastapi.testclient import TestClient

import db
import true_price
import v2_db


def install_dep() -> str:  # overridden below
    raise AssertionError("must be overridden")


@pytest.fixture
def client(isolated_db):
    app = FastAPI()
    true_price.register(app, lambda: None, install_dep)
    app.dependency_overrides[install_dep] = lambda x_test_install=Header(default="phone-1"): x_test_install
    return TestClient(app)


def paid(client, order, seller="s1", pincode="560001", paid=11000, items=10000, who="phone-1", **extra):
    # K30: a report needs a real order. Create it (as a sandbox order is created) unless it already exists.
    if db.get_order(order) is None:
        db.reserve_order(order, who)
    body = {"sellerID": seller, "pincode": pincode, "paidPaise": paid, **extra}
    if items is not None:
        body["itemsPaise"] = items
    return client.post(f"/orders/{order}/paid", json=body, headers={"X-Test-Install": who})


def price(client, seller="s1", pincode="560001"):
    return client.get("/true_price", params={"seller": seller, "pincode": pincode}).json()


def test_median_int():
    assert v2_db.median_int([5]) == 5
    assert v2_db.median_int([9, 1, 5]) == 5
    assert v2_db.median_int([1, 2, 3, 100]) == 2
    assert v2_db.median_int([-30, 10]) == -10


def test_not_enough_until_three_reports(client):
    assert price(client) == {"sellerID": "s1", "pincode": "560001", "reports": 0,
                             "enough": False, "medianExtraPaise": None}
    paid(client, "o1", paid=10500)
    paid(client, "o2", paid=10700)
    body = price(client)
    assert (body["reports"], body["enough"], body["medianExtraPaise"]) == (2, False, None)
    assert paid(client, "o3", paid=13000).status_code == 200
    body = price(client)
    assert (body["reports"], body["enough"], body["medianExtraPaise"]) == (3, True, 700)


def test_median_resists_outlier_and_negative_extra(client):
    for i, p in enumerate([9000, 10500, 10500, 10600, 999999]):  # one discount, one typo
        paid(client, f"o{i}", paid=p)
    assert price(client)["medianExtraPaise"] == 500


def test_scoped_by_seller_and_pincode(client):
    for i in range(3):
        paid(client, f"a{i}", seller="s1", pincode="560001", paid=10100)
        paid(client, f"b{i}", seller="s2", pincode="560001", paid=12000)
        paid(client, f"c{i}", seller="s1", pincode="400001", paid=15000)
    assert price(client, "s1", "560001")["medianExtraPaise"] == 100
    assert price(client, "s2", "560001")["medianExtraPaise"] == 2000
    assert price(client, "s1", "400001")["medianExtraPaise"] == 5000
    assert price(client, "s3", "560001")["reports"] == 0


def test_report_without_items_is_stored_but_not_counted(client):
    for i in range(3):
        assert paid(client, f"o{i}", items=None).status_code == 200
    assert price(client)["reports"] == 0


def test_same_order_replaces_not_duplicates(client):
    for _ in range(5):
        paid(client, "o1", paid=12000)
    assert price(client)["reports"] == 1
    paid(client, "o1", paid=10000)
    assert v2_db.extras("s1", "560001") == [0]


def test_other_install_cannot_overwrite(client):
    assert paid(client, "o1", who="phone-1").status_code == 200
    assert paid(client, "o1", who="phone-2", paid=99999).status_code == 409
    assert v2_db.extras("s1", "560001") == [1000]


@pytest.mark.parametrize("override", [
    {"paid": -1}, {"paid": "100"}, {"paid": 10.5}, {"paid": True}, {"paid": 10**10},
    {"items": -5}, {"pincode": "56001"}, {"pincode": "abcdef"}, {"seller": ""}])
def test_validation(client, override):
    assert paid(client, "o1", **override).status_code == 422


def test_unknown_fields_are_not_stored(client):
    paid(client, "o1", patientName="Asha", phone="9999999999")
    with v2_db.connect() as conn:
        cols = {r[1] for r in conn.execute("PRAGMA table_info(true_price_reports)")}
        dump = repr([tuple(r) for r in conn.execute("SELECT * FROM true_price_reports")])
    assert not {"name", "phone", "patient"} & cols
    assert "Asha" not in dump and "9999999999" not in dump


def test_query_validation(client):
    assert client.get("/true_price", params={"seller": "s1", "pincode": "12"}).status_code == 422
    assert client.get("/true_price", params={"seller": "s1"}).status_code == 422


def test_real_order_can_only_be_reported_by_its_owner(client, isolated_db):
    """Found live (K23): another install could pre-claim an order id before its owner reported it."""
    isolated_db.reserve_order("real-order", "phone-1")
    assert paid(client, "real-order", who="phone-2").status_code == 409
    assert v2_db.extras("s1", "560001") == []
    assert paid(client, "real-order", who="phone-1").status_code == 200
    assert v2_db.extras("s1", "560001") == [1000]


def test_invented_order_id_is_refused_even_for_sandbox(client):
    """K30: an id that is not in the orders table (or is another install's) never creates a report."""
    body = {"sellerID": "s1", "pincode": "560001", "paidPaise": 11000, "itemsPaise": 10000}
    r = client.post("/orders/made-up/paid", json=body, headers={"X-Test-Install": "phone-1"})
    assert (r.status_code, r.json()["detail"]) == (404, "order not found")
    for i in range(3):
        assert client.post(f"/orders/fake{i}/paid", json=body).status_code == 404
    assert v2_db.extras("s1", "560001") == [] and price(client)["reports"] == 0
    db.reserve_order("mine", "phone-1")
    assert client.post("/orders/mine/paid", json=body, headers={"X-Test-Install": "phone-2"}).status_code == 409
    assert client.post("/orders/mine/paid", json=body, headers={"X-Test-Install": "phone-1"}).status_code == 200
    db.mark_deleting("phone-1")  # an order being deleted does not exist any more
    assert client.post("/orders/mine/paid", json=body, headers={"X-Test-Install": "phone-1"}).status_code == 404
