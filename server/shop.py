"""Shop-ask HTTP layer (CONTRACT_P3.md). Mount with `shop.register(app, get_temporal, get_install_id)`.

The server never sends messages: it creates unguessable reply links; the phone puts the link
in its own WhatsApp message. Only a hash of each reply token is stored.
"""
import asyncio
import hashlib
import hmac
import html
import json
import logging
import os
import re
from datetime import timedelta
from decimal import Decimal, InvalidOperation
from typing import Any, Callable
from urllib.parse import parse_qs

from fastapi import Body, Depends, FastAPI, HTTPException, Request
from fastapi.responses import HTMLResponse

import p3_db
from p3_db import ReplyError

log = logging.getLogger("parchi.p3")
MAX_BODY = 32_768  # reply pages are tiny; refuse anything bigger
SECURITY_HEADERS = {
    "Cache-Control": "no-store",  # the URL is the secret
    "Referrer-Policy": "no-referrer",
    "X-Content-Type-Options": "nosniff",
    "Content-Security-Policy": ("default-src 'none'; style-src 'unsafe-inline'; "
                                "form-action 'self'; base-uri 'none'; frame-ancestors 'none'"),
}
CSS = ("body{font:18px/1.4 system-ui,sans-serif;margin:0;padding:12px;max-width:560px}"
       "h1{font-size:1.25em}.i{border:1px solid #888;border-radius:8px;padding:10px;margin:10px 0}"
       "label{display:flex;align-items:center;gap:10px;padding:10px 0;font-weight:600}"
       "input[type=radio]{width:26px;height:26px}"
       "input[type=number],input[type=time],input[type=datetime-local]{font-size:1em;padding:10px;"
       "width:100%;box-sizing:border-box}"
       "button{font-size:1.1em;padding:14px;width:100%;margin-top:12px;border-radius:8px}"
       ".n{font-size:.85em;color:#444}")


# ---- shared web helpers (lab.py imports these too) ----

def esc(value: Any) -> str:
    """Escape ANY text that came from a user or a shop/lab before it goes into HTML."""
    return html.escape(str(value), quote=True)


def page(title: str, body: str, status: int = 200) -> HTMLResponse:
    doc = (f'<!doctype html><html lang="en"><meta charset="utf-8">'
           f'<meta name="viewport" content="width=device-width,initial-scale=1">'
           f'<meta name="referrer" content="no-referrer"><title>{esc(title)}</title>'
           f"<style>{CSS}</style><body>{body}</body></html>")
    return HTMLResponse(doc, status_code=status, headers=SECURITY_HEADERS)


def message_page(english: str, hindi: str, status: int = 200) -> HTMLResponse:
    return page("Parchi", f"<h1>{esc(english)}</h1><p>{esc(hindi)}</p>", status)


def default_install_id(request: Request) -> str:
    """Install key -> install id. Uses auth.require_install when auth.py exists."""
    try:
        import auth
    except ImportError:
        key = request.headers.get("X-Install-Key", "")
        hashed = hashlib.sha256(key.encode()).hexdigest()
        import db
        with db.connect() as conn:
            row = conn.execute("SELECT install_id,key_hash FROM keys WHERE key_hash=?",
                               (hashed,)).fetchone()
        if not key or row is None or not hmac.compare_digest(row["key_hash"], hashed):
            raise HTTPException(401, "invalid install key")
        return row["install_id"]
    return auth.require_install(request)


def admin_header(request: Request) -> None:
    try:
        import auth
    except ImportError:
        expected = os.environ.get("PARCHI_ADMIN_KEY", "")
        given = request.headers.get("X-Admin-Key", "")
        same = hmac.compare_digest(hashlib.sha256(given.encode()).digest(),
                                   hashlib.sha256(expected.encode()).digest())
        if not expected or not same:
            raise HTTPException(401, "invalid admin key")
        return
    auth.require_admin(request)


def public_base(request: Request) -> str:
    return os.environ.get("PARCHI_PUBLIC_URL") or str(request.base_url).rstrip("/")


def task_queue() -> str:
    return os.environ.get("PARCHI_TASK_QUEUE", "parchi")


def time_scale() -> float:
    return float(os.environ.get("PARCHI_TIME_SCALE", "1"))


async def notify(temporal: Any, workflow_id: str, name: str, args: list[Any]) -> bool:
    """Signal a workflow. SQLite already holds the truth, so a failure is logged, not fatal."""
    try:
        await temporal.get_workflow_handle(workflow_id).signal(name, args=args)
        return True
    except Exception:
        log.warning("signal %s to %s failed", name, workflow_id)
        return False


async def read_body(request: Request) -> tuple[bool, Any]:
    """(is_json, parsed). Forms are plain urlencoded; no multipart needed."""
    try:
        if int(request.headers.get("content-length", "0")) > MAX_BODY:
            raise HTTPException(413, "body too large")
    except ValueError:
        raise HTTPException(400, "bad content-length")
    raw = await request.body()
    if len(raw) > MAX_BODY:
        raise HTTPException(413, "body too large")
    if "json" in request.headers.get("content-type", ""):
        try:
            data = json.loads(raw or b"{}")
        except ValueError:
            raise HTTPException(422, "invalid JSON")
        if not isinstance(data, dict):
            raise HTTPException(422, "JSON body must be an object")
        return True, data
    return False, {k: v[0] for k, v in parse_qs(raw.decode("utf-8", "replace"),
                                                keep_blank_values=True).items()}


def need(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def short_text(value: Any, name: str, limit: int) -> str:
    need(isinstance(value, str) and 0 < len(value.strip()) and len(value) <= limit, f"invalid {name}")
    return value


def whole(value: Any, name: str, low: int, high: int) -> int:
    need(type(value) is int and low <= value <= high, f"{name} must be an integer {low}..{high}")
    return value


# ---- shop validation and form parsing ----

def validate_ask(body: dict[str, Any]) -> dict[str, Any]:
    items, shops = body.get("items"), body.get("shops")
    need(isinstance(items, list) and 1 <= len(items) <= 30, "items must have 1..30 entries")
    clean_items, seen = [], set()
    for row in items:
        need(isinstance(row, dict), "invalid item")
        item = {"itemID": short_text(row.get("itemID"), "itemID", 128),
                "name": short_text(row.get("name"), "item name", 100),
                "quantity": whole(row.get("quantity"), "quantity", 1, 999)}
        need(item["itemID"] not in seen, "duplicate itemID")
        seen.add(item["itemID"])
        if row.get("strength") is not None:
            item["strength"] = short_text(row["strength"], "strength", 40)
        clean_items.append(item)
    need(isinstance(shops, list) and 1 <= len(shops) <= 9, "shops must have 1..9 entries")
    clean_shops, seen = [], set()
    for row in shops:
        need(isinstance(row, dict), "invalid shop")
        shop = {"shopID": short_text(row.get("shopID"), "shopID", 128),
                "name": short_text(row.get("name"), "shop name", 100)}
        need(shop["shopID"] not in seen, "duplicate shopID")
        seen.add(shop["shopID"])
        if row.get("distanceM") is not None:
            shop["distanceM"] = whole(row["distanceM"], "distanceM", 0, 10_000_000)
        if row.get("phone") is not None:  # accepted for the phone's own use, never stored
            short_text(row["phone"], "phone", 32)
        clean_shops.append(shop)
    ask: dict[str, Any] = {
        "items": clean_items, "shops": clean_shops,
        "pickupBy": p3_db.iso(p3_db.parse_time(body.get("pickupBy"), "pickupBy")),
        "groupSize": whole(body.get("groupSize", 3), "groupSize", 1, 9),
        "waitMinutes": whole(body.get("waitMinutes", 10), "waitMinutes", 1, 180)}
    if body.get("orderID") is not None:
        ask["orderID"] = short_text(body["orderID"], "orderID", 128)
    return ask


def rupees_to_paise(value: str) -> int:
    try:
        amount = Decimal(value.strip())
    except (InvalidOperation, AttributeError):
        raise ReplyError("invalid", "price must be a number of rupees")
    if not amount.is_finite() or amount < 0 or amount > 100_000:
        raise ReplyError("invalid", "price out of range")
    return int((amount * 100).quantize(Decimal(1)))


def form_items(form: dict[str, str], ask_items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    out = []
    for n, item in enumerate(ask_items):
        answer = form.get(f"a{n}")
        if answer not in ("0", "1"):
            raise ReplyError("invalid", "answer every item")
        row: dict[str, Any] = {"itemID": item["itemID"], "available": answer == "1"}
        if row["available"]:
            row["pricePaise"] = rupees_to_paise(form.get(f"p{n}", ""))
        out.append(row)
    return out


def form_ready_by(form: dict[str, str]) -> str | None:
    value = (form.get("readyBy") or "").strip()
    if not value:
        return None
    if re.fullmatch(r"\d{2}:\d{2}", value):  # <input type=time>: today in IST, tomorrow if long past
        now = p3_db.now()
        try:
            ready = now.replace(hour=int(value[:2]), minute=int(value[3:]), second=0, microsecond=0)
        except ValueError:
            return value
        if ready < now - timedelta(hours=1):
            ready += timedelta(days=1)
        return ready.isoformat(timespec="seconds")
    try:
        return p3_db.iso(p3_db.parse_time(value, "readyBy", assume_ist=True))
    except ValueError:
        return value  # submit_reply reports it as invalid


def ask_form(data: dict[str, Any]) -> str:
    rows = []
    for n, item in enumerate(data["items"]):
        strength = f" {esc(item['strength'])}" if item.get("strength") else ""
        rows.append(
            f'<div class="i"><b>{esc(item["name"])}</b>{strength} &times;{esc(item["quantity"])}'
            f'<label><input type="radio" name="a{n}" value="1" required>Available / उपलब्ध</label>'
            f'<label><input type="radio" name="a{n}" value="0">Not available / उपलब्ध नहीं</label>'
            f'<label>Price for all of it (₹) / पूरी मात्रा की कीमत'
            f'<input type="number" name="p{n}" min="0" step="0.01" inputmode="decimal"></label></div>')
    return (f'<h1>{esc(data["shopName"])}</h1>'
            f'<p>Parchi request / पर्ची अनुरोध. Please quote the exact brand and strength as '
            f'written. / कृपया लिखा हुआ ब्रांड और स्ट्रेंथ ही बताएं।</p>'
            f'<form method="post">{"".join(rows)}'
            f'<div class="i"><label>Ready by / तैयार होने का समय'
            f'<input type="time" name="readyBy"></label></div>'
            f'<button type="submit">Send / भेजें</button></form>')


def reply_page(data: dict[str, Any]) -> HTMLResponse:
    if data["shopState"] == "replied":
        return message_page("Thanks, your reply has been sent.", "धन्यवाद, आपका जवाब भेज दिया गया है।")
    if data["shopState"] == "not_needed":
        return message_page("Thanks, this is no longer needed.", "धन्यवाद, अब इसकी ज़रूरत नहीं है।")
    if data["askState"] != "waiting":
        return message_page("This request has closed.", "यह अनुरोध बंद हो गया है।")
    return page("Parchi", ask_form(data))


# ---- routes ----

def register(app: FastAPI, get_temporal: Callable[..., Any],
             get_install_id: Callable[..., Any] | None = None) -> None:
    install_dep = get_install_id or default_install_id

    def owned_ask(ask_id: str, install_id: str) -> dict[str, Any]:
        ask = p3_db.get_ask(ask_id)
        if ask is None or ask["install_id"] != install_id:
            raise HTTPException(404, "ask not found")
        return ask

    # Reply pages first so "/shop/reply/<token>" can never be read as "/shop/<askID>/status".
    @app.get("/shop/reply/{token}", response_class=HTMLResponse)
    async def shop_reply_page(token: str) -> HTMLResponse:
        data = await asyncio.to_thread(p3_db.shop_page_data, token)
        if data is None:
            return message_page("This link is not valid.", "यह लिंक सही नहीं है।", 404)
        return reply_page(data)

    @app.post("/shop/reply/{token}")
    async def shop_reply_submit(token: str, request: Request,
                                temporal: Any = Depends(get_temporal)) -> Any:
        data = await asyncio.to_thread(p3_db.shop_page_data, token)
        is_json, body = await read_body(request)
        try:
            if data is None:
                raise ReplyError("not_found", "unknown reply link")
            # Say "no longer needed" / "closed" before complaining about the form itself.
            if data["shopState"] == "not_needed":
                raise ReplyError("not_needed", "no longer needed")
            if data["shopState"] == "replied":
                raise ReplyError("answered", "this shop has already answered")
            if data["askState"] != "waiting":
                raise ReplyError("closed", "this request is closed")
            if is_json:
                items, ready = body.get("items"), body.get("readyBy")
            else:
                items, ready = form_items(body, data["items"]), form_ready_by(body)
            result = await asyncio.to_thread(
                lambda: p3_db.submit_reply(token=token, items=items, ready_by=ready))
        except ReplyError as error:
            status = p3_db.STATUS[error.code]
            if is_json:
                raise HTTPException(status, str(error))
            if error.code == "not_needed":
                return message_page("Thanks, this is no longer needed.",
                                    "धन्यवाद, अब इसकी ज़रूरत नहीं है।", status)
            return message_page(f"Could not send: {error}", "जवाब नहीं भेजा जा सका।", status)
        await notify(temporal, "shop-" + result["askID"], "shop_reply", [result["shopID"]])
        if is_json:
            return {"ok": True, "totalPaise": result["totalPaise"]}
        return message_page("Thanks, your reply has been sent.", "धन्यवाद, आपका जवाब भेज दिया गया है।")

    @app.post("/shop/ask", status_code=201)
    async def shop_ask(request: Request, body: dict[str, Any] = Body(...),
                       install_id: str = Depends(install_dep),
                       temporal: Any = Depends(get_temporal)) -> dict[str, Any]:
        try:
            ask = validate_ask(body)
        except ValueError as error:
            raise HTTPException(422, str(error))
        ask_id, links = await asyncio.to_thread(p3_db.create_ask, install_id, ask)
        ids = [s["shopID"] for s in ask["shops"]]
        data = {"ask_id": ask_id, "wait_minutes": ask["waitMinutes"],
                "groups": p3_db.chunks(ids, ask["groupSize"]), "time_scale": time_scale()}
        try:
            await temporal.start_workflow("ShopAskWorkflow", data, id="shop-" + ask_id,
                                          task_queue=task_queue())
        except Exception:
            await asyncio.to_thread(p3_db.delete_ask, ask_id)  # no half-created ask
            raise HTTPException(503, "temporal unavailable")
        base = public_base(request)
        return {"askID": ask_id, "round": 1,
                "replyLinks": [{"shopID": l["shopID"], "url": f"{base}/shop/reply/{l['token']}"}
                               for l in links]}

    @app.get("/shop/{ask_id}/status")
    async def shop_status(ask_id: str, install_id: str = Depends(install_dep)) -> dict[str, Any]:
        owned_ask(ask_id, install_id)
        status = await asyncio.to_thread(p3_db.ask_status, ask_id)
        if status is None:
            raise HTTPException(404, "ask not found")
        return status

    @app.post("/shop/{ask_id}/next")
    async def shop_next(ask_id: str, request: Request, install_id: str = Depends(install_dep),
                        temporal: Any = Depends(get_temporal)) -> dict[str, Any]:
        owned_ask(ask_id, install_id)
        try:
            opened = await asyncio.to_thread(p3_db.open_next, ask_id, install_id)
        except LookupError:
            raise HTTPException(404, "ask not found")
        if opened is None:
            raise HTTPException(409, "nothing to open")
        round_no, links = opened
        await notify(temporal, "shop-" + ask_id, "next_round", [round_no])
        base = public_base(request)
        return {"round": round_no,
                "replyLinks": [{"shopID": l["shopID"], "url": f"{base}/shop/reply/{l['token']}"}
                               for l in links]}

    @app.post("/judge/shop/{ask_id}/reply", dependencies=[Depends(admin_header)])
    async def judge_shop_reply(ask_id: str, body: dict[str, Any] = Body(...),
                               temporal: Any = Depends(get_temporal)) -> dict[str, Any]:
        shop_id = body.get("shopID")
        if not isinstance(shop_id, str):
            raise HTTPException(422, "shopID is required")
        try:
            result = await asyncio.to_thread(lambda: p3_db.submit_reply(
                ask_id=ask_id, shop_id=shop_id, items=body.get("items"),
                ready_by=body.get("readyBy"), via="judge"))
        except ReplyError as error:
            raise HTTPException(p3_db.STATUS[error.code], str(error))
        await notify(temporal, "shop-" + ask_id, "shop_reply", [shop_id])
        return {"ok": True, "totalPaise": result["totalPaise"]}
