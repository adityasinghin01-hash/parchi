import copy
import unittest

from contract import validate_order, validate_proposal


def sample():
    row = {"itemID": "a", "sellerID": "s1", "price": 100, "isSubstitute": False}
    plan = {"lines": [row], "feesBySeller": {}, "itemsTotal": 100, "feesTotal": 0,
            "stops": 1, "maxEtaMinutes": 60, "medicinesReadyMinutes": 60, "reportsReadyMinutes": 0}
    sellers = [{"id": sid, "name": sid, "channel": "localChemist", "etaMinutes": 60,
                "requiresVisit": True} for sid in ("s1", "s2")]
    return {"plan": plan, "sellers": sellers}


class ContractTests(unittest.TestCase):
    def test_money_cannot_be_coerced(self):
        for value in (True, -1, "100", 1.2):
            body = sample()
            body["plan"]["lines"][0]["price"] = value
            with self.assertRaises(ValueError):
                validate_order(body)

    def test_order_references_and_limit(self):
        body = sample()
        validate_order(body)
        body["plan"]["lines"][0]["sellerID"] = "absent"
        with self.assertRaises(ValueError):
            validate_order(body)
        body = sample()
        body["plan"]["lines"] *= 41
        with self.assertRaises(ValueError):
            validate_order(body)

    def test_swift_nothing_available_keeps_original_plan(self):
        body = sample()
        p = {"failure": "cancelled", "failedSellerID": "s1", "kept": [], "rerouted": [],
             "newPlan": copy.deepcopy(body["plan"]), "extraCost": 0, "stillMissing": ["a"]}
        validate_proposal(p, body["plan"], body["sellers"],
                          {"sellerID": "s1", "failure": "cancelled"}, {"s1": "failed"})

    def test_understated_extra_cost_is_rejected(self):
        body = sample()
        row = dict(body["plan"]["lines"][0], sellerID="s2", price=125)
        new = dict(body["plan"], lines=[row], itemsTotal=125)
        p = {"failure": "cancelled", "failedSellerID": "s1", "kept": [], "rerouted": [row],
             "newPlan": new, "extraCost": 0, "stillMissing": []}
        with self.assertRaises(ValueError):
            validate_proposal(p, body["plan"], body["sellers"],
                              {"sellerID": "s1", "failure": "cancelled"}, {"s1": "failed"})
        p["extraCost"] = 25
        validate_proposal(p, body["plan"], body["sellers"],
                          {"sellerID": "s1", "failure": "cancelled"}, {"s1": "failed"})


if __name__ == "__main__":
    unittest.main()
