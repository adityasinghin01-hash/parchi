import Foundation

/// Asks the lab server to delete everything it holds for this install (POST /reset with the install key; gap U19).
/// Reuses the address and key saved in `BackendSettings`. In Mock mode no network call is made. Only a 2xx reply whose JSON is
/// `{"ok": true}` counts as deleted; anything else is "NOT confirmed".
struct ResetClient {
    enum Outcome: Equatable {
        case deleted(Int)       // server confirmed; number of test orders removed
        case noServerCopy       // Mock mode and the app has never used Live: nothing was ever sent
        case mayExist           // Mock mode, but the app used Live before: a server copy may exist
        case noKey              // Live mode but no install key saved, so the server cannot tell whose data to delete
        case notReached         // network down or wrong address
        case notConfirmed       // the server answered, but not with a clear {"ok": true}

        var message: String {
            switch self {
            case .deleted(let n): return (n == 0 ? "Server copy deleted." : "Server copy deleted (\(n) test order\(n == 1 ? "" : "s")).")
                + " The lab server's workflow log of order steps is kept for up to 24 hours."
            case .noServerCopy: return "Mock mode: nothing was ever sent to a server."
            case .mayExist: return "A server copy may exist: switch to Live and delete again."
            case .noKey: return "No install key is saved, so the server copy could not be asked to delete. Add the key in the Developer panel and try again."
            case .notReached: return "Server copy NOT confirmed deleted: the server could not be reached. Try again on Wi-Fi."
            case .notConfirmed: return "Server copy NOT confirmed deleted: the server did not give a clear yes. Try again."
            }
        }

        var needsRetry: Bool { self == .notReached || self == .noKey || self == .notConfirmed }
        /// True only when the server said so.
        var isConfirmedDeleted: Bool { if case .deleted = self { return true } else { return false } }
    }

    let baseURL: URL?
    let installKey: String
    let isLive: Bool
    let usedLiveBefore: Bool
    var session: URLSession = .shared

    @MainActor
    init(settings: BackendSettings, session: URLSession = .shared, defaults: UserDefaults = .standard) {
        usedLiveBefore = BackendUsage.hasUsedLive(defaults)
        baseURL = URL(string: settings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines))
        installKey = settings.installKey.trimmingCharacters(in: .whitespacesAndNewlines)
        isLive = settings.mode == .live
        self.session = session
    }

    func reset() async -> Outcome {
        guard isLive else { return usedLiveBefore ? .mayExist : .noServerCopy }
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
            guard let http = response as? HTTPURLResponse else { return .notReached }
            guard (200..<300).contains(http.statusCode) else { return .notConfirmed }
            struct Reply: Decodable { var ok: Bool?; var deleted: Int? }
            guard let reply = try? JSONDecoder().decode(Reply.self, from: data), reply.ok == true else { return .notConfirmed }
            return .deleted(reply.deleted ?? 0)
        } catch {
            return .notReached
        }
    }
}
