import Observation
import PhotosUI
import SwiftUI
import UIKit

/// Photos import -> blur on this phone -> preview -> (Live) reader. Nothing leaves the phone before the blur step finishes.
@MainActor @Observable
final class CaptureModel {
    enum Phase: Equatable { case idle, blurring, preview, reading, failed(String) }

    var phase: Phase = .idle
    private(set) var blurred: UIImage?
    private(set) var rule = ""
    private(set) var hiddenCount = 0
    private(set) var notice: String?

    func load(_ picked: PhotosPickerItem) async {
        phase = .blurring
        guard let data = try? await picked.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
            phase = .failed("That photo could not be opened.")
            return
        }
        await load(image)
    }

    func load(_ image: UIImage) async {
        phase = .blurring
        let result = await PIIBlur.blurred(image)
        guard result.usable else {
            blurred = nil
            phase = .failed("No text could be read on this photo, so nothing was kept. Try again in better light, flat on a table.")
            return
        }
        blurred = result.image; rule = result.rule; hiddenCount = result.boxCount
        phase = .preview
    }

    func discard() { blurred = nil; phase = .idle; notice = nil }

    /// Keeps the blurred crop on the phone for up to 24 h (TempFileStore) and, in Live mode, asks the reader.
    /// Returns true when Confirm should open (reader lines or the demo parchi are loaded).
    func use(model: AppModel) async -> Bool {
        guard let blurred, let jpeg = blurred.jpegData(compressionQuality: 0.8) else { return false }
        _ = TempFileStore().write(jpeg, name: "crop-\(UUID().uuidString).jpg")
        guard model.backend.mode == .live, let live = model.backend.makeClient() else {
            notice = "Demo: no reader in Mock mode, so the sample parchi is shown."
            model.readDemoParchi()
            return true
        }
        phase = .reading
        do {
            let lines = try await ReaderClient(live: live).read(jpeg: jpeg)
            guard !lines.isEmpty else { phase = .failed("The reader found no medicines or tests on this photo."); return false }
            model.loadReaderLines(lines)
            phase = .idle
            return true
        } catch let error as ReaderError {
            if case .notConnected = error { notice = error.message; model.readDemoParchi(); phase = .idle; return true }
            phase = .failed(error.message)
            return false
        } catch {
            phase = .failed(ReaderError.unreachable.message)
            return false
        }
    }
}

/// The Home entry: "Choose a photo" and the preview sheet. Plain on purpose; the design teammates restyle it.
struct CaptureEntry: View {
    @Environment(AppModel.self) private var model
    @Binding var path: [Route]
    @State private var capture = CaptureModel()
    @State private var picked: PhotosPickerItem?
    @State private var showPreview = false

    var body: some View {
        PhotosPicker(selection: $picked, matching: .images) {
            Label("Choose a photo of the parchi", systemImage: "photo.on.rectangle")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .padding(.horizontal)
        .onChange(of: picked) { _, item in
            guard let item else { return }
            showPreview = true
            Task { await capture.load(item) }
        }
        .task {
            // Screenshots and tests: `-captureImagePath /path/to/parchi.jpg` skips the picker.
            if let file = UserDefaults.standard.string(forKey: "captureImagePath"), let image = UIImage(contentsOfFile: file) {
                showPreview = true
                await capture.load(image)
            }
        }
        .sheet(isPresented: $showPreview, onDismiss: { capture.discard(); picked = nil }) {
            CapturePreviewView(capture: capture) {
                showPreview = false
                path.append(.confirm)
            }
            .presentationDetents([.large])
        }
    }
}

struct CapturePreviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var capture: CaptureModel
    var onUse: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                switch capture.phase {
                case .blurring, .idle:
                    ProgressView("Hiding name, phone and address on this phone…")
                case .reading:
                    ProgressView("Reading your parchi…")
                case .failed(let message):
                    ContentUnavailableView("Can't use this photo", systemImage: "exclamationmark.triangle", description: Text(message))
                case .preview:
                    if let image = capture.blurred {
                        Image(uiImage: image).resizable().scaledToFit()
                            .accessibilityLabel("Your parchi with personal details hidden")
                        Label(capture.hiddenCount == 0 ? "No personal details were found to hide."
                              : "\(capture.hiddenCount) areas hidden on this phone. Only this blurred copy is kept, for up to 24 hours.",
                              systemImage: "eye.slash").font(.footnote).foregroundStyle(.secondary)
                        if let notice = capture.notice { Text(notice).font(.footnote).foregroundStyle(.orange) }
                        Button {
                            Task { if await capture.use(model: model) { onUse() } }
                        } label: { Text("Use this photo").frame(maxWidth: .infinity, minHeight: 48) }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            .navigationTitle("Check your photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}
