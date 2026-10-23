"""reader_claude spending cap: the user's limit is Rs 500 (a $5 top-up). Real calls are counted across restarts and stop at the cap."""
import json

import pytest
from fastapi.testclient import TestClient

import reader_claude as rc
from test_api import api_client  # noqa: F401  (reused fixture)
from test_reader_claude import Fake, JPEG, reply


@pytest.fixture
def capped(monkeypatch, tmp_path):
    monkeypatch.setattr(rc, "SPEND_FILE", tmp_path / "reader_spend.json")
    monkeypatch.setattr(rc, "SPEND_CAP_USD", 4.5)
    monkeypatch.setattr(rc, "RETRY_DELAY_S", 0)
    monkeypatch.delenv("PARCHI_ANTHROPIC_BASE_URL", raising=False)
    monkeypatch.setattr(rc, "CLIENT_OVERRIDE", None)
    monkeypatch.setattr(rc, "_client_cache", None)
    monkeypatch.setattr(rc, "USAGE", rc.Usage())
    return tmp_path


def test_real_spend_is_saved_and_survives_a_restart(capped):
    rc.USAGE.add("claude-opus-5-5", 1_000_000, 0)            # $4.00
    assert json.loads((capped / "reader_spend.json").read_text())["usd"] == 4.0
    assert rc.Usage().lifetime_usd == 4.0                    # a new process starts from the saved total
    assert (capped / "reader_spend.json").stat().st_mode & 0o077 == 0, "owner-only file"


def test_fake_client_and_stub_upstream_never_count(capped, monkeypatch):
    monkeypatch.setattr(rc, "CLIENT_OVERRIDE", Fake())
    rc.USAGE.add("claude-opus-5-5", 1_000_000, 0)
    assert rc.USAGE.lifetime_usd == 0 and not (capped / "reader_spend.json").exists()
    monkeypatch.setattr(rc, "CLIENT_OVERRIDE", None)
    monkeypatch.setenv("PARCHI_ANTHROPIC_BASE_URL", "http://127.0.0.1:8199")
    rc.USAGE.add("claude-opus-5-5", 1_000_000, 0)
    assert rc.USAGE.lifetime_usd == 0, "a stub upstream costs nothing"


def test_cap_reached_answers_503_and_makes_no_call(capped, monkeypatch):
    fake = Fake(reply({"lines": []}))
    monkeypatch.setattr(rc, "_get_client", lambda: fake)     # a "real" client object, no CLIENT_OVERRIDE, no stub env
    rc.USAGE.lifetime_usd = 4.5
    web = TestClient(rc.app)
    response = web.post("/read", files={"image": ("p.jpg", JPEG, "image/jpeg")})
    assert response.status_code == 503 and "cap" in response.json()["detail"]
    assert fake.calls == [], "no money is spent once the cap is reached"
    usage = web.get("/usage").json()
    assert usage["capReached"] is True and usage["capUsd"] == 4.5 and usage["lifetimeCostUsd"] == 4.5


def test_below_the_cap_still_reads(capped, monkeypatch):
    fake = Fake(reply({"lines": [{"kind": "medicine", "name": "Telma", "strength": "40", "quantity": None, "schedule": None}]}))
    monkeypatch.setattr(rc, "_get_client", lambda: fake)
    rc.USAGE.lifetime_usd = 4.49
    response = TestClient(rc.app).post("/read", files={"image": ("p.jpg", JPEG, "image/jpeg")})
    assert response.status_code == 200 and response.json()["lines"][0]["name"] == "Telma"
    assert rc.USAGE.lifetime_usd > 4.49, "the call was counted"


def test_server_maps_a_reader_503_to_reader_not_connected(api_client, monkeypatch):
    """The reader says 'no key' or 'spending cap reached' with a 503: the server tells the app 'reader not connected' (not a 502),
    which is what makes the app read the photo on the phone instead of showing an error."""
    import httpx
    import api
    monkeypatch.setenv("PARCHI_READER_URL", "http://reader.test:8100/read")
    monkeypatch.setattr(api, "READER_TRANSPORT", httpx.MockTransport(lambda req: httpx.Response(503, json={"detail": "reader spending cap reached"})))
    r = api_client.client.post("/read", headers={"X-Install-Key": api_client.key}, files={"image": ("p.png", b"\x89PNG\r\n\x1a\nx", "image/png")})
    assert r.status_code == 503 and r.json()["detail"] == "reader not connected"
    monkeypatch.setattr(api, "READER_TRANSPORT", httpx.MockTransport(lambda req: httpx.Response(500, text="boom")))
    r = api_client.client.post("/read", headers={"X-Install-Key": api_client.key}, files={"image": ("p.png", b"\x89PNG\r\n\x1a\nx", "image/png")})
    assert r.status_code == 502, "a real reader error stays a 502"
