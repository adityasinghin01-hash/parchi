import SwiftUI

/// K18: type a medicine in. Plain system components on purpose (the team's design replaces the look); all behaviour is here.
struct AddMedicineSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var index: ManualBrandIndex?
    @State private var loadFinished = false
    @State private var query = ""
    @State private var chosenName: String?
    @State private var strengths: [String] = []
    @State private var strength: String?
    @State private var typedStrength = ""
    @State private var quantity = 10

    private var suggestions: [String] { index?.suggestions(for: query) ?? [] }
    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            List {
                if let name = chosenName {
                    details(name)
                } else {
                    search
                }
            }
            .navigationTitle("Add a medicine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.frame(minHeight: 44)
                }
            }
            .task {
                index = await ManualBrandStore.shared.load()
                loadFinished = true
            }
        }
    }

    // MARK: Step 1: search

    @ViewBuilder private var search: some View {
        Section {
            TextField("Medicine name", text: $query)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .frame(minHeight: 44)
                .accessibilityIdentifier("manualMedicineSearch")
        }
        if !loadFinished {
            Section {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading...")
                }
            }
        } else if index == nil {
            Section {
                Text("The medicine list could not be loaded. You can still add the name as you typed it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        if !suggestions.isEmpty {
            Section("Suggestions") {
                ForEach(suggestions, id: \.self) { brand in
                    Button {
                        choose(ManualBrandIndex.displayName(forBrand: brand))
                    } label: {
                        Text(ManualBrandIndex.displayName(forBrand: brand))
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .accessibilityIdentifier("manualSuggestion-\(brand)")
                }
            }
        }
        if !trimmedQuery.isEmpty, loadFinished, !suggestions.contains(ManualBrandIndex.key(for: trimmedQuery)) {
            Section {
                Button {
                    choose(trimmedQuery)
                } label: {
                    Text("Add \"\(trimmedQuery)\" as typed")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .accessibilityIdentifier("manualAddAsTyped")
            } footer: {
                if index?.contains(brand: trimmedQuery) != true {
                    Text("We don't have this name. You can still add it; the next screen will ask you to check it.")
                }
            }
        }
    }

    private func choose(_ name: String) {
        chosenName = name
        if let index {
            strengths = model.manualStrengthChoices(brand: name, index: index)
        } else {
            strengths = []
        }
        strength = strengths.count == 1 ? strengths.first : nil
    }

    // MARK: Step 2: strength, quantity, Add

    @ViewBuilder private func details(_ name: String) -> some View {
        Section {
            HStack {
                Text(name).font(.headline)
                Spacer()
                Button("Change") { chosenName = nil }.frame(minWidth: 44, minHeight: 44)
            }
        }
        Section("Strength") {
            if strengths.isEmpty {
                TextField("Strength (number, if written)", text: $typedStrength)
                    .keyboardType(.decimalPad)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("manualStrengthField")
            } else {
                ForEach(strengths, id: \.self) { value in
                    Button {
                        strength = value
                    } label: {
                        HStack {
                            Text(value)
                            Spacer()
                            if strength == value { Image(systemName: "checkmark").accessibilityHidden(true) }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .accessibilityLabel(value)
                    .accessibilityAddTraits(strength == value ? .isSelected : [])
                    .accessibilityIdentifier("manualStrength-\(value)")
                }
            }
        }
        Section {
            HStack {
                Stepper("Tablets / units", value: $quantity, in: 1...1000)
                    .accessibilityValue("\(quantity)")
                    .accessibilityIdentifier("manualQuantity")
                Text("\(quantity)").monospacedDigit().font(.title3.bold()).accessibilityHidden(true)
            }
            .frame(minHeight: 44)
        }
        Section {
            Button {
                let written = strengths.isEmpty ? typedStrength : strength
                model.addManualMedicine(name: name, strength: written, quantity: quantity)
                dismiss()
            } label: {
                Text("Add").font(.headline).frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!strengths.isEmpty && strength == nil)
            .accessibilityIdentifier("manualAdd")
        } footer: {
            if !strengths.isEmpty && strength == nil { Text("Choose the strength written on the parchi.") }
        }
    }
}
