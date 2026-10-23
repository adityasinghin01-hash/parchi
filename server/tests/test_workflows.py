import asyncio
import copy
from contextlib import asynccontextmanager
from datetime import timedelta
from uuid import uuid4

import pytest
from temporalio.testing import WorkflowEnvironment
from temporalio.worker import Worker

from conftest import line, plan, proposal, sellers
from workflows import OrderWorkflow
import activities


@pytest.fixture(scope="module")
def temporal_env():
    with asyncio.Runner() as runner:
        env = runner.run(WorkflowEnvironment.start_time_skipping())
        yield runner, env
        runner.run(env.shutdown())


async def until(handle, predicate):
    last = None
    for _ in range(500):
        last = await handle.query("snapshot")
        if predicate(last):
            return last
        await asyncio.sleep(0.01)
    raise AssertionError(f"workflow did not reach expected state: {last}")


@asynccontextmanager
async def order(env, db, current=None, cap=None, metadata=None):
    oid = uuid4().hex
    queue = "test-" + oid
    db.reserve_order(oid, "phone")
    async with Worker(env.client, task_queue=queue, workflows=[OrderWorkflow],
                      activities=[activities.place_order, activities.audit,
                                  activities.store_approval]):
        handle = await env.client.start_workflow(
            OrderWorkflow.run,
            {"order_id": oid, "install_id": "phone", "plan": current or plan(),
             "sellers": metadata or sellers(), "auto_approve_cap_paise": cap,
             "time_scale": 1}, id="order-" + oid, task_queue=queue,
        )
        await until(handle, lambda s: s["ready"])
        try:
            yield oid, handle
        finally:
            if (await handle.query("snapshot"))["state"] != "done":
                await handle.terminate("test cleanup")


def test_happy_path(temporal_env, isolated_db):
    async def scenario(env):
        async with order(env, isolated_db) as (oid, handle):
            for kind in ("confirmed", "shipped", "delivered"):
                await handle.signal("seller_event", args=["s1", kind])
            result = await handle.result()
            assert result["state"] == "done"
            assert result["sellers"][0]["status"] == "delivered"
            assert len(isolated_db.placements_for(oid)) == 1
    temporal_env[0].run(scenario(temporal_env[1]))


def test_approved_plan_b_preserves_kept_seller(temporal_env, isolated_db):
    async def scenario(env):
        current = plan([line(), line("b", "s2", 200)])
        async with order(env, isolated_db, current) as (oid, handle):
            await handle.signal("seller_event", args=["s1", "cancelled"])
            state = await until(handle, lambda s: s["state"] == "needs_proposal")
            assert state["pending"] == {"sellerID": "s1", "failure": "cancelled"}
            assert state["waitingSince"] is not None
            p = proposal(current)
            await handle.signal("proposal", args=[1, p])
            await until(handle, lambda s: s["state"] == "awaiting_approval")
            await handle.signal("approve", args=[1])
            state = await until(handle, lambda s: s["planVersion"] == 2 and s["state"] == "placed")
            assert state["plan"] == p["newPlan"]
            assert {s["id"]: s["status"] for s in state["sellers"]} == {
                "s1": "rerouted", "s2": "placed", "s3": "placed"}
            assert [(r["sellerID"], r["planVersion"]) for r in isolated_db.placements_for(oid)] == [
                ("s1", 1), ("s2", 1), ("s3", 2)]
            for sid in ("s2", "s3"):
                await handle.signal("seller_event", args=[sid, "delivered"])
            assert (await handle.result())["state"] == "done"
    temporal_env[0].run(scenario(temporal_env[1]))


def test_stale_approval_is_ignored_and_audited(temporal_env, isolated_db):
    async def scenario(env):
        async with order(env, isolated_db) as (oid, handle):
            await handle.signal("seller_event", args=["s1", "cancelled"])
            await until(handle, lambda s: s["state"] == "needs_proposal")
            await handle.signal("proposal", args=[1, proposal()])
            await until(handle, lambda s: s["state"] == "awaiting_approval")
            await handle.signal("approve", args=[0])
            for _ in range(500):
                rows = isolated_db.audit_for(oid)
                if any(r["event"] == "ignored_signal" and r["detail"].get("reason") == "stale_version"
                       for r in rows):
                    break
                await asyncio.sleep(0.01)
            else:
                raise AssertionError("stale approval was not audited")
            state = await handle.query("snapshot")
            assert state["planVersion"] == 1
            assert state["state"] == "awaiting_approval"
            assert len(isolated_db.placements_for(oid)) == 1
    temporal_env[0].run(scenario(temporal_env[1]))


def test_late_at_eta_plus_30(temporal_env, isolated_db):
    async def scenario(env):
        async with order(env, isolated_db) as (_, handle):
            await handle.signal("seller_event", args=["s1", "confirmed"])
            await until(handle, lambda s: s["sellers"][0]["status"] == "confirmed")
            await env.sleep(timedelta(minutes=89))
            assert (await handle.query("snapshot"))["pending"] is None
            await env.sleep(timedelta(minutes=1, seconds=1))
            state = await until(handle, lambda s: s["state"] == "needs_proposal")
            assert state["pending"]["failure"] == "late"
    temporal_env[0].run(scenario(temporal_env[1]))


def test_unconfirmed_is_check_not_failure(temporal_env, isolated_db):
    async def scenario(env):
        async with order(env, isolated_db) as (_, handle):
            await env.sleep(timedelta(minutes=15, seconds=1))
            state = await until(handle, lambda s: s["needsCheck"] == ["s1"])
            assert state["pending"] is None
            assert state["sellers"][0]["status"] == "placed"
            await handle.signal("seller_event", args=["s1", "confirmed"])
            await until(handle, lambda s: s["needsCheck"] == [])
    temporal_env[0].run(scenario(temporal_env[1]))


def test_auto_approve_under_cap(temporal_env, isolated_db):
    async def scenario(env):
        async with order(env, isolated_db, cap=25) as (oid, handle):
            await handle.signal("seller_event", args=["s1", "cancelled"])
            await until(handle, lambda s: s["state"] == "needs_proposal")
            await handle.signal("proposal", args=[1, proposal(extra=25)])
            await until(handle, lambda s: s["planVersion"] == 2 and s["state"] == "placed")
            with isolated_db.connect() as conn:
                approval = conn.execute("SELECT approver FROM approvals WHERE order_id=?", (oid,)).fetchone()
            assert approval["approver"] == "auto-cap"
            assert len(isolated_db.placements_for(oid)) == 2
    temporal_env[0].run(scenario(temporal_env[1]))


def test_two_failures_are_fifo(temporal_env, isolated_db):
    async def scenario(env):
        current = plan([line(), line("b", "s2", 200)])
        async with order(env, isolated_db, current) as (_, handle):
            await handle.signal("seller_event", args=["s1", "cancelled"])
            await handle.signal("seller_event", args=["s2", "cancelled"])
            state = await until(handle, lambda s: len(s["queue"]) == 1)
            assert state["pending"]["sellerID"] == "s1"
            assert state["queue"][0]["sellerID"] == "s2"
            p1 = proposal(current)
            await handle.signal("proposal", args=[1, p1])
            await until(handle, lambda s: s["state"] == "awaiting_approval")
            await handle.signal("approve", args=[1])
            state = await until(handle, lambda s: s["state"] == "needs_proposal" and s["planVersion"] == 2)
            assert state["pending"]["sellerID"] == "s2"
            p2 = proposal(p1["newPlan"], failed="s2", replacement="s4")
            await handle.signal("proposal", args=[2, p2])
            await until(handle, lambda s: s["state"] == "awaiting_approval")
            await handle.signal("approve", args=[2])
            await until(handle, lambda s: s["planVersion"] == 3 and s["state"] == "placed")
            for sid in ("s3", "s4"):
                await handle.signal("seller_event", args=[sid, "delivered"])
            assert (await handle.result())["state"] == "done"
    temporal_env[0].run(scenario(temporal_env[1]))


def test_reject_leaves_plan_unchanged(temporal_env, isolated_db):
    async def scenario(env):
        async with order(env, isolated_db) as (oid, handle):
            await handle.signal("seller_event", args=["s1", "cancelled"])
            await until(handle, lambda s: s["state"] == "needs_proposal")
            await handle.signal("proposal", args=[1, proposal()])
            await until(handle, lambda s: s["state"] == "awaiting_approval")
            await handle.signal("reject", args=[1])
            result = await handle.result()
            assert result["plan"] == plan()
            assert result["planVersion"] == 1
            assert result["sellers"][0]["status"] == "cancelled"
            assert len(isolated_db.placements_for(oid)) == 1
    temporal_env[0].run(scenario(temporal_env[1]))


def test_nothing_available_requires_explicit_approval(temporal_env, isolated_db):
    async def scenario(env):
        async with order(env, isolated_db, cap=1000) as (oid, handle):
            await handle.signal("seller_event", args=["s1", "cancelled"])
            await until(handle, lambda s: s["state"] == "needs_proposal")
            p = proposal()
            # Swift nothing-available keeps the original plan (see test_contract.py).
            p.update(rerouted=[], newPlan=plan(), extraCost=0, stillMissing=["a"])
            await handle.signal("proposal", args=[1, p])
            state = await until(handle, lambda s: s["state"] == "awaiting_approval")
            assert state["nothingAvailable"] is True
            assert state["planVersion"] == 1
            await handle.signal("approve", args=[1])
            result = await handle.result()
            assert result["state"] == "done"
            assert result["planVersion"] == 2
            assert result["plan"] == plan()
            assert len(isolated_db.placements_for(oid)) == 1
    temporal_env[0].run(scenario(temporal_env[1]))


def test_invalid_proposal_and_premature_approval_do_not_place(temporal_env, isolated_db):
    async def scenario(env):
        current = plan([line(), line("b", "s2", 200)])
        async with order(env, isolated_db, current) as (oid, handle):
            await handle.signal("seller_event", args=["s1", "cancelled"])
            await until(handle, lambda s: s["state"] == "needs_proposal")
            await handle.signal("approve", args=[1])
            bad = copy.deepcopy(proposal(current))
            bad["kept"][0]["price"] = 999
            await handle.signal("proposal", args=[1, bad])
            good = proposal(current)
            await handle.signal("proposal", args=[1, good])
            state = await until(handle, lambda s: s["state"] == "awaiting_approval")
            assert state["planVersion"] == 1
            assert state["proposal"] == good
            assert len(isolated_db.placements_for(oid)) == 2
    temporal_env[0].run(scenario(temporal_env[1]))
