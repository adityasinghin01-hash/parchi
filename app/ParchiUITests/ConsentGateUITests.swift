import XCTest

/// The consent screen is shown ONCE, in front of the first photo, and "Not now" reads and keeps nothing.
/// The launch arguments below override the saved agreement (empty date + version 0 = never agreed) for this launch only.
final class ConsentGateUITests: XCTestCase {
    private let sample = "/tmp/parchi_samples/s10_000278.jpg"

    override func setUpWithError() throws { continueAfterFailure = false }

    private func launchNeverAgreed() throws -> XCUIApplication {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sample), "sample parchi not on this machine")
        let app = XCUIApplication()
        app.launchArguments = ["-backendMode", "mock", "-parchi.consentAt", "", "-parchi.consentVersion", "0", "-captureImagePath", sample]
        app.launch()
        return app
    }

    func testFirstPhotoAsksForConsentAndNotNowKeepsNothing() throws {
        let app = try launchNeverAgreed()
        let agree = app.buttons["Agree & continue"]
        XCTAssertTrue(agree.waitForExistence(timeout: 15), "the consent screen must come before the photo")
        XCTAssertFalse(app.navigationBars["Check your photo"].exists, "no photo is read before the person agrees")
        let notNow = app.buttons["Not now"]
        XCTAssertTrue(notNow.exists)
        notNow.tap()
        XCTAssertFalse(app.navigationBars["Check your photo"].waitForExistence(timeout: 4), "declining must not open the photo")
        XCTAssertTrue(app.buttons["Scan or share parchi"].waitForExistence(timeout: 5), "back on Home")
    }

    func testAgreeThenThePhotoPreviewOpens() throws {
        let app = try launchNeverAgreed()
        let agree = app.buttons["Agree & continue"]
        XCTAssertTrue(agree.waitForExistence(timeout: 15))
        agree.tap()
        XCTAssertTrue(app.navigationBars["Check your photo"].waitForExistence(timeout: 20), "after Agree the blurred preview opens")
    }
}
