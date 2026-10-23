"""Phase 3 SQLite layer (shop ask + lab booking). Own tables, created on demand.

SQLite is the source of truth for replies, winners and states; the Temporal workflows
only own the timers (no-reply, report chase). Every state change that two requests could
race on (first reply wins, one answer per shop) runs inside BEGIN IMMEDIATE.
Never stored: patient name, patient phone, shop phone.
"""
import base64
import hashlib
import hmac
import json
import os
import secrets
from pathlib import Path
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from typing import Any, Iterator

import db

IST = timezone(timedelta(hours=5, minutes=30))
DEFAULT_REPORT_HOURS = 24  # used when no reportDueAt is supplied at collection time

SCHEMA = """
CREATE TABLE IF NOT EXISTS shop_asks (
    ask_id TEXT PRIMARY KEY, install_id TEXT NOT NULL, order_id TEXT,
    items TEXT NOT NULL, pickup_by TEXT NOT NULL,
    group_size INTEGER NOT NULL, wait_minutes INTEGER NOT NULL,
    round INTEGER NOT NULL DEFAULT 1, state TEXT NOT NULL DEFAULT 'waiting',
    no_reply INTEGER NOT NULL DEFAULT 0, winner_shop_id TEXT, created TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS shop_asks_install ON shop_asks(install_id);
CREATE TABLE IF NOT EXISTS shop_shops (
    ask_id TEXT NOT NULL REFERENCES shop_asks(ask_id) ON DELETE CASCADE,
    shop_id TEXT NOT NULL, name TEXT NOT NULL, distance_m INTEGER,
    position INTEGER NOT NULL, state TEXT NOT NULL DEFAULT 'not_asked',
    round_asked INTEGER, token_hash TEXT UNIQUE, asked_at TEXT, replied_at TEXT,
    reply TEXT, total_paise INTEGER, ready_by TEXT, reply_via TEXT,
    PRIMARY KEY (ask_id, shop_id)
);
CREATE TABLE IF NOT EXISTS lab_bookings (
    booking_id TEXT PRIMARY KEY, install_id TEXT NOT NULL,
    lab_id TEXT NOT NULL, lab_name TEXT NOT NULL, tests TEXT NOT NULL,
    home_collection INTEGER NOT NULL, preferred_slot TEXT NOT NULL, address_text TEXT,
    order_id TEXT, seller_id TEXT, token_hash TEXT NOT NULL UNIQUE,
    state TEXT NOT NULL DEFAULT 'requested', no_reply INTEGER NOT NULL DEFAULT 0,
    slot TEXT, fee_paise INTEGER, report_due_at TEXT, fasting_reminder_at TEXT,
    note TEXT, created TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS lab_bookings_install ON lab_bookings(install_id);
"""


class ReplyError(Exception):
    """A rejected reply. `code` maps to an HTTP status in the routers."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


STATUS = {"not_found": 404, "closed": 409, "answered": 409, "not_needed": 409,
          "conflict": 409, "invalid": 422}


LAB_EXTRA_COLUMNS = ("idem_key", "body_hash")  # added after the first release: older databases are migrated here


def _migrate(conn: Any) -> None:
    have = {row[1] for row in conn.execute("PRAGMA table_info(lab_bookings)")}
    for column in LAB_EXTRA_COLUMNS:
        if column not in have:
            conn.execute(f"ALTER TABLE lab_bookings ADD COLUMN {column} TEXT")


@contextmanager
def connect(immediate: bool = False) -> Iterator[Any]:
    with db.connect() as conn:
        conn.executescript(SCHEMA)
        _migrate(conn)
        if immediate:
            conn.execute("BEGIN IMMEDIATE")
        yield conn


# ---- small shared helpers ----

def now() -> datetime:
    return datetime.now(IST)


def iso(value: datetime) -> str:
    return value.astimezone(IST).isoformat(timespec="seconds")


def parse_time(value: Any, name: str, assume_ist: bool = False) -> datetime:
    if not isinstance(value, str) or not 10 <= len(value) <= 40:
        raise ValueError(f"{name} must be an ISO-8601 time")
    try:
        parsed = datetime.fromisoformat(value.strip())
    except ValueError:
        raise ValueError(f"{name} must be an ISO-8601 time")
    if parsed.tzinfo is None:
        if not assume_ist:
            raise ValueError(f"{name} needs a UTC offset (for example +05:30)")
        parsed = parsed.replace(tzinfo=IST)
    return parsed.astimezone(IST)


def new_token() -> str:
    return secrets.token_urlsafe(16)  # 22 chars, 128 bits


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def fasting_reminder(slot: datetime, tests: list[dict[str, Any]]) -> str | None:
    """21:00 IST the evening before the slot; only when some test needs fasting."""
    if not any(t.get("fasting") is True for t in tests):
        return None
    day = slot.astimezone(IST).date() - timedelta(days=1)
    return iso(datetime(day.year, day.month, day.day, 21, 0, tzinfo=IST))


def delete_install(install_id: str) -> None:
    """Privacy: 'delete everything' on the phone also clears its shop/lab rows."""
    with connect() as conn:
        conn.execute("DELETE FROM shop_asks WHERE install_id=?", (install_id,))
        conn.execute("DELETE FROM lab_bookings WHERE install_id=?", (install_id,))


def delete_all() -> None:
    with connect() as conn:
        conn.execute("DELETE FROM shop_asks")
        conn.execute("DELETE FROM lab_bookings")


# ---- shop ask ----

def chunks(ids: list[str], size: int) -> list[list[str]]:
    return [ids[i:i + size] for i in range(0, len(ids), size)]


def create_ask(install_id: str, ask: dict[str, Any]) -> tuple[str, list[dict[str, str]]]:
    """Insert the ask and open round 1. Returns (askID, [{shopID, token}])."""
    ask_id = secrets.token_hex(8)
    stamp = iso(now())
    links = []
    with connect(immediate=True) as conn:
        conn.execute("""INSERT INTO shop_asks(ask_id,install_id,order_id,items,pickup_by,
                        group_size,wait_minutes,created) VALUES (?,?,?,?,?,?,?,?)""",
                     (ask_id, install_id, ask.get("orderID"), json.dumps(ask["items"]),
                      ask["pickupBy"], ask["groupSize"], ask["waitMinutes"], stamp))
        for pos, shop in enumerate(ask["shops"]):
            first = pos < ask["groupSize"]
            token = new_token() if first else None
            conn.execute("""INSERT INTO shop_shops(ask_id,shop_id,name,distance_m,position,state,
                            round_asked,token_hash,asked_at) VALUES (?,?,?,?,?,?,?,?,?)""",
                         (ask_id, shop["shopID"], shop["name"], shop.get("distanceM"), pos,
                          "asked" if first else "not_asked", 1 if first else None,
                          hash_token(token) if token else None, stamp if first else None))
            if token:
                links.append({"shopID": shop["shopID"], "token": token})
    return ask_id, links


def delete_ask(ask_id: str) -> None:
    with connect() as conn:
        conn.execute("DELETE FROM shop_asks WHERE ask_id=?", (ask_id,))


def get_ask(ask_id: str) -> dict[str, Any] | None:
    with connect() as conn:
        row = conn.execute("SELECT * FROM shop_asks WHERE ask_id=?", (ask_id,)).fetchone()
    return dict(row) if row else None


def open_next(ask_id: str, install_id: str | None = None) -> tuple[int, list[dict[str, str]]] | None:
    """Open the next group. None = nothing to open. LookupError = unknown ask/owner."""
    with connect(immediate=True) as conn:
        ask = conn.execute("SELECT * FROM shop_asks WHERE ask_id=?", (ask_id,)).fetchone()
        if ask is None or (install_id is not None and ask["install_id"] != install_id):
            raise LookupError(ask_id)
        if ask["state"] != "waiting":
            return None
        rows = conn.execute("""SELECT shop_id FROM shop_shops WHERE ask_id=? AND state='not_asked'
                               ORDER BY position LIMIT ?""", (ask_id, ask["group_size"])).fetchall()
        if not rows:
            return None
        new_round = ask["round"] + 1
        # Earlier groups that never answered are marked, but may still answer late.
        conn.execute("UPDATE shop_shops SET state='no_reply' WHERE ask_id=? AND state='asked'", (ask_id,))
        stamp, links = iso(now()), []
        for row in rows:
            token = new_token()
            conn.execute("""UPDATE shop_shops SET state='asked', round_asked=?, token_hash=?, asked_at=?
                            WHERE ask_id=? AND shop_id=?""",
                         (new_round, hash_token(token), stamp, ask_id, row["shop_id"]))
            links.append({"shopID": row["shop_id"], "token": token})
        conn.execute("UPDATE shop_asks SET round=?, no_reply=0 WHERE ask_id=?", (new_round, ask_id))
    return new_round, links


def shop_mark_no_reply(ask_id: str, round_no: int) -> bool:
    with connect(immediate=True) as conn:
        ask = conn.execute("SELECT state, round FROM shop_asks WHERE ask_id=?", (ask_id,)).fetchone()
        if ask is None or ask["state"] != "waiting" or ask["round"] != round_no:
            return False
        conn.execute("""UPDATE shop_shops SET state='no_reply'
                        WHERE ask_id=? AND state='asked' AND round_asked=?""", (ask_id, round_no))
        conn.execute("UPDATE shop_asks SET no_reply=1 WHERE ask_id=?", (ask_id,))
    return True


def close_ask(ask_id: str) -> str | None:
    """Close an ask nobody answered. Returns the winner instead if one just arrived."""
    with connect(immediate=True) as conn:
        ask = conn.execute("SELECT state, winner_shop_id FROM shop_asks WHERE ask_id=?",
                           (ask_id,)).fetchone()
        if ask is None:
            return None
        if ask["state"] == "waiting":
            conn.execute("UPDATE shop_asks SET state='closed', no_reply=1 WHERE ask_id=?", (ask_id,))
        return ask["winner_shop_id"]


def close_ask_round(ask_id: str, round_no: int) -> dict[str, Any]:
    """Close an ask nobody answered, but ONLY the round the caller was watching. If the user opened a newer round meanwhile (its
    reply links are live) nothing is closed and the caller learns the newer round. (Codex R8 row 8)"""
    with connect(immediate=True) as conn:
        ask = conn.execute("SELECT state, round, winner_shop_id FROM shop_asks WHERE ask_id=?", (ask_id,)).fetchone()
        if ask is None:
            return {"winner": None, "round": round_no, "closed": True}
        if ask["state"] == "waiting" and ask["round"] == round_no and ask["winner_shop_id"] is None:
            conn.execute("UPDATE shop_asks SET state='closed', no_reply=1 WHERE ask_id=?", (ask_id,))
            return {"winner": None, "round": round_no, "closed": True}
        return {"winner": ask["winner_shop_id"], "round": ask["round"], "closed": ask["state"] != "waiting"}


def ask_status(ask_id: str) -> dict[str, Any] | None:
    with connect() as conn:
        ask = conn.execute("SELECT * FROM shop_asks WHERE ask_id=?", (ask_id,)).fetchone()
        if ask is None:
            return None
        shops = conn.execute("SELECT * FROM shop_shops WHERE ask_id=? ORDER BY position",
                             (ask_id,)).fetchall()
    out_shops = []
    for s in shops:
        row: dict[str, Any] = {"shopID": s["shop_id"], "state": s["state"]}
        if s["asked_at"]:
            row["askedAt"] = s["asked_at"]
        if s["replied_at"]:
            row["repliedAt"] = s["replied_at"]
        row["items"] = json.loads(s["reply"]) if s["reply"] else []
        if s["state"] == "replied":
            row["totalPaise"] = s["total_paise"]
            if s["ready_by"]:
                row["readyBy"] = s["ready_by"]
        out_shops.append(row)
    waiting = ask["state"] == "waiting"
    next_group = [s["shop_id"] for s in shops if s["state"] == "not_asked"][:ask["group_size"]]
    status: dict[str, Any] = {
        "askID": ask_id, "state": ask["state"], "round": ask["round"],
        "noReply": bool(ask["no_reply"]),
        "nextGroup": next_group if ask["no_reply"] and waiting else [],
        "shops": out_shops,
    }
    if ask["winner_shop_id"]:
        status["winnerShopID"] = ask["winner_shop_id"]
    return status


def shop_page_data(token: str) -> dict[str, Any] | None:
    """Everything the reply page needs for this token (None = unknown token)."""
    with connect() as conn:
        shop = conn.execute("SELECT * FROM shop_shops WHERE token_hash=?",
                            (hash_token(token),)).fetchone()
        if shop is None:
            return None
        ask = conn.execute("SELECT * FROM shop_asks WHERE ask_id=?", (shop["ask_id"],)).fetchone()
    return {"shopName": shop["name"], "shopState": shop["state"], "askState": ask["state"],
            "items": json.loads(ask["items"]), "pickupBy": ask["pickup_by"]}


def clean_reply(items: Any, ask_items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Every ask item answered exactly once; price only for available items."""
    if not isinstance(items, list) or len(items) != len(ask_items):
        raise ReplyError("invalid", "answer every item")
    wanted = {i["itemID"] for i in ask_items}
    seen: dict[str, dict[str, Any]] = {}
    for row in items:
        if not isinstance(row, dict) or row.get("itemID") not in wanted or row["itemID"] in seen:
            raise ReplyError("invalid", "unknown or duplicate item")
        available = row.get("available")
        if type(available) is not bool:
            raise ReplyError("invalid", "available must be true or false")
        out: dict[str, Any] = {"itemID": row["itemID"], "available": available}
        if available:
            price = row.get("pricePaise")
            if type(price) is not int or not 0 <= price <= 10_000_000:
                raise ReplyError("invalid", "pricePaise must be an integer paise amount")
            out["pricePaise"] = price
        seen[row["itemID"]] = out
    return [seen[i["itemID"]] for i in ask_items]


def submit_reply(*, items: Any, ready_by: Any, token: str | None = None,
                 ask_id: str | None = None, shop_id: str | None = None,
                 via: str = "page") -> dict[str, Any]:
    """Store a shop's reply. The first complete reply wins; atomic against races."""
    with connect(immediate=True) as conn:
        if token is not None:
            shop = conn.execute("SELECT * FROM shop_shops WHERE token_hash=?",
                                (hash_token(token),)).fetchone()
        else:
            shop = conn.execute("SELECT * FROM shop_shops WHERE ask_id=? AND shop_id=?",
                                (ask_id, shop_id)).fetchone()
        if shop is None:
            raise ReplyError("not_found", "unknown reply link")
        ask = conn.execute("SELECT * FROM shop_asks WHERE ask_id=?", (shop["ask_id"],)).fetchone()
        if shop["state"] == "replied":
            raise ReplyError("answered", "this shop has already answered")
        if shop["state"] == "not_needed":
            raise ReplyError("not_needed", "no longer needed")
        if ask["state"] != "waiting":
            raise ReplyError("closed", "this request is closed")
        if shop["state"] not in ("asked", "no_reply"):
            raise ReplyError("conflict", "this shop has not been asked yet")
        ask_items = json.loads(ask["items"])
        answers = clean_reply(items, ask_items)
        # pricePaise is the price for the WHOLE quantity asked (same meaning as the planner's Offer.price),
        # so a shopkeeper quotes one number per item and the app never has to guess pack sizes.
        total = sum(a["pricePaise"] for a in answers if a["available"])
        ready = None
        if any(a["available"] for a in answers):
            try:
                ready = iso(parse_time(ready_by, "readyBy"))
            except ValueError as error:
                raise ReplyError("invalid", str(error))
        stamp = iso(now())
        conn.execute("""UPDATE shop_shops SET state='replied', replied_at=?, reply=?, total_paise=?,
                        ready_by=?, reply_via=? WHERE ask_id=? AND shop_id=?""",
                     (stamp, json.dumps(answers), total, ready, via, shop["ask_id"], shop["shop_id"]))
        conn.execute("""UPDATE shop_shops SET state='not_needed'
                        WHERE ask_id=? AND shop_id<>? AND state IN ('asked','no_reply')""",
                     (shop["ask_id"], shop["shop_id"]))
        conn.execute("UPDATE shop_asks SET state='replied', winner_shop_id=?, no_reply=0 WHERE ask_id=?",
                     (shop["shop_id"], shop["ask_id"]))
    return {"askID": shop["ask_id"], "shopID": shop["shop_id"], "totalPaise": total}


# ---- lab booking ----

def create_booking(install_id: str, b: dict[str, Any]) -> tuple[str, str]:
    booking_id, token = secrets.token_hex(8), new_token()
    with connect() as conn:
        conn.execute("""INSERT INTO lab_bookings(booking_id,install_id,lab_id,lab_name,tests,
                        home_collection,preferred_slot,address_text,order_id,seller_id,token_hash,created)
                        VALUES (?,?,?,?,?,?,?,?,?,?,?,?)""",
                     (booking_id, install_id, b["labID"], b["labName"], json.dumps(b["tests"]),
                      int(b["homeCollection"]), b["preferredSlot"], b.get("addressText"),
                      b.get("orderID"), b.get("sellerID"), hash_token(token), iso(now())))
    return booking_id, token


class KeyReuseError(Exception):
    """The same Idempotency-Key was sent with a different booking."""


def token_secret() -> bytes:
    """Server-side secret next to the database (mode 600). Reply links of idempotent bookings are HMACs of the booking id, so a retry
    can return the same link while the database still stores only the token's hash."""
    path = Path(os.environ.get("PARCHI_DB", "data/parchi.db")).parent / "token.secret"
    try:
        return path.read_bytes()
    except FileNotFoundError:
        path.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "wb") as handle:
            handle.write(secrets.token_bytes(32))
        return path.read_bytes()


def booking_token(booking_id: str) -> str:
    mac = hmac.new(token_secret(), f"lab-reply:{booking_id}".encode(), hashlib.sha256).digest()
    return base64.urlsafe_b64encode(mac)[:22].decode()  # 22 chars like new_token(), 132 bits


def create_booking_once(install_id: str, b: dict[str, Any], idem_key: str, body_hash: str) -> tuple[str, str, bool]:
    """Idempotent create (Codex R8 row 9): the booking id comes from install + key, so a retry after a lost response returns the
    SAME booking and reply link instead of creating a second booking, token and workflow. Returns (id, token, created)."""
    booking_id = hashlib.sha256(f"{install_id}\n{idem_key}".encode()).hexdigest()[:16]
    token = booking_token(booking_id)
    with connect(immediate=True) as conn:
        row = conn.execute("SELECT install_id, body_hash, state FROM lab_bookings WHERE booking_id=?", (booking_id,)).fetchone()
        if row is not None:
            if row["install_id"] != install_id or row["body_hash"] != body_hash:
                raise KeyReuseError("Idempotency-Key was already used with a different booking")
            # the link only works while the lab has not answered; afterwards there is nothing to hand out
            return booking_id, token if row["state"] == "requested" else "", False
        conn.execute("""INSERT INTO lab_bookings(booking_id,install_id,lab_id,lab_name,tests,
                        home_collection,preferred_slot,address_text,order_id,seller_id,token_hash,created,
                        idem_key,body_hash)
                        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                     (booking_id, install_id, b["labID"], b["labName"], json.dumps(b["tests"]),
                      int(b["homeCollection"]), b["preferredSlot"], b.get("addressText"),
                      b.get("orderID"), b.get("sellerID"), hash_token(token), iso(now()),
                      hashlib.sha256(idem_key.encode()).hexdigest(), body_hash))
    return booking_id, token, True


def delete_booking(booking_id: str) -> None:
    with connect() as conn:
        conn.execute("DELETE FROM lab_bookings WHERE booking_id=?", (booking_id,))


def get_booking(booking_id: str) -> dict[str, Any] | None:
    with connect() as conn:
        row = conn.execute("SELECT * FROM lab_bookings WHERE booking_id=?", (booking_id,)).fetchone()
    return dict(row) if row else None


def booking_status(row: dict[str, Any]) -> dict[str, Any]:
    status: dict[str, Any] = {"bookingID": row["booking_id"], "state": row["state"],
                              "noReply": bool(row["no_reply"])}
    for key, column in (("slot", "slot"), ("feePaise", "fee_paise"), ("reportDueAt", "report_due_at"),
                        ("fastingReminderAt", "fasting_reminder_at"), ("note", "note")):
        if row[column] is not None:
            status[key] = row[column]
    return status


def lab_page_data(token: str) -> dict[str, Any] | None:
    with connect() as conn:
        row = conn.execute("SELECT * FROM lab_bookings WHERE token_hash=?",
                           (hash_token(token),)).fetchone()
    if row is None:
        return None
    return dict(row, tests=json.loads(row["tests"]))


def lab_mark_no_reply(booking_id: str) -> bool:
    with connect(immediate=True) as conn:
        cur = conn.execute("UPDATE lab_bookings SET no_reply=1 WHERE booking_id=? AND state='requested'",
                           (booking_id,))
    return cur.rowcount == 1


def lab_time_state(booking_id: str, new_state: str, from_states: list[str]) -> str | None:
    """Time-driven transition (report_due, report_chase_due); returns the state now stored."""
    marks = ",".join("?" * len(from_states))
    with connect(immediate=True) as conn:
        conn.execute(f"UPDATE lab_bookings SET state=? WHERE booking_id=? AND state IN ({marks})",
                     (new_state, booking_id, *from_states))
        row = conn.execute("SELECT state FROM lab_bookings WHERE booking_id=?", (booking_id,)).fetchone()
    return row["state"] if row else None


def lab_expire(booking_id: str) -> str | None:
    """The workflow gave up on a booking that made no progress: close it for good. The reply link only works while the state is
    'requested' and judge events need confirmed/collected/..., so one UPDATE also kills the link. (Codex R8 row 7)"""
    with connect(immediate=True) as conn:
        conn.execute("""UPDATE lab_bookings SET state='expired', note=COALESCE(note || ' · ', '') || 'Closed: no progress'
                        WHERE booking_id=? AND state IN ('requested','confirmed')""", (booking_id,))
        row = conn.execute("SELECT state FROM lab_bookings WHERE booking_id=?", (booking_id,)).fetchone()
    return row["state"] if row else None


def lab_reply(token: str, action: Any, slot: Any = None, fee_paise: Any = None) -> dict[str, Any]:
    """The lab's one answer: confirm the slot, propose another, or decline."""
    with connect(immediate=True) as conn:
        row = conn.execute("SELECT * FROM lab_bookings WHERE token_hash=?",
                           (hash_token(token),)).fetchone()
        if row is None:
            raise ReplyError("not_found", "unknown reply link")
        if row["state"] != "requested":
            raise ReplyError("answered", "this booking has already been answered")
        if action not in ("confirm", "propose", "decline"):
            raise ReplyError("invalid", "action must be confirm, propose or decline")
        if fee_paise is not None and (type(fee_paise) is not int or not 0 <= fee_paise <= 10_000_000):
            raise ReplyError("invalid", "feePaise must be an integer paise amount")
        tests = json.loads(row["tests"])
        if action == "decline":
            conn.execute("""UPDATE lab_bookings SET state='rejected', no_reply=0, note=?
                            WHERE booking_id=?""", ("Lab cannot do this", row["booking_id"]))
        else:
            note = None
            if action == "confirm":
                chosen = parse_time(row["preferred_slot"], "slot")
            else:
                try:
                    chosen = parse_time(slot, "slot", assume_ist=True)
                except ValueError as error:
                    raise ReplyError("invalid", str(error))
                note = "Lab proposed another slot"
            conn.execute("""UPDATE lab_bookings SET state='confirmed', no_reply=0, slot=?, fee_paise=?,
                            fasting_reminder_at=?, note=? WHERE booking_id=?""",
                         (iso(chosen), fee_paise, fasting_reminder(chosen, tests), note,
                          row["booking_id"]))
        done = conn.execute("SELECT * FROM lab_bookings WHERE booking_id=?",
                            (row["booking_id"],)).fetchone()
    return dict(done)


# What the judge may simulate: kind -> (allowed current states, new state, note).
EVENTS = {
    "confirmed": (("requested",), "confirmed", None),
    "collected": (("confirmed",), "collected", None),
    "report_ready": (("collected", "report_due", "report_chase_due"), "done", None),
    "sample_rejected": (("confirmed", "collected"), "rejected", "Sample rejected"),
    "phlebotomist_late": (("confirmed",), None, "Phlebotomist is late"),
}


def lab_event(booking_id: str, kind: str, report_due_at: Any = None) -> dict[str, Any]:
    allowed, new_state, note = EVENTS[kind]
    with connect(immediate=True) as conn:
        row = conn.execute("SELECT * FROM lab_bookings WHERE booking_id=?", (booking_id,)).fetchone()
        if row is None:
            raise ReplyError("not_found", "unknown booking")
        if row["state"] not in allowed:
            raise ReplyError("conflict", f"{kind} is not possible while {row['state']}")
        changes: dict[str, Any] = {}
        if new_state:
            changes["state"] = new_state
        if note:
            changes["note"] = note
        if kind == "confirmed":
            slot = parse_time(row["preferred_slot"], "slot")
            changes.update(slot=iso(slot), no_reply=0,
                           fasting_reminder_at=fasting_reminder(slot, json.loads(row["tests"])))
        if kind == "collected":
            try:
                due = (parse_time(report_due_at, "reportDueAt") if report_due_at is not None else
                       parse_time(row["slot"], "slot") + timedelta(hours=DEFAULT_REPORT_HOURS))
            except ValueError as error:
                raise ReplyError("invalid", str(error))
            changes["report_due_at"] = iso(due)
        sets = ",".join(f"{k}=?" for k in changes)
        conn.execute(f"UPDATE lab_bookings SET {sets} WHERE booking_id=?", (*changes.values(), booking_id))
        done = conn.execute("SELECT * FROM lab_bookings WHERE booking_id=?", (booking_id,)).fetchone()
    return dict(done)
