"""Codex review R8 rows 6-7: the lab workflow follows SQLite even when a signal is lost, and waits for the booked slot."""
import asyncio
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest
from temporalio.testing import WorkflowEnvironment
from temporalio.worker import Worker

import lab
import lab_workflows
import p3_db
from test_lab import book_body, until  # noqa: F401  (reused helpers)


@pytest.fixture(scope="module")
def temporal_env():
    with asyncio.Runner() as runner:
        env = runner.run(WorkflowEnvironment.start_time_skipping())
        yield runner, env
        runner.run(env.shutdown())


def start(env, booking_id, queue):
    return env.client.start_workflow("LabBookingWorkflow", {"booking_id": booking_id, "time_scale": 1},
                                     id="lab-" + booking_id, task_queue=queue)


def worker(env):
    queue = "r8-lab-" + uuid4().hex
    return queue, Worker(env.client, task_queue=queue, workflows=lab_workflows.WORKFLOWS, activities=lab_workflows.ACTIVITIES)


def test_row6_lost_confirmation_and_collection_signals_do_not_strand_the_workflow(temporal_env, isolated_db):
    async def scenario(env):
        bid, token = p3_db.create_booking("inst-a", lab.validate_booking(book_body(), "inst-a"))
        queue, w = worker(env)
        async with w:
            handle = await start(env, bid, queue)
            p3_db.lab_reply(token, "confirm")                      # committed in SQLite; the signal is LOST
            await env.sleep(timedelta(minutes=11))
            assert (await until(handle, lambda s: s["state"] == "confirmed"))["noReply"] is False
            due = (await env.get_current_time()) + timedelta(hours=2)
            p3_db.lab_event(bid, "collected", due.isoformat())     # collection also committed; signal LOST again
            await env.sleep(timedelta(minutes=11))
            await until(handle, lambda s: s["state"] == "collected")
            await env.sleep(timedelta(hours=2))
            assert p3_db.get_booking(bid)["state"] == "report_due"
            await env.sleep(timedelta(hours=6, minutes=5))
            assert p3_db.get_booking(bid)["state"] == "report_chase_due", "the chase timers started"
            await handle.terminate("test cleanup")
    temporal_env[0].run(scenario(temporal_env[1]))


def test_row6_a_lost_sample_rejection_ends_the_workflow(temporal_env, isolated_db):
    async def scenario(env):
        bid, token = p3_db.create_booking("inst-a", lab.validate_booking(book_body(), "inst-a"))
        queue, w = worker(env)
        async with w:
            handle = await start(env, bid, queue)
            p3_db.lab_reply(token, "confirm")
            await env.sleep(timedelta(minutes=11))
            await until(handle, lambda s: s["state"] == "confirmed")
            p3_db.lab_event(bid, "sample_rejected")                 # signal lost
            await env.sleep(timedelta(minutes=11))
            assert (await handle.result())["state"] == "rejected"
    temporal_env[0].run(scenario(temporal_env[1]))


def test_row7_a_booking_eight_days_out_is_still_watched_on_the_booked_day(temporal_env, isolated_db):
    async def scenario(env):
        now = await env.get_current_time()
        slot = (now + timedelta(days=8)).astimezone(timezone(timedelta(hours=5, minutes=30))).replace(microsecond=0)
        bid, token = p3_db.create_booking("inst-a", lab.validate_booking(book_body(preferredSlot=slot.isoformat()), "inst-a"))
        queue, w = worker(env)
        async with w:
            handle = await start(env, bid, queue)
            p3_db.lab_reply(token, "confirm")
            await env.sleep(timedelta(days=8, hours=1))             # past the old 7-day idle limit and past the slot
            snap = await handle.query("snapshot")
            assert snap["state"] == "confirmed", "the workflow must still be watching on the booked day"
            due = (await env.get_current_time()) + timedelta(hours=1)
            p3_db.lab_event(bid, "collected", due.isoformat())
            await env.sleep(timedelta(minutes=11))
            await until(handle, lambda s: s["state"] == "collected")
            await handle.terminate("test cleanup")
    temporal_env[0].run(scenario(temporal_env[1]))


def test_row7_an_abandoned_booking_is_closed_and_its_reply_link_stops_working(temporal_env, isolated_db):
    async def scenario(env):
        bid, token = p3_db.create_booking("inst-a", lab.validate_booking(book_body(), "inst-a"))
        queue, w = worker(env)
        async with w:
            handle = await start(env, bid, queue)
            await env.sleep(timedelta(days=8))                       # nobody ever answers
            assert (await handle.result())["state"] == "expired"
            assert p3_db.get_booking(bid)["state"] == "expired"
            with pytest.raises(p3_db.ReplyError):
                p3_db.lab_reply(token, "confirm")                    # the link no longer works
            with pytest.raises(p3_db.ReplyError):
                p3_db.lab_event(bid, "confirmed")                    # nor the judge button
    temporal_env[0].run(scenario(temporal_env[1]))
