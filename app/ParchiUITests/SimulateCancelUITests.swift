import XCTest

/// The Track screen's demo button: tapping "Simulate cancel" on an online seller opens the Plan B sheet (Mock mode, no server).
final class SimulateCancelUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testSimulateCancelButtonOpensPlanB() {
        let app = XCUIApplication()
        app.launchArguments = ["-demoRoute", "track", "-backendMode", "mock"]
        app.launch()
        let cancel = app.buttons["Simulate cancel"].firstMatch
        // The bottom bar ("What next?") can cover the button's centre: scroll until the whole button is above it.
        let footer = app.buttons["What next? Doses and refills"]
        for _ in 0..<8 {
            if cancel.exists && cancel.isHittable && cancel.frame.maxY < footer.frame.minY { break }
            app.swipeUp()
        }
        XCTAssertTrue(cancel.isHittable, "the demo cancel button should be reachable by scrolling")
        XCTAssertLessThan(cancel.frame.maxY, footer.frame.minY, "the bottom bar must not cover the cancel button")
        cancel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["Approve"].waitForExistence(timeout: 8),
                      "tapping Simulate cancel should open the Plan B sheet (button still there: \(cancel.exists), cancelled text: \(app.staticTexts["Cancelled by seller"].exists))")
    }
}
