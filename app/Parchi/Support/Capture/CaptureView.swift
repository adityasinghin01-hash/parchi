import Observation
import PhotosUI
import SwiftUI
import UIKit
import VisionKit

/// Photos import -> best-effort hiding of name/phone/address on this phone -> preview the user must check -> (Live) reader.
/// The photo is processed on the phone first; in Live mode the processed photo (not the original) is what is uploaded.
@MainActor @Observable
final class CaptureModel {
    enum Phase: Equatable { case idle, blurring, preview, reading, failed(String) }

    /// Longest side and JPEG quality of the copy that is kept and uploaded (the server accepts up to 2 MB on /read).
    static let uploadMaxSide: CGFloat = 2000
    static let uploadQuality: CGFloat = 0.7

    var phase: Phase = .idle
    /// Why the last read failed; set together with `phase = .failed(...)`. nil for a photo problem (could not open, no text) or no failure.
    private(set) var failure: ReaderFailure?
    private(set) var blurred: UIImage?
    private(set) var rule = ""
    private(set) var hiddenCount = 0
    private(set) var notice: String?
    private(set) var decision: PIIBlur.Decision?
    /// The "I checked: no name, phone or address is visible" box. Only needed when nothing was hidden.
    var userChecked = false

    /// True only when "Use this photo" may run: something was hidden, or the user ticked the box (Live upload is impossible otherwise).
    var canUse: Bool { phase == .preview && blurred != nil && (decision?.canUse(userChecked: userChecked) ?? false) }

    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var work: Task<Void, Never>?
    @ObservationIgnored private var useTask: Task<Void, Never>?

    // MARK: Starting (tracked, so discard() can cancel)

    func begin(photo item: PhotosPickerItem) {
        let gen = restart()
        work = Task { [weak self] in await self?.load(item, gen: gen) }
    }

    func begin(image: UIImage) {
        let gen = restart()
        work = Task { [weak self] in await self?.load(image, gen: gen) }
    }

    /// Cancels anything running for an earlier photo and starts a new generation; late completions of the old one are ignored.
    private func restart() -> Int {
        work?.cancel(); useTask?.cancel(); useTask = nil
        generation += 1
        blurred = nil; decision = nil; userChecked = false; notice = nil; failure = nil
        phase = .blurring
        return generation
    }

    func load(_ picked: PhotosPickerItem) async { phase = .blurring; await load(picked, gen: generation) }
    func load(_ image: UIImage) async { phase = .blurring; await load(image, gen: generation) }

    private func load(_ picked: PhotosPickerItem, gen: Int) async {
        guard gen == generation, !Task.isCancelled else { return }   // discarded before it even started
        let image = await Self.decode(picked)
        guard gen == generation, !Task.isCancelled else { return }
        guard let image else {
            failPhoto(ReaderCopy.photoNotOpened)
            return
        }
        await load(image, gen: gen)
    }

    /// The encoded bytes are dropped as soon as the picture is decoded.
    private static func decode(_ picked: PhotosPickerItem) async -> UIImage? {
        guard let data = try? await picked.loadTransferable(type: Data.self) else { return nil }
        return UIImage(data: data)
    }

    private func load(_ image: UIImage, gen: Int) async {
        guard gen == generation, !Task.isCancelled else { return }
        let result = await PIIBlur.blurred(image)   // the original is held only for this call
        guard gen == generation, !Task.isCancelled else { return }   // closed or replaced meanwhile: do not refill the preview
        guard result.usable else {
            blurred = nil; decision = nil
            failPhoto(ReaderCopy.noTextOnPhoto)
            return
        }
        blurred = result.image; rule = result.rule; hiddenCount = result.boxCount; decision = result.decision
        userChecked = false
        phase = .preview
    }

    /// Cancels the blur and any reader request, drops the picture, and makes every late completion a no-op.
    func discard() {
        work?.cancel(); work = nil
        useTask?.cancel(); useTask = nil
        generation += 1
        blurred = nil; decision = nil; userChecked = false
        phase = .idle; notice = nil; hiddenCount = 0; failure = nil
    }

    // MARK: Using the photo

    /// The copy that is kept and uploaded: at most 2,000 px on the long side, JPEG quality 0.7 (so it stays under the server's 2 MB limit).
    static func uploadJPEG(_ image: UIImage, maxSide: CGFloat = uploadMaxSide, quality: CGFloat = uploadQuality) -> Data? {
        let width = image.size.width * image.scale, height = image.size.height * image.scale
        let longest = max(width, height)
        guard longest > 0 else { return nil }
        var out = image
        if longest > maxSide {
            let k = maxSide / longest
            let size = CGSize(width: max(1, (width * k).rounded()), height: max(1, (height * k).rounded()))
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1; format.opaque = true
            out = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        }
        return out.jpegData(compressionQuality: quality)
    }

    /// Button action: runs `use` as a tracked task so closing the sheet cancels it.
    func beginUse(model: AppModel, onUse: @escaping () -> Void) {
        guard canUse, useTask == nil else { return }
        let gen = generation
        useTask = Task { [weak self] in
            guard let self else { return }
            let ok = await self.use(model: model, gen: gen)
            let current = gen == self.generation && !Task.isCancelled
            if current { self.useTask = nil }
            if ok, current { onUse() }
        }
    }

    func use(model: AppModel) async -> Bool { await use(model: model, gen: generation) }

    /// Reads a PRINTED parchi on this phone (Apple Vision + the printed-line parser; nothing leaves the phone). Returns true when it
    /// read at least one medicine or test (or lines it was unsure about) and loaded them for Confirm with source `.onPhone`; false when
    /// it read nothing. It NEVER loads the sample parchi: the caller shows a failure with an explicit choice instead (G2).
    /// Lines it was not sure about go to `AppModel.readerNeedsHelp` (a card on Confirm), never guessed.
    private func readOnPhone(_ image: UIImage, model: AppModel, gen: Int, why: ReaderFailure? = nil) async -> Bool {
        phase = .reading
        let result = await OnPhoneReader().read(image)
        guard gen == generation, !Task.isCancelled, !result.lines.isEmpty || !result.needsHelp.isEmpty else { return false }
        model.loadReaderLines(result.lines, source: .onPhone)
        model.readerNeedsHelp = result.needsHelp
        notice = why.map { ReaderCopy.onPhoneAfterFailure($0) + " " + result.note } ?? result.note
        phase = .idle
        failure = nil
        return true
    }

    /// Shows a reader failure: `phase = .failed(message)` (kept for older views) and `failure` (for the buttons).
    private func fail(_ reason: ReaderFailure) {
        failure = reason
        phase = .failed(reason.message)
    }

    /// A problem with the photo itself (before any reading): no `ReaderFailure`, so no reader-specific buttons.
    private func failPhoto(_ message: String) {
        failure = nil
        phase = .failed(message)
    }

    /// Keeps the processed copy on the phone (removed the next time Parchi opens after 24 h) and, in Live mode, asks the reader.
    /// Returns true when Confirm should open with lines read from THIS photo. A failed or empty read never loads the sample (G2):
    /// it ends in `.failed` with a `ReaderFailure`, and the person chooses `retry`, `continueManually` or `useSampleInstead`.
    private func use(model: AppModel, gen: Int) async -> Bool {
        guard canUse, let blurred, let jpeg = Self.uploadJPEG(blurred) else { return false }
        _ = TempFileStore().write(jpeg, name: "crop-\(UUID().uuidString).jpg")
        failure = nil
        guard model.backend.mode == .live, let live = model.backend.makeClient() else {
            if await readOnPhone(blurred, model: model, gen: gen) { return true }
            guard gen == generation, !Task.isCancelled else { return false }
            fail(.noReaderInMock)
            return false
        }
        phase = .reading
        let reason: ReaderFailure
        do {
            let lines = try await ReaderClient(live: live).read(jpeg: jpeg)
            guard gen == generation, !Task.isCancelled else { return false }   // closed while reading: do not touch the model
            guard !lines.isEmpty else { fail(.empty); return false }
            model.loadReaderLines(lines, source: .reader)
            phase = .idle
            return true
        } catch let error as ReaderFailure {
            reason = error
        } catch {
            reason = .offline
        }
        guard gen == generation, !Task.isCancelled else { return false }
        // The lab reader did not read it: a PRINTED parchi can still be read on this phone (Apple Vision), also without internet.
        if await readOnPhone(blurred, model: model, gen: gen, why: reason) { return true }
        guard gen == generation, !Task.isCancelled else { return false }
        fail(reason)
        return false
    }

    // MARK: After a failure (explicit choices only)

    /// "Try again": the same processed photo is read again. `onUse` runs when Confirm should open (same as "Use this photo").
    func retry(model: AppModel, onUse: @escaping () -> Void = {}) {
        guard case .failed = phase else { return }
        guard blurred != nil, decision != nil else { phase = .idle; failure = nil; return }   // nothing to read again
        failure = nil
        phase = .preview
        beginUse(model: model, onUse: onUse)
    }

    /// "Type the medicines in": Confirm opens with an empty list, source `.manual`. Returns true (the caller opens Confirm).
    @discardableResult
    func continueManually(model: AppModel) -> Bool {
        useTask?.cancel(); useTask = nil
        model.startManualList()
        failure = nil; notice = nil
        phase = .idle
        return true
    }

    /// "Use the sample parchi": the person chose to see the bundled sample (source `.sample`, Confirm shows the sample banner).
    /// Returns true (the caller opens Confirm).
    @discardableResult
    func useSampleInstead(model: AppModel) -> Bool {
        useTask?.cancel(); useTask = nil
        model.readDemoParchi()
        failure = nil; notice = nil
        phase = .idle
        return true
    }
}

/// The Home entry: "Choose a photo", "Scan with the camera". The preview sheet lives at the root (`CaptureSession`).
struct CaptureEntry: View {
    @Binding var path: [Route]
    @State private var session = CaptureSession.shared
    @State private var picked: PhotosPickerItem?
    @State private var showScanner = false

    var body: some View {
        VStack(spacing: 8) {
            PhotosPicker(selection: $picked, matching: .images) {
                Label("Choose a photo of the parchi", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            if DocumentScannerView.isSupported {
                Button { showScanner = true } label: {
                    Label("Scan with the camera", systemImage: "doc.viewfinder").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
            } else {
                Button {} label: {
                    Label("Scan with the camera", systemImage: "doc.viewfinder").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .disabled(true)
                Text("The scanner needs a real iPhone").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .onChange(of: picked) { _, item in
            guard let item else { return }
            session.start(photo: item)
        }
        .onChange(of: session.showPreview) { _, shown in if !shown { picked = nil } }
        .onChange(of: session.showConsent) { _, shown in if !shown { picked = nil } }   // declined: the same photo can be picked again
        .task {
            // Screenshots and tests: `-captureImagePath /path/to/parchi.jpg` skips the picker.
            if let file = UserDefaults.standard.string(forKey: "captureImagePath"), let image = UIImage(contentsOfFile: file) {
                session.start(image: image)
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScannerView(onImage: { image in
                showScanner = false
                session.start(image: image)
            }, onClose: { showScanner = false })
            .ignoresSafeArea()
        }
    }
}

struct CapturePreviewView: View {
    /// The honest promise, word for word (also used by the tests).
    static let honestNote = "We try to hide the name, age, phone and address we can find. Check the picture before you continue; if anything personal is still visible, close it and crop it first."
    static let checkedBox = "I checked: no name, phone or address is visible"

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Bindable var capture: CaptureModel
    var onUse: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    switch capture.phase {
                    case .blurring, .idle:
                        ProgressView("Looking for the name, phone and address on this phone…")
                    case .reading:
                        ProgressView("Reading your parchi…")
                    case .failed(let message):
                        ContentUnavailableView("Can't use this photo", systemImage: "exclamationmark.triangle", description: Text(message))
                        // KR (G2/G5) minimal choices after a failed read; FE2 owns the look of this view and may restyle them.
                        // Identifiers used by tests: readerRetry, readerTypeIn, readerUseSample.
                        if let failure = capture.failure {
                            if failure.canRetry {
                                Button { capture.retry(model: model, onUse: onUse) } label: {
                                    Text(ReaderCopy.retryButton).frame(maxWidth: .infinity, minHeight: 44)
                                }
                                .buttonStyle(.borderedProminent).accessibilityIdentifier("readerRetry")
                            }
                            Button { if capture.continueManually(model: model) { onUse() } } label: {
                                Text(ReaderCopy.continueManuallyButton).frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.bordered).accessibilityIdentifier("readerTypeIn")
                            if failure == .noReaderInMock {
                                Button { if capture.useSampleInstead(model: model) { onUse() } } label: {
                                    Text(ReaderCopy.useSampleButton).frame(maxWidth: .infinity, minHeight: 44)
                                }
                                .buttonStyle(.bordered).accessibilityIdentifier("readerUseSample")
                                .accessibilityHint("Shows the sample parchi. It is not your photo.")
                            }
                        }
                    case .preview:
                        if let image = capture.blurred {
                            Image(uiImage: image).resizable().scaledToFit()
                                .accessibilityLabel("Your parchi, with the details we could find covered")
                            Text(Self.honestNote).font(.callout)
                            Label(capture.hiddenCount == 0 ? "We could not find a name, phone or address to hide."
                                  : "We hid \(capture.hiddenCount) area\(capture.hiddenCount == 1 ? "" : "s") on this phone.",
                                  systemImage: "eye.slash").font(.footnote).foregroundStyle(.secondary)
                            if let warning = capture.decision?.languageWarning {
                                Label(warning, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.orange)
                            }
                            Text(model.backend.mode == .live
                                 ? ReaderCopy.liveUploadNote : ReaderCopy.mockNote)
                                .font(.footnote).foregroundStyle(.secondary)
                            if let notice = capture.notice { Text(notice).font(.footnote).foregroundStyle(.orange) }
                            if capture.decision?.needsUserCheck == true {
                                Toggle(isOn: $capture.userChecked) { Text(Self.checkedBox) }
                                    .accessibilityIdentifier("noPersonalDetailsToggle")
                            }
                            Button {
                                capture.beginUse(model: model, onUse: onUse)
                            } label: { Text("Use this photo").frame(maxWidth: .infinity, minHeight: 48) }
                                .buttonStyle(.borderedProminent)
                                .disabled(!capture.canUse)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Check your photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}
