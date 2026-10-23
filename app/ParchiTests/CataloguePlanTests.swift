import ParchiCore
import XCTest
@testable import Parchi

/// App-level checks for K11: a parchi that is NOT the demo basket gets a complete plan from catalogue MRPs, with the
/// "Catalogue MRP · check at the shop" chip and a Jan Aushadhi "ask your doctor" line. Runs inside the app (hosted),
/// so it reads the real bundled brand_mrp.json and janaushadhi_products.json.
@MainActor
final class CataloguePlanTests: XCTestCase {
    private func reader(_ name: String, _ strength: String?, _ quantity: Int) -> ReaderLine {
        ReaderLine(kind: "medicine", name: name, strength: strength, quantity: quantity, schedule: nil)
    }

    private func threeCommonBrands() -> AppModel {
        let model = AppModel()
        model.loadReaderLines([reader("Dolo", "650", 15), reader("Augmentin", "625", 10), reader("Pantop", "40", 15)])
        return model
    }

    func testThreeLineNonDemoParchiGetsACompletePlanAtCatalogueMRP() throws {
        let model = threeCommonBrands()
        XCTAssertTrue(model.allConfirmed, "Dolo 650, Augmentin 625 and Pantop 40 exist in the catalogue")
        model.confirmList()

        let plan = try XCTUnwrap(model.plan, "a complete plan")
        XCTAssertEqual(plan.lines.count, 3)
        XCTAssertEqual(Set(plan.lines.map(\.sellerID)), ["doctorshop"])
        XCTAssertEqual(model.unavailable, [])
        XCTAssertEqual(model.catalogueMisses, [])

        // every line price = packs x catalogue MRP, from brand_mrp.json
        let dolo = try XCTUnwrap(plan.lines.first { $0.itemID == "r1" })
        XCTAssertEqual(dolo.price, 3427, "Dolo 650: 15 tablets = one strip of 15 at Rs 34.27")
        for line in plan.lines {
            let offer = try XCTUnwrap(model.catalogueOffers[line.itemID])
            XCTAssertEqual(line.price, offer.price.totalPaise)
            XCTAssertEqual(line.price, offer.price.perPackPaise * offer.price.packs)
            XCTAssertGreaterThan(line.price, 0)
        }
        XCTAssertEqual(plan.itemsTotal, plan.lines.map(\.price).reduce(0, +))
        XCTAssertEqual(model.medicinesAtMRP, model.planMedicinesTotal, "catalogue prices are MRP: nothing is saved against MRP")

        // the chip says where the price is from
        for line in plan.lines {
            let source = model.priceSource(sellerID: line.sellerID, itemID: line.itemID)
            XCTAssertEqual(source.kind, .mrp)
            XCTAssertEqual(source.datedLabel, "Catalogue MRP · check at the shop")
            XCTAssertNotNil(model.cataloguePackText(itemID: line.itemID))
        }
        XCTAssertEqual(model.priceSource(sellerID: "doctorshop").datedLabel, "Catalogue MRP · check at the shop")
    }

    func testJanAushadhiLineIsAnAskYourDoctorLineNeverApplied() throws {
        let model = threeCommonBrands()
        model.confirmList()
        let before = try XCTUnwrap(model.plan)

        let line = try XCTUnwrap(model.janAushadhiLine(itemID: "r1"), "Paracetamol 650 mg tablets are on the Jan Aushadhi list")
        XCTAssertTrue(line.hasPrefix("Ask your doctor: same salt at Jan Aushadhi ₹"), line)
        XCTAssertTrue(line.hasSuffix("(list of 23 Oct)"), line)
        XCTAssertTrue(line.contains("15.47"), "one 15's pack at the list MRP of Rs 15.47: \(line)")

        // the plan is the same whether or not the line exists: Jan Aushadhi is never a seller in it
        XCTAssertFalse(before.sellerIDs.contains("janaushadhi"))
        model.objective = .fastest
        model.objective = .cheapest
        XCTAssertEqual(model.plan, before)
        XCTAssertNil(model.janAushadhiLine(itemID: "nothing"))
    }

    func testMedicineThatIsNotInTheCatalogueBlocksThePlanAndSaysSo() {
        let model = AppModel()
        model.loadReaderLines([reader("Dolo", "650", 15), reader("Xyzzyqq", "10", 10)])
        model.confirmList()
        XCTAssertNil(model.plan, "never a plan with a made-up price")
        XCTAssertEqual(model.catalogueMisses, ["r2"])
        XCTAssertEqual(model.catalogueOffers.keys.sorted(), ["r1"])
    }

    func testProductOfADifferentStrengthOrKindIsNotPriced() {
        let model = AppModel()
        model.loadReaderLines([reader("Telma", "41", 10), reader("Telma SR", "40", 10), reader("Telma AZ", "40", 10)])
        XCTAssertFalse(model.allConfirmed)          // Telma 41 does not exist: the Confirm screen asks first
        model.choose(strength: "40", for: "r1")
        model.confirmList()
        XCTAssertNotNil(model.catalogueOffers["r1"])
        XCTAssertNotNil(model.catalogueOffers["r3"], "Telma AZ 40 is its own product")
        XCTAssertNotEqual(model.catalogueOffers["r1"]?.price.totalPaise, model.catalogueOffers["r3"]?.price.totalPaise)
        XCTAssertNil(model.catalogueOffers["r2"], "the parchi says SR and Telma has no SR: no price rather than another product's")
        XCTAssertEqual(model.catalogueMisses, ["r2"])
    }

    func testHighQuantityNeedsMorePacksAndUnknownPackSizeIsSaid() throws {
        let model = AppModel()
        model.loadReaderLines([reader("Dolo", "650", 31)])      // strips of 15: 3 strips
        model.confirmList()
        let offer = try XCTUnwrap(model.catalogueOffers["r1"])
        XCTAssertEqual(offer.price.packs, 3)
        XCTAssertEqual(model.plan?.itemsTotal, 3 * 3427)
        XCTAssertTrue(model.cataloguePackText(itemID: "r1")?.hasPrefix("3 × strip of 15 tablets") == true)
    }

    func testTestsKeepUsingLabPricesFromAppData() throws {
        let model = AppModel()
        model.loadReaderLines([reader("Dolo", "650", 15), ReaderLine(kind: "test", name: "CBC", strength: nil, quantity: nil, schedule: nil)])
        model.confirmList()
        XCTAssertEqual(model.catalogueOffers.keys.sorted(), ["r1"], "a test line never gets a catalogue price")
        XCTAssertNotNil(model.plan, "the medicines get a plan; a test the demo scenario has no lab offers for is priced lab by lab below it")
        XCTAssertEqual(model.unavailable, [])
        XCTAssertEqual(model.testsOutsidePlan.map(\.id), ["r2"], "the plan screen says the test is not in the total")
        // lab prices still come from AppData, per city; a city without a price stays empty ("Price not found yet")
        XCTAssertFalse(model.data.labPrices(city: "Meerut", test: "CBC").isEmpty)
        XCTAssertTrue(model.data.labPrices(city: "Meerut", test: "No such test").isEmpty)
    }

    func testH1XMedicineGetsNoJanAushadhiLine() throws {
        let model = AppModel()
        model.loadReaderLines([reader("Alprax", "0.25", 10)])       // alprazolam: schedule H1 in brand_schedule.json
        XCTAssertNotNil(model.lines.first?.inPersonOnly)
        XCTAssertNotNil(model.data.janAushadhiEquivalent(brand: "Alprax", strength: "0.25", quantity: 10),
                        "the list does have alprazolam 0.25 mg: the line is left out because of the H1 rule, not for lack of data")
        model.confirmList()
        XCTAssertNil(model.janAushadhiLine(itemID: "r1"))
        XCTAssertNotNil(model.inPersonMessage(itemID: "r1"))
        XCTAssertNotNil(model.plan, "still priced at the catalogue MRP at a shop you walk into")
    }

    /// The demo basket is exactly as before: same total, no catalogue offers, prices from the scenario.
    func testDemoBasketIsUnchanged() throws {
        let model = AppModel()
        model.readDemoParchi()
        model.choose(strength: "40", for: "telma")
        model.confirmList()
        let plan = try XCTUnwrap(model.plan)
        XCTAssertEqual(plan.payable, 269_677, "Rs 2,696.77")
        XCTAssertTrue(model.catalogueOffers.isEmpty)
        XCTAssertTrue(model.catalogueMisses.isEmpty)
        for line in plan.lines {
            XCTAssertNotEqual(model.priceSource(sellerID: line.sellerID, itemID: line.itemID).datedLabel, "Catalogue MRP · check at the shop")
        }
        XCTAssertGreaterThan(model.janAushadhiMedicines, 0, "the old aggregated 'ask your doctor' line is still there")
    }
}
