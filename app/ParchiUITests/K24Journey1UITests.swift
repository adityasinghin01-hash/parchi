import XCTest

/// K24 journey 1: a first-time user in Mock mode walks the whole app, from consent to "Delete everything" and back to Home.
/// It records what it sees (screenshots, small targets, jargon, audit issues) in /tmp/k24/<tag>/ for a human to read, and only FAILS
/// when a screen that must be there is not (a dead end), so it can be replayed at every text size, in dark mode and on every phone.
final class K24Journey1UITests: XCTestCase {
    private let rec = K24Recorder()
    private let sample = "/tmp/parchi_samples/s10_000278.jpg"

    override func setUpWithError() throws { continueAfterFailure = false }

    /// Test aid only: `-captureImagePath` re-opens the photo preview each time Home appears; a real person never sees that.
    private func dismissPreview(_ app: XCUIApplication) {
        if app.navigationBars["Check your photo"].waitForExistence(timeout: 2), app.buttons["Close"].exists { app.buttons["Close"].tap(); Thread.sleep(forTimeInterval: 0.8) }
    }

    private func backToHome(_ app: XCUIApplication) {
        for _ in 0..<8 where !app.buttons["Scan or share parchi"].exists {
            // Test aid only: `-captureImagePath` re-opens the photo preview each time Home appears; a real person never sees that.
            if app.buttons["Close"].exists && app.navigationBars["Check your photo"].exists { app.buttons["Close"].tap(); Thread.sleep(forTimeInterval: 0.6); continue }
            let back = app.navigationBars.buttons.firstMatch
            guard back.exists else { break }
            back.tap()
            Thread.sleep(forTimeInterval: 0.4)
        }
    }

    func testFirstTimeUserWalksTheWholeApp() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sample), "sample parchi not on this machine")
        let app = XCUIApplication()
        // Never agreed + a photo handed in (the Simulator has no camera); the map shows three fake shops so the shop sheet is stable.
        app.launchArguments = rec.env.launchArguments + ["-parchi.consentAt", "", "-parchi.consentVersion", "0", "-captureImagePath", sample, "-mapTestShops", "1"]
        app.launch()

        // 1. Consent, read in full.
        let agree = app.buttons["Agree & continue"]
        XCTAssertTrue(agree.waitForExistence(timeout: 20), "consent must come before the photo")
        rec.look(app, "j1", "01-consent-top", audit: true)
        app.swipeUp()
        rec.look(app, "j1", "02-consent-bottom")
        XCTAssertTrue(agree.exists, "Agree is reachable after scrolling")
        agree.tap()

        // 2. Photo preview.
        XCTAssertTrue(app.navigationBars["Check your photo"].waitForExistence(timeout: 20))
        _ = app.images["Your parchi, with the details we could find covered"].waitForExistence(timeout: 25)
        rec.look(app, "j1", "03-preview-top", audit: true)
        let tick = app.switches["noPersonalDetailsToggle"]
        let use = app.buttons["Use this photo"]
        app.scrollTo(use, tries: 4)
        rec.look(app, "j1", "04-preview-bottom")
        if tick.exists, !use.isEnabled { tick.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap() }
        XCTAssertTrue(use.isEnabled, "Use this photo works (after the tick if asked)")
        use.tap()

        // KR (G2): Mock mode never shows the sample by itself after a read that found nothing. The person picks it explicitly.
        let title = app.navigationBars["Did we read it right?"]
        let useSample = app.buttons["readerUseSample"]
        for _ in 0..<40 where !title.exists && !useSample.exists { Thread.sleep(forTimeInterval: 1) }
        if useSample.exists {
            rec.look(app, "j1", "04b-read-failed-choice")
            useSample.tap()
        }

        // 3. Confirm.
        XCTAssertTrue(title.waitForExistence(timeout: 40), "Confirm opens after Use this photo: \(app.debugDescription)")
        Thread.sleep(forTimeInterval: 1)
        rec.look(app, "j1", "05-confirm-top", audit: true)
        // Answer the doubtful line the way a person does: the strength buttons under the question.
        do {
            let option = app.buttons.matching(NSPredicate(format: "label == '40'")).firstMatch
            if app.reach(option) { app.press(option) } else { rec.note("[j1-confirm] the answer buttons for Telma could not be reached by scrolling") }
            for _ in 0..<30 { app.nudge(up: false) }
        }
        app.scrollTo(app.buttons["Add a test"], tries: 4)
        rec.look(app, "j1", "06-confirm-bottom")
        let allCorrect = app.buttons["All correct"]
        XCTAssertTrue(allCorrect.waitForExistence(timeout: 5), "the list can be confirmed: \(app.buttons.allElementsBoundByIndex.map(\.label))")
        XCTAssertTrue(allCorrect.isEnabled)
        allCorrect.tap()

        // 4. Plan, list then map.
        XCTAssertTrue(app.navigationBars["Your plan"].waitForExistence(timeout: 20))
        Thread.sleep(forTimeInterval: 1)
        rec.look(app, "j1", "07-plan-list-top", audit: true)
        for _ in 0..<3 { app.swipeUp() }
        rec.look(app, "j1", "08-plan-list-middle")
        for _ in 0..<12 { app.swipeUp() }
        rec.look(app, "j1", "09-plan-list-bottom")
        for _ in 0..<14 { app.swipeDown() }
        let picker = app.segmentedControls["planViewPicker"]
        XCTAssertTrue(picker.exists, "List | Map switch")
        picker.buttons["Map"].tap()
        _ = app.otherElements["planMap"].waitForExistence(timeout: 10)
        Thread.sleep(forTimeInterval: 2)
        rec.look(app, "j1", "10-plan-map", audit: true)

        // 5. Shop sheet.
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'shopRow-map-testchemista'")).firstMatch
        let strip = app.descendants(matching: .any).matching(identifier: "deliveryStrip").firstMatch
        let bar = app.buttons["Get it all"]
        if row.waitForExistence(timeout: 10) {
            // A person drags the list until a row is clear of the delivery strip and the Get it all bar.
            let limit = { (strip.exists ? strip.frame.minY : bar.frame.minY) - 4 }
            var reached = false
            for _ in 0..<10 {
                if row.frame.maxY <= limit(), row.frame.minY > 0 { reached = true; break }
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62)).press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
            }
            if reached { row.tap() } else { rec.note("[j1-shop] NO SHOP ROW CAN BE REACHED: the list between the map and the bottom strip is too small (row y \(Int(row.frame.minY))-\(Int(row.frame.maxY)), limit \(Int(limit())))") }
            if app.staticTexts["shopSheetName"].waitForExistence(timeout: 5) {
                rec.look(app, "j1", "11-shop-sheet", audit: true)
                app.swipeDown(velocity: .fast)
                Thread.sleep(forTimeInterval: 0.8)
            }
        } else {
            rec.note("[j1-shop] no shop row appeared in the map list")
        }
        if picker.exists { picker.buttons["List"].tap() }

        // 6. Get it all.
        let getItAll = app.buttons["Get it all"]
        _ = getItAll.waitForExistence(timeout: 5)
        rec.shot(app, "j1", "11b-before-get-it-all")
        XCTAssertTrue(getItAll.exists, "Get it all exists: \(app.debugDescription.prefix(1500))")
        if !getItAll.isHittable { rec.note("[j1-plan] Get it all is not tappable here (covered?) frame=\(getItAll.frame)"); app.swipeDown() }
        XCTAssertTrue(getItAll.isHittable, "Get it all is not covered")
        getItAll.tap()
        XCTAssertTrue(app.navigationBars["Get it all"].waitForExistence(timeout: 10))
        rec.look(app, "j1", "12-get-it-all-top", audit: true)
        for _ in 0..<8 { app.swipeUp() }
        rec.look(app, "j1", "13-get-it-all-bottom")
        let place = app.buttons["Place test orders"]
        XCTAssertTrue(place.isHittable)
        place.tap()

        // 7. Track, cancel, Plan B.
        XCTAssertTrue(app.navigationBars["Track"].waitForExistence(timeout: 10))
        rec.look(app, "j1", "14-track-top", audit: true)
        let cancel = app.buttons["Simulate cancel"].firstMatch
        let footer = app.buttons["What next? Doses and refills"]
        for _ in 0..<40 {
            if cancel.exists && cancel.isHittable && cancel.frame.maxY < footer.frame.minY { break }
            app.nudge(up: true)
        }
        rec.look(app, "j1", "15-track-cancel-button")
        XCTAssertTrue(cancel.isHittable, "Simulate cancel can be reached")
        app.press(cancel)
        let approve = app.buttons["Approve"]
        XCTAssertTrue(approve.waitForExistence(timeout: 10), "Plan B sheet")
        rec.look(app, "j1", "16-plan-b", audit: true)
        approve.tap()
        XCTAssertTrue(approve.waitForNonExistence(timeout: 8), "the Plan B sheet closes after Approve")
        let rerouted = app.staticTexts["Re-routed (Plan B)"]
        for _ in 0..<12 where !rerouted.exists { app.nudge(up: false) }   // at big text the row may be above the fold
        if !rerouted.exists { rec.note("[j1-track] after Approve, 'Re-routed (Plan B)' was not found on Track") }
        rec.look(app, "j1", "17-track-after-planb")

        // 8. Care.
        let care = app.buttons["What next? Doses and refills"]
        XCTAssertTrue(care.isHittable)
        care.tap()
        XCTAssertTrue(app.navigationBars["Care"].waitForExistence(timeout: 10))
        rec.look(app, "j1", "18-care", audit: true)

        // 9. History, Settings, Delete everything.
        backToHome(app)
        XCTAssertTrue(app.buttons["Scan or share parchi"].waitForExistence(timeout: 5), "back at Home")
        dismissPreview(app)
        rec.look(app, "j1", "19-home", audit: true)
        let recent = app.buttons["Recent parchis"]
        for _ in 0..<5 where !(recent.exists && recent.isHittable) { app.swipeUp() }   // at big text Home scrolls
        XCTAssertTrue(recent.isHittable, "Recent parchis can be reached on Home")
        recent.tap()
        XCTAssertTrue(app.navigationBars["Recent parchis"].waitForExistence(timeout: 5))
        rec.look(app, "j1", "20-history", audit: true)
        app.navigationBars.buttons.firstMatch.tap()
        dismissPreview(app)
        for _ in 0..<5 where !app.buttons["Settings"].isHittable { app.swipeDown() }
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        rec.look(app, "j1", "21-settings-top", audit: true)
        let delete = app.buttons.matching(NSPredicate(format: "label == 'Delete everything'")).firstMatch
        for _ in 0..<12 where !(delete.exists && delete.isHittable) { app.swipeUp() }
        rec.look(app, "j1", "22-settings-delete")
        XCTAssertTrue(delete.isHittable, "Delete everything can be reached")
        app.press(delete)
        sleep(1)
        rec.look(app, "j1", "23-delete-confirm")
        let confirm = app.buttons.matching(NSPredicate(format: "label == 'Delete everything'")).allElementsBoundByIndex.first { $0.isHittable && $0.frame.minY > 0 }
        (confirm ?? app.buttons["Delete everything"]).tap()
        _ = app.labelled("Everything on this phone is deleted.").waitForExistence(timeout: 20)
        sleep(1)
        rec.look(app, "j1", "24-delete-done")
        backToHome(app)
        XCTAssertTrue(app.buttons["Scan or share parchi"].waitForExistence(timeout: 5), "back at Home after Delete everything")
        rec.look(app, "j1", "25-home-after-delete")
    }
}
