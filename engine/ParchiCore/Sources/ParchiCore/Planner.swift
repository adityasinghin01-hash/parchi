import Foundation

/// Finds the best complete plan for a parchi across every channel.
///
/// The search is exact for the small sizes a prescription has (up to ~16 candidate sellers):
/// every subset of sellers is tried, each item goes to its cheapest offer inside the subset,
/// then a local pass moves items between chosen sellers to cross free-delivery thresholds.
public struct Planner: Sendable {
    public let items: [RxItem]
    public let sellers: [String: Seller]
    public let offers: [Offer]
    public let preferences: Preferences

    public init(items: [RxItem], sellers: [Seller], offers: [Offer], preferences: Preferences) {
        self.items = items
        self.sellers = Dictionary(uniqueKeysWithValues: sellers.map { ($0.id, $0) })
        self.offers = offers
        self.preferences = preferences
    }

    func usable(_ offer: Offer, excluding excluded: Set<OfferKey>) -> Bool {
        guard offer.inStock, sellers[offer.sellerID] != nil else { return false }
        guard !excluded.contains(OfferKey(itemID: offer.itemID, sellerID: offer.sellerID)) else { return false }
        if offer.exactMatch { return true }
        return offer.isSubstitute && preferences.doctorApprovedSubstitutes
    }

    /// Items that no seller can supply; a plan can never be called complete while this is non-empty.
    public func unavailableItems(excluding excluded: Set<OfferKey> = []) -> [String] {
        items.map(\.id).filter { id in !offers.contains { $0.itemID == id && usable($0, excluding: excluded) } }
    }

    public func best(excluding excluded: Set<OfferKey> = [], fixed: [PlanLine] = []) -> Plan? {
        ranked(excluding: excluded, fixed: fixed, limit: 1).first
    }

    /// Up to `limit` distinct complete plans, best first.
    public func ranked(excluding excluded: Set<OfferKey> = [], fixed: [PlanLine] = [], limit: Int = 3) -> [Plan] {
        let fixedIDs = Set(fixed.map(\.itemID))
        let open = items.filter { !fixedIDs.contains($0.id) }
        let valid = offers.filter { usable($0, excluding: excluded) && !fixedIDs.contains($0.itemID) }
        let byItem = Dictionary(grouping: valid, by: \.itemID)
        guard open.allSatisfy({ byItem[$0.id] != nil }) else { return [] }

        let candidates = Array(Set(valid.map(\.sellerID))).sorted()
        precondition(candidates.count <= 20, "too many sellers for exact search")
        var plans: [Plan] = []
        var seen = Set<[String]>()
        let subsets = 1 << candidates.count
        for mask in 1..<subsets {
            let chosen = Set(candidates.enumerated().filter { mask & (1 << $0.offset) != 0 }.map(\.element))
            guard var assignment = assign(open, byItem: byItem, within: chosen) else { continue }
            assignment = improve(assignment, byItem: byItem, within: chosen, fixed: fixed)
            let plan = makePlan(assignment + fixed)
            // Only keep subsets where every chosen seller is actually used.
            guard Set(plan.lines.map(\.sellerID)).isSuperset(of: chosen) else { continue }
            if let cap = preferences.maxEtaMinutes, plan.maxEtaMinutes > cap { continue }
            let key = plan.lines.map { "\($0.itemID)@\($0.sellerID)" }.sorted()
            if seen.insert(key).inserted { plans.append(plan) }
        }
        return Array(plans.sorted(by: better).prefix(limit))
    }

    func assign(_ open: [RxItem], byItem: [String: [Offer]], within chosen: Set<String>) -> [PlanLine]? {
        var lines: [PlanLine] = []
        for item in open {
            let inside = (byItem[item.id] ?? []).filter { chosen.contains($0.sellerID) }
            guard let pick = inside.min(by: { ($0.price, $0.isSubstitute ? 1 : 0) < ($1.price, $1.isSubstitute ? 1 : 0) }) else {
                return nil
            }
            lines.append(PlanLine(itemID: item.id, sellerID: pick.sellerID, price: pick.price, isSubstitute: pick.isSubstitute))
        }
        return lines
    }

    /// Move single items between already-chosen sellers when that lowers the payable total
    /// (for example to reach a free-delivery threshold).
    func improve(_ start: [PlanLine], byItem: [String: [Offer]], within chosen: Set<String>, fixed: [PlanLine]) -> [PlanLine] {
        var current = start
        var improved = true
        var rounds = 0
        while improved && rounds < 20 {
            improved = false
            rounds += 1
            for index in current.indices {
                let line = current[index]
                for offer in byItem[line.itemID] ?? [] where chosen.contains(offer.sellerID) && offer.sellerID != line.sellerID {
                    var trial = current
                    trial[index] = PlanLine(itemID: line.itemID, sellerID: offer.sellerID, price: offer.price, isSubstitute: offer.isSubstitute)
                    if score(makePlan(trial + fixed)) < score(makePlan(current + fixed)) {
                        current = trial
                        improved = true
                    }
                }
            }
        }
        return current
    }

    func makePlan(_ lines: [PlanLine]) -> Plan {
        let bySeller = Dictionary(grouping: lines, by: \.sellerID)
        var fees: [String: Paise] = [:]
        var eta = 0
        var medicinesReady = 0
        var reportsReady = 0
        var stops = 0
        for (sellerID, group) in bySeller {
            guard let seller = sellers[sellerID] else { continue }
            fees[sellerID] = seller.fees(forSubtotal: group.reduce(0) { $0 + $1.price })
            eta = max(eta, seller.etaMinutes)
            if seller.channel == .lab {
                reportsReady = max(reportsReady, seller.etaMinutes)
            } else {
                medicinesReady = max(medicinesReady, seller.etaMinutes)
            }
            if seller.requiresVisit { stops += 1 }
        }
        let sorted = lines.sorted { $0.itemID < $1.itemID }
        return Plan(lines: sorted, feesBySeller: fees, itemsTotal: lines.reduce(0) { $0 + $1.price },
                    feesTotal: fees.values.reduce(0, +), stops: stops, maxEtaMinutes: eta,
                    medicinesReadyMinutes: medicinesReady, reportsReadyMinutes: reportsReady)
    }

    /// Lower is better. The patient's time is priced in, so the cheapest plan is honest about trips.
    func score(_ plan: Plan) -> Int {
        plan.payable + plan.stops * preferences.visitCost
    }

    func better(_ a: Plan, _ b: Plan) -> Bool {
        switch preferences.objective {
        case .cheapest:
            return (score(a), a.maxEtaMinutes, a.sellerIDs.count) < (score(b), b.maxEtaMinutes, b.sellerIDs.count)
        case .fastest:
            return (a.medicinesReadyMinutes, a.reportsReadyMinutes, score(a)) < (b.medicinesReadyMinutes, b.reportsReadyMinutes, score(b))
        case .fewestStops:
            return (a.stops, a.sellerIDs.count, score(a)) < (b.stops, b.sellerIDs.count, score(b))
        }
    }
}

public struct OfferKey: Hashable, Sendable {
    public var itemID: String
    public var sellerID: String
    public init(itemID: String, sellerID: String) {
        self.itemID = itemID
        self.sellerID = sellerID
    }
}
