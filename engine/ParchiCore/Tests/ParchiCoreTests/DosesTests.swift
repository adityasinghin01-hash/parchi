import Foundation
import Testing
@testable import ParchiCore

@Test func dosesPerDayNumeric() {
    #expect(Doses.dosesPerDay(schedule: "1-0-1") == 2)
    #expect(Doses.dosesPerDay(schedule: "0-0-1") == 1)
    #expect(Doses.dosesPerDay(schedule: "1-1-1") == 3)
    #expect(Doses.dosesPerDay(schedule: "2-0-1") == 3)
    #expect(Doses.dosesPerDay(schedule: " 1 – 0 – 1 ") == 2)
    #expect(Doses.dosesPerDay(schedule: "1/2-0-1/2") == 1)
    #expect(Doses.dosesPerDay(schedule: "1-1-1-1") == 4)
}

@Test func dosesPerDayWords() {
    #expect(Doses.dosesPerDay(schedule: "OD") == 1)
    #expect(Doses.dosesPerDay(schedule: "o.d.") == 1)
    #expect(Doses.dosesPerDay(schedule: "BD") == 2)
    #expect(Doses.dosesPerDay(schedule: "bd") == 2)
    #expect(Doses.dosesPerDay(schedule: "TDS") == 3)
    #expect(Doses.dosesPerDay(schedule: "QID") == 4)
    #expect(Doses.dosesPerDay(schedule: "HS") == 1)
}

@Test func dosesPerDayUnknownAndZero() {
    #expect(Doses.dosesPerDay(schedule: "0-0-0") == 0)
    #expect(Doses.dosesPerDay(schedule: "") == nil)
    #expect(Doses.dosesPerDay(schedule: "SOS") == nil)
    #expect(Doses.dosesPerDay(schedule: "1-0") == nil)
    #expect(Doses.dosesPerDay(schedule: "a-b-c") == nil)
    #expect(Doses.dosesPerDay(schedule: "1/0-0-1") == nil)
    #expect(Doses.dosesPerDay(schedule: "-1-0-1") == nil)
}

@Test func slots() {
    #expect(Doses.doseSlots(schedule: "1-0-1") == [.morning, .night])
    #expect(Doses.doseSlots(schedule: "0-0-1") == [.night])
    #expect(Doses.doseSlots(schedule: "1-1-1") == [.morning, .afternoon, .night])
    #expect(Doses.doseSlots(schedule: "OD") == [.morning])
    #expect(Doses.doseSlots(schedule: "BD") == [.morning, .night])
    #expect(Doses.doseSlots(schedule: "TDS") == [.morning, .afternoon, .night])
    #expect(Doses.doseSlots(schedule: "0-0-0").isEmpty)
    #expect(Doses.doseSlots(schedule: "SOS").isEmpty)
}

@Test func daysLeftWholeAndPartialPacks() {
    #expect(Doses.daysLeft(quantity: 30, dosesPerDay: 2) == 15)
    #expect(Doses.daysLeft(quantity: 10, dosesPerDay: 3) == 3)       // 3.33 days → 3 whole days
    #expect(Doses.daysLeft(quantity: 1, dosesPerDay: 2) == 0)        // half a day
    #expect(Doses.daysLeft(quantity: 30, dosesPerDay: 1, daysElapsed: 10) == 20)
    #expect(Doses.daysLeft(quantity: 30, dosesPerDay: 2, daysElapsed: 40) == 0)
    #expect(Doses.daysLeft(quantity: 30, dosesPerDay: 2, daysElapsed: -5) == 15)
    #expect(Doses.daysLeft(quantity: 0, dosesPerDay: 2) == 0)
}

@Test func daysLeftZeroOrUnknownDoses() {
    #expect(Doses.daysLeft(quantity: 30, dosesPerDay: 0) == nil)
    #expect(Doses.daysLeft(quantity: 30, dosesPerDay: nil) == nil)
    #expect(Doses.daysLeft(quantity: -1, dosesPerDay: 1) == nil)
    #expect(Doses.refillInDays(quantity: 30, dosesPerDay: 0) == nil)
}

@Test func refillIsThreeDaysBefore() {
    #expect(Doses.refillInDays(quantity: 30, dosesPerDay: 2) == 12)          // 15 left - 3
    #expect(Doses.refillInDays(quantity: 30, dosesPerDay: 2, daysElapsed: 12) == 0) // 3 left → refill now
    #expect(Doses.refillInDays(quantity: 4, dosesPerDay: 2) == 0)            // 2 left → already due
}

@Test func refillDateUsesCalendarDays() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "Asia/Kolkata"))
    let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 9)))
    let sameDay = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 22)))
    let later = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 8)))
    let first = try #require(Doses.refillDate(quantity: 30, dosesPerDay: 2, started: start, now: sameDay, calendar: calendar))
    #expect(calendar.dateComponents([.month, .day], from: first) == DateComponents(month: 11, day: 4)) // 23 Oct + 12 days
    let second = try #require(Doses.refillDate(quantity: 30, dosesPerDay: 2, started: start, now: later, calendar: calendar))
    #expect(calendar.dateComponents([.month, .day], from: second) == DateComponents(month: 11, day: 4)) // 10 days in, 5 left, refill in 2
    #expect(Doses.refillDate(quantity: 30, dosesPerDay: 0, started: start, now: sameDay, calendar: calendar) == nil)
}
