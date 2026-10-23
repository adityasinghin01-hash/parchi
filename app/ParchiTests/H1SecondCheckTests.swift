import ParchiCore
import XCTest
@testable import Parchi

/// H1/X safety: the brand table is the first check, the salts of the exact catalogue product the parchi matches are the second.
/// Codex review R5: "Aaram 0.5" (alprazolam) got a Jan Aushadhi suggestion with no H1 warning. A brand line that is mostly ordinary
/// (Calpol: 1 of 8 products has tramadol) must NOT be flagged as a whole.
@MainActor
final class H1SecondCheckTests: XCTestCase {
    private func reader(_ name: String, _ strength: String?, _ quantity: Int) -> ReaderLine {
        ReaderLine(kind: "medicine", name: name, strength: strength, quantity: quantity, schedule: nil)
    }

    func testAaramIsInPersonOnlyAndHasNoJanAushadhiLine() {
        let model = AppModel()
        model.loadReaderLines([reader("Aaram", "0.5", 10)])
        XCTAssertNotNil(model.lines.first?.inPersonOnly, "brand table lists AARAM (alprazolam)")
        model.confirmList()
        XCTAssertNil(model.janAushadhiLine(itemID: "r1"))
        XCTAssertNotNil(model.inPersonMessage(itemID: "r1"))
        XCTAssertEqual(model.janAushadhiMedicines, 0)
    }

    func testMixedBrandIsCaughtByTheSaltsOfTheMatchedProduct() {
        let model = AppModel()
        model.loadReaderLines([reader("Asic", "50", 10)])   // Asic 50mg tablet = tramadol; the brand has mostly other products
        XCTAssertNil(model.data.scheduleCheck.isInPersonOnly(brand: "Asic"), "the brand table does not list this mixed brand")
        XCTAssertNil(model.lines.first?.inPersonOnly)
        model.confirmList()
        XCTAssertNotNil(model.lines.first?.inPersonOnly, "second check: the matched product contains a Schedule H1 salt")
        XCTAssertNil(model.janAushadhiLine(itemID: "r1"), "no Jan Aushadhi suggestion for an H1 medicine")
    }

    func testOrdinaryBrandWithOneScheduledSiblingIsNotFlagged() throws {
        let model = AppModel()
        model.loadReaderLines([reader("Calpol", "500", 15)])
        XCTAssertNil(model.lines.first?.inPersonOnly, "Calpol 500 is paracetamol; only 'Calpol T' has tramadol")
        model.confirmList()
        XCTAssertNil(model.lines.first?.inPersonOnly)
        let offer = try XCTUnwrap(model.catalogueOffers["r1"], "Calpol 500 is priced from the catalogue")
        XCTAssertEqual(offer.price.totalPaise, 1_665, "one strip of 15 at Rs 16.65")
    }
}
