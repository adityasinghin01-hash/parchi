import XCTest

final class OnboardingFlowTests: XCTestCase {
    @MainActor
    func testRegistrationRequiresDetailsAndReachesDashboard() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["welcome.continue"].tap()
        app.buttons["details.continue"].tap()
        XCTAssertTrue(app.staticTexts["Please enter your first name."].exists)
        app.textFields["profile.firstName"].tap()
        app.textFields["profile.firstName"].typeText("Aditi")
        app.textFields["profile.phone"].tap()
        app.textFields["profile.phone"].typeText("9876543210")
        app.swipeUp()
        app.buttons["profile.location"].tap()
        app.buttons["location.Meerut"].tap()
        app.buttons["details.continue"].tap()
        app.textFields["account.username"].tap()
        app.textFields["account.username"].typeText("aditi")
        app.secureTextFields["account.password"].tap()
        app.secureTextFields["account.password"].typeText("preview123")
        app.swipeUp()
        app.buttons["account.submit"].tap()
        XCTAssertTrue(app.staticTexts["You’re all set."].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["dashboard.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Hello, Aditi"].exists)
        XCTAssertFalse(app.staticTexts["Your profile preview is complete."].exists)
    }

    @MainActor
    func testHindiLoginAndPasswordVisibility() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["language.hi"].tap()
        app.buttons["switch.login"].tap()
        XCTAssertTrue(app.staticTexts["फिर से स्वागत है।"].exists)
        app.textFields["account.username"].tap()
        app.textFields["account.username"].typeText("demo")
        app.secureTextFields["account.password"].tap()
        app.secureTextFields["account.password"].typeText("preview123")
        app.buttons["पासवर्ड दिखाएँ"].tap()
        XCTAssertEqual(app.textFields["account.password"].value as? String, "preview123")
        app.swipeUp()
        app.buttons["login.submit"].tap()
        XCTAssertTrue(app.staticTexts["dashboard.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["dashboard.scan"].exists)
    }
}
