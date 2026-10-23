import asyncio
from collections import defaultdict
from datetime import timedelta
from types import SimpleNamespace
from uuid import uuid4

import pytest
from fastapi import FastAPI, Request
from fastapi.testclient import TestClient
from temporalio.testing import WorkflowEnvironment
from temporalio.worker import Worker

import lab
import lab_workflows
import p3_db

XSS = "<script>alert(1)</script>"
SLOT = "2026-10-25T07:30:00+05:30"
REMINDER = "2026-10-24T21:00:00+05:30"
FORM = {"content-type": "application/x-www-form-urlencoded"}


class FakeHandle:
    def __init__(self, broken=False):
        self.signals = []
        self.broken = broken

    async def signal(self, name, *, args):
        if self.broken:
            raise RuntimeError("down")
        self.signals.append((name, args))


class FakeTemporal:
    def __init__(self):
        self.handles = defaultdict(FakeHandle)
        self.started = []
        self.fail_start = False

    async def start_workflow(self, name, data, *, id, **kwargs):
        if self.fail_start:
            raise RuntimeError("down")
        self.started.append((name, id, data))

    def get_workflow_handle(self, id):
        return self.handles[id]


def book_body(**extra):
    body = {"labID": "lab1", "labName": "City Lab",
            "tests": [{"testID": "t1", "name": "HbA1c"},
                      {"testID": "t2", "name": "Fasting glucose", "fasting": True}],
            "homeCollection": True, "preferredSlot": SLOT, "addressText": "12 MG Road"}
    body.update(extra)
    return body


@pytest.fixture
def ctx(isolated_db, monkeypatch):
    import auth
    monkeypatch.setenv("PARCHI_ADMIN_KEY", "judge-secret")
    auth.limiter.clear()
    temporal = FakeTemporal()
    app = FastAPI()

    async def get_temporal():
        return temporal

    def install(request: Request) -> str:
        return request.headers["X-Test-Install"]

    lab.register(app, get_temporal, install)
    with TestClient(app) as client:
        yield SimpleNamespace(client=client, temporal=temporal, db=isolated_db,
                              h={"X-Test-Install": "inst-a"}, admin={"X-Admin-Key": "judge-secret"})
    auth.limiter.clear()


def book(ctx, **extra):
    response = ctx.client.post("/lab/book", headers=ctx.h, json=book_body(**extra))
    assert response.status_code == 201, response.text
    data = response.json()
    data["token"] = data["replyLink"].rsplit("/", 1)[1]
    return data


def status(ctx, booking_id):
    return ctx.client.get(f"/lab/{booking_id}/status", headers=ctx.h).json()


def judge(ctx, booking_id, kind, **extra):
    return ctx.client.post(f"/judge/lab/{booking_id}/event", headers=ctx.admin,
                           json={"kind": kind, **extra})


# ---- router ----

def test_book_returns_link_and_starts_workflow(ctx):
    data = book(ctx)
    assert len(data["token"]) >= 22 and data["replyLink"].startswith("http")
    name, wid, wf_data = ctx.temporal.started[0]
    assert (name, wid) == ("LabBookingWorkflow", "lab-" + data["bookingID"])
    assert wf_data["booking_id"] == data["bookingID"]
    assert status(ctx, data["bookingID"]) == {
        "bookingID": data["bookingID"], "state": "requested", "noReply": False}
    with p3_db.connect() as conn:  # only a hash of the token is stored
        dump = str(tuple(conn.execute("SELECT * FROM lab_bookings").fetchone()))
    assert data["token"] not in dump


@pytest.mark.parametrize("change", [
    {"tests": []}, {"homeCollection": "yes"}, {"preferredSlot": "2026-10-25T07:30:00"},
    {"labName": ""}, {"tests": [{"testID": "t", "name": "x", "fasting": "yes"}]},
    {"orderID": "someone-elses-order"},
])
def test_book_validation(ctx, change):
    assert ctx.client.post("/lab/book", headers=ctx.h, json=book_body(**change)).status_code == 422


def test_book_rolled_back_when_temporal_is_down(ctx):
    ctx.temporal.fail_start = True
    assert ctx.client.post("/lab/book", headers=ctx.h, json=book_body()).status_code == 503
    with p3_db.connect() as conn:
        assert conn.execute("SELECT count(*) FROM lab_bookings").fetchone()[0] == 0


def test_order_link_must_belong_to_the_caller(ctx):
    ctx.db.reserve_order("theirs", "inst-b")
    assert ctx.client.post("/lab/book", headers=ctx.h,
                           json=book_body(orderID="theirs", sellerID="s")).status_code == 422
    ctx.db.reserve_order("mine", "inst-a")
    assert ctx.client.post("/lab/book", headers=ctx.h,
                           json=book_body(orderID="mine", sellerID="s")).status_code == 201


def test_status_belongs_to_the_owner(ctx):
    data = book(ctx)
    assert ctx.client.get(f"/lab/{data['bookingID']}/status",
                          headers={"X-Test-Install": "inst-b"}).status_code == 404
    assert ctx.client.get("/lab/nope/status", headers=ctx.h).status_code == 404


def test_reply_page_is_small_bilingual_and_hardened(ctx):
    data = book(ctx)
    response = ctx.client.get("/lab/reply/" + data["token"])
    assert response.status_code == 200 and len(response.content) < 20_000
    for text in ("Confirm this slot / यह समय पक्का करें", "Propose another slot", "Cannot do / नहीं कर सकते",
                 "City Lab", "HbA1c", "Fasting / खाली पेट", "25 Oct 2026, 07:30 AM", "12 MG Road"):
        assert text in response.text
    assert response.headers["referrer-policy"] == "no-referrer"
    assert "default-src 'none'" in response.headers["content-security-policy"]
    assert ctx.client.get("/lab/reply/nope-nope-nope-nope-nope").status_code == 404


def test_xss_payloads_are_escaped(ctx):
    data = book(ctx, labName=XSS, addressText='"><img src=x onerror=alert(1)>',
                tests=[{"testID": "t", "name": "<svg onload=alert(1)>", "fasting": True}])
    page = ctx.client.get("/lab/reply/" + data["token"]).text
    assert "<script>" not in page and "<img" not in page and "<svg" not in page
    assert "&lt;script&gt;alert(1)&lt;/script&gt;" in page
    assert "&lt;svg onload=alert(1)&gt;" in page


def test_confirm_sets_fasting_reminder_21_00_evening_before(ctx):
    data = book(ctx)
    response = ctx.client.post("/lab/reply/" + data["token"], content="action=confirm", headers=FORM)
    assert response.status_code == 200 and "Thanks" in response.text
    st = status(ctx, data["bookingID"])
    assert st["state"] == "confirmed" and st["noReply"] is False
    assert st["slot"] == SLOT and st["fastingReminderAt"] == REMINDER
    assert ctx.temporal.handles["lab-" + data["bookingID"]].signals == [("lab_event", ["confirmed", None])]


def test_no_fasting_reminder_when_no_test_is_fasting(ctx):
    data = book(ctx, tests=[{"testID": "t1", "name": "HbA1c"},
                            {"testID": "t2", "name": "TSH", "fasting": False}])
    ctx.client.post("/lab/reply/" + data["token"], json={"action": "confirm"})
    st = status(ctx, data["bookingID"])
    assert st["state"] == "confirmed" and "fastingReminderAt" not in st


@pytest.mark.parametrize("slot", ["2026-10-25T00:30:00+05:30", "2026-10-24T19:00:00Z"])
def test_reminder_uses_the_ist_evening_before_the_slot(ctx, slot):
    data = book(ctx, preferredSlot=slot)
    ctx.client.post("/lab/reply/" + data["token"], json={"action": "confirm"})
    assert status(ctx, data["bookingID"])["fastingReminderAt"] == REMINDER


def test_propose_another_slot_with_fee_moves_the_reminder(ctx):
    data = book(ctx)
    response = ctx.client.post("/lab/reply/" + data["token"], headers=FORM,
                               content="action=propose&slot=2026-10-26T09%3A00&fee=150.50")
    assert response.status_code == 200
    st = status(ctx, data["bookingID"])
    assert st["state"] == "confirmed" and st["slot"] == "2026-10-26T09:00:00+05:30"
    assert st["feePaise"] == 15050 and st["fastingReminderAt"] == "2026-10-25T21:00:00+05:30"
    assert st["note"] == "Lab proposed another slot"


def test_propose_json_and_bad_input(ctx):
    data = book(ctx)
    url = "/lab/reply/" + data["token"]
    assert ctx.client.post(url, json={"action": "propose"}).status_code == 422
    assert ctx.client.post(url, json={"action": "propose", "slot": "soon"}).status_code == 422
    assert ctx.client.post(url, json={"action": "propose", "slot": SLOT, "feePaise": -1}).status_code == 422
    assert ctx.client.post(url, json={"action": "maybe"}).status_code == 422
    assert status(ctx, data["bookingID"])["state"] == "requested"
    ok = ctx.client.post(url, json={"action": "propose", "slot": SLOT, "feePaise": 5000})
    assert ok.status_code == 200 and ok.json()["feePaise"] == 5000


def test_decline_and_one_answer_only(ctx):
    data = book(ctx)
    url = "/lab/reply/" + data["token"]
    assert ctx.client.post(url, headers=FORM, content="action=decline").status_code == 200
    st = status(ctx, data["bookingID"])
    assert st["state"] == "rejected" and "slot" not in st
    assert ctx.temporal.handles["lab-" + data["bookingID"]].signals == [("lab_event", ["rejected", None])]
    assert ctx.client.post(url, json={"action": "confirm"}).status_code == 409
    assert "answered" in ctx.client.get(url).text
    assert status(ctx, data["bookingID"])["state"] == "rejected"


def test_judge_needs_admin_and_valid_kind(ctx):
    data = book(ctx)
    url = f"/judge/lab/{data['bookingID']}/event"
    assert ctx.client.post(url, json={"kind": "confirmed"}).status_code == 401
    assert ctx.client.post(url, json={"kind": "confirmed"}, headers=ctx.h).status_code == 401
    assert judge(ctx, data["bookingID"], "nonsense").status_code == 422
    assert judge(ctx, "nope", "confirmed").status_code == 404


def test_judge_lifecycle_and_report_due(ctx):
    data = book(ctx)
    bid = data["bookingID"]
    assert judge(ctx, bid, "collected").status_code == 409        # not confirmed yet
    assert judge(ctx, bid, "report_ready").status_code == 409
    assert judge(ctx, bid, "confirmed").status_code == 200
    st = status(ctx, bid)
    assert st["state"] == "confirmed" and st["slot"] == SLOT and st["fastingReminderAt"] == REMINDER
    assert judge(ctx, bid, "confirmed").status_code == 409
    assert judge(ctx, bid, "collected").status_code == 200
    st = status(ctx, bid)
    assert st["state"] == "collected" and st["reportDueAt"] == "2026-10-26T07:30:00+05:30"  # slot + 24 h
    assert judge(ctx, bid, "report_ready").status_code == 200
    assert status(ctx, bid)["state"] == "done"
    assert ctx.temporal.handles["lab-" + bid].signals == [
        ("lab_event", ["confirmed", None]),
        ("lab_event", ["collected", "2026-10-26T07:30:00+05:30"]),
        ("lab_event", ["report_ready", None])]


def test_judge_collected_accepts_a_report_due_time(ctx):
    data = book(ctx)
    bid = data["bookingID"]
    judge(ctx, bid, "confirmed")
    assert judge(ctx, bid, "collected", reportDueAt="2026-10-25T18:00:00+05:30").status_code == 200
    assert status(ctx, bid)["reportDueAt"] == "2026-10-25T18:00:00+05:30"


def test_sample_rejected_signals_the_order_workflow(ctx):
    ctx.db.reserve_order("order1", "inst-a")
    data = book(ctx, orderID="order1", sellerID="lab-seller")
    bid = data["bookingID"]
    judge(ctx, bid, "confirmed")
    judge(ctx, bid, "collected")
    response = judge(ctx, bid, "sample_rejected")
    assert response.status_code == 200 and response.json()["orderSignalled"] is True
    assert ctx.temporal.handles["order-order1"].signals == [("seller_event", ["lab-seller", "sampleRejected"])]
    st = status(ctx, bid)
    assert st["state"] == "rejected" and st["note"] == "Sample rejected"


def test_phlebotomist_late_signals_the_order_workflow(ctx):
    ctx.db.reserve_order("order1", "inst-a")
    data = book(ctx, orderID="order1", sellerID="lab-seller")
    bid = data["bookingID"]
    assert judge(ctx, bid, "phlebotomist_late").status_code == 409  # only after confirmation
    judge(ctx, bid, "confirmed")
    assert judge(ctx, bid, "phlebotomist_late").status_code == 200
    assert ctx.temporal.handles["order-order1"].signals == [("seller_event", ["lab-seller", "late"])]
    st = status(ctx, bid)
    assert st["state"] == "confirmed" and st["note"] == "Phlebotomist is late"


def test_no_order_signal_without_order_and_seller(ctx):
    ctx.db.reserve_order("order1", "inst-a")
    only_order = book(ctx, orderID="order1")
    plain = book(ctx)
    for data in (only_order, plain):
        judge(ctx, data["bookingID"], "confirmed")
        assert judge(ctx, data["bookingID"], "phlebotomist_late").json()["orderSignalled"] is False
    assert "order-order1" not in ctx.temporal.handles


def test_failed_order_signal_is_reported(ctx):
    ctx.db.reserve_order("order1", "inst-a")
    data = book(ctx, orderID="order1", sellerID="lab-seller")
    judge(ctx, data["bookingID"], "confirmed")
    ctx.temporal.handles["order-order1"] = FakeHandle(broken=True)
    assert judge(ctx, data["bookingID"], "phlebotomist_late").status_code == 502


def test_delete_install_clears_bookings(ctx):
    mine = book(ctx)
    other = ctx.client.post("/lab/book", headers={"X-Test-Install": "inst-b"}, json=book_body()).json()
    p3_db.delete_install("inst-a")
    assert p3_db.get_booking(mine["bookingID"]) is None
    assert p3_db.get_booking(other["bookingID"]) is not None


# ---- workflow (time skipping) ----

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


def new_booking():
    booking = lab.validate_booking(book_body(), "inst-a")
    return p3_db.create_booking("inst-a", booking)


def worker_for(env):
    queue = "lab-" + uuid4().hex
    return queue, Worker(env.client, task_queue=queue, workflows=lab_workflows.WORKFLOWS,
                         activities=lab_workflows.ACTIVITIES)


def db_state(booking_id):
    return p3_db.booking_status(p3_db.get_booking(booking_id))


def test_workflow_no_reply_at_30_minutes_then_late_reply(temporal_env, isolated_db):
    async def scenario(env):
        bid, token = new_booking()
        queue, worker = worker_for(env)
        async with worker:
            handle = await env.client.start_workflow(
                "LabBookingWorkflow", {"booking_id": bid, "time_scale": 1}, id="lab-" + bid, task_queue=queue)
            await env.sleep(timedelta(minutes=29))
            assert (await handle.query("snapshot"))["noReply"] is False
            assert db_state(bid)["noReply"] is False
            await env.sleep(timedelta(minutes=2))
            snap = await until(handle, lambda s: s["noReply"])
            assert snap["state"] == "requested"
            assert db_state(bid) == {"bookingID": bid, "state": "requested", "noReply": True}
            # a late answer is still accepted and clears the flag
            p3_db.lab_reply(token, "confirm")
            await handle.signal("lab_event", args=["confirmed", None])
            snap = await until(handle, lambda s: s["state"] == "confirmed")
            assert snap["noReply"] is False and db_state(bid)["noReply"] is False
            await handle.terminate("test cleanup")
    temporal_env[0].run(scenario(temporal_env[1]))


def test_workflow_no_reply_respects_time_scale(temporal_env, isolated_db):
    async def scenario(env):
        bid, _ = new_booking()
        queue, worker = worker_for(env)
        async with worker:
            handle = await env.client.start_workflow(
                "LabBookingWorkflow", {"booking_id": bid, "time_scale": 0.1}, id="lab-" + bid, task_queue=queue)
            await env.sleep(timedelta(minutes=3, seconds=5))   # 30 min x 0.1
            await until(handle, lambda s: s["noReply"])
            await handle.terminate("test cleanup")
    temporal_env[0].run(scenario(temporal_env[1]))


def test_workflow_report_chase_at_due_plus_6_hours(temporal_env, isolated_db):
    async def scenario(env):
        bid, _ = new_booking()
        queue, worker = worker_for(env)
        async with worker:
            handle = await env.client.start_workflow(
                "LabBookingWorkflow", {"booking_id": bid, "time_scale": 1}, id="lab-" + bid, task_queue=queue)
            p3_db.lab_event(bid, "confirmed")
            await handle.signal("lab_event", args=["confirmed", None])
            await until(handle, lambda s: s["state"] == "confirmed")
            due = (await env.get_current_time()) + timedelta(hours=2)
            row = p3_db.lab_event(bid, "collected", due.isoformat())
            await handle.signal("lab_event", args=["collected", row["report_due_at"]])
            await until(handle, lambda s: s["state"] == "collected")
            await env.sleep(timedelta(hours=1, minutes=59))
            assert (await handle.query("snapshot"))["state"] == "collected"
            assert db_state(bid)["state"] == "collected"
            await env.sleep(timedelta(minutes=2))                      # now due + 1 min
            await until(handle, lambda s: s["state"] == "report_due")
            assert db_state(bid)["state"] == "report_due"
            await env.sleep(timedelta(hours=5))                        # due + 5 h 1 min
            assert (await handle.query("snapshot"))["state"] == "report_due"
            await env.sleep(timedelta(hours=1))                        # due + 6 h 1 min
            await until(handle, lambda s: s["state"] == "report_chase_due")
            assert db_state(bid)["state"] == "report_chase_due"
            p3_db.lab_event(bid, "report_ready")
            await handle.signal("lab_event", args=["report_ready", None])
            result = await handle.result()
        assert result["state"] == "done" and db_state(bid)["state"] == "done"
    temporal_env[0].run(scenario(temporal_env[1]))


def test_workflow_report_ready_before_due_stops_the_timers(temporal_env, isolated_db):
    async def scenario(env):
        bid, _ = new_booking()
        queue, worker = worker_for(env)
        async with worker:
            handle = await env.client.start_workflow(
                "LabBookingWorkflow", {"booking_id": bid, "time_scale": 1}, id="lab-" + bid, task_queue=queue)
            p3_db.lab_event(bid, "confirmed")
            await handle.signal("lab_event", args=["confirmed", None])
            due = (await env.get_current_time()) + timedelta(hours=2)
            row = p3_db.lab_event(bid, "collected", due.isoformat())
            await handle.signal("lab_event", args=["collected", row["report_due_at"]])
            p3_db.lab_event(bid, "report_ready")
            await handle.signal("lab_event", args=["report_ready", None])
            result = await handle.result()
        assert result["state"] == "done" and db_state(bid)["state"] == "done"
    temporal_env[0].run(scenario(temporal_env[1]))


def test_workflow_ends_when_the_lab_declines(temporal_env, isolated_db):
    async def scenario(env):
        bid, token = new_booking()
        queue, worker = worker_for(env)
        async with worker:
            handle = await env.client.start_workflow(
                "LabBookingWorkflow", {"booking_id": bid, "time_scale": 1}, id="lab-" + bid, task_queue=queue)
            p3_db.lab_reply(token, "decline")
            await handle.signal("lab_event", args=["rejected", None])
            result = await handle.result()
        assert result["state"] == "rejected" and db_state(bid)["state"] == "rejected"
    temporal_env[0].run(scenario(temporal_env[1]))


def test_form_reposted_after_answer_says_already_sent_not_error(ctx):
    # K20: reloading the thank-you page re-posts the form.
    data = book(ctx)
    assert ctx.client.post("/lab/reply/" + data["token"], content="action=confirm", headers=FORM).status_code == 200
    again = ctx.client.post("/lab/reply/" + data["token"], content="action=decline", headers=FORM)
    assert again.status_code == 409 and "already sent" in again.text and "Could not send" not in again.text
    assert status(ctx, data["bookingID"])["state"] == "confirmed"
