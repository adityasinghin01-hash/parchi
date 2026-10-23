"""K30: "Delete everything" also removes the install's workflows from Temporal (stop them, then delete their histories).

Before this, reset deleted the SQLite rows and terminated orders and refill watches, but shop asks and lab bookings kept
running and every workflow's history stayed in Temporal for the namespace retention (24 h). Now, for the calling install:
  1. collect_ids(): find every workflow id BEFORE the rows go (orders, shop asks, lab bookings from their tables, plus the
     tombstones of orders this install already deleted in the last 48 h, plus refill watches found by their snapshot);
  2. wipe(): TERMINATE each (ignored if already finished), then DeleteWorkflowExecution (Temporal 1.32 dev server supports it).
Another install's workflows are never listed, so never touched. Only ids (random hex) are kept in Temporal anyway; no names.
"""
import asyncio
from typing import Any

from fastapi import HTTPException
from temporalio.api.common.v1 import WorkflowExecution
from temporalio.api.workflowservice.v1 import DeleteWorkflowExecutionRequest
from temporalio.service import RPCError, RPCStatusCode

import db
import p3_db

QUERY_WAIT = 10  # seconds per refill snapshot query
NOT_THERE = (RPCStatusCode.NOT_FOUND, RPCStatusCode.FAILED_PRECONDITION)
CANNOT_DELETE = (RPCStatusCode.UNIMPLEMENTED, RPCStatusCode.PERMISSION_DENIED)


def table_ids(install_id: str | None) -> list[str]:
    """Workflow ids of the install's orders (live and tombstoned), shop asks and lab bookings."""
    where, args = ("", ()) if install_id is None else (" WHERE install_id=?", (install_id,))
    ids: list[str] = []
    with p3_db.connect() as conn:  # p3_db.connect also makes sure the shop/lab tables exist
        ids += ["order-" + r[0] for r in conn.execute("SELECT order_id FROM orders" + where, args)]
        ids += ["order-" + r[0] for r in conn.execute("SELECT order_id FROM deleted_orders" + where, args)]
        ids += ["shop-" + r[0] for r in conn.execute("SELECT ask_id FROM shop_asks" + where, args)]
        ids += ["lab-" + r[0] for r in conn.execute("SELECT booking_id FROM lab_bookings" + where, args)]
    return ids


async def refill_ids(temporal: Any, install_id: str | None) -> list[str]:
    """Refill watches have no row: list every RefillWorkflow (running or closed) and read the install from its snapshot."""
    found: list[str] = []
    if install_id is None:
        async for item in temporal.list_workflows('WorkflowType="RefillWorkflow"'):
            found.append(item.id)
        return found
    gate = asyncio.Semaphore(8)

    async def mine(workflow_id: str) -> str | None:
        async with gate:
            try:
                snap = await asyncio.wait_for(temporal.get_workflow_handle(workflow_id).query("snapshot"), QUERY_WAIT)
            except RPCError as error:
                if error.status in NOT_THERE:
                    return None
                raise
            return workflow_id if snap.get("installID") == install_id else None

    try:
        listed = [item.id async for item in temporal.list_workflows('WorkflowType="RefillWorkflow"')]
        found = [i for i in await asyncio.gather(*(mine(w) for w in listed)) if i]
    except (RPCError, asyncio.TimeoutError):
        raise HTTPException(503, "temporal unavailable")
    return found


async def collect_ids(temporal: Any, install_id: str | None) -> list[str]:
    """Call this BEFORE the SQLite rows are deleted. None = every install (the admin's demo reset)."""
    return list(dict.fromkeys(table_ids(install_id) + await refill_ids(temporal, install_id)))


async def wipe(temporal: Any, ids: list[str]) -> dict[str, int]:
    """Terminate then delete each workflow. Returns counts: terminated, deleted, kept (server cannot delete)."""
    out = {"terminated": 0, "deleted": 0, "kept": 0}
    for workflow_id in ids:
        try:
            await temporal.get_workflow_handle(workflow_id).terminate(reason="reset")
            out["terminated"] += 1
        except RPCError as error:  # already finished or never started is fine
            if error.status not in NOT_THERE:
                raise HTTPException(503, "temporal unavailable")
        try:
            await temporal.workflow_service.delete_workflow_execution(DeleteWorkflowExecutionRequest(
                namespace=temporal.namespace, workflow_execution=WorkflowExecution(workflow_id=workflow_id)))
            out["deleted"] += 1
        except RPCError as error:
            if error.status == RPCStatusCode.NOT_FOUND:
                continue  # never existed (e.g. the order's start failed) or already deleted
            if error.status in CANNOT_DELETE:
                out["kept"] += 1  # an old Temporal server: the history stays until the namespace retention ends
                continue
            raise HTTPException(503, "temporal unavailable")
    return out
