"""Offline complaint drafting. Supplied contacts/rules are not live-verified."""
from __future__ import annotations
import csv
import json
import re
from datetime import date, timedelta
from pathlib import Path

DATA = Path(__file__).resolve().parents[2] / "data"
KINDS = {"online_pharmacy", "quick_commerce", "lab", "local_shop"}


def parse_contacts(cell: str, date_seen: str) -> list[dict]:
    """Retain each email's own source, never infer an email or URL."""
    return [{"value": m.group(1), "sourceUrl": m.group(2), "dateSeen": date_seen}
            for m in re.finditer(r"([\w.+-]+@[\w.-]+\.[A-Za-z]{2,})\s*<(https?://[^<>\s]+)>", cell or "")]


def load_contacts(path: Path | str | None = None) -> list[dict]:
    with Path(path or DATA / "company_contacts.csv").open(encoding="utf-8-sig", newline="") as f:
        return [{**row, "supportContacts": parse_contacts(row["support"], row["date_seen"]),
                 "grievanceContacts": parse_contacts(row["grievance"], row["date_seen"])} for row in csv.DictReader(f)]


def _day(value, field):
    try:
        return date.fromisoformat(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{field} must be an ISO date (YYYY-MM-DD)") from exc


def generate(payload: dict) -> dict:
    if not isinstance(payload, dict):
        raise ValueError("input must be an object")
    lang = payload.get("lang", "en")
    templates = json.loads((DATA / "templates.json").read_text(encoding="utf-8"))
    if lang not in templates or payload.get("issue") not in templates[lang]:
        raise ValueError("unsupported language or issue")
    hi = lang == "hi"
    seller, order, events = payload.get("seller", {}), payload.get("order", {}), payload.get("events", {})
    if any(not isinstance(v, dict) for v in (seller, order, events)):
        raise ValueError("seller, order and events must be objects")
    if any(not isinstance(v, dict) for v in (seller, order, events)):
        raise ValueError("seller, order and events must be objects")
    kind = seller.get("kind")
    if kind not in KINDS:
        raise ValueError("unsupported seller kind")
    today = _day(payload.get("today"), "today")
    placed = _day(order.get("placedOn"), "placedOn") if order.get("placedOn") else None
    if placed and placed > today:
        raise ValueError("placedOn cannot be after today")
    event_days = {}
    for key in ("promisedBy", "cancelledOn", "refundRequestedOn", "supportContactedOn", "grievanceSentOn"):
        if events.get(key):
            event_days[key] = _day(events[key], key)
            if key != "promisedBy" and event_days[key] > today:
                raise ValueError(f"{key} cannot be after today")
            if placed and event_days[key] < placed:
                raise ValueError(f"{key} cannot precede placedOn")
    amount = order.get("amountPaise")
    if amount is not None and (type(amount) is not int or amount < 0):
        raise ValueError("amountPaise must be a non-negative integer")
    if order.get("paidVia", "unknown") not in {"upi", "card", "cash", "unknown"}:
        raise ValueError("unsupported payment method")
    if "isTestOrder" in order and type(order["isTestOrder"]) is not bool:
        raise ValueError("isTestOrder must be boolean")
    items = order.get("items", [])
    if not isinstance(items, list) or any(not isinstance(i, dict) for i in items):
        raise ValueError("items must be an array of objects")
    for item in items:
        if item.get("qty") is not None and (type(item["qty"]) is not int or item["qty"] < 0):
            raise ValueError("item qty must be a non-negative integer")
    issue = payload["issue"]
    wording = templates[lang][issue]
    subject = ("ऑर्डर संबंधी अनुरोध" if hi else "Order support request")
    if order.get("orderId"):
        subject += " — " + str(order["orderId"])
    if order.get("isTestOrder"):
        subject = "Test order — " + subject
    lines = ["नमस्ते," if hi else "Hello,", wording["fact"]]
    for key, en, hindi in [("orderId", "Order ID", "ऑर्डर आईडी"), ("placedOn", "Placed on", "ऑर्डर की तारीख")]:
        if order.get(key):
            lines.append(f"{hindi if hi else en}: {order[key]}")
    if amount is not None:
        lines.append(("रकम" if hi else "Amount") + f": ₹{amount // 100}.{amount % 100:02d}")
    if order.get("paidVia") not in (None, "unknown"):
        lines.append(("भुगतान का तरीका" if hi else "Payment method") + ": " + order["paidVia"])
    if items:
        rendered = []
        for i in items:
            bits = [str(i[k]) for k in ("name", "strength") if i.get(k) is not None]
            if i.get("qty") is not None:
                bits.append(("संख्या " if hi else "qty ") + str(i["qty"]))
            if bits:
                rendered.append(" / ".join(bits))
        if rendered:
            lines.append(("सामान" if hi else "Items") + ": " + "; ".join(rendered))
    event_labels = {
        "promisedBy": ("Promised by", "डिलीवरी की बताई तारीख"),
        "cancelledOn": ("Cancelled on", "रद्द होने की तारीख"),
        "refundRequestedOn": ("Refund requested on", "रिफंड मांगा"),
        "supportContactedOn": ("Support contacted on", "सपोर्ट से संपर्क किया"),
        "grievanceSentOn": ("Grievance sent on", "शिकायत भेजी")}
    for key, d in event_days.items():
        lines.append(f"{event_labels[key][hi]}: {d.isoformat()}")
    lines.append(wording["ask"])
    # Never assume a disputed partial amount equals the entire order total.
    if issue == "refund_pending" and amount is not None:
        lines.append("कृपया देय रिफंड की रकम की पुष्टि करें।" if hi else "Please confirm the amount due for refund.")
    if order.get("paidVia") in {"upi", "card"} and issue in {"refund_pending", "cancelled_by_seller"}:
        lines.append("कृपया रिफंड मूल भुगतान के तरीके से करें।" if hi else "Please refund to my original payment method.")
    lines.append("धन्यवाद।" if hi else "Thank you.")
    notes = ["Hindi wording is draft; native review pending." if hi else "Message is a draft for you to review and send."]
    precautions = []
    if issue in {"wrong_item", "expired_or_damaged"}:
        precaution = "विक्रेता की पुष्टि मिलने तक इस दवा का इस्तेमाल न करें।" if hi else "Do not use this medicine until the seller confirms."
        precautions.append({"text": precaution, "reviewed": False})
        notes.append(precaution + " (reviewed: false)")
    evidence = (["ऑर्डर की पुष्टि और बिल", "भुगतान का रिकॉर्ड, यदि भुगतान किया है", "सपोर्ट से हुई बातचीत, यदि मौजूद है"] if hi else
                ["Order confirmation and bill", "Payment record, if paid", "Support conversation, if available"])
    if issue in {"wrong_item", "missing_item", "expired_or_damaged"}:
        evidence.append("मिले हुए सामान का रिकॉर्ड" if hi else "Record of the received items")
    disclaimer = ("यह संदेश आप जांचकर खुद भेजें। पर्ची संदेश नहीं भेजती, पैसे नहीं संभालती और कानूनी सलाह नहीं देती।" if hi else
                  "Review and send this message yourself. Parchi does not send messages, handle money or provide legal advice.")
    result = {"message": {"subject": subject, "body": "\n".join(lines), "lang": lang}, "evidence": evidence,
              "ladder": [], "followUps": [], "notes": notes, "disclaimer": disclaimer, "precautions": precautions}
    if order.get("isTestOrder"):
        notes.append("Sandbox only: no real seller contact or escalation.")
        return result
    routes = json.loads((DATA / "official_routes.json").read_text(encoding="utf-8"))
    notes.extend([routes["status"], "check on the official site", "Refund completion time is not verified; no number is promised."])
    name = str(seller.get("name", "")).strip().casefold()
    company = next((c for c in load_contacts() if c["company"].casefold() == name), None)
    # A local shop must not inherit a similarly named platform's grievance routing.
    support = company["supportContacts"] if company and kind != "local_shop" else []
    grievances = company["grievanceContacts"] if company and kind != "local_shop" else []
    support_contact = support[0] if support else None
    result["ladder"].append({"level": 1, "who": "विक्रेता सपोर्ट" if hi else "Seller support", "how": "ईमेल या ऑर्डर के ऐप चैट से संपर्क करें" if hi else "Use the seller's email or order app chat",
                            "contact": support_contact, "when": "now", "why": "पहले विक्रेता से संपर्क करें" if hi else "Ask the seller first"})
    if not support:
        notes.append("हम इस कंपनी का संपर्क नहीं ढूंढ पाए।" if hi else "we could not find a contact for this company")
    escalation = max(event_days.get("supportContactedOn", today) + timedelta(days=2), today)
    actual_sent = event_days.get("grievanceSentOn")
    if kind != "local_shop":
        notes.append("ASSUMPTION: wait 2 days after contacting support before escalation; this is not a verified rule.")
        if grievances:
            why = ("दिए गए द्वितीयक स्रोतों में 48 घंटे में पावती और 1 महीने में निवारण बताया गया है; check on the official site" if hi else
                   "Secondary sources describe acknowledgement within 48 hours and redress within 1 month; check on the official site")
            result["ladder"].append({"level": 2, "who": "शिकायत अधिकारी" if hi else "Grievance officer", "how": "ईमेल" if hi else "Email",
                                    "contact": grievances[0], "when": escalation.isoformat(), "why": why})
            sent = actual_sent or escalation
            if actual_sent and "supportContactedOn" in event_days and actual_sent < event_days["supportContactedOn"]:
                raise ValueError("grievanceSentOn cannot precede supportContactedOn")
            for days, label in [(2, "पावती जांचें" if hi else "Check acknowledgement"), (30, "निवारण की स्थिति जांचें" if hi else "Check resolution status")]:
                result["followUps"].append({"dueOn": (sent + timedelta(days=days)).isoformat(), "text": label + "; check on the official site",
                                            "basis": "sent" if actual_sent else "planned", "complaintDate": sent.isoformat()})
            notes.append("ASSUMPTION: resolution reminder uses +30 days as specified; it is not a calendar-month calculation or a verified deadline.")
            if not actual_sent:
                notes.append("Follow-ups are planned dates. Recompute with events.grievanceSentOn after you actually send the complaint.")
        else:
            notes.append("शिकायत अधिकारी का संपर्क नहीं मिला; हेल्पलाइन का विकल्प देखें।" if hi else "No grievance contact found; use the helpline option.")
    nch = next(r for r in routes["routes"] if r["id"] == "national_consumer_helpline")
    helpline_when = "now"
    if kind != "local_shop" and grievances:
        helpline_when = max(today, (actual_sent or escalation) + timedelta(days=2)).isoformat()
    result["ladder"].append({"level": 3, "who": nch["name"], "how": f"{nch['phone']} / WhatsApp {nch['whatsapp']} / {nch['portal']}",
                            "contact": {"value": nch["phone"], "sourceUrl": nch["secondary_sources"][0], "dateSeen": routes["date_seen"]},
                            "when": helpline_when,
                            "why": ("जवाब न मिले तो हेल्पलाइन से अगले विकल्प पूछें; check on the official site" if hi else "If there is no reply by the acknowledgement check, ask the helpline about next options; check on the official site") if grievances and kind != "local_shop" else ("अगले विकल्प हेल्पलाइन से पूछ सकते हैं; check on the official site" if hi else "You can ask the helpline about next options; check on the official site")})
    return result
