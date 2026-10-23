import Foundation

/// One line the reader (Aditya Singhal's model behind `POST /read`) found on a parchi. Contract: docs/team/READER-CONTRACT.md.
struct ReaderLine: Decodable, Equatable {
    var kind: String?          // "medicine" (default) | "test"
    var name: String
    var strength: String?
    var quantity: Int?
    var schedule: String?      // "1-0-1", "OD", ...
}

struct ReaderResponse: Decodable { var lines: [ReaderLine] }

enum ReaderError: Error {
    case notConnected, rejected(String), unreachable, invalidResponse

    var message: String {
        switch self {
        case .notConnected: return "The reader is not connected yet, so the demo parchi is shown."
        case .rejected(let reason): return "The reader could not use this photo (\(reason))."
        case .unreachable: return "Can't reach the server. Try again on the same Wi-Fi as the lab iMac."
        case .invalidResponse: return "The reader answered in a way the app does not understand."
        }
    }
}

/// Sends the ALREADY BLURRED crop to the reader. The unblurred photo never reaches this type.
struct ReaderClient {
    let live: LiveClient

    func read(jpeg: Data) async throws -> [ReaderLine] {
        if live.installKey.isEmpty { throw ReaderError.rejected("missing install key") }
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
        do { (data, response) = try await live.session.upload(for: request, from: body) } catch { throw ReaderError.unreachable }
        guard let http = response as? HTTPURLResponse else { throw ReaderError.invalidResponse }
        switch http.statusCode {
        case 200..<300:
            guard let parsed = try? JSONDecoder().decode(ReaderResponse.self, from: data) else { throw ReaderError.invalidResponse }
            return parsed.lines
        case 503: throw ReaderError.notConnected
        case 413, 415, 422: throw ReaderError.rejected("HTTP \(http.statusCode)")
        default: throw ReaderError.unreachable
        }
    }
}
