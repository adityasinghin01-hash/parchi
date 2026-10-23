"""LabBookingWorkflow: timers for a lab booking.

The API applies every lab reply / judge event to SQLite atomically, then signals
`lab_event` here so this workflow can mirror the state and own the clock:
 - no lab reply within 30 min -> noReply
 - collected -> report_due at reportDueAt -> report_chase_due at reportDueAt + 6 h
Times are scaled by `time_scale` (so a demo can run fast); tests use time skipping.
"""
import asyncio
from datetime import datetime, timedelta
from typing import Any

from temporalio import activity, workflow
from temporalio.common import RetryPolicy

with workflow.unsafe.imports_passed_through():
    import p3_db

RETRY = RetryPolicy(maximum_attempts=5)
TIMEOUT = timedelta(seconds=30)
NO_REPLY_MINUTES = 30
CHASE_MINUTES = 6 * 60
# Give up watching a booking that makes no progress (workflows must not live forever).
IDLE_MINUTES = 7 * 24 * 60
FINAL = ("done", "rejected")


@activity.defn
async def lab_mark_no_reply(booking_id: str) -> bool:
    return await asyncio.to_thread(p3_db.lab_mark_no_reply, booking_id)


@activity.defn
async def lab_time_state(booking_id: str, new_state: str, from_states: list[str]) -> str | None:
    return await asyncio.to_thread(p3_db.lab_time_state, booking_id, new_state, from_states)


@workflow.defn
class LabBookingWorkflow:
    def __init__(self) -> None:
        self.inbox: list[tuple[str, str | None]] = []
        self.booking_id = ""
        self.scale: float = 1
        self.state = "requested"
        self.no_reply = False
        self.report_due_at: str | None = None
        self.due_wake: datetime | None = None
        self.chase_wake: datetime | None = None
        self.idle_until: datetime | None = None

    @workflow.signal(name="lab_event")
    def lab_event(self, kind: str, report_due_at: str | None = None) -> None:
        self.inbox.append((kind, report_due_at))

    @workflow.query(name="snapshot")
    def snapshot(self) -> dict[str, Any]:
        return {"bookingID": self.booking_id, "state": self.state, "noReply": self.no_reply,
                "reportDueAt": self.report_due_at}

    def minutes(self, value: float) -> timedelta:
        return timedelta(minutes=value * self.scale)

    def apply_inbox(self) -> None:
        """Mirror events SQLite already accepted. Pure state, no activities."""
        while self.inbox:
            kind, due = self.inbox.pop(0)
            if kind == "confirmed" and self.state == "requested":
                self.state, self.no_reply = "confirmed", False
                self.idle_until = workflow.now() + self.minutes(IDLE_MINUTES)
            elif kind == "rejected" and self.state == "requested":
                self.state, self.no_reply = "rejected", False
            elif kind == "sample_rejected" and self.state in ("confirmed", "collected"):
                self.state = "rejected"
            elif kind == "collected" and self.state == "confirmed" and due:
                self.state, self.report_due_at = "collected", due
                now = workflow.now()
                wait = max(0.0, (datetime.fromisoformat(due) - now).total_seconds()) * self.scale
                self.due_wake = now + timedelta(seconds=wait)
                self.chase_wake = self.due_wake + self.minutes(CHASE_MINUTES)
            elif kind == "report_ready" and self.state in ("collected", "report_due",
                                                           "report_chase_due"):
                self.state = "done"
            # phlebotomist_late only changes the note in SQLite; nothing to mirror.

    @workflow.run
    async def run(self, data: dict[str, Any]) -> dict[str, Any]:
        self.booking_id = data["booking_id"]
        self.scale = data.get("time_scale") or 1
        # Phase 1: wait for the lab's answer; at 30 min flag noReply but keep listening.
        deadline = workflow.now() + self.minutes(NO_REPLY_MINUTES)
        while self.state == "requested":
            self.apply_inbox()
            if self.state != "requested":
                break
            remaining = (deadline - workflow.now()).total_seconds()
            if remaining <= 0:
                if self.no_reply:
                    return self.snapshot()  # the lab never answered; stop watching
                await workflow.execute_activity(
                    lab_mark_no_reply, args=[self.booking_id],
                    start_to_close_timeout=TIMEOUT, retry_policy=RETRY)
                self.no_reply = True
                deadline = workflow.now() + self.minutes(IDLE_MINUTES)
                continue
            try:
                await workflow.wait_condition(lambda: bool(self.inbox), timeout=remaining)
            except asyncio.TimeoutError:
                pass
        # Phase 2: confirmed -> collected -> report due -> chase.
        while self.state not in FINAL:
            self.apply_inbox()
            if self.state in FINAL:
                break
            now = workflow.now()
            target = {"collected": self.due_wake, "report_due": self.chase_wake}.get(
                self.state, self.idle_until)
            if target is not None and now >= target:
                if self.state == "collected":
                    stored = await self.move("report_due", ["collected"])
                elif self.state == "report_due":
                    stored = await self.move("report_chase_due", ["report_due"])
                else:
                    break  # idle for a week: stop watching
                self.state = stored or self.state
                if self.state == "report_chase_due":
                    self.idle_until = workflow.now() + self.minutes(IDLE_MINUTES)
                continue
            timeout = None if target is None else (target - now).total_seconds()
            try:
                await workflow.wait_condition(lambda: bool(self.inbox), timeout=timeout)
            except asyncio.TimeoutError:
                pass
        return self.snapshot()

    async def move(self, new_state: str, from_states: list[str]) -> str | None:
        return await workflow.execute_activity(
            lab_time_state, args=[self.booking_id, new_state, from_states],
            start_to_close_timeout=TIMEOUT, retry_policy=RETRY)


WORKFLOWS = [LabBookingWorkflow]
ACTIVITIES = [lab_mark_no_reply, lab_time_state]
