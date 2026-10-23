import Foundation
import ParchiCore
import UIKit

/// Everything a pin, a list row and the shop sheet show for one shop.
struct ShopQuote {
    var price: PinPrice
    var items: [ShopItemPrice]
    /// One honest sentence under the chip (what this number is NOT).
    var footnote: String?
}

/// Turns the app's data into `PinPrice`s with the rules in `PinPricing`. Reads the model; changes nothing in it.
@MainActor
struct ShopPricer {
    let app: AppModel

    var medicineIDs: [String] { app.scenario.items.filter { $0.kind == .medicine }.map(\.id) }

    /// Medicines a delivery seller may supply: H1/X medicines are in person only.
    var deliverableIDs: [String] { medicineIDs.filter { id in app.lines.first(where: { $0.id == id })?.inPersonOnly == nil } }

    /// The basket at MRP, per item: the doctor's-shop MRP in the demo scenario, else the catalogue MRP.
    var chemistMRP: [String: Paise] {
        var map: [String: Paise] = [:]
        for offer in app.scenario.offers where offer.sellerID == AppModel.catalogueSellerID && offer.inStock && !offer.isSubstitute {
            map[offer.itemID] = offer.price
        }
        for (id, offer) in app.catalogueOffers where map[id] == nil { map[id] = offer.price.totalPaise }
        return map
    }

    /// Jan Aushadhi list price per item that has a same-salt equivalent (never for H1/X lines; AppModel already skips them).
    var janAushadhiTotals: [String: Paise] { app.janAushadhiAsks.mapValues(\.totalPaise) }

    // MARK: Sources

    private var catalogueSource: PriceSource {
        let known = medicineIDs.filter { chemistMRP[$0] != nil }.allSatisfy { app.catalogueOffers[$0]?.price.packSizeKnown ?? true }
        return PriceSource.catalogueMRP(dateSeen: AppModel.catalogueSeen, packSizeKnown: known)
    }

    private var janAushadhiSource: PriceSource {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Kolkata")
        formatter.dateFormat = "d MMM"
        let date = app.data.janAushadhiListDate
        return PriceSource(kind: .mrp, dateSeen: date, note: "Jan Aushadhi list of \(formatter.string(from: date)) · ask your doctor")
    }

    // MARK: Shops

    /// Local shops from the plan data. They have no coordinates (list only), but replies from "Ask nearby shops" belong to them.
    func planShops() -> [MapShop] {
        app.shopCandidates().map { candidate in
            let channel = app.seller(candidate.id)?.channel
            return MapShop(id: candidate.id, name: candidate.name, address: nil, phone: nil, distanceM: candidate.distanceM,
                           latitude: nil, longitude: nil, kind: channel == .janAushadhi ? .janAushadhi : .chemist,
                           planSellerID: candidate.id, mapItem: nil)
        }
    }

    func quote(for shop: MapShop) -> ShopQuote {
        let ids = medicineIDs
        // 1. A shop that replied through "Ask nearby shops": its own price wins.
        if let row = app.shopAsk.rows.first(where: { $0.id == shop.id && $0.state == .replied }) {
            let price = PinPricing.reply(medicineIDs: ids, items: row.items, repliedAt: row.repliedAt ?? Date(), isDemo: row.isDemo)
            if !price.isAsk {
                let items = ids.map { id -> ShopItemPrice in
                    let item = row.items.first { $0.itemID == id }
                    let paise = item.flatMap { $0.available ? $0.pricePaise : nil }
                    return ShopItemPrice(itemID: id, name: app.itemName(id), paise: paise,
                                         note: paise == nil ? (item == nil ? "Not in the reply" : "Not available") : nil)
                }
                return ShopQuote(price: price, items: items,
                                 footnote: row.isDemo ? "This reply is scripted for the demo. No shop wrote it." : "The shop's own reply to your message.")
            }
        }
        // 2. Otherwise by kind.
        switch shop.kind {
        case .janAushadhi:
            let totals = janAushadhiTotals
            let price = PinPricing.janAushadhi(medicineIDs: ids, totals: totals, source: janAushadhiSource)
            let items = ids.map { ShopItemPrice(itemID: $0, name: app.itemName($0), paise: totals[$0], note: totals[$0] == nil ? "No same-salt match found" : nil) }
            return ShopQuote(price: price, items: items,
                             footnote: "Same salt only, not the same brand. Only your doctor can approve a switch; Parchi never changes a medicine.")
        case .chemist:
            let mrp = chemistMRP
            let price = PinPricing.chemist(medicineIDs: ids, mrp: mrp, source: catalogueSource)
            let items = ids.map { ShopItemPrice(itemID: $0, name: app.itemName($0), paise: mrp[$0], note: mrp[$0] == nil ? "No catalogue price" : nil) }
            return ShopQuote(price: price, items: items,
                             footnote: "This is the printed price (MRP), not a quote from this shop. Ask the shop for its price.")
        }
    }

    // MARK: Delivery-only sellers

    struct DeliverySeller: Identifiable {
        let id: String
        let name: String
        let price: PinPrice
        let inPlan: Bool
        let source: PriceSource
    }

    /// Online pharmacies and quick-commerce sellers: their plan price when the plan uses them, else their own offers.
    func deliverySellers() -> [DeliverySeller] {
        let ids = deliverableIDs
        let planLines = app.plan?.lines ?? []
        let rows = app.scenario.sellers.filter { $0.channel == .onlinePharmacy || $0.channel == .quickCommerce }.map { seller -> DeliverySeller in
            let inPlan = planLines.contains { $0.sellerID == seller.id }
            let offers: [Offer]
            let counted: [String]
            if inPlan {
                let mine = planLines.filter { $0.sellerID == seller.id && ids.contains($0.itemID) }
                offers = mine.map { Offer(itemID: $0.itemID, sellerID: seller.id, price: $0.price) }
                counted = ids
            } else {
                offers = app.scenario.offers
                counted = ids
            }
            let source = app.priceSource(sellerID: seller.id)
            let price = PinPricing.seller(medicineIDs: counted, offers: offers, sellerID: seller.id, source: source)
            return DeliverySeller(id: seller.id, name: seller.name, price: price, inPlan: inPlan, source: source)
        }
        return rows.sorted { PinPricing.areInOrder($0.price, nil, $0.name, $1.price, nil, $1.name) }
    }
}

// MARK: Ask this shop (reads/uses the existing ask flow; does not change it)

extension AppModel {
    /// Same as `prepareShopAsk()`, but this shop is in the candidate list (first) and the only one picked.
    /// `prepare` does nothing while an ask is already in progress, exactly as for the normal sheet.
    func prepareShopAsk(preselecting shop: MapShop) {
        var candidates = shopCandidates().filter { $0.id != shop.id }
        candidates.insert(ShopCandidate(id: shop.id, name: shop.name, distanceM: shop.distanceM), at: 0)
        shopAsk.prepare(items: scenario.items, candidates: candidates, demoOffers: scenario.offers,
                        liveRequested: backend.mode == .live, live: backend.makeClient(), orderID: liveOrderID)
        shopAsk.selected = [shop.id]
    }
}
