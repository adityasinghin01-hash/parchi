"""reader_claude: every test uses an injected fake client. No network, no key."""
import base64
import json
import logging
import os
import subprocess
import sys
from pathlib import Path
from types import SimpleNamespace

import anthropic
import httpx2
import pytest
from fastapi.testclient import TestClient

import reader_claude as rc

JPEG = b"\xff\xd8\xff\xe0" + b"IMAGE-SENTINEL-BYTES" + b"\x00" * 64
PNG = b"\x89PNG\r\n\x1a\n" + b"png-body"


def _req():
    return httpx2.Request("POST", "http://upstream.test/v1/messages")


def err(cls, status):
    return cls("boom-detail-sentinel", response=httpx2.Response(status, request=_req()), body=None)


def reply(payload, stop_reason="end_turn", tokens=(1000, 200), raw_text=None):
    text = raw_text if raw_text is not None else json.dumps(payload)
    return SimpleNamespace(
        stop_reason=stop_reason,
        content=[SimpleNamespace(type="text", text=text)],
        usage=SimpleNamespace(input_tokens=tokens[0], output_tokens=tokens[1]),
    )


class Fake:
    """Scripted: each call pops the next item; exceptions are raised, anything else is returned."""

    def __init__(self, *script):
        self.script = list(script)
        self.calls = []
        self.messages = self

    def create(self, **kwargs):
        self.calls.append(kwargs)
        item = self.script.pop(0)
        if isinstance(item, Exception):
            raise item
        return item


@pytest.fixture
def web(monkeypatch, tmp_path):
    monkeypatch.setattr(rc, "RETRY_DELAY_S", 0)
    monkeypatch.setattr(rc, "KEY_FILE", tmp_path / "anthropic.key")
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    monkeypatch.delenv("PARCHI_READER_MODEL", raising=False)
    monkeypatch.setattr(rc, "CLIENT_OVERRIDE", None)
    monkeypatch.setattr(rc, "_client_cache", None)
    rc.USAGE.reset()
    return TestClient(rc.app)


def use(monkeypatch, fake):
    monkeypatch.setattr(rc, "CLIENT_OVERRIDE", fake)
    return fake


def post(web, data=JPEG, ctype="image/jpeg", field="image"):
    return web.post("/read", files={field: ("p", data, ctype)})


GOOD = {"lines": [
    {"kind": "medicine", "name": "Telma", "strength": "40", "quantity": 30, "schedule": "1-0-0"},
    {"kind": "test", "name": "HbA1c", "strength": None, "quantity": None, "schedule": None},
]}


# ------------------------------------------------------------------ contract
def test_contract_shape_and_call_parameters(web, monkeypatch):
    fake = use(monkeypatch, Fake(reply(GOOD)))
    r = post(web)
    assert r.status_code == 200
    assert r.json() == {"lines": [
        {"kind": "medicine", "name": "Telma", "strength": "40", "quantity": 30, "schedule": "1-0-0"},
        {"kind": "test", "name": "HbA1c"},
    ]}
    call = fake.calls[0]
    assert call["model"] == "claude-opus-5-5" and call["max_tokens"] == 2000
    assert call["output_config"]["effort"] == "low"
    fmt = call["output_config"]["format"]
    assert fmt["type"] == "json_schema" and fmt["schema"]["additionalProperties"] is False
    item = fmt["schema"]["properties"]["lines"]["items"]
    assert item["additionalProperties"] is False and set(item["required"]) == set(item["properties"])
    for forbidden in ("temperature", "top_p", "top_k", "thinking", "tool_choice", "budget_tokens"):
        assert forbidden not in call
    content = call["messages"][0]["content"]
    assert [m["role"] for m in call["messages"]] == ["user"]
    assert content[0]["source"]["media_type"] == "image/jpeg"
    assert base64.b64decode(content[0]["source"]["data"]) == JPEG
    assert content[1]["text"] == rc.PROMPT


def test_png_media_type_and_model_switch(web, monkeypatch):
    monkeypatch.setenv("PARCHI_READER_MODEL", "claude-haiku-5-5")
    fake = use(monkeypatch, Fake(reply({"lines": []})))
    assert post(web, PNG, "image/png").json() == {"lines": []}
    assert fake.calls[0]["model"] == "claude-haiku-5-5"
    assert fake.calls[0]["messages"][0]["content"][0]["source"]["media_type"] == "image/png"


def test_label_says_heic_but_bytes_are_jpeg_is_accepted_real_heic_is_415(web, monkeypatch):
    use(monkeypatch, Fake(reply({"lines": []})))
    assert post(web, JPEG, "image/heic").status_code == 200
    use(monkeypatch, Fake())
    assert post(web, b"\x00\x00\x00\x18ftypheic" + b"x" * 40, "image/heic").status_code == 415


def test_empty_list(web, monkeypatch):
    use(monkeypatch, Fake(reply({"lines": []})))
    assert post(web).json() == {"lines": []}


# ------------------------------------------------------------------ failures
@pytest.mark.parametrize("stop", ["refusal", "max_tokens"])
def test_refusal_and_max_tokens_are_502_never_partial(web, monkeypatch, stop):
    use(monkeypatch, Fake(reply(GOOD, stop_reason=stop)))
    r = post(web)
    assert r.status_code == 502 and r.json() == {"detail": "reader could not read this photo", "code": "reader_error"}


@pytest.mark.parametrize("text", ["not json {", "", "[1,2]", '{"rows": []}', '{"lines": "x"}'])
def test_invalid_json_is_502(web, monkeypatch, text):
    use(monkeypatch, Fake(reply(None, raw_text=text)))
    r = post(web)
    assert r.status_code == 502 and r.json() == {"detail": "reader could not read this photo", "code": "reader_error"}


def test_no_text_block_is_502(web, monkeypatch):
    bad = SimpleNamespace(stop_reason="end_turn", content=[], usage=SimpleNamespace(input_tokens=1, output_tokens=1))
    use(monkeypatch, Fake(bad))
    assert post(web).status_code == 502


def test_bad_type_415_and_missing_field_415(web, monkeypatch):
    use(monkeypatch, Fake())
    assert post(web, b"%PDF-1.4", "application/pdf").status_code == 415
    assert post(web, JPEG, "image/jpeg", field="file").status_code == 415
    assert post(web, b"GIF89a....", "image/jpeg").status_code == 415  # label lies, bytes are not jpeg/png


def test_too_big_413(web, monkeypatch):
    fake = use(monkeypatch, Fake())
    assert post(web, JPEG + b"0" * rc.MAX_IMAGE_BYTES).status_code == 413
    assert fake.calls == []


def test_exactly_at_limit_is_not_413(web, monkeypatch):
    use(monkeypatch, Fake(reply({"lines": []})))
    assert post(web, JPEG + b"0" * (rc.MAX_IMAGE_BYTES - len(JPEG))).status_code == 200


def test_missing_key_is_503(web):
    r = post(web)
    assert r.status_code == 503 and r.json() == {"detail": "reader not connected", "code": "not_configured"}
    assert web.get("/health").json()["keyConfigured"] is False


def test_key_from_env_then_file(web, monkeypatch, tmp_path):
    assert rc._read_key() == ""
    (tmp_path / "anthropic.key").write_text("file-key-1\nsecond line\n")
    assert rc._read_key() == "file-key-1"
    monkeypatch.setenv("ANTHROPIC_API_KEY", "env-key")
    assert rc._read_key() == "env-key"
    assert web.get("/health").json() == {"ok": True, "keyConfigured": True, "model": "claude-opus-5-5"}


def test_base_url_env_reaches_the_sdk_client(web, monkeypatch):
    monkeypatch.setenv("ANTHROPIC_API_KEY", "k")
    monkeypatch.setenv("PARCHI_ANTHROPIC_BASE_URL", "http://127.0.0.1:9999")
    client = rc._get_client()
    assert str(client.base_url).startswith("http://127.0.0.1:9999") and client.max_retries == 0


# ------------------------------------------------------------------ retry
@pytest.mark.parametrize("first", [
    err(anthropic.RateLimitError, 429),
    err(anthropic.APIStatusError, 503),
    err(anthropic.APIStatusError, 529),
    anthropic.APIConnectionError(request=_req()),
    anthropic.APITimeoutError(request=_req()),
])
def test_retry_once_then_success(web, monkeypatch, first):
    fake = use(monkeypatch, Fake(first, reply(GOOD)))
    assert post(web).status_code == 200 and len(fake.calls) == 2


def test_retry_once_then_502(web, monkeypatch):
    fake = use(monkeypatch, Fake(err(anthropic.RateLimitError, 429), err(anthropic.RateLimitError, 429), reply(GOOD)))
    r = post(web)
    assert r.status_code == 502 and r.json() == {"detail": "reader could not read this photo", "code": "reader_error"}
    assert len(fake.calls) == 2


def test_client_errors_are_not_retried(web, monkeypatch):
    fake = use(monkeypatch, Fake(err(anthropic.APIStatusError, 401), reply(GOOD)))
    assert post(web).status_code == 502 and len(fake.calls) == 1


# ------------------------------------------------------------------ hygiene (pure function)
def test_hygiene_rules():
    raw = {"lines": [
        {"kind": "medicine", "name": "  Tel\x00ma\n 40  ", "strength": " 40 ", "quantity": 30, "schedule": "1-0-1"},
        {"kind": "drug", "name": "Dolo", "quantity": 0},
        {"kind": "test", "name": "   "},
        {"kind": "test", "name": ""},
        {"name": 5},
        "junk",
        {"kind": "medicine", "name": "A" * 200, "quantity": 10001},
        {"kind": "medicine", "name": "B", "quantity": True},
        {"kind": "medicine", "name": "C", "quantity": 10000, "strength": "", "schedule": None},
        {"kind": "medicine", "name": "D", "quantity": 2.0},
        {"kind": "medicine", "name": "E", "quantity": 2.5},
        {"kind": "medicine", "name": "F", "quantity": "7"},
        {"kind": "medicine", "name": "G", "quantity": -3},
    ]}
    out = rc.clean_lines(raw)
    assert out[0] == {"kind": "medicine", "name": "Telma 40", "strength": "40",
                      "quantity": 30, "schedule": "1-0-1"}
    assert out[1] == {"kind": "medicine", "name": "Dolo"}  # unknown kind -> medicine, quantity 0 omitted
    assert out[2] == {"kind": "medicine", "name": "A" * 80}
    assert out[3] == {"kind": "medicine", "name": "B"}
    assert out[4] == {"kind": "medicine", "name": "C", "quantity": 10000}
    assert out[5]["quantity"] == 2 and "quantity" not in out[6] and out[7]["quantity"] == 7 and "quantity" not in out[8]
    assert len(out) == 9


def test_hygiene_caps_30_and_survives_garbage():
    assert len(rc.clean_lines({"lines": [{"kind": "medicine", "name": f"M{i}"} for i in range(50)]})) == 30
    for junk in (None, 5, "x", {}, {"lines": None}, {"lines": [None, 1, []]}):
        assert rc.clean_lines(junk) == []


def test_control_characters_stripped():
    out = rc.clean_lines({"lines": [{"name": "Pan\x07to\u200bp\x7f", "schedule": "1\t-\n0-1"}]})
    assert out == [{"kind": "medicine", "name": "Pantop", "schedule": "1 - 0-1"}]


# ------------------------------------------------------------------ usage
def test_usage_counts_and_cost(web, monkeypatch):
    use(monkeypatch, Fake(reply(GOOD, tokens=(1_000_000, 100_000)), reply(GOOD, tokens=(1000, 200))))
    post(web); post(web)
    u = web.get("/usage").json()
    assert u["calls"] == 2 and u["inputTokens"] == 1_001_000 and u["outputTokens"] == 100_200
    assert u["costUsd"] == pytest.approx(4.004 + 2.004, abs=1e-4)  # opus: $4/M in, $20/M out
    assert u["costInr"] == pytest.approx(u["costUsd"] * 97, rel=1e-3) and u["inrPerUsd"] == 97
    assert "x 97.0" in u["note"] and set(u) >= {"calls", "inputTokens", "outputTokens", "costUsd", "costInr"}


def test_price_table_per_model(monkeypatch):
    for model, expected in (("claude-sonnet-5-5", 2 + 10), ("claude-haiku-5-5", 0.10 + 0.50), ("claude-opus-5-5", 4 + 20)):
        u = rc.Usage(); u.add(model, 1_000_000, 1_000_000)
        assert u.cost_usd == pytest.approx(expected)


# ------------------------------------------------------------------ privacy: nothing sensitive is ever logged
def test_logs_never_contain_key_image_or_model_text(web, monkeypatch, caplog, capsys, tmp_path):
    secret_key = "sk-ant-SECRET-KEY-SENTINEL"
    model_text = "MODEL-TEXT-SENTINEL"
    (tmp_path / "anthropic.key").write_text(secret_key + "\n")
    payload = {"lines": [{"kind": "medicine", "name": model_text, "strength": None, "quantity": None, "schedule": None}]}
    fake = Fake(err(anthropic.RateLimitError, 429), reply(payload),   # success after a retry
                reply(None, raw_text="not json " + model_text),       # invalid JSON containing model text
                reply(payload, stop_reason="refusal"),
                err(anthropic.APIStatusError, 500), err(anthropic.APIStatusError, 500))
    monkeypatch.setattr(rc, "CLIENT_OVERRIDE", fake)
    caplog.set_level(logging.DEBUG)
    for logger in ("reader_claude", "uvicorn", "uvicorn.error", "httpx", "anthropic", "httpcore"):
        logging.getLogger(logger).setLevel(logging.DEBUG)
    codes = [post(web).status_code for _ in range(4)]
    assert codes == [200, 502, 502, 502]
    web.get("/health"); web.get("/usage")
    everything = caplog.text + capsys.readouterr().out + capsys.readouterr().err
    assert everything  # we do log something (counts, status codes)
    image_b64 = base64.b64encode(JPEG).decode()
    for needle in (secret_key, model_text, "IMAGE-SENTINEL", image_b64, "boom-detail-sentinel", "Indian doctor"):
        assert needle not in everything
    for response in (web.get("/health").text, web.get("/usage").text):
        assert secret_key not in response and model_text not in response


# ------------------------------------------------------------------ K28/15: the REAL SDK must not log the photo
PROBE = """
import sys
if sys.argv[1] == "guard":
    import reader_claude  # noqa: F401  (pops ANTHROPIC_LOG and silences the SDK loggers at import)
import anthropic, httpx2

def handler(request):
    return httpx2.Response(200, json={"id": "m", "type": "message", "role": "assistant", "model": "x", "stop_sequence": None,
        "content": [{"type": "text", "text": "{\\"lines\\": []}"}], "stop_reason": "end_turn",
        "usage": {"input_tokens": 1, "output_tokens": 1}})

client = anthropic.Anthropic(api_key="k", base_url="http://up.test", max_retries=0,
                             http_client=httpx2.Client(transport=httpx2.MockTransport(handler)))
data = "IMAGEBASE64SENTINEL" * 20
client.messages.create(model="claude-opus-5-5", max_tokens=10, messages=[{"role": "user", "content": [
    {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": data}}]}])
print("CALL-OK")
"""


def _run_probe(mode):
    env = {**os.environ, "ANTHROPIC_LOG": "debug", "PYTHONPATH": str(Path(rc.__file__).parent)}
    out = subprocess.run([sys.executable, "-c", PROBE, mode], env=env, capture_output=True, text=True, timeout=60,
                         cwd=str(Path(rc.__file__).parent))
    assert "CALL-OK" in out.stdout, out.stderr
    return out.stdout + out.stderr


def test_sdk_debug_env_would_leak_the_image_without_the_guard_and_does_not_with_it():
    leaky = _run_probe("plain")
    assert "IMAGEBASE64SENTINEL" in leaky, "control: with ANTHROPIC_LOG=debug the bare SDK does log the photo"
    guarded = _run_probe("guard")
    assert "IMAGEBASE64SENTINEL" not in guarded and "Request options" not in guarded and "DEBUG" not in guarded


def test_forced_debug_levels_are_still_silent_through_the_real_sdk(monkeypatch, caplog):
    """Someone sets the SDK/HTTP loggers to DEBUG at run time: the filter still keeps the request body out of the log."""
    import httpx2
    monkeypatch.delenv("ANTHROPIC_LOG", raising=False)
    handler = lambda request: httpx2.Response(200, json={"id": "m", "type": "message", "role": "assistant", "model": "x",
        "stop_sequence": None, "content": [{"type": "text", "text": "{}"}], "stop_reason": "end_turn",
        "usage": {"input_tokens": 1, "output_tokens": 1}})
    client = anthropic.Anthropic(api_key="k", base_url="http://up.test", max_retries=0,
                                 http_client=httpx2.Client(transport=httpx2.MockTransport(handler)))
    names = ["anthropic", "anthropic._base_client", "httpx", "httpx2", "httpcore"]
    try:
        for name in names:
            logging.getLogger(name).setLevel(logging.DEBUG)
        caplog.set_level(logging.DEBUG)
        rc._call_once(client, "claude-opus-5-5", "image/jpeg", "IMAGEBASE64SENTINEL" * 20)
    finally:
        rc.silence_sdk_logging()
    assert "IMAGEBASE64SENTINEL" not in caplog.text
    assert not [r for r in caplog.records if r.name.split(".")[0] in ("anthropic", "httpx", "httpx2", "httpcore") and r.levelno < logging.WARNING]


def test_import_removes_the_env_var_and_pins_the_loggers():
    assert "ANTHROPIC_LOG" not in os.environ
    for name in ("anthropic", "httpx", "httpx2", "httpcore"):
        lg = logging.getLogger(name)
        assert lg.level == logging.WARNING and any(isinstance(f, rc._DropBelowWarning) for f in lg.filters)
    assert not rc._DropBelowWarning().filter(logging.LogRecord("anthropic._base_client", logging.DEBUG, "", 0, "x", None, None))
    assert rc._DropBelowWarning().filter(logging.LogRecord("anthropic._base_client", logging.WARNING, "", 0, "x", None, None))
    assert rc._DropBelowWarning().filter(logging.LogRecord("reader_claude", logging.INFO, "", 0, "x", None, None))


# ------------------------------------------------------------------ K28/16: one end-to-end time budget
def test_budget_ordering_and_constants():
    """app 65 s > server and scan page 60 s > reader deadline 50 s (plus a few seconds of connect/write slack)."""
    assert rc.TOTAL_DEADLINE_S == 50 and rc.MIN_RETRY_REMAINING_S == 15
    assert rc.TOTAL_DEADLINE_S + rc.CONNECT_TIMEOUT_S <= 60 < 65


def test_attempt_timeouts_never_exceed_what_is_left():
    for remaining in (50, 49.2, 30, 15, 5, 1.5):
        connect, rest = rc.attempt_timeouts(remaining)
        assert connect + rest <= remaining + 1e-9 and connect <= rc.CONNECT_TIMEOUT_S
    assert rc.attempt_timeouts(50) == (10, 40)
    assert rc.attempt_timeouts(0)[0] >= 0.5 and rc.attempt_timeouts(-3)[1] >= 0.5   # never zero/negative


def test_may_retry_needs_15_seconds_after_the_pause():
    assert rc.may_retry(16.0) is True and rc.may_retry(16.0 - 1e-6) is False and rc.may_retry(15.0) is False
    assert rc.may_retry(49) is True and rc.may_retry(0) is False and rc.may_retry(-5) is False


class Clock:
    def __init__(self):
        self.t = 1000.0

    def now(self):
        return self.t

    def sleep(self, seconds):
        self.t += seconds


def _clocked(monkeypatch):
    clock = Clock()
    monkeypatch.setattr(rc, "_now", clock.now)
    monkeypatch.setattr(rc, "_sleep", clock.sleep)
    monkeypatch.setattr(rc, "RETRY_DELAY_S", 1.0)
    return clock


class SlowFail(Fake):
    """Each call 'takes' `cost` seconds on the fake clock and then raises/returns the next scripted item."""

    def __init__(self, clock, cost, *script):
        super().__init__(*script)
        self.clock, self.cost = clock, cost

    def create(self, **kwargs):
        self.clock.t += self.cost
        return super().create(**kwargs)


def test_retry_happens_when_enough_deadline_is_left_and_each_call_gets_the_remainder(web, monkeypatch):
    clock = _clocked(monkeypatch)
    fake = SlowFail(clock, 10, err(anthropic.RateLimitError, 429), reply(GOOD))
    assert rc.read_photo(fake, JPEG, "image/jpeg")
    assert len(fake.calls) == 2
    first, second = fake.calls[0]["timeout"], fake.calls[1]["timeout"]
    assert (first.connect, first.read) == (10, 40)                 # 50 s left at the start
    assert second.connect + second.read <= 50 - 10 - 1 + 1e-9      # 10 s spent + 1 s pause: 39 s left, never the full 50


def test_no_retry_when_less_than_15_seconds_remain(web, monkeypatch):
    clock = _clocked(monkeypatch)
    fake = SlowFail(clock, 35.5, err(anthropic.APIStatusError, 503), reply(GOOD))   # 14.5 s left, 13.5 after the pause
    r = post_via(web, monkeypatch, fake)
    assert r.status_code == 502 and len(fake.calls) == 1, "too little time left: fail now rather than run past the deadline"


def test_retry_at_exactly_the_boundary(web, monkeypatch):
    clock = _clocked(monkeypatch)
    ok = SlowFail(clock, 34.0, err(anthropic.APIStatusError, 503), reply(GOOD))     # 16 s left, 15 after the pause
    assert post_via(web, monkeypatch, ok).status_code == 200 and len(ok.calls) == 2
    clock.t = 1000.0
    late = SlowFail(clock, 34.1, err(anthropic.APIStatusError, 503), reply(GOOD))   # 15.9 s left, 14.9 after the pause
    assert post_via(web, monkeypatch, late).status_code == 502 and len(late.calls) == 1


def test_total_time_never_passes_the_deadline_plus_slack(web, monkeypatch):
    """Worst case on the fake clock: every attempt uses its whole timeout. Elapsed stays under the 60 s the server waits."""
    clock = _clocked(monkeypatch)
    start = clock.t

    class UsesItAll(Fake):
        def create(self, **kwargs):
            t = kwargs["timeout"]
            clock.t += 20 if not self.calls else t.connect + t.read   # attempt 1 fails after 20 s, attempt 2 uses all it has
            return super().create(**kwargs)

    fake = UsesItAll(anthropic.APITimeoutError(request=_req()), anthropic.APITimeoutError(request=_req()))
    r = post_via(web, monkeypatch, fake)   # KR: a timeout now answers 504 + code "timeout" (was a plain 502)
    assert r.status_code == 504 and r.json()["code"] == "timeout" and len(fake.calls) == 2
    assert clock.t - start <= rc.TOTAL_DEADLINE_S + 1e-9 < 60


def post_via(web, monkeypatch, fake):
    use(monkeypatch, fake)
    return post(web)
