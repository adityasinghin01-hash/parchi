import XCTest

/// Live "Ask nearby shops" acceptance (K10): the Live app on the iMac simulator sends a real ask, the test answers as the
/// first shop through the judge endpoint, and the sheet must show "Replied" for that shop and "Not needed any more" for the rest.
/// Needs the lab server running; skipped otherwise.
/// Run: TEST_RUNNER_PARCHI_BASE_URL=http://localhost:8000 TEST_RUNNER_PARCHI_INSTALL_KEY=... TEST_RUNNER_PARCHI_ADMIN_KEY=... \
///      xcodebuild test -only-testing:ParchiUITests/ShopAskLiveUITests ...
final class ShopAskLiveUITests: XCTestCase {
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

    func testAskNearbyShopsReplyShowsRepliedAndNotNeeded() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demoRoute", "askShops", "-backendMode", "live", "-backendURL", base, "-installKey", installKey]
        app.launch()

        let pick = app.buttons["Pick the nearest 3"]
        XCTAssertTrue(pick.waitForExistence(timeout: 15), "The Ask nearby shops sheet should open with its Pick button")
        // The list row sits partly under the bottom "Send" bar; scroll it clear first so the tap cannot hit Send by mistake.
        let sendBar = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Send to'")).firstMatch
        for _ in 0..<4 where sendBar.exists && pick.frame.maxY > sendBar.frame.minY - 20 {
            app.collectionViews.containing(.button, identifier: "Pick the nearest 3").firstMatch.swipeUp()
        }
        XCTAssertLessThanOrEqual(pick.frame.maxY, sendBar.frame.minY - 20, "Pick the nearest 3 must not sit under the Send bar")
        press(pick)

        let send = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Send to'")).firstMatch
        XCTAssertTrue(send.waitForExistence(timeout: 5), "A 'Send to N shops' button should be there")
        let label = send.label
        let picked = Int(label.split(separator: " ").compactMap { Int($0) }.first ?? 0)
        XCTAssertGreaterThanOrEqual(picked, 2, "Need at least two picked shops to see 'Not needed any more' (button said '\(label)')")
        XCTAssertTrue(send.isEnabled, "'\(label)' should be enabled after picking shops")
        press(send)

        let ask = try waitForAsk()
        let first = try XCTUnwrap(ask.shops.first, "The ask should contain shops")
        XCTAssertEqual(ask.state, "waiting")
        XCTAssertEqual(ask.round, 1)

        let readyBy = ISO8601DateFormatter()
        readyBy.timeZone = TimeZone(identifier: "Asia/Kolkata")
        let items: [[String: Any]] = ask.items.enumerated().map { n, item in
            ["itemID": item.itemID, "available": true, "pricePaise": 4500 + 1250 * n]
        }
        let reply = try request("POST", "/judge/shop/\(ask.askID)/reply", admin: true, body: [
            "shopID": first.shopID,
            "items": items,
            "readyBy": readyBy.string(from: Date().addingTimeInterval(30 * 60)),
        ])
        XCTAssertTrue(String(decoding: reply, as: UTF8.self).contains("\"ok\":true"), "The judge reply should be accepted")

        let replied = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Replied'")).firstMatch
        XCTAssertTrue(replied.waitForExistence(timeout: 30), "The sheet should show 'Replied' for the shop that answered")
        let notNeeded = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Not needed any more'"))
        XCTAssertTrue(notNeeded.firstMatch.waitForExistence(timeout: 30), "The other shops should show 'Not needed any more'")
        XCTAssertEqual(notNeeded.count, picked - 1, "Every other picked shop should say 'Not needed any more'")

        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        press(done)
        XCTAssertTrue(app.navigationBars["Ask nearby shops"].waitForNonExistence(timeout: 10), "Done should close the sheet")
    }

    // MARK: UI helpers

    /// `.tap()` can miss buttons inside a List/overlay here; tap the middle of the element's frame instead.
    private func press(_ element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    // MARK: server helpers (synchronous, test-only)

    private struct Ask: Decodable {
        let askID: String; let state: String; let round: Int
        let shops: [Shop]; let items: [Item]
        struct Shop: Decodable { let shopID: String; let name: String; let state: String }
        struct Item: Decodable { let itemID: String; let name: String; let quantity: Int }
    }

    private func waitForAsk() throws -> Ask {
        var found: Ask?
        let end = Date().addingTimeInterval(25)
        while Date() < end && found == nil {
            let data = (try? request("GET", "/judge/shop/asks", admin: true)) ?? Data()
            found = (try? JSONDecoder().decode([Ask].self, from: data))?.first
            if found == nil { Thread.sleep(forTimeInterval: 0.5) }
        }
        return try XCTUnwrap(found, "The app's ask should appear in GET /judge/shop/asks")
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
