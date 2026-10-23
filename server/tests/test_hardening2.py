"""Round 2 from the independent review: key reuse, reset replay, delivered replacement, unresolved items, /read proxy."""
import copy

import httpx
import pytest

import api
import contract
from conftest import line, plan, proposal, sellers
from test_api import api_client, create, headers  # noqa: F401
from test_workflows import order, temporal_env, until  # noqa: F401


def test_same_key_different_body_is_409(api_client):
    assert create(api_client).status_code == 201
    other = {"plan": plan([line(price=999)]), "sellers": sellers()}
    r = api_client.client.post("/order", headers=headers(api_client), json=other)
    assert r.status_code == 409 and "different request" in r.json()["detail"]


def test_replayed_key_after_reset_does_not_resurrect_the_order(api_client):
    oid = create(api_client).json()["orderID"]
    assert api_client.client.post("/reset", headers=headers(api_client), json={}).status_code == 200
    r = create(api_client)
    assert r.status_code == 409 and "deleted" in r.json()["detail"]
    assert api_client.db.get_order(oid) is None


def test_reroute_to_a_delivered_seller_is_rejected():
    current = plan()
    p = proposal(current)  # reroutes a -> s3
    statuses = {"s1": "failed", "s3": "delivered"}
    with pytest.raises(ValueError, match="already delivered"):
        contract.validate_proposal(p, current, sellers(), {"sellerID": "s1", "failure": "cancelled"}, statuses)


def test_partial_proposal_keeps_unresolved_items_visible(temporal_env, isolated_db):
    import asyncio

    async def scenario(env):
        current = plan([line("a", "s1", 100), line("b", "s1", 100)])
        async with order(env, isolated_db, current) as (oid, handle):
            await handle.signal("seller_event", args=["s1", "cancelled"])
            await until(handle, lambda s: s["state"] == "needs_proposal")
            moved = [dict(line("a", "s3", 125))]
            p = {"failure": "cancelled", "failedSellerID": "s1", "kept": [], "rerouted": moved,
                 "newPlan": plan(moved), "extraCost": 125 - 200, "stillMissing": ["b"]}
            await handle.signal("proposal", args=[1, p])
            await until(handle, lambda s: s["state"] == "awaiting_approval")
            await handle.signal("approve", args=[1])
            state = await until(handle, lambda s: s["planVersion"] == 2)
            assert state["unresolvedItems"] == ["b"]
            rows = isolated_db.audit_for(oid)
            assert any(r["event"] == "approved" and r["detail"]["unresolvedItems"] == ["b"] for r in rows)
    temporal_env[0].run(scenario(temporal_env[1]))


# ---- /read proxy ----

@pytest.fixture
def reader(api_client, monkeypatch):
    monkeypatch.setenv("PARCHI_READER_URL", "http://reader.test/read")
    calls = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request)
        return httpx.Response(200, json={"lines": [{"name": "Telma", "strength": "40"}]})

    monkeypatch.setattr(api, "READER_TRANSPORT", httpx.MockTransport(handler))
    return calls


def post_image(ctx, data=b"\x89PNG fake", ctype="image/png"):
    return ctx.client.post("/read", headers={"X-Install-Key": ctx.key}, files={"image": ("p.png", data, ctype)})


def test_read_forwards_to_the_reader_and_returns_its_json(api_client, reader):
    r = post_image(api_client)
    assert r.status_code == 200 and r.json() == {"lines": [{"name": "Telma", "strength": "40"}]}
    assert len(reader) == 1 and b"fake" in reader[0].content


def test_read_rejects_wrong_type_and_oversize(api_client, reader):
    assert post_image(api_client, ctype="text/plain").status_code == 415
    assert post_image(api_client, data=b"x" * 4_000_001).status_code == 413
    assert reader == []  # nothing reached the reader


def test_read_when_reader_is_down_is_503(api_client, monkeypatch):
    monkeypatch.setenv("PARCHI_READER_URL", "http://reader.test/read")

    def boom(request):
        raise httpx.ConnectError("down")

    monkeypatch.setattr(api, "READER_TRANSPORT", httpx.MockTransport(boom))
    r = post_image(api_client)
    assert r.status_code == 503 and r.json() == {"detail": "reader not connected"}


def test_read_requires_the_install_key(api_client, reader):
    assert api_client.client.post("/read", files={"image": ("p.png", b"x", "image/png")}).status_code == 401
