import ParchiCore
import SwiftUI

struct TrackView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var payingSeller: String?

    var body: some View {
        @Bindable var model = model
        List {
            if let plan = model.approvedPlan {
                Section {
                    Text("Total \(rupees(plan.payable))").font(.title2.bold())
                }
                ForEach(plan.sellerIDs, id: \.self) { sellerID in
                    Section(model.sellerName(sellerID)) {
                        HStack {
                            Label(model.statuses[sellerID]?.rawValue ?? "Placed", systemImage: "shippingbox")
                            Spacer()
                            if model.seller(sellerID)?.channel == .onlinePharmacy, model.statuses[sellerID] == .placed {
                                Button(role: .destructive) { model.simulateCancel(sellerID: sellerID) } label: {
                                    Text("Simulate cancel").frame(minHeight: 44)   // K24: tap area was 38 pt
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        ForEach(plan.lines.filter { $0.sellerID == sellerID }, id: \.itemID) { line in
                            Text(model.itemName(line.itemID)).font(.subheadline).foregroundStyle(.secondary)
                        }
                        SellerTrustLines(sellerID: sellerID)
                        Button { payingSeller = sellerID } label: {
                            Text("What did you pay?").frame(minHeight: 44, alignment: .leading)
                        }
                        .font(.footnote)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            NavigationLink { CareView(store: HistoryStore.shared) } label: {
                Text("What next? Doses and refills").frame(maxWidth: .infinity, minHeight: 44)   // K24: the whole bar is the link
            }
            .background(.bar)
            .accessibilityLabel("What next? Doses and refills")
        }
        .navigationTitle("Track")
        .sheet(isPresented: Binding(get: { payingSeller != nil }, set: { if !$0 { payingSeller = nil } })) {
            if let seller = payingSeller { TruePriceSheet(sellerID: seller).presentationDetents([.medium]) }
        }
        .sheet(item: Binding(get: { model.planB.map(PlanBBox.init) }, set: { if $0 == nil { model.planB = nil } })) { box in
            PlanBSheet(proposal: box.proposal)
                .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])   // K24: at big text the half sheet showed one line
        }
    }
}

/// Wraps the proposal so it can drive `.sheet(item:)`.
struct PlanBBox: Identifiable {
    let proposal: PlanBProposal
    var id: String { proposal.failedSellerID }
}

struct PlanBSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let proposal: PlanBProposal
    @State private var answered = false   // K24: two quick taps on Approve must not ask the server twice

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("\(model.sellerName(proposal.failedSellerID)) cancelled \(proposal.rerouted.count + proposal.stillMissing.count) items.")
                        .font(.headline)
                }
                if proposal.stillMissing.isEmpty {
                    Section("Plan B") {
                        ForEach(proposal.rerouted, id: \.itemID) { line in
                            HStack {
                                Text(model.itemName(line.itemID))
                                Spacer()
                                Text(model.sellerName(line.sellerID)).foregroundStyle(.secondary)
                            }
                        }
                        Text("Extra cost \(rupees(proposal.extraCost)). Everything else stays as it is.")
                            .font(.subheadline)
                    }
                } else {
                    Text("No other seller has \(proposal.stillMissing.map(model.itemName).joined(separator: ", ")). Ask your doctor or chemist.")
                }
            }
            .navigationTitle("Plan B")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Approve") {
                        guard !answered else { return }
                        answered = true
                        model.approvePlanB(); dismiss()
                    }
                    .disabled(!proposal.stillMissing.isEmpty || answered)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Choose myself") { dismiss() }
                }
            }
        }
    }
}
