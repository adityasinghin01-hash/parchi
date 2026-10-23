import XCTest

/// K21: runs the seller probe (every seller in `SellerSites`, 40 s timeout each) with READ-ONLY page checks and asserts that the
/// report was produced. It makes no claim about which sellers load: that depends on the sellers and the network, so it is written down,
/// not asserted. It SKIPS when this machine is offline. Nothing is clicked or typed on a seller's site.
/// Output: `/tmp/k21/probe-<time>/report.json` plus one PNG per page.
final class CheckoutProbeUITests: XCTestCase {
    private let sellerIDs = ["truemeds", "onemg", "pharmeasy", "medkart", "medplus", "netmeds", "apollopharmacy", "blinkit", "instamart",
                             "redcliffe", "healthians", "apollo", "max"]

    override func setUpWithError() throws { continueAfterFailure = false }

    private func internetIsReachable() -> Bool {
        let done = DispatchSemaphore(value: 0)
        var ok = false
        var request = URLRequest(url: URL(string: "https://www.apple.com/library/test/success.html")!)
        request.timeoutInterval = 6
        URLSession(configuration: .ephemeral).dataTask(with: request) { _, response, _ in
            ok = (response as? HTTPURLResponse)?.statusCode == 200
            done.signal()
        }.resume()
        _ = done.wait(timeout: .now() + 8)
        return ok
    }

    func testProbeProducesAReportForEverySeller() throws {
        try XCTSkipUnless(internetIsReachable(), "no internet on this machine: the seller probe cannot run")
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "")
        let dir = "/tmp/k21/probe-\(stamp)"
        let app = XCUIApplication()
        app.launchArguments = ["-backendMode", "mock", "-parchi.consentAt", "2026-10-24T00:00:00Z", "-parchi.consentVersion", "2",
                               "-demoRoute", "checkout", "-checkoutScreen", "probe", "-probeAuto", "1", "-probeOut", dir]
        app.launch()
        let status = app.staticTexts["probe.status"]
        XCTAssertTrue(status.waitForExistence(timeout: 30), "the probe screen should open")
        let finished = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'done'"), object: status)
        XCTAssertEqual(XCTWaiter().wait(for: [finished], timeout: 1500), .completed, "the probe did not finish in 25 minutes")

        let data = try XCTUnwrap(FileManager.default.contents(atPath: dir + "/report.json"), "report.json was not written to \(dir)")
        let entries = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let seen = Set(entries.compactMap { $0["id"] as? String })
        for id in sellerIDs { XCTAssertTrue(seen.contains(id), "no probe entry for \(id)") }
        for e in entries { XCTAssertFalse((e["outcome"] as? String ?? "").isEmpty, "entry without a verdict: \(e["id"] ?? "?")") }
        // The internet check passed above, so every page failing as "offline" means the Simulator lost the network: skip, do not fail.
        if entries.allSatisfy({ ($0["outcome"] as? String) == "offline" }) { throw XCTSkip("every page failed as offline") }
        let shots = (try? FileManager.default.contentsOfDirectory(atPath: dir).filter { $0.hasSuffix(".png") }) ?? []
        XCTAssertGreaterThanOrEqual(shots.count, sellerIDs.count, "one screenshot per seller expected")
    }
}
