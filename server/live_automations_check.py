"""K23: live end-to-end proof of the automations that only had unit tests, against the RUNNING stack.

A1 reliability, A6 refill, A7 true price, A8 safety net ("did this go through?", replay, worker kill), A5 report chase.
Usage (from server/):  .venv/bin/python live_automations_check.py
Needs Temporal + worker + API already running (bash start_all.sh). Prints PASS/FAIL per check, exit 1 on any FAIL.

How it reaches the timers: the real timers are minutes/days long, and PARCHI_TIME_SCALE is read by the API when a
workflow is started (it is workflow input). So this script starts two EXTRA copies of the same API code on 127.0.0.1:8010
and :8011 with a small time scale, sharing the same database, Temporal server and the running worker. The API on :8000
is only used for a health check and a read-through of the shared database; it is never restarted by this script.
It uses its own two throw-away installs (data/k23_a.key, data/k23_b.key), so other jobs' data is not touched, and it
refuses to run while browser_e2e is running. Keys are read from data/*.key and never printed.
"""
import asyncio, json, os, signal, sqlite3, subprocess, sys, time, urllib.error, urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path
from uuid import uuid4

HERE = Path(__file__).resolve().parent
os.chdir(HERE)
sys.path.insert(0, str(HERE))
BASE = os.environ.get("PARCHI_BASE", "http://localhost:8000")
FAST_PORT, REFILL_PORT, LAB_PORT = 8010, 8011, 8012
FAST_SCALE = 0.02            # orders: the 15 min "did this go through?" check -> 18 s
LAB_SCALE = 0.001            # lab: report due + 6 h chase -> 21.6 s
IST = timezone(timedelta(hours=5, minutes=30))
TEMPORAL = os.environ.get("PARCHI_TEMPORAL", "localhost:7233")
DB = os.environ.get("PARCHI_DB", "data/parchi.db")
ADMIN = Path("data/admin.key").read_text().strip()
RUN = uuid4().hex[:6]
results: list[tuple[str, bool, float]] = []
procs: list[subprocess.Popen] = []
section_name = ""


# ---------- plumbing ----------

def check(name, ok, detail=""):
    results.append((section_name, bool(ok), 0))
    print(("PASS " if ok else "FAIL ") + f"[{section_name}] {name}" + (f" ({detail})" if detail else ""), flush=True)
    return bool(ok)


class Api:
    def __init__(self, base, key=None):
        self.base, self.key = base, key

    def call(self, method, path, body=None, admin=False, headers=None):
        h = {"Content-Type": "application/json", **(headers or {})}
        if admin:
            h["X-Admin-Key"] = ADMIN
        elif self.key:
            h["X-Install-Key"] = self.key
        data = None if body is None else json.dumps(body).encode()
        for _ in range(8):
            try:
                req = urllib.request.Request(self.base + path, method=method, headers=h, data=data)
                with urllib.request.urlopen(req, timeout=15) as r:
                    return r.status, json.loads(r.read() or b"null")
            except urllib.error.HTTPError as e:
                if e.code == 429:  # per-key rate limit: wait it out like a polite client
                    time.sleep(min(int(e.headers.get("Retry-After", "2")), 10)); continue
                try:
                    return e.code, json.loads(e.read() or b"null")
                except Exception:
                    return e.code, None
            except (urllib.error.URLError, TimeoutError, ConnectionError):
                time.sleep(1)
        return 0, None


def wait_for(fn, timeout, every=0.4):
    t0 = time.time()
    while time.time() - t0 < timeout:
        v = fn()
        if v:
            return v
        time.sleep(every)
    return None


def issue_key(label, path):
    p = Path(path)
    if not p.exists() or not p.read_text().strip():
        old = os.umask(0o077)
        try:
            with open(p, "w") as f:
                subprocess.run([sys.executable, "-m", "auth", "issue", label], stdout=f, stderr=subprocess.DEVNULL, check=True)
        finally:
            os.umask(old)
    return p.read_text().strip()


def start_api(port, scale):
    env = dict(os.environ, PARCHI_ADMIN_KEY=ADMIN, PARCHI_TIME_SCALE=str(scale), PARCHI_PUBLIC_URL=f"http://127.0.0.1:{port}")
    p = subprocess.Popen([sys.executable, "-m", "uvicorn", "api:app", "--host", "127.0.0.1", "--port", str(port), "--no-access-log"],
                         cwd=HERE, env=env, stdout=open(f"/tmp/k23_api_{port}.log", "w"), stderr=subprocess.STDOUT)
    procs.append(p)
    api = Api(f"http://127.0.0.1:{port}")
    ok = wait_for(lambda: (api.call("GET", "/health")[1] or {}).get("temporal"), 25)
    if not ok:
        raise RuntimeError(f"extra API on :{port} did not start (see /tmp/k23_api_{port}.log)")
    return p


def mkplan(lines, fees=None, **kw):
    fees = fees or {}
    p = {"lines": lines, "feesBySeller": fees, "itemsTotal": sum(r["price"] for r in lines), "feesTotal": sum(fees.values()),
         "stops": len({r["sellerID"] for r in lines}), "maxEtaMinutes": 120, "medicinesReadyMinutes": 120, "reportsReadyMinutes": 0}
    p.update(kw)
    return p


def line(item, seller, price):
    return {"itemID": item, "sellerID": seller, "price": price, "isSubstitute": False}


def sellers_meta(ids):
    return [{"id": s, "name": s, "channel": "localChemist", "etaMinutes": 120, "requiresVisit": True} for s in ids]


def place(api, lines, extra_sellers=(), key=None, area=None):
    ids = list(dict.fromkeys([r["sellerID"] for r in lines] + list(extra_sellers)))
    body = {"plan": mkplan(lines), "sellers": sellers_meta(ids)}
    if area:
        body["area"] = area
    code, out = api.call("POST", "/order", body, headers={"Idempotency-Key": key or f"k23-{RUN}-{uuid4().hex[:8]}"})
    return code, (out or {}).get("orderID"), body


def status(api, oid):
    return api.call("GET", f"/status/{oid}")[1] or {}


def ready(api, oid, timeout=20):
    return wait_for(lambda: (lambda s: s if s.get("ready") and s.get("sellers") else None)(status(api, oid)), timeout)


def event(oid, seller, kind, api):
    return api.call("POST", f"/judge/{oid}/event", {"sellerID": seller, "kind": kind}, admin=True)[0]


def sql(query, *args):
    con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
    try:
        return con.execute(query, args).fetchall()
    finally:
        con.close()


# ---------- A1 ----------

def a1_reliability(ctx):
    """A1 reliability"""
    api, area = ctx["fast"], f"k23 area {RUN}"
    good, flaky, fresh = f"k23-good-{RUN}", f"k23-flaky-{RUN}", f"k23-new-{RUN}"
    enc = area.replace(" ", "%20")
    code, rows = api.call("GET", f"/reliability?area={enc}")
    check("area starts with no history (every seller on the neutral 0.8 prior)", code == 200 and rows == [], f"http {code} {rows}")
    # (seller, judge events, outcome the order ended with). Delivered / cancelled / late, two sellers, one area.
    plans = [(good, ["confirmed", "shipped", "delivered"], "delivered"), (good, ["confirmed", "delivered"], "delivered"),
             (flaky, ["cancelled"], "cancelled"), (flaky, ["late"], "late"), (flaky, ["confirmed", "delivered"], "delivered")]
    done = 0
    for seller, events, outcome in plans:
        code, oid, _ = place(api, [line("a", seller, 5000)], area=area)
        if not check(f"sandbox order for {seller.split('-')[1]} placed", code == 201 and ready(api, oid), f"http {code}"):
            return
        codes = [event(oid, seller, k, api) for k in events]
        st = wait_for(lambda: (lambda s: s if (s.get("state") == "done" and outcome == "delivered") or
                               (s.get("state") == "needs_proposal" and outcome != "delivered") else None)(status(api, oid)), 12)
        check(f"order driven to '{outcome}'", all(c == 200 for c in codes) and st, f"events {events}, state {st and st['state']}")
        # K26: nothing calls /judge/reliability/record here; the workflow records the finished order itself.
        done += 1
        wait_for(lambda: sum(r["orders"] for r in (api.call("GET", f"/reliability?area={enc}")[1] or [])) >= done or None, 10)
    code, rows = api.call("GET", f"/reliability?area={enc}")
    by = {r["sellerID"]: r for r in rows or []}
    check("good seller: 2 delivered -> (2+4)/(2+5)=0.8571", by.get(good, {}).get("score") == 0.8571 and by[good]["orders"] == 2, str(by.get(good)))
    check("flaky seller: 1 delivered, cancelled, late -> (1+4)/(3+5)=0.625", by.get(flaky, {}).get("score") == 0.625 and by[flaky]["orders"] == 3, str(by.get(flaky)))
    check("scores moved off the 0.8 prior in opposite directions, best seller listed first",
          by.get(good, {}).get("score", 0) > 0.8 > by.get(flaky, {}).get("score", 1) and [r["sellerID"] for r in rows][0] == good)
    check("unknown seller is not listed (the app gives it the 0.8 prior)", fresh not in by)
    code, same = Api(BASE, ctx["key_a"]).call("GET", f"/reliability?area={enc}")
    check(f"the running API on {BASE} returns the same scores (shared database)", code == 200 and same == rows, f"http {code}")
    # Planning: same formula as ParchiCore Planner.reliabilityPenalty = server rank_with_reliability, weight 1 when 'prefer reliable' is on.
    import reliability
    scores = {r["sellerID"]: r["score"] for r in rows}
    cands = [{"sellerID": flaky, "cost": 1000}, {"sellerID": good, "cost": 1050}, {"sellerID": fresh, "cost": 1100}]
    off = [s["sellerID"] for s in reliability.rank_with_reliability(cands, scores, 0)]
    on = [s["sellerID"] for s in reliability.rank_with_reliability(cands, scores, 1)]
    check("reliability OFF: cheapest first (flaky 1000, good 1050, new 1100)", off == [flaky, good, fresh], str([o.split("-")[1] for o in off]))
    check("reliability ON (weight 1): dearer reliable seller beats the cheaper flaky one; unknown seller uses the prior",
          on == [good, fresh, flaky], str([o.split("-")[1] for o in on]) + " (1200, 1320, 1375)")
    check("ranking differs between off and on", off != on)
    # The demo endpoint with the same order id is the same key: it must not count the finished order twice.
    code, oid0, _ = place(api, [line("a", good, 5000)], area=area)
    ready(api, oid0)
    for k in ("delivered",):
        event(oid0, good, k, api)
    wait_for(lambda: (api.call("GET", f"/reliability?area={enc}")[1] or [{}])[0].get("orders") == 3 or None, 10)
    for _ in range(2):
        api.call("POST", "/judge/reliability/record", {"area": area, "sellerID": good, "outcome": "delivered", "orderID": oid0}, admin=True)
    event(oid0, good, "delivered", api)  # duplicate judge click
    time.sleep(1)
    code, rows = api.call("GET", f"/reliability?area={enc}")
    by = {r["sellerID"]: r for r in rows or []}
    check("same order recorded by hand twice + duplicate Deliver click: counted once (good seller 3 orders, (3+4)/(3+5)=0.875)",
          by.get(good, {}).get("orders") == 3 and by[good]["score"] == 0.875, str(by.get(good)))


# ---------- A7 ----------

def a7_true_price(ctx):
    """A7 true price"""
    api, other = ctx["fast"], Api(ctx["fast"].base, ctx["key_b"])
    seller, pin = f"k23-ts-{RUN}", "250001"
    q = f"/true_price?seller={seller}&pincode={pin}"
    oids = []
    for i in range(4):
        code, oid, _ = place(api, [line("a", seller, 10000)])
        ok = code == 201 and ready(api, oid) and all(event(oid, seller, k, api) == 200 for k in ("confirmed", "shipped", "delivered"))
        oids.append(oid)
        if not check(f"sandbox order {i + 1} delivered", ok and wait_for(lambda: status(api, oid).get("state") == "done", 12), f"http {code}"):
            return

    def paid(oid, **kw):
        body = {"sellerID": seller, "paidPaise": 11000, "itemsPaise": 10000, "pincode": pin}
        body.update(kw)
        return api.call("POST", f"/orders/{oid}/paid", body)[0]

    def info():
        return api.call("GET", q)[1] or {}
    check("before any report: 0 reports, not enough", info().get("reports") == 0 and info().get("enough") is False)
    ok = [paid(oids[0], paidPaise=11000), paid(oids[1], paidPaise=10500)]
    check("two good reports stored (200), still not enough", ok == [200, 200] and info().get("reports") == 2 and not info().get("enough"), str(info()))
    check("third good report -> enough, median extra = 1000 paise", paid(oids[2], paidPaise=12000) == 200 and info().get("enough") and info().get("medianExtraPaise") == 1000, str(info()))
    bad = {"negative paid": paid(oids[3], paidPaise=-1), "absurd paid (Rs 1 crore+)": paid(oids[3], paidPaise=10**12),
           "paid as text": paid(oids[3], paidPaise="9999"), "fractional paid": paid(oids[3], paidPaise=10.5),
           "bad pincode": paid(oids[3], pincode="12"), "negative items": paid(oids[3], itemsPaise=-5)}
    for name, code in bad.items():
        check(f"bad report refused: {name}", code == 422, f"http {code}")
    check("other install's order id (already reported by A) -> 409 and nothing changed",
          other.call("POST", f"/orders/{oids[0]}/paid", {"sellerID": seller, "paidPaise": 99999, "itemsPaise": 1, "pincode": pin})[0] == 409
          and info().get("reports") == 3 and info().get("medianExtraPaise") == 1000, str(info()))
    check("no key -> 401", Api(api.base).call("POST", f"/orders/{oids[0]}/paid", {})[0] == 401)
    squat = other.call("POST", f"/orders/{oids[3]}/paid", {"sellerID": seller, "paidPaise": 10100, "itemsPaise": 10000, "pincode": pin})[0]
    check("other install cannot pre-claim A's real order before A reports it (409, fixed in this task)", squat == 409 and info().get("reports") == 3, f"http {squat}")
    before = info().get("medianExtraPaise")
    check("a 4th real report (paid 15000 for items 10000) moves the estimate 1000 -> 1500", paid(oids[3], paidPaise=15000) == 200 and before == 1000 and info().get("medianExtraPaise") == 1500, str(info()))
    rows = sql("select count(*), count(distinct reporter) from true_price_reports where seller_id=?", seller)[0]
    check("stored in the database: 4 reports from one install", rows == (4, 1), str(rows))
    code, _ = api.call("POST", "/reset", {})
    left = sql("select count(*) from true_price_reports where seller_id=? and reporter=(select install_id from keys where label='k23-a')", seller)[0][0]
    check("delete-everything removes this install's reports", code == 200 and left == 0, f"http {code}, rows left {left}")
    check("estimate drops back (no longer enough)", (info().get("reports", 9) <= 1) and not info().get("enough"), str(info()))
    other.call("POST", "/reset", {})
    left_all = sql("select count(*) from true_price_reports where seller_id=?", seller)[0][0]
    check("and the other install's reset removes its row too", left_all == 0, f"rows left {left_all}")


# ---------- A8 ----------

def kill_and_restart_worker():
    pidfile = Path("data/worker.pid")
    pid = int(pidfile.read_text()) if pidfile.exists() else 0
    alive = False
    try:
        os.kill(pid, 0); alive = pid > 0
    except OSError:
        pass
    if not alive:
        out = subprocess.run(["pgrep", "-f", f"{HERE}/.venv/bin/python worker.py|^.venv/bin/python worker.py|python worker.py"], capture_output=True, text=True).stdout.split()
        pid = int(out[0]) if out else 0
    if pid:
        os.kill(pid, signal.SIGKILL)
        wait_for(lambda: subprocess.run(["kill", "-0", str(pid)], capture_output=True).returncode != 0, 5, 0.1)
    time.sleep(1.0)  # a window with no worker at all
    py = ".venv/bin/python" if Path(".venv/bin/python").exists() else sys.executable
    new = subprocess.Popen([py, "worker.py"], cwd=HERE, stdout=open("data/worker.log", "ab"), stderr=subprocess.STDOUT,
                           stdin=subprocess.DEVNULL, start_new_session=True)
    pidfile.write_text(str(new.pid))
    return pid, new.pid


def a8_safety_net(ctx):
    """A8 safety net"""
    api = ctx["fast"]
    s1, s2, s3 = f"k23-s1-{RUN}", f"k23-s2-{RUN}", f"k23-s3-{RUN}"
    key = f"k23-{RUN}-a8"
    lines = [line("a", s1, 10000), line("b", s2, 10000)]
    c1, oid, body = place(api, lines, extra_sellers=[s3], key=key)
    c2, oid2, _ = place(api, lines, extra_sellers=[s3], key=key)
    check("placement replayed with the same Idempotency-Key -> 201 then 200, same order", (c1, c2) == (201, 200) and oid == oid2, f"{c1}/{c2}")
    changed = dict(body, plan=mkplan([line("a", s1, 10000), line("b", s2, 10100)]))
    c3, _ = api.call("POST", "/order", changed, headers={"Idempotency-Key": key})
    check("same key with a different body -> 409", c3 == 409, f"http {c3}")
    if not check("order ready", ready(api, oid)):
        return
    placed = sql("select seller_id, plan_version from placements where order_id=?", oid)
    check("replay placed each seller exactly once", sorted(placed) == sorted([(s1, 1), (s2, 1)]), str(len(placed)))
    check("judge cancels s1 -> Plan B asked for", event(oid, s1, "cancelled", api) == 200 and wait_for(lambda: status(api, oid).get("state") == "needs_proposal", 8))
    pv = status(api, oid)["planVersion"]
    new_lines = [line("b", s2, 10000), line("a", s3, 12000)]
    proposal = {"failure": "cancelled", "failedSellerID": s1, "kept": [line("b", s2, 10000)], "rerouted": [line("a", s3, 12000)],
                "newPlan": mkplan(new_lines), "extraCost": 2000, "stillMissing": []}
    check("phone posts the proposal -> awaiting_approval", api.call("POST", f"/order/{oid}/proposal", {"planVersion": pv, "proposal": proposal})[0] == 200
          and wait_for(lambda: status(api, oid).get("state") == "awaiting_approval", 8))
    # ---- kill ONLY the worker mid-order (state: awaiting approval, confirm timers running)
    t0 = time.time()
    old, new = kill_and_restart_worker()
    check("worker killed with SIGKILL and started again (new pid)", old > 0 and new != old, f"{old} -> {new}")
    st = wait_for(lambda: (lambda s: s if s.get("state") == "awaiting_approval" else None)(status(api, oid)), 40)
    check("order state rebuilt from history after the restart (still awaiting approval, plan v1)", bool(st) and st["planVersion"] == 1, f"{round(time.time() - t0, 1)}s")
    ctx["restarted"] = True
    a1 = api.call("POST", f"/order/{oid}/approve", {"planVersion": pv})[0]
    a2 = api.call("POST", f"/order/{oid}/approve", {"planVersion": pv})[0]   # sent at once: may still pass the API's version check
    check("approve accepted; the immediate replay is either refused at the API (409) or ignored by the workflow", a1 == 200 and a2 in (200, 409), f"{a1}/{a2}")
    final = wait_for(lambda: (lambda s: s if s.get("planVersion") == 2 and s.get("ready") else None)(status(api, oid)), 15)
    check("plan v2 placed after approval", bool(final))
    placed = sorted(sql("select seller_id, plan_version from placements where order_id=?", oid))
    ign = [a for a in status(api, oid).get("audit", []) if a["event"] == "ignored_signal"]
    print(f"NOTE replayed approve: http {a2}; workflow audit shows {len(ign)} ignored_signal row(s)", flush=True)
    check("no seller placed twice (s1 v1, s2 v1, s3 v2)", placed == sorted([(s1, 1), (s2, 1), (s3, 2)]), str(placed))
    a3 = api.call("POST", f"/order/{oid}/approve", {"planVersion": pv})[0]
    check("a later replay of the same approval is refused (409 stale planVersion)", a3 == 409, f"http {a3}")
    appr = sql("select plan_version, approver from approvals where order_id=?", oid)
    check("exactly one approval stored, with its plan version", appr == [(2, "user")], str(appr))
    # ---- "did this go through?" fires after the shortened timer (15 min x 0.02 = 18 s), once per seller
    sec = 15 * 60 * FAST_SCALE
    check_fired = wait_for(lambda: (lambda s: s if s2 in s.get("needsCheck", []) else None)(status(api, oid)), sec + 25)
    check(f"'did this go through?' flag raised for the unconfirmed seller (timer {sec:.0f}s)", bool(check_fired), str(check_fired and check_fired["needsCheck"]))
    time.sleep(1)
    audit = status(api, oid).get("audit", [])
    unconfirmed = [a["detail"]["sellerID"] for a in audit if a["event"] == "unconfirmed"]
    check("flag audited once per seller (no repeat after the worker restart)", len(unconfirmed) == len(set(unconfirmed)) and s2 in unconfirmed, str([u.split('-')[1] for u in unconfirmed]))
    check("confirming clears the flag", event(oid, s2, "confirmed", api) == 200 and wait_for(lambda: s2 not in status(api, oid).get("needsCheck", [s2]), 8))
    seqs = [r[0] for r in sql("select seq from audit where order_id=? order by seq", oid)]
    check("audit sequence contiguous from 1", seqs == list(range(1, len(seqs) + 1)), f"{len(seqs)} rows")
    api.call("POST", "/reset", {})


# ---------- A6 (two halves; the refill timer is created before A8 so the worker kill happens while it waits) ----------

def a6_start(ctx):
    now = datetime.now(IST)
    target = now.date() if now.time() < datetime.strptime("08:58", "%H:%M").time() else now.date() + timedelta(days=1)
    due = datetime(target.year, target.month, target.day, 9, 0, tzinfo=IST)
    secs = (due - now).total_seconds()
    ctx["refill_scale"] = 40 / secs           # the refill waits secs * scale = ~40 s
    ctx["refill_target"] = target
    start = target - timedelta(days=12)       # 30 tablets at 1-0-1 = 15 days -> runs out target+3 -> reminder on `target`
    ctx["refill_api"] = Api(f"http://127.0.0.1:{REFILL_PORT}", ctx["key_c"])
    ctx["refill_proc"] = start_api(REFILL_PORT, ctx["refill_scale"])
    ctx["refill_api_b"] = Api(f"http://127.0.0.1:{REFILL_PORT}", ctx["key_d"])
    body = {"items": [{"name": "Metformin 500", "quantity": 30, "dosesPerDay": "1-0-1"}], "startDate": start.isoformat()}
    code, out = ctx["refill_api"].call("POST", "/refill/watch", body)
    ok = code == 201 and out and out["refillDueAt"].startswith(f"{target.isoformat()}T09:00:00") and out["runsOutOn"] == (target + timedelta(days=3)).isoformat()
    check("refill watch registered like the app does (30 tablets, 1-0-1): runs out in 3 days, reminder 09:00 IST", ok, f"http {code}, due {out and out['refillDueAt']}")
    ctx["refill_id"] = out["refillID"]
    ctx["refill_t0"] = time.time()
    code, other = ctx["refill_api_b"].call("POST", "/refill/watch", body)
    ctx["refill_id_b"] = other["refillID"] if code == 201 else None
    st = ctx["refill_api"].call("GET", f"/refill/{ctx['refill_id']}/status")[1] or {}
    check("watch starts in 'waiting' with no due event", st.get("state") == "waiting" and st.get("dueFiredAt") is None, str(st.get("state")))
    check("a second install's status cannot read it (404)", ctx["refill_api_b"].call("GET", f"/refill/{ctx['refill_id']}/status")[0] == 404)


async def _history(handle):
    h = await handle.fetch_history()
    names = [e.event_type for e in h.events]
    from temporalio.api.enums.v1 import EventType
    return sum(1 for n in names if n == EventType.EVENT_TYPE_TIMER_STARTED), sum(1 for n in names if n == EventType.EVENT_TYPE_TIMER_FIRED)


async def _temporal_view(refill_ids):
    from temporalio.client import Client
    client = await Client.connect(TEMPORAL)
    out = {}
    for rid in refill_ids:
        if not rid:
            continue
        handle = client.get_workflow_handle("refill-" + rid)
        d = await handle.describe()
        out[rid] = (d.status.name if d.status else None, await _history(handle))
    running = []
    async for w in client.list_workflows('WorkflowType="RefillWorkflow" AND ExecutionStatus="Running"'):
        running.append(w.id)
    return out, running


def a6_due(ctx):
    """A6 refill (due)"""
    api, rid = ctx["refill_api"], ctx["refill_id"]
    st = wait_for(lambda: (lambda s: s if s.get("state") == "due" else None)(api.call("GET", f"/refill/{rid}/status")[1] or {}), 90, 0.5)
    check("after the shortened timer the server records the refill as due (3 days before running out)", bool(st), f"{round(time.time() - ctx['refill_t0'], 1)}s after the watch" if st else "never due")
    if not st:
        return
    fired = st["dueFiredAt"]
    check("the due event carries a firing time", bool(fired), fired)
    time.sleep(4)
    st2 = api.call("GET", f"/refill/{rid}/status")[1] or {}
    view, _ = asyncio.run(_temporal_view([rid]))
    status_name, (started, fired_n) = view[rid]
    check("due fired once, not twice: same dueFiredAt later, exactly 1 timer started and 1 fired in the Temporal history",
          st2.get("dueFiredAt") == fired and st2.get("state") == "due" and (started, fired_n) == (1, 1), f"timers started/fired {started}/{fired_n}, workflow {status_name}")
    check("it survived the worker kill+restart that happened while it was waiting", ctx.get("restarted") is True)


def a6_delete(ctx):
    """A6 refill (delete everything)"""
    api, rid, rid_b = ctx["refill_api"], ctx["refill_id"], ctx["refill_id_b"]
    view, running = asyncio.run(_temporal_view([rid, rid_b]))
    check("before delete: both installs' watches are RUNNING in Temporal", view[rid][0] == "RUNNING" and view[rid_b][0] == "RUNNING" and f"refill-{rid}" in running, str({k: v[0] for k, v in view.items()}))
    code, out = api.call("POST", "/reset", {})
    view, running = asyncio.run(_temporal_view([rid, rid_b]))
    check("delete-everything (install A) cancels A's watch in Temporal (TERMINATED, not in the running list)", code == 200 and view[rid][0] == "TERMINATED" and f"refill-{rid}" not in running, f"http {code}, {view[rid][0]}")
    check("and leaves install B's watch alone", view[rid_b][0] == "RUNNING" and f"refill-{rid_b}" in running, view[rid_b][0])
    ctx["refill_api_b"].call("POST", "/reset", {})
    view, running = asyncio.run(_temporal_view([rid_b]))
    check("B's own delete-everything cancels B's watch", view[rid_b][0] == "TERMINATED" and f"refill-{rid_b}" not in running, view[rid_b][0])


# ---------- A5 ----------

def a5_chase(ctx):
    """A5 report chase"""
    api = ctx["lab"]
    now = datetime.now(IST)
    slot = (now + timedelta(days=1)).replace(hour=8, minute=0, second=0, microsecond=0).isoformat()
    body = {"labID": f"k23lab-{RUN}", "labName": "K23 Test Lab", "tests": [{"testID": "hba1c", "name": "HbA1c", "fasting": True}],
            "homeCollection": True, "preferredSlot": slot, "addressText": "Test address"}
    code, out = api.call("POST", "/lab/book", body)
    if not check("lab test booked", code == 201 and out.get("bookingID"), f"http {code}"):
        return
    bid, token = out["bookingID"], out["replyLink"].rsplit("/", 1)[1]
    lab = Api(api.base)
    c, _ = lab.call("POST", f"/lab/reply/{token}", {"action": "confirm"})
    st = api.call("GET", f"/lab/{bid}/status")[1] or {}
    check("lab confirms through its reply link (no key); status confirmed with a fasting reminder", c == 200 and st.get("state") == "confirmed" and bool(st.get("fastingReminderAt")), f"http {c}, {st.get('state')}")
    due = (datetime.now(IST) + timedelta(minutes=5)).isoformat()   # report due in 5 min -> 0.3 s at this scale
    c, _ = api.call("POST", f"/judge/lab/{bid}/event", {"kind": "collected", "reportDueAt": due}, admin=True)
    t0 = time.time()
    check("sample collected, report due set", c == 200 and (api.call("GET", f"/lab/{bid}/status")[1] or {}).get("state") == "collected")
    seen = {}

    def poll():
        s = (api.call("GET", f"/lab/{bid}/status")[1] or {}).get("state")
        seen.setdefault(s, time.time())
        return s == "report_chase_due"
    reached = wait_for(poll, 5 * 60 * LAB_SCALE + 6 * 3600 * LAB_SCALE + 40, 0.25)
    check("report goes 'report_due' first", "report_due" in seen, f"{round(seen.get('report_due', t0) - t0, 1)}s after collection (expected under 2 s)")
    check("then the chase fires at due + 6 h (scaled: 21.6 s later)", bool(reached) and "report_due" in seen and
          seen["report_chase_due"] - seen["report_due"] >= 6 * 3600 * LAB_SCALE * 0.9, f"{round(seen.get('report_chase_due', 0) - seen.get('report_due', 0), 1)}s after report_due" if reached else "never")
    time.sleep(8)
    state = (api.call("GET", f"/lab/{bid}/status")[1] or {}).get("state")

    async def moves():
        from temporalio.client import Client
        from temporalio.api.enums.v1 import EventType
        h = await (await Client.connect(TEMPORAL)).get_workflow_handle("lab-" + bid).fetch_history()
        return [e.activity_task_scheduled_event_attributes.activity_type.name for e in h.events if e.event_type == EventType.EVENT_TYPE_ACTIVITY_TASK_SCHEDULED]
    acts = asyncio.run(moves())
    check("the chase appears once: still report_chase_due 8 s later; Temporal ran the state move exactly twice (report_due, chase) and nothing more",
          state == "report_chase_due" and acts == ["lab_time_state", "lab_time_state"], f"{state}, activities {acts}")
    c, _ = api.call("POST", f"/judge/lab/{bid}/event", {"kind": "report_ready"}, admin=True)
    check("report_ready after the chase closes the booking (done)", c == 200 and (api.call("GET", f"/lab/{bid}/status")[1] or {}).get("state") == "done")
    api.call("POST", "/reset", {})


def run_section(label, fn, ctx, timings):
    global section_name
    section_name = label
    t0 = time.time()
    n0 = len(results)
    try:
        fn(ctx)
    except Exception as error:  # a crash is a failure, not a silent skip
        check(f"section crashed: {type(error).__name__}: {error}", False)
    timings.append((label, all(r[1] for r in results[n0:]) and len(results) > n0, time.time() - t0))


def main():
    if subprocess.run(["pgrep", "-f", "browser_e2e"], capture_output=True).stdout.strip():
        print("browser_e2e is running (K20). Wait for it, then re-run."); sys.exit(2)
    health = Api(BASE).call("GET", "/health")[1] or {}
    if not health.get("temporal"):
        print(f"FAIL stack not up on {BASE} (run: bash start_all.sh)"); sys.exit(2)
    print(f"stack up on {BASE}; extra API copies on :{FAST_PORT} (orders, scale {FAST_SCALE}), :{LAB_PORT} (lab, scale {LAB_SCALE}), :{REFILL_PORT} (refill)", flush=True)
    ctx = {f"key_{k}": issue_key(f"k23-{k}", f"data/k23_{k}.key") for k in "abcd"}   # c, d own the refill watches
    ctx["fast_proc"] = start_api(FAST_PORT, FAST_SCALE)
    ctx["fast"] = Api(f"http://127.0.0.1:{FAST_PORT}", ctx["key_a"])
    start_api(LAB_PORT, LAB_SCALE)
    ctx["lab"] = Api(f"http://127.0.0.1:{LAB_PORT}", ctx["key_b"])
    timings: list = []
    t_all = time.time()
    try:
        run_section("A6 refill (register)", a6_start, ctx, timings)
        for label, fn in [("A1 reliability", a1_reliability), ("A7 true price", a7_true_price), ("A8 safety net", a8_safety_net)]:
            run_section(label, fn, ctx, timings)
        run_section("A6 refill (due once)", a6_due, ctx, timings)
        run_section("A5 report chase", a5_chase, ctx, timings)
        run_section("A6 refill (delete everything)", a6_delete, ctx, timings)
    finally:
        for k in "abcd":
            Api(f"http://127.0.0.1:{FAST_PORT}", ctx[f"key_{k}"]).call("POST", "/reset", {})   # only this script's own installs
        for p in procs:
            p.terminate()
    bad = [r for r in results if not r[1]]
    print("\n" + "\n".join(f"{'PASS' if ok else 'FAIL'}  {label:34s} {sec:6.1f}s" for label, ok, sec in timings))
    print(f"RESULT {'PASS' if not bad else 'FAIL'}: {len(results) - len(bad)}/{len(results)} checks, {round(time.time() - t_all)}s")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
