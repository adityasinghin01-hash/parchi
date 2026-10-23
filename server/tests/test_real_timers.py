"""K31 item 3a: with PARCHI_TIME_SCALE unset, every timer is the plan value (no sped-up clock hiding in the code).

The live twin is live_timers_check.py, which reads the scheduled duration of the pending TIMER from Temporal itself.

  no-reply shop wait                  10 min
  order: "did this go through?"       15 min after placing
  order: late                         promised ETA + 30 min
  lab: no reply                       30 min;  report chase = report due + 6 h
  refill alert                        3 days before running out, 09:00 IST
  fasting reminder                    21:00 IST the evening before the slot
"""
import asyncio
import copy
from datetime import date, datetime, timedelta

import pytest

import lab_workflows
import p3_db
import refill
import shop
import shop_workflows
import workflows
from conftest import line, plan, sellers
from test_api import api_client, create  # noqa: F401
from test_workflows import order, temporal_env, until  # noqa: F401

IST = refill.IST


@pytest.fixture(autouse=True)
def real_clock(monkeypatch):
    monkeypatch.delenv("PARCHI_TIME_SCALE", raising=False)


# ---- the constants ----

def test_timer_constants_are_the_plan_values():
    assert workflows.CONFIRM_MINUTES == 15
    assert workflows.LATE_GRACE_MINUTES == 30
    assert lab_workflows.NO_REPLY_MINUTES == 30
    assert lab_workflows.CHASE_MINUTES == 6 * 60
    assert refill.LEAD_DAYS == 3
    assert shop_workflows.NEXT_WAIT_MINUTES == 60


def test_the_default_clock_scale_is_one():
    assert shop.time_scale() == 1.0


def test_shop_ask_waits_ten_minutes_by_default():
    ask = shop.validate_ask({"items": [{"itemID": "i", "name": "Metformin", "quantity": 1}],
                             "shops": [{"shopID": "s1", "name": "Shop 1"}], "pickupBy": "2026-10-25T20:00:00+05:30"})
    assert ask["waitMinutes"] == 10


def test_refill_alert_is_three_days_before_running_out_at_0900_ist():
    # 30 tablets at 2/day = 15 days: runs out on day 15, alert on day 12 at 09:00 IST
    result = refill.plan_refill([{"name": "x", "quantity": 30, "dosesPerDay": "1-0-1"}], date(2026, 10, 24), date(2026, 10, 24))
    assert result["runsOutOn"] == "2026-11-08"
    assert result["refillDueAt"] == "2026-11-05T09:00:00+05:30"
    assert datetime.fromisoformat(result["refillDueAt"]) == datetime(2026, 11, 8, 9, 0, tzinfo=IST) - timedelta(days=3)


@pytest.mark.parametrize("slot,expected", [
    ("2026-10-25T08:00:00+05:30", "2026-10-24T21:00:00+05:30"),
    ("2026-11-01T00:30:00+05:30", "2026-10-31T21:00:00+05:30"),   # slot just after midnight: the evening before
    ("2026-10-25T23:45:00+05:30", "2026-10-24T21:00:00+05:30"),
    ("2026-10-24T20:30:00+00:00", "2026-10-24T21:00:00+05:30"),   # 02:00 IST on the 25th, given in UTC
])
def test_fasting_reminder_is_2100_ist_the_evening_before(slot, expected):
    assert p3_db.fasting_reminder(datetime.fromisoformat(slot), [{"fasting": True}]) == expected


def test_no_fasting_reminder_without_a_fasting_test():
    assert p3_db.fasting_reminder(datetime(2026, 10, 25, 8, 0, tzinfo=IST), [{"fasting": False}, {}]) is None


# ---- every API start passes the real scale (1.0) to its workflow ----

def test_every_workflow_start_gets_scale_one(api_client):
    started: list[tuple[str, dict]] = []
    fake = api_client.temporal
    order_start = fake.start_workflow

    async def record(name, data, *, id, **kwargs):
        started.append((name, data))
        if name == "OrderWorkflow":
            return await order_start(name, data, id=id, **kwargs)

    fake.start_workflow = record
    h = {"X-Install-Key": api_client.key}
    c = api_client.client
    assert create(api_client).status_code == 201
    assert c.post("/shop/ask", headers=h, json={
        "items": [{"itemID": "i1", "name": "Metformin", "quantity": 2}],
        "shops": [{"shopID": "s1", "name": "Shop 1", "phone": "+910000000000"}],
        "pickupBy": "2026-10-25T20:00:00+05:30"}).status_code == 201
    assert c.post("/lab/book", headers=h, json={
        "labID": "lab1", "labName": "City Lab", "tests": [{"testID": "t1", "name": "HbA1c", "fasting": True}],
        "homeCollection": True, "preferredSlot": "2026-10-25T07:30:00+05:30", "addressText": "12 MG Road"}).status_code == 201
    assert c.post("/refill/watch", headers=h, json={
        "startDate": date.today().isoformat(), "items": [{"name": "x", "quantity": 400, "dosesPerDay": "1-0-1"}]}).status_code == 201
    assert sorted(n for n, _ in started) == ["LabBookingWorkflow", "OrderWorkflow", "RefillWorkflow", "ShopAskWorkflow"]
    for name, data in started:
        assert data["time_scale"] == 1.0, name
    shop_data = next(d for n, d in started if n == "ShopAskWorkflow")
    assert shop_data["wait_minutes"] == 10


# ---- the order clocks, on the real scale, in the time-skipping server ----

def test_order_confirm_clock_is_15_minutes_and_late_is_eta_plus_30(temporal_env, isolated_db):
    async def scenario(env):
        meta = sellers()                       # every seller promises 60 min
        async with order(env, isolated_db, plan([line()]), metadata=meta) as (oid, handle):
            await env.sleep(timedelta(minutes=14, seconds=50))
            assert (await handle.query("snapshot"))["needsCheck"] == []
            await env.sleep(timedelta(seconds=20))                         # 15 min 10 s
            snap = await until(handle, lambda s: s["needsCheck"] == ["s1"])
            assert snap["state"] == "placed"
            await env.sleep(timedelta(minutes=74, seconds=30))             # 89 min 40 s: ETA 60 + 30 = 90 not reached
            assert (await handle.query("snapshot"))["state"] == "placed"
            await env.sleep(timedelta(seconds=40))                         # 90 min 20 s
            snap = await until(handle, lambda s: s["state"] == "needs_proposal")
            assert snap["pending"] == {"sellerID": "s1", "failure": "late"}
    temporal_env[0].run(scenario(temporal_env[1]))


def test_late_follows_a_different_promised_eta(temporal_env, isolated_db):
    async def scenario(env):
        meta = copy.deepcopy(sellers())
        meta[0]["etaMinutes"] = 240
        async with order(env, isolated_db, plan([line()]), metadata=meta) as (oid, handle):
            await env.sleep(timedelta(minutes=269, seconds=30))
            assert (await handle.query("snapshot"))["state"] == "placed"
            await env.sleep(timedelta(minutes=1))                          # 270 min 30 s = 240 + 30
            await until(handle, lambda s: s["state"] == "needs_proposal")
    temporal_env[0].run(scenario(temporal_env[1]))


def test_a_confirmed_order_has_only_the_late_timer_left(temporal_env, isolated_db):
    """K31: once a seller confirmed, the 15 min check is gone; the next deadline is ETA + 30 min."""
    async def scenario(env):
        async with order(env, isolated_db, plan([line()])) as (oid, handle):
            before = (await handle.query("snapshot"))["deadlines"]["s1"]
            assert before["confirmDue"] is not None and before["lateDue"] is not None
            await handle.signal("seller_event", args=["s1", "confirmed"])
            snap = await until(handle, lambda s: s["sellers"][0]["status"] == "confirmed")
            after = snap["deadlines"]["s1"]
            assert after["confirmDue"] is None and after["lateDue"] == before["lateDue"]
            placed = datetime.fromisoformat(before["placedAt"])
            assert datetime.fromisoformat(before["confirmDue"]) - placed == timedelta(minutes=15)
            assert datetime.fromisoformat(before["lateDue"]) - placed == timedelta(minutes=60 + 30)
    temporal_env[0].run(scenario(temporal_env[1]))
