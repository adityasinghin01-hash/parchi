import pytest
from fastapi import FastAPI, Header
from fastapi.testclient import TestClient

import auth
import reliability


def install_dep(x_test_install: str = Header(default="")) -> str:  # overridden below
    raise AssertionError("must be overridden")


@pytest.fixture
def client(isolated_db, monkeypatch):
    monkeypatch.setenv("PARCHI_ADMIN_KEY", "judge-secret")
    auth.limiter.clear()
    app = FastAPI()
    reliability.register(app, lambda: None, install_dep)
    app.dependency_overrides[install_dep] = lambda x_test_install=Header(default="phone"): x_test_install
    yield TestClient(app)
    auth.limiter.clear()


ADMIN = {"X-Admin-Key": "judge-secret"}


def record(client, area, seller, outcome, headers=ADMIN):
    return client.post("/judge/reliability/record", headers=headers,
                       json={"area": area, "sellerID": seller, "outcome": outcome})


def test_compute_score_prior_and_values():
    assert reliability.compute_score(0, 0) == pytest.approx(0.8)
    assert reliability.compute_score(1, 1) == pytest.approx(5 / 6)
    assert reliability.compute_score(0, 1) == pytest.approx(4 / 6)
    assert reliability.compute_score(10, 20) == pytest.approx(14 / 25)


def test_record_and_score(isolated_db):
    assert reliability.score("560001", "s1") == pytest.approx(0.8)
    reliability.record("560001", "s1", "ok")
    reliability.record("560001", "s1", "delivered")
    reliability.record("560001", "s1", "cancelled")
    assert reliability.score("560001", "s1") == pytest.approx(6 / 8)
    assert reliability.score("560001", "other") == pytest.approx(0.8)
    assert reliability.score("560002", "s1") == pytest.approx(0.8)  # per area


def test_area_is_normalised(isolated_db):
    reliability.record("  Bengaluru ", "s1", "fail")
    assert reliability.score("bengaluru", "s1") == pytest.approx(4 / 6)


@pytest.mark.parametrize("area,seller,outcome", [
    ("", "s1", "ok"), (None, "s1", "ok"), ("560001", "", "ok"), ("560001", "s1", "banana")])
def test_record_rejects_bad_input(isolated_db, area, seller, outcome):
    with pytest.raises(ValueError):
        reliability.record(area, seller, outcome)


def test_api_sorted_best_first(client):
    for _ in range(3):
        assert record(client, "560001", "good", "ok").status_code == 200
    record(client, "560001", "bad", "late")
    record(client, "560001", "mid", "ok")
    record(client, "560002", "elsewhere", "ok")
    rows = client.get("/reliability", params={"area": "560001"}).json()
    assert [r["sellerID"] for r in rows] == ["good", "mid", "bad"]
    assert rows[0] == {"sellerID": "good", "score": round(7 / 8, 4), "orders": 3}
    assert rows[2]["orders"] == 1
    assert client.get("/reliability", params={"area": "nowhere"}).json() == []


def test_api_record_needs_admin_and_valid_body(client):
    assert record(client, "560001", "s1", "ok", headers={}).status_code == 401
    assert record(client, "560001", "s1", "ok", headers={"X-Admin-Key": "nope"}).status_code == 401
    assert record(client, "560001", "s1", "banana").status_code == 422
    assert client.get("/reliability", params={"area": "560001"}).json() == []
    assert record(client, "560001", "s1", "outOfStock").json() == {"ok": True, "score": round(4 / 6, 4)}


def test_api_requires_area(client):
    assert client.get("/reliability").status_code == 422


def test_rank_with_reliability():
    sellers = [{"sellerID": "cheap_flaky", "cost": 1000}, {"sellerID": "dear_solid", "cost": 1100},
               {"sellerID": "new", "cost": 1050}]
    scores = {"cheap_flaky": 0.4, "dear_solid": 0.95}
    assert [s["sellerID"] for s in reliability.rank_with_reliability(sellers, scores, 0)] == \
        ["cheap_flaky", "new", "dear_solid"]
    ranked = reliability.rank_with_reliability(sellers, scores, 1)
    # adjusted: 1600, 1155, 1260 (unknown seller = 0.8 prior)
    assert [s["sellerID"] for s in ranked] == ["dear_solid", "new", "cheap_flaky"]
    assert ranked[0]["adjustedCost"] == pytest.approx(1100 * 1.05)
    assert ranked[1]["reliability"] == reliability.PRIOR_SCORE
    assert "adjustedCost" not in sellers[0]  # input untouched
    with pytest.raises(ValueError):
        reliability.rank_with_reliability(sellers, scores, -1)
