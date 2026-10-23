import ParchiCore
import SwiftUI

/// Plan screen: List (today's screen, unchanged) | Map (K14: price pins, shop list, shop sheet).
struct PlanView: View {
    enum Mode: String { case list, map }

    @Environment(AppModel.self) private var model
    @Binding var path: [Route]
    /// Launch aid: `-planView map` opens the Map tab.
    @State private var mode: Mode = Mode(rawValue: UserDefaults.standard.string(forKey: "planView") ?? "") ?? .list

    var body: some View {
        Group {
            switch mode {
            case .list: PlanListContent()
            case .map: PlanMapView()
            }
        }
        .navigationTitle("Your plan")
        .shopLabActions()
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("Plan view", selection: $mode) {
                Text("List").tag(Mode.list)
                Text("Map").tag(Mode.map)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
            .accessibilityIdentifier("planViewPicker")
        }
        .safeAreaInset(edge: .bottom) {
            Button { guard path.last != .getItAll else { return }; path.append(.getItAll) } label: {
                Text("Get it all").font(.headline).frame(maxWidth: .infinity, minHeight: 50).barButtonText()
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.plan == nil)
            .padding()
            .background(.bar)
        }
    }
}

/// The list side of the Plan screen: whole-plan card, one section per seller, labs, Jan Aushadhi note.
private struct PlanListContent: View {
    @Environment(AppModel.self) private var model

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
                                PriceSourceChip(source: model.priceSource(sellerID: sellerID, itemID: line.itemID))
                                if let pack = model.cataloguePackText(itemID: line.itemID) {
                                    Text(pack).font(.caption).foregroundStyle(.secondary)
                                }
                                SellerTrustLines(sellerID: sellerID)
                                if let message = model.inPersonMessage(itemID: line.itemID) {
                                    Text(message).font(.caption).foregroundStyle(Color.parchiWarning)
                                }
                                if let ask = model.janAushadhiLine(itemID: line.itemID) {
                                    Text(ask)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .accessibilityIdentifier("janAushadhiAsk-\(line.itemID)")
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
                if !model.testsOutsidePlan.isEmpty {
                    Section {
                        Text("Lab tests are priced lab by lab below. They are not part of the total above.").font(.subheadline)
                    }
                }
                LabPricesSection()
                if model.janAushadhiMedicines > 0 {
                    Section("Ask your doctor") {
                        Text("The same salts cost \(rupees(model.janAushadhiMedicines)) at Jan Aushadhi instead of \(rupees(model.janAushadhiComparedMRP)) at MRP. Only your doctor can approve a switch; Parchi never changes a medicine on its own.")
                            .font(.subheadline)
                    }
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
                VStack(alignment: .leading, spacing: 6) {
                    let elsewhere = model.unavailable.filter { !model.catalogueMisses.contains($0) }
                    if !elsewhere.isEmpty {
                        Text("Not available anywhere: \(elsewhere.map(model.itemName).joined(separator: ", "))")
                    } else if model.catalogueMisses.isEmpty && model.scenario.items.isEmpty && !model.testsOutsidePlan.isEmpty {
                        Text("This parchi has only lab tests. Their prices are shown lab by lab below.")
                    } else if model.catalogueMisses.isEmpty {
                        Text("No complete plan found.")
                    }
                    if !model.catalogueMisses.isEmpty {
                        Text("No catalogue price found yet for \(model.catalogueMisses.map { id in model.catalogueMissReason(itemID: id).map { "\(model.itemName(id)) (\($0))" } ?? model.itemName(id) }.joined(separator: ", ")). Check the name and strength on the previous screen, or ask the shop.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if !model.testsOutsidePlan.isEmpty {   // lab tests are priced lab by lab even when there is no medicine plan
                    LabPricesSection()
                }
            }
        }
    }
}
