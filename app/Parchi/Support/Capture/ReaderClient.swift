import Foundation

/// One line the reader (`POST /read` on the lab server, Anthropic's Claude behind it) found on a parchi. Contract: docs/team/READER-CONTRACT.md.
struct ReaderLine: Decodable, Equatable {
    var kind: String?          // "medicine" (default) | "test"
    var name: String
    var strength: String?
    var quantity: Int?
    var schedule: String?      // "1-0-1", "OD", ...
}

struct ReaderResponse: Decodable { var lines: [ReaderLine] }

/// Error body of `/read`: `{"detail": "...", "code": "cap_reached"}`. `code` is the machine code (READER-CONTRACT.md).
private struct ReaderErrorBody: Decodable { var code: String? }

extension ReaderFailure: Error {}

/// Sends the ALREADY BLURRED crop to the reader. The unblurred photo never reaches this type.
/// Every failure is thrown as a `ReaderFailure` (server `code` first, then the HTTP status; a network failure is `.offline`).
struct ReaderClient {
    let live: LiveClient

    func read(jpeg: Data) async throws -> [ReaderLine] {
        if live.installKey.isEmpty { throw ReaderFailure.notConfigured }
        let boundary = "parchi-" + UUID().uuidString
        var body = Data()
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"image\"; filename=\"parchi.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".utf8))
        body.append(jpeg)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        var request = URLRequest(url: live.baseURL.appendingPathComponent("read"), timeoutInterval: 65)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(live.installKey, forHTTPHeaderField: "X-Install-Key")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await live.session.upload(for: request, from: body)
        } catch let error as URLError where error.code == .timedOut {
            throw ReaderFailure.timeout
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw ReaderFailure.offline
        }
        guard let http = response as? HTTPURLResponse else { throw ReaderFailure.readerError }
        if (200..<300).contains(http.statusCode) {
            guard let parsed = try? JSONDecoder().decode(ReaderResponse.self, from: data) else { throw ReaderFailure.readerError }
            return parsed.lines
        }
        throw Self.failure(status: http.statusCode, body: data)
    }

    /// Server answer that is not 2xx -> the failure to show. The machine `code` wins; the status is the fallback for an older server.
    static func failure(status: Int, body: Data) -> ReaderFailure {
        if let code = (try? JSONDecoder().decode(ReaderErrorBody.self, from: body))?.code, let failure = ReaderFailure(code: code) {
            return failure
        }
        switch status {
        case 503: return .notConfigured     // older server: "reader not connected"
        case 429: return .slowDown
        case 504: return .timeout
        default: return .readerError
        }
    }
}
