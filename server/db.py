import json
import os
import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator


@contextmanager
def connect() -> Iterator[sqlite3.Connection]:
    path = Path(os.environ.get("PARCHI_DB", "data/parchi.db"))
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys=ON")
    try:
        with conn:
            yield conn
    finally:
        conn.close()


def init_db() -> None:
    with connect() as conn:
        conn.execute("PRAGMA journal_mode=WAL")
        conn.executescript("""
            CREATE TABLE IF NOT EXISTS keys (
                install_id TEXT PRIMARY KEY, key_hash TEXT NOT NULL UNIQUE,
                label TEXT NOT NULL, created TEXT NOT NULL
                    DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
            );
            CREATE TABLE IF NOT EXISTS deleted_orders (
                order_id TEXT PRIMARY KEY, install_id TEXT NOT NULL,
                at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
            );
            CREATE TABLE IF NOT EXISTS orders (
                order_id TEXT PRIMARY KEY, install_id TEXT NOT NULL,
                deleting INTEGER NOT NULL DEFAULT 0,
                created TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
            );
            CREATE INDEX IF NOT EXISTS orders_install ON orders(install_id);
            CREATE TABLE IF NOT EXISTS placements (
                order_id TEXT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
                seller_id TEXT NOT NULL, plan_version INTEGER NOT NULL,
                label TEXT NOT NULL DEFAULT 'Test order',
                created TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
                PRIMARY KEY (order_id, seller_id, plan_version)
            );
            CREATE TABLE IF NOT EXISTS audit (
                order_id TEXT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
                seq INTEGER NOT NULL, actor TEXT NOT NULL, event TEXT NOT NULL,
                detail TEXT NOT NULL, plan_version INTEGER NOT NULL,
                created TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
                PRIMARY KEY (order_id, seq)
            );
            CREATE TABLE IF NOT EXISTS approvals (
                order_id TEXT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
                plan_version INTEGER NOT NULL, approver TEXT NOT NULL,
                proposal_hash TEXT NOT NULL,
                created TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
                PRIMARY KEY (order_id, plan_version)
            );
        """)
        columns = [row["name"] for row in conn.execute("PRAGMA table_info(orders)")]
        if "body_hash" not in columns:
            conn.execute("ALTER TABLE orders ADD COLUMN body_hash TEXT")
        # Tombstones only need to outlive a client's retry window (no personal data in them).
        conn.execute("DELETE FROM deleted_orders WHERE at < strftime('%Y-%m-%dT%H:%M:%fZ','now','-48 hours')")


class KeyReuseError(ValueError):
    """The same Idempotency-Key was sent with a different request body."""


def reserve_order(order_id: str, install_id: str, body_hash: str | None = None) -> dict[str, Any]:
    with connect() as conn:
        if conn.execute("SELECT 1 FROM deleted_orders WHERE order_id=?", (order_id,)).fetchone():
            raise ValueError("order was deleted")  # a replayed key must not resurrect a reset order
        conn.execute("INSERT OR IGNORE INTO orders(order_id,install_id,body_hash) VALUES (?,?,?)",
                     (order_id, install_id, body_hash))
        row = conn.execute("SELECT * FROM orders WHERE order_id=?", (order_id,)).fetchone()
        if row["install_id"] != install_id or row["deleting"]:
            raise ValueError("order unavailable")
        if body_hash is not None and row["body_hash"] not in (None, body_hash):
            raise KeyReuseError("idempotency key reused with a different body")
        return dict(row)


def get_order(order_id: str) -> dict[str, Any] | None:
    with connect() as conn:
        row = conn.execute("SELECT * FROM orders WHERE order_id=? AND deleting=0", (order_id,)).fetchone()
        return dict(row) if row else None


def list_orders(install_id: str | None = None, limit: int | None = None) -> list[dict[str, Any]]:
    sql = "SELECT * FROM orders WHERE deleting=0"
    params: list[Any] = []
    if install_id is not None:
        sql += " AND install_id=?"
        params.append(install_id)
    sql += " ORDER BY created DESC, order_id"
    if limit is not None:
        sql += " LIMIT ?"
        params.append(limit)
    with connect() as conn:
        return [dict(row) for row in conn.execute(sql, params)]


def place_order(order_id: str, seller_id: str, plan_version: int) -> dict[str, Any] | None:
    with connect() as conn:
        # The guard is inside the write transaction so reset wins against late retries.
        conn.execute("""INSERT OR IGNORE INTO placements(order_id,seller_id,plan_version)
                        SELECT order_id,?,? FROM orders WHERE order_id=? AND deleting=0""",
                     (seller_id, plan_version, order_id))
        row = conn.execute("""SELECT order_id AS orderID, seller_id AS sellerID,
                              plan_version AS planVersion, label, created FROM placements
                              WHERE order_id=? AND seller_id=? AND plan_version=?""",
                           (order_id, seller_id, plan_version)).fetchone()
        return dict(row) if row else None


def placements_for(order_id: str) -> list[dict[str, Any]]:
    with connect() as conn:
        return [dict(row) for row in conn.execute(
            """SELECT order_id AS orderID, seller_id AS sellerID, plan_version AS planVersion,
               label, created FROM placements WHERE order_id=? ORDER BY plan_version,seller_id""",
            (order_id,))]


def add_audit(order_id: str, actor: str, event: str, detail: dict[str, Any],
              plan_version: int, seq: int) -> None:
    with connect() as conn:
        conn.execute("""INSERT OR IGNORE INTO audit(order_id,actor,event,detail,plan_version,seq)
                        SELECT order_id,?,?,?,?,? FROM orders WHERE order_id=? AND deleting=0""",
                     (actor, event, json.dumps(detail, sort_keys=True), plan_version, seq, order_id))


def audit_for(order_id: str, limit: int = 20) -> list[dict[str, Any]]:
    with connect() as conn:
        rows = conn.execute("""SELECT seq,actor,event,detail,plan_version AS planVersion,created
                               FROM audit WHERE order_id=? ORDER BY seq DESC LIMIT ?""",
                            (order_id, limit)).fetchall()
    return [dict(row, detail=json.loads(row["detail"])) for row in reversed(rows)]


def store_approval(order_id: str, plan_version: int, approver: str, proposal_hash: str) -> None:
    with connect() as conn:
        conn.execute("""INSERT OR IGNORE INTO approvals(order_id,plan_version,approver,proposal_hash)
                        SELECT order_id,?,?,? FROM orders WHERE order_id=? AND deleting=0""",
                     (plan_version, approver, proposal_hash, order_id))


def mark_deleting(install_id: str | None = None) -> list[dict[str, Any]]:
    clause = " WHERE install_id=?" if install_id is not None else ""
    params = (install_id,) if install_id is not None else ()
    with connect() as conn:
        conn.execute("UPDATE orders SET deleting=1" + clause, params)
        return [dict(row) for row in conn.execute("SELECT * FROM orders" + clause, params)]


def delete_orders(install_id: str | None = None, ids: list[str] | None = None) -> None:
    """With `ids`, delete only those orders: an order created while a reset was running must survive it."""
    with connect() as conn:
        if ids is not None:
            conn.executemany("""INSERT OR IGNORE INTO deleted_orders(order_id,install_id)
                                SELECT order_id,install_id FROM orders WHERE order_id=?""", [(i,) for i in ids])
            conn.executemany("DELETE FROM orders WHERE order_id=?", [(i,) for i in ids])
            return
        clause = " WHERE install_id=?" if install_id is not None else ""
        params = (install_id,) if install_id is not None else ()
        conn.execute("INSERT OR IGNORE INTO deleted_orders(order_id,install_id) SELECT order_id,install_id FROM orders" + clause, params)
        conn.execute("DELETE FROM orders" + clause, params)
