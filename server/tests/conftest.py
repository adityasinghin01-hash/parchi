import copy
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


@pytest.fixture(autouse=True)
def _never_touch_the_real_spend_ledger(tmp_path, monkeypatch):
    """data/reader_spend.json is the user's real Claude budget ledger (Rs 500 limit). No test may read or write it: a test that added
    fake usage to the real file once left $36.60 in it and the real reader would have refused every call as 'cap reached'."""
    try:
        import reader_claude
    except Exception:  # the anthropic package may be missing on a machine that does not run the reader tests
        yield
        return
    monkeypatch.setattr(reader_claude, "SPEND_FILE", tmp_path / "reader_spend.json")
    monkeypatch.setattr(reader_claude.USAGE, "lifetime_usd", 0.0)
    yield


@pytest.fixture(autouse=True)
def _never_touch_the_real_spend_ledger(tmp_path, monkeypatch):
    """data/reader_spend.json is the user's real Claude budget ledger (Rs 500 limit). No test may read or write it: a test that added
    fake usage to the real file once left $36.60 in it and the real reader would have refused every call as 'cap reached'."""
    try:
        import reader_claude
    except Exception:  # the anthropic package may be missing on a machine that does not run the reader tests
        yield
        return
    monkeypatch.setattr(reader_claude, "SPEND_FILE", tmp_path / "reader_spend.json")
    monkeypatch.setattr(reader_claude.USAGE, "lifetime_usd", 0.0)
    yield


@pytest.fixture
def isolated_db(tmp_path, monkeypatch):
    monkeypatch.setenv("PARCHI_DB", str(tmp_path / "parchi.db"))
    import db
    db.init_db()
    return db


def line(item="a", seller="s1", price=100):
    return {"itemID": item, "sellerID": seller, "price": price, "isSubstitute": False}


def plan(lines=None):
    lines = copy.deepcopy(lines if lines is not None else [line()])
    return {
        "lines": lines, "feesBySeller": {},
        "itemsTotal": sum(row["price"] for row in lines), "feesTotal": 0,
        "stops": len({row["sellerID"] for row in lines}), "maxEtaMinutes": 60,
        "medicinesReadyMinutes": 60, "reportsReadyMinutes": 0,
    }


def sellers():
    return [
        {"id": sid, "name": sid, "channel": "localChemist", "etaMinutes": 60,
         "requiresVisit": True}
        for sid in ("s1", "s2", "s3", "s4")
    ]


def proposal(current=None, failed="s1", replacement="s3", extra=25):
    current = current or plan()
    kept = [copy.deepcopy(row) for row in current["lines"] if row["sellerID"] != failed]
    rerouted = [dict(row, sellerID=replacement, price=row["price"] + extra)
                for row in current["lines"] if row["sellerID"] == failed]
    return {
        "failure": "cancelled", "failedSellerID": failed,
        "kept": kept, "rerouted": rerouted, "newPlan": plan(kept + rerouted),
        "extraCost": sum(row["price"] for row in rerouted)
        - sum(row["price"] for row in current["lines"] if row["sellerID"] == failed),
        "stillMissing": [],
    }


@pytest.fixture(autouse=True)
def _fresh_read_rate_limit():
    """G10: the per-install /read window is in memory; every test starts with an empty one."""
    try:
        import api
    except Exception:
        yield
        return
    api._read_times.clear()
    yield
    api._read_times.clear()
