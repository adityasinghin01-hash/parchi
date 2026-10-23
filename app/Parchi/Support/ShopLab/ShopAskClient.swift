import Foundation

// Wire types for POST /shop/ask, GET /shop/{id}/status, POST /shop/{id}/next (server/CONTRACT_P3.md).
// Decoding is lenient on optional parts so a small server change never blanks the sheet.

struct AskItemBody: Encodable {
    var itemID: String
    var name: String
    var strength: String?
    var quantity: Int
}

struct AskShopBody: Encodable {
    var shopID: String
    var name: String
    var phone: String?
    var distanceM: Int?
}

struct ShopAskRequest: Encodable {
    var items: [AskItemBody]
    var shops: [AskShopBody]
    var pickupBy: String
    var groupSize: Int
    var waitMinutes: Int
    var orderID: String?
}

struct ShopReplyLink: Decodable, Equatable {
    var shopID: String
    var url: String
}

struct ShopAskResponse: Decodable {
    var askID: String
    var round: Int
    var replyLinks: [ShopReplyLink]

    private enum CodingKeys: String, CodingKey { case askID, round, replyLinks }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        askID = try c.decode(String.self, forKey: .askID)
        round = (try? c.decodeIfPresent(Int.self, forKey: .round)) ?? 1
        replyLinks = (try? c.decodeIfPresent([ShopReplyLink].self, forKey: .replyLinks)) ?? []
    }
}

struct ShopNextResponse: Decodable {
    var round: Int
    var replyLinks: [ShopReplyLink]

    private enum CodingKeys: String, CodingKey { case round, replyLinks }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        round = (try? c.decodeIfPresent(Int.self, forKey: .round)) ?? 1
        replyLinks = (try? c.decodeIfPresent([ShopReplyLink].self, forKey: .replyLinks)) ?? []
    }
}

struct ShopStatusItem: Decodable, Equatable {
    var itemID: String
    var available: Bool
    var pricePaise: Int?
}

struct ShopStatusShop: Decodable, Equatable {
    var shopID: String
    var state: String                 // asked | replied | not_needed | no_reply | not_asked
    var askedAt: String?
    var repliedAt: String?
    var items: [ShopStatusItem]
    var totalPaise: Int?
    var readyBy: String?

    private enum CodingKeys: String, CodingKey { case shopID, state, askedAt, repliedAt, items, totalPaise, readyBy }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        shopID = try c.decode(String.self, forKey: .shopID)
        state = (try? c.decodeIfPresent(String.self, forKey: .state)) ?? "not_asked"
        askedAt = try? c.decodeIfPresent(String.self, forKey: .askedAt)
        repliedAt = try? c.decodeIfPresent(String.self, forKey: .repliedAt)
        items = (try? c.decodeIfPresent([ShopStatusItem].self, forKey: .items)) ?? []
        totalPaise = try? c.decodeIfPresent(Int.self, forKey: .totalPaise)
        readyBy = try? c.decodeIfPresent(String.self, forKey: .readyBy)
    }
}

struct ShopStatus: Decodable {
    var askID: String
    var state: String                 // waiting | replied | closed
    var round: Int
    var noReply: Bool
    var nextGroup: [String]
    var shops: [ShopStatusShop]
    var winnerShopID: String?

    private enum CodingKeys: String, CodingKey { case askID, state, round, noReply, nextGroup, shops, winnerShopID }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        askID = try c.decode(String.self, forKey: .askID)
        state = try c.decode(String.self, forKey: .state)
        round = (try? c.decodeIfPresent(Int.self, forKey: .round)) ?? 1
        noReply = (try? c.decodeIfPresent(Bool.self, forKey: .noReply)) ?? false
        nextGroup = (try? c.decodeIfPresent([String].self, forKey: .nextGroup)) ?? []
        shops = (try? c.decodeIfPresent([ShopStatusShop].self, forKey: .shops)) ?? []
        winnerShopID = try? c.decodeIfPresent(String.self, forKey: .winnerShopID)
    }
}

/// Async client for the shop-ask endpoints. Every failure is a `LiveError` (plain-language `message`).
struct ShopAskClient {
    let transport: ShopLabTransport

    init(live: LiveClient) { transport = ShopLabTransport(live: live) }

    func ask(_ request: ShopAskRequest) async throws -> ShopAskResponse {
        try await transport.post("shop/ask", body: request)
    }

    func status(askID: String) async throws -> ShopStatus {
        try await transport.get("shop/\(askID)/status")
    }

    /// Opens the next group of shops (after "no reply"). 409 (`LiveError.conflict`) = nothing left to open.
    func next(askID: String) async throws -> ShopNextResponse {
        struct Empty: Encodable {}
        return try await transport.post("shop/\(askID)/next", body: Empty())
    }
}
