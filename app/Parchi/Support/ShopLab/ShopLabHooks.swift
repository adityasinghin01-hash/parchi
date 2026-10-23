import ParchiCore
import SwiftUI

/// Which Phase 3 sheet is open. Lives on AppModel so a launch route (`-demoRoute askShops|lab`) can open it.
enum ShopLabSheet: String, Identifiable {
    case askShops, lab
    var id: String { rawValue }
}

// Additive hooks on AppModel (nothing here changes Mock-mode behaviour of existing screens).
extension AppModel {
    /// Prices from the shop that replied first, as planner offers (sellerID = the shop's id). Claude merges these into the planner later.
    var shopReplyOffers: [Offer] { shopAsk.shopReplyOffers }
    /// Where the winning price came from ("Shop replied 6:40 pm"), nil until a shop replies.
    var shopReplySource: PriceSource? { shopAsk.winnerSource }

    /// Local shops in the plan data (chemists + Jan Aushadhi). "Jan Aushadhi Kendra (3.6 km)" gives its distance from the name.
    func shopCandidates() -> [ShopCandidate] {
        scenario.sellers.filter { $0.channel == .localChemist || $0.channel == .janAushadhi }.map { seller in
            let (name, parsed) = Self.splitDistance(seller.name)
            return ShopCandidate(id: seller.id, name: name, distanceM: seller.distanceMeters ?? parsed)
        }
    }

    /// Mock mode only: the scripted "shop replied" quotes the demo scenario's prices where it has them and the catalogue MRP for
    /// any other line (a typed or printed parchi), so the scripted reply never says "Not available" for a medicine we can price.
    /// The screen already says the reply is scripted. Live mode ignores this: a real shop answers.
    func demoShopOffers(for candidates: [ShopCandidate]) -> [Offer] {
        let have = Set(scenario.offers.map { OfferKey(itemID: $0.itemID, sellerID: $0.sellerID) })
        var extra: [Offer] = []
        for candidate in candidates {
            for offer in catalogueMRPOffers where !have.contains(OfferKey(itemID: offer.itemID, sellerID: candidate.id)) {
                extra.append(Offer(itemID: offer.itemID, sellerID: candidate.id, price: offer.price))
            }
        }
        return scenario.offers + extra
    }

    func prepareShopAsk() {
        let candidates = shopCandidates()
        shopAsk.prepare(items: scenario.items, candidates: candidates, demoOffers: demoShopOffers(for: candidates),
                        liveRequested: backend.mode == .live, live: backend.makeClient(), orderID: liveOrderID)
    }

    func prepareLabBooking() {
        let inPlan = Set((approvedPlan ?? plan)?.sellerIDs ?? [])
        labBooking.prepare(items: scenario.items, sellers: scenario.sellers, offers: scenario.offers,
                           liveRequested: backend.mode == .live, live: backend.makeClient(), orderID: liveOrderID, planSellerIDs: inPlan)
    }

    /// Launch routes `-demoRoute askShops` / `-demoRoute lab`. The lab route marks one test "told to fast" so the fasting note can be shown.
    func openShopLab(_ sheet: ShopLabSheet) {
        if sheet == .lab {
            labBooking.dayOffset = 2
            labBooking.demoMarkToldToFast("lipid")
            if labBooking.address.text.isEmpty { labBooking.address.text = "Demo address, Muradnagar" }
        }
        shopLabSheet = sheet
    }

    private static func splitDistance(_ name: String) -> (String, Int?) {
        guard let open = name.lastIndex(of: "("), name.hasSuffix("km)") else { return (name, nil) }
        let inside = name[name.index(after: open)...].dropLast(3).trimmingCharacters(in: .whitespaces)
        guard let km = Double(inside) else { return (name, nil) }
        return (name[..<open].trimmingCharacters(in: .whitespaces), Int(km * 1000))
    }
}

/// The one mount line for a screen: two toolbar buttons plus the sheets they open.
struct ShopLabActions: ViewModifier {
    @Environment(AppModel.self) private var app

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Ask shops") { app.shopLabSheet = .askShops }
                    Button("Labs") { app.shopLabSheet = .lab }
                }
            }
            .sheet(item: Bindable(app).shopLabSheet) { sheet in
                switch sheet {
                case .askShops: ShopAskSheet()
                case .lab: LabBookingView()
                }
            }
    }
}

extension View {
    /// "Ask nearby shops" + "Book lab tests" entry points (Phase 3). Add once per screen.
    func shopLabActions() -> some View { modifier(ShopLabActions()) }
}
