import XCTest

/// The Track screen's demo button: tapping "Simulate cancel" on an online seller opens the Plan B sheet (Mock mode, no server).
final class SimulateCancelUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testSimulateCancelButtonOpensPlanB() {
        let app = XCUIApplication()
        app.launchArguments = ["-demoRoute", "track", "-backendMode", "mock"]
        app.launch()
        let cancel = app.buttons["Simulate cancel"].firstMatch
        for _ in 0..<8 where !(cancel.exists && cancel.isHittable) { app.swipeUp() }
        XCTAssertTrue(cancel.isHittable, "the demo cancel button should be reachable by scrolling")
        cancel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["Approve"].waitForExistence(timeout: 8), "tapping Simulate cancel should open the Plan B sheet")
    }
}
