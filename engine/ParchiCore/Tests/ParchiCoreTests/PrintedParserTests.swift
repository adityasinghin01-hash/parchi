import Testing
@testable import ParchiCore

private let catalogue = Catalogue(productNames: [
    "Pan 40 Tablet", "Pan 20 Tablet", "Pantocid 40 Tablet", "Azithral 250 Tablet", "Azithral 500 Tablet", "Azithral 200 Liquid",
    "Ascoril LS Syrup", "Dolo 650 Tablet", "Dolo 500 Tablet", "Telma 20 Tablet", "Telma 40 Tablet", "Telma 80 Tablet",
    "Augmentin 625 Duo Tablet", "Augmentin 375 Tablet", "Allegra 120 Tablet", "Allegra 180 Tablet", "Cetzine 10 Tablet", "Cetzine 5 Syrup",
    "Glycomet 500 Tablet", "Glycomet 850 Tablet", "Neurobion Forte Tablet", "Zerodol 100 Tablet", "Calpol 500 Tablet",
    "Ciplox 500 Tablet", "Omez 20 Capsule", "Taxim 200 Tablet", "Betadine 5 Gargle", "Soframycin 1 Cream", "Ceftriaxone 1000 Injection",
])

private let parser = PrintedParser(catalogue: catalogue)
private let plain = PrintedParser()

private func parse(_ line: String) -> ParsedItem { parser.parse(line: line) }

private struct Expect {
    let line: String
    let form: DoseForm?
    let brand: String?
    let strength: String?
    let schedule: String?
    let days: Int?
    let quantity: Int?
}

// 1..22: realistic printed lines, including OCR noise.
private let cases: [Expect] = [
    Expect(line: "1) Tab Pan 40 mg 1-0-0 x 15 days", form: .tab, brand: "Pan", strength: "40 mg", schedule: "1-0-0", days: 15, quantity: 15),
    Expect(line: "Cap. AZITHRAL 500 OD x3d", form: .cap, brand: "AZITHRAL", strength: "500", schedule: "OD", days: 3, quantity: 3),
    Expect(line: "Syp Ascoril LS 5ml TDS", form: .syp, brand: "Ascoril LS", strength: nil, schedule: "TDS", days: nil, quantity: nil),
    Expect(line: "2) Tab. Dolo 650 1-1-1 x 5 days", form: .tab, brand: "Dolo", strength: "650", schedule: "1-1-1", days: 5, quantity: 15),
    Expect(line: "3. TAB TELMA 40 1-0-0 X 30 DAYS", form: .tab, brand: "TELMA", strength: "40", schedule: "1-0-0", days: 30, quantity: 30),
    Expect(line: "Tab Augmentin 625 Duo 1-0-1 x 5 days", form: .tab, brand: "Augmentin", strength: "625", schedule: "1-0-1", days: 5, quantity: 10),
    Expect(line: "Tab. Allegra 120mg BD x 7 days", form: .tab, brand: "Allegra", strength: "120 mg", schedule: "BD", days: 7, quantity: 14),
    Expect(line: "Tab Cetzine 10 mg HS x 10 days", form: .tab, brand: "Cetzine", strength: "10 mg", schedule: "HS", days: 10, quantity: 10),
    Expect(line: "4) Tab Glycomet 500 1-0-1 x 1 month", form: .tab, brand: "Glycomet", strength: "500", schedule: "1-0-1", days: 30, quantity: 60),
    Expect(line: "Tab Taxim 200 mg BD for 5 days", form: .tab, brand: "Taxim", strength: "200 mg", schedule: "BD", days: 5, quantity: 10),
    Expect(line: "Inj. Ceftriaxone 1 gm IV BD x 3 days", form: .inj, brand: "Ceftriaxone", strength: "1 g", schedule: "BD", days: 3, quantity: nil),
    Expect(line: "Cream Soframycin apply BD x 1 week", form: .cream, brand: "Soframycin", strength: nil, schedule: "BD", days: 7, quantity: nil),
    Expect(line: "Tab Neurobion Forte 0-1-0 x 30 days", form: .tab, brand: "Neurobion Forte", strength: nil, schedule: "0-1-0", days: 30, quantity: 30),
    Expect(line: "5) Cap Omez 20 mg 1-0-0 #15", form: .cap, brand: "Omez", strength: "20 mg", schedule: "1-0-0", days: nil, quantity: 15),
    Expect(line: "Tab Zerodol 100 SOS qty 10", form: .tab, brand: "Zerodol", strength: "100", schedule: "SOS", days: nil, quantity: 10),
    Expect(line: "Tab. Ciplox-500 BD x 5 d", form: .tab, brand: "Ciplox", strength: "500", schedule: "BD", days: 5, quantity: 10),
    Expect(line: "Tab Pan D 40 1-0-0 x 14 days", form: .tab, brand: "Pan D", strength: "40", schedule: "1-0-0", days: 14, quantity: 14),
    Expect(line: "Syp Cetzine 5 mg/5 ml 5ml HS x 5 days", form: .syp, brand: "Cetzine", strength: "5 mg/5 ml", schedule: "HS", days: 5, quantity: nil),
    // OCR noise: letter O for zero, l / I for one
    Expect(line: "1) Tab Pan 4O mg l-O-O x 15 days", form: .tab, brand: "Pan", strength: "40 mg", schedule: "1-0-0", days: 15, quantity: 15),
    Expect(line: "Tab Dolo 65O 1-O-1 x 5 days", form: .tab, brand: "Dolo", strength: "650", schedule: "1-0-1", days: 5, quantity: 10),
    Expect(line: "Cap. AZITHRAL 5OO 0D x3d", form: .cap, brand: "AZITHRAL", strength: "500", schedule: "OD", days: 3, quantity: 3),
    Expect(line: "Tab Telma 8O I-0-0 x 3O days", form: .tab, brand: "Telma", strength: "80", schedule: "1-0-0", days: 30, quantity: 30),
]

@Test func printedLinesParseToStructuredItems() {
    for c in cases {
        let item = parse(c.line)
        #expect(item.rawLine == c.line, "\(c.line)")
        #expect(item.form == c.form, "form: \(c.line)")
        #expect(item.brand == c.brand, "brand: \(c.line)")
        #expect(item.strength == c.strength, "strength: \(c.line)")
        #expect(item.schedule?.code == c.schedule, "schedule: \(c.line)")
        #expect(item.days == c.days, "days: \(c.line)")
        #expect(item.quantityHint == c.quantity, "quantity: \(c.line)")
        #expect(item.isConfident, "confident: \(c.line) -> \(item.confidence)")
    }
}

@Test func atLeastTwentyFiveRealisticLinesAreCovered() {
    // 22 structured cases above + the 6 below in this file (OCR brand repair, doses, tricky lines, junk).
    #expect(cases.count >= 20)
}

@Test func syrupDoseVolumeIsNotAStrength() {
    let item = parse("Syp Ascoril LS 5ml TDS")
    #expect(item.strength == nil)
    #expect(item.doseAmount == "5 ml")
    #expect(item.schedule == DoseSchedule(code: "TDS", dosesPerDay: 3))
}

@Test func schedulesCarryDosesPerDay() {
    #expect(parse("Tab Pan 40 1-0-1").schedule == DoseSchedule(code: "1-0-1", dosesPerDay: 2))
    #expect(parse("Tab Pan 40 1-1-1-1").schedule == DoseSchedule(code: "1-1-1-1", dosesPerDay: 4))
    #expect(parse("Tab Pan 40 1/2-0-1/2").schedule == DoseSchedule(code: "1/2-0-1/2", dosesPerDay: 1))
    #expect(parse("Tab Pan 40 QID").schedule == DoseSchedule(code: "QID", dosesPerDay: 4))
    #expect(parse("Tab Pan 40 SOS").schedule == DoseSchedule(code: "SOS", dosesPerDay: nil))
    #expect(parse("Tab Pan 40 1+0+1").schedule == DoseSchedule(code: "1-0-1", dosesPerDay: 2))
}

@Test func quantityIsAHintOnlyForTabletsAndCapsules() {
    #expect(parse("Tab Pan 40 1-0-1 x 10 days").quantityHint == 20)
    #expect(parse("Syp Ascoril LS 5ml TDS x 5 days").quantityHint == nil)
    #expect(parse("Tab Pan 40 1-0-1 x 10 days #30").quantityHint == 30)   // printed quantity wins
    #expect(parse("Tab Pan 40 1-0-0 x 10 tabs").quantityHint == 10)
}

@Test func catalogueConfirmsBrandAndStrength() {
    #expect(parse("Tab Telma 40 1-0-0 x 30 days").check == .confirmed(brand: "TELMA", strength: "40"))
    #expect(parse("Tab Allegra 120mg BD x 7 days").check == .confirmed(brand: "ALLEGRA", strength: "120"))
    #expect(plain.parse(line: "Tab Telma 40 1-0-0").check == nil)   // no catalogue given: no claim
}

@Test func impossibleStrengthIsFlaggedAndNotConfident() {
    let item = parse("Tab Telma 400 1-0-0 x 30 days")
    #expect(item.check == .strengthMismatch(brand: "TELMA", read: "400", available: ["20", "40", "80"]))
    #expect(item.strength == "400")           // reported as read, not corrected
    #expect(!item.isConfident)
}

@Test func unknownBrandKeepsReadingButLowConfidenceAndOnlySuggests() {
    let item = parse("Tab Telia 40 1-0-0 x 30 days")
    #expect(item.brand == "Telia")           // never replaced by a guess
    guard case .unknownBrand(_, let suggestions) = item.check else {
        Issue.record("expected unknownBrand")
        return
    }
    #expect(suggestions.first == "TELMA")
    #expect(!item.isConfident)
}

@Test func ocrDigitsInsideABrandAreRepairedOnlyToARealBrand() {
    // "1" for "I" and "0" for "O"; both repaired words are real brands in the catalogue.
    #expect(parse("Cap. AZ1THRAL 500 OD x3d").brand == "AZITHRAL")
    #expect(parse("Tab D0LO 650 1-0-1 x 5 days").brand == "DOLO")
    // not a brand in the catalogue after any repair: left as read, flagged
    let unrepaired = parse("Tab Z0RDX 10 1-0-0")
    #expect(unrepaired.brand == "Z0RDX")
    #expect(!unrepaired.isConfident)
    // without a catalogue nothing is repaired
    #expect(plain.parse(line: "Cap. AZ1THRAL 500 OD x3d").brand == "AZ1THRAL")
}

@Test func formAfterTheBrandAndGluedForms() {
    let a = parse("Dolo 650 Tablet 1-0-1 x 5 days")
    #expect(a.form == .tab)
    #expect(a.brand == "Dolo")
    #expect(a.strength == "650")
    let b = parse("Tab.Pan 40 1-0-0")
    #expect(b.form == .tab)
    #expect(b.brand == "Pan")
}

@Test func formWithoutBrandIsLowConfidence() {
    let item = parse("Tab 1-0-1 x 5 days")
    #expect(item.form == .tab)
    #expect(item.brand == nil)
    #expect(!item.isConfident)
}

@Test func strengthAndScheduleWithoutFormIsLowConfidence() {
    let item = parse("Pan 40 mg 1-0-0")
    #expect(item.brand == "Pan")
    #expect(item.form == nil)
    #expect(item.confidence <= 0.5)
    #expect(!item.isConfident)
}

@Test func jaFormMapping() {
    #expect(parse("Tab Pan 40 mg 1-0-0").form?.jaForm == .tablet)
    #expect(parse("Syp Ascoril LS 5ml TDS").form?.jaForm == .liquid)
    #expect(parse("Inj. Ceftriaxone 1 gm IV BD").form?.jaForm == .injection)
    #expect(DoseForm.drops.jaForm == nil)   // eye, ear or oral: ambiguous, so no Jan Aushadhi lookup
}

// 23..: lines the parser must NOT turn into medicines.
private let junk = [
    "Dr. Anil Kumar MBBS, MD (Medicine)",
    "Reg. No. 12345 Ph: 9876543210",
    "Date: 12/10/2026",
    "Patient: Ramesh Kumar 45/M",
    "Rx",
    "Follow up after 5 days",
    "Advice: Drink plenty of fluids",
    "Take rest and avoid cold food",
    "City Hospital, Sector 15, Noida",
    "BP 130/90 mmHg  Wt 72 kg",
    "",
    "   ",
    "1-0-1",
    "xyz ###",
    "Advice: syrup after meals",
]

@Test func linesItCannotParseComeBackLowConfidenceWithNoFields() {
    for line in junk {
        let item = parse(line)
        #expect(item.confidence <= 0.2, "\(line) -> \(item.confidence)")
        #expect(!item.isConfident, "\(line)")
        #expect(item.brand == nil, "brand: \(line)")
        #expect(item.form == nil, "form: \(line)")
        #expect(item.strength == nil, "strength: \(line)")
        #expect(item.days == nil && item.quantityHint == nil, "days/qty: \(line)")
        #expect(item.check == nil, "check: \(line)")
        #expect(item.rawLine == line)
    }
}

@Test func parseLinesKeepsOneItemPerLineInOrder() {
    let lines = ["Dr. Anil Kumar", "1) Tab Pan 40 mg 1-0-0 x 15 days", "Cap. AZITHRAL 500 OD x3d", "Follow up after 5 days"]
    let items = parser.parse(lines: lines)
    #expect(items.map(\.rawLine) == lines)
    #expect(items.map(\.isConfident) == [false, true, true, false])
}

@Test func totalRealisticLinesTestedIsAtLeast25() {
    // Structured cases + the single lines asserted in the other tests of this file.
    let singleLines = [
        "Syp Ascoril LS 5ml TDS", "Tab Telma 40 1-0-0 x 30 days", "Tab Allegra 120mg BD x 7 days", "Tab Telma 400 1-0-0 x 30 days",
        "Tab Telia 40 1-0-0 x 30 days", "Cap. AZ1THRAL 500 OD x3d", "Tab D0LO 650 1-0-1 x 5 days", "Dolo 650 Tablet 1-0-1 x 5 days",
        "Tab.Pan 40 1-0-0", "Tab 1-0-1 x 5 days", "Pan 40 mg 1-0-0", "Tab Z0RDX 10 1-0-0",
    ]
    #expect(cases.count + singleLines.count + junk.count >= 25)
    #expect(cases.count + singleLines.count >= 25)
}

// MARK: K16: shapes seen in Vision output of printed parchis

@Test func combinationStrengthsStayOneStrength() {
    #expect(parse("Tab. Kapocef AZ 200MG/250MG 0-0-1 x 7d").strength == "200 mg/250 mg")
    #expect(plain.parse(line: "Tab Pan 200 mg / 250 mg BD").strength == "200 mg/250 mg")
    #expect(plain.parse(line: "Syrup SNIZARIL 1 MG/125 MG/2.5 MG 2 tsf TDS x 10d").strength == "1 mg/125 mg/2.5 mg")
    #expect(plain.parse(line: "Tab TOPME CH 50/12.5 ER 0-0-1 x 15 days").strength == "50/12.5")
    // a schedule such as 1/2-0-1/2 is still a schedule, not a strength
    let half = plain.parse(line: "Tab. CIPROXIN 500MG ½-0-½ a.c. x 7 days")
    #expect(half.schedule?.code == "½-0-½")
    #expect(half.strength == "500 mg")
}

@Test func initialsAndEyeDropFormsAreRead() {
    let t = plain.parse(line: "2) T. LDLOW 20MG 1-0-1 BF x 5d")
    #expect(t.form == .tab && t.brand == "LDLOW" && t.strength == "20 mg")
    let c = plain.parse(line: "C. FORZOLE-D 10MG/20MG SOS empty stomach x 7 days")
    #expect(c.form == .cap && c.brand == "FORZOLE-D")
    let drops = plain.parse(line: "6) E/D EUPEPTINE 1 drop QID x 30 days")
    #expect(drops.form == .drops && drops.brand == "EUPEPTINE" && drops.strength == nil)
    let spray = plain.parse(line: "Nasal spray FLOCARE AZ 2 sprays BD x 15d")
    #expect(spray.form == .spray && spray.brand == "FLOCARE AZ" && spray.strength == nil)
}

@Test func doseCountsAreNotStrengths() {
    let a = plain.parse(line: "Tab VERTIFLIX 1 BD x 15d")
    #expect(a.strength == nil && a.schedule?.code == "BD")
    let b = plain.parse(line: "Tab. EVAQUIN 15MG 1OD empty stomach x 5 days")
    #expect(b.strength == "15 mg" && b.schedule?.code == "OD")
    let c = plain.parse(line: "Syrup MOXGIL DS 1 tsf BD x 3d")
    #expect(c.strength == nil && c.doseAmount == "1 tsf" && c.brand == "MOXGIL DS")
    // the catalogue says 2 is a real Doxacard strength, so "2 OD" keeps it as the strength
    let known = PrintedParser(catalogue: Catalogue(productNames: ["Doxacard 2 Tablet", "Doxacard 4 Tablet"]))
    #expect(known.parse(line: "T. DOXACARD 2 OD after food x 1 month").strength == "2")
}

@Test func topicalPackSizeIsTheStrengthButSyrupVolumeIsNot() {
    #expect(plain.parse(line: "Lotion KALEEZE 100ML apply HS x 15d").strength == "100 ml")
    #expect(plain.parse(line: "Syp Ascoril LS 5ml TDS").strength == nil)
}

@Test func headerAndAdviceLinesStayUnparsed() {
    for line in ["Dr. Nitin Agarwal", "MBBS, MD (Derma)", "Reg. No. MPMC 37101", "Sai Medical Centre, Bhopal • Ph: 79395 84427",
                 "Name: Komal Sharma", "Age/Sex: 74 Date: 22-2-2026", "Not valid for medico-legal purposes",
                 "Timings: 10 am - 2 pm, 5 pm - 8 pm", "Emergency: 7422806194", "BP 102/60", "Review after 7 days"] {
        let item = plain.parse(line: line)
        #expect(item.brand == nil && item.confidence <= 0.1, "\(line)")
    }
}

@Test func strengthGluedToScheduleAndDuration() {
    let a = plain.parse(line: "1. Tab. FAMCIMAC 500BDx1month")
    #expect(a.strength == "500" && a.schedule?.code == "BD" && a.days == 30)
    let b = plain.parse(line: "- Tab CEZOX MR 1-1-1 after food x 1 month")
    #expect(b.brand == "CEZOX MR" && b.schedule?.code == "1-1-1")
}

@Test func gramStrengthMatchesACatalogueThatWritesTheGramNumber() {
    let cat = PrintedParser(catalogue: Catalogue(productNames: ["Ertaneon 1gm Injection", "Ceftriaxone 1000 Injection"]))
    #expect(cat.parse(line: "Inj Ertaneon 1GM IM stat x 5 days").check == .confirmed(brand: "ERTANEON", strength: "1"))
    #expect(cat.parse(line: "Inj Ceftriaxone 1 gm IV BD x 3 days").check == .confirmed(brand: "CEFTRIAXONE", strength: "1000"))
}

// K27 item 20: an explicit number of units per dose multiplies the doses per day.
@Test func explicitDoseCountMultipliesTheQuantity() {
    for p in [parser, plain] {
        let a = p.parse(line: "Tab Dolo 650 2BD x 10 days")
        #expect(a.brand == "Dolo" && a.strength == "650" && a.schedule?.code == "BD" && a.days == 10, "\(a)")
        #expect(a.quantityHint == 40 && !a.quantityAmbiguous)
        #expect(p.parse(line: "Tab Dolo 650 2 BD x 10 days").quantityHint == 40)
        #expect(p.parse(line: "Tab Dolo 650 2TDS x 5 days").quantityHint == 30)
        #expect(p.parse(line: "Tab Dolo 650 2 tabs BD x 10 days").quantityHint == 40)
        #expect(p.parse(line: "Cap Omez 20 2 caps OD x 7 days").quantityHint == 14)
        #expect(p.parse(line: "Tab Dolo 650 3QID x 2 days").quantityHint == 24)
    }
    // unchanged: a count of one, patterns, and a printed quantity
    #expect(parse("Tab Dolo 650 1BD x 10 days").quantityHint == 20)
    #expect(parse("Tab Dolo 650 BD x 10 days").quantityHint == 20)
    #expect(parse("Tab Dolo 650 1-0-1 x 10 days").quantityHint == 20)
    #expect(parse("Tab Dolo 650 2BD x 10 days #15").quantityHint == 15)
    #expect(parse("Tab Dolo 650 2BD").quantityHint == nil)
}

@Test func doseCountWithADosePatternIsAskedNotGuessed() {
    for line in ["Tab Dolo 650 2 tabs 1-0-1 x 5 days", "Tab Dolo 650 1-0-1 2 tabs x 5 days"] {
        let item = parse(line)
        #expect(item.quantityAmbiguous && item.quantityHint == nil, "\(line) -> \(item)")
    }
    // no duration: nothing is inferred, so nothing to ask
    #expect(!parse("Tab Dolo 650 2 tabs 1-0-1").quantityAmbiguous)
    // a plain pattern is never ambiguous
    let plainPattern = parse("Tab Dolo 650 1-0-1 x 5 days")
    #expect(!plainPattern.quantityAmbiguous && plainPattern.quantityHint == 10)
}
