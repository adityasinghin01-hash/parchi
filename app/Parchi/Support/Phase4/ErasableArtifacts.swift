import Foundation
import UIKit
import UserNotifications

/// Something with a change counter and one text slot: `UIPasteboard`, or a fake in tests.
protocol PasteboardLike: AnyObject {
    var changeCount: Int { get }
    var string: String? { get set }
}

extension UIPasteboard: PasteboardLike {}

/// Remembers (in memory only) the last message Parchi copied, so "Delete everything" can clear the clipboard
/// without touching something the user copied elsewhere.
@MainActor
final class ClipboardTracker {
    static let shared = ClipboardTracker()

    private var lastText: String?
    private var lastChangeCount: Int?
    private let board: PasteboardLike

    init(board: PasteboardLike = UIPasteboard.general) { self.board = board }

    /// Copy `text` and remember that Parchi put it there.
    func copy(_ text: String) {
        board.string = text
        lastText = text
        lastChangeCount = board.changeCount
    }

    /// Clears the clipboard only if it still holds what Parchi copied: nothing has been copied since (the change counter is
    /// unchanged), so nothing is read from the clipboard and iOS shows no paste prompt. Returns true when it was cleared.
    @discardableResult
    func clearIfOurs() -> Bool {
        defer { lastText = nil; lastChangeCount = nil }
        guard lastText != nil, let count = lastChangeCount, board.changeCount == count else { return false }
        board.string = ""
        return true
    }
}

/// Local notifications Parchi scheduled (fasting reminders) and the ones already delivered.
enum NotificationCleanup {
    static func removeAll() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}

/// `parchi.backend.usedLive`: set once the app has sent data that a server may still hold (an order, a shop ask, a lab booking,
/// a refill watch). "Delete everything" keeps it (it lives under `parchi.backend.`), so a Delete pressed in Mock mode can say
/// that a server copy may exist.
enum BackendUsage {
    static let key = "parchi.backend.usedLive"
    static func markUsedLive(_ store: UserDefaults = .standard) { store.set(true, forKey: key) }
    static func hasUsedLive(_ store: UserDefaults = .standard) -> Bool { store.bool(forKey: key) }
}
