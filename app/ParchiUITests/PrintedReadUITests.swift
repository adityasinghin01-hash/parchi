import XCTest

/// A PRINTED parchi photo is read on the phone when no server reader is connected (Mock mode here): Confirm shows the medicines
/// that are in the photo, not the built-in demo parchi. Handwriting is not claimed. The fixture is synthetic (K16).
final class PrintedReadUITests: XCTestCase {
    private let sample = "/tmp/parchi_samples/printed_scan.jpg"

    override func setUpWithError() throws { continueAfterFailure = false }

    func testPrintedPhotoIsReadOnThePhoneAndConfirmShowsItsMedicines() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sample), "printed fixture not on this machine")
        let app = XCUIApplication()
        app.launchArguments = ["-backendMode", "mock", "-parchi.consentAt", "2026-10-24T00:00:00Z", "-parchi.consentVersion", "2", "-captureImagePath", sample]
        app.launch()
        XCTAssertTrue(app.images["Your parchi, with the details we could find covered"].waitForExistence(timeout: 30))
        let tick = app.switches.matching(NSPredicate(format: "label CONTAINS 'I checked'")).firstMatch
        if tick.waitForExistence(timeout: 3) { tick.tap() }
        let use = app.buttons["Use this photo"]
        XCTAssertTrue(use.waitForExistence(timeout: 5))
        use.tap()
        let read = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'trinox' OR label CONTAINS[c] 'evaquin' OR label CONTAINS[c] 'gelamp'")).firstMatch
        XCTAssertTrue(read.waitForExistence(timeout: 40), "Confirm should list the medicines read from the printed photo")
        let demo = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Dolo'")).firstMatch
        XCTAssertFalse(demo.exists, "the demo parchi must not be shown when the photo could be read")
    }
}
