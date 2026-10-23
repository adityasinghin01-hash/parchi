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
 "salts":["Telmisartan (40mg)","Metformin (500mg)","Amoxycillin (500mg) + Clavulanic Acid (125mg)","Paracetamol (125mg/5ml)","Paracetamol (650mg)","Pantoprazole (40mg)","Glimepiride (2mg) + Metformin (500mg)","Glimepiride (2mg) + Metformin (850mg)","Follitropin (75IU)","Alprazolam (0.5mg)","Thyroxine (50mcg)","Paracetamol (325mg) + Tramadol (37.5mg)","Alprazolam (0.25mg)"],
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
  "NOSALT":"10,100,0,4,0,1;10,200,0,4,0,2",
  "GLYCOMETGP":"2/500,17075,0,5,7;2/850,19350,0,5,8",
  "GONALF":"75,208967,4,20,9",
  "AARAM":"0.5,3300,3,4,10",
  "ALPRAX":"0.25,2000,0,4,13;0.5,2500,0,4,10",
  "THYRO":"50,20000,0,4,11",
  "NUNIT":"10,100,0,4",
  "CAPBRAND":"40,5000,0,8,6",
  "SYPBRAND":"100,5000,2,12,4",
  "OINTBRAND":"15,5000,2,28,6",
  "CALPOLT":"325,1500,0,4,12"
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
    JAProduct(productId: 10, genericName: "Alprazolam Tablets IP 0.5 mg", unitSize: "10's", mrpRupees: 7.94),
    JAProduct(productId: 11, genericName: "Alprazolam Tablets IP 0.25 mg", unitSize: "10's", mrpRupees: 6),
    JAProduct(productId: 12, genericName: "Paracetamol and Tramadol Tablets 325 mg + 37.5 mg", unitSize: "10's", mrpRupees: 9),
    JAProduct(productId: 13, genericName: "Pantoprazole Gastro Resistant Capsules IP 40 mg", unitSize: "10's", mrpRupees: 9),
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

@Test func unreadablePackSizeGivesNoPriceAndSaysWhy() throws {
    // K17 item 5: "Gonal-F 75" qty 3 used to be priced as one vial (an under-count). Now: no price, plan blocked honestly.
    #expect(tiny.match(name: "Oddpack", strength: "10") == nil)
    #expect(tiny.lookup(name: "Oddpack", strength: "10") == .miss(.packSizeUnclear))
    #expect(CatalogueMiss.packSizeUnclear.reason == "pack size unclear")
    #expect(tiny.lookup(name: "Nosuchbrand", strength: "10") == .miss(.notFound))
    // a plain count the parser can read still prices
    #expect(tiny.lookup(name: "Dolo", strength: "650").match != nil)
    // the real Gonal-F, the review's input: not priced (the unit check and the pack check each refuse it)
    #expect(tiny.match(name: "Gonal-F", strength: "75") == nil)
    #expect(tiny.match(name: "Gonal-F", strength: "75 IU") == nil)       // IU matches the unit, then the unreadable pack label stops it
    #expect(tiny.lookup(name: "Gonal-F", strength: "75 IU") == .miss(.packSizeUnclear))
}

// MARK: - combination strengths, units, written forms (K17)

@Test func combinationStrengthsAreMatchedExactly() throws {
    let a = try #require(tiny.match(name: "Glycomet-GP PR", strength: "2/500"))
    let b = try #require(tiny.match(name: "Glycomet-GP PR", strength: "2/850 mg"))
    #expect(a.entry.mrpPaise == 17075)
    #expect(b.entry.mrpPaise == 19350)
    #expect(tiny.match(name: "Glycomet-GP PR", strength: "2/700") == nil)
    #expect(tiny.match(name: "Glycomet-GP PR", strength: "2") == nil)         // a half-written combination is not guessed
    #expect(tiny.match(name: "Glycomet-GP PR", strength: "500") == nil)
    #expect(tiny.match(name: "Glycomet-GP PR", strength: nil) == nil)
    #expect(WrittenStrength("2/500").number == "2/500")
    #expect(WrittenStrength("125mg/5ml").number == "125")
    #expect(WrittenStrength("125mg/5ml").unit == "mg")
}

@Test func unitsMustAgree() throws {
    #expect(tiny.match(name: "Dolo", strength: "650 mcg") == nil)              // review item 4
    #expect(tiny.match(name: "Dolo", strength: "650mcg") == nil)
    #expect(tiny.match(name: "Dolo", strength: "650 µg") == nil)
    #expect(tiny.match(name: "Dolo", strength: "650 g") == nil)
    #expect(tiny.match(name: "Dolo", strength: "650 iu") == nil)
    #expect(tiny.match(name: "Dolo", strength: "650 %") == nil)
    #expect(tiny.match(name: "Dolo", strength: "650 furlongs") == nil)         // an unknown unit never matches
    #expect(tiny.match(name: "Dolo", strength: "650 mg") != nil)
    #expect(tiny.match(name: "Dolo", strength: "650MG") != nil)
    #expect(tiny.match(name: "Dolo", strength: "650") != nil)                  // no unit written, entry is mg: fine
    #expect(tiny.match(name: "Dolo", strength: "650 tablets") != nil)
    // entry in mcg: the unit must be written and be mcg (or an alias)
    #expect(tiny.match(name: "Thyro", strength: "50 mcg") != nil)
    #expect(tiny.match(name: "Thyro", strength: "50 µg") != nil)
    #expect(tiny.match(name: "Thyro", strength: "50 μg") != nil)
    #expect(tiny.match(name: "Thyro", strength: "50 micrograms") != nil)
    #expect(tiny.match(name: "Thyro", strength: "50") == nil)                  // missing unit, entry is not mg
    #expect(tiny.match(name: "Thyro", strength: "50 mg") == nil)
    // entry with an unknown unit (no salt): mg or nothing written
    #expect(tiny.match(name: "Nunit", strength: "10") != nil)
    #expect(tiny.match(name: "Nunit", strength: "10 mg") != nil)
    #expect(tiny.match(name: "Nunit", strength: "10 mcg") == nil)
    // entry unit from the composition
    #expect(try #require(tiny.match(name: "Thyro", strength: "50 mcg")).entry.unit == "mcg")
    #expect(try #require(tiny.match(name: "Glycomet-GP PR", strength: "2/500")).entry.unit == "mg")
    #expect(try #require(tiny.match(name: "Dolo", strength: "650")).entry.unit == "mg")
    #expect(try #require(tiny.match(name: "Dolo Syrup", strength: "125 mg")).entry.unit == "mg")
}

@Test func writtenAbbreviationsStateTheForm() throws {
    // review item 6: "Pan cap 40" is a capsule: no tablet price, no tablet Jan Aushadhi match
    #expect(tiny.match(name: "Pan cap", strength: "40") == nil)
    #expect(tiny.match(name: "Pan Cap.", strength: "40") == nil)
    #expect(tiny.match(name: "Pan caps", strength: "40") == nil)
    #expect(tiny.match(name: "Pan capsule", strength: "40") == nil)
    #expect(tiny.match(name: "Pan tab", strength: "40")?.entry.form == .tablet)
    #expect(tiny.match(name: "Pan inj", strength: "40")?.entry.form == .injection)
    #expect(tiny.match(name: "Pan", strength: "40")?.entry.form == .tablet)
    #expect(tiny.match(name: "Capbrand cap", strength: "40")?.entry.form == .capsule)
    #expect(tiny.match(name: "Capbrand tab", strength: "40") == nil)
    #expect(tiny.match(name: "Sypbrand syp", strength: "100")?.entry.form == .liquid)
    #expect(tiny.match(name: "Sypbrand susp", strength: "100")?.entry.form == .liquid)
    #expect(tiny.match(name: "Sypbrand tab", strength: "100") == nil)
    #expect(tiny.match(name: "Ointbrand oint", strength: "15")?.entry.form == .topical)
    #expect(tiny.match(name: "Ointbrand cap", strength: "15") == nil)
    // the abbreviation is not an extra word that would make a different medicine
    #expect(CatalogueMRPIndex.extraWords(afterBrandIn: "Pan cap 40") == "")
    #expect(CatalogueMRPIndex.extraWords(afterBrandIn: "Calpol syp 125") == "")
    #expect(CatalogueMRPIndex.extraWords(afterBrandIn: "Soframycin oint") == "")
    #expect(CatalogueMRPIndex.extraWords(afterBrandIn: "Pan tabs 40") == "")
    // and a Pan cap line gets no Jan Aushadhi suggestion either (there is no match to look one up for)
    #expect(tiny.match(name: "Pan cap", strength: "40").flatMap { tinyJA.equivalent(for: $0, quantity: 15) } == nil)
}

// MARK: - quantities (K17 item 7)

@Test func absurdQuantitiesGetNoPriceAndNeverTrap() throws {
    let big = [Int.max, 50_000_000_000_000_000, 10_001, Int.max - 1]
    for q in big {
        #expect(tiny.match(name: "Dolo", strength: "650", quantity: q) == nil)
        #expect(tiny.lookup(name: "Dolo", strength: "650", quantity: q) == .miss(.quantityTooLarge))
        let m = try #require(tiny.match(name: "Dolo", strength: "650"))
        #expect(m.pricedLine(quantity: q) == nil)
        #expect(tinyJA.equivalent(for: try #require(tiny.match(name: "Telma", strength: "40")), quantity: q) == nil)
        // the old entry points no longer trap either
        let clamped = m.linePrice(quantity: q)
        #expect(clamped.packs == 667)                     // 10,000 / 15, rounded up
        #expect(clamped.totalPaise == 667 * 3427)
        #expect(PackSize.packsNeeded(quantity: q, unitsPerPack: 15) > 0)
    }
    #expect(PackSize.packsNeeded(quantity: Int.max, unitsPerPack: 1) == Int.max)
    #expect(PackSize.packsNeeded(quantity: Int.max, unitsPerPack: 2) == Int.max / 2 + 1)
    #expect(PackSize.packsNeeded(quantity: Int.min, unitsPerPack: 10) == 1)
    #expect(PackSize.packsNeeded(quantity: 10_000, unitsPerPack: 10) == 1000)
    // the edge itself is priced
    let m = try #require(tiny.match(name: "Dolo", strength: "650", quantity: 10_000))
    #expect(m.pricedLine(quantity: 10_000)?.packs == 667)
    #expect(m.pricedLine(quantity: 15) == m.linePrice(quantity: 15))
    #expect(tiny.match(name: "Dolo", strength: "650", quantity: 0) != nil)
    #expect(tiny.match(name: "Dolo", strength: "650", quantity: -5) != nil)
}

@Test func anAbsurdMRPInTheFileIsRejectedNotMultiplied() throws {
    let json = """
    {"forms":["","tablet"],"variants":["","modified"],"packs":["strip of 10 tablets"],"salts":[],"extras":[],
     "brands":{"HUGE":"10,9223372036854775807,0,4","FINE":"10,1000,0,4"}}
    """
    let index = try CatalogueMRPIndex(json: Data(json.utf8))
    #expect(index.match(name: "Huge", strength: "10") == nil)
    #expect(index.match(name: "Fine", strength: "10") != nil)
}

// MARK: - H1 / X from the matched product's salts (K17 item 6)

private let h1x = ScheduleCheck(entries: [
    ScheduleEntry(schedule: .h1, salt: "Alprazolam"),
    ScheduleEntry(schedule: .h1, salt: "Tramadol"),
    ScheduleEntry(schedule: .x, salt: "Ketamine hydrochloride"),
])

@Test func aBrandMissingFromTheTableIsStillCaughtByItsSalts() throws {
    // The table passed here has no brands at all: only the matched product's own salts can catch it.
    #expect(h1x.brandCount == 0)
    let aaram = try #require(tiny.match(name: "Aaram", strength: "0.5"))
    #expect(aaram.schedule(using: h1x) == .h1)
    #expect(tinyJA.equivalent(for: aaram, quantity: 10) != nil)                            // without the check there would be a suggestion
    #expect(tinyJA.equivalent(for: aaram, quantity: 10, schedule: h1x) == nil)             // with it there is none
    let alprax = try #require(tiny.match(name: "Alprax", strength: "0.25"))
    #expect(alprax.schedule(using: h1x) == .h1)
    #expect(tinyJA.equivalent(for: alprax, quantity: 10, schedule: h1x) == nil)
    let alprax05 = try #require(tiny.match(name: "Alprax", strength: "0.5"))
    #expect(alprax05.schedule(using: h1x) == .h1)
    // a combination with one scheduled salt
    let calpolT = try #require(tiny.match(name: "Calpolt", strength: "325"))
    #expect(calpolT.schedule(using: h1x) == .h1)
    #expect(tinyJA.equivalent(for: calpolT, quantity: 10, schedule: h1x) == nil)
}

@Test func negativeControlNoScheduleNoChange() throws {
    let dolo = try #require(tiny.match(name: "Dolo", strength: "650"))
    #expect(dolo.schedule(using: h1x) == nil)
    #expect(tinyJA.equivalent(for: dolo, quantity: 15, schedule: h1x)?.match.mrpPaise == 1547)
    #expect(tinyJA.equivalent(for: dolo, quantity: 15, schedule: h1x) == tinyJA.equivalent(for: dolo, quantity: 15))
    let nosalt = try #require(tiny.match(name: "Nunit", strength: "10"))      // no salts known: nothing to check, nothing invented
    #expect(nosalt.schedule(using: h1x) == nil)
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

@Test func realReviewInputsGetNoWrongPrice() throws {
    // K17 items 1, 4, 5, 6: the exact failing inputs of the Codex review, against the bundled data
    // The bundled list has "Glycomet-GP 2 Tablet PR" (2 mg + 500 mg, Rs 170.75 for 15) and "Glycomet-GP 2/850 Tablet SR"
    // (Rs 96.75 for 10). They used to share the key "2": 15 tablets of "2/500" were priced as two 2/850 strips, Rs 193.50.
    #expect(realMRP.match(name: "Glycomet-GP PR", strength: "2/500") == nil)       // no product is called 2/500: no price
    #expect(realMRP.match(name: "Glycomet-GP", strength: "2/500", quantity: 15) == nil)
    let g850 = try #require(realMRP.match(name: "Glycomet-GP", strength: "2/850"))
    #expect(g850.entry.strength == "2/850")
    #expect(g850.entry.salt == nil || g850.entry.salt?.contains("850mg") == true)
    #expect(g850.entry.mrpPaise == 9675)
    let g2 = try #require(realMRP.match(name: "Glycomet-GP PR", strength: "2"))
    #expect(g2.entry.strength == "2")
    #expect(g2.entry.mrpPaise == 17075)                                             // the 2 mg + 500 mg product
    #expect(g2.entry.salt?.contains("500mg") == true)
    #expect(g2.linePrice(quantity: 15).totalPaise == 17075)
    #expect(g2.linePrice(quantity: 15).totalPaise != 19350)
    #expect(realMRP.match(name: "Dolo", strength: "650 mcg") == nil)
    #expect(realMRP.match(name: "Dolo", strength: "650 mg") != nil)
    #expect(realMRP.match(name: "Gonal-F", strength: "75", quantity: 3) == nil)
    #expect(realMRP.match(name: "Gonal-F", strength: "75 IU", quantity: 3)?.pricedLine(quantity: 3) == nil
            || realMRP.match(name: "Gonal-F", strength: "75 IU", quantity: 3) == nil)
    #expect(realMRP.match(name: "Pan cap", strength: "40") == nil)
    #expect(realMRP.match(name: "Dolo", strength: "650", quantity: Int.max) == nil)
    #expect(realMRP.match(name: "Dolo", strength: "650", quantity: 50_000_000_000_000_000) == nil)
    let dolo = try #require(realMRP.match(name: "Dolo", strength: "650"))
    #expect(dolo.linePrice(quantity: Int.max).packs > 0)
    #expect(dolo.pricedLine(quantity: Int.max) == nil)
}

private let realSchedule: ScheduleCheck = {
    // swiftlint:disable:next force_try
    try! ScheduleCheck(
        scheduleJSON: Data(contentsOf: catalogueRepoRoot.appendingPathComponent("engine/catalogue/schedule_h1_x.json")),
        brandJSON: Data(contentsOf: catalogueRepoRoot.appendingPathComponent("engine/catalogue/brand_schedule.json")))
}()

private let realScheduleSaltsOnly: ScheduleCheck = {
    // swiftlint:disable:next force_try
    try! ScheduleCheck(scheduleJSON: Data(contentsOf: catalogueRepoRoot.appendingPathComponent("engine/catalogue/schedule_h1_x.json")))
}()

@Test func realAlprazolamBrandsAreH1ByTableAndBySalts() throws {
    for (brand, strength) in [("Aaram", "0.5"), ("Alprax", "0.5"), ("Alprax", "0.25"), ("Alzolam", "0.5")] {
        #expect(realSchedule.isInPersonOnly(brand: brand) == .h1, "\(brand) must be in brand_schedule.json")
        if let match = realMRP.match(name: brand, strength: strength) {
            // the engine check alone, with a table that lists no brand at all
            #expect(match.schedule(using: realScheduleSaltsOnly) == .h1, "\(brand) \(strength)")
            #expect(realJA.equivalent(for: match, quantity: 10, schedule: realScheduleSaltsOnly) == nil)
        }
    }
    let aaram = try #require(realMRP.match(name: "Aaram", strength: "0.5"))
    #expect(aaram.entry.salt?.lowercased().contains("alprazolam") == true)
    #expect(aaram.schedule(using: realScheduleSaltsOnly) == .h1)
    #expect(realJA.equivalent(for: aaram, quantity: 10, schedule: realScheduleSaltsOnly) == nil)
    // negative control: the six demo medicines are not scheduled by table or by salts
    for (name, strength) in [("Dolo", "650"), ("Pan", "40"), ("Telma", "40"), ("Glycomet SR", "500"), ("Azithral", "500")] {
        #expect(realSchedule.isInPersonOnly(brand: name) == nil, "\(name)")
        let m = try #require(realMRP.match(name: name, strength: strength))
        #expect(m.schedule(using: realSchedule) == nil, "\(name)")
    }
    #expect(realSchedule.isInPersonOnly(brand: "Montair LC") == nil)
    #expect(realSchedule.brandCount > 5000)      // the table now reads the short_composition columns too (was 253)
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

/// Item 11 of the review, engine part only: how long the two bundled files take to load and the first lookup to run.
/// Printed, not asserted (it depends on the machine; this is a debug build on a Mac, not a phone).
@Test func measureColdLoadOfTheBundledFiles() throws {
    let clock = ContinuousClock()
    var mrp: CatalogueMRPIndex?
    let mrpTime = try clock.measure {
        mrp = try CatalogueMRPIndex(json: Data(contentsOf: catalogueRepoRoot.appendingPathComponent("engine/catalogue/brand_mrp.json")))
    }
    var ja: JanAushadhiIndex?
    let jaTime = try clock.measure {
        ja = JanAushadhiIndex(products: try JanAushadhiIndex.products(fromJSON: Data(contentsOf: catalogueRepoRoot.appendingPathComponent("engine/catalogue/janaushadhi_products.json"))))
    }
    var found: CatalogueMatch?
    let firstLookup = clock.measure { found = mrp?.match(name: "Dolo", strength: "650") }
    let firstJA = clock.measure { _ = found.flatMap { ja?.equivalent(for: $0, quantity: 15) } }
    print("COLD LOAD brand_mrp.json \(mrpTime), janaushadhi \(jaTime), first lookup \(firstLookup), first JA \(firstJA)")
    #expect(found != nil)
}
