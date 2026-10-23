import copy
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


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
