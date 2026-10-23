import UIKit
import XCTest
@testable import Parchi

/// K13: what the app SAYS about privacy must match what the code DOES. Pure rule tests plus model/erase tests that need no network.

// MARK: Stubs

final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (code, body) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}

final class FakeBoard: PasteboardLike {
    var changeCount = 0
    var string: String? { didSet { changeCount += 1 } }
}

@MainActor
private func makeDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
    let defaults = UserDefaults(suiteName: "k13-\(name)")!
    defaults.removePersistentDomain(forName: "k13-\(name)")
    return defaults
}

@MainActor
final class PrivacyK13Tests: XCTestCase {
    // MARK: 2. Fail closed on zero redaction (pure rule)

    func testNothingHiddenNeedsTheUserCheckBox() {
        let none = PIIBlur.Decision(rule: "fallback", hiddenCount: 0, unchecked: [])
        XCTAssertTrue(none.needsUserCheck)
        XCTAssertFalse(none.canUse(userChecked: false), "zero areas hidden and no tick: Use this photo must stay impossible")
        XCTAssertTrue(none.canUse(userChecked: true))
        let some = PIIBlur.Decision(rule: "label", hiddenCount: 3, unchecked: [])
        XCTAssertFalse(some.needsUserCheck)
        XCTAssertTrue(some.canUse(userChecked: false))
    }

    func testNoTextIsNeverUsable() {
        for rule in ["no_text", "no_image"] {
            let decision = PIIBlur.Decision(rule: rule, hiddenCount: 0, unchecked: [])
            XCTAssertFalse(decision.canUse(userChecked: true), rule)
            XCTAssertFalse(decision.hasReadableText)
        }
    }

    func testUncheckedHindiIsReportedToTheUser() {
        XCTAssertEqual(PIIBlur.Decision(rule: "label", hiddenCount: 1, unchecked: ["hi-IN"]).languageWarning,
                       "Hindi text could not be checked on this phone.")
        XCTAssertNil(PIIBlur.Decision(rule: "label", hiddenCount: 1, unchecked: []).languageWarning)
    }

    func testPatientLineWithNagarOrRoadIsNotExemptAsLetterhead() {
        func isLetterhead(_ s: String) -> Bool { PIIBlur.has(PIIBlur.letterhead, s) != nil }
        XCTAssertFalse(isLetterhead("Ravi Nagar"))
        XCTAssertFalse(isLetterhead("Station Road Meerut"))
        XCTAssertFalse(isLetterhead("Ravi Dr Kumar"), "Dr in the middle of a line is not a doctor header")
        XCTAssertTrue(isLetterhead("Dr. A. Sharma MBBS"))
        XCTAssertTrue(isLetterhead("City Clinic Timing 5-8"))
    }

    // MARK: 2/3. CaptureModel with a real (rendered) image

    private func textImage(_ text: String, size: CGSize = CGSize(width: 1400, height: 500)) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            (text as NSString).draw(at: CGPoint(x: 60, y: 160), withAttributes: [.font: UIFont.systemFont(ofSize: 110), .foregroundColor: UIColor.black])
        }
    }

    func testPreviewWithNothingHiddenCannotBeUsedUntilTicked() async throws {
        let model = CaptureModel()
        await model.load(textImage("Tab Dolo 650"))
        try XCTSkipUnless(model.phase == .preview, "Vision did not read the rendered text on this machine")
        XCTAssertEqual(model.hiddenCount, 0)
        XCTAssertFalse(model.canUse)
        model.userChecked = true
        XCTAssertTrue(model.canUse)
    }

    func testDiscardCancelsTheBlurAndALateResultCannotRefillThePreview() async throws {
        let model = CaptureModel()
        model.begin(image: textImage("Tab Dolo 650", size: CGSize(width: 3000, height: 1200)))
        model.discard()
        try await Task.sleep(for: .seconds(3))
        XCTAssertEqual(model.phase, .idle)
        XCTAssertNil(model.blurred)
        XCTAssertFalse(model.canUse)
    }

    func testUploadCopyIsAtMost2000PxAndUnder2MB() throws {
        let big = textImage("Tab Dolo 650", size: CGSize(width: 4000, height: 3000))
        let data = try XCTUnwrap(CaptureModel.uploadJPEG(big))
        let decoded = try XCTUnwrap(UIImage(data: data))
        let longest = max(decoded.size.width * decoded.scale, decoded.size.height * decoded.scale)
        XCTAssertLessThanOrEqual(longest, 2000)
        XCTAssertGreaterThan(longest, 1990)
        XCTAssertLessThan(data.count, 2_000_000)
        let small = try XCTUnwrap(CaptureModel.uploadJPEG(textImage("x", size: CGSize(width: 800, height: 600))))
        XCTAssertEqual(UIImage(data: small)?.size.width, 800, "small photos are not enlarged")
    }

    func testHonestNoteIsTheAgreedSentence() {
        XCTAssertEqual(CapturePreviewView.honestNote,
                       "We try to hide the name, age, phone and address we can find. Check the picture before you continue; if anything personal is still visible, close it and crop it first.")
        XCTAssertFalse(CapturePreviewView.honestNote.contains("%"))
    }

    // MARK: 4. Delete everything is complete

    func testErasingClearsAppModelLabAndShopAsk() async throws {
        let model = AppModel()
        model.readDemoParchi()
        model.choose(strength: "40", for: "telma")
        model.confirmList()
        model.placeTestOrders()
        model.skipSeller("apollo")
        XCTAssertFalse(model.lines.isEmpty)
        XCTAssertNotNil(model.approvedPlan)

        model.prepareLabBooking()
        model.labBooking.address.text = "12 Test Street, Meerut"
        model.labBooking.book()
        model.prepareShopAsk()
        model.shopAsk.phones = ["doctorshop": "9876543210"]
        model.shopAsk.send()
        XCTAssertFalse(model.labBooking.bookings.isEmpty, "precondition: a lab booking exists")
        XCTAssertFalse(model.shopAsk.rows.isEmpty, "precondition: a shop ask exists")

        NotificationCenter.default.post(name: .parchiErased, object: nil)

        XCTAssertTrue(model.lines.isEmpty)
        XCTAssertNil(model.plan)
        XCTAssertNil(model.approvedPlan)
        XCTAssertTrue(model.statuses.isEmpty)
        XCTAssertNil(model.planB)
        XCTAssertNil(model.liveOrderID)
        XCTAssertTrue(model.skippedSellers.isEmpty)
        XCTAssertTrue(model.labBooking.bookings.isEmpty)
        XCTAssertEqual(model.labBooking.address.text, "")
        XCTAssertTrue(model.shopAsk.rows.isEmpty)
        XCTAssertTrue(model.shopAsk.shopReplyOffers.isEmpty)
        XCTAssertTrue(model.shopAsk.phones.isEmpty)
        XCTAssertNil(model.shopAsk.winnerShopID)
    }

    func testErasingDropsTheCapturePreviewToo() async throws {
        let session = CaptureSession.shared
        session.capture.begin(image: textImage("Tab Dolo 650"))
        session.showPreview = true
        NotificationCenter.default.post(name: .parchiErased, object: nil)
        XCTAssertFalse(session.showPreview)
        XCTAssertEqual(session.capture.phase, .idle)
        XCTAssertNil(session.capture.blurred)
    }

    func testClipboardIsClearedOnlyIfParchiStillOwnsIt() {
        let board = FakeBoard()
        let tracker = ClipboardTracker(board: board)
        tracker.copy("Dolo 650 x15")
        XCTAssertEqual(board.string, "Dolo 650 x15")
        XCTAssertTrue(tracker.clearIfOurs())
        XCTAssertEqual(board.string, "")

        tracker.copy("Dolo 650 x15")
        board.string = "something the user copied later"
        XCTAssertFalse(tracker.clearIfOurs())
        XCTAssertEqual(board.string, "something the user copied later")
        XCTAssertFalse(tracker.clearIfOurs(), "nothing remembered any more")
    }

    // MARK: 5. Honest results

    private func resetClient(live: Bool, usedLive: Bool, reply: @escaping (URLRequest) throws -> (Int, Data)) -> ResetClient {
        let defaults = makeDefaults()
        if usedLive { BackendUsage.markUsedLive(defaults) }
        let backend = BackendSettings(store: defaults, arguments: [])
        backend.baseURL = "http://stub.test:8000"; backend.installKey = "key"; backend.mode = live ? .live : .mock
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = reply
        return ResetClient(settings: backend, session: URLSession(configuration: config), defaults: defaults)
    }

    func testOnlyA2xxJsonOkTrueIsDeleted() async {
        func outcome(_ code: Int, _ body: String) async -> ResetClient.Outcome {
            await resetClient(live: true, usedLive: true) { _ in (code, Data(body.utf8)) }.reset()
        }
        let good = await outcome(200, #"{"ok": true, "deleted": 2}"#)
        XCTAssertEqual(good, .deleted(2))
        let notOk = await outcome(200, #"{"ok": false}"#)
        XCTAssertEqual(notOk, .notConfirmed)
        let malformed = await outcome(200, "<html>proxy</html>")
        XCTAssertEqual(malformed, .notConfirmed)
        let empty = await outcome(204, "")
        XCTAssertEqual(empty, .notConfirmed)
        let missing = await outcome(200, #"{"deleted": 1}"#)
        XCTAssertEqual(missing, .notConfirmed)
        let serverError = await outcome(500, #"{"ok": true}"#)
        XCTAssertEqual(serverError, .notConfirmed)
        XCTAssertTrue(ResetClient.Outcome.notConfirmed.message.hasPrefix("Server copy NOT confirmed deleted"))
        XCTAssertTrue(ResetClient.Outcome.notReached.message.hasPrefix("Server copy NOT confirmed deleted"))
        let down = await resetClient(live: true, usedLive: true) { _ in throw URLError(.notConnectedToInternet) }.reset()
        XCTAssertEqual(down, .notReached)
    }

    func testMockDeleteAfterLiveUseSaysAServerCopyMayExist() async {
        let afterLive = await resetClient(live: false, usedLive: true) { _ in XCTFail("no network call in Mock"); return (200, Data()) }.reset()
        XCTAssertEqual(afterLive, .mayExist)
        XCTAssertEqual(afterLive.message, "A server copy may exist: switch to Live and delete again.")
        let never = await resetClient(live: false, usedLive: false) { _ in (200, Data()) }.reset()
        XCTAssertEqual(never, .noServerCopy)
    }

    func testEraseReportsLocalFailuresAndKeepsTheUsedLiveFlag() async throws {
        let defaults = makeDefaults()
        BackendUsage.markUsedLive(defaults)
        defaults.set("a house", forKey: "parchi.address")
        defaults.set(["x": "1"], forKey: "parchi.shopask.phones")
        defaults.set("http://keep.me", forKey: "parchi.backend.url")
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("k13-erase-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        var files = TempFileStore(directory: dir, sweptFolders: [dir], indexURL: FileManager.default.temporaryDirectory.appendingPathComponent("k13-index-\(UUID().uuidString).json"))
        _ = files.write(Data("jpg".utf8), name: "crop-1.jpg")
        _ = files.write(Data("jpg".utf8), name: "crop-2.jpg")
        files.removeItem = { url in if url.lastPathComponent == "crop-2.jpg" { throw CocoaError(.fileWriteNoPermission) }; try FileManager.default.removeItem(at: url) }
        let history = try HistoryStore(inMemory: true)
        history.fillDemo()
        var sellerSessionsCleared = false, artifactsCleared = false
        let reset = resetClient(live: false, usedLive: true) { _ in (200, Data()) }

        let report = await EraseEverything.run(history: history, tempFiles: files, reset: reset, defaults: defaults,
                                               clearSellerSessions: { sellerSessionsCleared = true }, clearArtifacts: { artifactsCleared = true })

        XCTAssertEqual(report.localFailures, ["photo copy crop-2.jpg"], "a file that cannot be deleted is reported, not swallowed")
        XCTAssertFalse(report.localOK)
        XCTAssertTrue(history.all().isEmpty)
        XCTAssertNil(defaults.object(forKey: "parchi.address"))
        XCTAssertNil(defaults.object(forKey: "parchi.shopask.phones"))
        XCTAssertTrue(BackendUsage.hasUsedLive(defaults), "Delete everything keeps parchi.backend.usedLive")
        XCTAssertEqual(defaults.string(forKey: "parchi.backend.url"), "http://keep.me")
        XCTAssertTrue(sellerSessionsCleared && artifactsCleared)
        XCTAssertEqual(report.server, .mayExist)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("crop-1.jpg").path))
    }

    func testEraseWithNoFailuresIsLocallyOK() async throws {
        let defaults = makeDefaults()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("k13-erase2-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let files = TempFileStore(directory: dir, sweptFolders: [dir], indexURL: FileManager.default.temporaryDirectory.appendingPathComponent("k13-index-\(UUID().uuidString).json"))
        _ = files.write(Data("jpg".utf8), name: "crop.jpg")
        let history = try HistoryStore(inMemory: true)
        history.fillDemo()
        let report = await EraseEverything.run(history: history, tempFiles: files, reset: resetClient(live: false, usedLive: false) { _ in (200, Data()) },
                                               defaults: defaults, clearSellerSessions: {}, clearArtifacts: {})
        XCTAssertTrue(report.localOK)
        XCTAssertEqual(report.server, .noServerCopy)
        XCTAssertTrue(EraseEverything.calendarNote.hasPrefix("Events Parchi added to your Calendar stay there"))
    }

    // MARK: 6. 24 h retention

    func testPurgeUsesTheIndexAndSweepsEveryFolder() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("k13-purge-\(UUID().uuidString)")
        let a = root.appendingPathComponent("a"), b = root.appendingPathComponent("b")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = TempFileStore(directory: a, sweptFolders: [a, b], indexURL: root.appendingPathComponent("index.json"))
        let now = Date()
        store.write(Data("1".utf8), name: "old.jpg", now: now.addingTimeInterval(-25 * 3600))
        store.write(Data("2".utf8), name: "fresh.jpg", now: now.addingTimeInterval(-3600))
        try FileManager.default.createDirectory(at: b, withIntermediateDirectories: true)
        let other = b.appendingPathComponent("framework-leftover.jpg")
        try Data("3".utf8).write(to: other)
        try FileManager.default.setAttributes([.creationDate: now.addingTimeInterval(-30 * 3600)], ofItemAtPath: other.path)

        XCTAssertEqual(store.purgeExpired(now: now), 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: a.appendingPathComponent("old.jpg").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: other.path), "files in every swept folder go")
        XCTAssertTrue(FileManager.default.fileExists(atPath: a.appendingPathComponent("fresh.jpg").path))
        XCTAssertEqual(store.loadIndex().count, 1, "the index keeps only files that still exist")
    }

    func testRolledBackClockOnlyDelaysRemovalByTheRollback() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("k13-clock-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = TempFileStore(directory: root.appendingPathComponent("a"), sweptFolders: [root.appendingPathComponent("a")], indexURL: root.appendingPathComponent("index.json"))
        let real = Date()
        let url = try XCTUnwrap(store.write(Data("x".utf8), name: "crop.jpg", now: real))
        // The clock is set back 3 days: the file now looks like it comes from the future.
        let rolledBack = real.addingTimeInterval(-3 * 86_400)
        XCTAssertEqual(store.purgeExpired(now: rolledBack), 0)
        XCTAssertEqual(store.loadIndex()[url.path]?.timeIntervalSince1970 ?? 0, rolledBack.timeIntervalSince1970, accuracy: 1, "age restarts at the rolled-back time")
        // 24 h later on the (wrong) clock it is removed: retention grew by the rollback at most, not without limit.
        // (+2 s: the index keeps dates to the second, so the stored start can be up to a second later than `rolledBack`.)
        XCTAssertEqual(store.purgeExpired(now: rolledBack.addingTimeInterval(24 * 3600 + 2)), 1)
    }
}
