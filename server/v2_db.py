"""V2 tables (reliability, true price). Own tables, CREATE IF NOT EXISTS; db.py is untouched.

Reuses db.connect() so the same PARCHI_DB file is used. No patient name or phone is stored.
"""
from contextlib import contextmanager
from typing import Any, Iterator
import sqlite3

import db

SCHEMA = """
CREATE TABLE IF NOT EXISTS seller_reliability (
    area TEXT NOT NULL, seller_id TEXT NOT NULL,
    ok INTEGER NOT NULL DEFAULT 0, total INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (area, seller_id), CHECK (ok >= 0 AND total >= ok)
);
-- Dedupe keys for reliability: sha256(order|seller|outcome), one way. install_id only lets
-- "Delete everything" clear this install's keys; the counts above carry no install or order id.
CREATE TABLE IF NOT EXISTS reliability_seen (
    key TEXT PRIMARY KEY, install_id TEXT NOT NULL DEFAULT '',
    created TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS reliability_seen_install ON reliability_seen(install_id);
CREATE TABLE IF NOT EXISTS true_price_reports (
    order_id TEXT NOT NULL, seller_id TEXT NOT NULL, pincode TEXT NOT NULL,
    paid_paise INTEGER NOT NULL, items_paise INTEGER,
    reporter TEXT NOT NULL,
    created TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    PRIMARY KEY (order_id, seller_id)
);
CREATE INDEX IF NOT EXISTS true_price_lookup ON true_price_reports(seller_id, pincode);
"""


@contextmanager
def connect() -> Iterator[sqlite3.Connection]:
    with db.connect() as conn:
        conn.executescript(SCHEMA)
        yield conn


# ---- reliability ----

def bump_reliability(area: str, seller_id: str, ok: bool) -> tuple[int, int]:
    with connect() as conn:
        conn.execute("INSERT OR IGNORE INTO seller_reliability(area,seller_id) VALUES (?,?)",
                     (area, seller_id))
        conn.execute("UPDATE seller_reliability SET total=total+1, ok=ok+? WHERE area=? AND seller_id=?",
                     (1 if ok else 0, area, seller_id))
        row = conn.execute("SELECT ok,total FROM seller_reliability WHERE area=? AND seller_id=?",
                           (area, seller_id)).fetchone()
        return row["ok"], row["total"]


def bump_reliability_once(key: str, area: str, seller_id: str, ok: bool, order_id: str,
                          live_order_only: bool) -> tuple[bool, int, int]:
    """Count one outcome unless `key` was counted before. Returns (counted, ok, total).

    The key and the count are written in one transaction, so replays, retries and a second
    process cannot count twice. With `live_order_only` (the workflow path) nothing is counted
    unless the order still exists and is not being deleted, so a reset wins against late retries.
    """
    with connect() as conn:
        if live_order_only:
            cur = conn.execute("""INSERT OR IGNORE INTO reliability_seen(key,install_id)
                                  SELECT ?, install_id FROM orders WHERE order_id=? AND deleting=0""",
                               (key, order_id))
        else:
            cur = conn.execute("""INSERT OR IGNORE INTO reliability_seen(key,install_id)
                                  VALUES (?, COALESCE((SELECT install_id FROM orders WHERE order_id=?),''))""",
                               (key, order_id))
        if cur.rowcount == 1:
            conn.execute("INSERT OR IGNORE INTO seller_reliability(area,seller_id) VALUES (?,?)", (area, seller_id))
            conn.execute("UPDATE seller_reliability SET total=total+1, ok=ok+? WHERE area=? AND seller_id=?",
                         (1 if ok else 0, area, seller_id))
        row = conn.execute("SELECT ok,total FROM seller_reliability WHERE area=? AND seller_id=?",
                           (area, seller_id)).fetchone()
        return cur.rowcount == 1, (row["ok"] if row else 0), (row["total"] if row else 0)


def reliability_counts(area: str, seller_id: str | None = None) -> list[dict[str, Any]]:
    sql, params = "SELECT seller_id,ok,total FROM seller_reliability WHERE area=?", [area]
    if seller_id is not None:
        sql += " AND seller_id=?"
        params.append(seller_id)
    with connect() as conn:
        return [dict(r) for r in conn.execute(sql, params)]


# ---- true price ----

def save_report(order_id: str, seller_id: str, pincode: str, paid: int,
                items: int | None, reporter: str) -> None:
    """One report per (order, seller); only the same reporter may replace it."""
    with connect() as conn:
        row = conn.execute("SELECT reporter FROM true_price_reports WHERE order_id=? AND seller_id=?",
                           (order_id, seller_id)).fetchone()
        if row is not None and row["reporter"] != reporter:
            raise ValueError("report belongs to another install")
        conn.execute("""INSERT INTO true_price_reports(order_id,seller_id,pincode,paid_paise,items_paise,reporter)
                        VALUES (?,?,?,?,?,?)
                        ON CONFLICT(order_id,seller_id) DO UPDATE SET pincode=excluded.pincode,
                        paid_paise=excluded.paid_paise, items_paise=excluded.items_paise""",
                     (order_id, seller_id, pincode, paid, items, reporter))


def extras(seller_id: str, pincode: str) -> list[int]:
    """paid - items for every report that says what the items cost."""
    with connect() as conn:
        rows = conn.execute("""SELECT paid_paise-items_paise AS extra FROM true_price_reports
                               WHERE seller_id=? AND pincode=? AND items_paise IS NOT NULL""",
                            (seller_id, pincode)).fetchall()
    return [r["extra"] for r in rows]


def median_int(values: list[int]) -> int:
    # Integer paise: the mean of the two middle values is floored.
    s, mid = sorted(values), len(values) // 2
    return s[mid] if len(s) % 2 else (s[mid - 1] + s[mid]) // 2


def delete_install(install_id: str) -> None:
    """Privacy: 'Delete everything' removes this install's true-price reports (reliability counts are aggregate, no install id, and stay; only the dedupe keys go)."""
    with connect() as conn:
        conn.execute("DELETE FROM true_price_reports WHERE reporter=?", (install_id,))
        conn.execute("DELETE FROM reliability_seen WHERE install_id=?", (install_id,))


def delete_all() -> None:
    with connect() as conn:
        conn.execute("DELETE FROM true_price_reports")
        conn.execute("DELETE FROM reliability_seen")
