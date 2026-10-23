import SwiftUI

/// Launch routes for screenshots and rehearsal: `-demoRoute history|care|settings|consent|rank|city`.
/// History and Care use an in-memory store seeded with sample parchis, so they never touch real saved data.
enum Phase4Route {
    @MainActor private static let demoHistory = HistoryStore.seedDemo()
    @MainActor private static let location = LocationProvider()

    @MainActor
    static func view(for name: String) -> AnyView? {
        switch name {
        case "history":
            return AnyView(NavigationStack { HistoryView(store: demoHistory) })
        case "care":
            return AnyView(NavigationStack { CareView(store: demoHistory) })
        case "settings":
            return AnyView(NavigationStack { SettingsView(history: demoHistory, backend: BackendSettings(), consent: ConsentStore()) })
        case "consent":
            return AnyView(FirstRunConsentView(consent: ConsentStore()))
        case "rank":
            return AnyView(NavigationStack { HowWeRankView() })
        case "city":
            return AnyView(NavigationStack { CityPickerView(location: location) })
        default:
            return nil
        }
    }
}
