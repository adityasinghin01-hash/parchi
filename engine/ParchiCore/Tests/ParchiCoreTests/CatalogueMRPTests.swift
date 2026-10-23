import Foundation
import Testing
@testable import ParchiCore

// MARK: - pack size

@Test func catalogueStripPacksCountTheirUnits() {
    #expect(PackSize.unitsPerPack(label: "strip of 10 tablets") == 10)
    #expect(PackSize.unitsPerPack(label: "strip of 15 Tablets") == 15)
    #expect(PackSize.unitsPerPack(label: "strip of 10 tablet sr") == 10)
    #expect(PackSize.unitsPerPack(label: "strip of 10 soft gelatin capsules") == 10)
    #expect(PackSize.unitsPerPack(label: "  Strip   of 6  tablets ") == 6)
}

@Test func bottlesTubesAndVialsAreOneUnit() {
    #expect(PackSize.unitsPerPack(label: "bottle of 100 ml Syrup") == 1)
    #expect(PackSize.unitsPerPack(label: "tube of 15 gm Cream") == 1)
    #expect(PackSize.unitsPerPack(label: "vial of 1 Injection") == 1)
    #expect(PackSize.unitsPerPack(label: "bottle of 5 ml Eye Drop") == 1)
}

@Test func unreadablePackLabelsGiveNil() {
    #expect(PackSize.unitsPerPack(label: "") == nil)
    #expect(PackSize.unitsPerPack(label: "strip") == nil)
    #expect(PackSize.unitsPerPack(label: "vial of 5.5 µcg Powder for Injection") == nil)
    #expect(PackSize.unitsPerPack(label: "strip of 0 tablets") == nil)
}

@Test func janAushadhiPackSizes() {
    #expect(PackSize.unitsPerPack(janAushadhiUnitSize: "10's") == 10)
    #expect(PackSize.unitsPerPack(janAushadhiUnitSize: "15's") == 15)
    #expect(PackSize.unitsPerPack(janAushadhiUnitSize: "10s") == 10)
    #expect(PackSize.unitsPerPack(janAushadhiUnitSize: "30's Bottle") == 30)
    #expect(PackSize.unitsPerPack(janAushadhiUnitSize: "100 ml") == 1)
    #expect(PackSize.unitsPerPack(janAushadhiUnitSize: "30g") == 1)
    #expect(PackSize.unitsPerPack(janAushadhiUnitSize: "5ml Drops") == 1)
    #expect(PackSize.unitsPerPack(janAushadhiUnitSize: "Vial") == 1)
    #expect(PackSize.unitsPerPack(janAushadhiUnitSize: "Pair in Mono-Pack") == nil)
}

@Test func packsNeededIsACeilingAndAtLeastOne() {
    #expect(PackSize.packsNeeded(quantity: 30, unitsPerPack: 30) == 1)
    #expect(PackSize.packsNeeded(quantity: 31, unitsPerPack: 30) == 2)
    #expect(PackSize.packsNeeded(quantity: 15, unitsPerPack: 10) == 2)
    #expect(PackSize.packsNeeded(quantity: 5, unitsPerPack: 10) == 1)
    #expect(PackSize.packsNeeded(quantity: 0, unitsPerPack: 10) == 1)
    #expect(PackSize.packsNeeded(quantity: 45, unitsPerPack: nil) == 1)       // unknown pack: one pack
    #expect(PackSize.packsNeeded(quantity: 45, unitsPerPack: 0) == 1)
}

// MARK: - a small index in the real file format

private let tinyJSON = """
{"forms":["","tablet","capsule","liquid","drops","injection","inhaler","topical","powder","gargle"],
 "variants":["","modified","dispersible","unclear"],
 "packs":["strip of 10 tablets","strip of 30 tablets","bottle of 100 ml Syrup","strip of 15 tablets","an odd pack"],
 "salts":["Telmisartan (40mg)","Metformin (500mg)","Amoxycillin (500mg) + Clavulanic Acid (125mg)","Paracetamol (125mg/5ml)","Paracetamol (650mg)","Pantoprazole (40mg)"],
 "extras":["H","AM"],
 "brands":{
  "TELMA":"40,24595,1,4,1;40,15000,0,4,0,1;80,18732,3,4",
  "GLYCOMET":"500,4771,0,5,2;1,6804,0,5",
  "DOLO":"650,3427,3,4,5;125,5000,2,12,4;1000,26800,0,20",
  "AUGMENTIN":"625,22342,0,4,3",
  "PAN":"40,15500,0,4,6;40,7000,0,20,6",
  "ODDPACK":"10,1000,4,4,1",
  "MONTAIRLC":",33600,3,4",
  "DVCOR":"500,1000,0,7,1",
  "SYNCRO":"20,900,0,4,1;20,1500,0,8",
  "DUOTEST":"625,300,0,4,3,1;625,200,3,4,3,2",
  "MIXED":"10,100,0,4,1,1;10,200,0,4,2,2",
  "NOSALT":"10,100,0,4,0,1;10,200,0,4,0,2"
 }}
"""

private let tiny = try! CatalogueMRPIndex(json: Data(tinyJSON.utf8))

private let tinyJA = JanAushadhiIndex(products: [
    JAProduct(productId: 1, genericName: "Telmisartan Tablets IP 40 mg", unitSize: "10's", mrpRupees: 9.5),
    JAProduct(productId: 2, genericName: "Metformin Hydrochloride Tablets IP 500mg", unitSize: "10's", mrpRupees: 6.81),
    JAProduct(productId: 3, genericName: "Metformin Hydrochloride Prolonged Release Tablets IP 500 mg", unitSize: "10's", mrpRupees: 7),
    JAProduct(productId: 4, genericName: "Paracetamol Tablets IP 650 mg", unitSize: "15's", mrpRupees: 15.47),
    JAProduct(productId: 5, genericName: "Amoxycillin 500mg and Potassium Clavulanate 125mg Tablets IP", unitSize: "10's", mrpRupees: 60),
    JAProduct(productId: 6, genericName: "Paracetamol Oral Suspension IP 125 mg per 5 ml", unitSize: "60 ml", mrpRupees: 21),
    JAProduct(productId: 7, genericName: "Pantoprazole Gastro Resistant Tablets IP 40 mg", unitSize: "10's", mrpRupees: 9.1),
    JAProduct(productId: 8, genericName: "Pantoprazole Injection IP 40 mg", unitSize: "Vial", mrpRupees: 30),
    JAProduct(productId: 9, genericName: "Telmisartan Tablets IP 40 mg", unitSize: "30's", mrpRupees: 20),
])

@Test func exactBrandAndStrengthGetsTheMRPAndPack() throws {
    let m = try #require(tiny.match(name: "Telma", strength: "40"))
    #expect(m.entry.mrpPaise == 24595)
    #expect(m.entry.packLabel == "strip of 30 tablets")
    #expect(m.entry.salt == "Telmisartan (40mg)")
    #expect(m.entry.form == .tablet)
    #expect(m.entry.release == .plain)
    #expect(!m.releaseAssumed && !m.formAmbiguous)
}

@Test func strengthWrittenWithUnitOrSpaceStillMatches() throws {
    #expect(try #require(tiny.match(name: "telma", strength: " 40 mg ")).entry.mrpPaise == 24595)
    #expect(try #require(tiny.match(name: "TELMA 80", strength: "80")).entry.mrpPaise == 18732)
}

@Test func neverADifferentStrengthOrAnUnknownBrand() {
    #expect(tiny.match(name: "Telma", strength: "20") == nil)
    #expect(tiny.match(name: "Telma", strength: "400") == nil)
    #expect(tiny.match(name: "Telma", strength: nil) == nil)          // brand has numbered products: a strength-less Telma is not guessed
    #expect(tiny.match(name: "Nosuchbrand", strength: "40") == nil)
    #expect(tiny.match(name: "Te", strength: "40") == nil)
}

@Test func extraWordsMakeADifferentMedicine() throws {
    let plain = try #require(tiny.match(name: "Telma", strength: "40"))
    let h = try #require(tiny.match(name: "Telma H", strength: "40"))
    #expect(plain.entry.extras == "")
    #expect(h.entry.extras == "H")
    #expect(h.entry.mrpPaise == 15000)
    #expect(h.entry.salt == nil)
    #expect(tiny.match(name: "Telma AM", strength: "40") == nil)      // no such product: no price rather than another medicine's
    #expect(tiny.match(name: "Telma H", strength: "80") == nil)
}

@Test func plainBrandMayTakeAMarketingWordWhenEveryProductHasTheSameSalt() throws {
    let m = try #require(tiny.match(name: "Duotest", strength: "625"))
    #expect(m.extrasAssumed)
    #expect(m.entry.mrpPaise == 200)                    // cheapest of the two
    #expect(m.entry.salt == "Amoxycillin (500mg) + Clavulanic Acid (125mg)")
    #expect(tinyJA.equivalent(for: m, quantity: 10)?.match.productId == 5)   // same salt for every product: Jan Aushadhi may be looked up
    #expect(tiny.match(name: "Duotest A", strength: "625") == nil)           // a written extra word must be the same
    #expect(tiny.match(name: "Mixed", strength: "10") == nil)                // the products at this strength differ in salt: not guessed
    #expect(tiny.match(name: "Nosalt", strength: "10") == nil)               // salt unknown: not guessed
    #expect(try #require(tiny.match(name: "Telma", strength: "40")).extrasAssumed == false)
}

@Test func wholeNameIsTriedBeforeFirstWord() throws {
    let m = try #require(tiny.match(name: "Montair LC", strength: nil))   // catalogue brand key MONTAIRLC, as in the app's check
    #expect(m.entry.mrpPaise == 33600)
    #expect(m.entry.strength == "")
}

@Test func statedReleaseTypeMustExist() throws {
    let sr = try #require(tiny.match(name: "Glycomet SR", strength: "500"))
    #expect(sr.entry.release == .modified)
    #expect(!sr.releaseAssumed)
    #expect(tiny.match(name: "Telma SR", strength: "40") == nil)      // the parchi says SR and no SR exists
}

@Test func plainNameWithOnlyAnSRProductPricesButIsMarkedAssumed() throws {
    let m = try #require(tiny.match(name: "Glycomet", strength: "500"))
    #expect(m.entry.release == .modified)
    #expect(m.releaseAssumed)
    #expect(!m.allowsJanAushadhi)
    #expect(tinyJA.equivalent(for: m, quantity: 20) == nil)
}

@Test func statedFormSelectsTheEntryOfThatForm() throws {
    #expect(try #require(tiny.match(name: "Pan Injection", strength: "40")).entry.mrpPaise == 7000)
    #expect(try #require(tiny.match(name: "Pan Tab", strength: "40")).entry.mrpPaise == 15500)
    #expect(tiny.match(name: "Pan Syrup", strength: "40") == nil)
}

@Test func unstatedFormPrefersTabletsOverInjections() throws {
    let m = try #require(tiny.match(name: "Pan", strength: "40"))     // a tablet and an injection exist
    #expect(m.entry.form == .tablet)
    #expect(m.entry.mrpPaise == 15500)
    #expect(!m.formAmbiguous)                                          // the tablet is the usual reading of a bare brand
    #expect(tinyJA.equivalent(for: m, quantity: 15)?.match.productId == 7)
}

@Test func unstatedFormWithTwoOralKindsIsAmbiguousAndGetsNoJanAushadhi() throws {
    let both = try CatalogueMRPIndex(json: Data("""
    {"forms":["","tablet","capsule"],"variants":["","modified","dispersible","unclear"],"packs":["strip of 10 tablets"],
     "salts":["Telmisartan (40mg)"],"extras":[],"brands":{"TWOKIND":"40,1000,0,4,1;40,900,0,8,1"}}
    """.utf8))
    let m = try #require(both.match(name: "Twokind", strength: "40"))
    #expect(m.formAmbiguous)
    #expect(m.entry.mrpPaise == 900)
    #expect(tinyJA.equivalent(for: m, quantity: 10) == nil)
    #expect(try #require(both.match(name: "Twokind Capsule", strength: "40")).formAmbiguous == false)
}

@Test func unclearReleaseCodesAreNeverMatchedToJanAushadhi() throws {
    let m = try #require(tiny.match(name: "Dvcor OD", strength: "500"))
    #expect(m.entry.release == .unclear)
    #expect(m.entry.mrpPaise == 1000)
    #expect(!m.allowsJanAushadhi)
}

@Test func linePriceIsPacksTimesMRP() throws {
    let telma = try #require(tiny.match(name: "Telma", strength: "40"))   // strip of 30
    #expect(telma.linePrice(quantity: 30) == CatalogueLinePrice(totalPaise: 24595, packs: 1, perPackPaise: 24595, packLabel: "strip of 30 tablets", packSizeKnown: true))
    #expect(telma.linePrice(quantity: 45).totalPaise == 49190)
    #expect(telma.linePrice(quantity: 45).packs == 2)
    let dolo = try #require(tiny.match(name: "Dolo", strength: "650"))    // strip of 15
    #expect(dolo.linePrice(quantity: 15).totalPaise == 3427)
    #expect(dolo.linePrice(quantity: 16).totalPaise == 6854)
    let syrup = try #require(tiny.match(name: "Dolo Syrup", strength: "125"))   // bottle: one unit
    #expect(syrup.linePrice(quantity: 1).totalPaise == 5000)
}

@Test func unreadablePackSizePricesOnePackAndSaysSo() throws {
    let m = try #require(tiny.match(name: "Oddpack", strength: "10"))
    let price = m.linePrice(quantity: 60)
    #expect(price.packs == 1)
    #expect(price.totalPaise == 1000)
    #expect(!price.packSizeKnown)
}

// MARK: - Jan Aushadhi equivalent of a catalogue entry

@Test func compositionBecomesSaltAndStrengthStrings() {
    let one = JanAushadhiIndex.query(fromComposition: "Telmisartan (40mg)")
    #expect(one?.salt == "Telmisartan")
    #expect(one?.strength == "40 mg")
    let two = JanAushadhiIndex.query(fromComposition: "Amoxycillin (500mg) + Clavulanic Acid (125mg)")
    #expect(two?.salt == "Amoxycillin + Clavulanic Acid")
    #expect(two?.strength == "500 mg + 125 mg")
    let liquid = JanAushadhiIndex.query(fromComposition: "Paracetamol (125mg/5ml)")
    #expect(liquid?.strength == "125 mg/5 ml")
    let both = JanAushadhiIndex.query(fromComposition: "Levocetirizine (2.5mg/5ml) + Montelukast (4mg/5ml)")
    #expect(both?.strength == "2.5 mg + 4 mg/5 ml")
    #expect(JanAushadhiIndex.query(fromComposition: "Clobetasol (0.05% w/w)")?.strength == "0.05 %")
    #expect(JanAushadhiIndex.query(fromComposition: "Vitamin B6 (Pyridoxine) (10mg)")?.salt == "Vitamin B6 (Pyridoxine)")
}

@Test func unclearCompositionsGiveNoQuery() {
    #expect(JanAushadhiIndex.query(fromComposition: "Loperamide (NA)") == nil)
    #expect(JanAushadhiIndex.query(fromComposition: "Paracetamol (500mg) + Domperidone (10mg/5ml)") == nil)   // different per-volume
    #expect(JanAushadhiIndex.query(fromComposition: "Iron, Folic (100mg)") == nil)                              // a separator inside a name
    #expect(JanAushadhiIndex.query(fromComposition: "") == nil)
}

@Test func equivalentForTelmisartanIsTheSameSaltStrengthAndForm() throws {
    let m = try #require(tiny.match(name: "Telma", strength: "40"))
    let eq = try #require(tinyJA.equivalent(for: m, quantity: 30))
    // two packs on the list: 3 x 10's = Rs 28.50, or one 30's = Rs 20.00: the cheaper cost for 30 tablets wins
    #expect(eq.match.productId == 9)
    #expect(eq.totalPaise == 2000)
    #expect(eq.packs == 1)
    #expect(eq.packSizeKnown)
    #expect(eq.match.source.kind == .mrp)
    let few = try #require(tinyJA.equivalent(for: m, quantity: 10))
    #expect(few.totalPaise == 950)
}

@Test func equivalentNeverCrossesStrengthFormOrReleaseType() throws {
    let sr = try #require(tiny.match(name: "Glycomet SR", strength: "500"))
    #expect(tinyJA.equivalent(for: sr, quantity: 20)?.match.productId == 3)       // modified release -> modified release
    let combo = try #require(tiny.match(name: "Augmentin", strength: "625"))
    #expect(tinyJA.equivalent(for: combo, quantity: 10)?.match.productId == 5)
    let syrup = try #require(tiny.match(name: "Dolo Syrup", strength: "125"))
    #expect(tinyJA.equivalent(for: syrup, quantity: 1)?.match.productId == 6)
    let tablet = try #require(tiny.match(name: "Dolo Tab", strength: "650"))
    #expect(tinyJA.equivalent(for: tablet, quantity: 15)?.match.productId == 4)
    let injection = try #require(tiny.match(name: "Pan Injection", strength: "40"))
    #expect(tinyJA.equivalent(for: injection, quantity: 1)?.match.productId == 8)
    // a product with no salt in the catalogue has no equivalent
    let noSalt = try #require(tiny.match(name: "Telma H", strength: "40"))
    #expect(tinyJA.equivalent(for: noSalt, quantity: 10) == nil)
    // a salt strength the list does not have
    let other = try #require(tiny.match(name: "Syncro", strength: "20"))
    #expect(tinyJA.equivalent(for: other, quantity: 10) == nil)
}

@Test func extraWordsAreReadTheSameWayAsTheBuilder() {
    #expect(CatalogueMRPIndex.extraWords(afterBrandIn: "Telma H 40 Tablet") == "H")
    #expect(CatalogueMRPIndex.extraWords(afterBrandIn: "Montair LC Kid Syrup") == "LC KID")
    #expect(CatalogueMRPIndex.extraWords(afterBrandIn: "Telma 40") == "")
    #expect(CatalogueMRPIndex.extraWords(afterBrandIn: "Glycomet SR 500") == "")
    #expect(CatalogueMRPIndex.extraWords(afterBrandIn: "Pan 40 Injection IV") == "")
    #expect(CatalogueMRPIndex.extraWords(afterBrandIn: "Granac MR 100mg/325mg/250mg Tablet") == "")
}

@Test func releaseWordsAreDetectedLikeTheBuilder() {
    #expect(CatalogueRelease.detect(in: "glycomet 500 sr tablet") == .modified)
    #expect(CatalogueRelease.detect(in: "montair 4mg chewable tablet") == .dispersible)
    #expect(CatalogueRelease.detect(in: "dvcor od 500mg tablet") == .unclear)
    #expect(CatalogueRelease.detect(in: "telma 40 tablet") == .plain)
}

@Test func brokenFilesAreRejected() {
    #expect(throws: (any Error).self) { try CatalogueMRPIndex(json: Data("[]".utf8)) }
    #expect(throws: (any Error).self) { try CatalogueMRPIndex(json: Data("{\"forms\":[]}".utf8)) }
    #expect(throws: (any Error).self) { try CatalogueMRPIndex(json: Data("not json".utf8)) }
}

// MARK: - the real bundled files

private let catalogueRepoRoot: URL = {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<5 { url.deleteLastPathComponent() }
    return url
}()

private let realMRP: CatalogueMRPIndex = {
    // swiftlint:disable:next force_try
    try! CatalogueMRPIndex(json: Data(contentsOf: catalogueRepoRoot.appendingPathComponent("engine/catalogue/brand_mrp.json")))
}()

private let realJA: JanAushadhiIndex = {
    // swiftlint:disable:next force_try
    JanAushadhiIndex(products: try! JanAushadhiIndex.products(fromJSON: Data(contentsOf: catalogueRepoRoot.appendingPathComponent("engine/catalogue/janaushadhi_products.json"))))
}()

@Test func bundledJanAushadhiListIsTheSavedOfficialList() throws {
    let saved = try Data(contentsOf: catalogueRepoRoot.appendingPathComponent("docs/research/evidence/janaushadhi_products_2026-10-23.json"))
    let bundled = try Data(contentsOf: catalogueRepoRoot.appendingPathComponent("engine/catalogue/janaushadhi_products.json"))
    #expect(saved == bundled)
}

@Test func realCatalogueCoversTheAppsBrandKeys() throws {
    let keys = try JSONDecoder().decode([String: [String]].self,
        from: Data(contentsOf: catalogueRepoRoot.appendingPathComponent("engine/catalogue/brand_strengths.json")))
    #expect(realMRP.brandCount > 130_000)
    var missing = 0
    for brand in keys.keys where !realMRP.contains(brand: brand) { missing += 1 }
    print("brand_strengths brands \(keys.count), without any MRP entry \(missing)")
    #expect(missing < 400)     // brands whose only products are discontinued, numberless next to numbered ones, or unpriced
}

@Test func realCommonBrandsGetTheirMRP() throws {
    let dolo = try #require(realMRP.match(name: "Dolo", strength: "650"))
    #expect(dolo.entry.packLabel == "strip of 15 tablets")
    #expect(dolo.entry.mrpPaise == 3427)
    #expect(dolo.entry.salt == "Paracetamol (650mg)")
    #expect(dolo.linePrice(quantity: 15).totalPaise == 3427)
    let telma = try #require(realMRP.match(name: "Telma", strength: "40"))
    #expect(telma.entry.salt == "Telmisartan (40mg)")
    #expect(telma.linePrice(quantity: 30).totalPaise == 24595)
    let azithral = try #require(realMRP.match(name: "Azithral", strength: "500"))
    #expect(azithral.entry.mrpPaise == 13236)
    #expect(azithral.entry.form == .tablet)
    #expect(azithral.entry.packLabel == "strip of 5 tablets")
    let glycomet = try #require(realMRP.match(name: "Glycomet SR", strength: "500"))
    #expect(glycomet.entry.release == .modified)
    #expect(glycomet.entry.salt == "Metformin (500mg)")
}

@Test func realJanAushadhiEquivalents() throws {
    let dolo = try #require(realMRP.match(name: "Dolo", strength: "650"))
    let eq = try #require(realJA.equivalent(for: dolo, quantity: 15))
    #expect(eq.match.mrpPaise == 1547)
    #expect(eq.totalPaise == 1547)
    let telma = try #require(realMRP.match(name: "Telma", strength: "40"))
    let telmaEq = try #require(realJA.equivalent(for: telma, quantity: 30))
    #expect(telmaEq.match.productName.lowercased().contains("telmisartan"))
    let glycomet = try #require(realMRP.match(name: "Glycomet SR", strength: "500"))
    #expect(realJA.equivalent(for: glycomet, quantity: 20)?.match.productName.lowercased().contains("prolonged") == true)
}

@Test func measureCoverageOnDemoMedicinesAndSample() {
    let demo: [(String, String?, Int)] = [("Dolo", "650", 15), ("Pan", "40", 15), ("Telma", "40", 30), ("Glycomet SR", "500", 20),
                                          ("Azithral", "500", 5), ("Montair LC", nil, 15)]
    var demoMRP = 0, demoJA = 0
    for (name, strength, quantity) in demo {
        let m = realMRP.match(name: name, strength: strength)
        if let m { demoMRP += 1; if realJA.equivalent(for: m, quantity: quantity) != nil { demoJA += 1 } }
        print("demo \(name) \(strength ?? "-"): MRP \(m.map { String($0.entry.mrpPaise) } ?? "none") \(m?.entry.packLabel ?? "") salt \(m?.entry.salt ?? "none") JA \(m.flatMap { realJA.equivalent(for: $0, quantity: quantity) }.map { $0.match.productName } ?? "none")")
    }
    var sampleMRP = 0, sampleSalt = 0, sampleJA = 0
    for (name, strength) in catalogueSample200 {
        guard let m = realMRP.match(name: name, strength: strength.isEmpty ? nil : strength) else { continue }
        sampleMRP += 1
        if m.entry.salt != nil { sampleSalt += 1 }
        if realJA.equivalent(for: m, quantity: 10) != nil { sampleJA += 1 }
    }
    print("COVERAGE demo 6: MRP \(demoMRP), JA \(demoJA); sample 200: MRP \(sampleMRP), with salt \(sampleSalt), JA \(sampleJA)")
    #expect(demoMRP >= 5)
    #expect(sampleMRP >= 150)
}
