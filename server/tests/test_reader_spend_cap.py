"""reader_claude spending cap: the user's limit is Rs 500 (a $5 top-up). Real calls are counted across restarts and stop at the cap."""
import json

import anthropic
import pytest
from fastapi.testclient import TestClient

import reader_claude as rc
from test_api import api_client  # noqa: F401  (reused fixture)
from test_reader_claude import Fake, JPEG, err, reply


@pytest.fixture
def capped(monkeypatch, tmp_path):
    monkeypatch.setattr(rc, "SPEND_FILE", tmp_path / "reader_spend.json")
    monkeypatch.setattr(rc, "SPEND_CAP_USD", 4.5)
    monkeypatch.setattr(rc, "RETRY_DELAY_S", 0)
    monkeypatch.delenv("PARCHI_ANTHROPIC_BASE_URL", raising=False)
    monkeypatch.delenv("PARCHI_READER_TEST_UPSTREAM", raising=False)
    monkeypatch.delenv("PARCHI_RESERVE_USD", raising=False)
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
    monkeypatch.setenv("PARCHI_READER_TEST_UPSTREAM", "1")
    rc.USAGE.add("claude-opus-5-5", 1_000_000, 0)
    assert rc.USAGE.lifetime_usd == 0, "an explicit test upstream costs nothing"


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
    rc.USAGE.lifetime_usd = 4.4   # 4.4 + the $0.06 Opus reservation fits under 4.5
    response = TestClient(rc.app).post("/read", files={"image": ("p.jpg", JPEG, "image/jpeg")})
    assert response.status_code == 200 and response.json()["lines"][0]["name"] == "Telma"
    assert rc.USAGE.lifetime_usd > 4.4 and rc.USAGE.reserved == 0, "the call was counted and its reservation reconciled"


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


# ------------------------------------------------------------------ K28/12: reserve before dispatch, threads
def test_concurrent_reads_never_exceed_the_cap(capped):
    """10 simultaneous reads at $4.40: only one $0.06 reservation fits under 4.5; the rest are refused BEFORE any call."""
    import threading
    rc.USAGE.lifetime_usd = 4.4
    inside, release, started = threading.Event(), threading.Event(), threading.Barrier(10)
    in_flight, peak, lock = [0], [0], threading.Lock()
    results = []

    class Slow(Fake):
        def create(self, **kwargs):
            with lock:
                in_flight[0] += 1; peak[0] = max(peak[0], in_flight[0])
            self.calls.append(kwargs)
            inside.set(); release.wait(5)
            with lock:
                in_flight[0] -= 1
            return reply({"lines": []}, tokens=(1000, 200))

    fake = Slow()

    def worker():
        started.wait(5)
        try:
            rc.read_photo(fake, JPEG, "image/jpeg"); results.append(200)
        except rc.HTTPException as exc:
            results.append(exc.status_code)

    threads = [threading.Thread(target=worker) for _ in range(10)]
    for t in threads:
        t.start()
    assert inside.wait(5)
    for _ in range(100):  # the nine refused workers finish while the one reservation is still held
        if len(results) == 9:
            break
        import time; time.sleep(0.05)
    assert sorted(results) == [503] * 9
    assert rc.USAGE.reserved == pytest.approx(0.06) and rc.USAGE.lifetime_usd + rc.USAGE.reserved <= 4.5 + 1e-9
    release.set()
    for t in threads:
        t.join(5)
    assert sorted(results) == [200] + [503] * 9 and len(fake.calls) == 1 and peak[0] == 1
    assert rc.USAGE.reserved == 0 and rc.USAGE.lifetime_usd == pytest.approx(4.4 + 0.008)


def test_many_slots_never_overbook(capped):
    """Cap room for 8 reservations (0.5 / 0.06); 40 threads; the reserved total never passes the room and at most 8 run."""
    import threading
    rc.USAGE.lifetime_usd = 4.0
    release, lock = threading.Event(), threading.Lock()
    state = {"now": 0, "peak": 0, "max_total": 0.0}

    class Slow(Fake):
        def create(self, **kwargs):
            with lock:
                state["now"] += 1; state["peak"] = max(state["peak"], state["now"])
                state["max_total"] = max(state["max_total"], rc.USAGE.lifetime_usd + rc.USAGE.reserved)
            release.wait(0.3)
            with lock:
                state["now"] -= 1
            return reply({"lines": []}, tokens=(1000, 200))

    codes = []

    def worker():
        try:
            rc.read_photo(Slow(), JPEG, "image/jpeg"); codes.append(200)
        except rc.HTTPException as exc:
            codes.append(exc.status_code)

    threads = [threading.Thread(target=worker) for _ in range(40)]
    for t in threads:
        t.start()
    for t in threads:
        t.join(10)
    assert state["peak"] <= 8 and state["max_total"] <= 4.5 + 1e-9
    assert codes.count(200) >= 8 and set(codes) <= {200, 503} and rc.USAGE.reserved == 0
    assert rc.USAGE.lifetime_usd <= 4.5


def test_reservation_is_released_on_failure_and_reconciled_on_success(capped):
    rc.RETRY_DELAY_S = 0
    for failing in (err(anthropic.APIStatusError, 401), RuntimeError("odd"), err(anthropic.RateLimitError, 429)):
        script = [failing, failing] if not isinstance(failing, RuntimeError) else [failing]
        with pytest.raises(Exception):
            rc.read_photo(Fake(*script), JPEG, "image/jpeg")
        assert rc.USAGE.reserved == 0 and rc.USAGE.lifetime_usd == 0, "a failed call is not billed"
    with pytest.raises(rc.HTTPException):  # unparseable reply: the money WAS spent, so it is counted
        rc.read_photo(Fake(reply(None, raw_text="not json")), JPEG, "image/jpeg")
    assert rc.USAGE.reserved == 0 and rc.USAGE.lifetime_usd == pytest.approx(0.008)
    rc.read_photo(Fake(reply({"lines": []}, tokens=(2000, 0))), JPEG, "image/jpeg")
    assert rc.USAGE.reserved == 0 and rc.USAGE.lifetime_usd == pytest.approx(0.008 + 0.008)


def test_reservation_estimate_is_per_model_and_configurable(capped, monkeypatch):
    assert rc.reserve_estimate("claude-opus-5-5") == 0.06
    assert rc.reserve_estimate("claude-sonnet-5-5") == 0.03 and rc.reserve_estimate("claude-haiku-5-5") == 0.005
    assert rc.reserve_estimate("claude-opus-5-5-20260101") == 0.06 and rc.reserve_estimate("something-new") == 0.06
    monkeypatch.setenv("PARCHI_RESERVE_USD", "0.5")
    assert rc.reserve_estimate("claude-haiku-5-5") == 0.5
    rc.USAGE.lifetime_usd = 4.1
    with pytest.raises(rc.HTTPException) as exc:
        rc.USAGE.reserve("claude-haiku-5-5")           # 4.1 + 0.5 > 4.5
    assert exc.value.status_code == 503 and rc.USAGE.reserved == 0
    for bad in ("abc", "-1", "0", "nan"):
        monkeypatch.setenv("PARCHI_RESERVE_USD", bad)
        assert rc.reserve_estimate("claude-opus-5-5") == 0.06
    monkeypatch.delenv("PARCHI_RESERVE_USD")
    rc.USAGE.lifetime_usd = 4.44                       # exactly fits: 4.44 + 0.06 = 4.50
    assert rc.USAGE.reserve("claude-opus-5-5") == 0.06
    with pytest.raises(rc.HTTPException):
        rc.USAGE.reserve("claude-haiku-5-5")           # even $0.005 more would pass the cap


def test_free_calls_reserve_nothing(capped, monkeypatch):
    monkeypatch.setattr(rc, "CLIENT_OVERRIDE", Fake())
    rc.USAGE.lifetime_usd = 4.5
    assert rc.USAGE.reserve("claude-opus-5-5") == 0.0 and rc.USAGE.reserved == 0


# ------------------------------------------------------------------ K28/13: the ledger fails closed
def _post(monkeypatch):
    fake = Fake(reply({"lines": []}))
    monkeypatch.setattr(rc, "_get_client", lambda: fake)
    return fake, TestClient(rc.app).post("/read", files={"image": ("p.jpg", JPEG, "image/jpeg")})


def test_missing_ledger_at_first_start_is_zero_and_works(capped, monkeypatch):
    usage = rc.Usage()
    assert usage.ledger_ok and usage.lifetime_usd == 0
    fake, r = _post(monkeypatch)
    assert r.status_code == 200 and len(fake.calls) == 1
    assert json.loads((capped / "reader_spend.json").read_text())["usd"] > 0


@pytest.mark.parametrize("content", ["not json", "{}", '{"usd": "abc"}', '{"usd": -1}', '{"usd": NaN}', '{"usd": null}',
                                      '{"usd": true}', "[]", "", '{"usd": Infinity}'])
def test_unreadable_ledger_refuses_real_calls(capped, monkeypatch, caplog, content):
    (capped / "reader_spend.json").write_text(content)
    rc.USAGE = rc.Usage()
    assert rc.USAGE.ledger_ok is False
    with caplog.at_level("WARNING"):
        fake, r = _post(monkeypatch)
    assert r.status_code == 503 and "ledger" in r.json()["detail"] and fake.calls == []
    assert rc.USAGE.reserved == 0
    messages = " ".join(rec.getMessage() for rec in caplog.records)
    assert "refusals=1" in messages and str(capped) not in messages and "reader_spend" not in messages  # count only
    assert TestClient(rc.app).get("/usage").json()["ledgerOk"] is False


def test_ledger_that_cannot_be_opened_refuses(capped, monkeypatch):
    (capped / "reader_spend.json").mkdir()               # a directory where the file should be: OSError on read
    rc.USAGE = rc.Usage()
    fake, r = _post(monkeypatch)
    assert r.status_code == 503 and fake.calls == []


def test_ledger_that_cannot_be_written_refuses_the_next_call(capped, monkeypatch):
    blocker = capped / "blocker"
    blocker.write_text("a file, not a directory")
    monkeypatch.setattr(rc, "SPEND_FILE", blocker / "reader_spend.json")   # mkdir/write under a file -> OSError
    rc.USAGE = rc.Usage()
    fake, r = _post(monkeypatch)
    assert r.status_code == 503 and fake.calls == [], "a ledger that can be neither read nor written refuses the call"
    # a plain missing file in a WRITABLE folder is still a normal first start
    monkeypatch.setattr(rc, "SPEND_FILE", capped / "sub" / "reader_spend.json")
    rc.USAGE = rc.Usage()
    assert rc.USAGE.ledger_ok and rc.USAGE.reserve("claude-opus-5-5") == 0.06


def test_save_failure_after_a_call_closes_the_budget_until_it_can_save(capped, monkeypatch):
    rc.USAGE = rc.Usage()
    assert rc.USAGE.reserve("claude-opus-5-5") == 0.06   # healthy start (file created)
    real_save = rc.Usage._save
    monkeypatch.setattr(rc.Usage, "_save", lambda self: False)
    rc.USAGE.add("claude-opus-5-5", 1000, 100, 0.06)
    assert rc.USAGE.ledger_ok is False and rc.USAGE.lifetime_usd > 0
    with pytest.raises(rc.HTTPException) as exc:
        rc.USAGE.reserve("claude-opus-5-5")
    assert exc.value.status_code == 503
    monkeypatch.setattr(rc.Usage, "_save", real_save)    # the disk works again
    rc.USAGE.release(0)
    assert rc.USAGE.reserve("claude-opus-5-5") == 0.06 and rc.USAGE.ledger_ok


def test_recovered_ledger_never_lowers_what_memory_knows(capped):
    (capped / "reader_spend.json").write_text("garbage")
    usage = rc.Usage()
    usage.lifetime_usd = 3.0
    (capped / "reader_spend.json").write_text('{"usd": 1.0}')
    assert usage.reserve("claude-opus-5-5") == 0.06 and usage.lifetime_usd == 3.0


# ------------------------------------------------------------------ K28/14: only an explicit test upstream is free
@pytest.mark.parametrize("env,expected_real", [
    ({}, True),
    ({"PARCHI_ANTHROPIC_BASE_URL": "https://api.anthropic.com"}, True),                       # the bypass K28 closes
    ({"PARCHI_ANTHROPIC_BASE_URL": "http://127.0.0.1:8199"}, True),                           # a URL alone is not enough
    ({"PARCHI_READER_TEST_UPSTREAM": "1"}, True),                                             # the flag alone is not enough
    ({"PARCHI_READER_TEST_UPSTREAM": "1", "PARCHI_ANTHROPIC_BASE_URL": "https://api.anthropic.com"}, True),
    ({"PARCHI_READER_TEST_UPSTREAM": "1", "PARCHI_ANTHROPIC_BASE_URL": "https://API.Anthropic.com./v1"}, True),
    ({"PARCHI_READER_TEST_UPSTREAM": "1", "PARCHI_ANTHROPIC_BASE_URL": "https://eu.api.anthropic.com"}, True),
    ({"PARCHI_READER_TEST_UPSTREAM": "true", "PARCHI_ANTHROPIC_BASE_URL": "http://127.0.0.1:8199"}, True),  # exactly "1"
    ({"PARCHI_READER_TEST_UPSTREAM": "1", "PARCHI_ANTHROPIC_BASE_URL": "http://127.0.0.1:8199"}, False),
    ({"PARCHI_READER_TEST_UPSTREAM": "1", "PARCHI_ANTHROPIC_BASE_URL": "http://localhost:18199/v1"}, False),
    ({"PARCHI_READER_TEST_UPSTREAM": "1", "PARCHI_ANTHROPIC_BASE_URL": "http://notanthropic.com"}, False),
])
def test_real_spend_exemption_needs_flag_and_non_anthropic_host(capped, monkeypatch, env, expected_real):
    for key, value in env.items():
        monkeypatch.setenv(key, value)
    assert rc.real_spend() is expected_real


def test_real_api_base_url_is_counted_and_capped(capped, monkeypatch):
    monkeypatch.setenv("PARCHI_ANTHROPIC_BASE_URL", "https://api.anthropic.com")
    rc.USAGE.add("claude-opus-5-5", 1_000_000, 0)
    assert rc.USAGE.lifetime_usd == 4.0
    rc.USAGE.lifetime_usd = 4.5
    fake, r = _post(monkeypatch)
    assert r.status_code == 503 and fake.calls == []
