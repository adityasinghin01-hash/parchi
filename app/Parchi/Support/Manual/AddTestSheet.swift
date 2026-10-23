import SwiftUI

/// K18: pick a test by hand from the canonical list (the same names the Confirm screen's test matching knows).
struct AddTestSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var names: [String] {
        let all = model.data.testCatalogue.tests.map(\.name).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        return Self.filter(all, query: query)
    }

    /// Case-insensitive "contains"; an empty query keeps everything.
    static func filter(_ names: [String], query: String) -> [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return names }
        return names.filter { $0.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Test name", text: $query)
                        .autocorrectionDisabled()
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("manualTestSearch")
                }
                Section {
                    ForEach(names, id: \.self) { name in
                        Button {
                            model.addManualTest(name: name)
                            dismiss()
                        } label: {
                            Text(name).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .accessibilityIdentifier("manualTest-\(name)")
                    }
                    if names.isEmpty {
                        Text("No test with that name in our list.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add a test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.frame(minHeight: 44)
                }
            }
        }
    }
}
