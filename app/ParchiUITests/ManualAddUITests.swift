import XCTest

/// K18: a person with a handwritten parchi types the medicines in on the Confirm screen and still gets the full plan.
/// Starts on the Confirm screen with a blank list (`-demoRoute confirm -demoReader ""`: the reader returned nothing).
final class ManualAddUITests: XCTestCase {
    private let shots = "/tmp/k18-shots"

    override func setUpWithError() throws {
        continueAfterFailure = false
        try? FileManager.default.createDirectory(atPath: shots, withIntermediateDirectories: true)
    }

    private func launchBlank() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-backendMode", "mock", "-demoRoute", "confirm", "-demoReader", ""]
        app.launch()
        return app
    }

    private func shot(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "\(shots)/\(name).png"))
    }

    private func label(_ app: XCUIApplication, _ text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", text)).firstMatch
    }

    /// Dolo 650 x 15 through the real sheet: search, suggestion, strength, stepper, Add.
    private func addDolo650x15(_ app: XCUIApplication) {
        let add = app.buttons["Add a medicine"]
        XCTAssertTrue(add.waitForExistence(timeout: 20), app.debugDescription)
        add.tap()
        let search = app.textFields["manualMedicineSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("dolo")
        let suggestion = app.buttons["manualSuggestion-DOLO"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 30), "suggestions for 'dolo' (the catalogue loads off the main thread)")
        shot("k18-add-medicine-suggestions")
        suggestion.tap()
        let strength = app.buttons["manualStrength-650"]
        XCTAssertTrue(strength.waitForExistence(timeout: 10))
        strength.tap()
        let stepper = app.steppers["manualQuantity"]
        XCTAssertTrue(stepper.waitForExistence(timeout: 10))
        XCTAssertEqual(stepper.label, "Tablets / units", "the stepper is labelled exactly \"Tablets / units\"")
        XCTAssertEqual(stepper.value as? String, "10", "default quantity is 10")
        for _ in 0..<5 { app.buttons["manualQuantity-Increment"].tap() }
        XCTAssertEqual(stepper.value as? String, "15")
        shot("k18-add-medicine-details")
        app.buttons["manualAdd"].tap()
    }

    func testTypeInDoloAndACBCThenGetThePlanAndRemoveALine() throws {
        let app = launchBlank()
        XCTAssertTrue(app.navigationBars["Did we read it right?"].waitForExistence(timeout: 20))
        let blank = app.buttons["Add a medicine or test first"]
        XCTAssertTrue(blank.exists)
        XCTAssertFalse(blank.isEnabled, "a blank list cannot be continued")
        XCTAssertTrue(app.buttons["Add a test"].exists)
        shot("k18-confirm-blank")

        addDolo650x15(app)
        XCTAssertTrue(app.staticTexts["Dolo 650"].waitForExistence(timeout: 10), app.debugDescription)

        app.buttons["Add a test"].tap()
        let testSearch = app.textFields["manualTestSearch"]
        XCTAssertTrue(testSearch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["manualTest-CBC"].exists, "the full list is shown before typing")
        testSearch.tap()
        testSearch.typeText("cbc")
        shot("k18-add-test")
        app.buttons["manualTest-CBC"].tap()
        XCTAssertTrue(app.staticTexts["CBC"].waitForExistence(timeout: 10))
        shot("k18-confirm-dolo-cbc")

        // The Confirm button now works; remove the CBC from its menu ("Remove CBC"), then Dolo is the whole parchi.
        app.buttons["Options for CBC"].tap()
        let removeCBC = app.buttons["Remove CBC"]
        XCTAssertTrue(removeCBC.waitForExistence(timeout: 5), "a visible Remove in the line's menu")
        shot("k18-remove-menu")
        removeCBC.tap()
        XCTAssertFalse(app.staticTexts["CBC"].waitForExistence(timeout: 2), "CBC is gone")
        XCTAssertTrue(app.staticTexts["Dolo 650"].exists, "Dolo stays, with its strength")

        let confirm = app.buttons["All correct"]
        XCTAssertTrue(confirm.isEnabled)
        confirm.tap()
        XCTAssertTrue(label(app, "Catalogue MRP · check at the shop").waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Everything ₹34.27"].exists, "Dolo 650 x 15 = one strip of 15 at Rs 34.27")
        shot("k18-plan")
    }

    func testSwipeToRemoveAndNoReaderNeededForAMedicineAndATest() throws {
        let app = launchBlank()
        addDolo650x15(app)
        XCTAssertTrue(app.staticTexts["Dolo 650"].waitForExistence(timeout: 10))
        app.buttons["Add a test"].tap()
        app.buttons["manualTest-CBC"].tap()
        XCTAssertTrue(app.staticTexts["CBC"].waitForExistence(timeout: 10))

        // swipe the Dolo row: the swipe action is labelled "Remove Dolo 650"
        app.staticTexts["Dolo 650"].swipeLeft()
        let remove = app.buttons["Remove Dolo 650"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5), app.debugDescription)
        shot("k18-swipe-remove")
        remove.tap()
        XCTAssertFalse(app.staticTexts["Dolo 650"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["CBC"].exists)
    }

    func testAlpraxTypedInSaysBuyInPersonAndAnUnknownNameIsAddableAsTyped() throws {
        let app = launchBlank()
        app.buttons["Add a medicine"].tap()
        let search = app.textFields["manualMedicineSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("alprax")
        let suggestion = app.buttons["manualSuggestion-ALPRAX"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 30))
        suggestion.tap()
        app.buttons["manualStrength-0.25"].tap()
        app.buttons["manualAdd"].tap()
        let message = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'original parchi'")).firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 10), "H1 medicine: buy in person with the original parchi")
        shot("k18-alprax-in-person")

        app.buttons["Add a medicine"].tap()
        let again = app.textFields["manualMedicineSearch"]
        XCTAssertTrue(again.waitForExistence(timeout: 10))
        again.tap()
        again.typeText("Xyzzyqq")
        let typed = app.buttons["manualAddAsTyped"]
        XCTAssertTrue(typed.waitForExistence(timeout: 10))
        typed.tap()
        app.buttons["manualAdd"].tap()
        XCTAssertTrue(app.staticTexts["Xyzzyqq"].waitForExistence(timeout: 10))
        XCTAssertTrue(label(app, "Answer the highlighted line").exists || app.buttons["Answer the highlighted line"].exists,
                      "the existing not-found rule: the patient must answer the line")
        shot("k18-unknown-as-typed")
    }
}
