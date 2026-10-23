import Foundation

/// Where a price on screen came from and when it was seen. The UI never shows a price without one of
/// these (hard rule: every number has a source + date), and shows "may have changed" once it is stale.
public struct PriceSource: Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case mrp          // printed MRP (local market shop until it replies)
        case online       // price read from a seller's product page
        case shopReply    // a shop answered "Ask nearby shops"
        case phoneCall    // our own phone survey
    }

    /// A price older than this (strictly) is stale (requirement U20).
    public static let staleAfter: TimeInterval = 7 * 24 * 60 * 60

    public let kind: Kind
    public let dateSeen: Date

    public init(kind: Kind, dateSeen: Date) {
        self.kind = kind
        self.dateSeen = dateSeen
    }

    /// "MRP", "Online, 23 Oct", "Shop replied 6:40 pm", "Called 24 Oct". Times are shown in IST.
    public var label: String {
        switch kind {
        case .mrp: return "MRP"
        case .online: return "Online, \(Self.format(dateSeen, "d MMM"))"
        case .shopReply: return "Shop replied \(Self.format(dateSeen, "h:mm a").lowercased())"
        case .phoneCall: return "Called \(Self.format(dateSeen, "d MMM"))"
        }
    }

    /// `label` plus the date for kinds whose label has none ("MRP, seen 23 Oct"), so a price always carries a date.
    public var datedLabel: String {
        kind == .mrp ? "MRP, seen \(Self.format(dateSeen, "d MMM"))" : label
    }

    /// Older than 7 days (exactly 7 days is still fresh). A date in the future is not stale.
    public func isStale(now: Date) -> Bool {
        now.timeIntervalSince(dateSeen) > Self.staleAfter
    }

    /// Text for the UI when stale, otherwise nil.
    public func staleNote(now: Date) -> String? {
        isStale(now: now) ? "may have changed" : nil
    }

    /// Parses a "yyyy-MM-dd" date from the bundled data (IST midnight).
    public static func date(fromISO text: String?) -> Date? {
        guard let text else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = ist
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: text)
    }

    static let ist = TimeZone(identifier: "Asia/Kolkata") ?? TimeZone(secondsFromGMT: 19_800) ?? .gmt

    private static func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = ist
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
