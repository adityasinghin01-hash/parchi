import SwiftUI

/// Small grey lines under a seller's price: reliability (A1) and reported real fees (A7). Shows nothing when there is no data.
struct SellerTrustLines: View {
    @Environment(AppModel.self) private var model
    let sellerID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let note = model.reliabilityNote(sellerID) { Text(note) }
            if let note = model.truePriceNote(sellerID) { Text(note) }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}

/// "What did you pay?" (A7): one optional number, saved only when the user taps Save.
struct TruePriceSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let sellerID: String
    @State private var text = ""
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Amount in ₹", text: $text).keyboardType(.numberPad)
                } header: {
                    Text("What did you pay \(model.sellerName(sellerID)) in total?")
                } footer: {
                    Text("Optional. We store only the amount, the seller and your city's PIN, never your name or phone.")
                }
                if let message { Section { Text(message).font(.subheadline) } }
            }
            .navigationTitle("Real price")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let rupees = Int(text.filter(\.isNumber)), rupees > 0 else { message = "Enter the amount in rupees."; return }
                        Task { message = await model.reportPaid(sellerID: sellerID, rupees: rupees) }
                    }
                }
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }
}
