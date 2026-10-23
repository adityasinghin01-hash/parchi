import Foundation
import Observation
import ParchiCore

/// Same shape as engine/scenarios/*.json (the files the parchi-plan CLI reads).
struct Scenario: Codable {
    var title: String
    var items: [RxItem]
    var sellers: [Seller]
    var offers: [Offer]
    var preferences: Preferences
    var simulateFailure: FailureSpec?

    struct FailureSpec: Codable {
        var sellerID: String
        var failure: Failure
    }
}

/// One line as the reader returned it, plus the brand–strength check result.
struct ReadLine: Identifiable {
    let id: String
    var item: RxItem
    var check: CheckResult?

    var needsAnswer: Bool {
        switch check {
        case .strengthMismatch, .unknownBrand: return true
        default: return false
        }
    }
}

enum OrderStatus: String {
    case placed = "Placed", rerouted = "Re-routed (Plan B)", cancelled = "Cancelled by seller"
}

@MainActor
@Observable
final class AppModel {
    private(set) var scenario: Scenario
    let catalogue: Catalogue

    var lines: [ReadLine] = []
    var objective: Objective = .cheapest { didSet { replan() } }
    private(set) var plan: Plan?
    private(set) var approvedPlan: Plan?
    private(set) var statuses: [String: OrderStatus] = [:]
    var planB: PlanBProposal?

    init() {
        scenario = Self.load("real_basket_cheapest")
        catalogue = Self.loadCatalogue()
    }

    // MARK: Reading (mock until Aditya Singhal's /read server is on the iMac)

    /// Simulates the reader on the demo parchi, with one realistic misread ("Telma 400").
    func readDemoParchi() {
        lines = scenario.items.map { item in
            var read = item
            if item.id == "telma" { read.strength = "400" }
            return ReadLine(id: item.id, item: read, check: check(read))
        }
        plan = nil
        approvedPlan = nil
        statuses = [:]
        planB = nil
    }

    func choose(strength: String, for lineID: String) {
        guard let i = lines.firstIndex(where: { $0.id == lineID }) else { return }
        lines[i].item.strength = strength
        lines[i].check = check(lines[i].item)
    }

    /// Catalogue keys are the first word of a product name ("Montair-LC" → MONTAIRLC, "Glycomet 500 SR" → GLYCOMET),
    /// so try the whole written name first, then its first word.
    private func check(_ item: RxItem) -> CheckResult? {
        guard item.kind == .medicine else { return nil }
        let whole = catalogue.check(brand: item.name, strength: item.strength)
        guard case .unknownBrand = whole, let first = item.name.split(separator: " ").first, first.count < item.name.count else { return whole }
        let byFirstWord = catalogue.check(brand: String(first), strength: item.strength)
        if case .unknownBrand = byFirstWord { return whole }
        return byFirstWord
    }

    var allConfirmed: Bool { !lines.contains(where: \.needsAnswer) }

    // MARK: Planning

    func confirmList() {
        scenario.items = lines.map(\.item)
        replan()
    }

    private var planner: Planner {
        var prefs = scenario.preferences
        prefs.objective = objective
        return Planner(items: scenario.items, sellers: scenario.sellers, offers: scenario.offers, preferences: prefs)
    }

    func replan() {
        guard !lines.isEmpty else { return }
        plan = planner.best()
    }

    var unavailable: [String] { planner.unavailableItems() }

    /// What the medicines cost at MRP at the doctor's shop (the patient's default today).
    var medicinesAtMRP: Paise {
        let medicineIDs = Set(scenario.items.filter { $0.kind == .medicine }.map(\.id))
        return scenario.offers.filter { $0.sellerID == "doctorshop" && medicineIDs.contains($0.itemID) }.map(\.price).reduce(0, +)
    }

    var planMedicinesTotal: Paise {
        guard let plan else { return 0 }
        let medicineIDs = Set(scenario.items.filter { $0.kind == .medicine }.map(\.id))
        return plan.lines.filter { medicineIDs.contains($0.itemID) }.map(\.price).reduce(0, +)
    }

    /// Same-salt Jan Aushadhi total, shown only as "ask your doctor" (never applied automatically).
    var janAushadhiMedicines: Paise {
        scenario.offers.filter { $0.sellerID == "janaushadhi" && $0.isSubstitute }.map(\.price).reduce(0, +)
    }

    // MARK: Orders + Plan B (sandbox)

    func placeTestOrders() {
        approvedPlan = plan
        statuses = Dictionary(uniqueKeysWithValues: (plan?.sellerIDs ?? []).map { ($0, OrderStatus.placed) })
    }

    func simulateCancel(sellerID: String) {
        guard let approved = approvedPlan else { return }
        statuses[sellerID] = .cancelled
        planB = PlanB(planner: planner).reroute(approved: approved, failedSellerID: sellerID, failure: .cancelled)
    }

    func approvePlanB() {
        guard let proposal = planB else { return }
        approvedPlan = proposal.newPlan
        plan = proposal.newPlan
        for line in proposal.rerouted { statuses[line.sellerID] = .rerouted }
        planB = nil
    }

    // MARK: Names

    func sellerName(_ id: String) -> String { scenario.sellers.first { $0.id == id }?.name ?? id }
    func seller(_ id: String) -> Seller? { scenario.sellers.first { $0.id == id } }
    func itemName(_ id: String) -> String {
        guard let item = scenario.items.first(where: { $0.id == id }) else { return id }
        return [item.name, item.strength].compactMap { $0 }.joined(separator: " ")
    }

    // MARK: Loading

    private static func load(_ name: String) -> Scenario {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let scenario = try? JSONDecoder().decode(Scenario.self, from: data) else {
            fatalError("Missing or invalid \(name).json in the app bundle")
        }
        return scenario
    }

    private static func loadCatalogue() -> Catalogue {
        guard let url = Bundle.main.url(forResource: "brand_strengths", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let map = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return Catalogue(strengths: [:])
        }
        return Catalogue(strengths: map.mapValues(Set.init))
    }
}
