"""K30: Delete everything removes the install's workflows from Temporal (all four kinds), and the approval race."""
import threading
from types import SimpleNamespace

import pytest
from temporalio.service import RPCError, RPCStatusCode

import approve_guard
import p3_db
from test_api import FakeHandle, api_client, create, headers  # noqa: F401  (api_client is a fixture)

ASK = {"items": [{"itemID": "i", "name": "x", "quantity": 1}], "pickupBy": "2026-10-25T10:00:00+05:30",
       "groupSize": 1, "waitMinutes": 10, "shops": [{"shopID": "s1", "name": "Shop"}]}
BOOKING = {"labID": "l", "labName": "Lab", "tests": [{"testID": "t", "name": "CBC"}], "homeCollection": False,
           "preferredSlot": "2026-10-25T08:00:00+05:30"}


def make_all(ctx, install):
    """An order (through the API), a shop ask, a lab booking and a refill watch for `install`; returns workflow ids."""
    key = ctx.key if install == ctx.install else ctx.other_key
    oid = ctx.client.post("/order", headers={"X-Install-Key": key, "Idempotency-Key": "k30-" + install},
                          json=_order_body()).json()["orderID"]
    ask_id, _ = p3_db.create_ask(install, ASK)
    booking_id, _ = p3_db.create_booking(install, BOOKING)
    ids = {"order": "order-" + oid, "shop": "shop-" + ask_id, "lab": "lab-" + booking_id, "refill": "refill-" + install[:8]}
    ctx.temporal.handles[ids["shop"]] = FakeHandle({})
    ctx.temporal.handles[ids["lab"]] = FakeHandle({})
    ctx.temporal.handles[ids["refill"]] = FakeHandle({"installID": install, "state": "waiting"})
    return ids


def _order_body():
    from conftest import plan, sellers
    return {"plan": plan(), "sellers": sellers()}


def test_reset_terminates_and_deletes_all_four_kinds_for_this_install_only(api_client):
    mine, theirs = make_all(api_client, api_client.install), make_all(api_client, api_client.other_install)
    temporal = api_client.temporal
    response = api_client.client.post("/reset", headers=headers(api_client, "x"), json={})
    assert response.status_code == 200
    assert response.json()["workflowsDeleted"] == 4 and response.json()["workflowsKept"] == 0
    assert sorted(temporal.deleted) == sorted(mine.values())           # all four histories deleted ...
    assert not any(w in temporal.handles for w in mine.values())       # ... so none can be listed or described
    for wid in theirs.values():                                        # the other install is untouched
        assert wid in temporal.handles and not temporal.handles[wid].terminated
    assert p3_db.get_ask(mine["shop"][5:]) is None and p3_db.get_booking(mine["lab"][4:]) is None
    assert p3_db.get_ask(theirs["shop"][5:]) is not None and p3_db.get_booking(theirs["lab"][4:]) is not None


def test_workflows_are_terminated_before_they_are_deleted(api_client):
    """Temporal refuses to delete a running workflow; the fake asserts it, so a wrong order fails here."""
    ids = make_all(api_client, api_client.install)
    api_client.client.post("/reset", headers=headers(api_client, "x"), json={})
    assert sorted(api_client.temporal.deleted) == sorted(ids.values())


def test_demo_reset_deletes_every_installs_workflows(api_client):
    ids = [*make_all(api_client, api_client.install).values(), *make_all(api_client, api_client.other_install).values()]
    assert api_client.client.post("/reset?scope=demo", headers={"X-Admin-Key": "judge-secret"}, json={}).status_code == 200
    assert sorted(api_client.temporal.deleted) == sorted(ids)


def test_tombstoned_orders_of_an_earlier_reset_are_found_too(api_client):
    """Rows of an order are gone after a reset, but its id stays in deleted_orders for 48 h: a later reset still wipes it."""
    oid = create(api_client).json()["orderID"]
    api_client.db.delete_orders(api_client.install)
    api_client.temporal.handles["order-" + oid].terminated = True
    assert api_client.client.post("/reset", headers=headers(api_client, "x"), json={}).json()["workflowsDeleted"] == 1
    assert "order-" + oid in api_client.temporal.deleted


def test_server_that_cannot_delete_still_resets_and_says_so(api_client):
    ids = make_all(api_client, api_client.install)

    async def refuse(request):
        raise RPCError("unimplemented", RPCStatusCode.UNIMPLEMENTED, b"")
    api_client.temporal.workflow_service = SimpleNamespace(delete_workflow_execution=refuse)
    response = api_client.client.post("/reset", headers=headers(api_client, "x"), json={})
    assert response.status_code == 200
    assert response.json()["workflowsDeleted"] == 0 and response.json()["workflowsKept"] == 4
    assert all(api_client.temporal.handles[w].terminated for w in ids.values())  # still stopped
    assert api_client.db.list_orders(api_client.install) == []                  # rows deleted anyway


def test_temporal_error_during_delete_keeps_rows_so_reset_can_be_retried(api_client):
    make_all(api_client, api_client.install)

    async def broken(request):
        raise RPCError("boom", RPCStatusCode.INTERNAL, b"")
    original = api_client.temporal.workflow_service
    api_client.temporal.workflow_service = SimpleNamespace(delete_workflow_execution=broken)
    assert api_client.client.post("/reset", headers=headers(api_client, "x"), json={}).status_code == 503
    assert len(api_client.db.mark_deleting(api_client.install)) == 1   # order row still there (hidden), not forgotten
    api_client.temporal.workflow_service = original
    assert api_client.client.post("/reset", headers=headers(api_client, "x"), json={}).json()["workflowsDeleted"] == 4


# ---- approval race ----

@pytest.fixture
def awaiting(api_client):
    oid = create(api_client).json()["orderID"]
    handle = api_client.temporal.handles["order-" + oid]
    handle.data.update(state="awaiting_approval", planVersion=1)
    return oid, handle


def approve(ctx, oid, idem=None, version=1):
    h = {"X-Install-Key": ctx.key, **({"Idempotency-Key": idem} if idem else {})}
    return ctx.client.post(f"/order/{oid}/approve", headers=h, json={"planVersion": version})


def test_two_simultaneous_approvals_one_wins_one_gets_409(api_client, awaiting):
    oid, handle = awaiting
    gate, results = threading.Barrier(8), []

    def go():
        gate.wait()
        results.append(approve(api_client, oid))
    threads = [threading.Thread(target=go) for _ in range(8)]
    [t.start() for t in threads]; [t.join() for t in threads]
    codes = sorted(r.status_code for r in results)
    assert codes == [200] + [409] * 7, codes
    assert all(r.json() == {"detail": "already approved"} for r in results if r.status_code == 409)
    assert [s[0] for s in handle.signals].count("approve") == 1  # exactly one signal reached the workflow


def test_same_idempotency_key_replays_the_first_answer(api_client, awaiting):
    oid, handle = awaiting
    first = approve(api_client, oid, "key-1")
    assert (first.status_code, first.json()) == (200, {"ok": True})
    handle.data["planVersion"] = 2     # the workflow moved on after the approval
    replay = approve(api_client, oid, "key-1")
    assert (replay.status_code, replay.json()) == (200, {"ok": True})
    assert approve(api_client, oid, "key-2").status_code == 409             # a different key is a different request
    assert approve(api_client, oid, None).status_code == 409
    assert [s[0] for s in handle.signals].count("approve") == 1             # the replay sent nothing


def test_second_approval_after_the_version_moved_on_is_already_approved(api_client, awaiting):
    oid, handle = awaiting
    assert approve(api_client, oid).status_code == 200
    handle.data.update(planVersion=2, state="placed")
    late = approve(api_client, oid)
    assert (late.status_code, late.json()) == (409, {"detail": "already approved"})
    assert approve(api_client, oid, version=7).json() == {"detail": "stale planVersion"}   # unknown version: as before


def test_approve_when_not_awaiting_is_refused_and_not_claimed(api_client):
    """K31 answers 409 for an approval nobody asked for; it must not leave a claim that blocks the real one later."""
    oid = create(api_client).json()["orderID"]
    handle = api_client.temporal.handles["order-" + oid]
    assert approve(api_client, oid).status_code == 409
    assert not approve_guard.is_claimed(oid, 1)
    handle.data["state"] = "awaiting_approval"
    assert approve(api_client, oid).status_code == 200


def test_wrong_proposal_id_releases_the_claim(api_client, awaiting):
    oid, handle = awaiting
    handle.data["proposal"] = {"proposalID": "p-2"}
    wrong = api_client.client.post(f"/order/{oid}/approve", headers={"X-Install-Key": api_client.key},
                                   json={"planVersion": 1, "proposalID": "p-1"})
    assert wrong.status_code == 409 and not approve_guard.is_claimed(oid, 1)
    right = api_client.client.post(f"/order/{oid}/approve", headers={"X-Install-Key": api_client.key},
                                   json={"planVersion": 1, "proposalID": "p-2"})
    assert right.status_code == 200


def test_failed_signal_releases_the_claim(api_client, awaiting):
    oid, handle = awaiting

    async def broken(name, *, args):
        raise RPCError("down", RPCStatusCode.UNAVAILABLE, b"")
    good = handle.signal
    handle.signal = broken
    with pytest.raises(RPCError):
        approve(api_client, oid)
    assert not approve_guard.is_claimed(oid, 1)
    handle.signal = good
    assert approve(api_client, oid).status_code == 200


def test_other_install_cannot_approve_or_probe(api_client, awaiting):
    oid, _ = awaiting
    r = api_client.client.post(f"/order/{oid}/approve", headers={"X-Install-Key": api_client.other_key},
                               json={"planVersion": 1})
    assert r.status_code == 404
    assert not approve_guard.is_claimed(oid, 1)


def test_non_integer_version_is_still_422(api_client, awaiting):
    oid, _ = awaiting
    assert approve(api_client, oid, version="1").status_code == 422
