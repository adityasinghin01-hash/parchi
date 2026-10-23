from collections import Counter
from typing import Any

FAILURES = {"cancelled", "outOfStock", "late", "sampleRejected"}
EVENTS = FAILURES | {"confirmed", "shipped", "delivered"}
CHANNELS = {"localChemist", "janAushadhi", "quickCommerce", "onlinePharmacy", "lab"}
INACTIVE = {"failed", "rerouted", "cancelled"}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def integer(value: Any, name: str, minimum: int | None = 0) -> None:
    require(type(value) is int, f"{name} must be an integer")
    require(minimum is None or value >= minimum, f"{name} is below its minimum")


def text(value: Any, name: str) -> None:
    require(isinstance(value, str) and 0 < len(value) <= 256, f"invalid {name}")


def validate_lines(lines: Any, known: set[str]) -> None:
    require(isinstance(lines, list) and len(lines) <= 40, "at most 40 lines allowed")
    seen: set[str] = set()
    for row in lines:
        require(isinstance(row, dict), "invalid plan line")
        text(row.get("itemID"), "itemID")
        text(row.get("sellerID"), "sellerID")
        require(row["itemID"] not in seen, "duplicate itemID")
        seen.add(row["itemID"])
        require(row["sellerID"] in known, "unknown seller")
        integer(row.get("price"), "price")
        require(type(row.get("isSubstitute")) is bool, "isSubstitute must be a boolean")


def validate_plan(plan: Any, known: set[str]) -> None:
    require(isinstance(plan, dict), "invalid plan")
    validate_lines(plan.get("lines"), known)
    fees = plan.get("feesBySeller")
    require(isinstance(fees, dict), "invalid feesBySeller")
    for sid, amount in fees.items():
        require(sid in known, "unknown fee seller")
        integer(amount, "seller fee")
    for name in ("itemsTotal", "feesTotal", "stops", "maxEtaMinutes",
                 "medicinesReadyMinutes", "reportsReadyMinutes"):
        integer(plan.get(name), name)
    require(plan["itemsTotal"] == sum(row["price"] for row in plan["lines"]), "itemsTotal mismatch")
    require(plan["feesTotal"] == sum(fees.values()), "feesTotal mismatch")


def validate_order(body: dict[str, Any]) -> None:
    metadata = body.get("sellers")
    require(isinstance(metadata, list) and 0 < len(metadata) <= 200, "invalid sellers")
    known: set[str] = set()
    for seller in metadata:
        require(isinstance(seller, dict), "invalid seller")
        text(seller.get("id"), "seller id")
        require(seller["id"] not in known, "duplicate seller id")
        known.add(seller["id"])
        text(seller.get("name"), "seller name")
        require(seller.get("channel") in CHANNELS, "invalid channel")
        integer(seller.get("etaMinutes"), "etaMinutes")
        require(type(seller.get("requiresVisit")) is bool, "requiresVisit must be a boolean")
    validate_plan(body.get("plan"), known)
    require(bool(body["plan"]["lines"]), "plan is empty")
    cap = body.get("autoApproveCapPaise")
    if cap is not None:
        integer(cap, "autoApproveCapPaise")


def line_counts(lines: list[dict[str, Any]]) -> Counter:
    return Counter((r["itemID"], r["sellerID"], r["price"], r["isSubstitute"]) for r in lines)


def validate_proposal(proposal: Any, plan: dict[str, Any], sellers: list[dict[str, Any]],
                      pending: dict[str, str] | None, statuses: dict[str, str]) -> None:
    require(isinstance(proposal, dict) and pending is not None, "no pending failure")
    require(proposal.get("failedSellerID") == pending["sellerID"], "wrong failed seller")
    require(proposal.get("failure") == pending["failure"], "wrong failure")
    known = {s["id"] for s in sellers}
    kept, rerouted = proposal.get("kept"), proposal.get("rerouted")
    validate_lines(kept, known)
    validate_lines(rerouted, known)
    expected = [r for r in plan["lines"] if r["sellerID"] != pending["sellerID"]]
    failed_items = {r["itemID"] for r in plan["lines"] if r["sellerID"] == pending["sellerID"]}
    require(line_counts(kept) == line_counts(expected), "kept lines changed")
    missing = proposal.get("stillMissing")
    require(isinstance(missing, list), "invalid stillMissing")
    for item in missing:
        text(item, "missing itemID")
    require(len(set(missing)) == len(missing) and set(missing) <= failed_items, "invalid missing items")
    integer(proposal.get("extraCost"), "extraCost", minimum=None)
    validate_plan(proposal.get("newPlan"), known)
    if not rerouted:
        require(bool(missing), "nothing available must name missing items")
        require(proposal["newPlan"] == plan and proposal["extraCost"] == 0,
                "nothing available must preserve the original plan")
        return
    routed_items = {r["itemID"] for r in rerouted}
    require(routed_items.isdisjoint(missing) and routed_items | set(missing) == failed_items,
            "rerouted and missing items must cover only the failed seller")
    for row in rerouted:
        require(statuses.get(row["sellerID"]) not in INACTIVE, "replacement seller is inactive")
    require(line_counts(proposal["newPlan"]["lines"]) == line_counts(kept + rerouted),
            "newPlan must contain kept and rerouted lines")
    # A phone-supplied low extraCost must not bypass the user's automatic approval cap.
    delta = (proposal["newPlan"]["itemsTotal"] + proposal["newPlan"]["feesTotal"]
             - plan["itemsTotal"] - plan["feesTotal"])
    require(proposal["extraCost"] == delta, "extraCost mismatch")
