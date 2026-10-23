import asyncio
from typing import Any

from temporalio import activity

import db


@activity.defn
async def place_order(order_id: str, seller_id: str, plan_version: int) -> dict[str, Any] | None:
    return await asyncio.to_thread(db.place_order, order_id, seller_id, plan_version)


@activity.defn
async def audit(order_id: str, actor: str, event: str, detail: dict[str, Any],
                plan_version: int, seq: int) -> None:
    await asyncio.to_thread(db.add_audit, order_id, actor, event, detail, plan_version, seq)


@activity.defn
async def store_approval(order_id: str, plan_version: int, approver: str, proposal_hash: str) -> None:
    await asyncio.to_thread(db.store_approval, order_id, plan_version, approver, proposal_hash)
