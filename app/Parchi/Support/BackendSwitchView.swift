import SwiftUI

/// Collapsed "Developer" disclosure with the Mock | Live switch. Self-contained: mount it with one line.
struct BackendDeveloperPanel: View {
    @State private var expanded = UserDefaults.standard.bool(forKey: "backendPanelOpen")

    var body: some View {
        DisclosureGroup("Developer", isExpanded: $expanded) {
            BackendSwitchView()
                .padding(.top, 8)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(.bar)
    }
}

struct BackendSwitchView: View {
    @Environment(AppModel.self) private var model
    @State private var testing = false
    @State private var testResult: String?

    var body: some View {
        @Bindable var backend = model.backend
        VStack(alignment: .leading, spacing: 10) {
            Picker("Backend", selection: $backend.mode) {
                ForEach(BackendMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            if backend.mode == .live {
                TextField("Server URL", text: $backend.baseURL)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                SecureField("Install key", text: $backend.installKey)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                HStack {
                    Button(testing ? "Testing…" : "Test connection") { runTest() }
                        .buttonStyle(.bordered)
                        .disabled(testing)
                    if let testResult {
                        Text(testResult).foregroundStyle(testResult == "OK" ? .green : .red)
                    }
                }
            } else {
                Text("Demo mode: nothing leaves this phone.")
            }

            if let error = model.backendError {
                Text(error).foregroundStyle(.red)
            }
        }
        .font(.footnote)
    }

    private func runTest() {
        testing = true
        testResult = nil
        Task {
            let ok = await model.testConnection()
            testResult = ok ? "OK" : "Failed"
            testing = false
        }
    }
}
