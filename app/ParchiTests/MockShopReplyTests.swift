import ParchiCore
import XCTest
@testable import Parchi

/// Mock-mode "Ask nearby shops": the scripted reply quotes the catalogue MRP for a medicine the demo basket has no price for,
/// instead of "Not available". The demo basket's own offers are untouched.
@MainActor
final class MockShopReplyTests: XCTestCase {
    func testScriptedReplyUsesCatalogueMRPForATypedParchi() throws {
        let model = AppModel()
        model.loadReaderLines([ReaderLine(kind: "medicine", name: "Dolo", strength: "650", quantity: 15, schedule: nil)])
        model.confirmList()
        let offers = model.demoShopOffers(for: [ShopCandidate(id: "map-test", name: "Test chemist", distanceM: 300)])
        let quote = try XCTUnwrap(offers.first { $0.sellerID == "map-test" && $0.itemID == "r1" }, "a scripted quote for Dolo 650")
        XCTAssertEqual(quote.price, 3_427, "Dolo 650 x 15 at the catalogue MRP, Rs 34.27")
    }

    func testDemoBasketOffersAreUnchanged() {
        let model = AppModel()
        model.readDemoParchi()
        let offers = model.demoShopOffers(for: model.shopCandidates())
        XCTAssertEqual(offers.count, model.scenario.offers.count, "no catalogue offers exist for the untouched demo parchi")
    }
}
