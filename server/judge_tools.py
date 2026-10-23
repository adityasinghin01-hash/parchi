"""Judge tools for shop asks and lab bookings (K10). Admin key only; mount with `register(app, ...)`.

JSON twins of the two judge-page sections. Output carries no tokens, no personal data and no install ids.
"""
import asyncio
import html
import json
from typing import Any, Callable

from fastapi import Depends, FastAPI

import p3_db
from shop import admin_header

LIMIT = 10
LAB_BUTTONS = [("Confirm", "confirmed"), ("Collected", "collected"), ("Report ready", "report_ready"),
               ("Sample rejected", "sample_rejected"), ("Late posting", "phlebotomist_late")]


def recent_asks() -> list[dict[str, Any]]:
    with p3_db.connect() as conn:
        asks = conn.execute("SELECT ask_id,state,round,items FROM shop_asks "
                            "ORDER BY created DESC, rowid DESC LIMIT ?", (LIMIT,)).fetchall()
        out = []
        for ask in asks:
            shops = conn.execute("SELECT shop_id,name,state FROM shop_shops WHERE ask_id=? ORDER BY position",
                                 (ask["ask_id"],)).fetchall()
            out.append({
                "askID": ask["ask_id"], "state": ask["state"], "round": ask["round"],
                "shops": [{"shopID": s["shop_id"], "name": s["name"], "state": s["state"]} for s in shops],
                "items": [{"itemID": i["itemID"], "name": i["name"], "quantity": i["quantity"]}
                          for i in json.loads(ask["items"])]})
    return out


def recent_bookings() -> list[dict[str, Any]]:
    with p3_db.connect() as conn:
        rows = conn.execute("SELECT booking_id,lab_name,state,slot,order_id,seller_id FROM lab_bookings "
                            "ORDER BY created DESC, rowid DESC LIMIT ?", (LIMIT,)).fetchall()
    out = []
    for row in rows:
        item: dict[str, Any] = {"bookingID": row["booking_id"], "labName": row["lab_name"],
                                "state": row["state"]}
        for key, column in (("slot", "slot"), ("orderID", "order_id"), ("sellerID", "seller_id")):
            if row[column] is not None:
                item[key] = row[column]
        out.append(item)
    return out


def esc(value: Any) -> str:
    return html.escape(str(value), quote=True)


def sections_html() -> str:
    """The two judge-page sections. Every dynamic value is escaped; the script builds no HTML."""
    asks = []
    for ask in recent_asks():
        rows = []
        for shop in ask["shops"]:
            can_reply = ask["state"] == "waiting" and shop["state"] in ("asked", "no_reply")
            reply = ""
            if can_reply:
                fields = "".join(
                    f'<label>{esc(i["name"])} &times;{esc(i["quantity"])} Rs '
                    f'<input type="number" min="0" step="0.01" data-item="{esc(i["itemID"])}"></label> '
                    for i in ask["items"])
                reply = (f' <button type="button" data-reply-toggle>Reply</button>'
                         f'<form class="rf" hidden data-ask="{esc(ask["askID"])}" data-shop="{esc(shop["shopID"])}">'
                         f'<div>Price in rupees for the whole quantity (leave empty = not available)</div>'
                         f'{fields}<label>Ready by <input type="time" class="rb"></label> '
                         f'<button type="submit">Send reply</button></form>')
            rows.append(f'<div>{esc(shop["name"])} <b>{esc(shop["state"])}</b>{reply}</div>')
        names = ", ".join(f'{esc(i["name"])} &times;{esc(i["quantity"])}' for i in ask["items"])
        asks.append(f'<div class="o"><b>Ask {esc(ask["askID"])}</b> {esc(ask["state"])} round {esc(ask["round"])}'
                    f'<div>{names}</div>{"".join(rows)}</div>')
    bookings = []
    for b in recent_bookings():
        buttons = "".join(f'<button data-lab="{esc(b["bookingID"])}" data-k="{kind}">{label}</button>'
                          for label, kind in LAB_BUTTONS)
        slot = f' slot {esc(b["slot"])}' if b.get("slot") else ""
        bookings.append(f'<div class="o"><b>{esc(b["labName"])}</b> <b>{esc(b["state"])}</b>{slot}'
                        f' (booking {esc(b["bookingID"])}) {buttons}</div>')
    return (f'<h2>Shop asks</h2>{"".join(asks) or "<p>None yet.</p>"}'
            f'<h2>Lab bookings</h2>{"".join(bookings) or "<p>None yet.</p>"}')


def register(app: FastAPI, get_temporal: Callable[..., Any] | None = None,
             get_install_id: Callable[..., Any] | None = None) -> None:
    @app.get("/judge/shop/asks", dependencies=[Depends(admin_header)])
    async def judge_shop_asks() -> list[dict[str, Any]]:
        return await asyncio.to_thread(recent_asks)

    @app.get("/judge/lab/bookings", dependencies=[Depends(admin_header)])
    async def judge_lab_bookings() -> list[dict[str, Any]]:
        return await asyncio.to_thread(recent_bookings)
