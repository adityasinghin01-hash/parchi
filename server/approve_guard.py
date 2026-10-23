"""K30: one approval per plan version, decided atomically in SQLite (not by the racy "read version, then signal").

Two approvals of the same plan version sent at once both used to pass the API's version check and both got 200
(the workflow ignored the second one, so there was no double effect, but the answer was wrong). Now the first
request writes a claim row (order, planVersion) in one INSERT; the second finds it and gets 409 "already approved".
A replay with the SAME Idempotency-Key gets the stored first answer (200) instead, even after the version moved on.
Stores only order id, plan version and the client's Idempotency-Key. Rows go with the order (ON DELETE CASCADE).
"""
from typing import Any, Awaitable, Callable

from fastapi import HTTPException

import db

SCHEMA = """
CREATE TABLE IF NOT EXISTS approve_claims (
    order_id TEXT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    plan_version INTEGER NOT NULL, idem_key TEXT,
    created TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    PRIMARY KEY (order_id, plan_version)
);
CREATE UNIQUE INDEX IF NOT EXISTS approve_claims_key ON approve_claims(order_id, idem_key)
    WHERE idem_key IS NOT NULL;
CREATE TABLE IF NOT EXISTS approve_receipts (
    order_id TEXT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    plan_version INTEGER NOT NULL, idem_key TEXT NOT NULL,
    PRIMARY KEY(order_id, idem_key)
);
"""
FIRST_ANSWER = {"ok": True}  # what the first, successful approval returned


def setup(conn) -> None:
    conn.executescript(SCHEMA)
    if "proposal_id" not in {r[1] for r in conn.execute("PRAGMA table_info(approve_claims)")}:
        try:
            conn.execute("ALTER TABLE approve_claims ADD COLUMN proposal_id TEXT NOT NULL DEFAULT ''")
        except db.sqlite3.OperationalError as error:
            if "duplicate column" not in str(error):
                raise


def replay(order_id: str, plan_version: int, idem_key: str | None) -> dict[str, Any] | None:
    """The stored first answer if this exact (Idempotency-Key, planVersion) already won the claim."""
    if not idem_key:
        return None
    with db.connect() as conn:
        setup(conn)
        row = conn.execute("SELECT 1 FROM approve_receipts WHERE order_id=? AND idem_key=? AND plan_version=?",
                           (order_id, idem_key, plan_version)).fetchone()
    return dict(FIRST_ANSWER) if row else None


def claim(order_id: str, plan_version: int, idem_key: str | None, proposal_id: str = "") -> bool:
    """True for exactly one caller per (order, planVersion)."""
    with db.connect() as conn:
        setup(conn)
        cur = conn.execute("""INSERT INTO approve_claims(order_id,plan_version,idem_key,proposal_id)
                           SELECT order_id,?,?,? FROM orders WHERE order_id=? AND deleting=0
                           ON CONFLICT(order_id,plan_version) DO UPDATE SET
                           idem_key=excluded.idem_key, proposal_id=excluded.proposal_id
                           WHERE approve_claims.proposal_id != excluded.proposal_id""",
                           (plan_version, idem_key or None, proposal_id, order_id))
        return cur.rowcount == 1


def release(order_id: str, plan_version: int, proposal_id: str = "") -> None:
    """The signal could not be sent: let the client try again."""
    with db.connect() as conn:
        setup(conn)
        conn.execute("DELETE FROM approve_claims WHERE order_id=? AND plan_version=? AND proposal_id=?",
                     (order_id, plan_version, proposal_id))


def is_claimed(order_id: str, plan_version: int) -> bool:
    with db.connect() as conn:
        setup(conn)
        return conn.execute("SELECT 1 FROM approve_claims WHERE order_id=? AND plan_version=?",
                            (order_id, plan_version)).fetchone() is not None


async def guarded_approve(order_id: str, version: Any, idem_key: str | None, install_id: str, temporal: Any, *,
                          owned_order: Callable, snapshot: Callable[..., Awaitable[dict[str, Any]]],
                          send_signal: Callable[..., Awaitable[dict[str, bool]]]) -> dict[str, Any]:
    """POST /order/{id}/approve. api.py passes its own helpers in (no import cycle). Non-int versions fall through to
    send_signal, which answers 422 as before."""
    if type(version) is int:
        owned_order(order_id, install_id)  # 404 for someone else's order, before anything is revealed
        again = replay(order_id, version, idem_key)
        if again is not None:
            return again
        snap = await snapshot(temporal, order_id)
        if version == snap["planVersion"] and snap["state"] == "awaiting_approval":
            proposal_id = (snap.get("proposal") or {}).get("proposalID", "")
            if not claim(order_id, version, idem_key, proposal_id):
                raise HTTPException(409, "already approved")  # lost the race by one INSERT
            try:
                answer = await send_signal(order_id, "approve", version, [], install_id, temporal)
                if idem_key:
                    with db.connect() as conn:
                        conn.execute("INSERT OR IGNORE INTO approve_receipts(order_id,plan_version,idem_key) VALUES (?,?,?)",
                                     (order_id, version, idem_key))
                return answer
            except BaseException:
                release(order_id, version, proposal_id)
                raise
        if is_claimed(order_id, version):
            raise HTTPException(409, "already approved")
    return await send_signal(order_id, "approve", version, [], install_id, temporal)
