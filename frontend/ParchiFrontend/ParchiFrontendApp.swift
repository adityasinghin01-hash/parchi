import SwiftUI

@main
struct ParchiFrontendApp: App {
    @State private var completion: WelcomeChoice?

    var body: some Scene {
        WindowGroup {
            ReferenceWelcomeView { choice in
                // The next destination will follow the user's next reference.
                // No upload, account creation or health-data processing occurs here.
                if choice == .agree {
                    UserDefaults.standard.set(Date(), forKey: "parchi.reference.preferenceDate")
                }
                completion = choice
            }
            .alert(completion == .agree ? "Your preferences are saved" : "Continue as Guest",
                   isPresented: Binding(get: { completion != nil }, set: { if !$0 { completion = nil } })) {
                Button("OK", role: .cancel) { completion = nil }
            } message: {
                Text(completion == .agree ? "You’re ready to continue." : "You can use Parchi without creating an account.")
            }
        }
    }
}

enum WelcomeChoice { case agree, guest }
