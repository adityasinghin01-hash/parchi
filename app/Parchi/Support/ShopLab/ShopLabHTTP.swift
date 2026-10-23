import Foundation

/// Same rules as `LiveClient` (X-Install-Key header, 5 s timeout, `LiveError` for every failure, never a crash),
/// reused for the Phase 3 endpoints in server/CONTRACT_P3.md. LiveClient's own `send` is private, so this is a twin of it.
struct ShopLabTransport {
    let live: LiveClient

    func send<R: Decodable, B: Encodable>(_ method: String, _ path: String, body: B?) async throws -> R {
        if live.installKey.isEmpty { throw LiveError.missingKey }
        var request = URLRequest(url: live.baseURL.appendingPathComponent(path), timeoutInterval: 5)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(live.installKey, forHTTPHeaderField: "X-Install-Key")
        if let body {
            do { request.httpBody = try JSONEncoder().encode(body) } catch { throw LiveError.invalidResponse }
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await live.session.data(for: request)
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

    func get<R: Decodable>(_ path: String) async throws -> R {
        try await send("GET", path, body: Optional<NoBody>.none)
    }

    func post<R: Decodable, B: Encodable>(_ path: String, body: B) async throws -> R {
        try await send("POST", path, body: body)
    }

    struct NoBody: Encodable {}

    private static func reason(in data: Data) -> String {
        struct Detail: Decodable { var detail: String }
        return (try? JSONDecoder().decode(Detail.self, from: data))?.detail ?? "bad request"
    }
}

/// ISO-8601 with the +05:30 offset (the contract's time format) and IST display helpers.
enum ISOTime {
    static let ist = TimeZone(identifier: "Asia/Kolkata") ?? TimeZone(secondsFromGMT: 19_800) ?? .gmt

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = ist
        return calendar
    }

    static func string(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = ist
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    /// Accepts "2026-10-23T18:00:00+05:30", with fractional seconds, with "Z", or with no offset (read as IST).
    static func parse(_ text: String?) -> Date? {
        guard let text, !text.isEmpty else { return nil }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: text) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: text) { return date }
        for pattern in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss"] {
            let naive = DateFormatter()
            naive.locale = Locale(identifier: "en_US_POSIX")
            naive.timeZone = ist
            naive.dateFormat = pattern
            if let date = naive.date(from: text) { return date }
        }
        return nil
    }

    static func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = ist
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    /// "6:00 pm"
    static func clock(_ date: Date) -> String { format(date, "h:mm a").lowercased() }
    /// "24 Oct, 7:00 am"
    static func slot(_ date: Date) -> String { format(date, "d MMM, h:mm a").replacingOccurrences(of: "AM", with: "am").replacingOccurrences(of: "PM", with: "pm") }
}

/// Phone numbers: digits only for wa.me; 10-digit Indian numbers get the 91 prefix.
enum PhoneNumber {
    static func digits(_ raw: String) -> String? {
        var digits = raw.filter(\.isNumber)
        if digits.count == 11, digits.hasPrefix("0") { digits.removeFirst() }
        if digits.count == 10 { digits = "91" + digits }
        return digits.count >= 11 ? digits : nil
    }
}

extension String {
    /// Percent-encodes everything but unreserved characters so "&", "+", newlines and Hindi text survive inside a URL query.
    var urlQueryValue: String {
        addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")) ?? self
    }
}
