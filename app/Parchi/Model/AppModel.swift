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

    // Live backend (all unused while mode == .mock)
    let backend = BackendSettings()
    /// Plain-language problem with the server, shown in the Developer panel. nil = all fine.
    var backendError: String?
    private(set) var liveOrderID: String?
    private var idempotencyKeys: [Plan: String] = [:]   // one key per approved plan, so a retry never double-orders
    private var pollTask: Task<Void, Never>?
    private var trackVisible = false
    private var serverPlanVersion = 1
    private var proposalKey: String?                    // "seller|version" already posted/shown, so we do it once
    private var postedProposalVersion: Int?             // set only when the server holds the proposal now on screen
    private var replacementSellers: Set<String> = []

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
        resetLiveOrder()
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
        if backend.mode == .live { startLiveOrder() }
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
        if backend.mode == .live { sendDecision(approve: true, proposal: proposal) }
    }

    /// Live only: tells the server the patient chose not to take the proposal. (The sheet's "Choose myself" does not call this yet.)
    func rejectPlanB() {
        guard let proposal = planB else { return }
        planB = nil
        if backend.mode == .live { sendDecision(approve: false, proposal: proposal) }
    }

    // MARK: Live backend

    /// Called by RootView when the Track screen appears/disappears; polling only runs while it is on screen.
    func trackVisibilityChanged(_ visible: Bool) {
        trackVisible = visible
        if visible { startPollingIfNeeded() } else { stopPolling() }
    }

    func testConnection() async -> Bool {
        guard let client = backend.makeClient() else { backendError = LiveError.badURL.message; return false }
        do {
            let health = try await client.health()
            if health.ok { backendError = nil }
            return health.ok
        } catch {
            backendError = (error as? LiveError)?.message
            return false
        }
    }

    private func resetLiveOrder() {
        stopPolling()
        liveOrderID = nil
        serverPlanVersion = 1
        proposalKey = nil
        postedProposalVersion = nil
        replacementSellers = []
    }

    private func startLiveOrder() {
        guard let approved = approvedPlan else { return }
        guard let client = backend.makeClient() else { backendError = LiveError.badURL.message; return }
        let key = idempotencyKeys[approved] ?? UUID().uuidString
        idempotencyKeys[approved] = key
        let sellers = scenario.sellers
        Task {
            do {
                let id = try await client.placeOrder(plan: approved, sellers: sellers, idempotencyKey: key)
                guard approvedPlan == approved else { return }   // the user moved on while we waited
                liveOrderID = id
                backendError = nil
                startPollingIfNeeded()
            } catch {
                // Never block the UI: the local (Mock) statuses already set above keep working.
                backendError = (error as? LiveError)?.message ?? LiveError.unreachable.message
            }
        }
    }

    private func startPollingIfNeeded() {
        guard backend.mode == .live, trackVisible, liveOrderID != nil, pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let id = self.liveOrderID, let client = self.backend.makeClient() else { break }
                if await self.pollOnce(client: client, orderID: id) { break }
                try? await Task.sleep(for: .seconds(2))
            }
            if !Task.isCancelled { self?.pollTask = nil }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Returns true when polling should stop (order done).
    private func pollOnce(client: LiveClient, orderID: String) async -> Bool {
        do {
            let status = try await client.status(orderID: orderID)
            if Task.isCancelled || orderID != liveOrderID { return true }
            backendError = nil
            await apply(status, client: client)
            return status.state == "done"
        } catch is CancellationError {
            return true
        } catch {
            backendError = (error as? LiveError)?.message ?? LiveError.unreachable.message
            return false   // keep the demo state on screen and try again at the next tick
        }
    }

    private func apply(_ status: ServerStatus, client: LiveClient) async {
        serverPlanVersion = status.planVersion
        for seller in status.sellers {
            switch seller.status {
            case "failed", "cancelled": statuses[seller.id] = .cancelled
            case "rerouted": statuses[seller.id] = .rerouted
            default: statuses[seller.id] = replacementSellers.contains(seller.id) ? .rerouted : .placed
            }
        }
        guard let approved = approvedPlan, let orderID = liveOrderID else { return }

        if status.state == "needs_proposal", let pending = status.pending {
            let key = "\(pending.sellerID)|\(status.planVersion)"
            guard proposalKey != key else { return }
            proposalKey = key
            let failure = Failure(rawValue: pending.failure) ?? .cancelled
            // The re-routing maths stays on the phone, using the existing Plan B engine.
            let proposal = PlanB(planner: planner).reroute(approved: approved, failedSellerID: pending.sellerID, failure: failure)
            do {
                try await client.postProposal(orderID: orderID, planVersion: status.planVersion, proposal: proposal)
                postedProposalVersion = status.planVersion
                replacementSellers = Set(proposal.rerouted.map(\.sellerID))
                planB = proposal
            } catch {
                proposalKey = nil   // try again next tick
                backendError = (error as? LiveError)?.message
            }
        } else if status.state == "awaiting_approval", planB == nil, let proposal = status.proposal,
                  let pending = status.pending, proposalKey != "\(pending.sellerID)|\(status.planVersion)" {
            // Proposal already on the server (e.g. the app was reopened): show it once.
            proposalKey = "\(pending.sellerID)|\(status.planVersion)"
            postedProposalVersion = status.planVersion
            replacementSellers = Set(proposal.rerouted.map(\.sellerID))
            planB = proposal
        }
    }

    private func sendDecision(approve: Bool, proposal: PlanBProposal) {
        // Only when the server actually holds this proposal (not for the local-only "Simulate cancel").
        guard let orderID = liveOrderID, let version = postedProposalVersion, let client = backend.makeClient() else { return }
        postedProposalVersion = nil
        Task {
            do {
                if approve { try await client.approve(orderID: orderID, planVersion: version) }
                else { try await client.reject(orderID: orderID, planVersion: version) }
            } catch {
                backendError = (error as? LiveError)?.message
            }
        }
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
