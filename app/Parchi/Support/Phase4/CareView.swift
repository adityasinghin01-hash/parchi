import ParchiCore
import SwiftData
import SwiftUI

/// S7 Care: today's doses, refill dates, lab slot and report time, all from the latest approved parchi.
struct CareView: View {
    let store: HistoryStore
    var body: some View {
        CareContent()
            .modelContainer(store.container)
    }
}

/// One dose to tick off today.
struct DoseEntry: Identifiable, Hashable {
    let id: String          // recordID|itemID|slot
    let medicine: String
    let slot: DoseSlot
}

struct RefillEntry: Identifiable {
    let id: String
    let medicine: String
    /// nil = cannot tell (no readable schedule).
    let inDays: Int?
}

/// Pure planning of the Care screen, kept apart from the views so it is easy to reason about.
enum CarePlan {
    static func medicineName(_ item: RxItem) -> String { [item.name, item.strength].compactMap { $0 }.joined(separator: " ") }

    static func elapsedDays(since start: Date, now: Date, calendar: Calendar = .current) -> Int {
        max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: now)).day ?? 0)
    }

    static func doses(for record: ParchiRecord, now: Date) -> [DoseEntry] {
        let elapsed = elapsedDays(since: record.approvedAt ?? record.createdAt, now: now)
        var result: [DoseEntry] = []
        for saved in record.items where saved.item.kind == .medicine {
            guard let schedule = saved.schedule, let perDay = Doses.dosesPerDay(schedule: schedule), perDay > 0,
                  (Doses.daysLeft(quantity: saved.item.quantity, dosesPerDay: perDay, daysElapsed: elapsed) ?? 0) > 0 else { continue }
            for slot in Doses.doseSlots(schedule: schedule) {
                result.append(DoseEntry(id: "\(record.id)|\(saved.item.id)|\(slot.rawValue)", medicine: medicineName(saved.item), slot: slot))
            }
        }
        return result
    }

    static func refills(for record: ParchiRecord, now: Date) -> [RefillEntry] {
        let elapsed = elapsedDays(since: record.approvedAt ?? record.createdAt, now: now)
        return record.items.filter { $0.item.kind == .medicine }.map { saved in
            let perDay = saved.schedule.flatMap { Doses.dosesPerDay(schedule: $0) }
            return RefillEntry(id: saved.item.id, medicine: medicineName(saved.item),
                               inDays: Doses.refillInDays(quantity: saved.item.quantity, dosesPerDay: perDay, daysElapsed: elapsed))
        }
    }
}

private struct CareContent: View {
    @Query(sort: \ParchiRecord.createdAt, order: .reverse) private var records: [ParchiRecord]
    @State private var taken: Set<String> = []

    private var record: ParchiRecord? { records.first { $0.approvedAt != nil } }
    private var dayKey: String { "parchi.care.taken." + Date().formatted(.iso8601.year().month().day()) }

    var body: some View {
        List {
            if let record {
                let now = Date()
                let doses = CarePlan.doses(for: record, now: now)
                Section("Today's doses") {
                    if doses.isEmpty {
                        Text("No dose times could be read from this parchi.").foregroundStyle(.secondary)
                    }
                    ForEach(DoseSlot.allCases, id: \.self) { slot in
                        ForEach(doses.filter { $0.slot == slot }) { dose in
                            DoseRow(dose: dose, isTaken: taken.contains(dose.id)) { toggle(dose.id) }
                        }
                    }
                }
                Section("Refills") {
                    ForEach(CarePlan.refills(for: record, now: now)) { refill in
                        LabeledContent(refill.medicine) { Text(refillText(refill.inDays)).foregroundStyle(refill.inDays == 0 ? .red : .secondary) }
                    }
                    Text("Worked out from the quantity and schedule written on your parchi, minus 3 days. It is a reminder, not medical advice.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let saved = record.savedPlan, !saved.labSellers.isEmpty {
                    Section("Lab") {
                        ForEach(saved.labSellers, id: \.id) { lab in
                            Label(lab.name, systemImage: "testtube.2")
                        }
                        Label(saved.labSlot ?? "Slot not confirmed yet", systemImage: "calendar")
                        if saved.plan.reportsReadyMinutes > 0 {
                            let due = (record.approvedAt ?? record.createdAt).addingTimeInterval(TimeInterval(saved.plan.reportsReadyMinutes * 60))
                            Label("Report expected \(due.formatted(date: .abbreviated, time: .shortened))", systemImage: "doc.text")
                        }
                    }
                }
            } else {
                ContentUnavailableView("Nothing to track yet", systemImage: "pills",
                                       description: Text("Approve a plan and your doses and refill dates show up here."))
            }
        }
        .navigationTitle("Care")
        .onAppear { taken = Set(UserDefaults.standard.stringArray(forKey: dayKey) ?? []) }
    }

    private func toggle(_ id: String) {
        if taken.contains(id) { taken.remove(id) } else { taken.insert(id) }
        UserDefaults.standard.set(Array(taken), forKey: dayKey)   // local only; "parchi." prefix, wiped by Delete everything
    }

    private func refillText(_ days: Int?) -> String {
        guard let days else { return "Can't tell" }
        if days == 0 { return "Refill now" }
        return days == 1 ? "Refill in 1 day" : "Refill in \(days) days"
    }
}

private struct DoseRow: View {
    let dose: DoseEntry
    let isTaken: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isTaken ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isTaken ? Color.green : Color.secondary)
                Image(systemName: symbol).foregroundStyle(.secondary)
                VStack(alignment: .leading) {
                    Text(dose.medicine)
                    Text(label).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dose.medicine), \(label)")
        .accessibilityValue(isTaken ? "taken" : "not taken")
        .accessibilityAddTraits(.isButton)
    }

    private var label: String {
        switch dose.slot {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        }
    }

    private var symbol: String {
        switch dose.slot {
        case .morning: return "sunrise"
        case .afternoon: return "sun.max"
        case .evening: return "sunset"
        case .night: return "moon"
        }
    }
}
