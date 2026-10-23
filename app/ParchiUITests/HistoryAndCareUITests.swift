import XCTest

/// Acceptance T7 (reopen part): a saved parchi opens and shows its plan in Mock mode, where the app makes no server call at all.
/// (The Simulator cannot switch Wi-Fi off, so "no network needed" is shown by Mock mode itself.)
final class HistoryAndCareUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ route: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demoRoute", route, "-backendMode", "mock"]
        app.launch()
        return app
    }

    func testSavedParchiReopensOnThePhone() {
        let app = launch("history")
        XCTAssertTrue(app.navigationBars["Recent parchis"].waitForExistence(timeout: 10))
        // The demo route draws History over the Track screen, so find the History row by its own text, not "first cell".
        let row = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'medicines'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "the seeded demo parchi should be listed")
        // The demo route draws the screen as an overlay, so tap by coordinate instead of relying on isHittable.
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        // Top of the reopened plan: its own saved totals, read from the phone's storage.
        let trips = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'In-person trips'")).firstMatch
        XCTAssertTrue(trips.waitForExistence(timeout: 8), "the reopened plan should show its saved totals")
        // The reassurance line is at the bottom of a long list, so scroll to it.
        let saved = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'opens without internet'")).firstMatch
        for _ in 0..<6 where !saved.exists { app.swipeUp() }
        XCTAssertTrue(saved.waitForExistence(timeout: 3), "the plan should say it is stored on this phone")
    }

    func testCareShowsDosesAndARefillDate() {
        let app = launch("care")
        XCTAssertTrue(app.navigationBars["Care"].waitForExistence(timeout: 10))
        let refill = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'refill'")).firstMatch
        XCTAssertTrue(refill.waitForExistence(timeout: 8), "Care should show a refill line for the seeded parchi")
    }
}
