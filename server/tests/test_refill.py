import asyncio
from datetime import date, datetime, timedelta
from uuid import uuid4

import httpx
import pytest
from fastapi import FastAPI, Header
from temporalio.testing import WorkflowEnvironment
from temporalio.worker import Worker

import refill
from refill import IST, RefillWorkflow, days_left, doses_per_day, due_at, plan_refill

D = date(2026, 10, 23)


# ---- pure functions ----

@pytest.mark.parametrize("value,expected", [
    ("1-0-1", 2), ("0-0-1", 1), ("1-1-1", 3), ("1-0-1-0", 2), ("0.5-0-0.5", 1),
    (2, 2), (1, 1), (0.5, 0.5), (" 1-0-1 ", 2)])
def test_doses_per_day(value, expected):
    assert doses_per_day(value) == expected


@pytest.mark.parametrize("value", ["abc", "", "0-0-0", 0, -1, True, None, "1", "1-0-1-0-1", 25, [1]])
def test_doses_per_day_rejects(value):
    with pytest.raises(ValueError):
        doses_per_day(value)


def test_days_left_1_0_1():
    assert days_left(30, "1-0-1", D, D) == 15
    assert days_left(30, "1-0-1", D, D + timedelta(days=5)) == 10
    assert days_left(30, "1-0-1", D, D + timedelta(days=15)) == 0
    assert days_left(30, "1-0-1", D, D + timedelta(days=40)) == 0  # never negative
    assert days_left(30, "1-0-1", D, D - timedelta(days=3)) == 15  # not started yet


def test_days_left_0_0_1():
    assert days_left(10, "0-0-1", D, D) == 10
    assert days_left(10, "0-0-1", D, D + timedelta(days=9)) == 1
    assert days_left(10, "0-0-1", D, D + timedelta(days=10)) == 0


def test_days_left_partial_packs():
    assert days_left(15, "1-0-1", D, D) == 7      # 1 tablet left over is not a full day
    assert days_left(1, "1-0-1", D, D) == 0
    assert days_left(10, 3, D, D) == 3
    assert days_left(10, 3, D, D + timedelta(days=1)) == 2
    assert days_left(3, 0.5, D, D) == 6           # half a tablet a day
    assert days_left(0, "0-0-1", D, D) == 0


def test_due_at_is_runout_minus_3_days_9am_ist():
    due = due_at(date(2026, 11, 10))
    assert due.isoformat() == "2026-11-07T09:00:00+05:30"
    assert due.utcoffset() == timedelta(hours=5, minutes=30)


def test_plan_refill_earliest_item_wins():
    result = plan_refill([{"name": "A", "quantity": 30, "dosesPerDay": "1-0-1"},
                          {"name": "B", "quantity": 10, "dosesPerDay": "0-0-1"}], D, D)
    assert result["daysLeft"] == 10
    assert result["runsOutOn"] == "2026-11-02"
    assert result["refillDueAt"] == "2026-10-30T09:00:00+05:30"
    assert [(r["name"], r["daysLeft"], r["runsOutOn"]) for r in result["items"]] == [
        ("A", 15, "2026-11-07"), ("B", 10, "2026-11-02")]


def test_plan_refill_mid_course():
    result = plan_refill([{"name": "A", "quantity": 30, "dosesPerDay": "1-0-1"}], D, D + timedelta(days=5))
    assert (result["daysLeft"], result["runsOutOn"]) == (10, "2026-11-07")


@pytest.mark.parametrize("items", [
    [], None, "x", [{"name": "A", "quantity": -1, "dosesPerDay": 1}],
    [{"name": "A", "quantity": 5}], [{"name": "", "quantity": 5, "dosesPerDay": 1}],
    [{"quantity": 5, "dosesPerDay": 1}], [{"name": "A", "quantity": "5", "dosesPerDay": 1}]])
def test_plan_refill_rejects(items):
    with pytest.raises(ValueError):
        plan_refill(items, D, D)


# ---- workflow + API on the time-skipping Temporal test server ----

@pytest.fixture
def temporal_env():
    # One server per test: skipping time moves its clock, and the API computes dates from the real clock.
    with asyncio.Runner() as runner:
        env = runner.run(WorkflowEnvironment.start_time_skipping())
        yield runner, env
        runner.run(env.shutdown())


class Harness:
    def __init__(self, env, http):
        self.env, self.http = env, http

    def h(self, who="phone-1"):
        return {"X-Test-Install": who}

    async def watch(self, items=None, start=None, who="phone-1"):
        start = start or datetime.now(IST).date()
        body = {"items": items or [{"name": "Metformin", "quantity": 30, "dosesPerDay": "1-0-1"}],
                "startDate": start.isoformat()}
        return await self.http.post("/refill/watch", json=body, headers=self.h(who))

    async def status(self, refill_id, who="phone-1"):
        return await self.http.get(f"/refill/{refill_id}/status", headers=self.h(who))

    async def until(self, refill_id, state):
        for _ in range(500):
            body = (await self.status(refill_id)).json()
            if body.get("state") == state:
                return body
            await asyncio.sleep(0.01)
        raise AssertionError(f"never reached {state}: {body}")


def run_with_harness(temporal_env, monkeypatch, scenario):
    runner, env = temporal_env
    queue = "refill-test-" + uuid4().hex
    monkeypatch.setenv("PARCHI_TASK_QUEUE", queue)
    monkeypatch.delenv("PARCHI_TIME_SCALE", raising=False)

    async def main():
        app = FastAPI()

        def install_dep() -> str:
            raise AssertionError("must be overridden")
        refill.register(app, lambda: env.client, install_dep)
        app.dependency_overrides[install_dep] = lambda x_test_install=Header(default="phone-1"): x_test_install
        async with Worker(env.client, task_queue=queue, workflows=refill.WORKFLOWS, activities=refill.ACTIVITIES):
            async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://t") as http:
                await scenario(env, Harness(env, http))
    runner.run(main())


def test_watch_due_then_done(temporal_env, monkeypatch):
    async def scenario(env, t):
        response = await t.watch()  # 30 tablets at 1-0-1 = 15 days -> due on day 12 at 09:00 IST
        assert response.status_code == 201
        body = response.json()
        assert body["daysLeft"] == 15
        assert datetime.fromisoformat(body["refillDueAt"]).hour == 9
        rid = body["refillID"]
        status = (await t.status(rid)).json()
        assert status["state"] == "waiting" and status["refillDueAt"] == body["refillDueAt"]
        assert "installID" not in status
        await env.sleep(timedelta(days=11))
        assert (await t.status(rid)).json()["state"] == "waiting"
        await env.sleep(timedelta(days=2))
        due = await t.until(rid, "due")
        assert due["dueFiredAt"] is not None
        assert (await t.http.post(f"/refill/{rid}/done", headers=t.h())).status_code == 200
        assert (await t.until(rid, "done"))["state"] == "done"
        # a late cancel after done is refused and changes nothing
        assert (await t.http.post(f"/refill/{rid}/cancel", headers=t.h())).status_code == 409
        assert (await t.status(rid)).json()["state"] == "done"
    run_with_harness(temporal_env, monkeypatch, scenario)


def test_cancel_while_waiting_never_fires(temporal_env, monkeypatch):
    async def scenario(env, t):
        rid = (await t.watch()).json()["refillID"]
        assert (await t.http.post(f"/refill/{rid}/cancel", headers=t.h())).status_code == 200
        await t.until(rid, "cancelled")
        await env.sleep(timedelta(days=30))
        status = (await t.status(rid)).json()
        assert status["state"] == "cancelled" and status["dueFiredAt"] is None
    run_with_harness(temporal_env, monkeypatch, scenario)


def test_already_overdue_is_due_immediately(temporal_env, monkeypatch):
    async def scenario(env, t):
        items = [{"name": "Thyroxine", "quantity": 10, "dosesPerDay": "0-0-1"}]
        body = (await t.watch(items, start=datetime.now(IST).date() - timedelta(days=9))).json()
        assert body["daysLeft"] == 1
        await t.until(body["refillID"], "due")
    run_with_harness(temporal_env, monkeypatch, scenario)


def test_time_scale_shrinks_the_wait(temporal_env):
    runner, env = temporal_env

    async def main():
        queue = "refill-scale-" + uuid4().hex
        due = (datetime.now(IST) + timedelta(days=10)).isoformat()
        async with Worker(env.client, task_queue=queue, workflows=[RefillWorkflow]):
            fast = await env.client.start_workflow(
                RefillWorkflow.run, {"refill_id": "f", "install_id": "i", "due_at": due, "time_scale": 1 / 86400},
                id="refill-f-" + uuid4().hex, task_queue=queue)
            slow = await env.client.start_workflow(
                RefillWorkflow.run, {"refill_id": "s", "install_id": "i", "due_at": due, "time_scale": 1},
                id="refill-s-" + uuid4().hex, task_queue=queue)
            await env.sleep(timedelta(seconds=30))  # 10 days / 86400 = ~10 s
            assert (await fast.query("snapshot"))["state"] == "due"
            assert (await slow.query("snapshot"))["state"] == "waiting"
            await fast.signal("done")
            assert (await fast.result())["state"] == "done"
            await slow.terminate("test cleanup")
    runner.run(main())


def test_status_is_private_and_validated(temporal_env, monkeypatch):
    async def scenario(env, t):
        rid = (await t.watch()).json()["refillID"]
        assert (await t.status(rid, who="phone-2")).status_code == 404
        assert (await t.http.post(f"/refill/{rid}/cancel", headers=t.h("phone-2"))).status_code == 404
        assert (await t.status(rid)).json()["state"] == "waiting"  # the other install changed nothing
        assert (await t.status("0" * 32)).status_code == 404
        assert (await t.status("not-an-id")).status_code == 404
        bad = [{"items": [], "startDate": "2026-10-23"},
               {"items": [{"name": "A", "quantity": 5, "dosesPerDay": 0}], "startDate": "2026-10-23"},
               {"items": [{"name": "A", "quantity": 5, "dosesPerDay": 1}], "startDate": "yesterday"},
               {"items": [{"name": "A", "quantity": 5, "dosesPerDay": 1}]}]
        for body in bad:
            assert (await t.http.post("/refill/watch", json=body, headers=t.h())).status_code == 422
        await t.http.post(f"/refill/{rid}/cancel", headers=t.h())
    run_with_harness(temporal_env, monkeypatch, scenario)
