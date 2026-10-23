import Foundation
import ParchiCore

/// Usage: parchi-plan <scenario.json>
/// Prints the best complete plan, two alternatives, and a Plan B for the scenario's simulated failure.
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

func rupees(_ paise: Paise) -> String { String(format: "₹%.2f", Double(paise) / 100) }

let args = CommandLine.arguments
guard args.count > 1, let data = FileManager.default.contents(atPath: args[1]) else {
    print("usage: parchi-plan <scenario.json>")
    exit(1)
}
let scenario = try JSONDecoder().decode(Scenario.self, from: data)
let names = Dictionary(uniqueKeysWithValues: scenario.sellers.map { ($0.id, $0.name) })
let itemNames = Dictionary(uniqueKeysWithValues: scenario.items.map { ($0.id, [$0.name, $0.strength].compactMap { $0 }.joined(separator: " ")) })
let planner = Planner(items: scenario.items, sellers: scenario.sellers, offers: scenario.offers, preferences: scenario.preferences)

func show(_ plan: Plan, label: String) {
    print("\n\(label): payable \(rupees(plan.payable)) (items \(rupees(plan.itemsTotal)) + fees \(rupees(plan.feesTotal))), trips \(plan.stops), medicines in \(plan.medicinesReadyMinutes) min, reports in \(plan.reportsReadyMinutes) min")
    for line in plan.lines {
        print("  - \(itemNames[line.itemID] ?? line.itemID) → \(names[line.sellerID] ?? line.sellerID) \(rupees(line.price))\(line.isSubstitute ? " (substitute, doctor approved)" : "")")
    }
}

print("== \(scenario.title)")
let missing = planner.unavailableItems()
if !missing.isEmpty { print("Not available anywhere: \(missing.map { itemNames[$0] ?? $0 })") }
let ranked = planner.ranked(limit: 3)
guard let best = ranked.first else {
    print("No complete plan exists.")
    exit(0)
}
show(best, label: "BEST PLAN")
for (i, alt) in ranked.dropFirst().enumerated() { show(alt, label: "Alternative \(i + 1)") }

if let spec = scenario.simulateFailure {
    let proposal = PlanB(planner: planner).reroute(approved: best, failedSellerID: spec.sellerID, failure: spec.failure)
    print("\n!! \(names[spec.sellerID] ?? spec.sellerID) reports: \(spec.failure.rawValue)")
    if !best.sellerIDs.contains(spec.sellerID) {
        print("Not in your plan, nothing to change.")
    } else if proposal.stillMissing.isEmpty {
        print("PLAN B (one tap to approve): extra \(rupees(proposal.extraCost))")
        for line in proposal.rerouted {
            print("  - \(itemNames[line.itemID] ?? line.itemID) → \(names[line.sellerID] ?? line.sellerID) \(rupees(line.price))")
        }
        print("  Kept as is: \(proposal.kept.map { itemNames[$0.itemID] ?? $0.itemID })")
        show(proposal.newPlan, label: "NEW PLAN")
    } else {
        print("No other seller has: \(proposal.stillMissing.map { itemNames[$0] ?? $0 }). Ask the doctor or lab.")
    }
}
