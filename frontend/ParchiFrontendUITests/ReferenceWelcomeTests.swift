import XCTest

final class ReferenceWelcomeTests: XCTestCase {
    @MainActor func testReferenceContentAndOptionalUsagePreference() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Parchi"].exists)
        XCTAssertTrue(app.buttons["welcome.permission.location"].exists)
        XCTAssertTrue(app.buttons["welcome.permission.camera"].exists)
        XCTAssertTrue(app.buttons["welcome.permission.notifications"].exists)
        app.swipeUp()
        app.buttons["welcome.permission.usage"].tap()
        XCTAssertTrue(app.switches["welcome.usage.toggle"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Optional and off by default. This build stores your preference only; it does not collect or send analytics."].exists)
        app.buttons["Done"].tap()
        app.buttons["welcome.guest"].tap()
        XCTAssertTrue(app.alerts["Continue as Guest"].waitForExistence(timeout: 2))
    }

    @MainActor func testAgreeDoesNotOpenOldRegistrationOrDashboard() {
        let app = XCUIApplication()
        app.launch()
        app.swipeUp()
        app.buttons["welcome.agree"].tap()
        XCTAssertTrue(app.alerts["Your preferences are saved"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.textFields["profile.firstName"].exists)
        XCTAssertFalse(app.staticTexts["dashboard.title"].exists)
    }

    @MainActor func testLargeTextReferenceScreen() {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.swipeUp(); app.swipeUp(); app.swipeUp()
        XCTAssertTrue(app.buttons["welcome.guest"].isHittable)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Reference welcome large text"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
