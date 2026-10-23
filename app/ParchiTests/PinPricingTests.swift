import ParchiCore
import XCTest
@testable import Parchi

/// K14: the price rules behind the Plan Map pins, list rows and shop sheet. A shop without a price says "Ask" and shows no number.
@MainActor
final class PinPricingTests: XCTestCase {
    private let ids = ["a", "b", "c", "d"]
    private let seen = PriceSource.date(fromISO: "2026-10-23") ?? Date()
    private var mrpChip: PriceSource { PriceSource.catalogueMRP(dateSeen: seen) }

    // MARK: Local chemist = the basket at MRP

    func testChemistWholeBasketIsTheSumAndNeedsNoCoverageText() {
        let price = PinPricing.chemist(medicineIDs: ids, mrp: ["a": 1000, "b": 2000, "c": 3000, "d": 4050], source: mrpChip)
        XCTAssertEqual(price.paise, 10050)
        XCTAssertEqual(price.text, rupees(10050))
        XCTAssertNil(price.coverageText)
        XCTAssertFalse(price.isAsk)
        XCTAssertEqual(price.source?.datedLabel, "Catalogue MRP · check at the shop")
    }

    func testChemistMissingLinesSayHowManyAreCovered() {
        let price = PinPricing.chemist(medicineIDs: ids, mrp: ["a": 1000, "c": 3000], source: mrpChip)
        XCTAssertEqual(price.paise, 4000)
        XCTAssertEqual(price.coverageText, "for 2 of 4")
        XCTAssertEqual(price.fullText, "\(rupees(4000)) for 2 of 4")
    }

    func testNoMRPAtAllIsAskWithNoNumber() {
        let price = PinPricing.chemist(medicineIDs: ids, mrp: [:], source: mrpChip)
        XCTAssertTrue(price.isAsk)
        XCTAssertNil(price.paise)
        XCTAssertEqual(price.text, "Ask")
        XCTAssertNil(price.coverageText)
        XCTAssertNil(price.source, "no number means no source chip")
        XCTAssertEqual(price.spoken, "No price yet, ask the shop")
        XCTAssertFalse(price.fullText.contains("₹"))
    }

    func testPricesForItemsOutsideTheBasketAreIgnored() {
        let price = PinPricing.chemist(medicineIDs: ["a"], mrp: ["a": 500, "zzz": 99_999], source: mrpChip)
        XCTAssertEqual(price.paise, 500)
    }

    func testDuplicateMedicineIDsCountOnce() {
        let price = PinPricing.chemist(medicineIDs: ["a", "a", "b"], mrp: ["a": 500, "b": 100], source: mrpChip)
        XCTAssertEqual(price.paise, 600)
        XCTAssertEqual(price.total, 2)
    }

    // MARK: Jan Aushadhi = list price of the lines with an equivalent, "Rs N for X of Y"

    func testJanAushadhiAlwaysSaysXofY() {
        let source = PriceSource(kind: .mrp, dateSeen: seen, note: "Jan Aushadhi list")
        let some = PinPricing.janAushadhi(medicineIDs: ids, totals: ["a": 1547, "c": 3714], source: source)
        XCTAssertEqual(some.paise, 5261)
        XCTAssertEqual(some.fullText, "\(rupees(5261)) for 2 of 4")
        let all = PinPricing.janAushadhi(medicineIDs: ids, totals: ["a": 1, "b": 2, "c": 3, "d": 4], source: source)
        XCTAssertEqual(all.fullText, "\(rupees(10)) for 4 of 4", "Jan Aushadhi says X of Y even when X == Y")
        let none = PinPricing.janAushadhi(medicineIDs: ids, totals: [:], source: source)
        XCTAssertTrue(none.isAsk)
        XCTAssertEqual(none.text, "Ask")
    }

    // MARK: A shop that replied

    func testReplyCountsOnlyAvailablePricedItems() {
        let items = [ShopStatusItem(itemID: "a", available: true, pricePaise: 900),
                     ShopStatusItem(itemID: "b", available: false, pricePaise: 5000),
                     ShopStatusItem(itemID: "c", available: true, pricePaise: nil),
                     ShopStatusItem(itemID: "d", available: true, pricePaise: 0)]
        let price = PinPricing.reply(medicineIDs: ids, items: items, repliedAt: seen, isDemo: false)
        XCTAssertEqual(price.paise, 900)
        XCTAssertEqual(price.coverageText, "for 1 of 4")
        XCTAssertTrue(price.source?.label.hasPrefix("Shop replied") ?? false)
        XCTAssertEqual(price.source?.kind, .shopReply)
    }

    func testReplyWithNothingPricedIsAskNeverZero() {
        let items = [ShopStatusItem(itemID: "a", available: false, pricePaise: nil)]
        let price = PinPricing.reply(medicineIDs: ids, items: items, repliedAt: seen, isDemo: true)
        XCTAssertTrue(price.isAsk)
        XCTAssertNotEqual(price.text, rupees(0))
    }

    func testDemoReplyIsLabelledScriptedButStillSaysShopReplied() {
        let price = PinPricing.reply(medicineIDs: ids, items: [ShopStatusItem(itemID: "a", available: true, pricePaise: 100)], repliedAt: seen, isDemo: true)
        let chip = price.source?.datedLabel ?? ""
        XCTAssertTrue(chip.contains("Shop replied"))
        XCTAssertTrue(chip.contains("demo"))
    }

    // MARK: Delivery sellers

    func testSellerUsesOnlyItsOwnInStockNonSubstituteOffers() {
        let offers = [Offer(itemID: "a", sellerID: "s", price: 100),
                      Offer(itemID: "b", sellerID: "s", price: 200, inStock: false),
                      Offer(itemID: "c", sellerID: "s", price: 300, isSubstitute: true),
                      Offer(itemID: "d", sellerID: "other", price: 400)]
        let price = PinPricing.seller(medicineIDs: ids, offers: offers, sellerID: "s",
                                      source: PriceSource(kind: .online, dateSeen: seen))
        XCTAssertEqual(price.paise, 100)
        XCTAssertEqual(price.coverageText, "for 1 of 4")
        XCTAssertTrue(PinPricing.seller(medicineIDs: ids, offers: offers, sellerID: "nobody", source: mrpChip).isAsk)
    }

    // MARK: Order = cheapest first, then nearest; Ask last

    func testOrderCheapestThenNearestAskLast() {
        func p(_ paise: Int?) -> PinPrice {
            paise.map { PinPrice(paise: $0, covered: 1, total: 1, source: nil) } ?? .ask(total: 1)
        }
        struct Shop { let name: String; let price: PinPrice; let distance: Int? }
        let shops = [Shop(name: "Ask near", price: p(nil), distance: 100),
                     Shop(name: "Dear near", price: p(500), distance: 100),
                     Shop(name: "Cheap far", price: p(300), distance: 5000),
                     Shop(name: "Cheap near", price: p(300), distance: 200),
                     Shop(name: "Cheap unknown", price: p(300), distance: nil),
                     Shop(name: "Ask far", price: p(nil), distance: 900)]
        let sorted = shops.sorted { PinPricing.areInOrder($0.price, $0.distance, $0.name, $1.price, $1.distance, $1.name) }
        XCTAssertEqual(sorted.map(\.name), ["Cheap near", "Cheap far", "Cheap unknown", "Dear near", "Ask near", "Ask far"])
    }

    // MARK: Hosted: the real demo basket (Mock demo total must not move)

    func testDemoBasketChemistPriceEqualsMedicinesAtMRPAndPlanTotalIsUnchanged() throws {
        let model = AppModel()
        model.readDemoParchi()
        model.choose(strength: "40", for: "telma")
        model.confirmList()
        let plan = try XCTUnwrap(model.plan)
        XCTAssertEqual(rupees(plan.payable), "₹2,696.77", "the Mock demo total must not change")

        let pricer = ShopPricer(app: model)
        let doctorShop = try XCTUnwrap(pricer.planShops().first { $0.planSellerID == "doctorshop" })
        let quote = pricer.quote(for: doctorShop)
        XCTAssertEqual(quote.price.paise, model.medicinesAtMRP)
        XCTAssertEqual(quote.price.paise, 103_040)
        XCTAssertNil(quote.price.coverageText)
        XCTAssertEqual(quote.price.source?.datedLabel, PriceSource.catalogueMRPNote)
        XCTAssertEqual(quote.items.count, 6)
        XCTAssertTrue(quote.items.allSatisfy { $0.paise != nil })
        XCTAssertEqual(quote.items.compactMap(\.paise).reduce(0, +), 103_040)

        // A MapKit chemist (not in the plan data) gets the same basket price.
        let mapChemist = MapShop(id: "map-x", name: "X", distanceM: 300, latitude: 28.75, longitude: 77.5, kind: .chemist)
        XCTAssertEqual(pricer.quote(for: mapChemist).price, quote.price)

        // Jan Aushadhi: X of Y with Y = the 6 medicines, X = lines with an equivalent, nothing invented.
        let kendra = MapShop(id: "map-j", name: "Jan Aushadhi Kendra", distanceM: 900, latitude: 28.76, longitude: 77.5, kind: .janAushadhi)
        let jan = pricer.quote(for: kendra).price
        XCTAssertEqual(jan.total, 6)
        XCTAssertEqual(jan.covered, model.janAushadhiAsks.count)
        XCTAssertEqual(jan.paise, model.janAushadhiAsks.values.map(\.totalPaise).reduce(0, +).nonZero)
        XCTAssertEqual(jan.coverageText, jan.isAsk ? nil : "for \(jan.covered) of 6")
        XCTAssertEqual(plan.payable, model.plan?.payable, "pricing is read-only")
    }

    func testDeliveryStripListsOnlineSellersWithPlanPriceOrOwnOffers() throws {
        let model = AppModel()
        model.readDemoParchi()
        model.choose(strength: "40", for: "telma")
        model.confirmList()
        let plan = try XCTUnwrap(model.plan)
        let strip = ShopPricer(app: model).deliverySellers()
        XCTAssertEqual(Set(strip.map(\.id)), ["truemeds", "medkart", "pharmeasy", "onemg"])
        for seller in strip where seller.inPlan {
            let planSum = plan.lines.filter { $0.sellerID == seller.id }.map(\.price).reduce(0, +)
            XCTAssertEqual(seller.price.paise, planSum, "\(seller.id): in-plan price = the plan's own lines")
        }
        XCTAssertEqual(strip.first { $0.id == "pharmeasy" }?.price.coverageText, "for 3 of 6", "own offers only; the missing lines are not guessed")
    }
}

private extension Int {
    /// 0 means "no price" in the comparison above.
    var nonZero: Int? { self == 0 ? nil : self }
}
