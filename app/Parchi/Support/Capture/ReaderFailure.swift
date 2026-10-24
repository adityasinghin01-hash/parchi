import Foundation

/// Why a photo could not be read. Each case has its own plain message: a reader problem is never shown as "can't reach the server".
/// Server machine codes (`/read` JSON `code`, see docs/team/READER-CONTRACT.md) map 1:1 through `init?(code:)`.
enum ReaderFailure: Equatable {
    /// The lab server has no reader key set up.
    case notConfigured
    /// Our spend cap (or Anthropic's own spend limit) is used up. Retrying does not help.
    case capReached
    /// Anthropic refused the lab server's key (401/403).
    case badKey
    /// The reading service failed (5xx or another upstream problem).
    case readerError
    /// The phone could not reach the lab server at all.
    case offline
    /// The read took too long and was stopped.
    case timeout
    /// The read worked but found no medicines or tests.
    case empty
    /// Mock (demo) mode has no reader and the on-phone reader found nothing.
    case noReaderInMock
    /// Too many photos from this phone in one minute (server code `slow_down`, HTTP 429).
    case slowDown

    /// Server `code` -> failure. nil for an unknown code (the caller decides, usually `.readerError`).
    init?(code: String) {
        switch code {
        case "not_configured": self = .notConfigured
        case "cap_reached": self = .capReached
        case "bad_key": self = .badKey
        case "reader_error": self = .readerError
        case "timeout": self = .timeout
        case "slow_down": self = .slowDown
        case "empty": self = .empty
        default: return nil
        }
    }

    var message: String { ReaderCopy.failureMessage(self) }

    /// True when trying the same photo again may work.
    var canRetry: Bool {
        switch self {
        case .readerError, .offline, .timeout, .empty, .slowDown: return true
        case .notConfigured, .capReached, .badKey, .noReaderInMock: return false
        }
    }
}
