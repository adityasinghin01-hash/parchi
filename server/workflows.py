import asyncio
from datetime import datetime, timedelta
from typing import Any

from temporalio import workflow
from temporalio.common import RetryPolicy

with workflow.unsafe.imports_passed_through():
    import hashlib
    import json

    import activities
    import contract

RETRY = RetryPolicy(maximum_attempts=5)
TIMEOUT = timedelta(seconds=30)
CONFIRM_MINUTES = 15
LATE_GRACE_MINUTES = 30
# Forward-only progress; anything else is a duplicate or out-of-order event.
RANK = {"placed": 0, "confirmed": 1, "shipped": 2, "delivered": 3}


@workflow.defn
class OrderWorkflow:
    def __init__(self) -> None:
        # Signals only append here; the main loop applies them one at a time, so a
        # signal can never interleave with a transition that is waiting on an activity.
        self.inbox: list[tuple[str, list[Any]]] = []
        self.ready = False
        self.gone = False
        self.seq = 0
        self.order_id = ""
        self.plan: dict[str, Any] = {}
        self.catalog: dict[str, dict[str, Any]] = {}
        self.cap: int | None = None
        self.scale: float = 1
        self.plan_version = 1
        self.state = "placed"
        self.sellers: dict[str, dict[str, Any]] = {}
        self.pending: dict[str, str] | None = None
        self.queue: list[dict[str, str]] = []
        self.proposal: dict[str, Any] | None = None
        self.nothing_available = False
        self.needs_check: list[str] = []
        self.waiting_since: str | None = None
        # Items the user approved a plan without (nothing available / partial proposal): never silently dropped.
        self.unresolved: list[str] = []

    # ---- signals and query ----

    @workflow.signal(name="seller_event")
    def seller_event(self, seller_id: str, kind: str) -> None:
        self.inbox.append(("seller_event", [seller_id, kind]))

    @workflow.signal(name="proposal")
    def on_proposal(self, plan_version: int, proposal: dict[str, Any]) -> None:
        self.inbox.append(("proposal", [plan_version, proposal]))

    @workflow.signal(name="approve")
    def on_approve(self, plan_version: int) -> None:
        self.inbox.append(("approve", [plan_version]))

    @workflow.signal(name="reject")
    def on_reject(self, plan_version: int) -> None:
        self.inbox.append(("reject", [plan_version]))

    @workflow.query(name="snapshot")
    def snapshot(self) -> dict[str, Any]:
        return {
            "ready": self.ready, "orderID": self.order_id, "state": self.state,
            "planVersion": self.plan_version, "plan": self.plan,
            "sellers": [{"id": sid, "status": s["status"], "etaMinutes": s["etaMinutes"]}
                        for sid, s in self.sellers.items()],
            "pending": self.pending, "queue": self.queue, "proposal": self.proposal,
            "nothingAvailable": self.nothing_available, "needsCheck": self.needs_check,
            "waitingSince": self.waiting_since, "unresolvedItems": self.unresolved,
        }

    # ---- main loop ----

    @workflow.run
    async def run(self, data: dict[str, Any]) -> dict[str, Any]:
        self.order_id = data["order_id"]
        self.plan = data["plan"]
        self.catalog = {s["id"]: s for s in data["sellers"]}
        self.cap = data.get("auto_approve_cap_paise")
        self.scale = data.get("time_scale") or 1
        ids = list(dict.fromkeys(row["sellerID"] for row in self.plan["lines"]))
        # The only parallel mutations; the (order, seller, version) key makes retries safe.
        results = await asyncio.gather(*[self.place(sid, 1) for sid in ids])
        if any(r is None for r in results):
            self.gone = True
        for sid in ids:
            self.sellers[sid] = self.new_seller(sid)
            await self.audit("workflow", "placed", {"sellerID": sid})
        self.ready = True

        while not self.gone:
            while self.inbox and not self.gone:
                name, args = self.inbox.pop(0)
                await self.apply(name, args)
            await self.fire_deadlines()
            if self.inbox:
                continue
            if self.finished():
                self.state = "done"
                await self.audit("workflow", "done", {})
                break
            due = self.next_deadline()
            timeout = None if due is None else (due - workflow.now()).total_seconds()
            if timeout is not None and timeout <= 0:
                continue
            try:
                await workflow.wait_condition(lambda: bool(self.inbox), timeout=timeout)
            except asyncio.TimeoutError:
                pass
        return self.snapshot()

    def finished(self) -> bool:
        return (self.pending is None and not self.queue and all(
            s["status"] in ("delivered", "cancelled", "rerouted") for s in self.sellers.values()))

    # ---- helpers ----

    def minutes(self, value: int) -> timedelta:
        return timedelta(minutes=value * self.scale)

    def new_seller(self, sid: str) -> dict[str, Any]:
        eta = self.catalog[sid]["etaMinutes"]
        now = workflow.now()
        return {"status": "placed", "etaMinutes": eta,
                "confirm_due": now + self.minutes(CONFIRM_MINUTES),
                "late_due": now + self.minutes(eta + LATE_GRACE_MINUTES)}

    async def place(self, seller_id: str, version: int) -> dict[str, Any] | None:
        return await workflow.execute_activity(
            activities.place_order, args=[self.order_id, seller_id, version],
            start_to_close_timeout=TIMEOUT, retry_policy=RETRY)

    async def audit(self, actor: str, event: str, detail: dict[str, Any]) -> None:
        self.seq += 1
        await workflow.execute_activity(
            activities.audit, args=[self.order_id, actor, event, detail, self.plan_version, self.seq],
            start_to_close_timeout=TIMEOUT, retry_policy=RETRY)

    async def ignore(self, signal: str, reason: str, **detail: Any) -> None:
        await self.audit("workflow", "ignored_signal", {"signal": signal, "reason": reason, **detail})

    def next_deadline(self) -> datetime | None:
        dues = [s[key] for s in self.sellers.values() for key in ("confirm_due", "late_due") if s[key]]
        return min(dues) if dues else None

    async def fire_deadlines(self) -> None:
        for sid, s in list(self.sellers.items()):
            now = workflow.now()
            if s["confirm_due"] and now >= s["confirm_due"]:
                s["confirm_due"] = None
                # Unconfirmed is a prompt to check by hand, never a failure.
                if s["status"] == "placed" and sid not in self.needs_check:
                    self.needs_check.append(sid)
                    await self.audit("workflow", "unconfirmed", {"sellerID": sid})
            if s["late_due"] and now >= s["late_due"]:
                s["late_due"] = None
                if s["status"] in ("placed", "confirmed", "shipped"):
                    await self.fail(sid, "late")

    def set_pending(self, failure: dict[str, str]) -> None:
        self.pending = failure
        self.state = "needs_proposal"
        self.proposal = None
        self.nothing_available = False
        self.waiting_since = workflow.now().isoformat()

    def next_failure(self) -> None:
        self.pending = self.proposal = self.waiting_since = None
        self.nothing_available = False
        if self.queue:
            self.set_pending(self.queue.pop(0))
        else:
            self.state = "placed"

    # ---- transitions ----

    async def apply(self, name: str, args: list[Any]) -> None:
        if name == "seller_event":
            await self.on_seller_event(*args)
        elif name == "proposal":
            await self.on_proposal_signal(*args)
        else:
            await self.on_decision(name, args[0])

    async def on_seller_event(self, sid: Any, kind: Any) -> None:
        detail = {"sellerID": str(sid)[:64], "kind": str(kind)[:32]}
        s = self.sellers.get(sid) if isinstance(sid, str) else None
        if not isinstance(kind, str) or kind not in contract.EVENTS:
            return await self.ignore("seller_event", "unknown_kind", **detail)
        if s is None:
            return await self.ignore("seller_event", "unknown_seller", **detail)
        if s["status"] in contract.INACTIVE:
            return await self.ignore("seller_event", "inactive_seller", **detail)
        if s["status"] == "delivered":
            return await self.ignore("seller_event", "already_delivered", **detail)
        if kind in contract.FAILURES:
            return await self.fail(sid, kind)
        if RANK[kind] <= RANK[s["status"]]:
            return await self.ignore("seller_event", "out_of_order", **detail)
        s["status"] = kind
        if sid in self.needs_check:
            self.needs_check.remove(sid)
        if kind == "delivered":
            s["confirm_due"] = s["late_due"] = None
        await self.audit("seller", kind, {"sellerID": sid})

    async def fail(self, sid: str, kind: str) -> None:
        s = self.sellers[sid]
        s["status"], s["confirm_due"], s["late_due"] = "failed", None, None
        if sid in self.needs_check:
            self.needs_check.remove(sid)
        failure = {"sellerID": sid, "failure": kind}
        queued = self.pending is not None
        if queued:
            self.queue.append(failure)
        else:
            self.set_pending(failure)
        await self.audit("workflow", "failure", {**failure, "queued": queued})

    async def on_proposal_signal(self, version: Any, proposal: Any) -> None:
        if version != self.plan_version or type(version) is not int:
            return await self.ignore("proposal", "stale_version", planVersion=str(version)[:16])
        if self.state != "needs_proposal":
            return await self.ignore("proposal", "not_waiting_for_proposal")
        statuses = {sid: s["status"] for sid, s in self.sellers.items()}
        try:
            contract.validate_proposal(proposal, self.plan, list(self.catalog.values()),
                                       self.pending, statuses)
        except (ValueError, KeyError, TypeError, AttributeError) as error:
            return await self.ignore("proposal", "invalid_proposal", message=str(error)[:200])
        self.proposal = proposal
        self.nothing_available = not proposal["rerouted"]
        # Nothing-available always needs the user, whatever the cap says.
        auto = (not self.nothing_available and self.cap is not None
                and proposal["extraCost"] <= self.cap)
        await self.audit("phone", "proposal", {"extraCost": proposal["extraCost"],
                                               "nothingAvailable": self.nothing_available})
        if auto:
            await self.approve("auto-cap")
        else:
            self.state = "awaiting_approval"

    async def on_decision(self, name: str, version: Any) -> None:
        if version != self.plan_version or type(version) is not int:
            return await self.ignore(name, "stale_version", planVersion=str(version)[:16])
        if self.state != "awaiting_approval":
            return await self.ignore(name, "not_awaiting_approval")
        if name == "approve":
            await self.approve("user")
            return
        failed = self.pending["sellerID"]  # type: ignore[index]
        self.sellers[failed]["status"] = "cancelled"
        self.next_failure()
        await self.audit("user", "rejected", {"sellerID": failed})

    async def approve(self, approver: str) -> None:
        proposal, failed = self.proposal, self.pending["sellerID"]  # type: ignore[index]
        version = self.plan_version + 1
        digest = hashlib.sha256(json.dumps(proposal, sort_keys=True).encode()).hexdigest()
        await workflow.execute_activity(
            activities.store_approval, args=[self.order_id, version, approver, digest],
            start_to_close_timeout=TIMEOUT, retry_policy=RETRY)
        # Already-active replacement sellers are not placed twice.
        new_ids = [] if self.nothing_available else [
            sid for sid in dict.fromkeys(r["sellerID"] for r in proposal["rerouted"])  # type: ignore[index]
            if sid not in self.sellers]
        for sid in new_ids:  # sequential: one mutation at a time
            if await self.place(sid, version) is None:
                self.gone = True
                return
        # State changes only after every activity succeeded, so queries and later
        # signals see either the old version or the complete new one.
        self.plan_version = version
        if self.nothing_available:
            self.sellers[failed]["status"] = "cancelled"
        else:
            self.plan = proposal["newPlan"]  # type: ignore[index]
            self.sellers[failed]["status"] = "rerouted"
            for sid in new_ids:
                self.sellers[sid] = self.new_seller(sid)
        extra = proposal["extraCost"]  # type: ignore[index]
        for item in proposal["stillMissing"]:  # type: ignore[index]
            if item not in self.unresolved:
                self.unresolved.append(item)
        self.next_failure()
        await self.audit(approver, "approved", {"failedSellerID": failed, "newSellers": new_ids,
                                                "extraCost": extra, "proposalHash": digest,
                                                "unresolvedItems": list(self.unresolved)})
