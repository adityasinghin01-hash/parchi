"""A7 true-price learner: what users really paid vs the item prices, per seller per pincode.

Stores only order id, seller id, pincode, amounts and the reporting install id (to stop one
install overwriting another's report). No patient name, phone or medicine names.
"""
import re
from typing import Any, Callable

from fastapi import APIRouter, Body, Depends, FastAPI, HTTPException, Query

import db
import v2_db

MIN_REPORTS = 3
MAX_PAISE = 100_000_000  # Rs 10 lakh; rejects typos and junk
PINCODE = re.compile(r"[1-9][0-9]{5}")
ID = re.compile(r"[A-Za-z0-9_.:-]{1,128}")


def _paise(value: Any, name: str, required: bool) -> int | None:
    if value is None and not required:
        return None
    if type(value) is not int or not 0 <= value <= MAX_PAISE:
        raise ValueError(f"{name} must be an integer number of paise between 0 and {MAX_PAISE}")
    return value


def report_paid(order_id: str, body: dict[str, Any], reporter: str) -> None:
    if not isinstance(order_id, str) or not ID.fullmatch(order_id):
        raise ValueError("invalid orderID")
    seller = body.get("sellerID")
    if not isinstance(seller, str) or not ID.fullmatch(seller):
        raise ValueError("invalid sellerID")
    pincode = body.get("pincode")
    if not isinstance(pincode, str) or not PINCODE.fullmatch(pincode):
        raise ValueError("pincode must be 6 digits")
    order = db.get_order(order_id)
    if order is None:
        # K30: always strict. A report must reference an order that exists (sandbox orders are real rows too).
        raise ValueError("order not found")
    if order["install_id"] != reporter:
        # A real order can only be reported by the install that placed it (else B could pre-claim A's order id).
        raise ValueError("report belongs to another install")
    paid = _paise(body.get("paidPaise"), "paidPaise", True)
    items = _paise(body.get("itemsPaise"), "itemsPaise", False)
    v2_db.save_report(order_id, seller, pincode, paid, items, reporter)


def true_price(seller: str, pincode: str) -> dict[str, Any]:
    """reports = reports that include itemsPaise (the only ones that give an extra)."""
    extra = v2_db.extras(seller, pincode)
    enough = len(extra) >= MIN_REPORTS
    return {"sellerID": seller, "pincode": pincode, "reports": len(extra), "enough": enough,
            "medianExtraPaise": v2_db.median_int(extra) if enough else None}


def register(app: FastAPI, get_temporal: Callable, get_install_id: Callable) -> None:
    router = APIRouter()

    @router.post("/orders/{order_id}/paid")
    async def paid(order_id: str, body: dict[str, Any] = Body(...),
                   install_id: str = Depends(get_install_id)) -> dict[str, bool]:
        try:
            report_paid(order_id, body, install_id)
        except ValueError as error:
            status = 409 if "another install" in str(error) else 404 if "not found" in str(error) else 422
            raise HTTPException(status, str(error))
        return {"ok": True}

    @router.get("/true_price")
    async def get_true_price(seller: str = Query(min_length=1, max_length=128),
                             pincode: str = Query(min_length=1, max_length=6),
                             _: str = Depends(get_install_id)) -> dict[str, Any]:
        if not PINCODE.fullmatch(pincode):
            raise HTTPException(422, "pincode must be 6 digits")
        return true_price(seller, pincode)

    app.include_router(router)
