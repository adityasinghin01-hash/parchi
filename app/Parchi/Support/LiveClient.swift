import Foundation
import ParchiCore

enum LiveError: Error, Equatable {
    case badURL
    case missingKey
    case unreachable
    case unauthorized
    case rateLimited
    case conflict            // 409: plan version moved on
    case rejected(String)    // 4xx with the server's reason
    case server(Int)
    case invalidResponse

    /// Plain-language text for the user (no jargon, no status codes).
    var message: String {
        switch self {
        case .badURL: return "The server address isn't valid. Showing the demo."
        case .missingKey: return "No install key is set. Showing the demo."
        case .unreachable: return "Can't reach the server. Showing the demo."
        case .unauthorized: return "The server didn't accept the install key. Showing the demo."
        case .rateLimited: return "The server is busy. Trying again shortly."
        case .conflict: return "The order changed on the server. Refreshing."
        case .rejected(let why): return "The server didn't accept this: \(why)"
        case .server, .invalidResponse: return "The server gave an unexpected answer. Showing the demo."
        }
    }
}

struct ServerSeller: Codable, Equatable {
    var id: String
    var status: String
    var etaMinutes: Int?
}

struct ServerPending: Codable, Equatable {
    var sellerID: String
    var failure: String
}

struct ServerAuditEntry: Codable, Equatable {
    var seq: Int?
    var actor: String?
    var event: String?
    var planVersion: Int?
    var created: String?
}

/// GET /status/{id}. Decoding is lenient on optional parts so a small server change never blanks the Track screen.
struct ServerStatus: Decodable {
    var orderID: String
    var state: String                 // placed | needs_proposal | awaiting_approval | done
    var planVersion: Int
    var sellers: [ServerSeller]
    var pending: ServerPending?
    var proposal: PlanBProposal?
    var nothingAvailable: Bool
    var needsCheck: [String]
    var waitingSince: String?
    var audit: [ServerAuditEntry]

    private enum CodingKeys: String, CodingKey {
        case orderID, state, planVersion, sellers, pending, proposal, nothingAvailable, needsCheck, waitingSince, audit
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        orderID = try c.decode(String.self, forKey: .orderID)
        state = try c.decode(String.self, forKey: .state)
        planVersion = try c.decode(Int.self, forKey: .planVersion)
        sellers = try c.decodeIfPresent([ServerSeller].self, forKey: .sellers) ?? []
        pending = try? c.decodeIfPresent(ServerPending.self, forKey: .pending)
        proposal = try? c.decodeIfPresent(PlanBProposal.self, forKey: .proposal)
        nothingAvailable = (try? c.decodeIfPresent(Bool.self, forKey: .nothingAvailable)) ?? false
        needsCheck = (try? c.decodeIfPresent([String].self, forKey: .needsCheck)) ?? []
        waitingSince = try? c.decodeIfPresent(String.self, forKey: .waitingSince)
        audit = (try? c.decodeIfPresent([ServerAuditEntry].self, forKey: .audit)) ?? []
    }
}

struct Health: Decodable, Equatable {
    var ok: Bool
    var temporal: Bool?
}

/// Small async client for the Parchi lab server. Every call times out after 5 s and throws a `LiveError`; nothing here crashes.
struct LiveClient {
    let baseURL: URL
    let installKey: String
    var session: URLSession = .shared

    init?(baseURLString: String, installKey: String, session: URLSession = .shared) {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https", url.host != nil else { return nil }
        self.baseURL = url
        self.installKey = installKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.session = session
    }

    // MARK: API

    func health() async throws -> Health {
        try await send("GET", "health", authenticated: false)
    }

    /// Returns the server's order ID. The same `idempotencyKey` always returns the same order.
    func placeOrder(plan: Plan, sellers: [Seller], autoApproveCapPaise: Int? = nil, idempotencyKey: String) async throws -> String {
        struct Body: Encodable { var plan: Plan; var sellers: [Seller]; var autoApproveCapPaise: Int? }
        struct Reply: Decodable { var orderID: String }
        let reply: Reply = try await send("POST", "order", body: Body(plan: plan, sellers: sellers, autoApproveCapPaise: autoApproveCapPaise),
                                          headers: ["Idempotency-Key": idempotencyKey])
        return reply.orderID
    }

    func status(orderID: String) async throws -> ServerStatus {
        try await send("GET", "status/\(orderID)")
    }

    func postProposal(orderID: String, planVersion: Int, proposal: PlanBProposal) async throws {
        struct Body: Encodable { var planVersion: Int; var proposal: PlanBProposal }
        try await sendIgnoringReply("POST", "order/\(orderID)/proposal", body: Body(planVersion: planVersion, proposal: proposal))
    }

    func approve(orderID: String, planVersion: Int) async throws {
        try await sendIgnoringReply("POST", "order/\(orderID)/approve", body: Version(planVersion: planVersion))
    }

    func reject(orderID: String, planVersion: Int) async throws {
        try await sendIgnoringReply("POST", "order/\(orderID)/reject", body: Version(planVersion: planVersion))
    }

    private struct Version: Encodable { var planVersion: Int }

    // MARK: Plumbing

    private struct Empty: Encodable {}
    private struct Ignored: Decodable { init(from decoder: Decoder) throws {} }

    private func sendIgnoringReply<B: Encodable>(_ method: String, _ path: String, body: B) async throws {
        let _: Ignored = try await send(method, path, body: body)
    }

    private func send<R: Decodable>(_ method: String, _ path: String, authenticated: Bool = true) async throws -> R {
        try await send(method, path, body: Optional<Empty>.none, authenticated: authenticated)
    }

    private func send<R: Decodable, B: Encodable>(_ method: String, _ path: String, body: B?, headers: [String: String] = [:],
                                                  authenticated: Bool = true) async throws -> R {
        if authenticated && installKey.isEmpty { throw LiveError.missingKey }
        var request = URLRequest(url: baseURL.appendingPathComponent(path), timeoutInterval: 5)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if authenticated { request.setValue(installKey, forHTTPHeaderField: "X-Install-Key") }
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        if let body {
            do { request.httpBody = try JSONEncoder().encode(body) } catch { throw LiveError.invalidResponse }
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw LiveError.unreachable
        }
        guard let http = response as? HTTPURLResponse else { throw LiveError.invalidResponse }
        switch http.statusCode {
        case 200..<300:
            do { return try JSONDecoder().decode(R.self, from: data) } catch { throw LiveError.invalidResponse }
        case 401, 403: throw LiveError.unauthorized
        case 409: throw LiveError.conflict
        case 429: throw LiveError.rateLimited
        case 400..<500: throw LiveError.rejected(Self.reason(in: data))
        default: throw LiveError.server(http.statusCode)
        }
    }

    /// FastAPI errors look like {"detail":"..."}; anything else becomes a generic phrase.
    private static func reason(in data: Data) -> String {
        struct Detail: Decodable { var detail: String }
        return (try? JSONDecoder().decode(Detail.self, from: data))?.detail ?? "bad request"
    }
}
