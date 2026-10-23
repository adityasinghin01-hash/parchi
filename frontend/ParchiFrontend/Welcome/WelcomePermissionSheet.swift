import SwiftUI

struct WelcomePermissionSheet: View {
    let permission: WelcomePermission
    @Bindable var store: WelcomePermissionStore
    @AppStorage("parchi.reference.usageOptIn") private var usageOptIn = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ReferencePermissionIcon(kind: permission).frame(width: 58, height: 58)
                    Text(permission.title).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    Text(explanation).font(.body).foregroundStyle(WelcomeAppearance.secondary)
                    switch permission {
                    case .location:
                        permissionButton("Allow location access") { store.requestLocation() }
                    case .camera:
                        permissionButton("Allow camera access") { Task { await store.requestCamera() } }
                        permissionButton("Choose photo access") { Task { await store.requestPhotos() } }
                    case .notifications:
                        permissionButton("Allow notifications") { Task { await store.requestNotifications() } }
                    case .usage:
                        Toggle("Share usage data", isOn: $usageOptIn)
                            .tint(WelcomeAppearance.orange).accessibilityIdentifier("welcome.usage.toggle")
                        Text("Optional and off by default. This build stores your preference only; it does not collect or send analytics.")
                            .font(.footnote).foregroundStyle(WelcomeAppearance.secondary)
                    }
                    if !store.status.isEmpty {
                        Text(store.status).font(.subheadline).foregroundStyle(WelcomeAppearance.secondary)
                            .accessibilityIdentifier("welcome.permission.status")
                    }
                }.padding(24)
            }
            .background(WelcomeAppearance.cream).foregroundStyle(WelcomeAppearance.brown)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.tint(WelcomeAppearance.orange)
                }
            }
            .onAppear { store.status = "" }
        }.preferredColorScheme(.light)
    }

    private var explanation: String {
        switch permission {
        case .location: return "Use your area to find nearby pharmacies and labs. You can continue without allowing location and choose an area manually later."
        case .camera: return "Choose how you want to share a prescription. Camera and photo access can be managed separately, and you can change either permission later."
        case .notifications: return "Allow reminders for medicines, tests and important updates. You can continue with notifications off."
        case .usage: return "Choose whether you want to help improve the Parchi experience. This preference is optional and does not affect guest access."
        }
    }

    private func permissionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.body.weight(.semibold))
                Spacer()
                if store.busy { ProgressView().tint(WelcomeAppearance.card) }
            }
            .padding(16).frame(minHeight: 52)
            .foregroundStyle(WelcomeAppearance.card)
            .background(WelcomeAppearance.orange, in: RoundedRectangle(cornerRadius: 15))
        }.buttonStyle(.plain).disabled(store.busy)
    }
}
