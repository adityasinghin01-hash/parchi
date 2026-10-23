"""Acceptance run T3 (server-truth version), executed ON the iMac:
the app in Live mode on the iOS simulator places an order, the judge cancels a seller, the phone posts a
Plan B proposal, the (simulated) tap approves it, everything is delivered. Repeats N times; every loop must pass.
Usage: .venv/bin/python e2e_live.py --loops 3"""
import argparse, json, os, sqlite3, subprocess, sys, time, urllib.error, urllib.request

BASE = "http://localhost:8000"
BUNDLE = "in.tessanova.parchi"
UDID = "12B6A285-914E-44DE-A52A-9577A9265B50"
APP = os.path.expanduser("~/parchi-dd-claude/Build/Products/Debug-iphonesimulator/Parchi.app")
INSTALL = open("data/sim_install.key").read().strip()
ADMIN = open("data/admin.key").read().strip()
results = []


def call(method, path, admin=False, body=None):
    headers = {"Content-Type": "application/json", ("X-Admin-Key" if admin else "X-Install-Key"): ADMIN if admin else INSTALL}
    req = urllib.request.Request(BASE + path, method=method, headers=headers, data=json.dumps(body).encode() if body is not None else None)
    for _ in range(8):
        try:
            with urllib.request.urlopen(req, timeout=10) as r:
                return r.status, json.loads(r.read() or b"null")
        except urllib.error.HTTPError as e:
            if e.code != 429:  # the server rate-limits to 60 requests/min per key: wait it out like a polite client
                return e.code, None
            time.sleep(min(int(e.headers.get("Retry-After", "2")), 10))
    return 429, None


def wait(label, fn, timeout):
    t0 = time.time()
    while time.time() - t0 < timeout:
        v = fn()
        if v:
            return v, round(time.time() - t0, 2)
        time.sleep(0.6)
    raise AssertionError(f"timeout waiting for: {label} ({timeout}s)")


def check(name, ok, detail=""):
    results.append(ok)
    print(("PASS " if ok else "FAIL ") + name + (f" ({detail})" if detail else ""))
    if not ok:
        raise AssertionError(name)


def sim(*args):
    return subprocess.run(["xcrun", "simctl", *args], capture_output=True, text=True)


def loop(i):
    print(f"--- loop {i}")
    call("POST", "/reset?scope=demo", admin=True, body={})
    sim("boot", UDID); sim("bootstatus", UDID, "-b"); sim("terminate", UDID, BUNDLE); sim("install", UDID, APP)
    sim("launch", UDID, BUNDLE, "-demoRoute", "track", "-backendMode", "live", "-backendURL", BASE, "-installKey", INSTALL)
    order, t = wait("order appears and is ready", lambda: next((o for o in (call("GET", "/judge/orders", admin=True)[1] or []) if o["ready"]), None), 20)
    oid = order["orderID"]
    check("order placed by the app", len(order["sellers"]) >= 2 and all(s["status"] == "placed" for s in order["sellers"]), f"{len(order['sellers'])} sellers, {t}s")
    victim = order["sellers"][0]["id"]
    t_cancel = time.time()
    check("judge cancel accepted", call("POST", f"/judge/{oid}/event", admin=True, body={"sellerID": victim, "kind": "cancelled"})[0] == 200)
    _, t1 = wait("needs_proposal", lambda: (call("GET", f"/status/{oid}")[1] or {}).get("state") == "needs_proposal", 6)
    snap, _ = wait("awaiting_approval (phone posted the proposal)", lambda: (lambda s: s if s and s["state"] == "awaiting_approval" else None)(call("GET", f"/status/{oid}")[1]), 10)
    t_prop = round(time.time() - t_cancel, 2)
    check("phone posted a Plan B proposal fast", t_prop <= 6, f"{t_prop}s after the cancel")
    sim("io", UDID, "screenshot", f"data/e2e_loop{i}_planb.png")
    check("proposal keeps unaffected sellers", snap["proposal"] is not None and not snap.get("nothingAvailable"))
    check("approve accepted", call("POST", f"/order/{oid}/approve", body={"planVersion": snap["planVersion"]})[0] == 200)
    final, _ = wait("plan version 2 placed", lambda: (lambda s: s if s and s["planVersion"] == 2 and s["state"] == "placed" else None)(call("GET", f"/status/{oid}")[1]), 10)
    st = {s["id"]: s["status"] for s in final["sellers"]}
    check("cancelled seller marked rerouted", st[victim] == "rerouted", str(st))
    for sid, status in st.items():
        if status in ("placed", "confirmed", "shipped"):
            for kind in ("confirmed", "shipped", "delivered"):
                code, _ = call("POST", f"/judge/{oid}/event", admin=True, body={"sellerID": sid, "kind": kind})
                check(f"judge {kind} {sid}", code == 200, f"http {code}")
    wait("order done", lambda: (call("GET", f"/status/{oid}")[1] or {}).get("state") == "done", 15)
    con = sqlite3.connect("data/parchi.db")
    rows = con.execute("select seller_id, plan_version from placements where order_id=?", (oid,)).fetchall()
    check("no seller placed twice in one plan version", len(rows) == len(set(rows)), f"{len(rows)} placements")
    check("replacement placed under version 2", any(v == 2 for _, v in rows), str(sorted(rows)))
    audit = [r[0] for r in con.execute("select seq from audit where order_id=? order by seq", (oid,))]
    check("audit sequence contiguous", audit == list(range(audit[0], audit[0] + len(audit))), f"{len(audit)} rows")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(); ap.add_argument("--loops", type=int, default=3); a = ap.parse_args()
    t0 = time.time()
    try:
        for n in range(1, a.loops + 1):
            loop(n)
        call("POST", "/reset?scope=demo", admin=True, body={})
        print(f"RESULT PASS: {a.loops} loops in a row, {len(results)} checks, {round(time.time() - t0)}s")
    except AssertionError as e:
        print(f"RESULT FAIL: {e}")
        sys.exit(1)
