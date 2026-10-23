import Foundation

extension Notification.Name {
    /// Posted after local data is wiped so view models drop what they cached in memory.
    static let parchiErased = Notification.Name("parchi.erased")
}

/// "Delete everything": history, saved settings, consent record, temp files, seller logins, scheduled notifications, the clipboard
/// copy Parchi made, the in-memory models, then the server copy. Calendar events cannot be removed (write-only access).
@MainActor
enum EraseEverything {
    /// Keys that belong to the backend developer panel are kept: they are the address and key needed to ask the server to delete,
    /// and `parchi.backend.usedLive` (a server copy may exist).
    static let keptPrefix = "parchi.backend."
    static let sharedKeys = ["parchi.address", "parchi.language", "parchi.autoApproveCapPaise", ConsentStore.atKey, ConsentStore.versionKey]

    /// What the Delete screen says about the Calendar, plainly.
    static let calendarNote = "Events Parchi added to your Calendar stay there; delete them in the Calendar app."

    /// Every saved key to remove: the shared ones plus anything else under "parchi." (care ticks, city, lab address, shop phones…).
    static func keysToRemove(in existing: [String]) -> [String] {
        let extra = existing.filter { $0.hasPrefix("parchi.") && !$0.hasPrefix(keptPrefix) }
        return Array(Set(sharedKeys + extra)).sorted()
    }

    struct Report: Equatable {
        var server: ResetClient.Outcome
        /// What could not be deleted on this phone (empty = everything local is gone).
        var localFailures: [String]
        var localOK: Bool { localFailures.isEmpty }
    }

    /// Wipes everything on this phone and returns what happened. Local data is wiped even when the server cannot be reached,
    /// and a local failure is reported, never hidden.
    static func run(history: HistoryStore, tempFiles: TempFileStore = TempFileStore(), reset: ResetClient,
                    defaults: UserDefaults = .standard,
                    clearSellerSessions: @MainActor () async -> Void = { await CheckoutPrivacy.clearSellerSessions() },
                    clearArtifacts: @MainActor () -> Void = { NotificationCleanup.removeAll(); ClipboardTracker.shared.clearIfOurs() }) async -> Report {
        var failures: [String] = []
        // Models first: this stops polling and in-flight work, so nothing writes data back while the rest is wiped.
        NotificationCenter.default.post(name: .parchiErased, object: nil)
        if !history.deleteAll() { failures.append("saved parchis") }
        let keys = keysToRemove(in: Array(defaults.dictionaryRepresentation().keys))
        for key in keys { defaults.removeObject(forKey: key) }
        if keys.contains(where: { defaults.object(forKey: $0) != nil }) { failures.append("saved settings") }
        failures += tempFiles.removeAll().map { "photo copy \($0)" }
        await clearSellerSessions()   // awaited: the WebKit data is gone before "deleted" is shown
        clearArtifacts()
        return Report(server: await reset.reset(), localFailures: failures)
    }
}
