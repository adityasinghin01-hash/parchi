import Foundation

/// Server counts per seller for the patient's area (A1 Smart Router). `score` = (ok + 4) / (total + 5), a neutral 0.8 prior.
struct SellerReliability: Decodable, Hashable {
    let sellerID: String
    let score: Double
    let orders: Int
}

/// A7: what other patients really paid on top of item prices. Only shown when the server says `enough`.
struct TruePriceInfo: Decodable, Hashable {
    let reports: Int
    let enough: Bool
    let medianExtraPaise: Int?
}

private struct PaidReport: Encodable {
    let sellerID: String
    let paidPaise: Int
    let itemsPaise: Int
    let pincode: String
}

private struct RefillItem: Encodable {
    let name: String
    let quantity: Int
    let dosesPerDay: String
}

private struct RefillRequest: Encodable {
    let items: [RefillItem]
    let startDate: String
}

struct RefillCreated: Decodable {
    let refillID: String
    let refillDueAt: String
}

private struct Ack: Decodable { var ok: Bool? }

/// Client for the V2 endpoints in server/V2_README.md. Same transport, headers and error style as the other clients.
struct V2Client {
    let transport: ShopLabTransport

    init(client: LiveClient) { transport = ShopLabTransport(live: client) }

    func reliability(area: String) async throws -> [SellerReliability] {
        try await transport.get("reliability?area=\(area.urlQueryValue)")
    }

    func truePrice(seller: String, pincode: String) async throws -> TruePriceInfo {
        try await transport.get("true_price?seller=\(seller.urlQueryValue)&pincode=\(pincode.urlQueryValue)")
    }

    func paid(orderID: String, sellerID: String, paidPaise: Int, itemsPaise: Int, pincode: String) async throws {
        let _: Ack = try await transport.post("orders/\(orderID)/paid",
                                              body: PaidReport(sellerID: sellerID, paidPaise: paidPaise, itemsPaise: itemsPaise, pincode: pincode))
    }

    /// `startDate` is YYYY-MM-DD (the first day the patient takes the medicine).
    func watchRefill(items: [(name: String, quantity: Int, schedule: String)], startDate: String) async throws -> RefillCreated {
        try await transport.post("refill/watch", body: RefillRequest(
            items: items.map { RefillItem(name: $0.name, quantity: $0.quantity, dosesPerDay: $0.schedule) }, startDate: startDate))
    }
}
