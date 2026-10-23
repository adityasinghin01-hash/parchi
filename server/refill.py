"""A6 refill autopilot: when will the medicines run out, and a durable reminder 3 days before.

Rules (kept simple on purpose):
- doses are whole-dose units (tablets); a partial pack counts only full days: 15 tablets at 2/day = 7 days.
- the start date is the first day a dose is taken; today's doses are not counted as taken yet.
- runsOutOn = startDate + supply days (first day with no medicine); refillDueAt = runsOutOn - 3 days, 09:00 IST.
- several items: the earliest runs-out date wins.
"""
import asyncio
import os
import re
from datetime import date, datetime, time, timedelta, timezone
from fractions import Fraction
from math import floor
from typing import Any, Callable
from uuid import uuid4

from temporalio import workflow
from temporalio.service import RPCError, RPCStatusCode

with workflow.unsafe.imports_passed_through():
    from fastapi import APIRouter, Body, Depends, FastAPI, HTTPException

IST = timezone(timedelta(hours=5, minutes=30))
LEAD_DAYS = 3
SCHEDULE = re.compile(r"\d+(\.\d+)?(-\d+(\.\d+)?){1,3}")
REFILL_ID = re.compile(r"[0-9a-f]{32}")


# ---- pure functions ----

def doses_per_day(value: Any) -> Fraction:
    """Number (2, 0.5) or an Indian schedule string: '1-0-1' = 2/day, '0-0-1' = 1/day."""
    if type(value) is bool:
        raise ValueError("invalid dosesPerDay")
    if isinstance(value, str):
        text = value.strip()
        if not SCHEDULE.fullmatch(text):
            raise ValueError("invalid dosesPerDay")
        result = sum(Fraction(part) for part in text.split("-"))
    elif isinstance(value, (int, float)):
        result = Fraction(str(value))
    else:
        raise ValueError("invalid dosesPerDay")
    if result <= 0 or result > 24:
        raise ValueError("dosesPerDay must be between 0 and 24")
    return result


def _quantity(value: Any) -> Fraction:
    if type(value) is bool or not isinstance(value, (int, float)) or not 0 <= value <= 100000:
        raise ValueError("invalid quantity")
    return Fraction(str(value))


def supply_days(quantity: Any, per_day: Any) -> int:
    return floor(_quantity(quantity) / doses_per_day(per_day))


def days_left(quantity: Any, per_day: Any, started: date, today: date) -> int:
    """Full days of medicine left, counting today. Never negative."""
    elapsed = max(0, (today - started).days)
    return max(0, supply_days(quantity, per_day) - elapsed)


def due_at(runs_out_on: date) -> datetime:
    return datetime.combine(runs_out_on - timedelta(days=LEAD_DAYS), time(9, 0), tzinfo=IST)


def plan_refill(items: Any, started: date, today: date) -> dict[str, Any]:
    if not isinstance(items, list) or not 0 < len(items) <= 40:
        raise ValueError("items must be a list of 1 to 40")
    rows = []
    for item in items:
        if not isinstance(item, dict) or not isinstance(item.get("name"), str) \
                or not 0 < len(item["name"]) <= 128:
            raise ValueError("invalid item name")
        supply = supply_days(item.get("quantity"), item.get("dosesPerDay"))
        rows.append({"name": item["name"],
                     "daysLeft": days_left(item["quantity"], item["dosesPerDay"], started, today),
                     "runsOutOn": (started + timedelta(days=supply)).isoformat()})
    first = min(date.fromisoformat(r["runsOutOn"]) for r in rows)
    return {"daysLeft": min(r["daysLeft"] for r in rows), "runsOutOn": first.isoformat(),
            "refillDueAt": due_at(first).isoformat(), "items": rows}


# ---- workflow ----

@workflow.defn
class RefillWorkflow:
    """waiting -> due (at refillDueAt) -> done | cancelled. done/cancel are accepted any time before the end."""

    def __init__(self) -> None:
        self.state = "waiting"
        self.refill_id = ""
        self.install_id = ""
        self.due_at = ""
        self.fired_at: str | None = None

    def finished(self) -> bool:
        return self.state in ("done", "cancelled")

    @workflow.signal(name="done")
    def done(self) -> None:
        if not self.finished():
            self.state = "done"

    @workflow.signal(name="cancel")
    def cancel(self) -> None:
        if not self.finished():
            self.state = "cancelled"

    @workflow.query(name="snapshot")
    def snapshot(self) -> dict[str, Any]:
        return {"refillID": self.refill_id, "installID": self.install_id, "state": self.state,
                "refillDueAt": self.due_at, "dueFiredAt": self.fired_at}

    @workflow.run
    async def run(self, data: dict[str, Any]) -> dict[str, Any]:
        self.refill_id, self.install_id = data["refill_id"], data["install_id"]
        self.due_at = data["due_at"]
        scale = data.get("time_scale") or 1  # input, not env: workflow code must stay deterministic
        # Same meaning as orders, shop and lab: waits are MULTIPLIED by the scale (0.01 = 100x faster).
        delay = (datetime.fromisoformat(self.due_at) - workflow.now()).total_seconds() * scale
        if delay > 0:
            try:
                await workflow.wait_condition(self.finished, timeout=timedelta(seconds=delay))
            except asyncio.TimeoutError:
                pass
        if self.state == "waiting":
            self.state = "due"
            self.fired_at = workflow.now().isoformat()
        await workflow.wait_condition(self.finished)
        return self.snapshot()


WORKFLOWS = [RefillWorkflow]  # add to the worker's workflows=[...] list
ACTIVITIES: list = []


# ---- API ----

def workflow_id(refill_id: str) -> str:
    return "refill-" + refill_id


async def cancel_watches(temporal: Any, install_id: str | None) -> int:
    """'Delete everything': terminate this install's running refill watches (None = all, for the demo reset).

    Refill watches have no SQLite row, so they are found by listing running RefillWorkflow executions and
    reading the install id from each one's snapshot. Medicine names were never sent to Temporal.
    """
    stopped = 0
    try:
        async for item in temporal.list_workflows(
                'WorkflowType="RefillWorkflow" AND ExecutionStatus="Running"'):
            handle = temporal.get_workflow_handle(item.id)
            try:
                if install_id is not None and (await handle.query("snapshot")).get("installID") != install_id:
                    continue
                await handle.terminate(reason="reset")
                stopped += 1
            except RPCError as error:  # finished or gone in the meantime is fine
                if error.status not in (RPCStatusCode.NOT_FOUND, RPCStatusCode.FAILED_PRECONDITION):
                    raise
    except RPCError:
        raise HTTPException(503, "temporal unavailable")
    return stopped


def register(app: FastAPI, get_temporal: Callable, get_install_id: Callable) -> None:
    router = APIRouter()

    @router.post("/refill/watch", status_code=201)
    async def watch(body: dict[str, Any] = Body(...), install_id: str = Depends(get_install_id),
                    temporal: Any = Depends(get_temporal)) -> dict[str, Any]:
        try:
            raw = body.get("startDate")
            if not isinstance(raw, str):
                raise ValueError("startDate must be YYYY-MM-DD")
            started = date.fromisoformat(raw)
            result = plan_refill(body.get("items"), started, datetime.now(IST).date())
        except ValueError as error:
            raise HTTPException(422, str(error))
        refill_id = uuid4().hex
        data = {"refill_id": refill_id, "install_id": install_id, "due_at": result["refillDueAt"],
                "time_scale": float(os.environ.get("PARCHI_TIME_SCALE", "1"))}
        try:  # medicine names stay out of Temporal: only the due time goes in
            await temporal.start_workflow("RefillWorkflow", data, id=workflow_id(refill_id),
                                          task_queue=os.environ.get("PARCHI_TASK_QUEUE", "parchi"))
        except RPCError:
            raise HTTPException(503, "temporal unavailable")
        return {"refillID": refill_id, **result}

    async def owned(refill_id: str, install_id: str, temporal: Any):
        if not REFILL_ID.fullmatch(refill_id):
            raise HTTPException(404, "refill not found")
        handle = temporal.get_workflow_handle(workflow_id(refill_id))
        try:
            snap = await handle.query("snapshot")
        except RPCError as error:
            raise HTTPException(404 if error.status == RPCStatusCode.NOT_FOUND else 503, "refill unavailable")
        if snap.get("installID") != install_id:
            raise HTTPException(404, "refill not found")
        return handle, snap

    @router.get("/refill/{refill_id}/status")
    async def status(refill_id: str, install_id: str = Depends(get_install_id),
                     temporal: Any = Depends(get_temporal)) -> dict[str, Any]:
        _, snap = await owned(refill_id, install_id, temporal)
        return {k: v for k, v in snap.items() if k != "installID"}

    def signal_route(action: str) -> None:
        async def endpoint(refill_id: str, install_id: str = Depends(get_install_id),
                           temporal: Any = Depends(get_temporal)) -> dict[str, bool]:
            handle, snap = await owned(refill_id, install_id, temporal)
            if snap["state"] in ("done", "cancelled"):
                raise HTTPException(409, "refill already " + snap["state"])
            try:
                await handle.signal(action)
            except RPCError:  # finished between the query and the signal
                raise HTTPException(409, "refill already finished")
            return {"ok": True}
        router.add_api_route(f"/refill/{{refill_id}}/{action}", endpoint, methods=["POST"],
                             name="refill_" + action)

    signal_route("done")
    signal_route("cancel")
    app.include_router(router)
