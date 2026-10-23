import ParchiCore
import XCTest
@testable import Parchi

/// The Plan screen's "Ask your doctor: the same salts cost X at Jan Aushadhi instead of Y at MRP" card must describe THIS parchi.
/// Codex review R5 found it showed the demo basket's Rs 189.48 for any parchi. Both numbers now cover only the medicines that
/// have a Jan Aushadhi equivalent, so the two sides compare the same lines.
@MainActor
final class JanAushadhiCardTests: XCTestCase {
    private func reader(_ name: String, _ strength: String?, _ quantity: Int) -> ReaderLine {
        ReaderLine(kind: "medicine", name: name, strength: strength, quantity: quantity, schedule: nil)
    }

    func testDemoCardIsUnchanged() {
        let model = AppModel()
        model.readDemoParchi()
        XCTAssertEqual(model.janAushadhiMedicines, 18_948, "Rs 189.48 for the six demo medicines")
        XCTAssertEqual(model.janAushadhiComparedMRP, 103_040, "Rs 1,030.40 at MRP for the same six")
        XCTAssertEqual(model.janAushadhiComparedMRP, model.medicinesAtMRP, "all six demo medicines have an equivalent")
    }

    func testSingleMedicineParchiCardCountsOnlyThatMedicine() throws {
        let model = AppModel()
        model.loadReaderLines([reader("Dolo", "650", 15)])
        model.confirmList()
        let equivalent = try XCTUnwrap(model.janAushadhiAsks["r1"], "Dolo 650 has a Jan Aushadhi equivalent")
        XCTAssertEqual(model.janAushadhiMedicines, equivalent.totalPaise)
        XCTAssertNotEqual(model.janAushadhiMedicines, 18_948, "never the demo basket's total")
        XCTAssertEqual(model.janAushadhiComparedMRP, 3_427, "Dolo 650 x 15 at the catalogue MRP, Rs 34.27")
        XCTAssertLessThan(model.janAushadhiMedicines, model.janAushadhiComparedMRP)
    }

    func testH1MedicineAloneShowsNoCard() {
        let model = AppModel()
        model.loadReaderLines([reader("Alprax", "0.25", 10)])   // alprazolam: Schedule H1, never suggested
        model.confirmList()
        XCTAssertEqual(model.janAushadhiMedicines, 0)
        XCTAssertEqual(model.janAushadhiComparedMRP, 0)
    }

    func testMixedParchiComparesOnlyTheMedicinesThatHaveAnEquivalent() throws {
        let model = AppModel()
        model.loadReaderLines([reader("Dolo", "650", 15), reader("Alprax", "0.25", 10)])
        model.confirmList()
        let dolo = try XCTUnwrap(model.janAushadhiAsks["r1"])
        XCTAssertNil(model.janAushadhiAsks["r2"], "H1 line has no suggestion")
        XCTAssertEqual(model.janAushadhiMedicines, dolo.totalPaise)
        XCTAssertEqual(model.janAushadhiComparedMRP, try XCTUnwrap(model.catalogueOffers["r1"]).price.totalPaise,
                       "the Alprax MRP is not part of the comparison")
    }
}
