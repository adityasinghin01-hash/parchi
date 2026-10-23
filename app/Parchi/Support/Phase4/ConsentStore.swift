import Foundation
import Observation

/// Records when the patient agreed to what the first-run screen says. Keys are shared with other screens: do not rename.
@MainActor
@Observable
final class ConsentStore {
    /// Bump when the promise text changes in a way that needs a new agreement.
    /// 2 (KR, G6): the picture is read by Anthropic's Claude service through our lab server (was: "our own computer").
    static let currentVersion = 2
    static let atKey = "parchi.consentAt"
    static let versionKey = "parchi.consentVersion"

    private(set) var agreedAt: Date?
    private(set) var version: Int

    @ObservationIgnored private let store: UserDefaults

    init(store: UserDefaults = .standard) {
        self.store = store
        agreedAt = store.string(forKey: Self.atKey).flatMap { Self.parse($0) }
        version = store.integer(forKey: Self.versionKey)
        // Delete everything clears the saved agreement BEFORE it posts this notification: re-read at once, so a photo that arrives
        // while the server copy is still being deleted cannot use the old, cached agreement.
        NotificationCenter.default.addObserver(forName: .parchiErased, object: nil, queue: nil) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    /// True on first run, after "Delete everything", or after the text changed.
    var needsConsent: Bool { agreedAt == nil || version < Self.currentVersion }

    func agree(now: Date = Date()) {
        store.set(Self.format(now), forKey: Self.atKey)
        store.set(Self.currentVersion, forKey: Self.versionKey)
        agreedAt = now
        version = Self.currentVersion
    }

    /// Re-reads the stored values (after Delete everything has cleared them).
    func reload() {
        agreedAt = store.string(forKey: Self.atKey).flatMap { Self.parse($0) }
        version = store.integer(forKey: Self.versionKey)
    }

    var summary: String {
        guard let agreedAt, !needsConsent else { return "Not agreed yet" }
        return "Agreed on " + agreedAt.formatted(date: .abbreviated, time: .shortened) + " (version \(version))"
    }

    static func format(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }
    static func parse(_ text: String) -> Date? { ISO8601DateFormatter().date(from: text) }
}
