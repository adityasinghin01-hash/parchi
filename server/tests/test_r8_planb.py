"""Codex review R8 rows 1-5: Plan B accounting. Each test failed before the fix (see docs/verification/CODEX-REVIEW-8-BACKEND.md)."""
import asyncio
import copy
from datetime import timedelta

import pytest

import contract
from conftest import line, plan, proposal, sellers
from test_workflows import order, temporal_env, until  # noqa: F401  (reused fixtures and helpers)


def run(temporal_env, scenario):
    runner, env = temporal_env
    runner.run(scenario(env))


async def audit_has(db, oid, event, tries=500):
    for _ in range(tries):
        if any(r["event"] == event for r in db.audit_for(oid)):
            return True
        await asyncio.sleep(0.01)
    return False


def slow_second_seller():
    rows = sellers()
    rows[1]["etaMinutes"] = 600          # s2 is not late at 91 minutes, s1 is
    return rows


def test_row1_late_seller_that_delivers_is_reconciled_not_rebought(temporal_env, isolated_db):
    async def scenario(env):
        current = plan([line("a", "s1"), line("b", "s2")])
        async with order(env, isolated_db, current, metadata=slow_second_seller()) as (oid, handle):
            await env.sleep(timedelta(minutes=91))
            state = await until(handle, lambda s: s["state"] == "needs_proposal")
            assert state["pending"] == {"sellerID": "s1", "failure": "late"}
            await handle.signal("seller_event", args=["s1", "delivered"])
            state = await until(handle, lambda s: s["pending"] is None)
            assert state["state"] == "placed" and state["proposal"] is None
            assert {s["id"]: s["status"] for s in state["sellers"]} == {"s1": "delivered", "s2": "placed"}
            assert await audit_has(isolated_db, oid, "delivered_after_late")
            assert [(r["sellerID"], r["planVersion"]) for r in isolated_db.placements_for(oid)] == [("s1", 1), ("s2", 1)]
            await handle.signal("seller_event", args=["s2", "delivered"])
            assert (await handle.result())["state"] == "done"
    run(temporal_env, scenario)


def test_row1_open_proposal_is_dropped_when_the_late_seller_delivers(temporal_env, isolated_db):
    async def scenario(env):
        current = plan([line("a", "s1"), line("b", "s2")])
        async with order(env, isolated_db, current, metadata=slow_second_seller()) as (oid, handle):
            await env.sleep(timedelta(minutes=91))
            await until(handle, lambda s: s["state"] == "needs_proposal")
            await handle.signal("proposal", args=[1, dict(proposal(current, failed="s1", replacement="s3"), failure="late")])
            await until(handle, lambda s: s["state"] == "awaiting_approval")
            await handle.signal("seller_event", args=["s1", "delivered"])
            state = await until(handle, lambda s: s["state"] == "placed")
            assert state["proposal"] is None and state["pending"] is None
            await handle.signal("approve", args=[1])          # a late approve of the dropped proposal changes nothing
            await asyncio.sleep(0.3)
            assert (await handle.query("snapshot"))["planVersion"] == 1
            assert [(r["sellerID"], r["planVersion"]) for r in isolated_db.placements_for(oid)] == [("s1", 1), ("s2", 1)]
    run(temporal_env, scenario)


def test_row2_items_added_to_an_existing_seller_get_their_own_placement(temporal_env, isolated_db):
    async def scenario(env):
        current = plan([line("a", "s1"), line("b", "s2")])
        async with order(env, isolated_db, current) as (oid, handle):
            await handle.signal("seller_event", args=["s2", "confirmed"])
            await handle.signal("seller_event", args=["s1", "cancelled"])
            await until(handle, lambda s: s["state"] == "needs_proposal")
            await handle.signal("proposal", args=[1, proposal(current, failed="s1", replacement="s2")])
            await until(handle, lambda s: s["state"] == "awaiting_approval")
            await handle.signal("approve", args=[1])
            state = await until(handle, lambda s: s["planVersion"] == 2)
            assert [(r["sellerID"], r["planVersion"]) for r in isolated_db.placements_for(oid)] == [("s1", 1), ("s2", 1), ("s2", 2)]
            by = {s["id"]: s["status"] for s in state["sellers"]}
            assert by == {"s1": "rerouted", "s2": "placed"}, "s2 must confirm the added item again"
            await handle.signal("seller_event", args=["s2", "delivered"])
            assert (await handle.result())["state"] == "done"
    run(temporal_env, scenario)


def test_row3_replacement_that_delivered_before_approval_makes_the_proposal_stale(temporal_env, isolated_db):
    async def scenario(env):
        current = plan([line("a", "s1"), line("b", "s3")])
        async with order(env, isolated_db, current) as (oid, handle):
            await handle.signal("seller_event", args=["s1", "cancelled"])
            await until(handle, lambda s: s["state"] == "needs_proposal")
            await handle.signal("proposal", args=[1, proposal(current, failed="s1", replacement="s3")])
            await until(handle, lambda s: s["state"] == "awaiting_approval")
            await handle.signal("seller_event", args=["s3", "delivered"])
            await until(handle, lambda s: {x["id"]: x["status"] for x in s["sellers"]}["s3"] == "delivered")
            await handle.signal("approve", args=[1])
            state = await until(handle, lambda s: s["state"] == "needs_proposal")
            assert state["proposal"] is None and state["planVersion"] == 1
            assert await audit_has(isolated_db, oid, "proposal_stale")
            assert [(r["sellerID"], r["planVersion"]) for r in isolated_db.placements_for(oid)] == [("s1", 1), ("s3", 1)]
    run(temporal_env, scenario)


def failed_both(items=("a", "b")):
    current = plan([line(i, "s1") for i in items])
    pending = {"sellerID": "s1", "failure": "cancelled"}
    return current, pending


def test_row4_nothing_available_must_name_every_failed_item():
    current, pending = failed_both()
    base = {"failure": "cancelled", "failedSellerID": "s1", "kept": [], "rerouted": [], "newPlan": current, "extraCost": 0}
    with pytest.raises(ValueError, match="ALL"):
        contract.validate_proposal(dict(base, stillMissing=["a"]), current, sellers(), pending, {"s1": "failed"})
    contract.validate_proposal(dict(base, stillMissing=["a", "b"]), current, sellers(), pending, {"s1": "failed"})
    contract.validate_proposal(dict(base, stillMissing=["a"]), current, sellers(), pending, {"s1": "failed"}, strict=False)  # old histories


def test_row4_in_the_workflow_a_partial_nothing_available_is_ignored(temporal_env, isolated_db):
    async def scenario(env):
        current, _ = failed_both()
        async with order(env, isolated_db, current) as (oid, handle):
            await handle.signal("seller_event", args=["s1", "cancelled"])
            await until(handle, lambda s: s["state"] == "needs_proposal")
            base = {"failure": "cancelled", "failedSellerID": "s1", "kept": [], "rerouted": [], "newPlan": current, "extraCost": 0}
            await handle.signal("proposal", args=[1, dict(base, stillMissing=["a"])])
            assert await audit_has(isolated_db, oid, "ignored_signal")
            assert (await handle.query("snapshot"))["state"] == "needs_proposal"
    run(temporal_env, scenario)


def test_row5_a_committed_fee_cannot_be_erased_to_pass_the_cap():
    current = plan([line("a", "s1", 1000), line("b", "s2", 1000)])
    current["feesBySeller"], current["feesTotal"] = {"s2": 500}, 500
    pending = {"sellerID": "s1", "failure": "cancelled"}
    p = proposal(current, failed="s1", replacement="s3", extra=500)       # a: 1000 -> 1500
    erased = copy.deepcopy(p)
    erased["newPlan"]["feesBySeller"], erased["newPlan"]["feesTotal"] = {}, 0
    erased["extraCost"] = erased["newPlan"]["itemsTotal"] + 0 - (current["itemsTotal"] + current["feesTotal"])
    assert erased["extraCost"] == 0, "the trick: the dropped fee hides the 500 of extra cost"
    with pytest.raises(ValueError, match="fee"):
        contract.validate_proposal(erased, current, sellers(), pending, {"s1": "failed", "s2": "placed"})
    kept = copy.deepcopy(p)
    kept["newPlan"]["feesBySeller"], kept["newPlan"]["feesTotal"] = {"s2": 500}, 500
    kept["extraCost"] = 500
    contract.validate_proposal(kept, current, sellers(), pending, {"s1": "failed", "s2": "placed"})
