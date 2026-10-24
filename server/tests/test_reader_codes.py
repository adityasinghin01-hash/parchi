"""KR (G3/G4/G9/G10): every /read failure carries a machine code; Anthropic's spend limit is never retried; per-install limit."""
import anthropic
import httpx
import httpx2
import pytest

import api
import reader_claude as rc
from test_api import api_client, headers  # noqa: F401
from test_reader_claude import GOOD, Fake, err, post, reply, use, web  # noqa: F401


def _status_error(status, body):
    response = httpx2.Response(status, request=httpx2.Request("POST", "http://upstream.test/v1/messages"))
    cls = {400: anthropic.BadRequestError, 401: anthropic.AuthenticationError, 403: anthropic.PermissionDeniedError,
           429: anthropic.RateLimitError}.get(status, anthropic.APIStatusError)
    return cls("boom-detail-sentinel", response=response, body=body)


SPEND_400 = {"type": "error", "error": {"type": "invalid_request_error",
             "message": "You have reached your specified API usage limits. You will regain access on 2026-11-01."}}
SPEND_429 = {"type": "error", "error": {"type": "enforced_spend_limit_reached", "message": "spend limit"}}


# ------------------------------------------------------------------ reader_claude codes
def test_missing_key_is_not_configured(web):
    r = post(web)
    assert r.status_code == 503 and r.json()["code"] == "not_configured"


@pytest.mark.parametrize("body,status", [(SPEND_400, 400), (SPEND_429, 429)])
def test_anthropic_spend_limit_is_cap_reached_and_never_retried(web, monkeypatch, body, status):
    fake = use(monkeypatch, Fake(_status_error(status, body), reply(GOOD)))
    r = post(web)
    assert r.status_code == 503 and r.json()["code"] == "cap_reached"
    assert len(fake.calls) == 1, "a spend limit must not be retried"


def test_plain_429_is_still_retried_once(web, monkeypatch):
    fake = use(monkeypatch, Fake(_status_error(429, {"type": "error", "error": {"type": "rate_limit_error", "message": "slow"}}), reply(GOOD)))
    assert post(web).status_code == 200 and len(fake.calls) == 2


@pytest.mark.parametrize("status", [401, 403])
def test_bad_key_is_bad_key_and_not_retried(web, monkeypatch, status):
    fake = use(monkeypatch, Fake(_status_error(status, None), reply(GOOD)))
    r = post(web)
    assert r.status_code == 502 and r.json()["code"] == "bad_key" and len(fake.calls) == 1


def test_other_400_is_reader_error(web, monkeypatch):
    fake = use(monkeypatch, Fake(_status_error(400, {"type": "error", "error": {"type": "invalid_request_error", "message": "bad image"}})))
    r = post(web)
    assert r.status_code == 502 and r.json()["code"] == "reader_error" and len(fake.calls) == 1


def test_5xx_twice_is_reader_error(web, monkeypatch):
    use(monkeypatch, Fake(err(anthropic.APIStatusError, 500), err(anthropic.APIStatusError, 529)))
    r = post(web)
    assert r.status_code == 502 and r.json()["code"] == "reader_error"


def test_timeout_twice_is_timeout(web, monkeypatch):
    req = httpx2.Request("POST", "http://upstream.test/v1/messages")
    use(monkeypatch, Fake(anthropic.APITimeoutError(request=req), anthropic.APITimeoutError(request=req)))
    r = post(web)
    assert r.status_code == 504 and r.json()["code"] == "timeout"


def test_ledger_cap_is_cap_reached(web, monkeypatch):
    monkeypatch.setattr(rc, "over_cap", lambda: True)
    use(monkeypatch, Fake())
    r = post(web)
    assert r.status_code == 503 and r.json()["code"] == "cap_reached"


def test_g9_calibration(monkeypatch):
    assert rc.MAX_TOKENS == 2000
    assert rc.RESERVE_USD == {"claude-opus-5-5": 0.07, "claude-sonnet-5-5": 0.04, "claude-haiku-5-5": 0.005}
    monkeypatch.delenv("PARCHI_INR_PER_USD", raising=False)
    assert rc._inr_per_usd() == 97
    monkeypatch.setenv("PARCHI_INR_PER_USD", "95.5")
    assert rc._inr_per_usd() == 95.5
    monkeypatch.setenv("PARCHI_INR_PER_USD", "-1")
    assert rc._inr_per_usd() == 97


def test_max_tokens_is_sent(web, monkeypatch):
    fake = use(monkeypatch, Fake(reply(GOOD)))
    assert post(web).status_code == 200 and fake.calls[0]["max_tokens"] == 2000


def test_usage_says_estimate(web):
    assert "estimate" in web.get("/usage").json()["note"]


# ------------------------------------------------------------------ api.py /read forwards the codes
def _post_image(ctx):
    return ctx.client.post("/read", headers=headers(ctx), files={"image": ("p.jpg", b"\xff\xd8\xffxx", "image/jpeg")})


@pytest.mark.parametrize("upstream,body,status,code", [
    (503, {"detail": "reader not connected", "code": "not_configured"}, 503, "not_configured"),
    (503, {"detail": "reader spending cap reached", "code": "cap_reached"}, 503, "cap_reached"),
    (503, {"detail": "reader not connected"}, 503, "not_configured"),
    (502, {"detail": "x", "code": "bad_key"}, 502, "bad_key"),
    (502, {"detail": "x", "code": "reader_error"}, 502, "reader_error"),
    (504, {"detail": "x", "code": "timeout"}, 504, "timeout"),
    (500, {"detail": "x"}, 502, "reader_error"),
    (502, {"detail": "x", "code": "made_up"}, 502, "reader_error"),
])
def test_server_forwards_reader_codes(api_client, monkeypatch, upstream, body, status, code):
    monkeypatch.setenv("PARCHI_READER_URL", "http://reader.test/read")
    monkeypatch.setattr(api, "READER_TRANSPORT", httpx.MockTransport(lambda req: httpx.Response(upstream, json=body)))
    r = _post_image(api_client)
    assert r.status_code == status and r.json()["code"] == code


def test_server_timeout_is_timeout(api_client, monkeypatch):
    monkeypatch.setenv("PARCHI_READER_URL", "http://reader.test/read")

    def slow(request):
        raise httpx.ReadTimeout("slow")

    monkeypatch.setattr(api, "READER_TRANSPORT", httpx.MockTransport(slow))
    r = _post_image(api_client)
    assert r.status_code == 504 and r.json()["code"] == "timeout"


# ------------------------------------------------------------------ G10 per-install limit
def test_seventh_read_in_a_minute_is_slow_down(api_client, monkeypatch):
    monkeypatch.setenv("PARCHI_READER_URL", "http://reader.test/read")
    calls = []
    monkeypatch.setattr(api, "READER_TRANSPORT", httpx.MockTransport(lambda req: calls.append(1) or httpx.Response(200, json={"lines": []})))
    clock = [1000.0]
    monkeypatch.setattr(api, "_read_clock", lambda: clock[0])
    for _ in range(6):
        assert _post_image(api_client).status_code == 200
    r = _post_image(api_client)
    assert r.status_code == 429 and r.json()["code"] == "slow_down"
    assert 1 <= int(r.headers["Retry-After"]) <= 60
    assert len(calls) == 6, "a refused request never reaches the reader (no spend)"
    other = api_client.client.post("/read", headers={"X-Install-Key": api_client.other_key},
                                   files={"image": ("p.jpg", b"\xff\xd8\xffxx", "image/jpeg")})
    assert other.status_code == 200, "the limit is per install"
    clock[0] += 60.0
    assert _post_image(api_client).status_code == 200, "the window slides"
