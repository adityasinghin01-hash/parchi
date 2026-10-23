import SwiftUI

/// S10 Settings and privacy.
struct SettingsView: View {
    let history: HistoryStore
    let backend: BackendSettings
    let consent: ConsentStore
    /// Clears seller website logins (the integrator passes `CheckoutPrivacy.clearSellerSessions`).
    var onClearSellerSessions: () -> Void
    /// Optional extra reset for the demo (hidden row).
    var onDemoReset: (() -> Void)?

    @AppStorage("parchi.language") private var language = "en"
    @AppStorage("parchi.address") private var address = ""
    @AppStorage("parchi.autoApproveCapPaise") private var capPaise = 0

    @State private var confirmingDelete = false
    @State private var working = false
    @State private var deleteResult: ResetClient.Outcome?
    @State private var deletedLocally = false
    @State private var versionTaps = 0
    @State private var demoResetDone = false

    init(history: HistoryStore, backend: BackendSettings, consent: ConsentStore,
         onClearSellerSessions: @escaping () -> Void = {}, onDemoReset: (() -> Void)? = nil) {
        self.history = history
        self.backend = backend
        self.consent = consent
        self.onClearSellerSessions = onClearSellerSessions
        self.onDemoReset = onDemoReset
    }

    var body: some View {
        Form {
            Section("Language") {
                Picker("Language", selection: $language) {
                    Text("English").tag("en")
                    Text("हिन्दी").tag("hi")
                    Text("Hinglish").tag("hinglish")
                }
            }

            Section {
                TextField("House, street, area, city", text: $address, axis: .vertical)
                    .textContentType(.fullStreetAddress)
                    .lineLimit(1...4)
            } header: {
                Text("Saved address")
            } footer: {
                Text("Stays on this phone. Do not enter your name or phone number. It is used only to fill lab and shop messages.")
            }

            Section {
                Stepper(value: capRupees, in: 0...500, step: 10) {
                    Text(capPaise == 0 ? "Always ask me first" : "Auto-approve up to ₹\(capPaise / 100) extra")
                }
            } header: {
                Text("Plan B")
            } footer: {
                Text("If a seller cancels, Parchi can approve a replacement plan that costs at most this much more. Above it, you decide.")
            }

            Section("Privacy") {
                LabeledContent("Your agreement", value: consent.summary)
                NavigationLink("How accurate is Parchi?") { AccuracyView() }
                NavigationLink("How we rank") { HowWeRankView() }
            }

            Section {
                SignOutSellersRow()
            }

            Section {
                Button("Delete everything", role: .destructive) { confirmingDelete = true }
                    .disabled(working)
                if working { ProgressView("Deleting…") }
                if deletedLocally {
                    Label("Everything on this phone is deleted.", systemImage: "checkmark.circle")
                }
                if let deleteResult {
                    Text(deleteResult.message).font(.footnote)
                    if deleteResult.needsRetry {
                        Button("Try the server again") { Task { await retryServer() } }
                    }
                }
            } footer: {
                Text("Deletes saved parchis, doses, settings, your agreement, photo crops and seller logins on this phone, and asks our lab server to delete this phone's test orders.")
            }

            Section {
                Text("Version \(versionText)")
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                    .onTapGesture { versionTaps += 1 }
                    .accessibilityHint("Tap seven times for the demo reset")
                if versionTaps >= 7 {
                    Button("Demo reset") { demoReset() }
                    if demoResetDone { Text("Demo data restored.").font(.footnote).foregroundStyle(.secondary) }
                }
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Delete everything?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) { Task { await deleteEverything() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. Your saved parchis and settings will be gone.")
        }
    }

    private var capRupees: Binding<Int> {
        Binding(get: { capPaise / 100 }, set: { capPaise = max(0, $0) * 100 })
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "0") (\(info?["CFBundleVersion"] as? String ?? "0"))"
    }

    private func deleteEverything() async {
        working = true
        deleteResult = nil
        let outcome = await EraseEverything.run(history: history, reset: ResetClient(settings: backend), onClearSellerSessions: onClearSellerSessions)
        consent.reload()
        deletedLocally = true
        deleteResult = outcome
        working = false
    }

    private func retryServer() async {
        working = true
        deleteResult = await ResetClient(settings: backend).reset()
        working = false
    }

    private func demoReset() {
        history.deleteAll()
        history.fillDemo()
        onDemoReset?()
        demoResetDone = true
    }
}

/// "How accurate is Parchi?" Only numbers from CONTEXT.md "Key measured numbers" (raw data in docs/research/evidence/).
struct AccuracyView: View {
    var body: some View {
        List {
            Section {
                row("Reading handwriting with Apple's built-in text reader (100 real handwritten parchis, MIRAGE-100)", "26.3% of medicine names found · 12.8% of what it found was right")
                row("A large AI model, tested blind on 16 parchis", "82.1% found · 87.3% right")
                row("Our own reader before training (Qwen2.5-VL-3B, first 30 MIRAGE parchis)", "13.6% found · 26.2% right · about 20 seconds per parchi")
                row("Hiding the patient's name (300 synthetic parchis)", "98.3% hidden")
                row("Hiding the patient's name (12 real parchi photos)", "12 of 12 hidden")
            } header: {
                Text("What we measured")
            } footer: {
                Text("No number is measured yet for our trained reader, so none is shown. Source: CONTEXT.md, “Key measured numbers”; raw data in docs/research/evidence/.")
            }
            Section {
                Text("Handwriting is hard to read, which is why you check every line on the Confirm screen before any plan is made. When Parchi is unsure about a brand and strength, it asks you instead of guessing.")
            } header: {
                Text("What this means for you")
            }
        }
        .navigationTitle("How accurate is Parchi?")
    }

    private func row(_ what: String, _ result: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(what)
            Text(result).font(.headline)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
