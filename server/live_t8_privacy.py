"""T8 (server half): 'Delete everything' clears every row this install created on the iMac: orders, placements, audit,
approvals, shop asks, lab bookings, true-price reports. K30: it also removes the install's WORKFLOWS from Temporal
(order, shop ask, lab booking, refill watch: terminated, then their histories deleted) while a second install's stay.
Runs on the iMac against the live API and the live Temporal:  .venv/bin/python live_t8_privacy.py   (about 3-4 min:
Temporal deletes histories in the background, usually within 1-2 minutes).
It resets ALL data first (admin demo reset), so do not run it while another job is using the stack."""
import asyncio, json, sqlite3, subprocess, sys, time, urllib.error, urllib.request
from datetime import date
BASE = "http://localhost:8000"
TEMPORAL = "localhost:7233"
INSTALL = open("data/sim_install.key").read().strip(); ADMIN = open("data/admin.key").read().strip()
def second_install():  # a throw-away second phone (printed once by `auth issue`, kept in data/k30_b.key)
    try:
        return open("data/k30_b.key").read().strip()
    except FileNotFoundError:
        key = subprocess.run([sys.executable, "-m", "auth", "issue", "k30-b"], capture_output=True, text=True, check=True).stdout.strip()
        with open("data/k30_b.key", "w") as f: f.write(key + "\n")
        return key
OTHER = second_install()
def call(method, path, key="install", body=None, who=None, idem=None):
    h = {"Content-Type": "application/json"}
    if key == "install": h["X-Install-Key"] = who or INSTALL
    if key == "admin": h["X-Admin-Key"] = ADMIN
    if idem: h["Idempotency-Key"] = idem
    for _ in range(6):
        try:
            with urllib.request.urlopen(urllib.request.Request(BASE + path, method=method, headers=h, data=None if body is None else json.dumps(body).encode()), timeout=30) as r:
                return r.status, json.loads(r.read() or b"null")
        except urllib.error.HTTPError as e:
            if e.code == 429: time.sleep(2); continue
            return e.code, None
    return 0, None
def counts():
    con = sqlite3.connect("data/parchi.db")
    tables = [r[0] for r in con.execute("select name from sqlite_master where type='table' and name not like 'sqlite_%' and name not in ('keys','seller_reliability','deleted_orders')")]
    return {t: con.execute(f"select count(*) from {t}").fetchone()[0] for t in tables}
ok = []
def check(n, c, d=""): ok.append(bool(c)); print(("PASS " if c else "FAIL ") + n + (f" ({d})" if d else ""), flush=True)

plan = {"lines": [{"itemID": "a", "sellerID": "s1", "price": 1000, "isSubstitute": False}], "feesBySeller": {}, "itemsTotal": 1000, "feesTotal": 0, "stops": 1, "maxEtaMinutes": 60, "medicinesReadyMinutes": 60, "reportsReadyMinutes": 0}
def populate(who, tag):
    """One order (confirmed), one shop ask, one lab booking, one refill watch for this install. Returns their workflow ids."""
    c, o = call("POST", "/order", who=who, idem=f"t8-{tag}-{time.time()}", body={"plan": plan, "sellers": [{"id": "s1", "name": "s1", "channel": "localChemist", "etaMinutes": 60, "requiresVisit": True}]})
    oid = (o or {}).get("orderID")
    call("POST", f"/judge/{oid}/event", "admin", {"sellerID": "s1", "kind": "confirmed"})
    c2, ask = call("POST", "/shop/ask", who=who, body={"items": [{"itemID": "x", "name": "Telma", "quantity": 30}], "shops": [{"shopID": "s1", "name": "Shop"}], "pickupBy": "2026-10-24T18:00:00+05:30"})
    c3, bk = call("POST", "/lab/book", who=who, body={"labID": "l", "labName": "Lab", "tests": [{"testID": "t", "name": "CBC"}], "homeCollection": False, "preferredSlot": "2026-10-25T08:00:00+05:30"})
    c4, rf = call("POST", "/refill/watch", who=who, body={"items": [{"name": "Metformin", "quantity": 30, "dosesPerDay": "1-0-1"}], "startDate": date.today().isoformat()})
    check(f"{tag}: order, shop ask, lab booking and refill watch created", (c, c2, c3, c4) == (201, 201, 201, 201), f"http {c}/{c2}/{c3}/{c4}")
    if tag == "A":
        call("POST", f"/orders/{oid}/paid", who=who, body={"sellerID": "s1", "paidPaise": 1200, "itemsPaise": 1000, "pincode": "250001"})
    return {"order": "order-" + str(oid), "shop": "shop-" + str((ask or {}).get("askID")), "lab": "lab-" + str((bk or {}).get("bookingID")), "refill": "refill-" + str((rf or {}).get("refillID"))}

async def temporal_state(ids):
    """{workflow id: 'RUNNING'/'TERMINATED'/... or 'NOT_FOUND'} by describe, plus how many a namespace list still shows."""
    from temporalio.client import Client
    from temporalio.service import RPCError, RPCStatusCode
    c = await Client.connect(TEMPORAL)
    out = {}
    for w in ids:
        try: out[w] = (await c.get_workflow_handle(w).describe()).status.name
        except RPCError as e:
            if e.status != RPCStatusCode.NOT_FOUND: raise
            out[w] = "NOT_FOUND"
    listed = set()
    for w in ids:
        async for item in c.list_workflows(f'WorkflowId = "{w}"'): listed.add(item.id)
    return out, listed
def tstate(ids): return asyncio.run(temporal_state(ids))

call("POST", "/reset?scope=demo", "admin", {})
call("POST", "/reset", who=OTHER)  # nothing left of an older run of this script
before0 = counts()
check("start clean", sum(before0.values()) == 0, str(before0))
A = populate(INSTALL, "A")
time.sleep(1.5)
a_only = counts()
check("server holds data for this install before reset", sum(a_only.values()) > 0, str({k: v for k, v in a_only.items() if v}))
B = populate(OTHER, "B")
time.sleep(1.5)
both = counts()
b_part = {t: both[t] - a_only[t] for t in both}
idsA, idsB = list(A.values()), list(B.values())
st, listed = tstate(idsA + idsB)
check("Temporal knows all 8 workflows before reset (A's 4 and B's 4)", all(v != "NOT_FOUND" for v in st.values()) and listed == set(idsA + idsB), str(st))
check("A's order/shop/lab/refill are RUNNING before reset", all(st[w] == "RUNNING" for w in idsA), str({k: st[v] for k, v in A.items()}))
oid = A["order"][len("order-"):]

c, r = call("POST", "/reset", body={})
check("reset accepted", c == 200, f"http {c} {r}")
# The persistent demo stack can also contain this install's tombstoned histories
# from earlier rehearsals. Those are intentionally retried by reset_workflows.
# Below we separately prove all four current A histories disappear and B stays.
check("reset requests deletion of all four current A histories (plus earlier A histories)", isinstance(r, dict) and r.get("workflowsDeleted", 0) >= 4 and r.get("workflowsKept") == 0, str(r))
after = counts()
check("A's rows are gone, B's rows are untouched", after == b_part, "B only: " + str({k: v for k, v in after.items() if v}))
c, _ = call("GET", f"/status/{oid}")
check("old order no longer readable", c == 404, f"http {c}")
c, _ = call("GET", f"/status/{B['order'][len('order-'):]}", who=OTHER)
check("B's order is still readable", c == 200, f"http {c}")

# Temporal deletes closed histories in the background: poll until A's four are gone (describe NOT_FOUND and not listed).
t0 = time.time(); st = listed = None
while time.time() - t0 < 300:
    st, listed = tstate(idsA + idsB)
    if all(st[w] == "NOT_FOUND" for w in idsA) and not (listed & set(idsA)): break
    time.sleep(5)
secs = round(time.time() - t0)
check(f"A's four workflow histories are gone from Temporal (describe = not found, absent from the namespace list) after {secs} s",
      all(st[w] == "NOT_FOUND" for w in idsA) and not (listed & set(idsA)), str({k: st[v] for k, v in A.items()}))
check("B's four workflows are intact and still RUNNING", all(st[w] == "RUNNING" for w in idsB) and set(idsB) <= listed, str({k: st[v] for k, v in B.items()}))

c, r = call("POST", "/reset", who=OTHER, body={})
check("B's own reset accepted", c == 200 and r.get("workflowsDeleted", 0) >= 4 and r.get("workflowsKept") == 0, f"http {c} {r}")
check("every table is empty after both installs 'Delete everything'", sum(counts().values()) == 0, str({k: v for k, v in counts().items() if v}) or "all zero")
t0 = time.time()
while time.time() - t0 < 300:
    st, listed = tstate(idsA + idsB)
    if all(v == "NOT_FOUND" for v in st.values()) and not listed: break
    time.sleep(5)
check(f"all 8 workflows are gone from Temporal after {round(time.time() - t0)} s", all(v == "NOT_FOUND" for v in st.values()) and not listed, str(st))
print("NOTE deleted_orders keeps only random order/install ids for 48 h so a replayed request cannot resurrect a deleted order (no personal data).")
print("NOTE Temporal deletes a workflow's history in the background after DeleteWorkflowExecution (seen: 1 to 2 minutes on the dev server); until then the history (item ids, prices, seller ids, no names or phones) can still be read.")
print("RESULT", "PASS" if all(ok) else "FAIL", f"{sum(ok)}/{len(ok)}")
sys.exit(0 if all(ok) else 1)
