import Foundation

/// Money is always integer paise so totals never drift.
public typealias Paise = Int

public enum ItemKind: String, Codable, Sendable {
    case medicine
    case test
}

/// One line of the parchi after the patient has confirmed it.
public struct RxItem: Codable, Hashable, Sendable {
    public var id: String
    public var kind: ItemKind
    public var name: String
    public var strength: String?
    public var quantity: Int

    public init(id: String, kind: ItemKind, name: String, strength: String? = nil, quantity: Int = 1) {
        self.id = id
        self.kind = kind
        self.name = name
        self.strength = strength
        self.quantity = quantity
    }
}

public enum Channel: String, Codable, Sendable {
    case localChemist
    case janAushadhi
    case quickCommerce
    case onlinePharmacy
    case lab
}

public struct Seller: Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var channel: Channel
    public var deliveryFee: Paise
    /// Delivery becomes free at or above this subtotal; nil means never free.
    public var freeDeliveryAbove: Paise?
    public var handlingFee: Paise
    /// Home-collection or visit fee for labs, charged once per seller used.
    public var collectionFee: Paise
    public var etaMinutes: Int
    /// True when the patient must go there in person (a shop or a lab without home collection).
    public var requiresVisit: Bool
    public var distanceMeters: Int?

    public init(id: String, name: String, channel: Channel, deliveryFee: Paise = 0, freeDeliveryAbove: Paise? = nil,
                handlingFee: Paise = 0, collectionFee: Paise = 0, etaMinutes: Int, requiresVisit: Bool = false,
                distanceMeters: Int? = nil) {
        self.id = id
        self.name = name
        self.channel = channel
        self.deliveryFee = deliveryFee
        self.freeDeliveryAbove = freeDeliveryAbove
        self.handlingFee = handlingFee
        self.collectionFee = collectionFee
        self.etaMinutes = etaMinutes
        self.requiresVisit = requiresVisit
        self.distanceMeters = distanceMeters
    }

    /// Fees this seller adds for a given subtotal of items bought there.
    public func fees(forSubtotal subtotal: Paise) -> Paise {
        var delivery = deliveryFee
        if let threshold = freeDeliveryAbove, subtotal >= threshold { delivery = 0 }
        return delivery + handlingFee + collectionFee
    }
}

public struct Offer: Codable, Hashable, Sendable {
    public var itemID: String
    public var sellerID: String
    /// Price for the full prescribed quantity.
    public var price: Paise
    public var inStock: Bool
    /// Same brand, strength, form and pack as prescribed.
    public var exactMatch: Bool
    /// A cheaper same-salt option; only usable when the doctor has agreed.
    public var isSubstitute: Bool

    public init(itemID: String, sellerID: String, price: Paise, inStock: Bool = true, exactMatch: Bool = true,
                isSubstitute: Bool = false) {
        self.itemID = itemID
        self.sellerID = sellerID
        self.price = price
        self.inStock = inStock
        self.exactMatch = exactMatch
        self.isSubstitute = isSubstitute
    }
}

public enum Objective: String, Codable, Sendable {
    case cheapest
    case fastest
    case fewestStops
}

public struct Preferences: Codable, Sendable {
    public var objective: Objective
    /// The doctor agreed to same-salt substitutes (never assumed).
    public var doctorApprovedSubstitutes: Bool
    /// What one in-person trip is worth to the patient, used so a ₹5 saving never costs an extra trip.
    public var visitCost: Paise
    public var maxEtaMinutes: Int?
    /// Smart Router (A1): delivery reliability per seller, 0...1 (successful / total orders in the patient's area).
    /// Optional so older scenario files still decode. Unknown sellers use the neutral 0.8 prior.
    public var reliability: [String: Double]?
    /// 0 (default) = choose by price only. Above 0 the planner CHOOSES with cost * (1 + weight * (1 - reliability))
    /// per seller; the totals shown to the patient stay the real amounts.
    public var reliabilityWeight: Double?

    public init(objective: Objective = .cheapest, doctorApprovedSubstitutes: Bool = false, visitCost: Paise = 5_000,
                maxEtaMinutes: Int? = nil, reliability: [String: Double]? = nil, reliabilityWeight: Double? = nil) {
        self.objective = objective
        self.doctorApprovedSubstitutes = doctorApprovedSubstitutes
        self.visitCost = visitCost
        self.maxEtaMinutes = maxEtaMinutes
        self.reliability = reliability
        self.reliabilityWeight = reliabilityWeight
    }
}

public struct PlanLine: Codable, Hashable, Sendable {
    public var itemID: String
    public var sellerID: String
    public var price: Paise
    public var isSubstitute: Bool
}

public struct Plan: Codable, Hashable, Sendable {
    public var lines: [PlanLine]
    public var feesBySeller: [String: Paise]
    public var itemsTotal: Paise
    public var feesTotal: Paise
    public var payable: Paise { itemsTotal + feesTotal }
    public var stops: Int
    public var maxEtaMinutes: Int
    /// When every medicine arrives (lab report times are tracked separately).
    public var medicinesReadyMinutes: Int
    /// When the last lab report is due.
    public var reportsReadyMinutes: Int
    public var sellerIDs: [String] { Array(Set(lines.map(\.sellerID))).sorted() }
}
