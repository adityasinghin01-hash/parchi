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
import os
import re
import threading
import time
from pathlib import Path

import anthropic
from fastapi import FastAPI, File, HTTPException, Request, UploadFile
from fastapi.responses import JSONResponse

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
CONNECT_TIMEOUT_S = 20
TOTAL_TIMEOUT_S = 60
RETRY_DELAY_S = 1.0
INR_PER_USD = 88
# Hard stop for REAL spending (the user's limit is Rs 500; a $5 top-up). Counted across restarts in data/reader_spend.json.
SPEND_CAP_USD = float(os.environ.get("PARCHI_SPEND_CAP_USD", "4.5"))
SPEND_FILE = Path(os.environ.get("PARCHI_SPEND_FILE") or Path(__file__).resolve().parent / "data" / "reader_spend.json")
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
                timeout=anthropic.Timeout(TOTAL_TIMEOUT_S, connect=CONNECT_TIMEOUT_S)))
        return _client_cache[1]


class Usage:
    def __init__(self) -> None:
        self.lock = threading.Lock()
        self.reset()
        self.lifetime_usd = self._load()

    @staticmethod
    def _load() -> float:
        try:
            return max(0.0, float(json.loads(SPEND_FILE.read_text(encoding="utf-8"))["usd"]))
        except (OSError, ValueError, KeyError, TypeError):
            return 0.0

    def _save(self) -> None:
        try:  # best effort; the prepaid balance is the real limit
            SPEND_FILE.parent.mkdir(parents=True, exist_ok=True)
            tmp = SPEND_FILE.with_suffix(".tmp")
            tmp.write_text(json.dumps({"usd": round(self.lifetime_usd, 6)}), encoding="utf-8")
            os.chmod(tmp, 0o600)
            os.replace(tmp, SPEND_FILE)
        except OSError:
            log.warning("could not save the spend counter")

    def reset(self) -> None:
        self.calls = 0
        self.input_tokens = 0
        self.output_tokens = 0
        self.cost_usd = 0.0
        self.since = time.strftime("%Y-%m-%dT%H:%M:%S%z")

    def add(self, model: str, input_tokens: int, output_tokens: int) -> None:
        price_in, price_out = PRICES.get(model) or next(
            (p for name, p in PRICES.items() if model.startswith(name)), PRICES[DEFAULT_MODEL])
        with self.lock:
            self.calls += 1
            self.input_tokens += input_tokens
            self.output_tokens += output_tokens
            delta = (input_tokens * price_in + output_tokens * price_out) / 1_000_000
            self.cost_usd += delta
            if real_spend():
                self.lifetime_usd += delta
                self._save()


def real_spend() -> bool:
    """False for tests and for a stub upstream: only calls to the real API count against the cap."""
    return CLIENT_OVERRIDE is None and not os.environ.get("PARCHI_ANTHROPIC_BASE_URL")


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


def _call_once(client, model: str, media_type: str, b64: str):
    return client.messages.create(
        model=model,
        max_tokens=4000,
        output_config={"effort": "low", "format": {"type": "json_schema", "schema": LINES_SCHEMA}},
        messages=[{"role": "user", "content": [
            {"type": "image", "source": {"type": "base64", "media_type": media_type, "data": b64}},
            {"type": "text", "text": PROMPT},
        ]}],
    )


def _call_with_retry(client, model: str, media_type: str, b64: str):
    """Most specific exception first. Retry ONCE after 1 s on 429 / 5xx / connection errors, then 502."""
    for attempt in (1, 2):
        try:
            return _call_once(client, model, media_type, b64)
        except anthropic.RateLimitError:
            retryable, why = True, "429"
        except anthropic.APIStatusError as exc:
            retryable, why = exc.status_code >= 500, str(exc.status_code)
        except anthropic.APIConnectionError as exc:
            retryable, why = True, type(exc).__name__
        if not retryable or attempt == 2:
            log.warning("upstream failed (%s) attempt=%d", why, attempt)
            raise HTTPException(502, CANNOT_READ)
        log.info("upstream %s, retrying once", why)
        time.sleep(RETRY_DELAY_S)
    raise HTTPException(502, CANNOT_READ)  # unreachable


def _lines_from_response(response) -> list[dict]:
    if getattr(response, "stop_reason", None) in ("refusal", "max_tokens"):
        log.warning("model stop_reason=%s", response.stop_reason)
        raise HTTPException(502, CANNOT_READ)
    text = next((b.text for b in getattr(response, "content", []) or [] if getattr(b, "type", None) == "text"), None)
    try:
        parsed = json.loads(text)
    except (TypeError, ValueError):
        log.warning("model reply was not valid JSON")
        raise HTTPException(502, CANNOT_READ)
    if not isinstance(parsed, dict) or not isinstance(parsed.get("lines"), list):
        log.warning("model reply had no lines list")
        raise HTTPException(502, CANNOT_READ)
    return clean_lines(parsed)


def read_photo(client, data: bytes, media_type: str) -> list[dict]:
    model = model_name()
    started = time.monotonic()
    response = _call_with_retry(client, model, media_type, base64.b64encode(data).decode("ascii"))
    usage = getattr(response, "usage", None)
    tokens_in = int(getattr(usage, "input_tokens", 0) or 0)
    tokens_out = int(getattr(usage, "output_tokens", 0) or 0)
    USAGE.add(model, tokens_in, tokens_out)
    lines = _lines_from_response(response)
    log.info("read ok lines=%d in=%d out=%d seconds=%.1f", len(lines), tokens_in, tokens_out, time.monotonic() - started)
    return lines


# ---------------------------------------------------------------- the web app
app = FastAPI(title="Parchi Claude reader", docs_url=None, redoc_url=None, openapi_url=None)


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
        }


@app.post("/read")
async def read(request: Request, image: UploadFile | None = File(None)) -> JSONResponse:
    declared = request.headers.get("content-length", "")
    if declared.isdigit() and int(declared) > MAX_IMAGE_BYTES + 65_536:
        raise HTTPException(413, "image too large")
    client = _get_client()
    if client is None:
        raise HTTPException(503, "reader not connected")
    if over_cap():  # the app then reads on the phone instead (the server maps a reader 503 to "reader not connected")
        raise HTTPException(503, "reader spending cap reached")
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
