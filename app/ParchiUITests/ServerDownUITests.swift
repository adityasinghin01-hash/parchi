import XCTest

/// Resilience: with the app in Live mode and NO server reachable, Plan B still works on the phone (the demo must survive a dead iMac).
final class ServerDownUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testPlanBStillWorksWhenTheServerIsDown() {
        let app = XCUIApplication()
        // Port 9 (discard) has nothing listening: every call fails fast. `-demoRoute planB` places the demo orders and cancels one online seller locally.
        app.launchArguments = ["-demoRoute", "planB", "-backendMode", "live", "-backendURL", "http://localhost:9", "-installKey", "none"]
        app.launch()
        let approve = app.buttons["Approve"]
        XCTAssertTrue(approve.waitForExistence(timeout: 12), "the Plan B sheet must appear without any server")
        approve.tap()
        XCTAssertTrue(app.staticTexts["Re-routed (Plan B)"].waitForExistence(timeout: 8), "the re-routed seller must show after approving")
    }
}
