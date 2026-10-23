import SwiftUI

/// S9 How we rank. Each sentence is checked against engine/ParchiCore/Sources/ParchiCore/Planner.swift (see comments).
struct HowWeRankView: View {
    var body: some View {
        List {
            Section("What decides the order") {
                // Planner.makePlan: payable = itemsTotal + feesTotal; fees = delivery + handling + collection (Seller.fees).
                point("indianrupeesign.circle", "The full price you pay",
                      "Plans are ranked by everything you would pay: the medicines and tests, plus delivery, handling and lab visit fees. Delivery that is free above a certain amount is counted correctly.")
                // Planner.score: payable + stops * visitCost (visitCost 5000 paise in the scenario and the default).
                point("figure.walk", "Trips count",
                      "Each place you must go to in person adds a small allowance (₹50 in this version) when plans are compared, so a few rupees saved never costs you an extra trip.")
                // Planner.better(.cheapest): score, then maxEtaMinutes, then number of sellers.
                point("clock", "Then how soon, then how few sellers",
                      "If two plans cost the same, the one ready sooner comes first, then the one with fewer sellers.")
            }
            Section("You choose what matters") {
                // Objective: cheapest / fastest / fewestStops.
                point("slider.horizontal.3", "Cheapest, fastest or fewest stops",
                      "Cheapest is the default. Fastest puts the plan that gets your medicines (then reports) soonest first. Fewest stops puts the plan with the fewest in-person trips first.")
                // Plan.stops, medicinesReadyMinutes, reportsReadyMinutes (PlanView line 16). Distance is not on PlanView yet, so it is not claimed.
                point("list.bullet.rectangle", "What is shown on each plan",
                      "Total price, number of in-person trips, when the medicines are ready and when reports are due.")
            }
            Section("What we do not do") {
                // Planner has no seller weight, fee or sponsorship input; order depends only on the fields above.
                point("hand.raised", "No seller pays for position",
                      "No seller can pay to appear higher. The order comes only from the price, trips and time above.")
                // Planner.usable: substitutes only if preferences.doctorApprovedSubstitutes; AppModel shows Jan Aushadhi as "ask your doctor".
                point("stethoscope", "Cheaper same-salt medicines: ask your doctor",
                      "A cheaper same-salt option, including at a Jan Aushadhi Kendra, is shown only as something to ask your doctor about. Parchi never swaps a brand for you.")
                // Planner.ranked returns [] when any item has no usable offer.
                point("checkmark.seal", "No half-plans called complete",
                      "A plan that leaves out a medicine or test is never offered as the complete plan.")
            }
            Section("Where prices come from") {
                // PriceSource: kinds mrp/online/shopReply/phoneCall, staleAfter 7 days.
                point("calendar", "Every price has a source and a date",
                      "A price is marked as MRP, an online page, a shop's reply or our own phone call, with the date. A price older than 7 days is marked “may have changed”.")
            }
        }
        .navigationTitle("How we rank")
    }

    private func point(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.title3).frame(width: 28).foregroundStyle(.tint).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
