import Foundation

/// The promise on the consent screen: parchi photo crops and caches are deleted after 24 hours.
public enum Purge {
    public static let maxAge: TimeInterval = 24 * 60 * 60
}

/// True once a file is 24 hours old or more. A file dated in the future (clock moved) is kept.
public func shouldPurge(created: Date, now: Date) -> Bool {
    now.timeIntervalSince(created) >= Purge.maxAge
}
