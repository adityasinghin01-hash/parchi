import ParchiCore
import SwiftUI

struct TrackView: View {
    @Environment(AppModel.self) private var model

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
                                Button("Simulate cancel", role: .destructive) { model.simulateCancel(sellerID: sellerID) }
                                    .buttonStyle(.bordered)
                            }
                        }
                        ForEach(plan.lines.filter { $0.sellerID == sellerID }, id: \.itemID) { line in
                            Text(model.itemName(line.itemID)).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            NavigationLink("What next? Doses and refills") { CareView(store: HistoryStore.shared) }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(.bar)
        }
        .navigationTitle("Track")
        .sheet(item: Binding(get: { model.planB.map(PlanBBox.init) }, set: { if $0 == nil { model.planB = nil } })) { box in
            PlanBSheet(proposal: box.proposal)
                .presentationDetents([.medium, .large])
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
                    Button("Approve") { model.approvePlanB(); dismiss() }
                        .disabled(!proposal.stillMissing.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Choose myself") { dismiss() }
                }
            }
        }
    }
}
