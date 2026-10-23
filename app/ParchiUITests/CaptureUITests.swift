import XCTest

/// K12: every image source ends in the same blurred preview. `-captureImagePath` skips the picker; the sheet must show the
/// blurred copy and the on-phone reassurance, and the scanner row must say it needs a real iPhone in the Simulator.
final class CaptureUITests: XCTestCase {
    private let sample = "/tmp/parchi_samples/s10_000278.jpg"

    override func setUpWithError() throws { continueAfterFailure = false }

    func testImagePathShowsBlurredPreview() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sample), "sample parchi not on this machine")
        let app = XCUIApplication()
        app.launchArguments = ["-backendMode", "mock", "-parchi.consentAt", "2026-10-24T00:00:00Z", "-parchi.consentVersion", "2", "-captureImagePath", sample]
        app.launch()
        XCTAssertTrue(app.navigationBars["Check your photo"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.images["Your parchi, with the details we could find covered"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Use this photo"].exists)
    }

    func testScannerRowSaysItNeedsARealPhoneInSimulator() throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("Simulator-only check")
        #endif
        let app = XCUIApplication()
        app.launchArguments = ["-backendMode", "mock"]
        app.launch()
        let note = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'The scanner needs a real iPhone'")).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 10), app.debugDescription)
        let scan = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Scan with the camera'")).firstMatch
        XCTAssertTrue(scan.exists)
        XCTAssertFalse(scan.isEnabled)
    }
}
