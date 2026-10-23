import XCTest

/// Acceptance T3 (UI version): the Live app on the iMac simulator, a judge cancel from the server side,
/// then a REAL tap on "Approve" in the Plan B sheet. Needs the lab server running; skipped otherwise.
/// Run: TEST_RUNNER_PARCHI_BASE_URL=http://localhost:8000 TEST_RUNNER_PARCHI_INSTALL_KEY=... TEST_RUNNER_PARCHI_ADMIN_KEY=... xcodebuild test ...
final class PlanBFlowUITests: XCTestCase {
    private var base = ""
    private var installKey = ""
    private var adminKey = ""

    override func setUpWithError() throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        guard let b = env["PARCHI_BASE_URL"], let k = env["PARCHI_INSTALL_KEY"], let a = env["PARCHI_ADMIN_KEY"] else {
            throw XCTSkip("Set TEST_RUNNER_PARCHI_BASE_URL / _INSTALL_KEY / _ADMIN_KEY for the live run")
        }
        base = b; installKey = k; adminKey = a
        _ = try request("POST", "/reset?scope=demo", admin: true, body: [:])
    }

    func testJudgeCancelShowsPlanBAndApproveReroutes() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demoRoute", "track", "-backendMode", "live", "-backendURL", base, "-installKey", installKey]
        app.launch()

        let order = try waitForReadyOrder()
        let victim = try XCTUnwrap(order.sellers.first?.id)
        _ = try request("POST", "/judge/\(order.orderID)/event", admin: true, body: ["sellerID": victim, "kind": "cancelled"])

        let approve = app.buttons["Approve"]
        XCTAssertTrue(approve.waitForExistence(timeout: 10), "Plan B sheet should appear after the judge cancels a seller")
        approve.tap()

        XCTAssertTrue(app.staticTexts["Re-routed (Plan B)"].waitForExistence(timeout: 10), "Track should show the re-routed seller")
        let final = try waitFor("plan version 2 placed") { (try? self.status(order.orderID)).map { $0.planVersion == 2 && $0.state == "placed" } ?? false }
        XCTAssertTrue(final)
    }

    // MARK: server helpers (synchronous, test-only)

    private struct JudgeOrder: Decodable { let orderID: String; let ready: Bool; let sellers: [Seller]; struct Seller: Decodable { let id: String; let status: String } }
    private struct Status: Decodable { let state: String; let planVersion: Int }

    private func waitForReadyOrder() throws -> JudgeOrder {
        var found: JudgeOrder?
        _ = try waitFor("order appears", timeout: 25) {
            let data = (try? self.request("GET", "/judge/orders", admin: true)) ?? Data()
            found = (try? JSONDecoder().decode([JudgeOrder].self, from: data))?.first(where: { $0.ready && !$0.sellers.isEmpty })
            return found != nil
        }
        return try XCTUnwrap(found)
    }

    private func status(_ id: String) throws -> Status {
        try JSONDecoder().decode(Status.self, from: request("GET", "/status/\(id)"))
    }

    private func waitFor(_ what: String, timeout: TimeInterval = 15, _ condition: () -> Bool) throws -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end { if condition() { return true }; Thread.sleep(forTimeInterval: 0.5) }
        XCTFail("timeout waiting for \(what)")
        return false
    }

    @discardableResult
    private func request(_ method: String, _ path: String, admin: Bool = false, body: [String: Any]? = nil) throws -> Data {
        var req = URLRequest(url: URL(string: base + path)!)
        req.httpMethod = method
        req.setValue(admin ? adminKey : installKey, forHTTPHeaderField: admin ? "X-Admin-Key" : "X-Install-Key")
        if let body { req.httpBody = try JSONSerialization.data(withJSONObject: body); req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let sem = DispatchSemaphore(value: 0)
        var out = Data(); var failure: Error?
        URLSession.shared.dataTask(with: req) { d, _, e in out = d ?? Data(); failure = e; sem.signal() }.resume()
        sem.wait()
        if let failure { throw failure }
        return out
    }
}
