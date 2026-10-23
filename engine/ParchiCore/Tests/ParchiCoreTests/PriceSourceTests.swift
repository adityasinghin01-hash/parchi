import Foundation
import Testing
@testable import ParchiCore

private let ist = TimeZone(identifier: "Asia/Kolkata")!

/// A moment in IST (the app shows IST).
private func moment(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = ist
    return cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

@Test func labelFormats() {
    #expect(PriceSource(kind: .mrp, dateSeen: moment(2026, 10, 23)).label == "MRP")
    #expect(PriceSource(kind: .online, dateSeen: moment(2026, 10, 23, 9)).label == "Online, 23 Oct")
    #expect(PriceSource(kind: .shopReply, dateSeen: moment(2026, 10, 24, 18, 40)).label == "Shop replied 6:40 pm")
    #expect(PriceSource(kind: .shopReply, dateSeen: moment(2026, 10, 24, 9, 5)).label == "Shop replied 9:05 am")
    #expect(PriceSource(kind: .phoneCall, dateSeen: moment(2026, 10, 24, 11)).label == "Called 24 Oct")
}

@Test func mrpAlwaysCarriesADate() {
    #expect(PriceSource(kind: .mrp, dateSeen: moment(2026, 10, 23)).datedLabel == "MRP, seen 23 Oct")
    #expect(PriceSource(kind: .online, dateSeen: moment(2026, 10, 23)).datedLabel == "Online, 23 Oct")
}

@Test func staleBoundaryIsExactlySevenDays() {
    let seen = moment(2026, 10, 1, 12)
    let source = PriceSource(kind: .online, dateSeen: seen)
    #expect(!source.isStale(now: seen))
    #expect(!source.isStale(now: seen.addingTimeInterval(7 * 86_400 - 1)))
    #expect(!source.isStale(now: seen.addingTimeInterval(7 * 86_400)))        // exactly 7 days: still fresh
    #expect(source.isStale(now: seen.addingTimeInterval(7 * 86_400 + 1)))     // 1 s over: stale
    #expect(source.staleNote(now: seen.addingTimeInterval(8 * 86_400)) == "may have changed")
    #expect(source.staleNote(now: seen.addingTimeInterval(86_400)) == nil)
}

@Test func futureDateIsNotStale() {
    let source = PriceSource(kind: .shopReply, dateSeen: moment(2026, 10, 25))
    #expect(!source.isStale(now: moment(2026, 10, 23)))
}

@Test func isoDateParsesAsISTMidnight() {
    #expect(PriceSource.date(fromISO: "2026-10-23") == moment(2026, 10, 23))
    #expect(PriceSource.date(fromISO: nil) == nil)
    #expect(PriceSource.date(fromISO: "not a date") == nil)
}

@Test func catalogueMRPChipSaysItIsACatalogueMRPAndStillAges() {
    let seen = moment(2026, 10, 23)
    let source = PriceSource.catalogueMRP(dateSeen: seen)
    #expect(source.kind == .mrp)
    #expect(source.datedLabel == "Catalogue MRP · check at the shop")
    #expect(source != PriceSource(kind: .mrp, dateSeen: seen))
    #expect(!source.isStale(now: moment(2026, 10, 30)))
    #expect(source.staleNote(now: moment(2026, 10, 31)) == "may have changed")
    #expect(PriceSource.catalogueMRP(dateSeen: seen, packSizeKnown: false).datedLabel
        == "Catalogue MRP · check at the shop · pack size unclear, 1 pack priced")
}
