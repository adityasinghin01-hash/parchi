import ParchiCore
import SwiftData
import SwiftUI

/// "Recent parchis" (S1 / gap U3). Mounted on Home by the integrator. Reads only what is saved on the phone.
struct HistoryView: View {
    let store: HistoryStore
    var body: some View {
        HistoryList()
            .modelContainer(store.container)
    }
}

private struct HistoryList: View {
    @Query(sort: \ParchiRecord.createdAt, order: .reverse) private var records: [ParchiRecord]

    var body: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView("No saved parchis yet", systemImage: "doc.text",
                                       description: Text("When you approve a plan it is saved here, on this phone."))
            } else {
                List(records) { record in
                    NavigationLink {
                        HistoryDetailView(record: record)
                    } label: {
                        HistoryRow(record: record)
                    }
                }
            }
        }
        .navigationTitle("Recent parchis")
    }
}

struct HistoryRow: View {
    let record: ParchiRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.title).font(.headline)
            Text(record.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline).foregroundStyle(.secondary)
            HStack {
                Text("\(record.medicineCount) medicines · \(record.testCount) tests")
                Spacer()
                Label(record.historyStatus.title, systemImage: record.historyStatus.symbol)
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
            .font(.subheadline)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// The saved plan, rebuilt from the stored JSON alone (no network, no catalogue).
struct HistoryDetailView: View {
    let record: ParchiRecord

    var body: some View {
        List {
            if let saved = record.savedPlan {
                Section("Total you pay") {
                    LabeledContent("Items", value: rupees(saved.plan.itemsTotal))
                    LabeledContent("Delivery and other fees", value: rupees(saved.plan.feesTotal))
                    LabeledContent("Everything") { Text(rupees(saved.plan.payable)).bold() }
                    LabeledContent("In-person trips", value: "\(saved.plan.stops)")
                }
                ForEach(saved.plan.sellerIDs, id: \.self) { sellerID in
                    Section(saved.sellerName(sellerID)) {
                        ForEach(saved.plan.lines.filter { $0.sellerID == sellerID }, id: \.itemID) { line in
                            LabeledContent(name(of: line.itemID), value: rupees(line.price))
                        }
                    }
                }
                if let slot = saved.labSlot {
                    Section("Lab slot") { Label(slot, systemImage: "calendar") }
                }
            } else {
                ContentUnavailableView("This saved plan can't be opened", systemImage: "exclamationmark.triangle")
            }
            Section {
                Label("Saved on this phone. It opens without internet.", systemImage: "iphone")
                    .font(.footnote).foregroundStyle(.secondary)
                if record.historyStatus != .planned {
                    Text("Test order only: nothing was bought.").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(record.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func name(of itemID: String) -> String {
        guard let item = record.items.first(where: { $0.item.id == itemID })?.item else { return itemID }
        return [item.name, item.strength].compactMap { $0 }.joined(separator: " ")
    }
}
