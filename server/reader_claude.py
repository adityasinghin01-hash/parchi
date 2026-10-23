"""The "last option" reader: reads ONE prescription photo with the Claude API.

Run:  uvicorn reader_claude:app --host 127.0.0.1 --port 8100 --no-access-log
`server/api.py` forwards `POST /read` here when PARCHI_READER_URL points at this service.
Contract: docs/team/READER-CONTRACT.md. Privacy: the image lives only in memory; the key, the image bytes
and the model's text are never logged, printed, returned or stored (only counts, status codes, timings).
"""
import asyncio
import base64
import json
import logging
import math
import os
import re
import threading
import time
from pathlib import Path
from urllib.parse import urlsplit

# K28/15: the SDK reads ANTHROPIC_LOG when it is imported and at "debug" it logs the whole request, including the
# base64 photo. Remove it BEFORE the import, then (below) pin the SDK/HTTP loggers to WARNING with a filter.
os.environ.pop("ANTHROPIC_LOG", None)

import anthropic  # noqa: E402
from fastapi import FastAPI, File, HTTPException, Request, UploadFile  # noqa: E402
from fastapi.responses import JSONResponse  # noqa: E402

_QUIET_LOGGERS = ("anthropic", "httpx", "httpx2", "httpcore")


class _DropBelowWarning(logging.Filter):
    """Drops DEBUG/INFO records of the SDK and HTTP libraries (their debug lines carry the request body)."""

    def filter(self, record: logging.LogRecord) -> bool:
        return record.levelno >= logging.WARNING or not record.name.split(".")[0] in _QUIET_LOGGERS


def silence_sdk_logging() -> None:
    """Idempotent. A logger filter only sees records logged directly on that logger, so the filter is also put on every
    existing child logger and on the root handlers (where child records end up); levels are forced to WARNING."""
    flt = _DropBelowWarning()
    names = [n for n in logging.root.manager.loggerDict if n.split(".")[0] in _QUIET_LOGGERS] + list(_QUIET_LOGGERS)
    for name in names:
        lg = logging.getLogger(name)
        lg.setLevel(logging.WARNING)
        if not any(isinstance(f, _DropBelowWarning) for f in lg.filters):
            lg.addFilter(flt)
    for handler in logging.root.handlers:
        if not any(isinstance(f, _DropBelowWarning) for f in handler.filters):
            handler.addFilter(flt)


silence_sdk_logging()

log = logging.getLogger("reader_claude")
if not log.handlers:  # uvicorn does not configure app loggers; only counts, status codes and timings are ever logged
    _handler = logging.StreamHandler()
    _handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    log.addHandler(_handler)
    log.setLevel(logging.INFO)

DEFAULT_MODEL = "claude-opus-5-5"
MAX_IMAGE_BYTES = 2_000_000
ALLOWED_TYPES = {"image/jpeg", "image/png", "image/heic"}
KEY_FILE = Path(__file__).resolve().parent / "data" / "anthropic.key"
# One end-to-end budget (K28/16): app waits 65 s > server /read and scan page wait 60 s > reader deadline 50 s (+ small
# connect/write slack). The deadline covers the retry; the retry only happens if at least MIN_RETRY_REMAINING_S are left.
CONNECT_TIMEOUT_S = 10
TOTAL_DEADLINE_S = 50
MIN_RETRY_REMAINING_S = 15
RETRY_DELAY_S = 1.0
def _inr_per_usd() -> float:
    """Fixed estimate rate (not live). Default 97; PARCHI_INR_PER_USD (a positive number) overrides it."""
    try:
        value = float(os.environ.get("PARCHI_INR_PER_USD", ""))
        if math.isfinite(value) and value > 0:
            return value
    except ValueError:
        pass
    return 97.0


INR_PER_USD = _inr_per_usd()
# Hard stop for REAL spending (the user's limit is Rs 500; a $5 top-up). Counted across restarts in data/reader_spend.json.
SPEND_CAP_USD = float(os.environ.get("PARCHI_SPEND_CAP_USD", "4.5"))
SPEND_FILE = Path(os.environ.get("PARCHI_SPEND_FILE") or Path(__file__).resolve().parent / "data" / "reader_spend.json")
# Worst-case USD reserved BEFORE each real call (K28/12), released/reconciled with the real cost afterwards.
# G9: measured 5 real calls = about 2,500 input + 250 output tokens, $0.015 and 5.8 s per scan (max_tokens 2000 caps the output).
RESERVE_USD = {"claude-opus-5-5": 0.07, "claude-sonnet-5-5": 0.04, "claude-haiku-5-5": 0.005}
MAX_TOKENS = 2000
MAX_LINES = 30
MAX_NAME_CHARS = 80
MAX_FIELD_CHARS = 40
# USD per million tokens (input, output).
PRICES = {
    "claude-opus-5-5": (4.0, 20.0),
    "claude-sonnet-5-5": (2.0, 10.0),
    "claude-haiku-5-5": (0.10, 0.50),
}

PROMPT = (
    "You are reading ONE photo of an Indian doctor's prescription. "
    "Return only what is WRITTEN, in page order: every medicine (kind \"medicine\": name = the brand or drug name "
    "exactly as written; strength = digits and unit as written, e.g. \"40\" or \"500 mg\"; quantity only if a number "
    "of tablets/units/days-times-doses is written; schedule only if written, e.g. \"1-0-1\" or \"OD/BD\"), and every "
    "lab test (kind \"test\", name as written). "
    "NEVER guess, expand, correct, or substitute a brand. If a word is unreadable, leave that line out. "
    "Never invent a medicine. Do not add generic names. "
    "Ignore the clinic letterhead, the doctor's name and registration number. "
    "NEVER output the patient's name, age, phone number or address, even if visible. "
    "If the photo is not a prescription, or nothing is readable, return an empty list. "
    "Use null for any of strength, quantity, schedule that is not written."
)

_NULLABLE_STR = {"anyOf": [{"type": "string"}, {"type": "null"}]}
_NULLABLE_INT = {"anyOf": [{"type": "integer"}, {"type": "null"}]}
LINES_SCHEMA = {
    "type": "object",
    "properties": {
        "lines": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "kind": {"type": "string", "enum": ["medicine", "test"]},
                    "name": {"type": "string"},
                    "strength": _NULLABLE_STR,
                    "quantity": _NULLABLE_INT,
                    "schedule": _NULLABLE_STR,
                },
                "required": ["kind", "name", "strength", "quantity", "schedule"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["lines"],
    "additionalProperties": False,
}

CANNOT_READ = "reader could not read this photo"


class ReaderFailed(HTTPException):
    """An HTTP error that also carries a machine `code` for the app (docs/team/READER-CONTRACT.md):
    not_configured | cap_reached | bad_key | reader_error | timeout | slow_down. The body is {"detail": ..., "code": ...}."""

    def __init__(self, status: int, detail: str, code: str, headers: dict | None = None) -> None:
        super().__init__(status, detail, headers=headers)
        self.code = code


# ---------------------------------------------------------------- output hygiene (pure)
_WS_CONTROLS = re.compile(r"[\t\n\r\x0b\x0c\x85\u2028\u2029]")
_CONTROLS = re.compile(r"[\x00-\x1f\x7f-\x9f\u200b-\u200f\u202a-\u202e\u2060-\u2064\ufeff]")


def _clean_text(value, limit: int) -> str:
    if not isinstance(value, str):
        return ""
    value = _CONTROLS.sub("", _WS_CONTROLS.sub(" ", value))
    return " ".join(value.split())[:limit].strip()


def _clean_quantity(value):
    if isinstance(value, bool):
        return None
    if isinstance(value, float) and value.is_integer():
        value = int(value)
    if isinstance(value, str) and value.strip().isdigit():
        value = int(value.strip())
    if isinstance(value, int) and 1 <= value <= 10000:
        return value
    return None


def clean_lines(raw) -> list[dict]:
    """Normalise whatever the model returned into contract lines. Pure; never raises on odd input."""
    items = raw.get("lines") if isinstance(raw, dict) else raw
    out: list[dict] = []
    for item in items if isinstance(items, list) else []:
        if not isinstance(item, dict):
            continue
        name = _clean_text(item.get("name"), MAX_NAME_CHARS)
        if not name:
            continue
        line = {"kind": "test" if item.get("kind") == "test" else "medicine", "name": name}
        strength = _clean_text(item.get("strength"), MAX_FIELD_CHARS)
        if strength:
            line["strength"] = strength
        quantity = _clean_quantity(item.get("quantity"))
        if quantity is not None:
            line["quantity"] = quantity
        schedule = _clean_text(item.get("schedule"), MAX_FIELD_CHARS)
        if schedule:
            line["schedule"] = schedule
        out.append(line)
        if len(out) >= MAX_LINES:
            break
    return out


# ---------------------------------------------------------------- key, client, usage
def _read_key() -> str:
    key = os.environ.get("ANTHROPIC_API_KEY", "").strip()
    if key:
        return key
    try:
        with open(KEY_FILE, encoding="utf8") as handle:
            return handle.readline().strip()
    except OSError:
        return ""


def model_name() -> str:
    return os.environ.get("PARCHI_READER_MODEL", DEFAULT_MODEL)


CLIENT_OVERRIDE = None  # tests inject a fake client here (any object with .messages.create)
_client_cache: tuple[str, object] | None = None
_client_lock = threading.Lock()


def _get_client():
    """Returns a client or None when no key exists. The key never leaves this function."""
    global _client_cache
    if CLIENT_OVERRIDE is not None:
        return CLIENT_OVERRIDE
    key = _read_key()
    if not key:
        return None
    base_url = os.environ.get("PARCHI_ANTHROPIC_BASE_URL") or None
    with _client_lock:
        fingerprint = f"{key}|{base_url}"
        if _client_cache is None or _client_cache[0] != fingerprint:
            _client_cache = (fingerprint, anthropic.Anthropic(
                api_key=key, base_url=base_url, max_retries=0,
                timeout=anthropic.Timeout(TOTAL_DEADLINE_S, connect=CONNECT_TIMEOUT_S)))
        return _client_cache[1]


def _price_key(model: str) -> str:
    return model if model in PRICES else next((name for name in PRICES if model.startswith(name)), DEFAULT_MODEL)


def reserve_estimate(model: str) -> float:
    """Worst-case USD for one call. PARCHI_RESERVE_USD (a positive number) overrides the per-model table."""
    try:
        override = float(os.environ.get("PARCHI_RESERVE_USD", ""))
        if math.isfinite(override) and override > 0:
            return override
    except ValueError:
        pass
    return RESERVE_USD[_price_key(model)]


class SpendRefused(ReaderFailed):
    def __init__(self, detail: str, code: str = "cap_reached") -> None:
        super().__init__(503, detail, code)


class Usage:
    EPS = 1e-9

    def __init__(self) -> None:
        self.lock = threading.Lock()
        self.reset()
        self.reserved = 0.0
        self.ledger_ok = True      # False = cannot read or write the spend file: real calls are refused (fail closed)
        self.refusals = 0
        self.lifetime_usd = 0.0
        self.lifetime_usd = self._load()

    def _load(self) -> float:
        """A missing file is the first start (= 0). Anything else that is not a clean non-negative number fails closed."""
        try:
            text = SPEND_FILE.read_text(encoding="utf-8")
        except FileNotFoundError:
            self.ledger_ok = True
            return self.lifetime_usd
        except OSError:
            self.ledger_ok = False
            return self.lifetime_usd
        try:
            raw = json.loads(text)["usd"]
            if isinstance(raw, bool):
                raise ValueError
            value = float(raw)
            if not math.isfinite(value) or value < 0:
                raise ValueError
        except (ValueError, KeyError, TypeError):
            self.ledger_ok = False
            return self.lifetime_usd
        self.ledger_ok = True
        return max(value, self.lifetime_usd)

    def _save(self) -> bool:
        try:
            SPEND_FILE.parent.mkdir(parents=True, exist_ok=True)
            tmp = SPEND_FILE.with_suffix(".tmp")
            tmp.write_text(json.dumps({"usd": round(self.lifetime_usd, 6)}), encoding="utf-8")
            os.chmod(tmp, 0o600)
            os.replace(tmp, SPEND_FILE)
            return True
        except OSError:
            return False

    def reset(self) -> None:
        self.calls = 0
        self.input_tokens = 0
        self.output_tokens = 0
        self.cost_usd = 0.0
        self.since = time.strftime("%Y-%m-%dT%H:%M:%S%z")

    def _refuse(self, detail: str, why: str, code: str = "cap_reached") -> None:
        self.refusals += 1
        log.warning("%s; refusing a real call (refusals=%d)", why, self.refusals)
        raise SpendRefused(detail, code)

    def reserve(self, model: str) -> float:
        """Atomically set aside the worst-case cost of one call BEFORE it is dispatched. Returns the amount (0 when the
        call is free: fake client or test upstream). Invariant: lifetime + reserved never exceeds the cap."""
        if not real_spend():
            return 0.0
        estimate = reserve_estimate(model)
        with self.lock:
            if not self.ledger_ok or not SPEND_FILE.exists():
                # after a failure: re-read (never lower than memory); on a first start: prove the file can be written.
                if not self.ledger_ok:
                    self.lifetime_usd = self._load()
                if self.ledger_ok and not self._save():
                    self.ledger_ok = False
            if not self.ledger_ok:
                self._refuse("reader spending ledger unavailable", "spend ledger cannot be read or written", "reader_error")
            if self.lifetime_usd + self.reserved + estimate > SPEND_CAP_USD + self.EPS:
                self._refuse("reader spending cap reached", "spending cap would be exceeded")
            self.reserved += estimate
            return estimate

    def release(self, reserved: float) -> None:
        """The call failed (nothing was billed): give the reservation back."""
        if reserved:
            with self.lock:
                self.reserved = max(0.0, self.reserved - reserved)

    def add(self, model: str, input_tokens: int, output_tokens: int, reserved: float = 0.0) -> None:
        """Count a finished call and, in the same locked step, swap its reservation for the real cost."""
        price_in, price_out = PRICES[_price_key(model)]
        with self.lock:
            self.calls += 1
            self.input_tokens += input_tokens
            self.output_tokens += output_tokens
            delta = (input_tokens * price_in + output_tokens * price_out) / 1_000_000
            self.cost_usd += delta
            self.reserved = max(0.0, self.reserved - reserved)
            if real_spend():
                self.lifetime_usd += delta
                if not self._save():
                    self.ledger_ok = False
                    log.warning("could not save the spend counter; refusing real calls until it can be saved")


def real_spend() -> bool:
    """True unless this is a fake client or an EXPLICIT test upstream. The exemption needs PARCHI_READER_TEST_UPSTREAM=1
    AND a base URL whose host is not anthropic.com; a base URL alone (even the real API) is counted and capped."""
    if CLIENT_OVERRIDE is not None:
        return False
    if os.environ.get("PARCHI_READER_TEST_UPSTREAM") != "1":
        return True
    base = os.environ.get("PARCHI_ANTHROPIC_BASE_URL") or ""
    try:
        host = (urlsplit(base).hostname or "").lower().rstrip(".")
    except ValueError:
        return True
    return not host or host == "anthropic.com" or host.endswith(".anthropic.com")


USAGE = Usage()


def over_cap() -> bool:
    return real_spend() and USAGE.lifetime_usd >= SPEND_CAP_USD


# ---------------------------------------------------------------- the model call
def _sniff(data: bytes) -> str | None:
    if data[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    return None


_now = time.monotonic   # tests replace these two to drive the deadline arithmetic without waiting
_sleep = time.sleep


def attempt_timeouts(remaining: float) -> tuple[float, float]:
    """(connect, everything else) in seconds for one attempt; connect + the rest never exceeds what is left."""
    remaining = max(1.0, remaining)
    connect = min(float(CONNECT_TIMEOUT_S), remaining / 2)
    return connect, remaining - connect


def may_retry(remaining: float) -> bool:
    """Retry only if, after the pause, at least MIN_RETRY_REMAINING_S of the deadline are still left."""
    return remaining - RETRY_DELAY_S >= MIN_RETRY_REMAINING_S


def _call_once(client, model: str, media_type: str, b64: str, remaining: float = float(TOTAL_DEADLINE_S)):
    connect, rest = attempt_timeouts(remaining)
    return client.messages.create(
        model=model,
        max_tokens=MAX_TOKENS,
        timeout=anthropic.Timeout(rest, connect=connect),
        output_config={"effort": "low", "format": {"type": "json_schema", "schema": LINES_SCHEMA}},
        messages=[{"role": "user", "content": [
            {"type": "image", "source": {"type": "base64", "media_type": media_type, "data": b64}},
            {"type": "text", "text": PROMPT},
        ]}],
    )


def _error_info(exc) -> tuple[str, str]:
    """(error type, message) from an Anthropic error body, lower case; never logged (may echo request details)."""
    body = getattr(exc, "body", None)
    err = body.get("error") if isinstance(body, dict) else None
    if not isinstance(err, dict):
        err = body if isinstance(body, dict) else {}
    kind = str(err.get("type") or "").lower()
    message = str(err.get("message") or getattr(exc, "message", "") or "").lower()
    return kind, message


def is_spend_limit(exc) -> bool:
    """Anthropic's own spend limit: HTTP 400 "You have reached your specified ... usage limits", or 429
    `enforced_spend_limit_reached`. Retrying cannot help, so it is never retried."""
    status = getattr(exc, "status_code", None)
    kind, message = _error_info(exc)
    if status == 429 and ("enforced_spend_limit" in kind or "enforced_spend_limit" in message or "spend limit" in message):
        return True
    return status == 400 and "usage limits" in message


def classify(exc) -> tuple[bool, int, str, str]:
    """(retryable, http status, detail, code) for an upstream exception. Most specific first."""
    if isinstance(exc, anthropic.APITimeoutError):
        return True, 504, "reader timed out", "timeout"
    if isinstance(exc, anthropic.APIStatusError):
        status = exc.status_code
        if is_spend_limit(exc):
            return False, 503, "reader spending cap reached", "cap_reached"
        if status in (401, 403):
            return False, 502, CANNOT_READ, "bad_key"
        if status == 429 or status >= 500:
            return True, 502, CANNOT_READ, "reader_error"
        return False, 502, CANNOT_READ, "reader_error"
    if isinstance(exc, anthropic.APIConnectionError):
        return True, 502, CANNOT_READ, "reader_error"
    return False, 502, CANNOT_READ, "reader_error"


def _call_with_retry(client, model: str, media_type: str, b64: str, deadline: float | None = None):
    """One deadline (TOTAL_DEADLINE_S) covers both attempts. Retry ONCE after 1 s on 429 / 5xx / connection errors / timeouts,
    and only when at least MIN_RETRY_REMAINING_S would remain. Never retried: Anthropic's spend limit (400 "usage limits",
    429 enforced_spend_limit_reached), 401/403 and other 4xx. Every failure carries a machine code (ReaderFailed)."""
    if deadline is None:
        deadline = _now() + TOTAL_DEADLINE_S
    for attempt in (1, 2):
        try:
            return _call_once(client, model, media_type, b64, deadline - _now())
        except (anthropic.APIStatusError, anthropic.APIConnectionError) as exc:
            retryable, status, detail, code = classify(exc)
            why = str(getattr(exc, "status_code", "")) or type(exc).__name__
        if retryable and attempt == 1 and not may_retry(deadline - _now()):
            log.warning("upstream failed (%s, %s); too little of the deadline is left to retry", why, code)
            raise ReaderFailed(status, detail, code)
        if not retryable or attempt == 2:
            log.warning("upstream failed (%s, %s) attempt=%d", why, code, attempt)
            raise ReaderFailed(status, detail, code)
        log.info("upstream %s, retrying once", why)
        _sleep(RETRY_DELAY_S)
    raise ReaderFailed(502, CANNOT_READ, "reader_error")  # unreachable


def _lines_from_response(response) -> list[dict]:
    if getattr(response, "stop_reason", None) in ("refusal", "max_tokens"):
        log.warning("model stop_reason=%s", response.stop_reason)
        raise ReaderFailed(502, CANNOT_READ, "reader_error")
    text = next((b.text for b in getattr(response, "content", []) or [] if getattr(b, "type", None) == "text"), None)
    try:
        parsed = json.loads(text)
    except (TypeError, ValueError):
        log.warning("model reply was not valid JSON")
        raise ReaderFailed(502, CANNOT_READ, "reader_error")
    if not isinstance(parsed, dict) or not isinstance(parsed.get("lines"), list):
        log.warning("model reply had no lines list")
        raise ReaderFailed(502, CANNOT_READ, "reader_error")
    return clean_lines(parsed)


def read_photo(client, data: bytes, media_type: str) -> list[dict]:
    model = model_name()
    started = time.monotonic()
    reserved = USAGE.reserve(model)  # K28/12: set the worst case aside BEFORE the call; may raise 503 (cap / ledger)
    try:
        response = _call_with_retry(client, model, media_type, base64.b64encode(data).decode("ascii"))
    except BaseException:
        USAGE.release(reserved)      # nothing was billed
        raise
    usage = getattr(response, "usage", None)
    tokens_in = int(getattr(usage, "input_tokens", 0) or 0)
    tokens_out = int(getattr(usage, "output_tokens", 0) or 0)
    USAGE.add(model, tokens_in, tokens_out, reserved)  # reservation -> real cost
    lines = _lines_from_response(response)
    log.info("read ok lines=%d in=%d out=%d seconds=%.1f", len(lines), tokens_in, tokens_out, time.monotonic() - started)
    return lines


# ---------------------------------------------------------------- the web app
app = FastAPI(title="Parchi Claude reader", docs_url=None, redoc_url=None, openapi_url=None)


@app.exception_handler(ReaderFailed)
async def _reader_failed(_: Request, exc: ReaderFailed) -> JSONResponse:
    return JSONResponse({"detail": exc.detail, "code": exc.code}, status_code=exc.status_code, headers=exc.headers)


@app.get("/health")
def health() -> dict:
    return {"ok": True, "keyConfigured": CLIENT_OVERRIDE is not None or bool(_read_key()), "model": model_name()}


@app.get("/usage")
def usage() -> dict:
    with USAGE.lock:
        return {
            "calls": USAGE.calls,
            "inputTokens": USAGE.input_tokens,
            "outputTokens": USAGE.output_tokens,
            "costUsd": round(USAGE.cost_usd, 6),
            "costInr": round(USAGE.cost_usd * INR_PER_USD, 4),
            "inrPerUsd": INR_PER_USD,
            "note": f"estimate from the price table; INR = USD x {INR_PER_USD} (fixed rate, not live)",
            "since": USAGE.since,
            "lifetimeCostUsd": round(USAGE.lifetime_usd, 4),
            "lifetimeCostInr": round(USAGE.lifetime_usd * INR_PER_USD, 2),
            "capUsd": SPEND_CAP_USD,
            "capReached": over_cap(),
            "reservedUsd": round(USAGE.reserved, 4),
            "ledgerOk": USAGE.ledger_ok,
        }


@app.post("/read")
async def read(request: Request, image: UploadFile | None = File(None)) -> JSONResponse:
    declared = request.headers.get("content-length", "")
    if declared.isdigit() and int(declared) > MAX_IMAGE_BYTES + 65_536:
        raise HTTPException(413, "image too large")
    client = _get_client()
    if client is None:
        raise ReaderFailed(503, "reader not connected", "not_configured")
    if over_cap():  # the app shows "spending limit reached" (and still tries its on-phone reader for printed parchis)
        raise ReaderFailed(503, "reader spending cap reached", "cap_reached")
    if image is None or image.content_type not in ALLOWED_TYPES:
        raise HTTPException(415, "send one image (jpeg, png or heic) in the 'image' field")
    data = await image.read(MAX_IMAGE_BYTES + 1)
    if len(data) > MAX_IMAGE_BYTES:
        raise HTTPException(413, "image too large")
    media_type = _sniff(data)  # trust the bytes, not the label; the API takes jpeg/png only
    if media_type is None:
        raise HTTPException(415, "send a jpeg or png picture (heic must be converted first)")
    lines = await asyncio.to_thread(read_photo, client, data, media_type)
    return JSONResponse({"lines": lines})
