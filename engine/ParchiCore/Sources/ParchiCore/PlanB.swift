import Foundation

/// What went wrong with part of an approved plan.
public enum Failure: String, Codable, Sendable {
    case cancelled
    case outOfStock
    case late
    case sampleRejected
}

public struct PlanBProposal: Codable, Sendable {
    public var failure: Failure
    public var failedSellerID: String
    /// Lines that already succeeded and are kept exactly as they were.
    public var kept: [PlanLine]
    /// The re-routed lines that need the patient's one-tap approval.
    public var rerouted: [PlanLine]
    public var newPlan: Plan
    public var extraCost: Paise
    /// Items no remaining seller can supply; shown plainly, never hidden.
    public var stillMissing: [String]
}

/// Payment-style failover for medicines and tests: when one seller fails, only the affected
/// items are re-routed to the next-best seller and everything already done stays done.
public struct PlanB: Sendable {
    public let planner: Planner

    public init(planner: Planner) {
        self.planner = planner
    }

    public func reroute(approved: Plan, failedSellerID: String, failure: Failure) -> PlanBProposal {
        let failedLines = approved.lines.filter { $0.sellerID == failedSellerID }
        let kept = approved.lines.filter { $0.sellerID != failedSellerID }
        let excluded = Set(failedLines.map { OfferKey(itemID: $0.itemID, sellerID: failedSellerID) })
        let missing = planner.unavailableItems(excluding: excluded).filter { id in failedLines.contains { $0.itemID == id } }
        guard missing.isEmpty, let plan = planner.best(excluding: excluded, fixed: kept) else {
            return PlanBProposal(failure: failure, failedSellerID: failedSellerID, kept: kept, rerouted: [],
                                 newPlan: approved, extraCost: 0, stillMissing: missing.isEmpty ? failedLines.map(\.itemID) : missing)
        }
        let rerouted = plan.lines.filter { line in failedLines.contains { $0.itemID == line.itemID } }
        return PlanBProposal(failure: failure, failedSellerID: failedSellerID, kept: kept, rerouted: rerouted,
                             newPlan: plan, extraCost: plan.payable - approved.payable, stillMissing: [])
    }
}
