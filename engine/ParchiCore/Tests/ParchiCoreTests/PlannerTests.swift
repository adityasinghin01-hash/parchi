import Testing
@testable import ParchiCore

private let dolo = RxItem(id: "dolo", kind: .medicine, name: "Dolo", strength: "650", quantity: 1)
private let pan = RxItem(id: "pan", kind: .medicine, name: "Pan", strength: "40", quantity: 1)
private let cbc = RxItem(id: "cbc", kind: .test, name: "CBC")

private let shop = Seller(id: "shop", name: "Tyagi Medicos", channel: .localChemist, etaMinutes: 15, requiresVisit: true, distanceMeters: 900)
private let online = Seller(id: "online", name: "Online pharmacy", channel: .onlinePharmacy, deliveryFee: 4_900,
                            freeDeliveryAbove: 30_000, etaMinutes: 1_440)
private let quick = Seller(id: "quick", name: "10-minute app", channel: .quickCommerce, deliveryFee: 3_000,
                           freeDeliveryAbove: 19_900, handlingFee: 900, etaMinutes: 12)
private let lab = Seller(id: "lab", name: "Lab A", channel: .lab, collectionFee: 10_000, etaMinutes: 240)
private let labB = Seller(id: "labB", name: "Lab B", channel: .lab, etaMinutes: 300, requiresVisit: true)

@Test func incompleteSellerCannotWinAlone() throws {
    // The online pharmacy is cheapest for Dolo but has no CBC; a plan must still cover CBC.
    let planner = Planner(items: [dolo, cbc], sellers: [online, lab], offers: [
        Offer(itemID: "dolo", sellerID: "online", price: 2_000),
        Offer(itemID: "cbc", sellerID: "lab", price: 30_000),
    ], preferences: Preferences())
    let plan = try #require(planner.best())
    #expect(Set(plan.lines.map(\.itemID)) == ["dolo", "cbc"])
}

@Test func missingItemMeansNoCompletePlan() {
    let planner = Planner(items: [dolo, cbc], sellers: [online], offers: [
        Offer(itemID: "dolo", sellerID: "online", price: 2_000),
    ], preferences: Preferences())
    #expect(planner.best() == nil)
    #expect(planner.unavailableItems() == ["cbc"])
}

@Test func feesDecideTheWinnerNotSticker() throws {
    // Online item is ₹3 cheaper but ₹49 delivery applies below ₹300, so the shop wins on payable.
    let planner = Planner(items: [dolo], sellers: [shop, online], offers: [
        Offer(itemID: "dolo", sellerID: "shop", price: 3_400),
        Offer(itemID: "dolo", sellerID: "online", price: 3_100),
    ], preferences: Preferences(visitCost: 0))
    let plan = try #require(planner.best())
    #expect(plan.lines.first?.sellerID == "shop")
    #expect(plan.payable == 3_400)
}

@Test func consolidatingToReachFreeDeliveryIsFound() throws {
    // Splitting looks cheaper per item, but buying both online crosses ₹300 and kills the ₹49 fee.
    let planner = Planner(items: [dolo, pan], sellers: [quick, online], offers: [
        Offer(itemID: "dolo", sellerID: "online", price: 16_000),
        Offer(itemID: "pan", sellerID: "online", price: 15_000),
        Offer(itemID: "dolo", sellerID: "quick", price: 15_500),
        Offer(itemID: "pan", sellerID: "quick", price: 15_800),
    ], preferences: Preferences())
    let plan = try #require(planner.best())
    #expect(plan.sellerIDs.count == 1)
    #expect(plan.feesTotal == 0 || plan.sellerIDs == ["quick"])
}

@Test func substituteNeedsDoctorApproval() throws {
    let offers = [
        Offer(itemID: "pan", sellerID: "shop", price: 15_000),
        Offer(itemID: "pan", sellerID: "online", price: 4_000, exactMatch: false, isSubstitute: true),
    ]
    let strict = Planner(items: [pan], sellers: [shop, online], offers: offers, preferences: Preferences(visitCost: 0))
    #expect(try #require(strict.best()).lines.first?.isSubstitute == false)

    let approved = Planner(items: [pan], sellers: [shop, online], offers: offers,
                           preferences: Preferences(doctorApprovedSubstitutes: true, visitCost: 0))
    #expect(try #require(approved.best()).lines.first?.isSubstitute == true)
}

@Test func outOfStockIsIgnored() throws {
    let planner = Planner(items: [dolo], sellers: [shop, quick], offers: [
        Offer(itemID: "dolo", sellerID: "quick", price: 1_000, inStock: false),
        Offer(itemID: "dolo", sellerID: "shop", price: 3_400),
    ], preferences: Preferences())
    #expect(try #require(planner.best()).lines.first?.sellerID == "shop")
}

@Test func fastestObjectivePicksTenMinuteApp() throws {
    let planner = Planner(items: [dolo], sellers: [online, quick], offers: [
        Offer(itemID: "dolo", sellerID: "online", price: 2_000),
        Offer(itemID: "dolo", sellerID: "quick", price: 3_400),
    ], preferences: Preferences(objective: .fastest))
    #expect(try #require(planner.best()).lines.first?.sellerID == "quick")
}

@Test func tripCostStopsSillySplits() throws {
    // Lab B saves ₹100 vs home collection but costs a trip worth ₹150 to this patient.
    let planner = Planner(items: [cbc], sellers: [lab, labB], offers: [
        Offer(itemID: "cbc", sellerID: "lab", price: 30_000),
        Offer(itemID: "cbc", sellerID: "labB", price: 30_000),
    ], preferences: Preferences(visitCost: 15_000))
    #expect(try #require(planner.best()).lines.first?.sellerID == "lab")
}

@Test func planBReroutesOnlyTheFailedItems() throws {
    let planner = Planner(items: [dolo, pan, cbc], sellers: [shop, quick, online, lab], offers: [
        Offer(itemID: "dolo", sellerID: "quick", price: 3_000),
        Offer(itemID: "pan", sellerID: "quick", price: 17_000),
        Offer(itemID: "dolo", sellerID: "online", price: 2_800),
        Offer(itemID: "pan", sellerID: "online", price: 16_000),
        Offer(itemID: "dolo", sellerID: "shop", price: 3_400),
        Offer(itemID: "pan", sellerID: "shop", price: 18_000),
        Offer(itemID: "cbc", sellerID: "lab", price: 30_000),
    ], preferences: Preferences(objective: .fastest))
    let approved = try #require(planner.best())
    #expect(approved.lines.first { $0.itemID == "dolo" }?.sellerID == "quick")

    let proposal = PlanB(planner: planner).reroute(approved: approved, failedSellerID: "quick", failure: .cancelled)
    #expect(proposal.stillMissing.isEmpty)
    #expect(proposal.kept.map(\.itemID) == ["cbc"])
    #expect(Set(proposal.rerouted.map(\.itemID)) == ["dolo", "pan"])
    #expect(!proposal.rerouted.contains { $0.sellerID == "quick" })
}

@Test func planBSaysPlainlyWhenNothingElseHasIt() throws {
    let planner = Planner(items: [cbc], sellers: [lab], offers: [Offer(itemID: "cbc", sellerID: "lab", price: 30_000)],
                          preferences: Preferences())
    let approved = try #require(planner.best())
    let proposal = PlanB(planner: planner).reroute(approved: approved, failedSellerID: "lab", failure: .sampleRejected)
    #expect(proposal.stillMissing == ["cbc"])
    #expect(proposal.rerouted.isEmpty)
}

@Test func fastestJudgesMedicinesSeparatelyFromLabReports() throws {
    // A slow lab report must not stop the planner from choosing the 10-minute app for medicines.
    let planner = Planner(items: [dolo, cbc], sellers: [online, quick, lab], offers: [
        Offer(itemID: "dolo", sellerID: "online", price: 2_000),
        Offer(itemID: "dolo", sellerID: "quick", price: 3_400),
        Offer(itemID: "cbc", sellerID: "lab", price: 30_000),
    ], preferences: Preferences(objective: .fastest))
    let plan = try #require(planner.best())
    #expect(plan.lines.first { $0.itemID == "dolo" }?.sellerID == "quick")
    #expect(plan.medicinesReadyMinutes == 12)
    #expect(plan.reportsReadyMinutes == 240)
}
