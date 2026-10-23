from collections import Counter
from typing import Any

FAILURES = {"cancelled", "outOfStock", "late", "sampleRejected"}
EVENTS = FAILURES | {"confirmed", "shipped", "delivered"}
AREA_KEYS = ("area", "city", "pincode")
CHANNELS = {"localChemist", "janAushadhi", "quickCommerce", "onlinePharmacy", "lab"}
INACTIVE = {"failed", "rerouted", "cancelled"}
UNAVAILABLE_FOR_REROUTE = INACTIVE | {"delivered"}

LINE_FIELDS = ("itemID", "sellerID", "price", "isSubstitute")
PLAN_FIELDS = ("lines", "feesBySeller", "itemsTotal", "feesTotal", "stops", "maxEtaMinutes",
               "medicinesReadyMinutes", "reportsReadyMinutes")
SELLER_FIELDS = ("id", "name", "channel", "etaMinutes", "requiresVisit")
PROPOSAL_FIELDS = ("failure", "failedSellerID", "kept", "rerouted", "newPlan", "extraCost", "stillMissing")


def fields(value: Any, names: tuple[str, ...]) -> dict[str, Any]:
    require(isinstance(value, dict), "expected an object")
    return {key: value[key] for key in names if key in value}


def clean_lines(value: Any) -> list[dict[str, Any]]:
    require(isinstance(value, list) and len(value) <= 40, "at most 40 lines allowed")
    return [fields(row, LINE_FIELDS) for row in value]


def clean_plan(value: Any) -> dict[str, Any]:
    result = fields(value, PLAN_FIELDS)
    if "lines" in result:
        result["lines"] = clean_lines(result["lines"])
    return result


def clean_sellers(value: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [fields(row, SELLER_FIELDS) for row in value]


def clean_proposal(value: Any) -> dict[str, Any]:
    result = fields(value, PROPOSAL_FIELDS)
    for key in ("kept", "rerouted"):
        if key in result:
            result[key] = clean_lines(result[key])
    if "newPlan" in result:
        result["newPlan"] = clean_plan(result["newPlan"])
    return result


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
        require(seller["etaMinutes"] <= 10_080, "etaMinutes above one week")  # also keeps workflow timers sane
        require(type(seller.get("requiresVisit")) is bool, "requiresVisit must be a boolean")
    validate_plan(body.get("plan"), known)
    require(bool(body["plan"]["lines"]), "plan is empty")
    for key in AREA_KEYS:  # optional: where the order is delivered (reliability is kept per area)
        if body.get(key) is not None:
            require(isinstance(body[key], str) and 0 < len(body[key].strip()) and len(body[key]) <= 64, f"invalid {key}")
    cap = body.get("autoApproveCapPaise")
    if cap is not None:
        integer(cap, "autoApproveCapPaise")


def line_counts(lines: list[dict[str, Any]]) -> Counter:
    return Counter((r["itemID"], r["sellerID"], r["price"], r["isSubstitute"]) for r in lines)


def reroute_blockers(proposal: dict[str, Any], statuses: dict[str, str]) -> list[str]:
    """Replacement sellers of a proposal that can no longer take the items (failed, rerouted, cancelled or already delivered).
    Checked when the proposal arrives AND again the moment it is approved (a seller can deliver in between). (Codex R8 row 3)"""
    return sorted({r["sellerID"] for r in proposal.get("rerouted", []) if statuses.get(r["sellerID"]) in UNAVAILABLE_FOR_REROUTE})


def validate_proposal(proposal: Any, plan: dict[str, Any], sellers: list[dict[str, Any]],
                      pending: dict[str, str] | None, statuses: dict[str, str], strict: bool = True) -> None:
    """`strict` carries the R8 rules (complete coverage of failed items, committed fees kept). The workflow passes False only to
    replay histories recorded before those rules existed."""
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
        if strict:  # every item of the failed seller must be accounted for, not just some of them (Codex R8 row 4)
            require(set(missing) == failed_items, "nothing available must name ALL the failed seller's items")
        require(proposal["newPlan"] == plan and proposal["extraCost"] == 0,
                "nothing available must preserve the original plan")
        return
    routed_items = {r["itemID"] for r in rerouted}
    require(routed_items.isdisjoint(missing) and routed_items | set(missing) == failed_items,
            "rerouted and missing items must cover only the failed seller")
    for row in rerouted:
        require(statuses.get(row["sellerID"]) not in UNAVAILABLE_FOR_REROUTE,
                "replacement seller is inactive or already delivered")
    require(line_counts(proposal["newPlan"]["lines"]) == line_counts(kept + rerouted),
            "newPlan must contain kept and rerouted lines")
    if strict:  # a fee already committed to a kept seller cannot be erased to make the extra cost look smaller (Codex R8 row 5)
        new_fees = proposal["newPlan"]["feesBySeller"]
        for sid, fee in plan["feesBySeller"].items():
            if sid != pending["sellerID"]:
                require(new_fees.get(sid, 0) >= fee, "a committed seller fee was removed")
    # A phone-supplied low extraCost must not bypass the user's automatic approval cap.
    delta = (proposal["newPlan"]["itemsTotal"] + proposal["newPlan"]["feesTotal"]
             - plan["itemsTotal"] - plan["feesTotal"])
    require(proposal["extraCost"] == delta, "extraCost mismatch")
