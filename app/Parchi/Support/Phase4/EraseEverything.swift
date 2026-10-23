import Foundation

/// "Delete everything": history, saved settings, consent record, temp files, seller logins, then the server copy.
@MainActor
enum EraseEverything {
    /// Keys that belong to the backend developer panel are kept: they are the address and key needed to ask the server to delete.
    static let keptPrefix = "parchi.backend."
    static let sharedKeys = ["parchi.address", "parchi.language", "parchi.autoApproveCapPaise", ConsentStore.atKey, ConsentStore.versionKey]

    /// Every saved key to remove: the shared ones plus anything else under "parchi." (care ticks, city, lab address, shop phones…).
    static func keysToRemove(in existing: [String]) -> [String] {
        let extra = existing.filter { $0.hasPrefix("parchi.") && !$0.hasPrefix(keptPrefix) }
        return Array(Set(sharedKeys + extra)).sorted()
    }

    /// Wipes everything on this phone and returns the server result. Local data is wiped even when the server cannot be reached.
    static func run(history: HistoryStore, tempFiles: TempFileStore = TempFileStore(), reset: ResetClient,
                    defaults: UserDefaults = .standard, onClearSellerSessions: () -> Void) async -> ResetClient.Outcome {
        history.deleteAll()
        for key in keysToRemove(in: Array(defaults.dictionaryRepresentation().keys)) { defaults.removeObject(forKey: key) }
        tempFiles.removeAll()
        onClearSellerSessions()
        return await reset.reset()
    }
}
