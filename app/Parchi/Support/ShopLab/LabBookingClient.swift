import Foundation

// Wire types for POST /lab/book and GET /lab/{id}/status (server/CONTRACT_P3.md).

struct LabBookTestBody: Encodable {
    var testID: String
    var name: String
    var fasting: Bool
}

struct LabBookRequest: Encodable {
    var labID: String
    var labName: String
    var tests: [LabBookTestBody]
    var homeCollection: Bool
    var preferredSlot: String
    var addressText: String?
    var orderID: String?
    var sellerID: String?
}

struct LabBookResponse: Decodable {
    var bookingID: String
    var replyLink: String?
}

struct LabStatus: Decodable {
    var bookingID: String
    var state: String            // requested | confirmed | rejected | collected | report_due | report_chase_due | done
    var noReply: Bool
    var slot: String?
    var feePaise: Int?
    var reportDueAt: String?
    var fastingReminderAt: String?
    var note: String?

    private enum CodingKeys: String, CodingKey { case bookingID, state, noReply, slot, feePaise, reportDueAt, fastingReminderAt, note }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bookingID = try c.decode(String.self, forKey: .bookingID)
        state = try c.decode(String.self, forKey: .state)
        noReply = (try? c.decodeIfPresent(Bool.self, forKey: .noReply)) ?? false
        slot = try? c.decodeIfPresent(String.self, forKey: .slot)
        feePaise = try? c.decodeIfPresent(Int.self, forKey: .feePaise)
        reportDueAt = try? c.decodeIfPresent(String.self, forKey: .reportDueAt)
        fastingReminderAt = try? c.decodeIfPresent(String.self, forKey: .fastingReminderAt)
        note = try? c.decodeIfPresent(String.self, forKey: .note)
    }
}

struct LabBookingClient {
    let transport: ShopLabTransport

    init(live: LiveClient) { transport = ShopLabTransport(live: live) }

    func book(_ request: LabBookRequest) async throws -> LabBookResponse {
        try await transport.post("lab/book", body: request)
    }

    func status(bookingID: String) async throws -> LabStatus {
        try await transport.get("lab/\(bookingID)/status")
    }
}
