"""K31: the REAL timer durations are what is configured, read from Temporal itself (not from a sped-up clock).

Usage (from server/):  .venv/bin/python live_timers_check.py
Needs Temporal + worker + API already running (bash start_all.sh). Prints PASS/FAIL per check, exit 1 on any FAIL.

How: it starts its OWN copy of the API on 127.0.0.1:8013 with PARCHI_TIME_SCALE removed from the environment (so the
default, real scale 1 is used), sharing the database, Temporal server and the running worker. It starts one workflow of
each kind through that API with a throw-away install key (data/k31_timers.key) and reads the PENDING timer from the
workflow history: TimerStarted.startToFireTimeout (a timer that was started and neither fired nor cancelled). That is
the duration Temporal will really wait. Then it terminates every workflow it started, deletes the install's rows and the
key. The :8000 API is never touched.

  no-reply shop wait   10 min        order "did this go through?"   15 min        order late   ETA + 30 min
  lab no reply         30 min        report chase                   report due + 6 h
  refill alert         3 days before running out, 09:00 IST          fasting reminder   21:00 IST the evening before
(The fasting reminder is a stored time, not a Temporal timer: it is read from the booking status.)

Tolerance: a timer is started a few milliseconds after the clock it counts from was read (an activity runs in between), so
the scheduled duration may be shorter than the nominal one by at most 30 s (orders / report chase) or 2 s (exact timers).
It can never be longer. The printed table shows the real difference.
"""
import asyncio
import hashlib
import json
import os
import sqlite3
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path
from uuid import uuid4

HERE = Path(__file__).resolve().parent
os.chdir(HERE)
sys.path.insert(0, str(HERE))
PORT = 8013
TEMPORAL = os.environ.get("PARCHI_TEMPORAL", "localhost:7233")
DB = os.environ.get("PARCHI_DB", "data/parchi.db")
ADMIN = Path("data/admin.key").read_text().strip()
KEY_FILE = Path("data/k31_timers.key")
IST = timezone(timedelta(hours=5, minutes=30))
RUN = uuid4().hex[:6]
results: list[bool] = []
table: list[tuple[str, str, str, str]] = []   # (what, plan value, scheduled, verdict)
workflow_ids: list[str] = []
proc: subprocess.Popen | None = None


def check(name: str, ok: bool, detail: str = "") -> bool:
    results.append(bool(ok))
    print(("PASS " if ok else "FAIL ") + name + (f" ({detail})" if detail else ""), flush=True)
    return bool(ok)


def fmt(seconds: float) -> str:
    seconds = round(seconds)
    d, rest = divmod(seconds, 86400)
    h, rest = divmod(rest, 3600)
    m, s = divmod(rest, 60)
    return " ".join(p for p in (f"{d}d" if d else "", f"{h}h" if h else "", f"{m}m" if m else "", f"{s}s" if s or not seconds else "") if p)


# ---------- plumbing ----------

class Api:
    def __init__(self, base: str, key: str | None = None):
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
                if e.code == 429:
                    time.sleep(min(int(e.headers.get("Retry-After", "2")), 10)); continue
                try:
                    return e.code, json.loads(e.read() or b"null")
                except Exception:
                    return e.code, None
            except (urllib.error.URLError, TimeoutError, ConnectionError):
                time.sleep(1)
        return 0, None


def wait_for(fn, timeout, every=0.3):
    t0 = time.time()
    while time.time() - t0 < timeout:
        v = fn()
        if v:
            return v
        time.sleep(every)
    return None


def issue_key() -> str:
    old = os.umask(0o077)
    try:
        with open(KEY_FILE, "w") as f:
            subprocess.run([sys.executable, "-m", "auth", "issue", f"k31-timers-{RUN}"], stdout=f, stderr=subprocess.DEVNULL, check=True)
    finally:
        os.umask(old)
    return KEY_FILE.read_text().strip()


def start_api() -> subprocess.Popen:
    env = {k: v for k, v in os.environ.items() if k != "PARCHI_TIME_SCALE"}   # the REAL scale: unset = 1
    env.update(PARCHI_ADMIN_KEY=ADMIN, PARCHI_PUBLIC_URL=f"http://127.0.0.1:{PORT}")
    p = subprocess.Popen([sys.executable, "-m", "uvicorn", "api:app", "--host", "127.0.0.1", "--port", str(PORT), "--no-access-log"],
                         cwd=HERE, env=env, stdout=open(f"/tmp/k31_api_{PORT}.log", "w"), stderr=subprocess.STDOUT)
    api = Api(f"http://127.0.0.1:{PORT}")
    if not wait_for(lambda: (api.call("GET", "/health")[1] or {}).get("temporal"), 25):
        p.terminate()
        raise RuntimeError(f"own API on :{PORT} did not start (see /tmp/k31_api_{PORT}.log)")
    return p


# ---------- reading Temporal ----------

def _secs(duration) -> float:
    return duration.seconds + duration.nanos / 1e9


def _when(ts) -> datetime:
    return datetime.fromtimestamp(ts.seconds + ts.nanos / 1e9, tz=timezone.utc)


async def _history(wid: str):
    from temporalio.client import Client
    client = await Client.connect(TEMPORAL)
    return await client.get_workflow_handle(wid).fetch_history()


def pending_timers(wid: str) -> list[dict]:
    """Timers started and neither fired nor cancelled: {seconds: scheduled duration, started: when, fires: when it will fire}."""
    from temporalio.api.enums.v1 import EventType
    started, done = {}, set()
    for e in asyncio.run(_history(wid)).events:
        if e.event_type == EventType.EVENT_TYPE_TIMER_STARTED:
            a = e.timer_started_event_attributes
            at = _when(e.event_time)
            started[e.event_id] = {"seconds": _secs(a.start_to_fire_timeout), "started": at,
                                   "fires": at + timedelta(seconds=_secs(a.start_to_fire_timeout))}
        elif e.event_type == EventType.EVENT_TYPE_TIMER_FIRED:
            done.add(e.timer_fired_event_attributes.started_event_id)
        elif e.event_type == EventType.EVENT_TYPE_TIMER_CANCELED:
            done.add(e.timer_canceled_event_attributes.started_event_id)
    return [t for i, t in sorted(started.items()) if i not in done]


def workflow_input(wid: str) -> dict:
    from temporalio.api.enums.v1 import EventType
    for e in asyncio.run(_history(wid)).events:
        if e.event_type == EventType.EVENT_TYPE_WORKFLOW_EXECUTION_STARTED:
            return json.loads(e.workflow_execution_started_event_attributes.input.payloads[0].data)
    return {}


def query(wid: str, name: str = "snapshot") -> dict:
    async def go():
        from temporalio.client import Client
        return await (await Client.connect(TEMPORAL)).get_workflow_handle(wid).query(name)
    return asyncio.run(go())


def terminate(wid: str) -> None:
    async def go():
        from temporalio.client import Client
        try:
            await (await Client.connect(TEMPORAL)).get_workflow_handle(wid).terminate(reason="k31 timers check")
        except Exception:
            pass
    asyncio.run(go())


def running(wid: str) -> bool:
    async def go():
        from temporalio.client import Client
        d = await (await Client.connect(TEMPORAL)).get_workflow_handle(wid).describe()
        return d.status is not None and d.status.name == "RUNNING"
    try:
        return asyncio.run(go())
    except Exception:
        return False


def timer_where(wid: str, predicate, timeout=20):
    """The first pending timer (after waiting) that satisfies predicate; None if none shows up."""
    def look():
        for t in pending_timers(wid):
            if predicate(t):
                return t
        return None
    return wait_for(look, timeout, 0.4)


def row(what: str, expected: float, timer: dict | None, slack: float, both_sides: bool = False) -> bool:
    """Check one scheduled duration: expected - slack <= scheduled <= expected (it can only be a little short).
    both_sides: the plan value was itself measured from a server timestamp, so allow +-slack."""
    if timer is None:
        table.append((what, fmt(expected), "no pending timer", "FAIL"))
        return check(f"{what}: pending timer found", False)
    got = timer["seconds"]
    ok = expected - slack <= got <= expected + (slack if both_sides else 0.001)
    table.append((what, f"{fmt(expected)} ({expected:.0f}s)", f"{got:.1f}s ({'off by' if both_sides else 'short by'} {expected - got:.1f}s)", "PASS" if ok else "FAIL"))
    return check(f"{what}: scheduled {got:.1f}s, plan value {expected:.0f}s ({fmt(expected)})", ok,
                 f"allowed +-{slack:.0f}s" if both_sides else f"allowed 0..{slack:.0f}s short")


# ---------- the checks ----------

def plan_of(lines, eta):
    return ({"lines": lines, "feesBySeller": {}, "itemsTotal": sum(r["price"] for r in lines), "feesTotal": 0, "stops": 1,
             "maxEtaMinutes": eta, "medicinesReadyMinutes": eta, "reportsReadyMinutes": 0},
            [{"id": lines[0]["sellerID"], "name": "K31 chemist", "channel": "localChemist", "etaMinutes": eta, "requiresVisit": True}])


def order_timers(api: Api) -> None:
    eta = 120
    sid = f"k31-{RUN}"
    lines = [{"itemID": "a", "sellerID": sid, "price": 5000, "isSubstitute": False}]
    plan, sellers = plan_of(lines, eta)
    code, out = api.call("POST", "/order", {"plan": plan, "sellers": sellers}, headers={"Idempotency-Key": f"k31-{RUN}"})
    if not check("order placed", code == 201 and out and out.get("orderID"), f"http {code}"):
        return
    oid = out["orderID"]
    wid = "order-" + oid
    workflow_ids.append(wid)
    wait_for(lambda: (api.call("GET", f"/status/{oid}")[1] or {}).get("ready"), 20)
    scale = workflow_input(wid).get("time_scale")
    check("order workflow started with the real scale (input time_scale == 1)", scale == 1, str(scale))
    confirm = timer_where(wid, lambda t: True, 10)
    check("order: exactly one timer is pending right after placing (the 15 min check)", len(pending_timers(wid)) == 1, f"{len(pending_timers(wid))} pending")
    row("order: 'did this go through?' check", 15 * 60, confirm, 30)
    dl = query(wid)["deadlines"][sid]
    placed = datetime.fromisoformat(dl["placedAt"])
    c_off = datetime.fromisoformat(dl["confirmDue"]) - placed
    l_off = datetime.fromisoformat(dl["lateDue"]) - placed
    check("order: workflow state says confirm deadline = placed + 15 min and late deadline = placed + ETA + 30 min (exact)",
          c_off == timedelta(minutes=15) and l_off == timedelta(minutes=eta + 30), f"confirm +{fmt(c_off.total_seconds())}, late +{fmt(l_off.total_seconds())}")
    if confirm:
        gap = abs((confirm["fires"] - (placed + timedelta(minutes=15))).total_seconds())
        check("order: the timer fires at placed + 15 min (within 3 s of the workflow's own clock)", gap <= 3, f"{gap:.2f}s apart")
    # The seller confirms: the 15 min check has nothing left to check, so the next (and only) timer is the late deadline.
    code, _ = api.call("POST", f"/judge/{oid}/event", {"sellerID": sid, "kind": "confirmed"}, admin=True)
    check("seller 'confirmed' event accepted", code == 200, f"http {code}")
    late = timer_where(wid, lambda t: 3600 < t["seconds"] <= (eta + 30) * 60 + 1, 20)
    row(f"order: late = promised ETA ({eta} min) + 30 min", (eta + 30) * 60, late, 30)
    if late:
        gap = abs((late["fires"] - (placed + timedelta(minutes=eta + 30))).total_seconds())
        check("order: the late timer fires at placed + ETA + 30 min (within 3 s)", gap <= 3, f"{gap:.2f}s apart")
    check("order: only the late timer is pending now (the 15 min check was cancelled)", len(pending_timers(wid)) == 1, f"{len(pending_timers(wid))} pending")


def shop_timer(api: Api) -> None:
    body = {"items": [{"itemID": "i1", "name": "Metformin", "quantity": 1}],
            "shops": [{"shopID": f"k31-{RUN}", "name": "K31 shop", "phone": "+910000000000"}], "pickupBy": (datetime.now(IST) + timedelta(days=1)).isoformat()}
    code, out = api.call("POST", "/shop/ask", body)
    if not check("shop ask created without a waitMinutes (the default)", code == 201 and out and out.get("askID"), f"http {code}"):
        return
    wid = "shop-" + out["askID"]
    workflow_ids.append(wid)
    data = workflow_input(wid)
    check("shop workflow input: wait_minutes == 10, time_scale == 1", data.get("wait_minutes") == 10 and data.get("time_scale") == 1, f"{data.get('wait_minutes')} min, scale {data.get('time_scale')}")
    row("shop ask: no-reply wait", 10 * 60, timer_where(wid, lambda t: True, 15), 2)


def lab_timers(api: Api) -> None:
    slot = (datetime.now(IST) + timedelta(days=2)).replace(hour=8, minute=0, second=0, microsecond=0)
    body = {"labID": f"k31lab-{RUN}", "labName": "K31 Test Lab", "tests": [{"testID": "hba1c", "name": "HbA1c", "fasting": True}],
            "homeCollection": True, "preferredSlot": slot.isoformat(), "addressText": "Test address"}
    code, out = api.call("POST", "/lab/book", body)
    if not check("lab booked", code == 201 and out and out.get("bookingID"), f"http {code}"):
        return
    bid, token = out["bookingID"], out["replyLink"].rsplit("/", 1)[1]
    wid = "lab-" + bid
    workflow_ids.append(wid)
    check("lab workflow started with the real scale (input time_scale == 1)", workflow_input(wid).get("time_scale") == 1)
    row("lab booking: no-reply wait", 30 * 60, timer_where(wid, lambda t: True, 15), 2)
    c, _ = Api(api.base).call("POST", f"/lab/reply/{token}", {"action": "confirm"})
    st = api.call("GET", f"/lab/{bid}/status")[1] or {}
    check("lab confirmed through its reply link", c == 200 and st.get("state") == "confirmed", f"http {c}, {st.get('state')}")
    expected_reminder = datetime(slot.year, slot.month, slot.day, 21, 0, tzinfo=IST) - timedelta(days=1)
    got = st.get("fastingReminderAt")
    ok = bool(got) and datetime.fromisoformat(got) == expected_reminder
    table.append(("fasting reminder (slot 08:00)", expected_reminder.strftime("%d %b 21:00 IST, evening before"), str(got), "PASS" if ok else "FAIL"))
    check("fasting reminder = 21:00 IST the evening before the slot", ok, f"slot {slot.isoformat()} -> {got}")
    due = datetime.now(IST) + timedelta(seconds=3)       # the report is due in 3 real seconds; the chase is then due + 6 h
    c, _ = api.call("POST", f"/judge/lab/{bid}/event", {"kind": "collected", "reportDueAt": due.isoformat()}, admin=True)
    check("sample collected with the report due in 3 s", c == 200, f"http {c}")
    # The chase is the only timer between 5 h and 6 h; the 7-day idle timer of the confirmed state may still be listed for an instant.
    chase = timer_where(wid, lambda t: 5 * 3600 < t["seconds"] <= 6 * 3600 + 1, 30)
    row("lab report chase: report due + 6 h", 6 * 3600, chase, 30)
    if chase:
        gap = abs((chase["fires"] - (due + timedelta(hours=6))).total_seconds())
        check("lab report chase fires at report due + 6 h (within 3 s of the due time that was sent)", gap <= 3, f"{gap:.2f}s apart")
    st = api.call("GET", f"/lab/{bid}/status")[1] or {}
    check("lab booking is 'report_due' while the chase timer waits", st.get("state") == "report_due", str(st.get("state")))


def fasting_slots(api: Api) -> None:
    now = datetime.now(IST)
    for label, slot in (("slot just after midnight (00:30)", (now + timedelta(days=4)).replace(hour=0, minute=30, second=0, microsecond=0)),
                        ("slot in the evening (19:45)", (now + timedelta(days=3)).replace(hour=19, minute=45, second=0, microsecond=0))):
        body = {"labID": f"k31lab-{uuid4().hex[:4]}", "labName": "K31 Test Lab", "tests": [{"testID": "t", "name": "Fasting glucose", "fasting": True}],
                "homeCollection": True, "preferredSlot": slot.isoformat(), "addressText": "Test address"}
        code, out = api.call("POST", "/lab/book", body)
        if not check(f"fasting booking created ({label})", code == 201 and out, f"http {code}"):
            continue
        workflow_ids.append("lab-" + out["bookingID"])
        Api(api.base).call("POST", f"/lab/reply/{out['replyLink'].rsplit('/', 1)[1]}", {"action": "confirm"})
        got = (api.call("GET", f"/lab/{out['bookingID']}/status")[1] or {}).get("fastingReminderAt")
        expected = datetime(slot.year, slot.month, slot.day, 21, 0, tzinfo=IST) - timedelta(days=1)
        ok = bool(got) and datetime.fromisoformat(got) == expected
        table.append((f"fasting reminder ({label})", expected.strftime("%d %b 21:00 IST"), str(got), "PASS" if ok else "FAIL"))
        check(f"fasting reminder {label}: 21:00 IST the evening before", ok, f"{slot.isoformat()} -> {got}")


def refill_timer(api: Api) -> None:
    today = datetime.now(IST).date()
    body = {"items": [{"name": "Metformin 500", "quantity": 30, "dosesPerDay": "1-0-1"}], "startDate": today.isoformat()}   # 15 days of tablets
    code, out = api.call("POST", "/refill/watch", body)
    if not check("refill watch registered (30 tablets, 1-0-1, starting today)", code == 201 and out and out.get("refillID"), f"http {code}"):
        return
    wid = "refill-" + out["refillID"]
    workflow_ids.append(wid)
    run_out = today + timedelta(days=15)
    expected = datetime(run_out.year, run_out.month, run_out.day, 9, 0, tzinfo=IST) - timedelta(days=3)
    check("refill: runs out in 15 days; reminder = 3 days before, 09:00 IST",
          out["runsOutOn"] == run_out.isoformat() and datetime.fromisoformat(out["refillDueAt"]) == expected,
          f"runs out {out['runsOutOn']}, reminder {out['refillDueAt']}")
    check("refill workflow input time_scale == 1", workflow_input(wid).get("time_scale") == 1)
    timer = timer_where(wid, lambda t: True, 15)
    if timer is None:
        row("refill alert", 0, None, 0)
        return
    want = (expected - timer["started"]).total_seconds()   # the plan value, measured from the moment the timer started
    row("refill alert: 3 days before running out, 09:00 IST", want, timer, 2, both_sides=True)
    gap = abs((timer["fires"] - expected).total_seconds())
    check("refill: the timer fires at the reminder time (within 2 s)", gap <= 2, f"{gap:.2f}s apart; fires {timer['fires'].astimezone(IST).isoformat(timespec='seconds')}")


def cleanup(api: Api | None, key_made: bool) -> None:
    for wid in workflow_ids:
        terminate(wid)
    if api is not None and key_made:
        api.call("POST", "/reset", {})   # this install's rows only (orders, shop asks, lab bookings, refill watches)
    if KEY_FILE.exists():
        try:
            digest = hashlib.sha256(KEY_FILE.read_text().strip().encode()).hexdigest()
            with sqlite3.connect(DB, timeout=30) as conn:
                conn.execute("DELETE FROM keys WHERE key_hash=?", (digest,))
        finally:
            KEY_FILE.unlink(missing_ok=True)


def main() -> None:
    global proc
    health = Api("http://localhost:8000").call("GET", "/health")[1] or {}
    if not health.get("temporal"):
        print("FAIL stack not up on :8000 (run: bash start_all.sh)")
        sys.exit(2)
    t0 = time.time()
    api = None
    key_made = False
    try:
        key = issue_key()
        key_made = True
        proc = start_api()
        api = Api(f"http://127.0.0.1:{PORT}", key)
        print(f"own API on :{PORT} with PARCHI_TIME_SCALE unset; isolated install key data/k31_timers.key", flush=True)
        for fn in (order_timers, shop_timer, lab_timers, fasting_slots, refill_timer):
            try:
                fn(api)
            except Exception as error:   # a crash is a FAIL, never a silent skip
                check(f"{fn.__name__} crashed: {type(error).__name__}: {error}", False)
    finally:
        cleanup(api, key_made)
        if proc:
            proc.terminate()
    left = [w for w in workflow_ids if running(w)]
    check("clean up: every workflow this script started is terminated", not left, f"{len(workflow_ids)} started, still running: {left}")
    check("clean up: the throw-away key and file are gone", not KEY_FILE.exists())
    print("\n| What | Plan value | Scheduled in Temporal | |\n|---|---|---|---|")
    for what, expected, got, verdict in table:
        print(f"| {what} | {expected} | {got} | {verdict} |")
    bad = results.count(False)
    print(f"RESULT {'PASS' if not bad else 'FAIL'}: {len(results) - bad}/{len(results)} checks, {round(time.time() - t0)}s")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
