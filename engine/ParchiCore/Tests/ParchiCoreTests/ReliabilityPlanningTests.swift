import Testing
@testable import ParchiCore

private let item = RxItem(id: "telma", kind: .medicine, name: "Telma", strength: "40", quantity: 1)
private let item2 = RxItem(id: "pan", kind: .medicine, name: "Pan", strength: "40", quantity: 1)
private func shop(_ id: String, fee: Paise = 0) -> Seller {
    Seller(id: id, name: id, channel: .onlinePharmacy, deliveryFee: fee, etaMinutes: 60)
}

private func chosen(_ prefs: Preferences, a: Paise, b: Paise, items: [RxItem] = [item]) -> (seller: String, payable: Paise)? {
    let offers = items.flatMap { [Offer(itemID: $0.id, sellerID: "A", price: a), Offer(itemID: $0.id, sellerID: "B", price: b)] }
    let plan = Planner(items: items, sellers: [shop("A"), shop("B")], offers: offers, preferences: prefs).best()
    return plan.map { ($0.sellerIDs.first!, $0.payable) }
}

@Test func weightZeroIsExactlyTheOldBehaviour() throws {
    let plain = Planner(items: [item, item2], sellers: [shop("A", fee: 4_900), shop("B")], offers: [
        Offer(itemID: "telma", sellerID: "A", price: 10_000), Offer(itemID: "telma", sellerID: "B", price: 10_500),
        Offer(itemID: "pan", sellerID: "A", price: 8_000), Offer(itemID: "pan", sellerID: "B", price: 8_100),
    ], preferences: Preferences())
    let withScores = Planner(items: plain.items, sellers: Array(plain.sellers.values), offers: plain.offers,
                             preferences: Preferences(reliability: ["A": 0.1, "B": 0.99], reliabilityWeight: 0))
    #expect(plain.ranked(limit: 5) == withScores.ranked(limit: 5))
}

@Test func slightlyDearerReliableSellerBeatsCheaperUnreliableOne() throws {
    let prefs = Preferences(reliability: ["A": 0.2, "B": 0.95], reliabilityWeight: 1)
    let result = try #require(chosen(prefs, a: 1_000, b: 1_050))
    #expect(result.seller == "B")
    #expect(result.payable == 1_050)  // the SHOWN total is the real price, not the penalised one
}

@Test func aMuchCheaperUnreliableSellerStillWins() throws {
    let prefs = Preferences(reliability: ["A": 0.2, "B": 0.95], reliabilityWeight: 1)
    #expect(try #require(chosen(prefs, a: 500, b: 1_050)).seller == "A")
}

@Test func withoutWeightPriceAloneDecides() throws {
    let prefs = Preferences(reliability: ["A": 0.2, "B": 0.95])
    #expect(try #require(chosen(prefs, a: 1_000, b: 1_050)).seller == "A")
}

@Test func unknownSellerUsesTheNeutralPrior() throws {
    // A unknown (0.8 -> x1.2), B known reliable (0.95 -> x1.05): 1,000 * 1.2 = 1,200 vs 1,100 * 1.05 = 1,155.
    let prefs = Preferences(reliability: ["B": 0.95], reliabilityWeight: 1)
    #expect(try #require(chosen(prefs, a: 1_000, b: 1_100)).seller == "B")
    // and with B at the prior too the cheaper A wins again
    #expect(try #require(chosen(Preferences(reliabilityWeight: 1), a: 1_000, b: 1_100)).seller == "A")
}

@Test func planBUsesTheSameWeights() throws {
    let sellers = [shop("A"), shop("B"), shop("C")]
    let offers = [
        Offer(itemID: "telma", sellerID: "A", price: 900),
        Offer(itemID: "telma", sellerID: "B", price: 1_000),
        Offer(itemID: "telma", sellerID: "C", price: 960),
    ]
    func replanned(_ prefs: Preferences) throws -> String {
        let planner = Planner(items: [item], sellers: sellers, offers: offers, preferences: prefs)
        let approved = Plan(lines: [PlanLine(itemID: "telma", sellerID: "A", price: 900, isSubstitute: false)], feesBySeller: [:], itemsTotal: 900,
                            feesTotal: 0, stops: 0, maxEtaMinutes: 60, medicinesReadyMinutes: 60, reportsReadyMinutes: 0)
        let proposal = PlanB(planner: planner).reroute(approved: approved, failedSellerID: "A", failure: .cancelled)
        return try #require(proposal.rerouted.first).sellerID
    }
    #expect(try replanned(Preferences()) == "C")  // price only: C is cheaper than B
    #expect(try replanned(Preferences(reliability: ["B": 0.97, "C": 0.3], reliabilityWeight: 1)) == "B")
}
