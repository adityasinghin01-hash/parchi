import ParchiCore
import XCTest
@testable import Parchi

/// K18: typing medicines and tests in by hand (Confirm screen). Runs hosted in the app, so it reads the real bundled
/// brand_mrp.json, brand_strengths.json, tests_canonical.json and the H1/X files.
@MainActor
final class ManualAddTests: XCTestCase {
    private func reader(_ name: String, _ strength: String?, _ quantity: Int) -> ReaderLine {
        ReaderLine(kind: "medicine", name: name, strength: strength, quantity: quantity, schedule: nil)
    }

    /// A tiny catalogue file in the real format, for exact expectations.
    private func tinyIndex(_ keys: [String]) throws -> ManualBrandIndex {
        var brands: [String: String] = [:]
        for key in keys { brands[key] = "10,1000,0,4" }
        let json = try JSONSerialization.data(withJSONObject: ["brands": brands])
        return try XCTUnwrap(ManualBrandIndex(json: json))
    }

    private func realIndex() async throws -> ManualBrandIndex {
        let loaded = await ManualBrandStore.shared.load()
        return try XCTUnwrap(loaded, "brand_mrp.json must be in the app bundle")
    }

    // MARK: suggestions

    func testPrefixMatchesComeBeforeContainsMatchesAndAreCaseInsensitive() throws {
        let index = try tinyIndex(["ZDOLO", "DOLOMIN", "ADOLA", "DOLO", "PANTOP", "DOLOX"])
        XCTAssertEqual(index.suggestions(for: "dol"), ["DOLO", "DOLOMIN", "DOLOX", "ADOLA", "ZDOLO"])
        XCTAssertEqual(index.suggestions(for: "DoL"), index.suggestions(for: "dol"))
        XCTAssertEqual(index.suggestions(for: "  dolo "), ["DOLO", "DOLOMIN", "DOLOX", "ZDOLO"])
        XCTAssertEqual(index.suggestions(for: "tOp"), ["PANTOP"], "contains match when nothing starts with it")
        XCTAssertEqual(index.suggestions(for: ""), [])
        XCTAssertEqual(index.suggestions(for: "   "), [])
        XCTAssertEqual(index.suggestions(for: "qqq"), [])
    }

    func testAtMostTwentySuggestionsPrefixFirst() throws {
        let prefixed = (0..<15).map { "TAB" + String(UnicodeScalar(UInt8(65 + $0))) + "X" }          // 15 start with TAB
        let inside = (0..<15).map { "X" + String(UnicodeScalar(UInt8(65 + $0))) + "TABY" }           // 15 merely contain TAB
        let index = try tinyIndex(prefixed + inside)
        let found = index.suggestions(for: "tab")
        XCTAssertEqual(found.count, 20)
        XCTAssertEqual(Array(found.prefix(15)), prefixed.sorted(), "all 15 prefix matches first")
        XCTAssertTrue(found.dropFirst(15).allSatisfy { $0.contains("TAB") && !$0.hasPrefix("TAB") })
    }

    func testOnlyBrandsThatCanBePricedAreSuggested() throws {
        let index = try tinyIndex(["AB", "ABC", "AB1C", "abcd", "ABCD"])
        XCTAssertEqual(index.brands, ["ABC", "ABCD"], "2 letters, digits and lower case can never match a catalogue key")
        XCTAssertEqual(index.suggestions(for: "ab"), ["ABC", "ABCD"])
    }

    func testRealCatalogueSuggestionsAreCappedAndPriceable() async throws {
        let index = try await realIndex()
        XCTAssertGreaterThan(index.brands.count, 100_000)
        XCTAssertEqual(index.suggestions(for: "a").count, 20)
        let dolo = index.suggestions(for: "dolo")
        XCTAssertEqual(dolo.first, "DOLO")
        XCTAssertLessThanOrEqual(dolo.count, 20)
        XCTAssertTrue(dolo.dropFirst().allSatisfy { $0.hasPrefix("DOLO") || $0.contains("DOLO") })
        // every suggestion is a real catalogue key the price lookup resolves ("Dolo" -> DOLO; priced when the strength is right)
        let model = AppModel()
        for brand in ["DOLO", "PANTOP", "TELMA", "AUGMENTIN", "MONTAIR"] {
            XCTAssertTrue(index.contains(brand: brand), brand)
            let strengths = index.strengths(brand: brand)
            XCTAssertFalse(strengths.isEmpty, brand)
            XCTAssertTrue(strengths.contains { model.data.catalogueOffer(brand: ManualBrandIndex.displayName(forBrand: brand), strength: $0) != nil },
                          "\(brand) has at least one strength that gets a catalogue price")
        }
        XCTAssertFalse(index.contains(brand: "Xyzzyqq"))
        // Montair LC has no number in its catalogue name: no strength list (the screen shows a number field), still priced
        XCTAssertTrue(index.contains(brand: "Montair LC"))
        XCTAssertEqual(index.strengths(brand: "Montair LC"), [])
        XCTAssertNotNil(model.data.catalogueOffer(brand: "Montairlc", strength: nil))
    }

    func testStrengthsAreTheCataloguesOwnAndSortedByNumber() async throws {
        let index = try await realIndex()
        XCTAssertEqual(index.strengths(brand: "Dolo"), ["100", "120", "156.25", "250", "500", "650", "1000"])
        XCTAssertEqual(index.strengths(brand: "alprax"), ["0.125", "0.25", "0.5", "1", "1.5"])
        XCTAssertEqual(index.strengths(brand: "Xyzzyqq"), [], "never invented")
        let model = AppModel()
        let choices = model.manualStrengthChoices(brand: "Dolo", index: index)
        XCTAssertTrue(choices.contains("650"))
        XCTAssertTrue(choices.allSatisfy { Set(model.catalogue.strengths["DOLO"] ?? []).contains($0) },
                      "every offered strength is one the Confirm check accepts")
    }

    func testBrandWithNoNumberInItsNameOffersNoStrengthList() throws {
        let json = try JSONSerialization.data(withJSONObject: ["brands": ["SOAPY": ",1000,0,4", "TWOWAY": ",1000,0,4;5,1000,0,4"]])
        let index = try XCTUnwrap(ManualBrandIndex(json: json))
        XCTAssertEqual(index.strengths(brand: "Soapy"), [])
        XCTAssertEqual(index.strengths(brand: "Twoway"), ["5"])
    }

    // MARK: add / remove through the model

    func testRebuildKeepsStrengthsQuantitiesAndKinds() {
        let model = AppModel()
        model.loadReaderLines([reader("Dolo", "650", 15), reader("Telma", "41", 10),
                               ReaderLine(kind: "test", name: "CBC", strength: nil, quantity: nil, schedule: nil)])
        XCTAssertFalse(model.allConfirmed)
        model.choose(strength: "40", for: "r2")                 // the patient's answer must survive the rebuild

        model.addManualMedicine(name: "Pantop", strength: "40", quantity: 20)

        XCTAssertEqual(model.lines.map(\.id), ["r1", "r2", "r3", "r4"])
        XCTAssertEqual(model.lines.map(\.item.name), ["Dolo", "Telma", "CBC", "Pantop"])
        XCTAssertEqual(model.lines.map(\.item.strength), ["650", "40", nil, "40"])
        XCTAssertEqual(model.lines.map(\.item.quantity), [15, 10, 1, 20])
        XCTAssertEqual(model.lines.map(\.item.kind), [.medicine, .medicine, .test, .medicine])
        XCTAssertTrue(model.allConfirmed, "Telma 40 stays answered")
        XCTAssertEqual(model.lines[2].canonicalTestName, "CBC")
    }

    func testRemoveWorksAndRenumbers() {
        let model = AppModel()
        model.loadReaderLines([reader("Dolo", "650", 15), reader("Pantop", "40", 15), reader("Augmentin", "625", 10)])
        model.removeManualLine("r2")
        XCTAssertEqual(model.lines.map(\.item.name), ["Dolo", "Augmentin"])
        XCTAssertEqual(model.lines.map(\.id), ["r1", "r2"])
        XCTAssertEqual(model.lines.map(\.item.quantity), [15, 10])
        model.removeManualLine("nope")
        XCTAssertEqual(model.lines.count, 2, "unknown id changes nothing")
        model.removeManualLine("r1")
        model.removeManualLine("r1")
        XCTAssertTrue(model.lines.isEmpty)
        XCTAssertTrue(model.allConfirmed)
    }

    func testAddedMedicineGetsTheCatalogueMRPPlan() throws {
        let model = AppModel()
        model.addManualMedicine(name: "Dolo", strength: "650", quantity: 15)
        XCTAssertTrue(model.allConfirmed)
        model.confirmList()
        let plan = try XCTUnwrap(model.plan)
        XCTAssertEqual(plan.itemsTotal, 3427, "Dolo 650: one strip of 15 at Rs 34.27")
        XCTAssertEqual(model.priceSource(sellerID: "doctorshop", itemID: "r1").datedLabel, "Catalogue MRP · check at the shop")
    }

    func testAddingAlpraxShowsTheInPersonMessageAndNoOnlinePrice() throws {
        let model = AppModel()
        model.addManualMedicine(name: "Alprax", strength: "0.25", quantity: 10)
        let line = try XCTUnwrap(model.lines.first)
        let schedule = try XCTUnwrap(line.inPersonOnly, "alprazolam is H1")
        XCTAssertTrue(schedule.inPersonMessage.localizedCaseInsensitiveContains("original parchi"), schedule.inPersonMessage)
        model.confirmList()
        XCTAssertEqual(model.inPersonMessage(itemID: "r1"), schedule.inPersonMessage)
        let plan = try XCTUnwrap(model.plan)
        for planned in plan.lines {
            let channel = model.seller(planned.sellerID)?.channel
            XCTAssertNotEqual(channel, .onlinePharmacy)
            XCTAssertNotEqual(channel, .quickCommerce)
        }
        XCTAssertNil(model.janAushadhiLine(itemID: "r1"))
    }

    func testTypedNameThatMatchesNoBrandKeepsTheExistingNotFoundRules() throws {
        let model = AppModel()
        model.addManualMedicine(name: "  Xyzzyqq  ", strength: "", quantity: 5)
        let line = try XCTUnwrap(model.lines.first)
        XCTAssertEqual(line.item.name, "Xyzzyqq", "kept as typed, trimmed")
        XCTAssertNil(line.item.strength, "an empty strength field means no strength")
        guard case .unknownBrand? = line.check else { return XCTFail("expected unknownBrand, got \(String(describing: line.check))") }
        XCTAssertFalse(model.allConfirmed)
    }

    func testQuantityIsClampedAndBlankNamesAreIgnored() {
        let model = AppModel()
        model.addManualMedicine(name: "Dolo", strength: "650", quantity: 99_999)
        model.addManualMedicine(name: "Pantop", strength: "40", quantity: -4)
        model.addManualMedicine(name: "   ", strength: nil, quantity: 10)
        model.addManualTest(name: "")
        XCTAssertEqual(model.lines.map(\.item.quantity), [1000, 1])
        XCTAssertEqual(model.lines.count, 2)
    }

    // MARK: tests

    func testTwentyNineCanonicalTestsAreOfferedAndAddingOneWorks() {
        let model = AppModel()
        let names = model.data.testCatalogue.tests.map(\.name)
        XCTAssertEqual(names.count, 29)
        XCTAssertEqual(AddTestSheet.filter(names, query: "").count, 29)
        XCTAssertTrue(AddTestSheet.filter(names, query: "cbc").contains("CBC"))
        XCTAssertTrue(AddTestSheet.filter(names, query: "zzzz").isEmpty)

        model.addManualTest(name: "CBC")
        let line = model.lines[0]
        XCTAssertEqual(line.item.kind, .test)
        XCTAssertEqual(line.canonicalTestName, "CBC")
        XCTAssertFalse(line.needsAnswer)
    }

    func testEveryCanonicalTestAddsAsAnExactMatch() {
        let model = AppModel()
        let names = model.data.testCatalogue.tests.map(\.name)
        for name in names { model.addManualTest(name: name) }
        XCTAssertEqual(model.lines.count, 29)
        XCTAssertEqual(model.lines.compactMap(\.canonicalTestName), names)
        XCTAssertTrue(model.allConfirmed)
    }

    func testAskYourDoctorOnAnAmbiguousTestSurvivesARebuild() throws {
        let model = AppModel()
        model.loadReaderLines([reader("Dolo", "650", 15), ReaderLine(kind: "test", name: "T3", strength: nil, quantity: nil, schedule: nil)])
        guard case .ambiguous? = model.lines[1].testMatch else { throw XCTSkip("T3 is not ambiguous in this catalogue") }
        XCTAssertFalse(model.allConfirmed)
        model.askDoctorAbout(testLine: "r2")
        XCTAssertTrue(model.allConfirmed)

        model.addManualMedicine(name: "Pantop", strength: "40", quantity: 10)
        XCTAssertTrue(model.lines[1].askDoctor, "the patient's 'ask my doctor' is put back")
        XCTAssertTrue(model.allConfirmed)

        model.removeManualLine("r1")            // the test moves to r1 and keeps its flag
        XCTAssertEqual(model.lines.first?.item.kind, .test)
        XCTAssertTrue(model.lines[0].askDoctor)
    }

    func testDemoParchiTotalIsUntouchedWhenNothingIsEdited() throws {
        let model = AppModel()
        model.readDemoParchi()
        model.choose(strength: "40", for: "telma")
        model.confirmList()
        XCTAssertEqual(try XCTUnwrap(model.plan).payable, 269_677, "Rs 2,696.77")
    }
}
