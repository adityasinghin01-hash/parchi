"""Lab-booking HTTP layer (CONTRACT_P3.md). Mount with `lab.register(app, get_temporal, get_install_id)`.

Only a hash of the lab's reply token is stored. No patient name or phone is ever accepted
or stored; the address text is the home-collection address only.
"""
import asyncio
from typing import Any, Callable

from fastapi import Body, Depends, FastAPI, HTTPException, Request
from fastapi.responses import HTMLResponse

import db
import p3_db
from p3_db import ReplyError
from shop import (admin_header, default_install_id, esc, need, notify, message_page, page,
                  public_base, read_body, rupees_to_paise, short_text, task_queue, time_scale)

JUDGE_KINDS = {"confirmed", "collected", "report_ready", "sample_rejected", "phlebotomist_late"}
# Judge events that also tell the order workflow, so Plan B runs.
ORDER_EVENT = {"sample_rejected": "sampleRejected", "phlebotomist_late": "late"}


def validate_booking(body: dict[str, Any], install_id: str) -> dict[str, Any]:
    tests = body.get("tests")
    need(isinstance(tests, list) and 1 <= len(tests) <= 20, "tests must have 1..20 entries")
    clean_tests, seen = [], set()
    for row in tests:
        need(isinstance(row, dict), "invalid test")
        test = {"testID": short_text(row.get("testID"), "testID", 128),
                "name": short_text(row.get("name"), "test name", 100)}
        need(test["testID"] not in seen, "duplicate testID")
        seen.add(test["testID"])
        if row.get("fasting") is not None:
            need(type(row["fasting"]) is bool, "fasting must be true or false")
            test["fasting"] = row["fasting"]
        clean_tests.append(test)
    need(type(body.get("homeCollection")) is bool, "homeCollection must be true or false")
    booking: dict[str, Any] = {
        "labID": short_text(body.get("labID"), "labID", 128),
        "labName": short_text(body.get("labName"), "labName", 100),
        "tests": clean_tests, "homeCollection": body["homeCollection"],
        "preferredSlot": p3_db.iso(p3_db.parse_time(body.get("preferredSlot"), "preferredSlot"))}
    if body.get("addressText") is not None:
        booking["addressText"] = short_text(body["addressText"], "addressText", 300)
    for key in ("orderID", "sellerID"):
        if body.get(key) is not None:
            booking[key] = short_text(body[key], key, 128)
    if "orderID" in booking:
        # Only link to the caller's own order, so a booking can never signal someone else's.
        order = db.get_order(booking["orderID"])
        need(order is not None and order["install_id"] == install_id, "unknown orderID")
    return booking


def when(value: str) -> str:
    return p3_db.parse_time(value, "time").strftime("%d %b %Y, %I:%M %p")


def lab_form(row: dict[str, Any]) -> str:
    tests = "".join(
        f"<li>{esc(t['name'])}{' (Fasting / खाली पेट)' if t.get('fasting') else ''}</li>"
        for t in row["tests"])
    address = f"<p>{esc(row['address_text'])}</p>" if row["address_text"] else ""
    home = "Yes / हाँ" if row["home_collection"] else "No / नहीं"
    return (f'<h1>{esc(row["lab_name"])}</h1><p>Parchi lab booking / पर्ची लैब बुकिंग</p>'
            f'<ul>{tests}</ul>'
            f'<p>Preferred slot / पसंदीदा समय: <b>{esc(when(row["preferred_slot"]))}</b></p>'
            f'<p>Home collection / घर से सैंपल: {home}</p>{address}'
            f'<form method="post">'
            f'<button name="action" value="confirm" formnovalidate>'
            f'Confirm this slot / यह समय पक्का करें</button>'
            f'<div class="i"><label>Another slot / दूसरा समय'
            f'<input type="datetime-local" name="slot"></label>'
            f'<label>Fee (₹) / शुल्क<input type="number" name="fee" min="0" step="0.01" '
            f'inputmode="decimal"></label>'
            f'<button name="action" value="propose">Propose another slot / दूसरा समय सुझाएं</button></div>'
            f'<button name="action" value="decline" formnovalidate>Cannot do / नहीं कर सकते</button>'
            f'</form>')


def reply_page(row: dict[str, Any]) -> HTMLResponse:
    if row["state"] != "requested":
        return message_page("Thanks, this booking has been answered.",
                            "धन्यवाद, इस बुकिंग का जवाब दिया जा चुका है।")
    return page("Parchi", lab_form(row))


def register(app: FastAPI, get_temporal: Callable[..., Any],
             get_install_id: Callable[..., Any] | None = None) -> None:
    install_dep = get_install_id or default_install_id

    def owned(booking_id: str, install_id: str) -> dict[str, Any]:
        row = p3_db.get_booking(booking_id)
        if row is None or row["install_id"] != install_id:
            raise HTTPException(404, "booking not found")
        return row

    @app.get("/lab/reply/{token}", response_class=HTMLResponse)
    async def lab_reply_page(token: str) -> HTMLResponse:
        row = await asyncio.to_thread(p3_db.lab_page_data, token)
        if row is None:
            return message_page("This link is not valid.", "यह लिंक सही नहीं है।", 404)
        return reply_page(row)

    @app.post("/lab/reply/{token}")
    async def lab_reply_submit(token: str, request: Request,
                               temporal: Any = Depends(get_temporal)) -> Any:
        is_json, body = await read_body(request)
        try:
            if is_json:
                action, slot, fee = body.get("action"), body.get("slot"), body.get("feePaise")
            else:
                action, slot = body.get("action"), body.get("slot") or None
                fee = rupees_to_paise(body["fee"]) if body.get("fee", "").strip() else None
            row = await asyncio.to_thread(lambda: p3_db.lab_reply(token, action, slot, fee))
        except ReplyError as error:
            status = p3_db.STATUS[error.code]
            if is_json:
                raise HTTPException(status, str(error))
            return message_page(f"Could not send: {error}", "जवाब नहीं भेजा जा सका।", status)
        kind = "rejected" if row["state"] == "rejected" else "confirmed"
        await notify(temporal, "lab-" + row["booking_id"], "lab_event", [kind, None])
        if is_json:
            return p3_db.booking_status(row)
        return message_page("Thanks, your reply has been sent.", "धन्यवाद, आपका जवाब भेज दिया गया है।")

    @app.post("/lab/book", status_code=201)
    async def lab_book(request: Request, body: dict[str, Any] = Body(...),
                       install_id: str = Depends(install_dep),
                       temporal: Any = Depends(get_temporal)) -> dict[str, Any]:
        try:
            booking = validate_booking(body, install_id)
        except ValueError as error:
            raise HTTPException(422, str(error))
        booking_id, token = await asyncio.to_thread(p3_db.create_booking, install_id, booking)
        try:
            await temporal.start_workflow(
                "LabBookingWorkflow", {"booking_id": booking_id, "time_scale": time_scale()},
                id="lab-" + booking_id, task_queue=task_queue())
        except Exception:
            await asyncio.to_thread(p3_db.delete_booking, booking_id)  # no half-created booking
            raise HTTPException(503, "temporal unavailable")
        return {"bookingID": booking_id, "replyLink": f"{public_base(request)}/lab/reply/{token}"}

    @app.get("/lab/{booking_id}/status")
    async def lab_status(booking_id: str, install_id: str = Depends(install_dep)) -> dict[str, Any]:
        return p3_db.booking_status(owned(booking_id, install_id))

    @app.post("/judge/lab/{booking_id}/event", dependencies=[Depends(admin_header)])
    async def judge_lab_event(booking_id: str, body: dict[str, Any] = Body(...),
                              temporal: Any = Depends(get_temporal)) -> dict[str, Any]:
        kind = body.get("kind")
        if kind not in JUDGE_KINDS:
            raise HTTPException(422, "kind must be one of " + ", ".join(sorted(JUDGE_KINDS)))
        try:
            row = await asyncio.to_thread(
                lambda: p3_db.lab_event(booking_id, kind, body.get("reportDueAt")))
        except ReplyError as error:
            raise HTTPException(p3_db.STATUS[error.code], str(error))
        await notify(temporal, "lab-" + booking_id, "lab_event",
                     [kind, row["report_due_at"] if kind == "collected" else None])
        signalled = None
        if kind in ORDER_EVENT and row["order_id"] and row["seller_id"]:
            # Same signal the order judge sends, so the order workflow starts Plan B.
            signalled = await notify(temporal, "order-" + row["order_id"], "seller_event",
                                     [row["seller_id"], ORDER_EVENT[kind]])
            if not signalled:
                raise HTTPException(502, "booking updated but the order could not be signalled")
        return {"ok": True, "state": row["state"], "orderSignalled": bool(signalled)}
