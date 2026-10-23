import Foundation
import Observation

/// Mock = the offline demo (no network, ever). Live = also talk to the lab server for order tracking.
enum BackendMode: String, CaseIterable, Identifiable {
    case mock, live
    var id: String { rawValue }
    var title: String { self == .mock ? "Mock" : "Live" }
}

/// Backend choice, persisted in UserDefaults. Launch arguments override the saved values for this run only
/// (used for screenshots/tests): `-backendMode live|mock`, `-backendURL <url>`, `-installKey <key>`.
@MainActor
@Observable
final class BackendSettings {
    static let defaultURL = "http://localhost:8000"

    var mode: BackendMode { didSet { store.set(mode.rawValue, forKey: Keys.mode) } }
    var baseURL: String { didSet { store.set(baseURL, forKey: Keys.url) } }
    var installKey: String { didSet { store.set(installKey, forKey: Keys.key) } }

    @ObservationIgnored private let store: UserDefaults

    private enum Keys {
        // Saved under their own names so a launch argument (which lives in the argument domain) never gets saved by accident.
        static let mode = "parchi.backend.mode"
        static let url = "parchi.backend.url"
        static let key = "parchi.backend.installKey"
    }

    init(store: UserDefaults = .standard, arguments: [String] = ProcessInfo.processInfo.arguments) {
        self.store = store
        var mode = BackendMode(rawValue: store.string(forKey: Keys.mode) ?? "") ?? .mock
        var url = store.string(forKey: Keys.url) ?? Self.defaultURL
        var key = store.string(forKey: Keys.key) ?? ""
        if let value = Self.argument("-backendMode", in: arguments), let parsed = BackendMode(rawValue: value.lowercased()) { mode = parsed }
        if let value = Self.argument("-backendURL", in: arguments) { url = value }
        if let value = Self.argument("-installKey", in: arguments) { key = value }
        self.mode = mode
        self.baseURL = url
        self.installKey = key
    }

    private static func argument(_ name: String, in arguments: [String]) -> String? {
        guard let i = arguments.firstIndex(of: name), arguments.indices.contains(i + 1) else { return nil }
        return arguments[i + 1]
    }

    /// nil when the saved URL is not a usable http(s) address.
    func makeClient() -> LiveClient? {
        LiveClient(baseURLString: baseURL, installKey: installKey)
    }
}
