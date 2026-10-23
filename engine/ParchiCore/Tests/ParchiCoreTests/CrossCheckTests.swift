import Testing
@testable import ParchiCore

private let catalogue = Catalogue(productNames: [
    "Telma 20 Tablet", "Telma 40 Tablet", "Telma 80 Tablet",
    "Pan 40 Tablet", "Dolo 650 Tablet", "Augmentin 625 Duo Tablet",
])

@Test func realBrandAndStrengthIsConfirmed() {
    #expect(catalogue.check(brand: "Telma", strength: "40") == .confirmed(brand: "TELMA", strength: "40"))
}

@Test func impossibleStrengthIsFlaggedWithRealChoices() {
    #expect(catalogue.check(brand: "Telma", strength: "400")
            == .strengthMismatch(brand: "TELMA", read: "400", available: ["20", "40", "80"]))
}

@Test func missingStrengthAsksWithOptions() {
    #expect(catalogue.check(brand: "telma", strength: nil) == .strengthMissing(brand: "TELMA", available: ["20", "40", "80"]))
}

@Test func misreadBrandGetsClosestRealBrand() {
    // Apple Vision read "Telia 40" for "Telma 40" on MIRAGE rx004.
    guard case .unknownBrand(_, let suggestions) = catalogue.check(brand: "Telia", strength: "40") else {
        Issue.record("expected unknown brand")
        return
    }
    #expect(suggestions.first == "TELMA")
}

@Test func doctorMemoryBreaksTies() {
    var memory = DoctorMemory()
    memory.record(doctor: "Dr. K. Sharma", confirmedBrands: ["NERVIDAY", "SUPRACAL", "NERVIDAY"])
    let ranked = memory.rerank(doctor: "dr. k. sharma", candidates: [("NERVIT", 0.52), ("NERVIDAY", 0.48)])
    #expect(ranked.first?.brand == "NERVIDAY")
}

@Test func unknownDoctorKeepsModelOrder() {
    let memory = DoctorMemory()
    let ranked = memory.rerank(doctor: "new doctor", candidates: [("A", 0.4), ("B", 0.6)])
    #expect(ranked.map(\.brand) == ["B", "A"])
}
