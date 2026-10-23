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
