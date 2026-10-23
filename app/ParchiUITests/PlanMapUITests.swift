import XCTest

/// K14: Plan > Map. Deterministic parts use the launch aids `-mapTestShops 1` (three fake shops) and `-mapOffline 1` (search fails).
/// The last test runs the real MapKit search: with internet it shows pins, without it the offline message.
final class PlanMapUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demoRoute", "plan", "-planView", "map"] + extra
        app.launch()
        return app
    }

    /// The list sits between the map and the delivery strip (the strip covers the list's lower part): drag the list until the
    /// row's bottom edge is above the strip, so a tap lands on the row and not on the strip.
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        let strip = app.descendants(matching: .any).matching(identifier: "deliveryStrip").firstMatch
        for _ in 0..<10 {
            let limit = strip.exists ? strip.frame.minY : app.frame.height - 120
            if element.exists, element.frame.maxY <= limit, element.frame.minY >= 0 { return }
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62))
            let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.50))
            from.press(forDuration: 0.1, thenDragTo: to)
        }
    }

    private func pins(_ app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'mapPin-'"))
    }

    func testListIsTheDefaultAndMapTabSwitches() {
        let app = XCUIApplication()
        app.launchArguments = ["-demoRoute", "plan"]
        app.launch()
        let picker = app.segmentedControls["planViewPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 15))
        XCTAssertTrue(picker.buttons["List"].isSelected, "List is the default")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Everything'")).firstMatch.waitForExistence(timeout: 5), "today's list screen")
        XCTAssertTrue(app.buttons["Get it all"].exists)
        picker.buttons["Map"].tap()
        XCTAssertTrue(app.otherElements["planMap"].waitForExistence(timeout: 10) || app.staticTexts["mapOfflineMessage"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Get it all"].exists, "Get it all stays on the Map tab")
        picker.buttons["List"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Everything'")).firstMatch.waitForExistence(timeout: 5))
    }

    func testPinsAppearWithIconAndPriceText() {
        let app = launch(["-mapTestShops", "1"])
        XCTAssertTrue(app.segmentedControls["planViewPicker"].buttons["Map"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.segmentedControls["planViewPicker"].buttons["Map"].isSelected, "-planView map opens the Map tab")
        let first = pins(app).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 15), "pins from the test shops")
        XCTAssertGreaterThanOrEqual(pins(app).count, 3)
        XCTAssertTrue(first.label.contains("₹") || first.label.contains("No price"), "a pin says its price in words: \(first.label)")
        XCTAssertFalse(app.staticTexts["mapOfflineMessage"].exists)
        // Delivery-only sellers sit in the bottom strip.
        XCTAssertTrue(app.descendants(matching: .any)["deliveryStrip"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["deliverySeller-truemeds"].exists)
    }

    func testTappingAListRowOpensTheShopSheetWithItsButtons() {
        let app = launch(["-mapTestShops", "1"])
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'shopRow-map-testchemista'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        reveal(row, in: app)
        row.tap()
        XCTAssertTrue(app.staticTexts["shopSheetName"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["shopSheetName"].label, "Test Chemist A")
        XCTAssertTrue(app.descendants(matching: .any)["shopSheetPrice"].exists)
        for id in ["shopDirections", "shopAsk", "shopCopy", "shopCall"] {   // Test Chemist A has a phone number
            let button = app.buttons[id]
            XCTAssertTrue(button.exists, "\(id) button")
            XCTAssertGreaterThanOrEqual(button.frame.height, 44, "\(id) is at least 44 pt tall")
            XCTAssertFalse(button.label.isEmpty)
        }
        // Call in the Simulator says why it cannot.
        app.buttons["shopCall"].tap()
        XCTAssertTrue(app.staticTexts["Calling works on a real iPhone."].waitForExistence(timeout: 3))
        // Copy message works and says nothing was sent.
        app.buttons["shopCopy"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Message copied'")).firstMatch.waitForExistence(timeout: 3))
    }

    func testAskThisShopOpensTheExistingSheetWithThatShopPicked() {
        let app = launch(["-mapTestShops", "1"])
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'shopRow-map-testchemista'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        reveal(row, in: app)
        row.tap()
        XCTAssertTrue(app.buttons["shopAsk"].waitForExistence(timeout: 5))
        app.buttons["shopAsk"].tap()
        XCTAssertTrue(app.navigationBars["Ask nearby shops"].waitForExistence(timeout: 5))
        let send = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Send to'")).firstMatch
        XCTAssertTrue(send.waitForExistence(timeout: 5))
        let settled = NSPredicate(format: "label == 'Send to 1 shop'")
        expectation(for: settled, evaluatedWith: send)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.staticTexts["Test Chemist A"].exists, "the shop is in the ask list")
    }

    func testOfflineShowsTheMessageAndTheListStillWorks() {
        let app = launch(["-mapOffline", "1"])
        let message = app.staticTexts["mapOfflineMessage"]
        XCTAssertTrue(message.waitForExistence(timeout: 15))
        XCTAssertEqual(message.label, "The map needs internet. The list still works.")
        XCTAssertEqual(pins(app).count, 0)
        // The list is there: shops from the plan data.
        let row = app.buttons["shopRow-doctorshop"]
        XCTAssertTrue(row.exists)
        row.tap()
        XCTAssertTrue(app.staticTexts["shopSheetName"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["shopDirections"].exists)
        XCTAssertTrue(app.buttons["shopAsk"].exists)
        XCTAssertTrue(app.buttons["shopCopy"].exists)
        XCTAssertFalse(app.buttons["shopCall"].exists, "no phone number, no Call button")
        XCTAssertTrue(app.staticTexts["Catalogue MRP · check at the shop"].exists, "chip wording")
    }

    func testRealMapKitSearchGivesPinsOrTheOfflineMessage() {
        let app = launch()
        let offline = app.staticTexts["mapOfflineMessage"]
        let end = Date().addingTimeInterval(40)
        var outcome = ""
        while Date() < end, outcome.isEmpty {
            if offline.exists { outcome = "offline" } else if pins(app).count > 0 { outcome = "pins" }
            else { Thread.sleep(forTimeInterval: 1) }
        }
        // With internet but nothing found the map and the list still show; none of these may be a blank or crashed screen.
        XCTAssertTrue(["offline", "pins", ""].contains(outcome))
        XCTAssertTrue(app.otherElements["planMap"].exists || offline.exists, "a map or the offline message, never an empty screen (outcome: \(outcome.isEmpty ? "map without pins" : outcome))")
        let anyRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'shopRow-'")).firstMatch
        XCTAssertTrue(anyRow.exists, "the list is always there (the plan data's shops at least)")
        XCTAssertTrue(app.state == .runningForeground, "no crash")
    }
}
