import Foundation

/// The promise on the consent screen: parchi photo crops and caches are removed the next time the app opens after 24 hours.
public enum Purge {
    public static let maxAge: TimeInterval = 24 * 60 * 60
}

/// True once a file is 24 hours old or more. A file dated in the future (clock moved) is kept by this function alone;
/// `retentionStart` is what callers use so that "kept" can never last longer than the clock was rolled back.
public func shouldPurge(created: Date, now: Date) -> Bool {
    now.timeIntervalSince(created) >= Purge.maxAge
}

/// When a file's 24 hours start. `recorded` is the date our own index wrote when the file first appeared (nil if unknown),
/// `fileCreated` is the file system's creation date (nil if unknown). The earlier of the two wins, but never a date later than
/// `now`: if the clock was rolled back, the file's age restarts at `now`, so retention grows by at most the size of the rollback
/// instead of growing without limit. The caller must store the returned date back in its index, otherwise the age would restart
/// at every call. With neither date known the file starts its 24 hours now.
public func retentionStart(recorded: Date?, fileCreated: Date?, now: Date) -> Date {
    let known = [recorded, fileCreated].compactMap { $0 }
    guard let earliest = known.min() else { return now }
    return min(earliest, now)
}
