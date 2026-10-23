import Observation
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// One shared capture + preview sheet for every way an image can arrive (Photos, camera scanner, "Open in Parchi", test launch argument).
/// Every path ends in `CaptureModel.begin(...)`, which hides what it can find on the phone BEFORE anything is stored or sent.
@MainActor @Observable
final class CaptureSession {
    static let shared = CaptureSession()
    let capture = CaptureModel()
    var showPreview = false
    /// The consent screen, shown ONCE in front of the first photo (Photos, scanner or Open in). Set by the root hook.
    /// Reads the same saved agreement as the app's own store, so a photo that arrives before the root hook runs is still checked.
    var consent = ConsentStore()
    var showConsent = false
    /// Every new photo request and every Delete everything bumps this. A delayed start (the short waits below) that finds a newer
    /// number is dropped and cleaned up, so an erased or superseded photo can never start after the fact (Codex R7 rows 1, 3, 4).
    private var generation = 0
    private var pendingAfterConsent: (gen: Int, start: () -> Void, decline: () -> Void)?

    init() {
        // "Delete everything" closes the preview and drops the picture, any running blur or reader request, the consent screen,
        // and any photo still waiting for an answer or for its delayed start.
        NotificationCenter.default.addObserver(forName: .parchiErased, object: nil, queue: nil) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.generation += 1
                let pending = self.pendingAfterConsent
                self.pendingAfterConsent = nil
                self.showConsent = false
                self.showPreview = false
                self.capture.discard()
                pending?.decline()
            }
        }
    }

    func start(photo item: PhotosPickerItem) {
        requireConsent {
            self.showPreview = true
            self.capture.begin(photo: item)
        } decline: {}
    }

    func start(image: UIImage) {
        requireConsent {
            self.showPreview = true
            self.capture.begin(image: image)
        } decline: {}
    }

    func dismissed() { capture.discard() }

    /// Runs `start` at once when the person has already agreed; otherwise shows the consent screen first and runs it only on
    /// "Agree & continue". "Not now" (or swiping the screen away) runs `decline` and nothing is read or kept.
    private func requireConsent(_ start: @escaping () -> Void, decline: @escaping () -> Void) {
        generation += 1
        let gen = generation
        // A newer photo replaces one still waiting for an answer: clean the old one up first (an Inbox copy is deleted).
        if let old = pendingAfterConsent { pendingAfterConsent = nil; old.decline() }
        guard consent.needsConsent else { start(); return }
        pendingAfterConsent = (gen, start, decline)
        // The photo picker or scanner that produced this image is still closing; a sheet presented that instant is dropped by iOS.
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            if pendingAfterConsent?.gen == gen, gen == generation { showConsent = true }
        }
    }

    var hasPendingConsent: Bool { pendingAfterConsent != nil }

    func consentAgreed() {
        showConsent = false
        guard let pending = pendingAfterConsent else { return }
        pendingAfterConsent = nil
        // Let the consent sheet finish closing first: iOS drops a sheet presented while another one is still on its way out.
        // If Delete everything, a newer photo or a withdrawn agreement arrives during the wait, this photo is dropped and cleaned up.
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard pending.gen == generation, !consent.needsConsent else { pending.decline(); return }
            pending.start()
        }
    }

    func consentDeclined() {
        showConsent = false
        let pending = pendingAfterConsent
        pendingAfterConsent = nil
        pending?.decline()
    }

    /// "Open in Parchi" / Share: the file is read into memory, the incoming copy in our Inbox is deleted, then the image goes through the hiding step.
    /// The original file is never copied anywhere. Declining the consent screen still deletes the incoming Inbox copy.
    func open(url: URL) {
        requireConsent {
            self.showPreview = true
            self.capture.phase = .blurring
            let loaded = Self.readAndRemoveInbox(url)
            guard let image = loaded else {
                self.capture.phase = .failed("Parchi can only open photos. Nothing was kept.")
                return
            }
            self.capture.begin(image: image)
        } decline: {
            _ = Self.readAndRemoveInbox(url)
        }
    }

    /// Reads an image file into memory; deletes it afterwards only if it is iOS's inbox copy inside this app's own container.
    static func readAndRemoveInbox(_ url: URL) -> UIImage? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        var image: UIImage?
        if let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image),
           let data = try? Data(contentsOf: url) {
            image = UIImage(data: data)
        }
        if url.isFileURL, url.path.contains("/Inbox/"), url.path.hasPrefix(NSHomeDirectory()) {
            try? FileManager.default.removeItem(at: url)
        }
        return image
    }
}

/// Root-level hook: handles `onOpenURL` and presents the single preview sheet, then opens Confirm.
private struct CaptureInboxModifier: ViewModifier {
    @Binding var path: [Route]
    let consent: ConsentStore
    @Bindable private var session = CaptureSession.shared

    func body(content: Content) -> some View {
        content
            .onAppear { session.consent = consent }
            .onOpenURL { session.open(url: $0) }
            .task {
                // Test aid: `-captureOpenURL /path/x.jpg` goes through the same handler as "Open in Parchi".
                if let file = UserDefaults.standard.string(forKey: "captureOpenURL") { session.open(url: URL(fileURLWithPath: file)) }
            }
            .sheet(isPresented: $session.showConsent, onDismiss: { if session.hasPendingConsent { session.consentDeclined() } }) {
                FirstRunConsentView(consent: consent, onAgree: { session.consentAgreed() }, onDecline: { session.consentDeclined() })
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $session.showPreview, onDismiss: { session.dismissed() }) {
                CapturePreviewView(capture: session.capture) {
                    session.showPreview = false
                    path = [.confirm]
                }
                .presentationDetents([.large])
            }
    }
}

extension View {
    func captureInbox(path: Binding<[Route]>, consent: ConsentStore) -> some View { modifier(CaptureInboxModifier(path: path, consent: consent)) }
}
