import Foundation

/// Asks the lab server to delete everything it holds for this install (POST /reset with the install key; gap U19).
/// Reuses the address and key saved in `BackendSettings`. In Mock mode there is no server copy and no network call is made.
struct ResetClient {
    enum Outcome: Equatable {
        case deleted(Int)       // server confirmed; number of test orders removed
        case noServerCopy       // Mock mode: the app never talked to a server
        case noKey              // Live mode but no install key saved, so the server cannot tell whose data to delete
        case notReached         // network down, wrong address, or the server refused

        var message: String {
            switch self {
            case .deleted(let n): return n == 0 ? "Server copy checked: nothing was stored." : "Server copy deleted (\(n) test order\(n == 1 ? "" : "s"))."
            case .noServerCopy: return "Mock mode: nothing was ever sent to a server."
            case .noKey: return "No install key is saved, so the server copy could not be asked to delete. Add the key in the Developer panel and try again."
            case .notReached: return "Server copy not reached, try again on Wi-Fi."
            }
        }

        var needsRetry: Bool { self == .notReached || self == .noKey }
    }

    let baseURL: URL?
    let installKey: String
    let isLive: Bool
    var session: URLSession = .shared

    @MainActor
    init(settings: BackendSettings, session: URLSession = .shared) {
        baseURL = URL(string: settings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines))
        installKey = settings.installKey.trimmingCharacters(in: .whitespacesAndNewlines)
        isLive = settings.mode == .live
        self.session = session
    }

    func reset() async -> Outcome {
        guard isLive else { return .noServerCopy }
        guard !installKey.isEmpty else { return .noKey }
        guard let baseURL, let scheme = baseURL.scheme?.lowercased(), scheme == "http" || scheme == "https", baseURL.host != nil else { return .notReached }
        var request = URLRequest(url: baseURL.appendingPathComponent("reset"), timeoutInterval: 8)
        request.httpMethod = "POST"
        request.setValue(installKey, forHTTPHeaderField: "X-Install-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = Data("{}".utf8)
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return .notReached }
            struct Reply: Decodable { var ok: Bool?; var deleted: Int? }
            let reply = try? JSONDecoder().decode(Reply.self, from: data)
            return .deleted(reply?.deleted ?? 0)
        } catch {
            return .notReached
        }
    }
}
