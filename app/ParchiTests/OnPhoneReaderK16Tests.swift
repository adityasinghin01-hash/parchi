import CoreGraphics
import ParchiCore
import UIKit
import XCTest
@testable import Parchi

/// K16: the on-phone reader for PRINTED parchis. Grouping, header rejection, "needsHelp, never guessed", and two real Vision runs
/// on tiny synthetic fixtures. Handwriting is not tested here because it is not supported.
final class OnPhoneReaderK16Tests: XCTestCase {
    private func box(_ text: String, x: CGFloat, y: CGFloat, w: CGFloat = 0.2, h: CGFloat = 0.02) -> OCRBox {
        OCRBox(text: text, rect: CGRect(x: x, y: y, width: w, height: h), confidence: 0.9)
    }

    private var reader: OnPhoneReader {
        let catalogue = Catalogue(productNames: ["Pan 40 Tablet", "Pan 20 Tablet", "Dolo 650 Tablet", "Telma 40 Tablet", "Telma 80 Tablet", "Azithral 500 Tablet"])
        return OnPhoneReader(parser: PrintedParser(catalogue: catalogue), tests: nil)
    }

    // MARK: line grouping

    func testBoxesOnTheSameRowJoinLeftToRightAndRowsRunTopToBottom() {
        // Vision's y grows upwards, so y 0.8 is higher on the page than 0.5.
        let boxes = [
            box("1-0-1", x: 0.50, y: 0.50, w: 0.1), box("Tab", x: 0.10, y: 0.5005), box("Pan 40", x: 0.25, y: 0.499),
            box("Name: Ravi", x: 0.10, y: 0.80),
            box("Cap Azithral 500", x: 0.10, y: 0.40, w: 0.4),
        ]
        let rows = LineGrouper.group(boxes, aspect: 0.7)
        XCTAssertEqual(rows.map(\.text), ["Name: Ravi", "Tab Pan 40 1-0-1", "Cap Azithral 500"])
    }

    func testSideColumnFarAwayIsNotGluedAndMedicineStartsAtItsForm() {
        // "c/o Fever" sits left of the medicine on the same row but with a wide gap: one row would be wrong, two boxes in one row are cut at "Tab".
        let near = [box("c/o Headache", x: 0.05, y: 0.5, w: 0.15), box("Tab Pan 40 1-0-1", x: 0.28, y: 0.5, w: 0.4)]
        let row = LineGrouper.group(near, aspect: 0.7)
        XCTAssertEqual(row.count, 1)
        XCTAssertEqual(OnPhoneReader.rowText(row[0]), "Tab Pan 40 1-0-1")
        let far = [box("Age: 34", x: 0.02, y: 0.5, w: 0.05), box("Tab Pan 40 1-0-1", x: 0.6, y: 0.5, w: 0.3)]
        XCTAssertEqual(LineGrouper.group(far, aspect: 0.7).count, 2, "a gap wider than 4 line-heights starts a new row")
    }

    func testBoxesThatOnlyTouchVerticallyAreDifferentRows() {
        let boxes = [box("Tab Pan 40 OD", x: 0.1, y: 0.50), box("Tab Dolo 650 TDS", x: 0.1, y: 0.475)]   // 0.025 apart, 0.02 tall: no overlap
        XCTAssertEqual(LineGrouper.group(boxes, aspect: 1).count, 2)
    }

    func testEmptyAndBlankBoxesGiveNoRows() {
        XCTAssertTrue(LineGrouper.group([], aspect: 1).isEmpty)
        XCTAssertTrue(LineGrouper.group([box("  ", x: 0.1, y: 0.1)], aspect: 1).isEmpty)
    }

    // MARK: header / footer / patient / doctor lines never become medicines

    func testHeaderFooterPatientAndDoctorLinesAreIgnored() {
        let rows = ["Dr. Nitin Agarwal", "MBBS, MD (Derma)", "Reg. No. MPMC 37101", "Sai Medical Centre, Bhopal • Ph: 79395 84427",
                    "Name: Komal Sharma", "Age/Sex: 34 Date: 22-2-2026", "Rx", "BP 102/60", "c/o Fever", "Dx Viral fever", "Timings: 10 am - 2 pm, 5 pm - 8 pm",
                    "Emergency: 7422806194", "Not valid for medico-legal purposes", "Review after 7 days", "F/U 1 wk", "Dr. T. Sharma MBBS"]
        let result = reader.interpret(rows: rows)
        XCTAssertTrue(result.lines.isEmpty, "\(result.lines)")
        XCTAssertTrue(result.needsHelp.isEmpty, "\(result.needsHelp)")
    }

    func testNoLabelRowIsEverReadAsAMedicineFromAFormWordInsideAHeader() {
        // "Tab" appears inside a clinic/credential line: the line has no medicine shape, so nothing is invented.
        let result = reader.interpret(rows: ["Dr. Rao's Tablet Clinic", "City Hospital & Nursing Home", "Advice: take tablets after food"])
        XCTAssertTrue(result.lines.isEmpty, "\(result.lines)")
    }

    // MARK: needsHelp, not guess

    func testConfidentLineBecomesAMedicineWithFields() {
        let result = reader.interpret(rows: ["1) Tab Telma 40 1-0-0 x 30 days"])
        XCTAssertEqual(result.lines.count, 1)
        XCTAssertEqual(result.lines.first?.name, "Telma")
        XCTAssertEqual(result.lines.first?.strength, "40")
        XCTAssertEqual(result.lines.first?.schedule, "1-0-0")
        XCTAssertEqual(result.lines.first?.quantity, 30)
        XCTAssertEqual(result.lines.first?.kind, "medicine")
        XCTAssertTrue(result.needsHelp.isEmpty)
        XCTAssertTrue(result.note.hasPrefix("Read on this phone. Printed text only. Check every line."))
    }

    func testUnsureLineGoesToNeedsHelpWithRawTextAndIsNotGuessed() {
        // unknown brand ("Telia" is one letter from Telma), impossible strength, no form: none may become a medicine line
        let rows = ["Tab Telia 40 1-0-0 x 30 days", "Tab Telma 400 1-0-0 x 30 days", "Zordx 10 mg 1-0-1", "Syp"]
        let result = reader.interpret(rows: rows)
        XCTAssertTrue(result.lines.isEmpty, "\(result.lines)")
        XCTAssertEqual(Array(result.needsHelp.prefix(3)), Array(rows.prefix(3)), "raw text kept, as read")
        XCTAssertFalse(result.lines.contains { $0.name.lowercased().contains("telma") }, "Telia must not be 'corrected' to Telma")
    }

    func testSomeRowsWithAndWithoutHelpKeepPageOrder() {
        let result = reader.interpret(rows: ["Tab Pan 40 1-0-0", "Tab Telia 40 OD", "Tab Dolo 650 TDS"])
        XCTAssertEqual(result.lines.map(\.name), ["Pan", "Dolo"])
        XCTAssertEqual(result.needsHelp, ["Tab Telia 40 OD"])
    }

    func testTwoMedicinesOnOneRowAreSplit() {
        let result = reader.interpret(rows: ["1) Tab Pan 40 1-0-0 x 5d 2) Tab Dolo 650 TDS x 3d"])
        XCTAssertEqual(result.lines.map(\.name), ["Pan", "Dolo"])
    }

    func testSideColumnTextBeforeTheMedicineIsDroppedButHeaderIsNotPromoted() {
        let result = reader.interpret(rows: ["Allergic rhinitis 2) Tab Telma 80 OD x 10d"])
        XCTAssertEqual(result.lines.map(\.name), ["Telma"])
    }

    func testSpacesVisionDropsAreRestored() {
        let result = reader.interpret(rows: ["-Tab Pan 40 OD", "2) T.DOLO 650 TDS", "3) TabTELMA 40 1-0-0", "-Tab AZITHRAL MR1-1-1 x 3d"])
        XCTAssertEqual(result.lines.map { $0.name.uppercased() }, ["PAN", "DOLO", "TELMA", "AZITHRAL MR"])
        XCTAssertEqual(result.lines.last?.schedule, "1-1-1")
        XCTAssertTrue(result.needsHelp.isEmpty, "\(result.needsHelp)")
    }

    func testTestsAreOnlyTakenFromAnExplicitTestsLine() {
        let result = reader.interpret(rows: ["Inv: CBC, HbA1c", "Complete the course of tablets"])
        XCTAssertEqual(result.lines.map(\.name), ["CBC", "HbA1c"])
        XCTAssertTrue(result.lines.allSatisfy { $0.kind == "test" })
        // "Adv:" can also be plain advice, so without a test catalogue the names are not trusted
        let adv = reader.interpret(rows: ["Adv: plenty of fluids"])
        XCTAssertTrue(adv.lines.isEmpty)
        XCTAssertEqual(adv.needsHelp, ["plenty of fluids"])
    }

    // MARK: notes are honest

    func testNoteSaysHandwritingCannotBeReadWhenMostLinesFailed() {
        let few = reader.interpret(rows: ["Tab Telia 40 OD", "Tab Zordx 10 OD", "Tab Pan 40 OD"])
        XCTAssertTrue(few.note.contains("Handwriting could not be read on this phone"), few.note)
        let nothing = reader.interpret(rows: [])
        XCTAssertTrue(nothing.note.contains("Nothing could be read"), nothing.note)
        XCTAssertTrue(nothing.lines.isEmpty && nothing.needsHelp.isEmpty)
    }

    func testNoteNeverClaimsMoreThanPrintedText() {
        let ok = reader.interpret(rows: ["Tab Pan 40 OD"])
        XCTAssertTrue(ok.note.contains("Printed text only"))
        XCTAssertFalse(ok.note.lowercased().contains("handwrit") && !ok.note.contains("could not"))
    }

    // MARK: real Vision on tiny synthetic fixtures (Simulator or device)

    private func fixture(_ name: String) throws -> UIImage {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "jpg"), "missing fixture \(name)")
        return try XCTUnwrap(UIImage(contentsOfFile: url.path))
    }

    private func realReader() -> OnPhoneReader {
        OnPhoneReader(bundle: .main)
    }

    func testReadsTheScanFixtureWithBrandsStrengthsAndNothingInvented() async throws {
        let result = await realReader().read(try fixture("printed_scan"))
        let names = result.lines.filter { $0.kind == "medicine" }.map { $0.name.uppercased() }
        for expected in ["GELAMP", "FORZOLE-D", "TRINOX", "EVAQUIN"] {
            XCTAssertTrue(names.contains(expected) || result.needsHelp.joined(separator: " ").uppercased().contains(expected), "\(expected) missing: \(names) \(result.needsHelp)")
        }
        XCTAssertGreaterThanOrEqual(names.filter { ["GELAMP", "FORZOLE-D", "TRINOX", "EVAQUIN"].contains($0) }.count, 3)
        XCTAssertEqual(result.lines.first { $0.name.uppercased() == "TRINOX" }?.strength, "250 mg")
        XCTAssertEqual(result.lines.first { $0.name.uppercased() == "EVAQUIN" }?.strength, "15 mg")
        let allowed: Set<String> = ["GELAMP", "FORZOLE-D", "TRINOX", "EVAQUIN"]
        XCTAssertTrue(names.allSatisfy { allowed.contains($0) }, "invented medicine: \(names)")
        XCTAssertTrue(result.note.contains("Printed text only"), result.note)
    }

    func testReadsThePhotoFixtureAndNeverTurnsHeaderLinesIntoMedicines() async throws {
        let result = await realReader().read(try fixture("printed_photo"))
        let names = result.lines.filter { $0.kind == "medicine" }.map { $0.name.uppercased() }
        let allowed = ["ESTIRIC", "FLUCLIK", "FLOXMED", "TRYBROR"]
        XCTAssertGreaterThanOrEqual(names.filter { n in allowed.contains { n.hasPrefix($0) } }.count, 3, "\(names) \(result.needsHelp)")
        XCTAssertTrue(names.allSatisfy { n in allowed.contains { n.hasPrefix($0) } }, "invented medicine: \(names)")
    }

    func testABlankPageGivesNothingAndSaysSo() async throws {
        let size = CGSize(width: 400, height: 600)
        let blank = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        let result = await realReader().read(blank)
        XCTAssertTrue(result.lines.isEmpty)
        XCTAssertTrue(result.needsHelp.isEmpty)
        XCTAssertTrue(result.note.contains("Nothing could be read"), result.note)
    }
}

/// Measurement runner for K16. Skipped unless `/tmp/k16/run.json` exists on the machine running the tests, e.g.
/// `{"images": "/tmp/k16/img", "out": "/tmp/k16/sim_out.json"}`. Runs the real reader (Vision in the Simulator) on every .jpg/.png in
/// the folder and writes rows, lines, needsHelp, note and seconds per image for `/tmp/k16/score.py`. Not part of the shipped app.
final class OnPhoneReaderMeasureK16: XCTestCase {
    func testMeasureFolder() async throws {
        guard let data = FileManager.default.contents(atPath: "/tmp/k16/run.json"),
              let cfg = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let dir = cfg["images"], let outPath = cfg["out"] else { throw XCTSkip("no /tmp/k16/run.json") }
        let reader = OnPhoneReader(bundle: .main)
        let files = try FileManager.default.contentsOfDirectory(atPath: dir).filter { $0.hasSuffix(".jpg") || $0.hasSuffix(".png") }.sorted()
        var out: [[String: Any]] = []
        for f in files {
            guard let image = UIImage(contentsOfFile: dir + "/" + f), let cg = image.cgImage else { continue }
            let start = Date()
            let boxes = await Task.detached { OnPhoneReader.recognise(cg, orientation: .up) }.value
            let aspect = CGFloat(cg.width) / CGFloat(cg.height)
            let rows = LineGrouper.group(boxes, aspect: aspect).map(OnPhoneReader.rowText)
            let result = reader.interpret(boxes: boxes, aspect: aspect)
            let seconds = Date().timeIntervalSince(start)
            out.append([
                "id": (f as NSString).deletingPathExtension, "sec": seconds, "rows": rows, "needsHelp": result.needsHelp, "note": result.note,
                "lines": result.lines.map { ["kind": $0.kind ?? "", "name": $0.name, "strength": $0.strength ?? "", "quantity": $0.quantity ?? 0, "schedule": $0.schedule ?? ""] as [String: Any] },
            ])
        }
        try JSONSerialization.data(withJSONObject: out).write(to: URL(fileURLWithPath: outPath))
        XCTAssertEqual(out.count, files.count)
    }
}
