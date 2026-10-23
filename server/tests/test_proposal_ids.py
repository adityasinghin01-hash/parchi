"""K31 item 2: proposal ids on approve / reject.

API cases use the fake Temporal of test_api (the handle's snapshot is edited by hand); the workflow cases run the real
OrderWorkflow in the time-skipping test server."""
import asyncio
import copy

import pytest

import test_api
from test_api import api_client, create, headers  # noqa: F401
from test_workflows import order, temporal_env, until  # noqa: F401
from conftest import line, plan, proposal


def awaiting(ctx, oid, proposal_id="1-1", state="awaiting_approval", version=1):
    handle = ctx.temporal.handles["order-" + oid]
    handle.data.update(state=state, planVersion=version,
                       proposal=None if proposal_id is None else {"proposalID": proposal_id})
    return handle


def decide(ctx, oid, action, **body):
    return ctx.client.post(f"/order/{oid}/{action}", headers=headers(ctx, "decide-" + str(len(str(body)))),
                           json={"planVersion": 1, **body})


@pytest.mark.parametrize("action", ["approve", "reject"])
def test_current_proposal_id_is_accepted_and_forwarded(api_client, action):
    oid = create(api_client).json()["orderID"]
    handle = awaiting(api_client, oid)
    r = decide(api_client, oid, action, proposalID="1-1")
    assert r.status_code == 200 and r.json() == {"ok": True}
    assert handle.signals == [(action, [1, "1-1"])]


@pytest.mark.parametrize("action", ["approve", "reject"])
def test_old_client_without_an_id_still_works(api_client, action):
    oid = create(api_client).json()["orderID"]
    handle = awaiting(api_client, oid)
    assert decide(api_client, oid, action).status_code == 200
    assert handle.signals == [(action, [1])]  # the old signal shape


@pytest.mark.parametrize("action", ["approve", "reject"])
def test_an_id_that_is_not_the_current_proposal_is_409(api_client, action):
    oid = create(api_client).json()["orderID"]
    handle = awaiting(api_client, oid, proposal_id="1-2")
    r = decide(api_client, oid, action, proposalID="1-1")
    assert r.status_code == 409 and r.json() == {"detail": "stale proposal"}
    assert handle.signals == []


@pytest.mark.parametrize("action", ["approve", "reject"])
@pytest.mark.parametrize("state", ["placed", "needs_proposal", "done"])
@pytest.mark.parametrize("with_id", [True, False])
def test_a_decision_on_an_already_resolved_proposal_is_409_not_200(api_client, action, state, with_id):
    oid = create(api_client).json()["orderID"]
    handle = awaiting(api_client, oid, proposal_id=None, state=state)
    r = decide(api_client, oid, action, **({"proposalID": "1-1"} if with_id else {}))
    assert r.status_code == 409 and r.json() == {"detail": "stale proposal"}
    assert handle.signals == []


def test_a_late_reject_replay_cannot_reject_a_newer_proposal(api_client):
    oid = create(api_client).json()["orderID"]
    handle = awaiting(api_client, oid, proposal_id="1-1")
    assert decide(api_client, oid, "reject", proposalID="1-1").status_code == 200
    awaiting(api_client, oid, proposal_id="1-2")  # the next failure got its own proposal, same planVersion
    r = decide(api_client, oid, "reject", proposalID="1-1")  # the old reject, delivered again
    assert r.status_code == 409 and r.json() == {"detail": "stale proposal"}
    assert handle.signals == [("reject", [1, "1-1"])]
    assert decide(api_client, oid, "reject", proposalID="1-2").status_code == 200


@pytest.mark.parametrize("bad", [5, ["1-1"], "", "x" * 65, {"a": 1}])
def test_a_malformed_id_is_422(api_client, bad):
    oid = create(api_client).json()["orderID"]
    awaiting(api_client, oid)
    assert decide(api_client, oid, "approve", proposalID=bad).status_code == 422
    assert decide(api_client, oid, "reject", proposalID=bad).status_code == 422


def test_stale_plan_version_is_still_reported_first(api_client):
    oid = create(api_client).json()["orderID"]
    awaiting(api_client, oid, version=2)
    r = decide(api_client, oid, "approve", proposalID="1-1")
    assert r.status_code == 409 and r.json() == {"detail": "stale planVersion"}


def test_status_shows_the_proposal_id(api_client):
    oid = create(api_client).json()["orderID"]
    awaiting(api_client, oid, proposal_id="1-7")
    body = api_client.client.get(f"/status/{oid}", headers=headers(api_client)).json()
    assert body["proposal"]["proposalID"] == "1-7"


# ---- the workflow itself (real OrderWorkflow, time-skipping test server) ----

def test_workflow_stamps_ids_and_ignores_a_stale_decision(temporal_env, isolated_db):
    async def scenario(env):
        current = plan([line(), line("b", "s2", 200), line("c", "s4", 300)])
        async with order(env, isolated_db, current) as (oid, handle):
            await handle.signal("seller_event", args=["s1", "cancelled"])
            await handle.signal("seller_event", args=["s2", "cancelled"])  # queued behind s1
            await until(handle, lambda s: s["state"] == "needs_proposal")
            p1 = proposal(current)
            await handle.signal("proposal", args=[1, {**p1, "proposalID": "forged"}])  # a client cannot choose the id
            state = await until(handle, lambda s: s["state"] == "awaiting_approval")
            assert state["proposal"]["proposalID"] == "1-1"
            await handle.signal("reject", args=[1, "1-1"])
            state = await until(handle, lambda s: s["pending"] and s["pending"]["sellerID"] == "s2")
            assert state["proposal"] is None and state["planVersion"] == 1
            p2 = proposal(current, failed="s2", replacement="s3")
            await handle.signal("proposal", args=[1, p2])
            state = await until(handle, lambda s: s["state"] == "awaiting_approval")
            assert state["proposal"]["proposalID"] == "1-2"
            await handle.signal("reject", args=[1, "1-1"])  # the late replay of the first reject
            await handle.signal("approve", args=[1, "1-1"])  # and a late approve of it
            await asyncio.sleep(0.3)
            state = await handle.query("snapshot")
            assert state["state"] == "awaiting_approval" and state["proposal"]["proposalID"] == "1-2"
            assert state["planVersion"] == 1
            reasons = [a["detail"] for a in isolated_db.audit_for(oid, 50) if a["event"] == "ignored_signal"]
            assert sum(1 for d in reasons if d.get("reason") == "stale_proposal") == 2
            await handle.signal("approve", args=[1, "1-2"])  # the right id is accepted
            state = await until(handle, lambda s: s["planVersion"] == 2)
            assert state["sellers"][1]["status"] == "rerouted"
    temporal_env[0].run(scenario(temporal_env[1]))


def test_workflow_still_takes_old_shaped_decisions(temporal_env, isolated_db):
    async def scenario(env):
        async with order(env, isolated_db, plan([line(), line("b", "s2", 200)])) as (oid, handle):
            await handle.signal("seller_event", args=["s1", "cancelled"])
            await until(handle, lambda s: s["state"] == "needs_proposal")
            await handle.signal("proposal", args=[1, proposal(plan([line(), line("b", "s2", 200)]))])
            await until(handle, lambda s: s["state"] == "awaiting_approval")
            await handle.signal("approve", args=[1])  # no id: the old signal shape
            await until(handle, lambda s: s["planVersion"] == 2)
    temporal_env[0].run(scenario(temporal_env[1]))
