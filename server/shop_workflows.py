"""ShopAskWorkflow: the no-reply timer for a shop ask.

Replies are stored (atomically, first complete reply wins) by the API in SQLite and then
signalled here; the workflow owns the clock: no complete reply within waitMinutes ->
noReply + nextGroup. Deterministic: only workflow.now()/timers, SQLite via activities.
"""
import asyncio
from datetime import timedelta
from typing import Any

from temporalio import activity, workflow
from temporalio.common import RetryPolicy

with workflow.unsafe.imports_passed_through():
    import p3_db

RETRY = RetryPolicy(maximum_attempts=5)
TIMEOUT = timedelta(seconds=30)
# After the last wait expires and the user has a next group to open, how long the ask
# stays open for the user's tap (or a late reply) before it is closed.
NEXT_WAIT_MINUTES = 60


@activity.defn
async def shop_mark_no_reply(ask_id: str, round_no: int) -> bool:
    return await asyncio.to_thread(p3_db.shop_mark_no_reply, ask_id, round_no)


@activity.defn
async def shop_close(ask_id: str) -> str | None:
    return await asyncio.to_thread(p3_db.close_ask, ask_id)


@activity.defn
async def shop_close_round(ask_id: str, round_no: int) -> dict[str, Any]:
    return await asyncio.to_thread(p3_db.close_ask_round, ask_id, round_no)


@workflow.defn
class ShopAskWorkflow:
    def __init__(self) -> None:
        self.ask_id = ""
        self.round = 1
        self.state = "waiting"
        self.no_reply = False
        self.next_group: list[str] = []
        self.winner: str | None = None

    @workflow.signal(name="shop_reply")
    def shop_reply(self, shop_id: str) -> None:
        # The API only signals after SQLite accepted the reply, so the first one is final.
        if self.winner is None and self.state == "waiting":
            self.winner = shop_id

    @workflow.signal(name="next_round")
    def next_round(self, round_no: int) -> None:
        if type(round_no) is int and round_no > self.round and self.state == "waiting":
            self.round = round_no
            self.no_reply = False
            self.next_group = []

    @workflow.query(name="snapshot")
    def snapshot(self) -> dict[str, Any]:
        return {"askID": self.ask_id, "state": self.state, "round": self.round,
                "noReply": self.no_reply, "nextGroup": self.next_group,
                "winnerShopID": self.winner}

    @workflow.run
    async def run(self, data: dict[str, Any]) -> dict[str, Any]:
        self.ask_id = data["ask_id"]
        groups: list[list[str]] = data["groups"]
        scale = data.get("time_scale") or 1
        wait = timedelta(minutes=data["wait_minutes"] * scale)
        grace = timedelta(minutes=NEXT_WAIT_MINUTES * scale)
        close_by_round = workflow.patched("shop-close-round-v1")  # R8 row 8: never close a round newer than the one being watched
        while True:
            current = self.round
            changed = lambda: self.winner is not None or self.round != current  # noqa: E731
            try:
                await workflow.wait_condition(changed, timeout=wait)
            except asyncio.TimeoutError:
                pass
            if self.winner is not None:
                break
            if self.round != current:
                continue  # the user opened the next group early: restart the clock
            await workflow.execute_activity(
                shop_mark_no_reply, args=[self.ask_id, current],
                start_to_close_timeout=TIMEOUT, retry_policy=RETRY)
            self.no_reply = True
            self.next_group = groups[current] if current < len(groups) else []
            if self.next_group:
                try:
                    await workflow.wait_condition(changed, timeout=grace)
                except asyncio.TimeoutError:
                    pass
                if self.winner is not None:
                    break
                if self.round != current:
                    continue
            # Nothing left to open (or the user never tapped): close, unless a reply
            # landed in SQLite just before and its signal is still on the way.
            if close_by_round:
                result = await workflow.execute_activity(
                    shop_close_round, args=[self.ask_id, current], start_to_close_timeout=TIMEOUT, retry_policy=RETRY)
                self.winner = result["winner"]
                if self.winner is None and not result["closed"]:
                    # The user opened a newer round while this one was timing out (its signal may still be on the way):
                    # keep watching the newer round, its clock starts now.
                    if result["round"] > self.round:
                        self.round, self.no_reply, self.next_group = result["round"], False, []
                    continue
            else:
                self.winner = await workflow.execute_activity(
                    shop_close, args=[self.ask_id], start_to_close_timeout=TIMEOUT, retry_policy=RETRY)
            if self.winner is None:
                self.state = "closed"
            break
        if self.winner is not None:
            self.state = "replied"
            self.no_reply = False
            self.next_group = []
        return self.snapshot()


WORKFLOWS = [ShopAskWorkflow]
ACTIVITIES = [shop_mark_no_reply, shop_close, shop_close_round]
