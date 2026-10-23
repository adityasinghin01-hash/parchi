import json
import re

import pytest

import test_api
from test_api import api_client as _api_client  # noqa: F401  (reused fixture)

XSS = "<script>alert(1)</script>"
ADMIN = {"X-Admin-Key": "judge-secret"}
SLOT = "2026-10-25T07:30:00+05:30"
PICKUP = "2026-10-25T20:00:00+05:30"


@pytest.fixture
def api_client(_api_client):
    """The API fixture, whose fake Temporal also accepts the shop/lab workflow starts."""
    fake = _api_client.temporal
    order_start = fake.start_workflow

    async def start(name, data, *, id, **kwargs):
        if name == "OrderWorkflow":
            return await order_start(name, data, id=id, **kwargs)

    fake.start_workflow = start
    return _api_client


def ask(ctx, n_shops=2, **extra):
    body = {"items": [{"itemID": "i1", "name": "Metformin", "quantity": 2},
                      {"itemID": "i2", "name": "Vitamin D", "quantity": 1}],
            "shops": [{"shopID": f"s{n}", "name": f"Shop {n}", "phone": "+910000000000"}
                      for n in range(1, n_shops + 1)],
            "pickupBy": PICKUP}
    body.update(extra)
    r = ctx.client.post("/shop/ask", headers={"X-Install-Key": ctx.key}, json=body)
    assert r.status_code == 201, r.text
    return r.json()


def book(ctx, **extra):
    body = {"labID": "lab1", "labName": "City Lab", "tests": [{"testID": "t1", "name": "HbA1c"}],
            "homeCollection": True, "preferredSlot": SLOT, "addressText": "12 MG Road"}
    body.update(extra)
    r = ctx.client.post("/lab/book", headers={"X-Install-Key": ctx.key}, json=body)
    assert r.status_code == 201, r.text
    return r.json()


def test_endpoints_need_the_admin_key(api_client):
    for path in ("/judge/shop/asks", "/judge/lab/bookings"):
        assert api_client.client.get(path).status_code == 401
        assert api_client.client.get(path, headers={"X-Admin-Key": "wrong"}).status_code == 401
        assert api_client.client.get(path, headers={"X-Install-Key": api_client.key}).status_code == 401
        assert api_client.client.get(path + "?k=judge-secret").status_code == 401  # header only
        assert api_client.client.get(path, headers=ADMIN).status_code == 200


def test_asks_shape_and_no_secrets(api_client):
    made = ask(api_client)
    token = made["replyLinks"][0]["url"].rsplit("/", 1)[1]
    rows = api_client.client.get("/judge/shop/asks", headers=ADMIN).json()
    assert rows == [{
        "askID": made["askID"], "state": "waiting", "round": 1,
        "shops": [{"shopID": "s1", "name": "Shop 1", "state": "asked"},
                  {"shopID": "s2", "name": "Shop 2", "state": "asked"}],
        "items": [{"itemID": "i1", "name": "Metformin", "quantity": 2},
                  {"itemID": "i2", "name": "Vitamin D", "quantity": 1}]}]
    dump = json.dumps(rows)
    assert token not in dump and api_client.install not in dump and "+910000000000" not in dump


def test_asks_newest_first_and_capped_at_ten(api_client):
    ids = [ask(api_client)["askID"] for _ in range(12)]
    rows = api_client.client.get("/judge/shop/asks", headers=ADMIN).json()
    assert [r["askID"] for r in rows] == ids[::-1][:10]


def test_ask_state_follows_a_reply(api_client):
    made = ask(api_client)
    body = {"shopID": "s1", "readyBy": PICKUP,
            "items": [{"itemID": "i1", "available": True, "pricePaise": 4000},
                      {"itemID": "i2", "available": False}]}
    assert api_client.client.post(f"/judge/shop/{made['askID']}/reply", headers=ADMIN, json=body).status_code == 200
    row = api_client.client.get("/judge/shop/asks", headers=ADMIN).json()[0]
    assert row["state"] == "replied"
    assert [s["state"] for s in row["shops"]] == ["replied", "not_needed"]


def test_bookings_shape_newest_first_and_no_secrets(api_client):
    first = book(api_client)
    second = book(api_client, labName="Second Lab")
    token = second["replyLink"].rsplit("/", 1)[1]
    rows = api_client.client.get("/judge/lab/bookings", headers=ADMIN).json()
    assert [r["bookingID"] for r in rows] == [second["bookingID"], first["bookingID"]]
    assert rows[0] == {"bookingID": second["bookingID"], "labName": "Second Lab", "state": "requested"}
    dump = json.dumps(rows)
    assert token not in dump and api_client.install not in dump and "12 MG Road" not in dump


def test_booking_shows_slot_and_order_link_after_confirm(api_client):
    api_client.db.reserve_order("order1", api_client.install)
    made = book(api_client, orderID="order1", sellerID="lab-seller")
    r = api_client.client.post(f"/judge/lab/{made['bookingID']}/event", headers=ADMIN, json={"kind": "confirmed"})
    assert r.status_code == 200
    row = api_client.client.get("/judge/lab/bookings", headers=ADMIN).json()[0]
    assert row == {"bookingID": made["bookingID"], "labName": "City Lab", "state": "confirmed", "slot": SLOT,
                   "orderID": "order1", "sellerID": "lab-seller"}


def test_bookings_capped_at_ten(api_client):
    for n in range(12):
        book(api_client, labName=f"City Lab {n}")  # identical posts within 10 minutes are ONE booking (idempotent), so vary them
    assert len(api_client.client.get("/judge/lab/bookings", headers=ADMIN).json()) == 10


def test_page_needs_the_admin_key(api_client):
    assert api_client.client.get("/judge").status_code == 401
    assert api_client.client.get("/judge?k=wrong").status_code == 401


def test_page_has_both_sections_and_actions(api_client):
    made = ask(api_client)
    booked = book(api_client)
    page = api_client.client.get("/judge", headers=ADMIN).text
    assert "<h2>Shop asks</h2>" in page and "<h2>Lab bookings</h2>" in page
    assert page.count("<button type=\"button\" data-reply-toggle>Reply</button>") == 2 and made["askID"] in page
    assert f'data-ask="{made["askID"]}" data-shop="s1"' in page
    for label, kind in (("Confirm", "confirmed"), ("Collected", "collected"), ("Report ready", "report_ready"),
                        ("Sample rejected", "sample_rejected"), ("Late posting", "phlebotomist_late")):
        assert f'<button data-lab="{booked["bookingID"]}" data-k="{kind}">{label}</button>' in page
    assert "/judge/shop/" in page and "/judge/lab/" in page
    assert "https://" not in page and "http://" not in page and "<script src" not in page  # no CDN


def test_page_keeps_order_buttons(api_client):
    oid = test_api.create(api_client).json()["orderID"]
    page = api_client.client.get("/judge", headers=ADMIN).text
    assert f'<button data-o="{oid}" data-s="s1" data-k="cancelled">Cancel</button>' in page
    assert "'/judge/' + encodeURIComponent(b.dataset.o) + '/event'" in page


def test_reply_form_only_for_shops_that_can_still_answer(api_client):
    made = ask(api_client)
    body = {"shopID": "s1", "readyBy": PICKUP,
            "items": [{"itemID": "i1", "available": True, "pricePaise": 100},
                      {"itemID": "i2", "available": True, "pricePaise": 100}]}
    api_client.client.post(f"/judge/shop/{made['askID']}/reply", headers=ADMIN, json=body)
    page = api_client.client.get("/judge", headers=ADMIN).text
    assert "data-reply-toggle>" not in page and "<b>replied</b>" in page and "<b>not_needed</b>" in page


def test_page_escapes_everything_from_users(api_client):
    oid = test_api.create(api_client).json()["orderID"]
    made = ask(api_client, items=[{"itemID": XSS, "name": XSS, "quantity": 1}],
               shops=[{"shopID": XSS, "name": XSS}])
    book(api_client, labName=XSS, tests=[{"testID": "t", "name": XSS}], orderID=oid, sellerID=XSS)
    page = api_client.client.get("/judge", headers=ADMIN).text
    assert XSS not in page
    assert "&lt;script&gt;alert(1)&lt;/script&gt;" in page
    assert len(re.findall(r"<script", page)) == 1  # only the page's own script
    assert made["askID"] in page
    # The JSON twin is data, not markup.
    assert api_client.client.get("/judge/shop/asks", headers=ADMIN).json()[0]["shops"][0]["name"] == XSS
