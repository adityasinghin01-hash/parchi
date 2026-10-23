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
# The signals are hints; SQLite is the truth. Every RECONCILE_MINUTES the workflow re-reads the stored state, so one lost signal
# (API crash or Temporal outage between the commit and the signal) cannot leave it behind. (Codex R8 row 6)
RECONCILE_MINUTES = 10
FINAL = ("done", "rejected", "expired")


@activity.defn
async def lab_mark_no_reply(booking_id: str) -> bool:
    return await asyncio.to_thread(p3_db.lab_mark_no_reply, booking_id)


@activity.defn
async def lab_time_state(booking_id: str, new_state: str, from_states: list[str]) -> str | None:
    return await asyncio.to_thread(p3_db.lab_time_state, booking_id, new_state, from_states)


@activity.defn
async def lab_snapshot(booking_id: str) -> dict[str, Any] | None:
    row = await asyncio.to_thread(p3_db.get_booking, booking_id)
    return None if row is None else {"state": row["state"], "report_due_at": row["report_due_at"], "slot": row["slot"]}


@activity.defn
async def lab_expire(booking_id: str) -> str | None:
    return await asyncio.to_thread(p3_db.lab_expire, booking_id)


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
        self.reconcile_on = False
        self.next_reconcile: datetime | None = None

    @workflow.signal(name="lab_event")
    def lab_event(self, kind: str, report_due_at: str | None = None) -> None:
        self.inbox.append((kind, report_due_at))

    @workflow.query(name="snapshot")
    def snapshot(self) -> dict[str, Any]:
        return {"bookingID": self.booking_id, "state": self.state, "noReply": self.no_reply,
                "reportDueAt": self.report_due_at}

    def minutes(self, value: float) -> timedelta:
        return timedelta(minutes=value * self.scale)

    async def reconcile(self) -> None:
        """Queue the events a lost signal would have delivered, derived from the state SQLite holds."""
        snap = await workflow.execute_activity(lab_snapshot, args=[self.booking_id],
                                               start_to_close_timeout=TIMEOUT, retry_policy=RETRY)
        if snap is None:
            return
        stored, due, now_state = snap["state"], snap["report_due_at"], self.state
        if stored == "expired":
            self.state = "expired"
        elif stored == "rejected" and now_state in ("requested", "confirmed", "collected"):
            self.inbox.append(("rejected" if now_state == "requested" else "sample_rejected", None))
        elif stored in ("confirmed", "collected", "report_due", "report_chase_due", "done"):
            if now_state == "requested":
                self.inbox.append(("confirmed", None))
            if stored in ("collected", "report_due", "report_chase_due", "done") and now_state in ("requested", "confirmed") and due:
                self.inbox.append(("collected", due))
            if stored == "done" and now_state != "done":
                self.inbox.append(("report_ready", None))
        if snap["slot"] and stored == "confirmed":
            # Wait until a week after the BOOKED slot, not a week after the confirmation (the slot can be days away).
            idle = datetime.fromisoformat(snap["slot"]) + self.minutes(IDLE_MINUTES)
            if self.idle_until is None or idle > self.idle_until:
                self.idle_until = idle

    async def maybe_reconcile(self) -> None:
        if self.reconcile_on and workflow.now() >= self.next_reconcile:  # type: ignore[operator]
            await self.reconcile()
            self.next_reconcile = workflow.now() + self.minutes(RECONCILE_MINUTES)

    def until_reconcile(self) -> float | None:
        if not self.reconcile_on:
            return None
        return max(0.0, (self.next_reconcile - workflow.now()).total_seconds())  # type: ignore[operator]

    async def give_up(self) -> bool:
        """Stop watching a booking that made no progress and close it.

        lab_expire returns the authoritative final state from SQLite:
          - None / "expired" → genuinely idle; the workflow is done.
          - anything else    → the booking progressed between the idle deadline and the
                               expire activity (e.g. sample collected just before expiry
                               with the signal delayed). Honor the real state, reconcile
                               the inbox from SQLite, and let the caller decide what to do.

        New behaviour is guarded by workflow.patched("lab-give-up-v1") for safe replay
        against old workflow histories that never saw this path.
        """
        if not self.reconcile_on:
            return False
        previous = self.state
        authoritative = await workflow.execute_activity(
            lab_expire, args=[self.booking_id],
            start_to_close_timeout=TIMEOUT, retry_policy=RETRY)
        if workflow.patched("lab-give-up-v1") and authoritative and authoritative != "expired":
            # The booking progressed (e.g. collected) just before we tried to expire it.
            # lab_expire will have left SQLite in the progressed state; reconcile so this
            # workflow mirrors it and continues with the appropriate timers.
            await self.reconcile()
            self.apply_inbox()
            return self.state != previous
        else:
            self.state = "expired"
            return False

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
        self.reconcile_on = workflow.patched("lab-reconcile-v1")
        self.next_reconcile = workflow.now() + self.minutes(RECONCILE_MINUTES)
        # Phase 1: wait for the lab's answer; at 30 min flag noReply but keep listening.
        deadline = workflow.now() + self.minutes(NO_REPLY_MINUTES)
        while self.state == "requested":
            self.apply_inbox()
            if self.state != "requested":
                break
            remaining = (deadline - workflow.now()).total_seconds()
            if remaining <= 0:
                if self.no_reply:
                    if not await self.give_up():
                        return self.snapshot()  # the lab never answered; stop watching
                    # give_up found the booking progressed (e.g. confirmed just before expiry);
                    # fall through so Phase 1 loop picks up the new state.
                    continue
                await workflow.execute_activity(
                    lab_mark_no_reply, args=[self.booking_id],
                    start_to_close_timeout=TIMEOUT, retry_policy=RETRY)
                self.no_reply = True
                deadline = workflow.now() + self.minutes(IDLE_MINUTES)
                continue
            wait = remaining if not self.reconcile_on else min(remaining, self.until_reconcile())  # type: ignore[type-var]
            try:
                await workflow.wait_condition(lambda: bool(self.inbox), timeout=wait)
            except asyncio.TimeoutError:
                pass
            await self.maybe_reconcile()
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
                    if await self.give_up():
                        # Booking progressed; continue watching in Phase 2.
                        continue
                    break  # idle for a week with no progress: stop watching
                self.state = stored or self.state
                if self.state == "report_chase_due":
                    self.idle_until = workflow.now() + self.minutes(IDLE_MINUTES)
                continue
            timeout = None if target is None else (target - now).total_seconds()
            if self.reconcile_on:
                timeout = self.until_reconcile() if timeout is None else min(timeout, self.until_reconcile())  # type: ignore[type-var]
            try:
                await workflow.wait_condition(lambda: bool(self.inbox), timeout=timeout)
            except asyncio.TimeoutError:
                pass
            await self.maybe_reconcile()
        return self.snapshot()

    async def move(self, new_state: str, from_states: list[str]) -> str | None:
        return await workflow.execute_activity(
            lab_time_state, args=[self.booking_id, new_state, from_states],
            start_to_close_timeout=TIMEOUT, retry_policy=RETRY)


WORKFLOWS = [LabBookingWorkflow]
ACTIVITIES = [lab_mark_no_reply, lab_time_state, lab_snapshot, lab_expire]
