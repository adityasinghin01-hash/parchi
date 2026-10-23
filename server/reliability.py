"""A1 seller reliability per area.

score = (ok + PRIOR_OK) / (total + PRIOR_TOTAL) = (ok + 4) / (total + 5).
That is a neutral prior of 0.8 (as if every seller had 4 good orders out of 5 already), so one
bad first order drops a seller to 0.667 instead of 0, and a new seller is never ranked as perfect.
"""
from typing import Any, Callable

from fastapi import APIRouter, Body, Depends, FastAPI, HTTPException, Query, Request

import auth
import contract
import v2_db

PRIOR_OK = 4
PRIOR_TOTAL = 5
PRIOR_SCORE = PRIOR_OK / PRIOR_TOTAL
OK_OUTCOMES = {"ok", "delivered"}
FAIL_OUTCOMES = contract.FAILURES | {"fail"}


def normalize_area(area: Any) -> str:
    if not isinstance(area, str) or not area.strip() or len(area) > 64:
        raise ValueError("invalid area")
    return " ".join(area.lower().split())


def compute_score(ok: int, total: int) -> float:
    return (ok + PRIOR_OK) / (total + PRIOR_TOTAL)


def is_ok(outcome: Any) -> bool:
    if outcome in OK_OUTCOMES:
        return True
    if outcome in FAIL_OUTCOMES:
        return False
    raise ValueError("outcome must be ok, delivered, fail or one of " + ", ".join(sorted(contract.FAILURES)))


def record(area: str, seller: str, outcome: str) -> float:
    """Count one order for (area, seller); returns the new score."""
    if not isinstance(seller, str) or not seller or len(seller) > 256:
        raise ValueError("invalid sellerID")
    ok, total = v2_db.bump_reliability(normalize_area(area), seller, is_ok(outcome))
    return compute_score(ok, total)


def score(area: str, seller: str) -> float:
    rows = v2_db.reliability_counts(normalize_area(area), seller)
    return compute_score(rows[0]["ok"], rows[0]["total"]) if rows else PRIOR_SCORE


def scores_for_area(area: str) -> list[dict[str, Any]]:
    rows = [{"sellerID": r["seller_id"], "score": round(compute_score(r["ok"], r["total"]), 4),
             "orders": r["total"]} for r in v2_db.reliability_counts(normalize_area(area))]
    return sorted(rows, key=lambda r: (-r["score"], -r["orders"], r["sellerID"]))


def rank_with_reliability(sellers: list[dict[str, Any]], scores: dict[str, float],
                          weight: float) -> list[dict[str, Any]]:
    """Order candidates cheapest-first after a reliability penalty (used later by the planner).

    sellers: dicts with `sellerID` and `cost` (paise: price + fees). scores: sellerID -> score,
    unknown sellers get the neutral prior. adjustedCost = cost * (1 + weight * (1 - score)).
    weight 0 = pure price. Ties break on higher score, then sellerID. Input is not modified.
    """
    if weight < 0:
        raise ValueError("weight must be >= 0")
    out = []
    for s in sellers:
        rel = scores.get(s["sellerID"], PRIOR_SCORE)
        out.append(dict(s, reliability=rel, adjustedCost=s["cost"] * (1 + weight * (1 - rel))))
    return sorted(out, key=lambda s: (s["adjustedCost"], -s["reliability"], s["sellerID"]))


def register(app: FastAPI, get_temporal: Callable, get_install_id: Callable) -> None:
    router = APIRouter()

    def admin(request: Request) -> None:
        auth.require_admin(request)

    @router.get("/reliability")
    async def get_reliability(area: str = Query(min_length=1, max_length=64),
                              _: str = Depends(get_install_id)) -> list[dict[str, Any]]:
        try:
            return scores_for_area(area)
        except ValueError as error:
            raise HTTPException(422, str(error))

    @router.post("/judge/reliability/record", dependencies=[Depends(admin)])
    async def judge_record(body: dict[str, Any] = Body(...)) -> dict[str, Any]:
        try:
            new = record(body.get("area"), body.get("sellerID"), body.get("outcome"))
        except ValueError as error:
            raise HTTPException(422, str(error))
        return {"ok": True, "score": round(new, 4)}

    app.include_router(router)
