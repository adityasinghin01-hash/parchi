import XCTest

/// K13: the preview says what the code does, the zero-redaction box gates "Use this photo", and the Delete screen is plain about the Calendar.
final class PrivacyK13UITests: XCTestCase {
    private let zeroSample = "/tmp/parchi_samples/k13_zero.png"
    private let sample = "/tmp/parchi_samples/s10_000278.jpg"

    override func setUpWithError() throws { continueAfterFailure = false }

    func testNothingHiddenBlocksUseUntilTheBoxIsTicked() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: zeroSample), "k13 sample image not on this machine")
        let app = XCUIApplication()
        app.launchArguments = ["-backendMode", "mock", "-parchi.consentAt", "2026-10-24T00:00:00Z", "-parchi.consentVersion", "1", "-captureImagePath", zeroSample]
        app.launch()
        XCTAssertTrue(app.navigationBars["Check your photo"].waitForExistence(timeout: 15))
        let box = app.switches["noPersonalDetailsToggle"]
        XCTAssertTrue(box.waitForExistence(timeout: 20), app.debugDescription)
        let use = app.buttons["Use this photo"]
        XCTAssertTrue(use.exists)
        XCTAssertFalse(use.isEnabled, "nothing hidden and no tick: Use this photo must be disabled")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'We try to hide the name, age, phone and address we can find. Check the picture'")).firstMatch.exists)
        save(app, as: "k13-zero-unticked")
        box.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        save(app, as: "k13-zero-ticked")
        XCTAssertTrue(use.isEnabled, "after ticking I checked: ... the button works")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '%'")).firstMatch.exists, "no percentage on the preview")
    }

    func testHiddenAreasNeedNoTickAndTheNoteIsHonest() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sample), "sample parchi not on this machine")
        let app = XCUIApplication()
        app.launchArguments = ["-backendMode", "mock", "-parchi.consentAt", "2026-10-24T00:00:00Z", "-parchi.consentVersion", "1", "-captureImagePath", sample]
        app.launch()
        XCTAssertTrue(app.images["Your parchi, with the details we could find covered"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Use this photo"].isEnabled)
        XCTAssertFalse(app.switches["noPersonalDetailsToggle"].exists)
        save(app, as: "k13-preview")
    }

    func testDeleteScreenSaysCalendarEventsStay() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-backendMode", "mock", "-demoRoute", "settings"]
        app.launch()
        let note = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Events Parchi added to your Calendar stay there; delete them in the Calendar app.'")).firstMatch
        var tries = 0
        while !note.exists && tries < 6 { app.swipeUp(); tries += 1 }
        XCTAssertTrue(note.waitForExistence(timeout: 5), app.debugDescription)
    }

    private func save(_ app: XCUIApplication, as name: String) {
        // Screenshots for the K13 report (written next to the other verification aids; ignored when /tmp is not writable).
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/\(name).png"))
    }

    func testDeleteEverythingResultIsHonestAndNamesTheCalendar() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-backendMode", "mock", "-demoRoute", "settings"]
        app.launch()
        let button = app.buttons.matching(NSPredicate(format: "label == 'Delete everything'")).firstMatch
        var tries = 0
        while !app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Calendar app.'")).firstMatch.exists && tries < 8 { app.swipeUp(); tries += 1 }
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        save(app, as: "k13-delete-screen")
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        sleep(1)   // the confirmation dialog's button is listed first
        let all = app.buttons.matching(NSPredicate(format: "label == 'Delete everything'"))
        XCTAssertTrue(all.firstMatch.waitForExistence(timeout: 5))
        all.element(boundBy: 0).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let done = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'on this phone'")).firstMatch
        _ = done.waitForExistence(timeout: 20)
        sleep(2)
        save(app, as: "k13-delete-result")
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Everything on this phone is deleted.'")).firstMatch.exists, app.debugDescription)
        let mock = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Mock mode: nothing was ever sent' OR label BEGINSWITH 'A server copy may exist'")).firstMatch
        XCTAssertTrue(mock.exists, "Mock-mode result must be one of the two honest sentences")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'stay there; delete them in the Calendar app.'")).firstMatch.exists)
    }
}
