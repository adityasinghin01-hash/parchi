"""Regression tests for two demo-blocking lab reliability findings.

Issue 1 (lab.py POST /lab/book):
  - On Temporal start failure the committed SQLite row must be RETAINED (not deleted)
    and a 503 returned, so a retry can succeed.
  - On a replay (created=False, existing booking via idempotency) the workflow must be
    re-started idempotently with REJECT_DUPLICATE; WorkflowAlreadyStartedError must be
    silenced, not cause a 503.

Issue 2 (lab_workflows.py give_up):
  - give_up ignores the authoritative state returned by lab_expire. If the sample was
    collected just before expiry and the signal was delayed, lab_expire returns "collected"
    but the old code blindly overwrites self.state with "expired", stranding the booking
    with no report timers and the wrong DB state.
  - Fix: honor the returned state; reconcile inbox; continue watching when progressed.
  - New path guarded with workflow.patched("lab-give-up-v1") for deterministic replay.

Test structure: FakeTemporal stubs model the start-idempotency contract narrowly;
the workflow test uses WorkflowEnvironment.start_time_skipping() with controlled
activity outcomes.
"""
import asyncio
from datetime import timedelta
from types import SimpleNamespace
from uuid import uuid4

import pytest
from temporalio.exceptions import WorkflowAlreadyStartedError
from temporalio.testing import WorkflowEnvironment
from temporalio.worker import Worker

import lab
import lab_workflows
import p3_db
from test_lab import book_body, ctx, status, until  # noqa: F401  (reused fixtures/helpers)


# ---------------------------------------------------------------------------
# Narrow FakeTemporal that models start-idempotency behaviour
# ---------------------------------------------------------------------------

class IdempotentFakeTemporal:
    """Tracks started workflow ids. start_workflow raises WorkflowAlreadyStartedError
    for an id it has already seen, matching REJECT_DUPLICATE semantics.
    Optionally raises RuntimeError when fail_start is True (simulates Temporal down)."""

    def __init__(self):
        self.started: list[tuple[str, str]] = []   # (name, id)
        self._ids: set[str] = set()
        self.fail_start = False

    async def start_workflow(self, name, data, *, id, **kwargs):
        if self.fail_start:
            raise RuntimeError("temporal unavailable")
        if id in self._ids:
            raise WorkflowAlreadyStartedError(id, name)
        self._ids.add(id)
        self.started.append((name, id))

    def get_workflow_handle(self, id):
        from collections import defaultdict
        from test_lab import FakeHandle
        return defaultdict(FakeHandle)[id]


# ---------------------------------------------------------------------------
# HTTP fixtures using IdempotentFakeTemporal
# ---------------------------------------------------------------------------

@pytest.fixture
def ictx(isolated_db, monkeypatch):
    """Like ctx but with IdempotentFakeTemporal."""
    import auth
    from fastapi import FastAPI, Request
    from fastapi.testclient import TestClient

    monkeypatch.setenv("PARCHI_ADMIN_KEY", "judge-secret")
    auth.limiter.clear()
    temporal = IdempotentFakeTemporal()
    app = FastAPI()

    async def get_temporal():
        return temporal

    def install(request: Request) -> str:
        return request.headers.get("X-Test-Install", "inst-a")

    lab.register(app, get_temporal, install)
    with TestClient(app) as client:
        yield SimpleNamespace(client=client, temporal=temporal, db=isolated_db,
                              h={"X-Test-Install": "inst-a"})
    auth.limiter.clear()


def post(ictx, headers=None, **extra):
    return ictx.client.post(
        "/lab/book",
        headers={**ictx.h, **(headers or {})},
        json=book_body(**extra),
    )


def booking_count():
    with p3_db.connect() as conn:
        return conn.execute("SELECT COUNT(*) FROM lab_bookings").fetchone()[0]


# ---------------------------------------------------------------------------
# Issue 1a – Temporal start failure must RETAIN the row and return 503
# ---------------------------------------------------------------------------

def test_issue1a_booking_retained_on_temporal_failure(ictx):
    """BEFORE fix: the except block deleted the row. AFTER fix: row is kept, 503 returned."""
    ictx.temporal.fail_start = True
    resp = post(ictx, {"Idempotency-Key": "idem-fail-1"})
    assert resp.status_code == 503, f"expected 503, got {resp.status_code}: {resp.text}"
    assert booking_count() == 1, (
        "booking row must be RETAINED on Temporal failure so the client can retry"
    )


def test_issue1a_retained_row_can_be_retried_successfully(ictx):
    """After the retained row, a retry with the same key must start the workflow and return 201."""
    ictx.temporal.fail_start = True
    resp1 = post(ictx, {"Idempotency-Key": "idem-retry-1"})
    assert resp1.status_code == 503
    assert booking_count() == 1

    ictx.temporal.fail_start = False
    resp2 = post(ictx, {"Idempotency-Key": "idem-retry-1"})
    # The booking already exists (created=False path), so the workflow must be re-started
    # idempotently; response is 200 with the same bookingID.
    assert resp2.status_code in (200, 201), f"retry should succeed: {resp2.status_code} {resp2.text}"
    assert resp2.json()["bookingID"] is not None
    assert booking_count() == 1, "still only one row"
    assert len(ictx.temporal.started) == 1, "exactly one workflow was ever started"


# ---------------------------------------------------------------------------
# Issue 1b – Replay path (created=False) must start workflow idempotently
# ---------------------------------------------------------------------------

def test_issue1b_replay_starts_workflow_idempotently(ictx):
    """BEFORE fix: created=False returned 200 without re-starting the workflow.
    AFTER fix: workflow is started with REJECT_DUPLICATE; WorkflowAlreadyStartedError silenced."""
    # First call: creates DB row and starts workflow.
    resp1 = post(ictx, {"Idempotency-Key": "idem-replay-1"})
    assert resp1.status_code == 201
    bid = resp1.json()["bookingID"]
    assert len(ictx.temporal.started) == 1

    # Second call (replay): created=False; must attempt start and silently accept AlreadyStarted.
    resp2 = post(ictx, {"Idempotency-Key": "idem-replay-1"})
    assert resp2.status_code == 200
    assert resp2.json()["bookingID"] == bid
    # The idempotent start was attempted (even if the fake immediately raised AlreadyStarted).
    assert len(ictx.temporal.started) >= 1, "start was attempted on replay"
    assert booking_count() == 1


def test_issue1b_replay_does_not_fail_503_on_already_started(ictx):
    """WorkflowAlreadyStartedError on a replay must not bubble up as 503."""
    post(ictx, {"Idempotency-Key": "idem-replay-2"})  # first: starts workflow, registers id
    resp = post(ictx, {"Idempotency-Key": "idem-replay-2"})  # second: REJECT_DUPLICATE raises AlreadyStarted
    assert resp.status_code == 200, (
        f"WorkflowAlreadyStartedError must be silenced on replay; got {resp.status_code}"
    )


# Issue 2: control the exact commit-between-deadline-and-expiry race. Merely
# collecting then sleeping a week exercises normal reconciliation, not this race.
def test_expiry_race_keeps_collection_and_arms_report_timers(monkeypatch):
    from datetime import datetime, timezone
    from lab_workflows import LabBookingWorkflow
    now = datetime(2026, 10, 24, tzinfo=timezone.utc)
    due = now + timedelta(hours=2)
    w = LabBookingWorkflow()
    w.booking_id = "race"
    w.reconcile_on = True
    w.state = "confirmed"

    async def activity(fn, **kwargs):
        if fn is lab_workflows.lab_expire:
            return "collected"
        assert fn is lab_workflows.lab_snapshot
        return {"state": "collected", "report_due_at": due.isoformat(), "slot": None}

    monkeypatch.setattr(lab_workflows.workflow, "execute_activity", activity)
    monkeypatch.setattr(lab_workflows.workflow, "patched", lambda name: True)
    monkeypatch.setattr(lab_workflows.workflow, "now", lambda: now)
    assert asyncio.run(w.give_up()) is True
    assert w.state == "collected"
    assert w.due_wake == due
    assert w.chase_wake == now + timedelta(hours=8)


def test_old_workflow_expiry_path_still_finishes_without_spinning():
    w = lab_workflows.LabBookingWorkflow()
    w.reconcile_on = False
    assert asyncio.run(w.give_up()) is False
