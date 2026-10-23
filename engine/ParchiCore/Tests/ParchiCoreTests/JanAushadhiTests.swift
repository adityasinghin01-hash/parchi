import Foundation
import Testing
@testable import ParchiCore

private func p(_ id: Int, _ name: String, _ mrp: Double, _ unit: String = "10's") -> JAProduct {
    JAProduct(productId: id, genericName: name, unitSize: unit, mrpRupees: mrp)
}

private let small = JanAushadhiIndex(products: [
    p(1, "Aceclofenac 100mg and Paracetamol 325mg Tablets", 10.32),
    p(2, "Telmisartan Tablets IP 40 mg", 9.5),
    p(3, "Telmisartan Tablets IP 80 mg", 14),
    p(4, "Telmisartan Tablets IP 40 mg", 40, "30's"),
    p(5, "Paracetamol Tablets IP 650 mg", 15.47, "15's"),
    p(6, "Metformin Hydrochloride Prolonged Release Tablets IP 500 mg", 7),
    p(7, "Metformin Hydrochloride Tablets IP 500mg", 6.81),
    p(8, "Pantoprazole Gastro Resistant Tablets IP 40 mg", 9.1),
    p(9, "Cetirizine Syrup IP 5 mg per 5 ml", 21.3, "60 ml"),
    p(10, "Ciprofloxacin Eye Drops IP 0.3% w/v", 12, "5 ml"),
    p(11, "Clotrimazole Cream IP 1% w/w", 18, "15 g"),
    p(12, "Amoxycillin 500mg and Potassium Clavulanate 125mg Tablets IP", 60),
    p(13, "Montelukast\u{00A0}Sodium 10mg\u{00A0}\u{00A0}and Fexofenadine Hydrochloride 120 mg Tablets", 45.38),
    p(14, "Levetiracetam Tablets 500 mg", 0),
    p(15, "Azithromycin Dispersible Tablets 100mg", 30),
    p(16, "Ceftriaxone Injection IP 1 g", 40, "Vial"),
    p(17, "Co-trimoxazole (Sulphamethoxazole 200mg and Trimethoprim 40mg per 5ml) Oral Suspension IP", 25, "50 ml"),
    p(18, "Atorvastatin 20mg + Ezetimibe 10mg Tablets", 28.13),
    p(19, "Pancreatin Capsules 40000", 20),
    p(20, "Povidone Iodine Gargle 2% w/v", 37.5, "100 ml"),
    p(21, "Fexofenadine Hydrochloride Suspension (30mg/5ml)", 28.13, "60 ml"),
])

@Test func exactSaltStrengthFormMatches() {
    let m = small.match(salt: "Telmisartan", strength: "40 mg", form: .tablet)
    #expect(m?.productId == 2)            // first pack on the list
    #expect(m?.mrpPaise == 950)
    #expect(m?.productName == "Telmisartan Tablets IP 40 mg")
    #expect(small.matches(salt: "telmisartan", strength: "40", form: .tablet).map(\.productId) == [2, 4])
}

@Test func neverADifferentStrength() {
    #expect(small.match(salt: "Telmisartan", strength: "20 mg", form: .tablet) == nil)
    #expect(small.match(salt: "Telmisartan", strength: "400 mg", form: .tablet) == nil)
    #expect(small.match(salt: "Paracetamol", strength: "500 mg", form: .tablet) == nil)
    #expect(small.match(salt: "Paracetamol", strength: "650", form: .tablet)?.productId == 5)
}

@Test func neverADifferentForm() {
    #expect(small.match(salt: "Telmisartan", strength: "40 mg", form: .capsule) == nil)
    #expect(small.match(salt: "Cetirizine", strength: "5 mg/5 ml", form: .tablet) == nil)
    #expect(small.match(salt: "Ciprofloxacin", strength: "0.3%", form: .liquid) == nil)   // eye drops are not a syrup
    #expect(small.match(salt: "Ciprofloxacin", strength: "0.3%", form: .drops)?.productId == 10)
}

@Test func combinationSaltsAreOrderInsensitive() {
    let a = small.match(salt: "Aceclofenac + Paracetamol", strength: "100 mg + 325 mg", form: .tablet)
    let b = small.match(salt: "Paracetamol + Aceclofenac", strength: "325 mg + 100 mg", form: .tablet)
    #expect(a?.productId == 1)
    #expect(b?.productId == 1)
    #expect(small.match(salt: "Paracetamol and Aceclofenac", strength: "325/100", form: .tablet)?.productId == 1)
}

@Test func combinationNeedsEverySaltAndEveryStrength() {
    #expect(small.match(salt: "Paracetamol", strength: "325 mg", form: .tablet) == nil)                       // missing a salt
    #expect(small.match(salt: "Paracetamol + Aceclofenac", strength: "100 mg + 325 mg", form: .tablet) == nil) // strengths swapped between salts
    #expect(small.match(salt: "Paracetamol + Aceclofenac", strength: "325 mg", form: .tablet) == nil)          // one strength for two salts
    #expect(small.match(salt: "Aceclofenac + Paracetamol + Caffeine", strength: "100 + 325 + 30", form: .tablet) == nil)
}

@Test func saltFormWordsAndSpellingDoNotBlockAMatch() {
    #expect(small.match(salt: "Metformin", strength: "500 mg", form: .tablet)?.productId == 7)
    #expect(small.match(salt: "Metformin Hydrochloride", strength: "500mg", form: .tablet)?.productId == 7)
    #expect(small.match(salt: "Amoxicillin + Clavulanic acid", strength: "500 mg + 125 mg", form: .tablet)?.productId == 12)
    #expect(small.match(salt: "Montelukast + Fexofenadine", strength: "10 mg + 120 mg", form: .tablet)?.productId == 13)
}

@Test func releaseTypeMustAgree() {
    #expect(small.match(salt: "Metformin", strength: "500 mg", form: .tablet, variant: .modifiedRelease)?.productId == 6)
    #expect(small.match(salt: "Metformin", strength: "500 mg", form: .tablet, variant: .standard)?.productId == 7)
    // gastro-resistant is how plain pantoprazole is made
    #expect(small.match(salt: "Pantoprazole", strength: "40 mg", form: .tablet)?.productId == 8)
    #expect(small.match(salt: "Pantoprazole", strength: "40 mg", form: .tablet, variant: .modifiedRelease) == nil)
    #expect(small.match(salt: "Azithromycin", strength: "100 mg", form: .tablet) == nil)
    #expect(small.match(salt: "Azithromycin", strength: "100 mg", form: .tablet, variant: .dispersible)?.productId == 15)
}

@Test func perVolumeStrengthMustAgree() {
    #expect(small.match(salt: "Cetirizine", strength: "5 mg/5 ml", form: .liquid)?.productId == 9)
    #expect(small.match(salt: "Cetirizine", strength: "5 mg per 5 ml", form: .liquid)?.productId == 9)
    #expect(small.match(salt: "Cetirizine", strength: "5 mg", form: .liquid) == nil)
    #expect(small.match(salt: "Cetirizine", strength: "5 mg/10 ml", form: .liquid) == nil)
    #expect(small.match(salt: "Sulfamethoxazole + Trimethoprim", strength: "200 mg + 40 mg /5 ml", form: .liquid)?.productId == 17)
}

@Test func unitsAreConvertedButNeverMixed() {
    #expect(small.match(salt: "Ceftriaxone", strength: "1 g", form: .injection)?.productId == 16)
    #expect(small.match(salt: "Ceftriaxone", strength: "1000 mg", form: .injection)?.productId == 16)
    #expect(small.match(salt: "Ceftriaxone", strength: "1 gm", form: .injection)?.productId == 16)
    #expect(small.match(salt: "Clotrimazole", strength: "1%", form: .topical)?.productId == 11)
    #expect(small.match(salt: "Clotrimazole", strength: "1 mg", form: .topical) == nil)     // % is not mg
    #expect(small.match(salt: "Atorvastatin + Ezetimibe", strength: "20 + 10", form: .tablet)?.productId == 18)
}

@Test func gargleAndWeightVolumeStrengths() {
    #expect(small.match(salt: "Povidone Iodine", strength: "2% w/v", form: .gargle)?.mrpPaise == 3750)
    #expect(small.match(salt: "Povidone-Iodine", strength: "2 %", form: .gargle)?.productId == 20)
    #expect(small.match(salt: "Povidone Iodine", strength: "5 %", form: .gargle) == nil)
}

@Test func strengthInBracketsAfterTheName() {
    #expect(small.match(salt: "Fexofenadine", strength: "30 mg/5 ml", form: .liquid)?.mrpPaise == 2813)
    #expect(small.match(salt: "Fexofenadine", strength: "60 mg/5 ml", form: .liquid) == nil)
}

@Test func unpricedAndUnreadableProductsAreNeverMatched() {
    #expect(small.match(salt: "Levetiracetam", strength: "500 mg", form: .tablet) == nil)   // MRP 0
    #expect(small.match(salt: "Pancreatin", strength: "40000", form: .capsule) == nil)     // no unit on the list
    #expect(small.unpricedCount == 1)
    #expect(small.productCount == 21)
}

@Test func rubbishQueriesReturnNothing() {
    #expect(small.match(salt: "", strength: "40 mg", form: .tablet) == nil)
    #expect(small.match(salt: "Telmisartan", strength: "", form: .tablet) == nil)
    #expect(small.match(salt: "Telmisartan", strength: "forty", form: .tablet) == nil)
    #expect(small.match(salt: "Telmisartan", strength: "0 mg", form: .tablet) == nil)
}

@Test func matchCarriesSourceAndDate() throws {
    let m = try #require(small.match(salt: "Telmisartan", strength: "40", form: .tablet))
    #expect(m.source.kind == .mrp)
    #expect(m.source.datedLabel == "MRP, seen 23 Oct")
    #expect(m.sourceName == "Jan Aushadhi official product list")
}

// MARK: - the real saved list

private let repoRoot: URL = {
    // .../engine/ParchiCore/Tests/ParchiCoreTests/JanAushadhiTests.swift -> repo root
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<5 { url.deleteLastPathComponent() }
    return url
}()

private let savedList = repoRoot.appendingPathComponent("docs/research/evidence/janaushadhi_products_2026-10-23.json")

@Test func realListLoadsAndMostPricedRowsAreMatchable() throws {
    let data = try Data(contentsOf: savedList)
    let products = try JanAushadhiIndex.products(fromJSON: data)
    let index = JanAushadhiIndex(products: products)
    let priced = index.productCount - index.unpricedCount
    #expect(products.count == 2439)
    #expect(index.unpricedCount == 343)
    #expect(priced == 2096)
    print("JA real list: rows \(index.productCount), unpriced \(index.unpricedCount), priced \(priced), matchable \(index.matchableCount)")
    #expect(Double(index.matchableCount) / Double(priced) > 0.5)
}

@Test func realListKnownProducts() throws {
    let index = JanAushadhiIndex(products: try JanAushadhiIndex.products(fromJSON: Data(contentsOf: savedList)))
    // From the saved official list (names and MRPs as printed there).
    #expect(index.match(salt: "Paracetamol", strength: "650 mg", form: .tablet)?.mrpPaise == 1547)
    #expect(index.match(salt: "Metformin", strength: "500 mg", form: .tablet)?.productName == "Metformin Hydrochloride Tablets IP 500mg")
    #expect(index.match(salt: "Metformin", strength: "500 mg", form: .tablet)?.mrpPaise == 681)
    #expect(index.match(salt: "Escitalopram", strength: "5 mg", form: .tablet)?.mrpPaise == 750)
    #expect(index.match(salt: "Aceclofenac + Paracetamol", strength: "100 mg + 325 mg", form: .tablet)?.mrpPaise == 1032)
    #expect(index.match(salt: "Paracetamol", strength: "123 mg", form: .tablet) == nil)
}
