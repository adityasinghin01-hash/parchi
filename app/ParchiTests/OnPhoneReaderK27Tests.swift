import CoreGraphics
import ParchiCore
import XCTest
@testable import Parchi

/// K27 (Codex review R7, rows 18-21): the on-phone reader's four bugs, each with the exact failing input of the review.
@MainActor
final class OnPhoneReaderK27Tests: XCTestCase {
    private func box(_ text: String, x: CGFloat, y: CGFloat, w: CGFloat = 0.2, h: CGFloat = 0.02) -> OCRBox {
        OCRBox(text: text, rect: CGRect(x: x, y: y, width: w, height: h), confidence: 0.9)
    }

    private var reader: OnPhoneReader {
        let catalogue = Catalogue(productNames: ["Pan 40 Tablet", "Pan 20 Tablet", "Dolo 650 Tablet", "Dolo 500 Tablet", "Dolo 1000 Injection",
                                                 "Telma 40 Tablet", "Telma 80 Tablet", "Montair LC Tablet", "Omez 20 Capsule", "Ascoril LS Syrup", "Soframycin 1 Ointment"])
        return OnPhoneReader(parser: PrintedParser(catalogue: catalogue), tests: nil)
    }

    // MARK: 18 - needsHelp is kept in the model and cleared with the parchi

    func testNeedsHelpLinesAreKeptInTheModelAndClearedWithTheParchi() {
        let result = reader.interpret(rows: ["Tab Pan 40 OD", "Tab Telia 40 OD", "Tab Dolo 650 TDS"])
        XCTAssertEqual(result.needsHelp, ["Tab Telia 40 OD"])

        let model = AppModel()
        model.loadReaderLines(result.lines)
        model.readerNeedsHelp = result.needsHelp               // what the capture step does right after loadReaderLines
        XCTAssertEqual(model.readerNeedsHelp, ["Tab Telia 40 OD"])
        XCTAssertEqual(model.lines.count, 2, "only the recognised lines are on the list")

        model.loadReaderLines(result.lines)                    // a new reading replaces it
        XCTAssertEqual(model.readerNeedsHelp, [])

        model.readerNeedsHelp = ["Tab Telia 40 OD"]
        model.eraseAll()                                       // Delete everything
        XCTAssertEqual(model.readerNeedsHelp, [])

        model.readerNeedsHelp = ["Tab Telia 40 OD"]
        model.readDemoParchi()                                 // a new photo that falls back to the demo parchi
        XCTAssertEqual(model.readerNeedsHelp, [])
    }

    func testManualEditsPreserveUnrecognisedReaderRows() {
        let model = AppModel()
        model.loadReaderLines([ReaderLine(kind: "medicine", name: "Dolo", strength: "650", quantity: 2, schedule: nil)])
        model.readerNeedsHelp = ["Tab Telia 40 OD"]
        model.addManualMedicine(name: "Pan", strength: "40", quantity: 1)
        XCTAssertEqual(model.readerNeedsHelp, ["Tab Telia 40 OD"])
        model.addManualTest(name: "CBC")
        XCTAssertEqual(model.readerNeedsHelp, ["Tab Telia 40 OD"])
        model.removeManualLine("r1")
        XCTAssertEqual(model.readerNeedsHelp, ["Tab Telia 40 OD"])
        model.loadReaderLines([])
        XCTAssertTrue(model.readerNeedsHelp.isEmpty, "a new reading still clears the old warning")
    }

    // MARK: 19 - the stated dosage form travels in the name

    func testInjectionFormIsKeptSoItIsNotPricedAsATablet() throws {
        let result = reader.interpret(rows: ["Inj Dolo 1000 mg #1"])
        let line = try XCTUnwrap(result.lines.first, "\(result)")
        XCTAssertEqual(line.name, "Dolo Inj")
        XCTAssertEqual(line.strength, "1000 mg")
        XCTAssertEqual(line.quantity, 1)

        let model = AppModel()
        model.loadReaderLines(result.lines)
        model.confirmList()
        let offer = try XCTUnwrap(model.catalogueOffers["r1"], "Dolo 1000 injection has a catalogue price")
        XCTAssertEqual(offer.price.perPackPaise, 26_800, "the infusion pack, Rs 268")
        XCTAssertNotEqual(offer.price.perPackPaise, 4_500, "not the Rs 45 tablet")

        // the same name without the form is still the tablet
        model.loadReaderLines([ReaderLine(kind: "medicine", name: "Dolo", strength: "1000 mg", quantity: 1, schedule: nil)])
        model.confirmList()
        XCTAssertEqual(model.catalogueOffers["r1"]?.price.perPackPaise, 4_500)
    }

    func testEachFormIsCarriedAsTheAbbreviationTheMatcherKnows() {
        XCTAssertEqual(reader.interpret(rows: ["Tab Pan 40 OD"]).lines.first?.name, "Pan Tab")
        XCTAssertEqual(reader.interpret(rows: ["Cap Omez 20 OD"]).lines.first?.name, "Omez Cap")
        XCTAssertEqual(reader.interpret(rows: ["Syp Ascoril LS 5ml TDS"]).lines.first?.name, "Ascoril LS Syp")
        XCTAssertEqual(reader.interpret(rows: ["Oint Soframycin BD x 5 days"]).lines.first?.name, "Soframycin Oint")
        // a multi-word brand keeps matching as that brand: the Confirm check strips the form word again
        XCTAssertEqual(AppModel().catalogue.check(brand: "Montair LC Tab", strength: "10"), AppModel().catalogue.check(brand: "Montair LC", strength: "10"))
    }

    // MARK: 20 - an explicit dose count multiplies the quantity; an ambiguous one is asked, not guessed

    func testExplicitDoseCountMultipliesTheQuantity() {
        XCTAssertEqual(reader.interpret(rows: ["Tab Dolo 650 2BD x 10 days"]).lines.first?.quantity, 40)
        XCTAssertEqual(reader.interpret(rows: ["Tab Dolo 650 2 BD x 10 days"]).lines.first?.quantity, 40)
        XCTAssertEqual(reader.interpret(rows: ["Tab Dolo 650 2 tabs BD x 10 days"]).lines.first?.quantity, 40)
        XCTAssertEqual(reader.interpret(rows: ["Tab Dolo 650 1-0-1 x 10 days"]).lines.first?.quantity, 20, "a pattern stays as it was")
    }

    func testAmbiguousDoseCountGoesToNeedsHelpWithItsRawText() {
        let row = "Tab Dolo 650 2 tabs 1-0-1 x 5 days"
        let result = reader.interpret(rows: [row])
        XCTAssertTrue(result.lines.isEmpty, "\(result.lines)")
        XCTAssertEqual(result.needsHelp, [row])
    }

    // MARK: 21 - two medicines in one grouped row

    func testTwoMedicinesInOneRowKeepTheFirstOne() {
        let boxes = [box("Dolo 650 Tablet TDS", x: 0.05, y: 0.5, w: 0.22), box("Tab Pan 40 OD", x: 0.30, y: 0.5, w: 0.2)]
        let result = reader.interpret(boxes: boxes, aspect: 0.7)
        XCTAssertEqual(result.lines.map(\.name), ["Dolo Tab", "Pan Tab"], "\(result)")
        XCTAssertEqual(result.lines.map(\.schedule), ["TDS", "OD"])
        XCTAssertTrue(result.needsHelp.isEmpty, "\(result.needsHelp)")
    }

    func testASideColumnBeforeTheMedicineIsStillDropped() {
        for side in ["c/o Headache", "Fever x 3 days", "Allergic rhinitis"] {
            let result = reader.interpret(boxes: [box(side, x: 0.05, y: 0.5, w: 0.15), box("Tab Pan 40 OD", x: 0.28, y: 0.5, w: 0.2)], aspect: 0.7)
            XCTAssertEqual(result.lines.map(\.name), ["Pan Tab"], side)
            XCTAssertTrue(result.needsHelp.isEmpty, "\(side): \(result.needsHelp)")
        }
    }

    func testAnUnsureMedicineBeforeTheFormBoxIsShownNotDropped() {
        let result = reader.interpret(boxes: [box("Telia 40 Tablet OD", x: 0.05, y: 0.5, w: 0.22), box("Tab Pan 40 OD", x: 0.30, y: 0.5, w: 0.2)], aspect: 0.7)
        XCTAssertEqual(result.lines.map(\.name), ["Pan Tab"])
        XCTAssertEqual(result.needsHelp, ["Telia 40 Tablet OD"])
    }
}
