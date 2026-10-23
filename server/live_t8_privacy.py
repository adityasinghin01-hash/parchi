"""T8 (server half): 'Delete everything' clears every row this install created on the iMac: orders, placements, audit,
approvals, shop asks, lab bookings, true-price reports. Runs on the iMac against the live API."""
import json, sqlite3, sys, time, urllib.error, urllib.request
BASE = "http://localhost:8000"
INSTALL = open("data/sim_install.key").read().strip(); ADMIN = open("data/admin.key").read().strip()
def call(method, path, key="install", body=None):
    h = {"Content-Type": "application/json"}
    if key == "install": h["X-Install-Key"] = INSTALL
    if key == "admin": h["X-Admin-Key"] = ADMIN
    for _ in range(6):
        try:
            with urllib.request.urlopen(urllib.request.Request(BASE + path, method=method, headers=h, data=None if body is None else json.dumps(body).encode()), timeout=10) as r:
                return r.status, json.loads(r.read() or b"null")
        except urllib.error.HTTPError as e:
            if e.code == 429: time.sleep(2); continue
            return e.code, None
def counts():
    con = sqlite3.connect("data/parchi.db")
    tables = [r[0] for r in con.execute("select name from sqlite_master where type='table' and name not like 'sqlite_%' and name not in ('keys','seller_reliability')")]
    return {t: con.execute(f"select count(*) from {t}").fetchone()[0] for t in tables}
ok = []
def check(n, c, d=""): ok.append(bool(c)); print(("PASS " if c else "FAIL ") + n + (f" ({d})" if d else ""))
call("POST", "/reset?scope=demo", "admin", {})
before0 = counts()
check("start clean", sum(before0.values()) == 0, str(before0))
plan = {"lines": [{"itemID": "a", "sellerID": "s1", "price": 1000, "isSubstitute": False}], "feesBySeller": {}, "itemsTotal": 1000, "feesTotal": 0, "stops": 1, "maxEtaMinutes": 60, "medicinesReadyMinutes": 60, "reportsReadyMinutes": 0}
c, o = call("POST", "/order", body={"plan": plan, "sellers": [{"id": "s1", "name": "s1", "channel": "localChemist", "etaMinutes": 60, "requiresVisit": True}]}) if False else (None, None)
req = urllib.request.Request(BASE + "/order", method="POST", headers={"Content-Type": "application/json", "X-Install-Key": INSTALL, "Idempotency-Key": "t8-" + str(time.time())}, data=json.dumps({"plan": plan, "sellers": [{"id": "s1", "name": "s1", "channel": "localChemist", "etaMinutes": 60, "requiresVisit": True}]}).encode())
oid = json.loads(urllib.request.urlopen(req, timeout=10).read())["orderID"]
call("POST", f"/judge/{oid}/event", "admin", {"sellerID": "s1", "kind": "confirmed"})
call("POST", "/shop/ask", body={"items": [{"itemID": "x", "name": "Telma", "quantity": 30}], "shops": [{"shopID": "s1", "name": "Shop"}], "pickupBy": "2026-10-24T18:00:00+05:30"})
call("POST", "/lab/book", body={"labID": "l", "labName": "Lab", "tests": [{"testID": "t", "name": "CBC"}], "homeCollection": False, "preferredSlot": "2026-10-25T08:00:00+05:30"})
call("POST", f"/orders/{oid}/paid", body={"sellerID": "s1", "paidPaise": 1200, "itemsPaise": 1000, "pincode": "250001"})
time.sleep(1.5)
mid = counts()
check("server holds data for this install before reset", sum(mid.values()) > 0, str({k: v for k, v in mid.items() if v}))
c, r = call("POST", "/reset", body={})
check("reset accepted", c == 200, f"http {c} {r}")
after = counts()
check("every table is empty after 'Delete everything'", sum(after.values()) == 0, str({k: v for k, v in after.items() if v}) or "all zero")
c, _ = call("GET", f"/status/{oid}")
check("old order no longer readable", c == 404, f"http {c}")
print("NOTE Temporal keeps each workflow's history for 24 h (namespace retention): item ids, prices and seller ids only, no names or phones.")
print("RESULT", "PASS" if all(ok) else "FAIL", f"{sum(ok)}/{len(ok)}")
sys.exit(0 if all(ok) else 1)
