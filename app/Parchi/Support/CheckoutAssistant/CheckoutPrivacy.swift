import SwiftUI
import WebKit

/// Requirement U10: one tap signs the patient out of every seller site opened inside Parchi.
enum CheckoutPrivacy {
    @MainActor
    static func clearSellerSessions() async {
        let store = WKWebsiteDataStore.default()
        await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        HTTPCookieStorage.shared.removeCookies(since: .distantPast)
    }
}

/// Drop into Settings: `SignOutSellersRow()`.
struct SignOutSellersRow: View {
    @State private var confirming = false
    @State private var done = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button("Sign out of all sellers", role: .destructive) { confirming = true }
            Text(done ? "Done. Seller logins and carts opened in Parchi are cleared."
                      : "Clears logins and cookies of the seller websites you opened inside Parchi.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .confirmationDialog("Sign out of all seller websites?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                Task { await CheckoutPrivacy.clearSellerSessions(); done = true }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
