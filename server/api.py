import asyncio
import collections
import hashlib
import json
import html
import math
import os
import threading
import time
from contextlib import asynccontextmanager
from typing import Any

import httpx
from fastapi import Body, Depends, FastAPI, File, Header, HTTPException, Request, UploadFile
from fastapi.responses import HTMLResponse, JSONResponse
from temporalio.client import Client
from temporalio.common import WorkflowIDReusePolicy
from temporalio.exceptions import WorkflowAlreadyStartedError
from temporalio.service import RPCError, RPCStatusCode

import auth
import contract
import db
import judge_session

QUERY_WAIT = 10  # seconds to wait for a workflow query before giving up


@asynccontextmanager
async def lifespan(app: FastAPI):
    db.init_db()
    yield


app = FastAPI(title="Parchi Orchestrator", lifespan=lifespan)
MAX_BODY_BYTES = 1_000_000
# POST /read carries a photo: up to 2 MB of image plus a little multipart framing. Every other route keeps 1 MB.
READER_MAX_BYTES = 2_000_000
READ_BODY_BYTES = READER_MAX_BYTES + 16_384
PHOTO_PATHS = ("/read", "/judge/scan/read")  # the second is the admin-only phone test page (scan_page.py)


def body_limit_for(request: Request) -> int:
    return READ_BODY_BYTES if request.method == "POST" and request.url.path in PHOTO_PATHS else MAX_BODY_BYTES


from body_limit import BodySizeLimit

app.add_middleware(BodySizeLimit, default_limit=MAX_BODY_BYTES, photo_limit=READ_BODY_BYTES, photo_paths=PHOTO_PATHS)

app.state.temporal = None


async def get_temporal(request: Request) -> Client:
    state = request.app.state
    if state.temporal is None:
        try:
            state.temporal = await Client.connect(os.environ.get("PARCHI_TEMPORAL", "localhost:7233"))
        except Exception:
            raise HTTPException(503, "temporal unavailable")
    return state.temporal


def admin_header(request: Request) -> None:
    auth.require_admin(request)


def admin_query(request: Request) -> None:
    """The judge HTML page: header or session cookie; a browser without a session is sent to /judge/login.
    (Name kept for old imports; ?k= no longer authenticates here: judge_session.bridge turns it into a cookie.)"""
    judge_session.admin_page(request)


def workflow_id(order_id: str) -> str:
    return "order-" + order_id


def owned_order(order_id: str, install_id: str) -> dict[str, Any]:
    order = db.get_order(order_id)
    if order is None or order["install_id"] != install_id:
        raise HTTPException(404, "order not found")
    return order


async def snapshot(temporal: Any, order_id: str) -> dict[str, Any]:
    try:
        handle = temporal.get_workflow_handle(workflow_id(order_id))
        return await asyncio.wait_for(handle.query("snapshot"), QUERY_WAIT)
    except (RPCError, asyncio.TimeoutError):
        raise HTTPException(503, "workflow unavailable")


async def terminate(temporal: Any, orders: list[dict[str, Any]]) -> None:
    for order in orders:
        try:
            await temporal.get_workflow_handle(workflow_id(order["order_id"])).terminate(reason="reset")
        except RPCError as error:
            # Already finished or never started is fine; anything else must not delete rows.
            if error.status not in (RPCStatusCode.NOT_FOUND, RPCStatusCode.FAILED_PRECONDITION):
                raise HTTPException(503, "temporal unavailable")


@app.get("/health")
async def health(request: Request) -> dict[str, bool]:
    try:
        up = bool(await (await get_temporal(request)).service_client.check_health())
    except Exception:
        up = False
    return {"ok": True, "temporal": up}


@app.post("/order")
async def create_order(
    install_id: str = Depends(auth.require_install),
    temporal: Any = Depends(get_temporal),
    idempotency_key: str = Header(min_length=1, max_length=128),
    body: dict[str, Any] = Body(...),
) -> JSONResponse:
    try:
        contract.validate_order(body)
    except ValueError as error:
        raise HTTPException(422, str(error))
    # Stable id: replaying the same request can only ever reach the same workflow.
    order_id = hashlib.sha256(f"{install_id}\n{idempotency_key}".encode()).hexdigest()[:32]
    body_hash = hashlib.sha256(json.dumps(body, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    try:
        db.reserve_order(order_id, install_id, body_hash)
    except db.KeyReuseError:
        raise HTTPException(409, "Idempotency-Key was already used with a different request")
    except ValueError as error:
        raise HTTPException(409, str(error) if "deleted" in str(error) else "order unavailable")
    data = {"order_id": order_id, "install_id": install_id, "plan": contract.clean_plan(body["plan"]),
            "sellers": contract.clean_sellers(body["sellers"]), "auto_approve_cap_paise": body.get("autoApproveCapPaise"),
            "time_scale": float(os.environ.get("PARCHI_TIME_SCALE", "1")),
            # Reliability area: the order's area, else city, else pincode; none = the default area.
            "area": next((body[k] for k in contract.AREA_KEYS if body.get(k)), None) or reliability.DEFAULT_AREA}
    created = True
    try:
        await temporal.start_workflow(
            "OrderWorkflow", data, id=workflow_id(order_id),
            task_queue=os.environ.get("PARCHI_TASK_QUEUE", "parchi"),
            id_reuse_policy=WorkflowIDReusePolicy.REJECT_DUPLICATE)
    except WorkflowAlreadyStartedError:
        created = False
    except RPCError:
        raise HTTPException(503, "temporal unavailable")
    return JSONResponse({"orderID": order_id}, status_code=201 if created else 200)


@app.get("/status/{order_id}")
async def status(order_id: str, install_id: str = Depends(auth.require_install),
                 temporal: Any = Depends(get_temporal)) -> dict[str, Any]:
    owned_order(order_id, install_id)
    snap = await snapshot(temporal, order_id)
    return {
        "orderID": order_id, "state": snap["state"], "planVersion": snap["planVersion"],
        "sellers": snap["sellers"], "pending": snap["pending"], "proposal": snap["proposal"],
        "nothingAvailable": snap["nothingAvailable"], "needsCheck": snap["needsCheck"],
        "waitingSince": snap["waitingSince"], "audit": db.audit_for(order_id, 20),
        "unresolvedItems": snap.get("unresolvedItems", []),
        # False while the first placements are still being written; clients should not trust the seller list yet.
        "ready": snap.get("ready", True),
    }


def proposal_id_of(body: dict[str, Any]) -> str | None:
    """The optional proposalID of an approve/reject body (old clients send none)."""
    value = body.get("proposalID")
    if value is not None and not (isinstance(value, str) and 0 < len(value) <= 64):
        raise HTTPException(422, "proposalID must be a string")
    return value


async def send_signal(order_id: str, name: str, version: Any, extra: list[Any],
                      install_id: str, temporal: Any, proposal_id: str | None = None) -> dict[str, bool]:
    if type(version) is not int:
        raise HTTPException(422, "planVersion must be an integer")
    owned_order(order_id, install_id)
    snap = await snapshot(temporal, order_id)
    if version != snap["planVersion"]:
        raise HTTPException(409, "stale planVersion")
    if name in ("approve", "reject"):
        # K31: a decision is only ever about the proposal on screen NOW. Already resolved -> 409, never a silent 200;
        # a late replay naming an older proposal can never decide a newer one.
        current = (snap.get("proposal") or {}).get("proposalID")
        if snap["state"] != "awaiting_approval" or (proposal_id is not None and proposal_id != current):
            raise HTTPException(409, "stale proposal")
        if proposal_id is not None:
            extra = [*extra, proposal_id]
    await temporal.get_workflow_handle(workflow_id(order_id)).signal(name, args=[version, *extra])
    return {"ok": True}


@app.post("/order/{order_id}/proposal")
async def post_proposal(order_id: str, body: dict[str, Any] = Body(...),
                        install_id: str = Depends(auth.require_install),
                        temporal: Any = Depends(get_temporal)) -> dict[str, bool]:
    if not isinstance(body.get("proposal"), dict):
        raise HTTPException(422, "proposal must be an object")
    try:
        cleaned = contract.clean_proposal(body["proposal"])
    except ValueError as error:
        raise HTTPException(422, str(error))
    return await send_signal(order_id, "proposal", body.get("planVersion"), [cleaned],
                             install_id, temporal)


@app.post("/order/{order_id}/approve")
async def post_approve(order_id: str, body: dict[str, Any] = Body(...),
                       install_id: str = Depends(auth.require_install),
                       temporal: Any = Depends(get_temporal),
                       idempotency_key: str | None = Header(default=None, max_length=128)) -> dict[str, Any]:
    # K30: one approval per plan version (atomic claim); same Idempotency-Key replays the first answer.
    import approve_guard
    proposal_id = proposal_id_of(body)

    async def send_with_id(order_id, name, version, extra, install_id, temporal):  # K31: carries the optional proposalID
        return await send_signal(order_id, name, version, extra, install_id, temporal, proposal_id)

    return await approve_guard.guarded_approve(
        order_id, body.get("planVersion"), idempotency_key, install_id, temporal,
        owned_order=owned_order, snapshot=snapshot, send_signal=send_with_id)


@app.post("/order/{order_id}/reject")
async def post_reject(order_id: str, body: dict[str, Any] = Body(...),
                      install_id: str = Depends(auth.require_install),
                      temporal: Any = Depends(get_temporal)) -> dict[str, bool]:
    return await send_signal(order_id, "reject", body.get("planVersion"), [], install_id, temporal,
                             proposal_id_of(body))


@app.post("/judge/{order_id}/event", dependencies=[Depends(admin_header)])
async def judge_event(order_id: str, body: dict[str, Any] = Body(...),
                      temporal: Any = Depends(get_temporal)) -> dict[str, bool]:
    seller_id, kind = body.get("sellerID"), body.get("kind")
    if not isinstance(seller_id, str) or not isinstance(kind, str) or kind not in contract.EVENTS:
        raise HTTPException(422, "invalid sellerID or kind")
    if db.get_order(order_id) is None:
        raise HTTPException(404, "order not found")
    await temporal.get_workflow_handle(workflow_id(order_id)).signal("seller_event", args=[seller_id, kind])
    return {"ok": True}


BUTTONS = [("Confirm", "confirmed"), ("Ship", "shipped"), ("Deliver", "delivered"),
           ("Cancel", "cancelled"), ("Out of stock", "outOfStock"), ("Late", "late")]

PAGE = """<!doctype html><meta charset="utf-8"><title>Parchi judge</title>
<style>body{font-family:sans-serif;margin:1.5em}.o{border:1px solid #888;padding:.6em;margin:.6em 0}
button{margin:2px}.rf{margin:.4em 0}.rf label{margin-right:.8em}</style>
<h1>Parchi judge: Test orders</h1><button type="button" id="logout">Log out</button><div id="msg"></div><!--ORDERS-->
<script>
const say = (t) => { document.getElementById('msg').textContent = t; };
async function post(path, body) {
  // The browser sends the session cookie by itself; X-Parchi-Judge is the CSRF guard a cross-site page cannot add.
  const r = await fetch(path, {method: 'POST', headers: {'Content-Type': 'application/json', 'X-Parchi-Judge': '1'},
    body: JSON.stringify(body)});
  say(r.ok ? 'sent' : (r.status === 401 ? 'session expired: log in again' : 'error ' + r.status));
  if (r.ok) setTimeout(() => location.reload(), 600);
  if (r.status === 401) setTimeout(() => { location.href = '/judge/login'; }, 1200);
}
document.addEventListener('click', async (e) => {
  if (e.target.closest('#logout')) {
    await fetch('/judge/logout', {method: 'POST', headers: {'X-Parchi-Judge': '1'}});
    location.href = '/judge/login'; return;
  }
  const t = e.target.closest('button[data-reply-toggle]');
  if (t) { const f = t.nextElementSibling; f.hidden = !f.hidden; return; }
  const l = e.target.closest('button[data-lab]');
  if (l) { await post('/judge/lab/' + encodeURIComponent(l.dataset.lab) + '/event', {kind: l.dataset.k}); return; }
  const b = e.target.closest('button[data-o]'); if (!b) return;
  await post('/judge/' + encodeURIComponent(b.dataset.o) + '/event', {sellerID: b.dataset.s, kind: b.dataset.k});
});
document.addEventListener('submit', async (e) => {
  const f = e.target.closest('form.rf'); if (!f) return;
  e.preventDefault();
  const items = [...f.querySelectorAll('input[data-item]')].map((i) => {
    const has = i.value.trim() !== '';
    return has ? {itemID: i.dataset.item, available: true, pricePaise: Math.round(parseFloat(i.value) * 100)}
               : {itemID: i.dataset.item, available: false};
  });
  const time = f.querySelector('.rb').value;
  const today = new Date(Date.now() + 5.5 * 3600e3).toISOString().slice(0, 10);
  const body = {shopID: f.dataset.shop, items: items};
  if (items.some((i) => i.available)) {
    if (!time) { say('enter a ready-by time'); return; }
    body.readyBy = today + 'T' + time + ':00+05:30';
  }
  await post('/judge/shop/' + encodeURIComponent(f.dataset.ask) + '/reply', body);
});
</script>"""


@app.get("/judge/orders", dependencies=[Depends(admin_header)])
async def judge_orders(temporal: Any = Depends(get_temporal)) -> list[dict[str, Any]]:
    """Machine-readable twin of the judge page (used by the end-to-end acceptance run)."""
    out = []
    for order in db.list_orders(limit=20):
        try:
            snap = await snapshot(temporal, order["order_id"])
        except HTTPException:
            continue
        out.append({"orderID": order["order_id"], "state": snap["state"], "planVersion": snap["planVersion"],
                    "ready": snap.get("ready", True),
                    "sellers": [{"id": x["id"], "status": x["status"]} for x in snap["sellers"]]})
    return out


@app.get("/judge", response_class=HTMLResponse, dependencies=[Depends(admin_query)])
async def judge_page(temporal: Any = Depends(get_temporal)) -> str:
    def esc(value: Any) -> str:
        return html.escape(str(value), quote=True)

    parts = []
    for order in db.list_orders(limit=20):
        oid = order["order_id"]
        try:
            snap = await snapshot(temporal, oid)
        except HTTPException:
            parts.append(f'<div class="o">Test order {esc(oid)}: unavailable</div>')
            continue
        rows = []
        for s in snap["sellers"]:
            buttons = "".join(
                f'<button data-o="{esc(oid)}" data-s="{esc(s["id"])}" data-k="{kind}">{label}</button>'
                for label, kind in BUTTONS)
            rows.append(f'<div>{esc(s["id"])} <b>{esc(s["status"])}</b> {buttons}</div>')
        parts.append(f'<div class="o"><b>Test order {esc(oid)}</b> state: {esc(snap["state"])}'
                     f' v{esc(snap["planVersion"])}{"".join(rows)}</div>')
    return HTMLResponse(PAGE.replace("<!--ORDERS-->", "".join(parts) + judge_tools.sections_html()),
                        headers={"Cache-Control": "no-store", "Referrer-Policy": "no-referrer"})


@app.post("/reset")
async def reset(request: Request, scope: str | None = None,
                temporal: Any = Depends(get_temporal)) -> dict[str, Any]:
    if scope == "demo":
        auth.require_admin(request)
        install_id = None
    else:
        install_id = auth.require_install(request)
    # Tombstone first so a late retried activity cannot re-create rows, then terminate,
    # then delete (the cascade removes placements, audit and approvals).
    orders = db.mark_deleting(install_id)
    wf_ids = await reset_workflows.collect_ids(temporal, install_id)  # K30: ids first, while the rows still exist
    await terminate(temporal, orders)
    await refill.cancel_watches(temporal, install_id)  # refill watches have no row; they are found in Temporal
    wiped = await reset_workflows.wipe(temporal, wf_ids)  # K30: terminate shop/lab too, then delete every history
    db.delete_orders(install_id, ids=[o["order_id"] for o in orders])
    # "Delete everything" also clears the shop/lab/true-price rows that belong to this install.
    if install_id is None:
        p3_db.delete_all(); v2_db.delete_all()
    else:
        p3_db.delete_install(install_id); v2_db.delete_install(install_id)
    try:
        db.truncate_wal()
    except db.sqlite3.OperationalError:
        raise HTTPException(503, "private data checkpoint busy; retry reset")
    return {"ok": True, "deleted": len(orders), "workflowsDeleted": wiped["deleted"], "workflowsKept": wiped["kept"]}


READER_TYPES = {"image/jpeg", "image/png", "image/heic"}
READER_TRANSPORT: Any = None  # tests inject an httpx.MockTransport here


# G10: at most READ_LIMIT /read requests per install key in READ_WINDOW_S seconds (in memory, sliding window).
READ_LIMIT = 6
READ_WINDOW_S = 60.0
_read_times: dict[str, "collections.deque[float]"] = {}
_read_lock = threading.Lock()
_read_clock = time.monotonic  # tests replace it


def _read_allowed(key: str) -> int:
    """0 when this request may go ahead (and is counted), else the seconds to wait (Retry-After)."""
    now = _read_clock()
    with _read_lock:
        times = _read_times.setdefault(key, collections.deque())
        while times and now - times[0] >= READ_WINDOW_S:
            times.popleft()
        if len(times) >= READ_LIMIT:
            return max(1, math.ceil(READ_WINDOW_S - (now - times[0])))
        times.append(now)
        if len(_read_times) > 10_000:  # bound memory: drop keys with no recent request
            for k in [k for k, v in _read_times.items() if not v or now - v[-1] >= READ_WINDOW_S]:
                _read_times.pop(k, None)
        return 0


def _read_failed(status: int, detail: str, code: str, headers: dict | None = None) -> JSONResponse:
    """Error answer of /read: {"detail": ..., "code": ...}. Codes: docs/team/READER-CONTRACT.md."""
    return JSONResponse({"detail": detail, "code": code}, status_code=status, headers=headers)


_READER_CODES = {"not_configured", "cap_reached", "bad_key", "reader_error", "timeout"}


@app.post("/read")
async def read(image: UploadFile | None = File(None), key: str = Depends(auth.require_install)) -> JSONResponse:
    """Forward a parchi crop to the reader (PARCHI_READER_URL, reader_claude.py). The image is never logged or stored.
    Every failure carries a machine `code` (not_configured, cap_reached, bad_key, reader_error, timeout, slow_down)."""
    wait = _read_allowed(key)
    if wait:
        return _read_failed(429, "too many photos, wait a minute", "slow_down", {"Retry-After": str(wait)})
    reader = os.environ.get("PARCHI_READER_URL", "")
    if not reader:
        return _read_failed(503, "reader not connected", "not_configured")
    if image is None or image.content_type not in READER_TYPES:
        raise HTTPException(415, "send one image (jpeg, png or heic) in the 'image' field")
    data = await image.read(READER_MAX_BYTES + 1)
    if len(data) > READER_MAX_BYTES:
        raise HTTPException(413, "image too large")
    try:
        async with httpx.AsyncClient(timeout=float(os.environ.get("PARCHI_READER_TIMEOUT", "60")), transport=READER_TRANSPORT) as client:
            reply = await client.post(reader, files={"image": ("parchi", data, image.content_type)})
    except httpx.TimeoutException:
        return _read_failed(504, "reader timed out", "timeout")
    except httpx.HTTPError:
        return _read_failed(503, "reader not connected", "not_configured")
    if reply.status_code >= 400:
        try:
            code = reply.json().get("code")
        except (ValueError, AttributeError):
            code = None
        if code not in _READER_CODES:
            code = "not_configured" if reply.status_code == 503 else "reader_error"
        if reply.status_code == 503:  # no key, or a spending cap: the app says which, then tries its on-phone reader
            return _read_failed(503, "reader not connected", code)
        if code == "timeout":
            return _read_failed(504, "reader timed out", code)
        return _read_failed(502, "reader error", code)
    return JSONResponse(reply.json())




# V2 modules: each adds its own routes (tests cover them in tests/test_reliability.py etc.).
import p3_db, v2_db, shop, lab, reliability, refill, true_price, judge_tools, reset_workflows  # noqa: E402

for _module in (shop, lab, reliability, refill, true_price, judge_tools):
    _module.register(app, get_temporal, auth.require_install)

import scan_page  # noqa: E402

app.include_router(scan_page.router)
app.include_router(judge_session.router)
app.middleware("http")(judge_session.bridge)  # K31: GET /judge?k=... -> cookie + 303 without k
