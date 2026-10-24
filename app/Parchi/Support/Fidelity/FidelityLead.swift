import SwiftUI

/// The lead's route group: every web route drawn natively from its measured HTML spec (`WebSpecScreen`), for exact visual preview.
@MainActor
enum FidelityLead {
    static let routes = ["welcome", "signin", "verify", "home", "area", "capture", "reading", "review", "plans", "plan-map", "get-all", "checkout", "track", "care", "pass", "history", "account", "ranking"]
    static func view(_ name: String) -> AnyView? {
        guard routes.contains(name) || (name.hasPrefix("web-") && routes.contains(String(name.dropFirst(4)))) else { return nil }
        return AnyView(WebSpecScreen(route: name.hasPrefix("web-") ? String(name.dropFirst(4)) : name))
    }
}
