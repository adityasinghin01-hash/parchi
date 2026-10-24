import SwiftUI

/// Preview/test aid: launch with `-fidelityScreen <name>` to show ONE screen as the whole app, so a screenshot can be compared with the
/// HTML render of the same route (`frontend/specs/web/<name>.png`). Names are the web routes:
///   welcome signin verify home area capture reading review plans plan-map get-all checkout track care pass history account ranking
/// Each job fills in ITS OWN group file (FidelityFE2.swift ... FidelityFE5.swift); this file only dispatches.
@MainActor
enum FidelityScreens {
    static func view(for name: String) -> AnyView? {
        FidelityFE2.view(name) ?? FidelityFE3.view(name) ?? FidelityFE4.view(name) ?? FidelityFE5.view(name)
    }
}
