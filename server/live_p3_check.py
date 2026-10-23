"""Live check (T4/T5 evidence) of shop ask + lab booking against the running iMac server."""
import json, re, sys, time, urllib.error, urllib.request
BASE = "http://localhost:8000"
INSTALL = open("data/sim_install.key").read().strip(); ADMIN = open("data/admin.key").read().strip()
ok = []
def call(method, path, key="install", body=None, raw=False, ctype="application/json"):
    h = {"Content-Type": ctype}
    if key == "install": h["X-Install-Key"] = INSTALL
    if key == "admin": h["X-Admin-Key"] = ADMIN
    data = body if isinstance(body, (bytes, type(None))) else json.dumps(body).encode()
    for _ in range(6):
        try:
            with urllib.request.urlopen(urllib.request.Request(BASE + path, method=method, headers=h, data=data), timeout=10) as r:
                t = r.read(); return r.status, (t.decode() if raw else json.loads(t or b"null"))
        except urllib.error.HTTPError as e:
            if e.code == 429: time.sleep(2); continue
            t = e.read(); return e.code, (t.decode() if raw else None)
    return 429, None
def check(name, cond, detail=""):
    ok.append(bool(cond)); print(("PASS " if cond else "FAIL ") + name + (f" ({detail})" if detail else ""))
def poll(fn, timeout=10):
    t = time.time()
    while time.time() - t < timeout:
        v = fn()
        if v: return v
        time.sleep(0.5)
    return None

call("POST", "/reset?scope=demo", "admin", {})
items = [{"itemID": "telma", "name": "Telma", "strength": "40", "quantity": 30}, {"itemID": "pan", "name": "Pan", "strength": "40", "quantity": 15}]
shops = [{"shopID": f"s{i}", "name": f"Shop {i}", "distanceM": 500 * i} for i in range(1, 5)]
c, ask = call("POST", "/shop/ask", body={"items": items, "shops": shops, "pickupBy": "2026-10-24T18:00:00+05:30", "waitMinutes": 10})
check("shop ask created (first group of 3 links)", c == 201 and len(ask["replyLinks"]) == 3, f"http {c}")
aid = ask["askID"]; link = ask["replyLinks"][0]["url"]; path = "/" + link.split("/", 3)[3]
c, page = call("GET", path, key=None, raw=True)
check("shopkeeper reply page opens (HTML, items listed, no key needed)", c == 200 and "Telma" in page and "<form" in page, f"http {c}, {len(page)} bytes")
c, _ = call("POST", path, key=None, body={"items": [{"itemID": "telma", "available": True, "pricePaise": 28000}, {"itemID": "pan", "available": True, "pricePaise": 15000}], "readyBy": "2026-10-24T18:00:00+05:30"})
check("shop reply accepted", c == 200, f"http {c}")
c, st = call("GET", f"/shop/{aid}/status")
check("status shows replied winner with total", c == 200 and st["state"] == "replied" and st.get("winnerShopID") == "s1" and st["shops"][0]["totalPaise"] == 43000, f"state={st and st['state']} total={st and st['shops'][0].get('totalPaise')}")
others = [s["state"] for s in st["shops"] if s["shopID"] in ("s2", "s3")]
check("other shops marked not_needed", others == ["not_needed", "not_needed"], str(others))
c, _ = call("POST", path, key=None, body={"items": [], "readyBy": "2026-10-24T18:00:00+05:30"})
check("second reply from same shop rejected", c in (409, 422), f"http {c}")
c, evil = call("POST", "/shop/ask", body={"items": [{"itemID": "x", "name": "<script>alert(1)</script>", "quantity": 1}], "shops": shops[:1], "pickupBy": "2026-10-24T18:00:00+05:30"})
c2, evilpage = call("GET", "/" + evil["replyLinks"][0]["url"].split("/", 3)[3], key=None, raw=True)
check("HTML escaped on reply page (XSS)", "<script>alert(1)</script>" not in evilpage and "&lt;script&gt;" in evilpage)
c, _ = call("GET", f"/shop/{aid}/status", key=None)
check("status needs the install key", c == 401, f"http {c}")

c, lab = call("POST", "/lab/book", body={"labID": "redcliffe", "labName": "Redcliffe Labs", "tests": [{"testID": "hba1c", "name": "HbA1c", "fasting": True}], "homeCollection": True, "preferredSlot": "2026-10-25T08:00:00+05:30", "addressText": "Muradnagar"})
check("lab booking created", c == 201 and lab.get("replyLink"), f"http {c}")
bid = lab["bookingID"]; lpath = "/" + lab["replyLink"].split("/", 3)[3]
c, lp = call("GET", lpath, key=None, raw=True)
check("lab reply page opens", c == 200 and "<form" in lp, f"http {c}")
c, _ = call("POST", f"/judge/lab/{bid}/event", "admin", {"kind": "confirmed"})
c, ls = call("GET", f"/lab/{bid}/status")
check("lab confirmed with fasting reminder 21:00 the evening before", ls["state"] == "confirmed" and (ls.get("fastingReminderAt") or "").startswith("2026-10-24T21:00"), f"state={ls['state']} reminder={ls.get('fastingReminderAt')}")
print("RESULT", "PASS" if all(ok) else "FAIL", f"{sum(ok)}/{len(ok)} checks")
call("POST", "/reset?scope=demo", "admin", {})
sys.exit(0 if all(ok) else 1)
