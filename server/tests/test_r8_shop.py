"""Codex review R8 row 8: closing an ask must never close (and kill the reply links of) a round newer than the one being watched."""
import asyncio
from datetime import timedelta
from uuid import uuid4

import pytest
from temporalio.testing import WorkflowEnvironment
from temporalio.worker import Worker

import p3_db
import shop
import shop_workflows
from test_shop import ask_body, READY, reply_body  # noqa: F401  (reused helpers)


@pytest.fixture(scope="module")
def temporal_env():
    with asyncio.Runner() as runner:
        env = runner.run(WorkflowEnvironment.start_time_skipping())
        yield runner, env
        runner.run(env.shutdown())


def test_close_ask_round_unit(isolated_db):
    body = shop.validate_ask(ask_body(4, groupSize=3, waitMinutes=10))
    ask_id, _ = p3_db.create_ask("inst-a", body)
    p3_db.open_next(ask_id, "inst-a")                                  # round 2 is open, links are live
    assert p3_db.close_ask_round(ask_id, 1) == {"winner": None, "round": 2, "closed": False}
    assert p3_db.ask_status(ask_id)["state"] == "waiting"
    assert p3_db.close_ask_round(ask_id, 2)["closed"] is True          # the round actually being watched closes
    assert p3_db.ask_status(ask_id)["state"] == "closed"


def test_workflow_keeps_watching_a_newer_round_it_was_not_told_about(temporal_env, isolated_db):
    async def scenario(env):
        body = shop.validate_ask(ask_body(4, groupSize=3, waitMinutes=10))
        ask_id, _ = p3_db.create_ask("inst-a", body)
        ids = [s["shopID"] for s in body["shops"]]
        queue = "r8-shop-" + uuid4().hex
        async with Worker(env.client, task_queue=queue, workflows=shop_workflows.WORKFLOWS, activities=shop_workflows.ACTIVITIES):
            handle = await env.client.start_workflow(
                "ShopAskWorkflow", {"ask_id": ask_id, "wait_minutes": 10, "time_scale": 1, "groups": p3_db.chunks(ids, 3)},
                id="shop-" + ask_id, task_queue=queue)
            await env.sleep(timedelta(minutes=11))                     # round 1 timed out, the workflow waits for the user's tap
            round_no, links = p3_db.open_next(ask_id, "inst-a")        # the API opens round 2 ... and its signal is LOST
            assert round_no == 2
            await env.sleep(timedelta(minutes=62))                     # the 60-minute wait ends: the old code closed the ask here
            assert p3_db.ask_status(ask_id)["state"] == "waiting", "round 2 must stay open"
            reply = p3_db.submit_reply(token=links[0]["token"], items=reply_body()["items"], ready_by=READY)   # its link still works
            await handle.signal("shop_reply", args=[reply["shopID"]])
            assert (await handle.result())["winnerShopID"] == reply["shopID"]
    temporal_env[0].run(scenario(temporal_env[1]))
