import Foundation
import Testing
@testable import ParchiCore

private func realCheck() throws -> ScheduleCheck {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { url.deleteLastPathComponent() } // -> engine/
    let dir = url.appendingPathComponent("catalogue")
    return try ScheduleCheck(scheduleJSON: Data(contentsOf: dir.appendingPathComponent("schedule_h1_x.json")),
                             brandJSON: Data(contentsOf: dir.appendingPathComponent("brand_schedule.json")))
}

private let small = ScheduleCheck(
    entries: [
        ScheduleEntry(schedule: .h1, salt: "Tramadol"),
        ScheduleEntry(schedule: .h1, salt: "Ethambutol Hydrochloride"),
        ScheduleEntry(schedule: .x, salt: "Ketamine hydrochloride"),
    ],
    brands: ["ALPRAX": BrandScheduleEntry(schedule: .h1, salt: "Alprazolam")]
)

@Test func h1AndXHits() {
    #expect(small.isInPersonOnly(salt: "Tramadol") == .h1)
    #expect(small.isInPersonOnly(salt: "ketamine") == .x)
}

@Test func caseSpaceAndSuffixInsensitive() {
    #expect(small.isInPersonOnly(salt: "  TRAMADOL ") == .h1)
    #expect(small.isInPersonOnly(salt: "Tramadol HCl") == .h1)
    #expect(small.isInPersonOnly(salt: "tramadol hydrochloride 50 mg") == .h1)
    #expect(small.isInPersonOnly(salt: "Ethambutol") == .h1)                       // file says "...Hydrochloride"
    #expect(small.isInPersonOnly(salt: "ETHAMBUTOL  hcl (400mg)") == .h1)
    #expect(small.isInPersonOnly(salt: "Ketamine Hydrochloride") == .x)
}

@Test func misses() {
    #expect(small.isInPersonOnly(salt: "Paracetamol") == nil)
    #expect(small.isInPersonOnly(salt: "Tramadolx") == nil)
    #expect(small.isInPersonOnly(salt: "") == nil)
    #expect(small.isInPersonOnly(salt: "hydrochloride") == nil)
}

@Test func compositionTakesStrictestSalt() {
    #expect(small.isInPersonOnly(composition: "Paracetamol/Acetaminophen (325mg) + Tramadol (37.5mg)") == .h1)
    #expect(small.isInPersonOnly(composition: "Tramadol (50mg) + Ketamine (10mg)") == .x)
    #expect(small.isInPersonOnly(composition: "Paracetamol (650mg)") == nil)
}

@Test func brandLookup() {
    #expect(small.isInPersonOnly(brand: "Alprax") == .h1)
    #expect(small.isInPersonOnly(brand: "alprax 0.25 Tablet") == .h1)
    #expect(small.isInPersonOnly(brand: "Dolo") == nil)
}

@Test func inPersonMessage() {
    #expect(Schedule.h1.inPersonMessage == "Buy in person with the original parchi")
}

@Test func realFileHasAll66Salts() throws {
    let check = try realCheck()
    #expect(check.saltCount == 66)
    for salt in ["Alprazolam", "Zolpidem", "Cefixime", "Ceftriaxone", "Levofloxacin", "Tramadol", "Oseltamivir"] {
        #expect(check.isInPersonOnly(salt: salt) == .h1, "\(salt)")
    }
    for salt in ["Methylphenidate", "Amphetamine", "Ketamine HCl"] {
        #expect(check.isInPersonOnly(salt: salt) == .x, "\(salt)")
    }
    #expect(check.entry(forSalt: "tramadol")?.sourceURL.hasPrefix("https://") == true)
}

@Test func realFileCommonSaltsAreNotFlagged() throws {
    let check = try realCheck()
    for salt in ["Paracetamol", "Azithromycin", "Amoxycillin", "Telmisartan", "Pantoprazole", "Metformin", "Cetirizine"] {
        #expect(check.isInPersonOnly(salt: salt) == nil, "\(salt)")
    }
}

@Test func realBrandTable() throws {
    let check = try realCheck()
    #expect(check.brandCount > 100)
    #expect(check.isInPersonOnly(brand: "Alprax") == .h1)
    #expect(check.isInPersonOnly(brand: "Anxit 0.5") == .h1)
    #expect(check.isInPersonOnly(brand: "Dolo 650") == nil)
    #expect(check.isInPersonOnly(brand: "Telma") == nil)
    #expect(check.isInPersonOnly(brand: "Azithral") == nil)
}
