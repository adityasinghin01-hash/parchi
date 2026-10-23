"""A1 automation (K26): finished orders feed seller reliability by themselves, once."""
import asyncio
from contextlib import asynccontextmanager
from datetime import timedelta
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from temporalio.testing import WorkflowEnvironment
from temporalio.worker import Worker

import activities
import reliability
import v2_db
from conftest import line, plan, sellers
from test_api import FakeTemporal, headers
from test_workflows import until
from workflows import OrderWorkflow

ACTS = [activities.place_order, activities.audit, activities.store_approval, activities.record_outcome]


@pytest.fixture(scope="module")
def temporal_env():
    with asyncio.Runner() as runner:
        env = runner.run(WorkflowEnvironment.start_time_skipping())
        yield runner, env
        runner.run(env.shutdown())


def counts(area, seller):
    rows = v2_db.reliability_counts(reliability.normalize_area(area), seller)
    return (rows[0]["ok"], rows[0]["total"]) if rows else (0, 0)


async def counted(area, seller, expected, tries=500):
    """The failure state is visible a moment before the activity runs: wait for the count."""
    for _ in range(tries):
        if counts(area, seller) == expected:
            return
        await asyncio.sleep(0.01)
    assert counts(area, seller) == expected


async def start(env, db, queue, current=None, area="Noida", install="phone", oid=None):
    oid = oid or uuid4().hex
    db.reserve_order(oid, install)
    data = {"order_id": oid, "install_id": install, "plan": current or plan(), "sellers": sellers(),
            "auto_approve_cap_paise": None, "time_scale": 1}
    if area:
        data["area"] = area
    handle = await env.client.start_workflow(OrderWorkflow.run, data, id="order-" + oid, task_queue=queue)
    await until(handle, lambda s: s["ready"])
    return oid, handle


def run(temporal_env, scenario):
    runner, env = temporal_env
    queue = "rel-" + uuid4().hex

    async def main():
        async with Worker(env.client, task_queue=queue, workflows=[OrderWorkflow], activities=ACTS):
            await scenario(env, queue)
    runner.run(main())


@pytest.mark.parametrize("kind,ok", [("delivered", 1), ("cancelled", 0), ("outOfStock", 0), ("sampleRejected", 0)])
def test_each_outcome_counts_once(temporal_env, isolated_db, kind, ok):
    async def scenario(env, queue):
        oid, handle = await start(env, isolated_db, queue)
        assert counts("noida", "s1") == (0, 0)
        await handle.signal("seller_event", args=["s1", kind])
        await until(handle, lambda s: s["state"] in ("done", "needs_proposal"))
        await counted("noida", "s1", (ok, 1))
        await asyncio.sleep(0.2)
        assert counts("noida", "s1") == (ok, 1)
        assert reliability.score("Noida", "s1") == pytest.approx((ok + 4) / 6)
    run(temporal_env, scenario)


def test_late_counts_once_and_a_later_delivery_cannot_undo_it(temporal_env, isolated_db):
    async def scenario(env, queue):
        oid, handle = await start(env, isolated_db, queue)
        await env.sleep(timedelta(minutes=91))
        await until(handle, lambda s: s["state"] == "needs_proposal")
        await counted("noida", "s1", (0, 1))
        await handle.signal("seller_event", args=["s1", "delivered"])  # ignored: seller already failed
        await handle.signal("seller_event", args=["s1", "late"])
        await asyncio.sleep(0.3)
        assert counts("noida", "s1") == (0, 1)
    run(temporal_env, scenario)


def test_confirm_and_ship_do_not_count(temporal_env, isolated_db):
    async def scenario(env, queue):
        oid, handle = await start(env, isolated_db, queue)
        for kind in ("confirmed", "shipped"):
            await handle.signal("seller_event", args=["s1", kind])
        await until(handle, lambda s: s["sellers"][0]["status"] == "shipped")
        assert counts("noida", "s1") == (0, 0)
    run(temporal_env, scenario)


def test_duplicate_signals_and_activity_replay_count_once(temporal_env, isolated_db):
    async def scenario(env, queue):
        oid, handle = await start(env, isolated_db, queue)
        for _ in range(3):
            await handle.signal("seller_event", args=["s1", "delivered"])
        assert (await handle.result())["state"] == "done"
        assert counts("noida", "s1") == (1, 1)
        # The activity itself retried / replayed after success: still one.
        for _ in range(3):
            assert await asyncio.to_thread(reliability.record_order_outcome, oid, "s1", "noida", "delivered") is False
        assert counts("noida", "s1") == (1, 1)
    run(temporal_env, scenario)


def test_worker_restart_mid_order(temporal_env, isolated_db):
    runner, env = temporal_env
    queue = "rel-restart-" + uuid4().hex

    async def main():
        current = plan([line(), line("b", "s2", 200)])
        async with Worker(env.client, task_queue=queue, workflows=[OrderWorkflow], activities=ACTS, max_cached_workflows=0):
            oid, handle = await start(env, isolated_db, queue, current)
            await handle.signal("seller_event", args=["s1", "delivered"])
            await until(handle, lambda s: s["sellers"][0]["status"] == "delivered")
        # worker is gone; a signal arrives while nobody is running, then a fresh worker rebuilds from history
        await handle.signal("seller_event", args=["s1", "delivered"])
        await handle.signal("seller_event", args=["s2", "cancelled"])
        assert counts("noida", "s2") == (0, 0)
        async with Worker(env.client, task_queue=queue, workflows=[OrderWorkflow], activities=ACTS, max_cached_workflows=0):
            await counted("noida", "s2", (0, 1), tries=1000)  # the restarted worker replays history and finishes the work
            await until(handle, lambda s: s["state"] == "needs_proposal")
            assert counts("noida", "s1") == (1, 1)
            await handle.signal("seller_event", args=["s2", "cancelled"])
            await asyncio.sleep(0.3)
            assert counts("noida", "s2") == (0, 1)
            await handle.terminate("test cleanup")
    runner.run(main())


def test_two_orders_same_seller_two_areas(temporal_env, isolated_db):
    async def scenario(env, queue):
        a, ha = await start(env, isolated_db, queue, area="Noida")
        b, hb = await start(env, isolated_db, queue, area="560001")
        c, hc = await start(env, isolated_db, queue, area=None)  # no area on the order
        await ha.signal("seller_event", args=["s1", "delivered"])
        await hb.signal("seller_event", args=["s1", "cancelled"])
        await hc.signal("seller_event", args=["s1", "delivered"])
        await asyncio.gather(ha.result(), until(hb, lambda s: s["state"] == "needs_proposal"), hc.result())
        await counted("560001", "s1", (0, 1))
        assert counts("noida", "s1") == (1, 1)
        assert counts("560001", "s1") == (0, 1)
        assert counts(reliability.DEFAULT_AREA, "s1") == (1, 1)
        assert reliability.score("noida", "s1") == pytest.approx(5 / 6)
        assert reliability.score("560001", "s1") == pytest.approx(4 / 6)
    run(temporal_env, scenario)


def test_plan_b_replacement_seller_counts_for_itself(temporal_env, isolated_db):
    from conftest import proposal
    async def scenario(env, queue):
        oid, handle = await start(env, isolated_db, queue)
        await handle.signal("seller_event", args=["s1", "outOfStock"])
        await until(handle, lambda s: s["state"] == "needs_proposal")
        await handle.signal("proposal", args=[1, dict(proposal(), failure="outOfStock")])
        await until(handle, lambda s: s["state"] == "awaiting_approval")
        await handle.signal("approve", args=[1])
        await until(handle, lambda s: s["planVersion"] == 2 and s["state"] == "placed")
        await handle.signal("seller_event", args=["s3", "delivered"])
        assert (await handle.result())["state"] == "done"
        await counted("noida", "s1", (0, 1))  # failed once, not again when rerouted
        assert counts("noida", "s3") == (1, 1)
    run(temporal_env, scenario)


# ---- the DB / endpoint layer (no Temporal) ----

def test_no_count_for_deleted_or_unknown_order(isolated_db):
    isolated_db.reserve_order("o1", "phone")
    isolated_db.mark_deleting("phone")
    assert reliability.record_order_outcome("o1", "s1", "noida", "delivered") is False
    assert reliability.record_order_outcome("never-existed", "s1", "noida", "delivered") is False
    assert counts("noida", "s1") == (0, 0)


def test_manual_endpoint_shares_the_key_and_keeps_working(isolated_db):
    isolated_db.reserve_order("o1", "phone")
    assert reliability.record_order_outcome("o1", "s1", "noida", "cancelled") is True
    # same key: nothing changes, same score comes back
    assert reliability.record("noida", "s1", "cancelled", order_id="o1") == pytest.approx(4 / 6)
    assert counts("noida", "s1") == (0, 1)
    # ok / delivered are one outcome
    reliability.record("noida", "s2", "ok", order_id="o2")
    reliability.record("noida", "s2", "delivered", order_id="o2")
    assert counts("noida", "s2") == (1, 1)
    # without an order id it behaves exactly as before (demo button)
    reliability.record("noida", "s1", "cancelled")
    reliability.record("noida", "s1", "cancelled")
    assert counts("noida", "s1") == (0, 3)
    # a different order is a different key
    reliability.record("noida", "s1", "cancelled", order_id="o3")
    assert counts("noida", "s1") == (0, 4)


def test_manual_api_dedupes_by_order_id(isolated_db, monkeypatch):
    import api
    import auth
    monkeypatch.setenv("PARCHI_ADMIN_KEY", "judge-secret")
    auth.limiter.clear()
    api.app.state.temporal = FakeTemporal()
    with TestClient(api.app) as client:
        post = lambda body: client.post("/judge/reliability/record", headers={"X-Admin-Key": "judge-secret"}, json=body)
        first = post({"area": "noida", "sellerID": "s1", "outcome": "fail", "orderID": "o9"})
        again = post({"area": "noida", "sellerID": "s1", "outcome": "fail", "orderID": "o9"})
        assert first.json() == again.json() == {"ok": True, "score": round(4 / 6, 4)}
        assert post({"area": "noida", "sellerID": "s1", "outcome": "fail", "orderID": 5}).status_code == 422
        assert counts("noida", "s1") == (0, 1)
    auth.limiter.clear()


def test_score_formula_unchanged():
    assert reliability.compute_score(0, 0) == pytest.approx(0.8)
    assert reliability.compute_score(3, 3) == pytest.approx(7 / 8)
    assert reliability.compute_score(1, 3) == pytest.approx(5 / 8)


def test_aggregate_rows_hold_no_install_or_order_id(isolated_db):
    isolated_db.reserve_order("order-secret-id", "install-secret-id")
    reliability.record_order_outcome("order-secret-id", "s1", "noida", "delivered")
    with v2_db.connect() as conn:
        cols = [r["name"] for r in conn.execute("PRAGMA table_info(seller_reliability)")]
        rows = [dict(r) for r in conn.execute("SELECT * FROM seller_reliability")]
        keys = [dict(r) for r in conn.execute("SELECT * FROM reliability_seen")]
    assert cols == ["area", "seller_id", "ok", "total"]
    assert rows == [{"area": "noida", "seller_id": "s1", "ok": 1, "total": 1}]
    assert len(keys[0]["key"]) == 64 and "order-secret-id" not in str(keys)  # one-way hash


def test_delete_everything_clears_keys_but_keeps_counts(isolated_db, monkeypatch):
    import api
    import auth
    monkeypatch.setenv("PARCHI_ADMIN_KEY", "judge-secret")
    auth.limiter.clear()
    install, key = auth.issue_key("phone one")
    other, other_key = auth.issue_key("phone two")
    temporal = FakeTemporal()
    api.app.state.temporal = temporal
    api.app.dependency_overrides[api.get_temporal] = lambda: temporal
    with TestClient(api.app) as client:
        mine = client.post("/order", headers={"X-Install-Key": key, "Idempotency-Key": "a"},
                           json={"plan": plan(), "sellers": sellers(), "city": "Noida"}).json()["orderID"]
        theirs = client.post("/order", headers={"X-Install-Key": other_key, "Idempotency-Key": "b"},
                             json={"plan": plan(), "sellers": sellers()}).json()["orderID"]
        assert temporal.handles[f"order-{mine}"].data["plan"]  # started
        for oid in (mine, theirs):
            reliability.record_order_outcome(oid, "s1", "noida", "delivered")
        assert counts("noida", "s1") == (2, 2)
        with v2_db.connect() as conn:
            assert conn.execute("SELECT count(*) FROM reliability_seen").fetchone()[0] == 2
        assert client.post("/reset", headers={"X-Install-Key": key}, json={}).status_code == 200
        with v2_db.connect() as conn:
            assert [r["install_id"] for r in conn.execute("SELECT install_id FROM reliability_seen")] == [other]
        assert counts("noida", "s1") == (2, 2)  # aggregate stays
        # a late retry for the deleted order cannot count again
        assert reliability.record_order_outcome(mine, "s1", "noida", "delivered") is False
        assert counts("noida", "s1") == (2, 2)
        assert client.post("/reset?scope=demo", headers={"X-Admin-Key": "judge-secret"}, json={}).status_code == 200
        with v2_db.connect() as conn:
            assert conn.execute("SELECT count(*) FROM reliability_seen").fetchone()[0] == 0
        assert counts("noida", "s1") == (2, 2)
    api.app.dependency_overrides.clear()
    auth.limiter.clear()


@pytest.mark.parametrize("extra,expected", [
    ({}, "unknown"), ({"pincode": "201301"}, "201301"), ({"city": "Noida", "pincode": "201301"}, "Noida"),
    ({"area": "Sector 62", "city": "Noida"}, "Sector 62")])
def test_order_area_is_passed_to_the_workflow(isolated_db, monkeypatch, extra, expected):
    import api
    import auth
    auth.limiter.clear()
    install, key = auth.issue_key("phone")
    temporal = FakeTemporal()
    captured = {}
    real = temporal.start_workflow

    async def spy(name, data, **kw):
        captured.update(data)
        return await real(name, data, **kw)
    temporal.start_workflow = spy
    api.app.dependency_overrides[api.get_temporal] = lambda: temporal
    with TestClient(api.app) as client:
        r = client.post("/order", headers={"X-Install-Key": key, "Idempotency-Key": "k"},
                        json={"plan": plan(), "sellers": sellers(), **extra})
        assert r.status_code == 201
        assert captured["area"] == (expected if expected != "unknown" else reliability.DEFAULT_AREA)
        bad = client.post("/order", headers={"X-Install-Key": key, "Idempotency-Key": "k2"},
                          json={"plan": plan(), "sellers": sellers(), "area": "x" * 65})
        assert bad.status_code == 422
    api.app.dependency_overrides.clear()
    auth.limiter.clear()
