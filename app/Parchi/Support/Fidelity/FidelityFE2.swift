import SwiftUI

/// Job FE2 fills this in. Return the REAL screen view for each web route this job owns (home, capture, reading, review), wrapped the way the app shows it
/// (inside a NavigationStack when it needs one, with `.artboardScaled()` at the root), or nil for any other name.
/// `FidelityScreens` calls it for `-fidelityScreen <route>`.
@MainActor
enum FidelityFE2 {
    static func view(_ name: String) -> AnyView? {
        switch name {
        // case "home": return AnyView(NavigationStack { HomeView(path: .constant([])) })
        default: return nil
        }
    }
}
