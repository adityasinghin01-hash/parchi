import Foundation
import Testing
@testable import ParchiCore

/// engine/catalogue/tests_canonical.json, the real file the app bundles.
private func realCatalogue() throws -> TestCatalogue {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { url.deleteLastPathComponent() } // -> engine/
    return try TestCatalogue(json: Data(contentsOf: url.appendingPathComponent("catalogue/tests_canonical.json")))
}

private let small = TestCatalogue(tests: [
    CanonicalTest(name: "Free T3", synonyms: ["FT3"], confusableWith: ["Total T3"]),
    CanonicalTest(name: "Total T3", synonyms: ["TT3"], confusableWith: ["Free T3"]),
    CanonicalTest(name: "HbA1c", synonyms: ["A1C"], confusableWith: ["Estimated average glucose (eAG)"]),
    CanonicalTest(name: "CBC", synonyms: ["Complete Blood Count"]),
])

@Test func synonymIsCaseSpaceAndPunctuationInsensitive() {
    #expect(canonicalTest(for: "complete blood count", catalogue: small) == .exact("CBC"))
    #expect(canonicalTest(for: "  C.B.C  ", catalogue: small) == .exact("CBC"))
    #expect(canonicalTest(for: "Hb-A1c", catalogue: small) == .exact("HbA1c"))
    #expect(canonicalTest(for: "HBA1C test", catalogue: small) == .exact("HbA1c"))
}

@Test func missingQualifierIsAmbiguousNotGuessed() {
    #expect(canonicalTest(for: "T3", catalogue: small) == .ambiguous(["Free T3", "Total T3"]))
}

@Test func lookAlikeOfAKnownTestIsAskedNotMapped() {
    // "average glucose" is not HbA1c; the patient/doctor intent must be confirmed.
    #expect(canonicalTest(for: "Estimated average glucose (eAG)", catalogue: small)
            == .ambiguous(["HbA1c", "Estimated average glucose (eAG)"]))
    #expect(canonicalTest(for: "eAG", catalogue: small) == .ambiguous(["HbA1c", "eAG"]))
}

@Test func unknownAndEmptyNames() {
    #expect(canonicalTest(for: "Quantum scan", catalogue: small) == .unknown)
    #expect(canonicalTest(for: "   ", catalogue: small) == .unknown)
    #expect(canonicalTest(for: "()", catalogue: small) == .unknown)
}

@Test func realFileLoadsAll29Tests() throws {
    let cat = try realCatalogue()
    #expect(cat.tests.count == 29)
    #expect(cat.tests.first { $0.name == "CBC" }?.fasting == .notRequired)
    #expect(cat.tests.first { $0.name == "Fasting blood sugar" }?.fasting == .required)
    #expect(cat.tests.contains { $0.fasting == .unknown })
}

@Test func realFileExactNames() throws {
    let cat = try realCatalogue()
    #expect(canonicalTest(for: "Complete Blood Count", catalogue: cat) == .exact("CBC"))
    #expect(canonicalTest(for: "lipid panel", catalogue: cat) == .exact("Lipid profile"))
    #expect(canonicalTest(for: "FBS", catalogue: cat) == .exact("Fasting blood sugar"))
    #expect(canonicalTest(for: "Fasting Blood Sugar (FBS)", catalogue: cat) == .exact("Fasting blood sugar"))
    #expect(canonicalTest(for: "free T3", catalogue: cat) == .exact("Free T3"))
    #expect(canonicalTest(for: "TT4", catalogue: cat) == .unknown)  // not observed on any cited page, so not guessed
    #expect(canonicalTest(for: "glycated hemoglobin", catalogue: cat) == .exact("HbA1c"))
    #expect(canonicalTest(for: "TSH", catalogue: cat) == .exact("TSH"))
}

@Test func realFileFreeVsTotalThyroidIsAsked() throws {
    let cat = try realCatalogue()
    #expect(canonicalTest(for: "T3", catalogue: cat) == .ambiguous(["Free T3", "Total T3"]))
    #expect(canonicalTest(for: "T4", catalogue: cat) == .ambiguous(["Free T4", "Total T4"]))
    #expect(canonicalTest(for: "T4 test", catalogue: cat) == .ambiguous(["Free T4", "Total T4"]))
    #expect(canonicalTest(for: "Thyroid profile", catalogue: cat)
            == .ambiguous(["Thyroid profile (T3 T4 TSH)", "Thyroid profile free"]))
}

@Test func realFileGlucoseFastingVsPostMealVsRandomIsAsked() throws {
    let cat = try realCatalogue()
    for written in ["blood sugar", "sugar", "glucose", "Blood glucose"] {
        guard case .ambiguous(let c) = canonicalTest(for: written, catalogue: cat) else {
            Issue.record("\(written) should be ambiguous"); continue
        }
        #expect(Set(c) == ["Fasting blood sugar", "Post-prandial blood sugar", "Random blood sugar"], "\(written)")
    }
    #expect(canonicalTest(for: "Random blood sugar", catalogue: cat) == .exact("Random blood sugar"))
}

@Test func realFileHbA1cVsAverageGlucose() throws {
    let cat = try realCatalogue()
    #expect(canonicalTest(for: "A1C", catalogue: cat) == .exact("HbA1c"))
    #expect(canonicalTest(for: "estimated average glucose", catalogue: cat)
            == .ambiguous(["HbA1c", "estimated average glucose"]))
}

@Test func realFileSharedAbbreviationIsAmbiguous() throws {
    let cat = try realCatalogue()
    // "UA" is a synonym of both urine analysis and uric acid in the cited sources.
    #expect(canonicalTest(for: "UA", catalogue: cat) == .ambiguous(["Urine routine", "Uric acid"]))
}

@Test func realFileCholesterolMightBeTheWholeLipidProfile() throws {
    let cat = try realCatalogue()
    #expect(canonicalTest(for: "Cholesterol", catalogue: cat) == .ambiguous(["Lipid profile", "Cholesterol"]))
}

@Test func everyCanonicalNameAndSynonymResolvesToItselfOrIsAsked() throws {
    let cat = try realCatalogue()
    for test in cat.tests {
        for alias in [test.name] + test.synonyms {
            switch canonicalTest(for: alias, catalogue: cat) {
            case .exact(let name): #expect(name == test.name, "\(alias) -> \(name)")
            case .ambiguous(let names): #expect(names.contains(test.name), "\(alias) lost \(test.name)")
            case .unknown: Issue.record("\(alias) is unknown")
            }
        }
    }
}
