import Foundation
import Testing
@testable import ParchiCore

@Test func purgeAtExactly24Hours() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    #expect(shouldPurge(created: now.addingTimeInterval(-24 * 3600), now: now))
    #expect(shouldPurge(created: now.addingTimeInterval(-24 * 3600 - 1), now: now))
    #expect(shouldPurge(created: now.addingTimeInterval(-48 * 3600), now: now))
}

@Test func keepsFreshFiles() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    #expect(!shouldPurge(created: now.addingTimeInterval(-24 * 3600 + 1), now: now))
    #expect(!shouldPurge(created: now, now: now))
    #expect(!shouldPurge(created: now.addingTimeInterval(3600), now: now)) // clock moved back: keep
}

@Test func retentionStartUsesTheEarlierDateAndNeverTheFuture() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let old = now.addingTimeInterval(-30 * 3600), recent = now.addingTimeInterval(-3600)
    #expect(retentionStart(recorded: recent, fileCreated: old, now: now) == old)   // a later index date cannot extend a file's life
    #expect(retentionStart(recorded: old, fileCreated: recent, now: now) == old)
    #expect(retentionStart(recorded: nil, fileCreated: recent, now: now) == recent)
    #expect(retentionStart(recorded: nil, fileCreated: nil, now: now) == now)      // unknown: its 24 hours start now
}

@Test func rolledBackClockExtendsRetentionByNoMoreThanTheRollback() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let written = now.addingTimeInterval(-20 * 3600)          // written 20 h ago
    let rollback: TimeInterval = 10 * 3600
    let clockNow = now.addingTimeInterval(-rollback)           // the clock is then set back by 10 h: the file now looks 10 h old
    let start = retentionStart(recorded: written, fileCreated: written, now: clockNow)
    #expect(start == written && !shouldPurge(created: start, now: clockNow))
    // Set back by 30 h: the file looks like it comes from the future. Its age restarts at the rolled-back "now", not later.
    let farBack = now.addingTimeInterval(-30 * 3600)
    let rebased = retentionStart(recorded: written, fileCreated: written, now: farBack)
    #expect(rebased == farBack)
    #expect(shouldPurge(created: rebased, now: farBack.addingTimeInterval(24 * 3600)))
    // Real time passes 24 h after the rollback began: gone. Real age 20 h + 24 h = 44 h; without the clamp it would be 74 h.
}
