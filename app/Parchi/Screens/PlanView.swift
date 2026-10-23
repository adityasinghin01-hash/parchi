import ParchiCore
import SwiftUI

struct PlanView: View {
    @Environment(AppModel.self) private var model
    @Binding var path: [Route]

    var body: some View {
        @Bindable var model = model
        List {
            if let plan = model.plan {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Everything \(rupees(plan.payable))")
                            .font(.title.bold())
                        Text("Medicines \(readyText(minutes: plan.medicinesReadyMinutes)) · reports \(readyText(minutes: plan.reportsReadyMinutes)) · \(plan.stops) trips")
                            .foregroundStyle(.secondary)
                        let saved = model.medicinesAtMRP - model.planMedicinesTotal
                        if saved > 0 {
                            Text("Medicines cost \(rupees(saved)) less than MRP at the doctor's shop (\(rupees(model.medicinesAtMRP))).")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 4)
                    Picker("Plan for", selection: $model.objective) {
                        Text("Cheapest").tag(Objective.cheapest)
                        Text("Fastest").tag(Objective.fastest)
                        Text("No trips").tag(Objective.fewestStops)
                    }
                    .pickerStyle(.segmented)
                }
                ForEach(plan.sellerIDs, id: \.self) { sellerID in
                    Section(model.sellerName(sellerID)) {
                        ForEach(plan.lines.filter { $0.sellerID == sellerID }, id: \.itemID) { line in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(model.itemName(line.itemID))
                                    Spacer()
                                    Text(rupees(line.price)).monospacedDigit()
                                }
                                PriceSourceChip(source: model.priceSource(sellerID: sellerID))
                                if let message = model.inPersonMessage(itemID: line.itemID) {
                                    Text(message).font(.caption).foregroundStyle(.orange)
                                }
                            }
                        }
                        if let fee = plan.feesBySeller[sellerID], fee > 0 {
                            HStack {
                                Text("Fees (delivery / handling / collection)").foregroundStyle(.secondary)
                                Spacer()
                                Text(rupees(fee)).monospacedDigit()
                            }
                        }
                    }
                }
                LabPricesSection()
                Section("Ask your doctor") {
                    Text("The same salts cost \(rupees(model.janAushadhiMedicines)) at Jan Aushadhi instead of \(rupees(model.medicinesAtMRP)) at MRP. Only your doctor can approve a switch; Parchi never changes a medicine on its own.")
                        .font(.subheadline)
                }
                Section {
                    Text("Prices captured 23 Oct 2026 (MedScanner, Jan Aushadhi PMBI list, lab price pages). We rank by total price, then time, then trips. No seller pays to appear higher.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    NavigationLink("How we rank") { HowWeRankView() }
                    NavigationLink {
                        CityPickerView(location: model.location)
                    } label: {
                        LabeledContent("Searching around", value: model.location.centre.name)
                    }
                }
            } else {
                Text(model.unavailable.isEmpty ? "No complete plan found." : "Not available anywhere: \(model.unavailable.map(model.itemName).joined(separator: ", "))")
            }
        }
        .navigationTitle("Your plan")
        .shopLabActions()
        .safeAreaInset(edge: .bottom) {
            Button { path.append(.getItAll) } label: {
                Text("Get it all").font(.headline).frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.plan == nil)
            .padding()
            .background(.bar)
        }
    }
}
