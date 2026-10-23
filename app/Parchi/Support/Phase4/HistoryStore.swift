import Foundation
import ParchiCore
import SwiftData

/// One saved parchi (gap U3). Everything needed to show the plan again lives in these fields, so reopening works with Wi-Fi off.
@Model
final class ParchiRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var title: String
    /// JSON of `[SavedItem]`.
    var itemsJSON: Data
    /// JSON of `SavedPlan`.
    var planJSON: Data
    var approvedAt: Date?
    /// Raw value of `HistoryStatus`.
    var status: String

    init(id: UUID = UUID(), createdAt: Date, title: String, itemsJSON: Data, planJSON: Data, approvedAt: Date?, status: HistoryStatus) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.itemsJSON = itemsJSON
        self.planJSON = planJSON
        self.approvedAt = approvedAt
        self.status = status.rawValue
    }

    var historyStatus: HistoryStatus { HistoryStatus(rawValue: status) ?? .planned }
    var items: [SavedItem] { (try? JSONDecoder().decode([SavedItem].self, from: itemsJSON)) ?? [] }
    var savedPlan: SavedPlan? { try? JSONDecoder().decode(SavedPlan.self, from: planJSON) }
    var medicineCount: Int { items.filter { $0.item.kind == .medicine }.count }
    var testCount: Int { items.filter { $0.item.kind == .test }.count }
}

enum HistoryStatus: String, Codable {
    case planned, ordered, done

    var title: String {
        switch self {
        case .planned: return "Planned"
        case .ordered: return "Test order placed"
        case .done: return "Done"
        }
    }

    var symbol: String {
        switch self {
        case .planned: return "list.bullet.clipboard"
        case .ordered: return "shippingbox"
        case .done: return "checkmark.circle"
        }
    }
}

/// A confirmed line plus the schedule exactly as written on the parchi ("1-0-1", "BD"), nil for tests or when unreadable.
struct SavedItem: Codable, Hashable {
    var item: RxItem
    var schedule: String?
}

struct SavedSeller: Codable, Hashable {
    var id: String
    var name: String
    var channel: Channel
}

/// The approved plan plus seller names, so the saved screen needs no catalogue.
struct SavedPlan: Codable, Hashable {
    var plan: Plan
    var sellers: [SavedSeller]
    /// Confirmed lab slot as text ("Tomorrow, 7:30 am"), only when one exists.
    var labSlot: String?

    func sellerName(_ id: String) -> String { sellers.first { $0.id == id }?.name ?? id }
    var labSellers: [SavedSeller] { sellers.filter { $0.channel == .lab && plan.sellerIDs.contains($0.id) } }
}

@MainActor
final class HistoryStore {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    /// `inMemory: true` for tests and demo seeding: nothing touches the disk.
    init(inMemory: Bool = false) throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(for: ParchiRecord.self, configurations: configuration)
    }

    /// The on-disk store the app uses. If the disk store cannot open, history falls back to memory for this run.
    static let shared: HistoryStore = {
        if let store = try? HistoryStore() { return store }
        // An in-memory container only fails if SwiftData itself is broken; nothing sensible is left to do then.
        return try! HistoryStore(inMemory: true) // swiftlint:disable:this force_try
    }()

    /// Call when the patient approves a plan. `items` are the confirmed lines with their schedules.
    @discardableResult
    func saveApproved(title: String, items: [SavedItem], plan: Plan, sellers: [Seller], labSlot: String? = nil,
                      status: HistoryStatus = .ordered, now: Date = Date()) -> ParchiRecord? {
        let ids = Set(plan.sellerIDs)
        let saved = SavedPlan(plan: plan,
                              sellers: sellers.filter { ids.contains($0.id) }.map { SavedSeller(id: $0.id, name: $0.name, channel: $0.channel) },
                              labSlot: labSlot)
        guard let itemsJSON = try? JSONEncoder().encode(items), let planJSON = try? JSONEncoder().encode(saved) else { return nil }
        let record = ParchiRecord(createdAt: now, title: title, itemsJSON: itemsJSON, planJSON: planJSON, approvedAt: now, status: status)
        context.insert(record)
        try? context.save()
        return record
    }

    func update(_ record: ParchiRecord, status: HistoryStatus) {
        record.status = status.rawValue
        try? context.save()
    }

    /// Newest first.
    func all() -> [ParchiRecord] {
        let descriptor = FetchDescriptor<ParchiRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func delete(_ record: ParchiRecord) {
        context.delete(record)
        try? context.save()
    }

    func deleteAll() {
        for record in all() { context.delete(record) }
        try? context.save()
    }

    // MARK: Demo

    /// An in-memory store with two sample parchis (clearly sample data), for screenshots and rehearsal.
    static func seedDemo(now: Date = Date()) -> HistoryStore {
        let store = (try? HistoryStore(inMemory: true)) ?? HistoryStore.shared
        store.fillDemo(now: now)
        return store
    }

    /// Adds the demo parchis to this store (also used by the hidden demo reset in Settings).
    func fillDemo(now: Date = Date()) {
        let demo = DemoBasket.load()
        let schedules: [String: String] = ["pan": "1-0-0", "telma": "OD", "glycomet": "1-0-1", "azithral": "OD", "montair": "0-0-1"]
        let items = demo.items.map { SavedItem(item: $0, schedule: schedules[$0.id]) }
        if let plan = Planner(items: demo.items, sellers: demo.sellers, offers: demo.offers, preferences: demo.preferences).best() {
            saveApproved(title: "Sample parchi: general check-up", items: items, plan: plan, sellers: demo.sellers,
                                      labSlot: "Tomorrow, 7:30 am (sample)", status: .ordered, now: now.addingTimeInterval(-2 * 86_400))
        }
        let older = Array(demo.items.prefix(2))
        if let plan = Planner(items: older, sellers: demo.sellers, offers: demo.offers, preferences: demo.preferences).best() {
            saveApproved(title: "Sample parchi: fever", items: older.map { SavedItem(item: $0, schedule: $0.id == "dolo" ? "TDS" : "OD") },
                                      plan: plan, sellers: demo.sellers, status: .done, now: now.addingTimeInterval(-12 * 86_400))
        }
        try? context.save()
    }
}

/// The bundled real-price basket, decoded with the engine's own types so this file does not depend on AppModel.
struct DemoBasket {
    var items: [RxItem]
    var sellers: [Seller]
    var offers: [Offer]
    var preferences: Preferences

    private struct File: Decodable {
        var items: [RxItem]
        var sellers: [Seller]
        var offers: [Offer]
        var preferences: Preferences
    }

    static func load() -> DemoBasket {
        if let url = Bundle.main.url(forResource: "real_basket_cheapest", withExtension: "json"),
           let data = try? Data(contentsOf: url), let file = try? JSONDecoder().decode(File.self, from: data) {
            return DemoBasket(items: file.items, sellers: file.sellers, offers: file.offers, preferences: file.preferences)
        }
        // Tiny fallback so previews and tests still have something to show. Sample numbers, not measured data.
        let items = [RxItem(id: "dolo", kind: .medicine, name: "Dolo", strength: "650", quantity: 15),
                     RxItem(id: "pan", kind: .medicine, name: "Pan", strength: "40", quantity: 15)]
        let shop = Seller(id: "shop", name: "Sample chemist", channel: .localChemist, etaMinutes: 0, requiresVisit: true)
        let offers = items.map { Offer(itemID: $0.id, sellerID: "shop", price: 10_000) }
        return DemoBasket(items: items, sellers: [shop], offers: offers, preferences: Preferences())
    }
}
