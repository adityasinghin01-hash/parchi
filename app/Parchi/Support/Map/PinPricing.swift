import Foundation
import ParchiCore

/// The price a map pin / list row / shop sheet shows for one shop. Plain values only, so the rules are unit-tested
/// (`ParchiTests/PinPricingTests`). Nothing here invents a number: a shop with no price is `.isAsk` and shows "Ask".
struct PinPrice: Equatable {
    /// Paise for the lines counted in `covered`. nil = no price ("Ask").
    var paise: Paise?
    /// How many of the parchi's medicines the price covers, out of `total`.
    var covered: Int
    var total: Int
    /// Where the number comes from (the chip under it). nil when there is no number.
    var source: PriceSource?
    /// Jan Aushadhi always says "for X of Y" (the brief's wording); the others only when the price is partial.
    var alwaysShowCoverage = false

    static func ask(total: Int) -> PinPrice { PinPrice(paise: nil, covered: 0, total: total, source: nil) }

    var isAsk: Bool { paise == nil }
    var isPartial: Bool { covered < total }

    /// "₹2,696.77" or "Ask". Never a number for a shop without a price.
    var text: String { paise.map { rupees($0) } ?? "Ask" }

    /// "for 4 of 6", or nil when the price covers everything (and the kind does not always say it).
    var coverageText: String? {
        guard !isAsk, isPartial || alwaysShowCoverage else { return nil }
        return "for \(covered) of \(total)"
    }

    /// The pin label and list-row price: "₹330 for 4 of 6".
    var fullText: String { [text, coverageText].compactMap { $0 }.joined(separator: " ") }

    /// What a screen reader says.
    var spoken: String { isAsk ? "No price yet, ask the shop" : fullText }
}

/// One medicine's price at one shop, for the shop sheet.
struct ShopItemPrice: Equatable, Identifiable {
    var id: String { itemID }
    let itemID: String
    let name: String
    /// nil = not known / not available at this shop.
    let paise: Paise?
    var note: String?
}

enum PinPricing {
    /// A local chemist (MapKit or in the plan data): the basket at MRP. `mrp` = price of the full line quantity per item id.
    /// A shop without any MRP for the basket is "Ask". `source` is the catalogue chip ("Catalogue MRP · check at the shop").
    static func chemist(medicineIDs: [String], mrp: [String: Paise], source: PriceSource) -> PinPrice {
        sum(medicineIDs, prices: mrp, source: source)
    }

    /// A Jan Aushadhi Kendra: the list price of the lines that have a same-salt equivalent, "₹N for X of Y".
    /// No equivalent at all = "Ask" (no number).
    static func janAushadhi(medicineIDs: [String], totals: [String: Paise], source: PriceSource) -> PinPrice {
        var price = sum(medicineIDs, prices: totals, source: source)
        price.alwaysShowCoverage = true
        return price
    }

    /// A shop that answered "Ask nearby shops": only the items it marked available with a price count.
    /// A reply with no priced item gives "Ask" (never "₹0").
    static func reply(medicineIDs: [String], items: [ShopStatusItem], repliedAt: Date, isDemo: Bool) -> PinPrice {
        var prices: [String: Paise] = [:]
        for item in items where item.available {
            if let p = item.pricePaise, p > 0, medicineIDs.contains(item.itemID) { prices[item.itemID] = p }
        }
        let source = PriceSource(kind: .shopReply, dateSeen: repliedAt, note: isDemo ? "Shop replied (demo, scripted) · \(PriceSource(kind: .shopReply, dateSeen: repliedAt).label)" : nil)
        return sum(medicineIDs, prices: prices, source: source)
    }

    /// A seller with its own offers (delivery sellers): in-stock, non-substitute offers for the medicines.
    static func seller(medicineIDs: [String], offers: [Offer], sellerID: String, source: PriceSource) -> PinPrice {
        var prices: [String: Paise] = [:]
        for offer in offers where offer.sellerID == sellerID && offer.inStock && !offer.isSubstitute && medicineIDs.contains(offer.itemID) {
            prices[offer.itemID] = offer.price
        }
        return sum(medicineIDs, prices: prices, source: source)
    }

    private static func sum(_ ids: [String], prices: [String: Paise], source: PriceSource) -> PinPrice {
        let unique = Array(NSOrderedSet(array: ids)) as? [String] ?? ids
        let known = unique.compactMap { prices[$0] }
        guard !known.isEmpty else { return .ask(total: unique.count) }
        return PinPrice(paise: known.reduce(0, +), covered: known.count, total: unique.count, source: source)
    }

    // MARK: Order

    /// Cheapest first, then nearest. "Ask" shops (no price) after the priced ones; unknown distance after known; then A to Z.
    static func areInOrder(_ a: PinPrice, _ aDistance: Int?, _ aName: String,
                           _ b: PinPrice, _ bDistance: Int?, _ bName: String) -> Bool {
        switch (a.paise, b.paise) {
        case let (x?, y?) where x != y: return x < y
        case (.some, nil): return true
        case (nil, .some): return false
        default: break
        }
        switch (aDistance, bDistance) {
        case let (x?, y?) where x != y: return x < y
        case (.some, nil): return true
        case (nil, .some): return false
        default: return aName.localizedCaseInsensitiveCompare(bName) == .orderedAscending
        }
    }
}
