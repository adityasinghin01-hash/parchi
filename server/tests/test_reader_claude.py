"""reader_claude: every test uses an injected fake client. No network, no key."""
import base64
import json
import logging
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
    assert call["model"] == "claude-opus-5-5" and call["max_tokens"] == 4000
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
    assert r.status_code == 502 and r.json() == {"detail": "reader could not read this photo"}


@pytest.mark.parametrize("text", ["not json {", "", "[1,2]", '{"rows": []}', '{"lines": "x"}'])
def test_invalid_json_is_502(web, monkeypatch, text):
    use(monkeypatch, Fake(reply(None, raw_text=text)))
    r = post(web)
    assert r.status_code == 502 and r.json() == {"detail": "reader could not read this photo"}


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
    assert r.status_code == 503 and r.json() == {"detail": "reader not connected"}
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
    assert r.status_code == 502 and r.json() == {"detail": "reader could not read this photo"}
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
    assert u["costInr"] == pytest.approx(u["costUsd"] * 88, rel=1e-3) and u["inrPerUsd"] == 88
    assert "x 88" in u["note"] and set(u) >= {"calls", "inputTokens", "outputTokens", "costUsd", "costInr"}


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
