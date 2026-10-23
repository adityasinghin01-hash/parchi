import UIKit
import XCTest
@testable import Parchi

/// The consent screen sits in front of the FIRST photo from any source. Nothing is read, stored or sent until the person agrees.
@MainActor
final class ConsentGateTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        suiteName = "parchi.test.consent.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func session(agreed: Bool) -> CaptureSession {
        let session = CaptureSession()
        session.consent = ConsentStore(store: defaults)
        if agreed { session.consent.agree() }
        return session
    }

    private var image: UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
    }

    func testFirstPhotoWaitsForConsentAndStartsNothing() async throws {
        let s = session(agreed: false)
        s.start(image: image)
        XCTAssertFalse(s.showPreview, "no preview, no blur, no read before agreeing")
        XCTAssertTrue(s.hasPendingConsent)
        try await Task.sleep(for: .milliseconds(700))
        XCTAssertTrue(s.showConsent, "the consent screen appears")
        XCTAssertFalse(s.showPreview)
    }

    func testNotNowDropsThePhoto() async throws {
        let s = session(agreed: false)
        s.start(image: image)
        try await Task.sleep(for: .milliseconds(700))
        s.consentDeclined()
        XCTAssertFalse(s.showConsent)
        XCTAssertFalse(s.hasPendingConsent)
        try await Task.sleep(for: .milliseconds(800))
        XCTAssertFalse(s.showPreview, "declined: the photo is never opened")
        XCTAssertTrue(s.consent.needsConsent, "declining does not count as agreeing")
    }

    func testAgreeStartsThePendingPhotoOnce() async throws {
        let s = session(agreed: false)
        s.start(image: image)
        try await Task.sleep(for: .milliseconds(700))
        s.consent.agree()
        s.consentAgreed()
        XCTAssertFalse(s.showConsent)
        try await Task.sleep(for: .milliseconds(900))
        XCTAssertTrue(s.showPreview, "after Agree the preview opens")
        // a second photo does not ask again
        s.showPreview = false
        s.start(image: image)
        XCTAssertTrue(s.showPreview)
        XCTAssertFalse(s.hasPendingConsent)
    }

    func testAlreadyAgreedGoesStraightToThePreview() {
        let s = session(agreed: true)
        s.start(image: image)
        XCTAssertTrue(s.showPreview)
        XCTAssertFalse(s.showConsent)
    }

    func testDecliningAnOpenInFileStillDeletesTheIncomingCopy() async throws {
        let inbox = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents/Inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let file = inbox.appendingPathComponent("consent-gate-\(UUID().uuidString).jpg")
        try XCTUnwrap(image.jpegData(compressionQuality: 0.8)).write(to: file)
        let s = session(agreed: false)
        s.open(url: file)
        XCTAssertFalse(s.showPreview)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), "kept only until the person answers")
        try await Task.sleep(for: .milliseconds(700))
        s.consentDeclined()
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path), "declined: the incoming copy is deleted")
        XCTAssertFalse(s.showPreview)
    }
}
