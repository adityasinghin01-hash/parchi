"""K20: end-to-end in a REAL browser (headless Chromium via Playwright) against the live server.

Judge page (desktop 1280x800), shop reply page and lab reply page (mobile 390x844, Android user agent).
Run from anywhere, NOT in the server venv:
    ~/pw-venv/bin/python server/browser_e2e.py [--base http://localhost:8000] [--shots /tmp/k20]
Keys are read here from data/admin.key and data/sim_install.key and are never printed (output is scrubbed).
Exit code 0 = every check PASS, 1 = at least one FAIL. Needs the server up (`bash start_all.sh`).
"""
import argparse
import asyncio
import copy
import json
import re
import sys
import time
import traceback
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import urlparse

from playwright.async_api import async_playwright

HERE = Path(__file__).resolve().parent
ADMIN = (HERE / "data/admin.key").read_text().strip()
INSTALL = (HERE / "data/sim_install.key").read_text().strip()
IST = timezone(timedelta(hours=5, minutes=30))
LOCAL_HOSTS = {"localhost", "127.0.0.1", "[::1]"}
ANDROID_UA = ("Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) "
              "Chrome/124.0.0.0 Mobile Safari/537.36")
EVIL_SCRIPT = "<script>window.__xss=1;alert('xss1')</script>"
EVIL_IMG = '"><img src=x onerror="window.__xss=1;alert(\'xss2\')">'
HINDI = "शर्मा मेडिकल स्टोर, मुरादनगर"

BASE = "http://localhost:8000"
SHOTS = Path("/tmp/k20")
rows: list[tuple[str, str, bool, str]] = []   # (scenario, check, ok, detail)
timings: dict[str, float] = {}
requests_seen: list[tuple[str, str]] = []      # (host, path) of EVERY browser request, no query strings
current = ["-"]


# ---------------------------------------------------------------- output helpers

def clean(text: object) -> str:
    """Never let a key or a reply token reach stdout / the report."""
    s = str(text)
    for secret in (ADMIN, INSTALL):
        s = s.replace(secret, "***")
    s = re.sub(r"(/(?:shop|lab)/reply/)[\w-]{10,}", r"\1<token>", s)
    return re.sub(r"([?&]k=)[^&\s'\"]+", r"\1***", s)


def check(name: str, ok: bool, detail: str = "") -> bool:
    rows.append((current[0], name, bool(ok), clean(detail)))
    print(("PASS " if ok else "FAIL ") + f"[{current[0]}] {name}" + (f" ({clean(detail)})" if detail else ""), flush=True)
    return bool(ok)


# ---------------------------------------------------------------- plain HTTP helper (urllib, like e2e_live.py)

def api(method: str, path: str, who: str = "install", body: object = None, headers: dict | None = None,
        raw: bool = False) -> tuple[int, object]:
    h = {"Content-Type": "application/json"}
    if who == "install":
        h["X-Install-Key"] = INSTALL
    elif who == "admin":
        h["X-Admin-Key"] = ADMIN
    h.update(headers or {})
    data = body if isinstance(body, (bytes, type(None))) else json.dumps(body).encode()
    for _ in range(8):
        try:
            req = urllib.request.Request(BASE + path, method=method, headers=h, data=data)
            with urllib.request.urlopen(req, timeout=10) as r:
                text = r.read()
                return r.status, (text.decode() if raw else json.loads(text or b"null"))
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(min(int(e.headers.get("Retry-After", "2")), 10))
                continue
            text = e.read()
            return e.code, (text.decode() if raw else None)
    return 429, None


async def poll(fn, timeout: float, step: float = 0.2):
    t0 = time.time()
    while time.time() - t0 < timeout:
        v = fn()
        if v:
            return v, round(time.time() - t0, 2)
        await asyncio.sleep(step)
    return None, round(time.time() - t0, 2)


# ---------------------------------------------------------------- test data

def line(item: str, seller: str, price: int = 10000) -> dict:
    return {"itemID": item, "sellerID": seller, "price": price, "isSubstitute": False}


def plan_of(lines: list[dict]) -> dict:
    return {"lines": lines, "feesBySeller": {}, "itemsTotal": sum(r["price"] for r in lines), "feesTotal": 0,
            "stops": len({r["sellerID"] for r in lines}), "maxEtaMinutes": 60,
            "medicinesReadyMinutes": 60, "reportsReadyMinutes": 0}


def seller(sid: str, channel: str = "localChemist") -> dict:
    return {"id": sid, "name": sid, "channel": channel, "etaMinutes": 60, "requiresVisit": channel != "onlinePharmacy"}


def proposal_for(plan: dict, failed: str, replacement: str, extra: int = 2500) -> dict:
    kept = [copy.deepcopy(r) for r in plan["lines"] if r["sellerID"] != failed]
    rerouted = [dict(r, sellerID=replacement, price=r["price"] + extra) for r in plan["lines"] if r["sellerID"] == failed]
    new = plan_of(kept + rerouted)
    return {"failure": "cancelled", "failedSellerID": failed, "kept": kept, "rerouted": rerouted, "newPlan": new,
            "extraCost": new["itemsTotal"] - plan["itemsTotal"], "stillMissing": []}


def create_order(sellers: list[dict], lines: list[dict]) -> tuple[str, dict]:
    plan = plan_of(lines)
    code, r = api("POST", "/order", body={"plan": plan, "sellers": sellers},
                  headers={"Idempotency-Key": "k20-" + uuid.uuid4().hex})
    assert code in (200, 201), f"order create http {code}"
    return r["orderID"], plan


def ist_now() -> datetime:
    return datetime.now(IST)


def shop_items() -> list[dict]:
    return [{"itemID": "r1", "name": "Telma 40", "strength": "40 mg", "quantity": 30},
            {"itemID": "r2", "name": "Pan 40", "strength": "40 mg", "quantity": 15},
            {"itemID": "r3", "name": "Dolo 650", "quantity": 10}]


def create_ask(shops: list[dict], items: list[dict] | None = None, group: int = 3) -> tuple[str, dict[str, str]]:
    pickup = (ist_now() + timedelta(hours=3)).isoformat(timespec="seconds")
    code, r = api("POST", "/shop/ask", body={"items": items or shop_items(), "shops": shops, "pickupBy": pickup,
                                              "groupSize": group, "waitMinutes": 10})
    assert code == 201, f"ask create http {code}"
    return r["askID"], {l["shopID"]: l["url"] for l in r["replyLinks"]}


def ask_status(aid: str) -> dict:
    return api("GET", f"/shop/{aid}/status")[1] or {}


def shop_state(aid: str, sid: str) -> str | None:
    return next((s["state"] for s in ask_status(aid).get("shops", []) if s["shopID"] == sid), None)


def create_booking(tests: list[dict], slot: datetime, lab_name: str = "Redcliffe Labs", address: str | None = "Muradnagar, Ghaziabad",
                   order_id: str | None = None, seller_id: str | None = None) -> tuple[str, str]:
    body = {"labID": "redcliffe", "labName": lab_name, "tests": tests, "homeCollection": address is not None,
            "preferredSlot": slot.isoformat(timespec="seconds")}
    if address:
        body["addressText"] = address
    if order_id:
        body.update(orderID=order_id, sellerID=seller_id)
    code, r = api("POST", "/lab/book", body=body)
    assert code == 201, f"booking create http {code}"
    return r["bookingID"], r["replyLink"]


def booking_status(bid: str) -> dict:
    return api("GET", f"/lab/{bid}/status")[1] or {}


def css(value: str) -> str:
    """Escape a value for use inside a double-quoted CSS attribute selector."""
    return value.replace("\\", "\\\\").replace('"', '\\"')


def tomorrow_slot(hour: int = 8, days: int = 1) -> datetime:
    d = (ist_now() + timedelta(days=days)).date()
    return datetime(d.year, d.month, d.day, hour, 0, tzinfo=IST)


# ---------------------------------------------------------------- browser helpers

class Watch:
    """Dialogs, console errors and page errors for one page."""

    def __init__(self, page, tag: str):
        self.dialogs: list[str] = []
        self.console_errors: list[str] = []
        self.page_errors: list[str] = []
        self.tag = tag
        page.on("dialog", lambda d: (self.dialogs.append(d.message), asyncio.ensure_future(d.dismiss())))
        page.on("console", lambda m: self.console_errors.append(m.text) if m.type == "error" else None)
        page.on("pageerror", lambda e: self.page_errors.append(str(e)))

    def real_errors(self) -> list[str]:
        """Console errors that are not just the browser logging a 4xx/5xx the test provoked on purpose."""
        return [e for e in self.console_errors if "Failed to load resource" not in e]


async def new_context(browser, kind: str):
    if kind == "desktop":
        ctx = await browser.new_context(viewport={"width": 1280, "height": 800}, locale="en-IN", timezone_id="Asia/Kolkata")
    else:
        ctx = await browser.new_context(viewport={"width": 390, "height": 844}, user_agent=ANDROID_UA, is_mobile=True,
                                        has_touch=True, device_scale_factor=2, locale="en-IN", timezone_id="Asia/Kolkata")

    def on_request(req):
        u = urlparse(req.url)
        if u.scheme in ("http", "https", "ws", "wss", "ftp"):
            requests_seen.append((u.hostname or "?", u.path))
        elif u.scheme not in ("about", "data", "blob"):
            requests_seen.append((u.scheme + "://" + (u.hostname or ""), u.path))
    ctx.on("request", on_request)
    return ctx


async def open_judge(ctx, key: str | None = None):
    page = await ctx.new_page()
    watch = Watch(page, "judge")
    resp = await page.goto(f"{BASE}/judge?k={key if key is not None else ADMIN}")
    return page, watch, resp


async def shot(page, name: str, full: bool = False) -> str:
    SHOTS.mkdir(parents=True, exist_ok=True)
    path = str(SHOTS / f"{name}.png")
    await page.screenshot(path=path, full_page=full)
    return path


async def clear_msg(page) -> None:
    await page.evaluate("document.getElementById('msg').textContent = ''")


async def after_post(page, expect: str = "sent") -> str:
    """The judge page writes sent / error NNN into #msg, then reloads itself after 0.6 s."""
    msg = page.locator("#msg")
    for _ in range(40):
        text = (await msg.text_content()) or ""
        if text:
            break
        await asyncio.sleep(0.1)
    if text == "sent":
        await page.wait_for_timeout(1000)
        await page.wait_for_load_state("load")
    return text


def judge_form(page, ask_id: str, shop_id: str):
    return page.locator(f'form.rf[data-ask="{css(ask_id)}"][data-shop="{css(shop_id)}"]')


async def judge_reply(page, ask_id: str, shop_id: str, prices: dict[str, str], ready: str = "19:30") -> str:
    """Click Reply, fill the rupee fields (missing/empty = not available) and the time, click Send reply."""
    form = judge_form(page, ask_id, shop_id)
    await clear_msg(page)
    await form.locator("xpath=preceding-sibling::button[@data-reply-toggle][1]").click()
    for item_id, value in prices.items():
        await form.locator(f'input[data-item="{css(item_id)}"]').fill(value)
    if ready:
        await form.locator("input.rb").fill(ready)
    await form.locator('button[type="submit"]').click()
    return await after_post(page)


async def horizontal_overflow(page) -> int:
    return await page.evaluate("document.documentElement.scrollWidth - document.documentElement.clientWidth")


# ================================================================ scenarios

async def scenario_1(browser):
    """Order + judge: click Cancel, Plan B proposal within 3 s, approve through the API, reload shows v2."""
    ctx = await new_context(browser, "desktop")
    sellers = [seller(s) for s in ("s1", "s2", "s3", "s4")]
    lines = [line("a", "s1"), line("b", "s2"), line("c", "s1")]
    oid, plan = create_order(sellers, lines)
    ready, t = await poll(lambda: (api("GET", f"/status/{oid}")[1] or {}).get("ready"), 15)
    check("sandbox order created and ready", bool(ready), f"{t}s")
    page, watch, resp = await open_judge(ctx)
    check("judge page opens (200)", resp.status == 200, f"http {resp.status}")
    row = page.locator("div.o", has_text=f"Test order {oid}")
    text = await row.inner_text()
    check("judge page lists the order as placed v1", re.search(r"state: placed v1", text) is not None, text.split("\n")[0])
    await shot(page, "s1_judge_before")
    t_click = time.time()
    await page.locator(f'button[data-o="{oid}"][data-s="s1"][data-k="cancelled"]').click()
    msg = await after_post(page)
    check("click on Cancel shows 'sent'", msg == "sent", msg)
    snap, _ = await poll(lambda: (lambda s: s if s and s["state"] == "needs_proposal" else None)(api("GET", f"/status/{oid}")[1]), 3)
    t_needs = round(time.time() - t_click, 2)
    check("order asks for a Plan B within 3 s of the click", snap is not None and t_needs <= 3.0, f"{t_needs}s (phone side starts here)")
    # The server never re-plans: play the phone and post the proposal, then wait for the awaiting_approval state.
    prop = proposal_for(plan, "s1", "s4")
    code, _ = api("POST", f"/order/{oid}/proposal", body={"planVersion": 1, "proposal": prop})
    check("phone-side proposal accepted", code == 200, f"http {code}")
    snap, t = await poll(lambda: (lambda s: s if s and s["state"] == "awaiting_approval" else None)(api("GET", f"/status/{oid}")[1]), 5)
    t_prop = round(time.time() - t_click, 2)
    check("proposal visible through the API (awaiting_approval) within 3 s of the click",
          snap is not None and snap.get("proposal") is not None and t_prop <= 3.0, f"{t_prop}s after the click")
    code, _ = api("POST", f"/order/{oid}/approve", body={"planVersion": 1})
    check("approve through the API accepted", code == 200, f"http {code}")
    final, t = await poll(lambda: (lambda s: s if s and s["planVersion"] == 2 and s["state"] == "placed" else None)(api("GET", f"/status/{oid}")[1]), 8)
    check("order moved to plan version 2", final is not None, f"{t}s")
    await page.reload()
    text = await row.inner_text()
    check("reloaded judge page shows v2", re.search(r"state: placed v2", text) is not None, text.split("\n")[0])
    check("cancelled seller shown as rerouted, replacement placed",
          re.search(r"s1\s+rerouted", text) is not None and re.search(r"s4\s+placed", text) is not None)
    await shot(page, "s1_judge_after_planb")
    check("no dialogs / JS errors on the judge page", not watch.dialogs and not watch.page_errors and not watch.real_errors(),
          f"dialogs={watch.dialogs} errors={watch.page_errors + watch.real_errors()}")
    await ctx.close()


async def scenario_2(browser):
    """Shop ask: map-<uuid> shop, judge Reply click, the other shops not_needed, second reply refused, then the shop's own link on mobile."""
    desk = await new_context(browser, "desktop")
    mob = await new_context(browser, "mobile")
    map_uuid = f"map-{uuid.uuid4()}"
    app_style = "map-शरममडकल-287512-775123"     # what ShopSearch.makeID builds for a Devanagari name (letters only, then 10 m grid)
    shops = [{"shopID": map_uuid, "name": "Sharma Medical Store", "distanceM": 450, "phone": "9876543210"},
             {"shopID": app_style, "name": HINDI, "distanceM": 820},
             {"shopID": "s3", "name": "City Chemist", "distanceM": 1300}]
    aid, links = create_ask(shops)
    check("ask for 3 shops incl. map-<uuid> and a Devanagari map id accepted", len(links) == 3 and map_uuid in links, f"{len(links)} links")

    page, watch, _ = await open_judge(desk)
    stale, _, _ = await open_judge(desk)      # second tab holding a stale copy of the same forms
    block = page.locator("div.o", has_text=f"Ask {aid}")
    text = await block.inner_text()
    check("judge page shows the ask with the map shop, Hindi name, all 'asked'",
          "Sharma Medical Store" in text and HINDI in text and text.count("asked") >= 3, text.replace("\n", " | ")[:120])
    await judge_form(page, aid, map_uuid).locator("xpath=preceding-sibling::button[1]").click()
    await shot(page, "s2_judge_reply_form")
    await judge_form(page, aid, map_uuid).locator("xpath=preceding-sibling::button[1]").click()   # close again; judge_reply reopens
    msg = await judge_reply(page, aid, map_uuid, {"r1": "280.50", "r2": "150", "r3": ""}, ready="21:30")
    check("click Send reply on the map shop -> 'sent'", msg == "sent", msg)
    st = ask_status(aid)
    by = {s["shopID"]: s for s in st["shops"]}
    check("ask state replied, winner is the map shop", st["state"] == "replied" and st.get("winnerShopID") == map_uuid,
          f"state={st['state']}")
    items = {i["itemID"]: i for i in by[map_uuid]["items"]}
    check("prices stored in paise, empty item = not available, total correct",
          items["r1"].get("pricePaise") == 28050 and items["r2"].get("pricePaise") == 15000 and items["r3"]["available"] is False
          and by[map_uuid].get("totalPaise") == 43050, f"total={by[map_uuid].get('totalPaise')}")
    check("ready-by stored as today 21:30 IST", (by[map_uuid].get("readyBy") or "").endswith("T21:30:00+05:30"), by[map_uuid].get("readyBy") or "")
    check("the other shops became not_needed", by[app_style]["state"] == "not_needed" and by["s3"]["state"] == "not_needed",
          f"{by[app_style]['state']}, {by['s3']['state']}")
    text = await block.inner_text()
    check("reloaded judge page shows replied and no more Reply buttons for this ask",
          "replied" in text and await block.locator("button[data-reply-toggle]").count() == 0, text.replace("\n", " | ")[:140])
    await shot(page, "s2_judge_after_reply")
    # second reply from the same shop: from the stale tab (browser) and through the API
    await judge_form(stale, aid, map_uuid).locator("xpath=preceding-sibling::button[1]").click()
    await judge_form(stale, aid, map_uuid).locator('input[data-item="r1"]').fill("1")
    await judge_form(stale, aid, map_uuid).locator("input.rb").fill("20:00")
    await clear_msg(stale)
    await judge_form(stale, aid, map_uuid).locator('button[type="submit"]').click()
    msg = await after_post(stale)
    check("second reply of the same shop from a stale tab is refused (error 409)", msg == "error 409", msg)
    code, _ = api("POST", f"/judge/shop/{aid}/reply", "admin", {"shopID": map_uuid, "items": [{"itemID": "r1", "available": False}, {"itemID": "r2", "available": False}, {"itemID": "r3", "available": False}]})
    check("second reply through the API refused (409)", code == 409, f"http {code}")
    code, _ = api("POST", f"/judge/shop/{aid}/reply", "admin", {"shopID": "s3", "items": []})
    check("a reply for a 'not needed' shop is refused too (409)", code == 409, f"http {code}")
    check("first reply is unchanged after the refused attempts", ask_status(aid)["winnerShopID"] == map_uuid
          and {s["shopID"]: s for s in ask_status(aid)["shops"]}[map_uuid]["totalPaise"] == 43050)

    # ---- the shop's own link, as the app builds the message, opened on a phone
    aid2, links2 = create_ask(shops)
    tmpl = next(t for t in json.loads((HERE.parent / "engine/catalogue/message_templates.json").read_text())
                if t["id"] == "shop_ask_en_whatsapp")["text"]
    message = tmpl.replace("{items}", "Telma 40 x30").replace("{pickup_hint}", "6:30 PM").replace("{reply_link}", links2[map_uuid])
    found = re.search(r"https?://\S+/shop/reply/[\w-]+", message)
    check("reply link found inside the WhatsApp message text the app builds", found is not None and found.group(0) == links2[map_uuid])
    sp = await mob.new_page()
    swatch = Watch(sp, "shop")
    resp = await sp.goto(found.group(0))
    check("shop reply link opens on the phone (200, CSP + no-store headers)",
          resp.status == 200 and "default-src 'none'" in (resp.headers.get("content-security-policy") or "")
          and resp.headers.get("cache-control") == "no-store", f"http {resp.status}")
    body = await sp.inner_text("body")
    check("page lists the 3 items and the Hindi labels", all(x in body for x in ("Telma 40", "Pan 40", "Dolo 650", "उपलब्ध", "Sharma Medical Store")))
    vp = await sp.evaluate("[window.innerWidth, document.querySelector('meta[name=viewport]') !== null]")
    check("mobile viewport 390 wide, viewport meta present, no sideways scroll", vp == [390, True] and await horizontal_overflow(sp) <= 0, f"{vp}")
    await shot(sp, "s2_shop_reply_mobile", full=True)
    # error path first: 'Available' without a price
    await sp.locator('input[name="a0"][value="1"]').check()
    await sp.locator('input[name="a1"][value="0"]').check()
    await sp.locator('input[name="a2"][value="0"]').check()
    await sp.get_by_role("button", name=re.compile("Send")).click()
    await sp.wait_for_load_state("load")
    body = await sp.inner_text("body")
    check("'Available' without a price: friendly error page, nothing stored", "Could not send" in body and shop_state(aid2, map_uuid) == "asked", body.replace("\n", " | ")[:80])
    await sp.go_back()
    await sp.reload()
    await sp.locator('input[name="a0"][value="1"]').check()
    await sp.locator('input[name="p0"]').fill("312.75")
    await sp.locator('input[name="a1"][value="0"]').check()
    await sp.locator('input[name="a2"][value="1"]').check()
    await sp.locator('input[name="p2"]').fill("49")
    await sp.locator('input[name="readyBy"]').fill("19:15")
    await sp.get_by_role("button", name=re.compile("Send")).click()
    await sp.wait_for_load_state("load")
    body = await sp.inner_text("body")
    check("phone form submit shows the thank-you page", "Thanks, your reply has been sent" in body and "धन्यवाद" in body)
    await shot(sp, "s2_shop_thanks_mobile")
    st = ask_status(aid2)
    sh = {s["shopID"]: s for s in st["shops"]}[map_uuid]
    items = {i["itemID"]: i for i in sh["items"]}
    check("stored: r1 31275 paise, r2 not available, r3 4900, total 36175, ready 19:15",
          items["r1"].get("pricePaise") == 31275 and items["r2"]["available"] is False and items["r3"].get("pricePaise") == 4900
          and sh["totalPaise"] == 36175 and (sh.get("readyBy") or "").endswith("T19:15:00+05:30"), f"total={sh.get('totalPaise')} ready={sh.get('readyBy')}")
    await sp.reload()
    body = await sp.inner_text("body")
    check("reload of the thank-you page (browser re-posts the form) says 'already sent', not an error, no form",
          "already sent" in body and "Could not send" not in body and await sp.locator("form").count() == 0, body.replace("\n", " | ")[:80])
    await sp.goto(links2[map_uuid])
    check("opening the link again (GET) shows the thank-you text, no form", "Thanks, your reply has been sent" in await sp.inner_text("body") and await sp.locator("form").count() == 0)
    # the other shop's phone: no longer needed
    op = await mob.new_page()
    await op.goto(links2["s3"])
    body = await op.inner_text("body")
    check("another shop's link now says 'no longer needed'", "no longer needed" in body and "ज़रूरत नहीं" in body)
    r = await op.request.post(links2["s3"], form={"a0": "0", "a1": "0", "a2": "0"})
    check("POST to a not-needed shop's link is refused (409)", r.status == 409, f"http {r.status}")
    check("no dialogs / JS errors on shop pages", not swatch.dialogs and not swatch.page_errors and not swatch.real_errors(),
          f"{swatch.dialogs} {swatch.page_errors + swatch.real_errors()}")
    await desk.close()
    await mob.close()


async def scenario_3(browser):
    """Lab booking: judge buttons by clicking, lab reply page on mobile, fasting reminder 21:00 IST the evening before."""
    desk = await new_context(browser, "desktop")
    mob = await new_context(browser, "mobile")
    fasting = [{"testID": "hba1c", "name": "HbA1c", "fasting": True}, {"testID": "lipid", "name": "Lipid profile", "fasting": True}]
    slot = tomorrow_slot(8)
    expected_reminder = f"{(slot.date() - timedelta(days=1)).isoformat()}T21:00:00+05:30"
    # an order with a lab seller, so Late posting also has to reach the order (Plan B)
    oid, plan = create_order([seller("chem1"), seller("lab1", "lab"), seller("chem2")],
                             [line("a", "chem1"), line("t1", "lab1", 45000)])
    await poll(lambda: (api("GET", f"/status/{oid}")[1] or {}).get("ready"), 15)
    bid_a, _ = create_booking(fasting, slot)
    bid_b, _ = create_booking([{"testID": "tsh", "name": "TSH"}], slot, lab_name="Metropolis", order_id=oid, seller_id="lab1")
    page, watch, _ = await open_judge(desk)
    ra, rb = page.locator("div.o", has_text=f"booking {bid_a}"), page.locator("div.o", has_text=f"booking {bid_b}")
    check("both bookings listed with the five buttons",
          await ra.locator("button[data-lab]").count() == 5 and await rb.locator("button[data-lab]").count() == 5)

    async def press(bid: str, kind: str, want: str | None = None) -> str:
        await clear_msg(page)
        await page.locator(f'button[data-lab="{bid}"][data-k="{kind}"]').click()
        return await after_post(page)

    t0 = time.time()
    check("A: click Confirm -> sent", await press(bid_a, "confirmed") == "sent")
    s = booking_status(bid_a)
    check("A: state confirmed, fasting reminder stored = 21:00 IST the evening before", s["state"] == "confirmed" and s.get("fastingReminderAt") == expected_reminder,
          f"{s.get('state')} reminder={s.get('fastingReminderAt')} expected={expected_reminder}")
    check("A: reloaded judge page shows 'confirmed'", "confirmed" in await ra.inner_text())
    check("A: click Collected -> sent", await press(bid_a, "collected") == "sent")
    s = booking_status(bid_a)
    check("A: collected with a report due time", s["state"] == "collected" and bool(s.get("reportDueAt")), s.get("reportDueAt") or "")
    check("A: click Report ready -> done", await press(bid_a, "report_ready") == "sent" and booking_status(bid_a)["state"] == "done")
    msg = await press(bid_a, "collected")
    check("A: illegal button (Collected after done) -> visible 'error 409', page keeps working", msg == "error 409", msg)
    m = await press(bid_b, "confirmed")
    check("B: click Confirm -> sent", m == "sent", m)
    check("B: click Late posting -> note stored", await press(bid_b, "phlebotomist_late") == "sent"
          and booking_status(bid_b).get("note") == "Phlebotomist is late")
    snap, t = await poll(lambda: (lambda s: s if s and s["state"] == "needs_proposal" else None)(api("GET", f"/status/{oid}")[1]), 4)
    check("B: Late posting reached the linked ORDER (needs_proposal, Plan B starts)", snap is not None, f"{t}s")
    check("B: click Sample rejected -> rejected", await press(bid_b, "sample_rejected") == "sent" and booking_status(bid_b)["state"] == "rejected")
    await shot(page, "s3_judge_lab")
    check("all five judge lab buttons were clicked in the browser (took %.1fs)" % (time.time() - t0), True)

    # ---- the lab's own page on a phone
    bid_c, link_c = create_booking(fasting, slot)
    lp = await mob.new_page()
    lwatch = Watch(lp, "lab")
    resp = await lp.goto(link_c)
    body = await lp.inner_text("body")
    check("lab reply page opens on the phone with tests, fasting label, slot, address",
          resp.status == 200 and "HbA1c" in body and "Fasting" in body and "खाली पेट" in body and "08:00 AM" in body and "Muradnagar" in body,
          f"http {resp.status}")
    ov = await horizontal_overflow(lp)
    check("mobile viewport 390 wide, no sideways scroll", await lp.evaluate("window.innerWidth") == 390 and ov <= 0, f"overflow {ov}px")
    await shot(lp, "s3_lab_reply_mobile", full=True)
    await lp.get_by_role("button", name=re.compile("Confirm this slot")).click()
    await lp.wait_for_load_state("load")
    body = await lp.inner_text("body")
    s = booking_status(bid_c)
    check("C: lab clicks 'Confirm this slot' -> thank-you, booking confirmed, reminder 21:00 IST the evening before",
          "Thanks" in body and s["state"] == "confirmed" and s.get("fastingReminderAt") == expected_reminder, f"{s.get('state')} {s.get('fastingReminderAt')}")
    await lp.goto(link_c)
    check("C: reopening the link: 'already answered', no buttons", "answered" in await lp.inner_text("body") and await lp.locator("button").count() == 0)
    r = await lp.request.post(link_c, form={"action": "decline"})
    check("C: a second answer is refused (409) and the booking stays confirmed", r.status == 409 and booking_status(bid_c)["state"] == "confirmed", f"http {r.status}")

    bid_d, link_d = create_booking(fasting, slot)
    await lp.goto(link_d)
    new_slot = tomorrow_slot(9, days=3)
    await lp.locator('input[name="slot"]').fill(new_slot.strftime("%Y-%m-%dT%H:%M"))
    await lp.locator('input[name="fee"]').fill("150.50")
    await lp.get_by_role("button", name=re.compile("Propose another slot")).click()
    await lp.wait_for_load_state("load")
    s = booking_status(bid_d)
    exp = f"{(new_slot.date() - timedelta(days=1)).isoformat()}T21:00:00+05:30"
    check("D: lab proposes another slot + fee: stored, reminder moves with the new slot",
          s["state"] == "confirmed" and s.get("slot", "").startswith(new_slot.strftime("%Y-%m-%dT09:00")) and s.get("feePaise") == 15050
          and s.get("fastingReminderAt") == exp and s.get("note") == "Lab proposed another slot", f"{s.get('slot')} fee={s.get('feePaise')} rem={s.get('fastingReminderAt')}")
    bid_e, link_e = create_booking([{"testID": "tsh", "name": "TSH"}], slot, address=None)
    await lp.goto(link_e)
    check("E: visit-the-lab booking says home collection 'No'", "No / नहीं" in await lp.inner_text("body"))
    await lp.get_by_role("button", name=re.compile("Cannot do")).click()
    await lp.wait_for_load_state("load")
    s = booking_status(bid_e)
    check("E: 'Cannot do' -> rejected, and no fasting reminder (no fasting test)", s["state"] == "rejected" and not s.get("fastingReminderAt"), s.get("state", ""))
    check("no dialogs / JS errors on lab pages", not lwatch.dialogs and not lwatch.page_errors and not lwatch.real_errors())
    await desk.close()
    await mob.close()


async def scenario_4(browser):
    """Browser security checks."""
    desk = await new_context(browser, "desktop")
    mob = await new_context(browser, "mobile")
    evil_shops = [{"shopID": EVIL_IMG, "name": EVIL_SCRIPT, "distanceM": 100},
                  {"shopID": "s2", "name": EVIL_IMG, "distanceM": 200}]
    evil_items = [{"itemID": EVIL_IMG, "name": EVIL_SCRIPT, "quantity": 2}, {"itemID": "ok", "name": EVIL_IMG, "quantity": 1}]
    aid, links = create_ask(evil_shops, evil_items)
    bid, link = create_booking([{"testID": "t1", "name": EVIL_SCRIPT, "fasting": True}, {"testID": EVIL_IMG, "name": EVIL_IMG}],
                               tomorrow_slot(), lab_name=EVIL_SCRIPT, address=EVIL_IMG[:290])
    aid2, links = create_ask(evil_shops, evil_items)     # a second ask for the phone-side checks (the first one gets answered by the judge)
    oid, _plan = create_order([seller(EVIL_IMG), seller("s2")], [line("a", EVIL_IMG), line("b", "s2")])
    await poll(lambda: (api("GET", f"/status/{oid}")[1] or {}).get("ready"), 15)

    page, w, resp = await open_judge(desk)
    html = await page.content()
    check("judge page: payloads are in the page as TEXT (no live <script>/<img onerror>)",
          await page.locator("script").count() == 1 and await page.locator("img").count() == 0
          and EVIL_SCRIPT in await page.inner_text("body") and EVIL_IMG in await page.inner_text("body"))
    await asyncio.sleep(0.5)
    check("judge page: nothing executed (window.__xss unset, no dialog, no JS error)",
          await page.evaluate("window.__xss") is None and not w.dialogs and not w.page_errors and not w.real_errors(), f"{w.dialogs} {w.page_errors}")
    await shot(page, "s4_xss_judge")
    # act on the weird ids: the reply form posts the exact shopID/itemID back, the Cancel button the exact seller id
    msg = await judge_reply(page, aid, EVIL_IMG, {EVIL_IMG: "10", "ok": ""}, ready="18:00")
    check("judge: Reply on a shop whose id contains quotes/HTML posts the exact id (stored as replied)",
          msg == "sent" and shop_state(aid, EVIL_IMG) == "replied", msg)
    await clear_msg(page)
    await page.locator(f'button[data-o="{oid}"][data-s="{css(EVIL_IMG)}"][data-k="cancelled"]').click()
    msg = await after_post(page)
    snap, _ = await poll(lambda: (lambda s: s if s and s["state"] == "needs_proposal" else None)(api("GET", f"/status/{oid}")[1]), 4)
    check("judge: Cancel on a seller whose id is an HTML payload reaches that exact seller", msg == "sent" and snap is not None)

    sp = await mob.new_page()
    sw = Watch(sp, "shop")
    resp = await sp.goto(links["s2"])
    body = await sp.inner_text("body")
    check("shop reply page: shop/item names shown as text, nothing executed",
          resp.status == 200 and "script" in body and await sp.locator("form img, h1 img, body img").count() == 0
          and await sp.evaluate("window.__xss") is None and not sw.dialogs)
    await shot(sp, "s4_xss_shop_mobile", full=True)
    # a hostile value in the one free-text-like field (readyBy) -> error page, escaped
    await sp.locator('input[name="a0"][value="0"]').check()
    await sp.locator('input[name="a1"][value="1"]').check()
    await sp.locator('input[name="p1"]').fill("5")
    await sp.evaluate("""(v) => { const i = document.querySelector('input[name=readyBy]'); i.type = 'text'; i.value = v; }""", EVIL_IMG)
    await sp.get_by_role("button", name=re.compile("Send")).click()
    await sp.wait_for_load_state("load")
    body = await sp.inner_text("body")
    check("hostile readyBy -> 'Could not send' page, payload not executed, nothing stored",
          "Could not send" in body and await sp.locator("img").count() == 0 and await sp.evaluate("window.__xss") is None
          and not sw.dialogs and shop_state(aid2, "s2") == "asked", body.replace("\n", " | ")[:100])
    check("shop reply page: no dialogs, no JS errors", not sw.dialogs and not sw.page_errors and not sw.real_errors())

    lp = await mob.new_page()
    lw = Watch(lp, "lab")
    await lp.goto(link)
    body = await lp.inner_text("body")
    check("lab reply page: test/lab names and address shown as text, nothing executed",
          EVIL_SCRIPT in body and await lp.locator("img").count() == 0 and await lp.evaluate("window.__xss") is None and not lw.dialogs and not lw.page_errors)
    await shot(lp, "s4_xss_lab_mobile", full=True)
    csp = (await lp.request.get(link)).headers.get("content-security-policy") or ""
    check("CSP on reply pages forbids scripts and external loads", all(tok in csp for tok in ("default-src 'none'", "form-action 'self'", "frame-ancestors 'none'")), csp[:60])

    # ---- keys
    bad, _, resp = await open_judge(desk, key="definitely-wrong")
    body = await bad.inner_text("body")
    check("judge page with a wrong key -> 401, no order/ask data in the body", resp.status == 401 and "Test order" not in body and "Ask " not in body, f"http {resp.status}")
    await shot(bad, "s4_wrong_key")
    nokey = await desk.new_page()
    r = await nokey.goto(f"{BASE}/judge")
    check("judge page with no key -> 401", r.status == 401, f"http {r.status}")
    for path in ("/judge/orders", "/judge/shop/asks", "/judge/lab/bookings"):
        p = await desk.new_page()
        r = await p.goto(f"{BASE}{path}?k={ADMIN}")
        check(f"{path}?k=<admin key> -> 401 (header only)", r.status == 401, f"http {r.status}")
        await p.close()
    for path, key in ((f"/shop/{aid}/status", INSTALL), (f"/status/{oid}", INSTALL), (f"/lab/{bid}/status", INSTALL), ("/judge/orders", INSTALL)):
        p = await desk.new_page()
        r = await p.goto(f"{BASE}{path}?k={key}")
        check(f"{path.split('/')[1]} endpoint with ?k=<key> in the URL -> 401", r.status == 401, f"http {r.status}")
        await p.close()
    r = await desk.request.get(f"{BASE}/judge/orders")
    check("JSON endpoint without any key -> 401", r.status == 401)
    r = await desk.request.get(f"{BASE}/judge/shop/asks", headers={"X-Install-Key": INSTALL})
    check("admin JSON endpoint with the INSTALL key -> 401", r.status == 401)
    r = await desk.request.get(f"{BASE}/judge/shop/asks", headers={"X-Admin-Key": ADMIN})
    body = await r.text()
    check("admin JSON with the right header -> 200 and no reply tokens/urls in it", r.status == 200 and "/shop/reply/" not in body and "token" not in body.lower())
    await desk.close()
    await mob.close()


async def scenario_5(browser):
    """Robustness: reload while pending, two tabs at once, very long text, Hindi."""
    desk = await new_context(browser, "desktop")
    mob = await new_context(browser, "mobile")
    shops = [{"shopID": "p1", "name": "Pending Chemist", "distanceM": 100}, {"shopID": "p2", "name": HINDI, "distanceM": 200},
             {"shopID": "p3", "name": "Third", "distanceM": 300}]
    aid, links = create_ask(shops)
    page, w, _ = await open_judge(desk)
    block = page.locator("div.o", has_text=f"Ask {aid}")
    await judge_form(page, aid, "p1").locator("xpath=preceding-sibling::button[1]").click()
    await judge_form(page, aid, "p1").locator('input[data-item="r1"]').fill("55")
    for _ in range(3):
        await page.reload()
    text = await block.inner_text()
    check("3 reloads during a pending ask: still waiting, shops still 'asked', Reply buttons present",
          ask_status(aid)["state"] == "waiting" and await block.locator("button[data-reply-toggle]").count() == 3 and text.count("asked") >= 3)
    check("typed-but-unsent values are dropped on reload, nothing was stored", await judge_form(page, aid, "p1").locator('input[data-item="r1"]').input_value() == ""
          and shop_state(aid, "p1") == "asked")
    check("Hindi shop name renders as the exact string on the judge page", HINDI in await block.inner_text())
    sp = await mob.new_page()
    await sp.goto(links["p2"])
    for _ in range(2):
        await sp.reload()
    check("reload of the phone page during a pending ask: form is back, Hindi heading intact",
          await sp.locator("h1").inner_text() == HINDI and await sp.locator("form").count() == 1)
    await shot(sp, "s5_hindi_shop_mobile", full=True)

    # ---- two tabs replying at once, 3 rounds
    wins = []
    for rnd in range(3):
        aid2, links2 = create_ask([{"shopID": "x1", "name": f"Race A{rnd}", "distanceM": 1}, {"shopID": "x2", "name": f"Race B{rnd}", "distanceM": 2}, {"shopID": "x3", "name": "Race C", "distanceM": 3}])
        pa, pb = await mob.new_page(), await mob.new_page()
        await pa.goto(links2["x1"])
        await pb.goto(links2["x2"])
        for p, price in ((pa, "10"), (pb, "20")):
            await p.locator('input[name="a0"][value="1"]').check()
            await p.locator('input[name="p0"]').fill(price)
            await p.locator('input[name="a1"][value="0"]').check()
            await p.locator('input[name="a2"][value="0"]').check()
            await p.locator('input[name="readyBy"]').fill("18:00")
        await asyncio.gather(pa.get_by_role("button", name=re.compile("Send")).click(), pb.get_by_role("button", name=re.compile("Send")).click())
        await asyncio.gather(pa.wait_for_load_state("load"), pb.wait_for_load_state("load"))
        texts = [await pa.inner_text("body"), await pb.inner_text("body")]
        st = ask_status(aid2)
        states = sorted(s["state"] for s in st["shops"] if s["shopID"] in ("x1", "x2"))
        ok = states == ["not_needed", "replied"] and st["state"] == "replied" and sum("reply has been sent" in t for t in texts) == 1 \
            and sum("no longer needed" in t for t in texts) == 1
        wins.append(ok)
        check(f"race {rnd + 1}/3: two shops' tabs press Send together -> exactly one wins", ok, f"states={states}, pages={[t.split(chr(10))[0] for t in texts]}")
        await pa.close()
        await pb.close()
    # same shop, same link, two tabs
    for rnd in range(3):
        aid3, links3 = create_ask([{"shopID": "y1", "name": "Same link", "distanceM": 1}])
        pa, pb = await mob.new_page(), await mob.new_page()
        await pa.goto(links3["y1"])
        await pb.goto(links3["y1"])
        for p in (pa, pb):
            await p.locator('input[name="a0"][value="0"]').check()
            await p.locator('input[name="a1"][value="0"]').check()
            await p.locator('input[name="a2"][value="0"]').check()
        await asyncio.gather(pa.get_by_role("button", name=re.compile("Send")).click(), pb.get_by_role("button", name=re.compile("Send")).click())
        await asyncio.gather(pa.wait_for_load_state("load"), pb.wait_for_load_state("load"))
        texts = [await pa.inner_text("body"), await pb.inner_text("body")]
        ok = sum("Thanks, your reply has been sent" in t for t in texts) == 1 and sum("already sent" in t for t in texts) == 1 and shop_state(aid3, "y1") == "replied"
        check(f"same link in two tabs {rnd + 1}/3: exactly one reply is accepted", ok, f"{[t.split(chr(10))[0] for t in texts]}")
        await pa.close()
        await pb.close()
    # judge tab vs shop phone at once
    aid4, links4 = create_ask([{"shopID": "z1", "name": "Judge vs shop", "distanceM": 1}, {"shopID": "z2", "name": "Other", "distanceM": 2}])
    jp, _, _ = await open_judge(desk)
    pb = await mob.new_page()
    await pb.goto(links4["z2"])
    await pb.locator('input[name="a0"][value="0"]').check()
    await pb.locator('input[name="a1"][value="0"]').check()
    await pb.locator('input[name="a2"][value="0"]').check()
    await judge_form(jp, aid4, "z1").locator("xpath=preceding-sibling::button[1]").click()
    await judge_form(jp, aid4, "z1").locator('input[data-item="r1"]').fill("9")
    await judge_form(jp, aid4, "z1").locator("input.rb").fill("17:00")
    await asyncio.gather(judge_form(jp, aid4, "z1").locator('button[type="submit"]').click(), pb.get_by_role("button", name=re.compile("Send")).click())
    await asyncio.sleep(1.5)
    st = ask_status(aid4)
    states = sorted(s["state"] for s in st["shops"])
    check("judge-page reply and phone reply at the same moment: exactly one wins", states == ["not_needed", "replied"], f"{states}")

    # ---- very long text
    long_name = "L" * 100   # the maximum the server accepts, no spaces: worst case for the layout
    aid5, links5 = create_ask([{"shopID": "l1", "name": long_name, "distanceM": 5}], [{"itemID": "li", "name": "M" * 100, "quantity": 1}])
    lp = await mob.new_page()
    await lp.goto(links5["l1"])
    over = await horizontal_overflow(lp)
    check("100-letter shop and item names on the phone: page still loads", await lp.locator("form").count() == 1)
    check("100-letter unbroken names do not push the phone page sideways", over <= 0, f"overflow {over}px")
    await shot(lp, "s5_long_name_mobile", full=True)
    jp2, _, _ = await open_judge(desk)
    check("100-letter names on the judge page: loads", await jp2.locator("div.o", has_text=f"Ask {aid5}").count() == 1)
    code, _ = api("POST", "/shop/ask", body={"items": shop_items(), "shops": [{"shopID": "q", "name": "N" * 101}], "pickupBy": (ist_now() + timedelta(hours=1)).isoformat()})
    check("101-letter shop name refused with 422 (limit enforced)", code == 422, f"http {code}")
    booking_long = "A" * 290
    bid, link = create_booking([{"testID": "t", "name": "T" * 100}], tomorrow_slot(), lab_name="B" * 100, address=booking_long)
    lbp = await mob.new_page()
    await lbp.goto(link)
    over = await horizontal_overflow(lbp)
    check("290-letter address / 100-letter lab and test name on the lab page: no sideways scroll", over <= 0, f"overflow {over}px")
    await shot(lbp, "s5_long_lab_mobile", full=True)
    r = await lp.request.post(links5["l1"], data="a0=0&readyBy=" + "9" * 40_000, headers={"Content-Type": "application/x-www-form-urlencoded"})
    check("40 KB form body refused with 413 (shop page)", r.status == 413, f"http {r.status}")
    r = await lp.request.post(link, data="action=confirm&x=" + "9" * 40_000, headers={"Content-Type": "application/x-www-form-urlencoded"})
    check("40 KB form body refused with 413 (lab page)", r.status == 413, f"http {r.status}")
    check("the shop could still answer after the refused huge post", shop_state(aid5, "l1") == "asked")
    # Hindi in a lab / tests
    bid, link = create_booking([{"testID": "t", "name": "थायरॉइड प्रोफ़ाइल", "fasting": True}], tomorrow_slot(), lab_name="श्री लाल पैथ लैब", address="गांधी नगर, मुरादनगर")
    hp = await mob.new_page()
    await hp.goto(link)
    body = await hp.inner_text("body")
    check("Hindi lab, test and address render as the exact strings", all(x in body for x in ("श्री लाल पैथ लैब", "थायरॉइड प्रोफ़ाइल", "गांधी नगर, मुरादनगर")))
    await shot(hp, "s5_hindi_lab_mobile", full=True)
    jh, _, _ = await open_judge(desk)
    check("Hindi lab name on the judge page", "श्री लाल पैथ लैब" in await jh.inner_text("body"))
    await desk.close()
    await mob.close()


# ================================================================ main

async def main() -> int:
    global BASE, SHOTS
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="http://localhost:8000")
    ap.add_argument("--shots", default="/tmp/k20")
    ap.add_argument("--only", default="", help="comma list of scenario numbers, e.g. 1,3")
    a = ap.parse_args()
    BASE, SHOTS = a.base.rstrip("/"), Path(a.shots)
    wanted = {x for x in a.only.split(",") if x} or {"1", "2", "3", "4", "5"}
    SHOTS.mkdir(parents=True, exist_ok=True)
    code, _ = api("GET", "/health", who="none")
    if code != 200:
        print("FAIL server not reachable at", BASE, "- run `bash start_all.sh` first")
        return 1
    code, _ = api("POST", "/reset?scope=demo", "admin", {})
    print(f"reset demo data: http {code}")
    t_all = time.time()
    async with async_playwright() as pw:
        browser = await pw.chromium.launch(headless=True)
        for n, fn in (("1", scenario_1), ("2", scenario_2), ("3", scenario_3), ("4", scenario_4), ("5", scenario_5)):
            if n not in wanted:
                continue
            current[0] = f"S{n}"
            t0 = time.time()
            try:
                await fn(browser)
            except Exception as e:  # a crash is a FAIL, never a silent skip
                check(f"scenario crashed: {type(e).__name__}", False, (traceback.extract_tb(e.__traceback__)[-1].name + ":" + str(traceback.extract_tb(e.__traceback__)[-1].lineno) + " " + (str(e).splitlines()[0][:160] if str(e) else "")))
            timings[f"S{n}"] = round(time.time() - t0, 1)
        await browser.close()
    current[0] = "NET"
    external = sorted({f"{h}{p}" for h, p in requests_seen if h not in LOCAL_HOSTS})
    hosts = sorted({h for h, _ in requests_seen})
    check("no request to any non-localhost host in the whole run", not external, f"{len(requests_seen)} requests, hosts={hosts}" + (f" EXTERNAL={external[:5]}" if external else ""))
    code, _ = api("POST", "/reset?scope=demo", "admin", {})
    fails = [r for r in rows if not r[2]]
    print("\nscenario  checks  fail  seconds")
    for s in sorted({r[0] for r in rows}):
        sel = [r for r in rows if r[0] == s]
        print(f"{s:8}  {len(sel):6}  {sum(not r[2] for r in sel):4}  {timings.get(s, '-')}")
    print(f"RESULT {'PASS' if not fails else 'FAIL'}: {len(rows) - len(fails)}/{len(rows)} checks, {round(time.time() - t_all)}s; screenshots in {SHOTS}")
    return 0 if not fails else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
