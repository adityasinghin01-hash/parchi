import SwiftUI
import UIKit
import VisionKit

/// SwiftUI wrapper for Apple's document camera. Multi-page scans: only page 1 is used for now.
/// The page image stays in memory and goes straight to `onImage` (which must run it through the blur); nothing is written here.
struct DocumentScannerView: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    var onClose: () -> Void

    /// The Simulator reports `isSupported == true` on recent iOS but has no camera, so treat it as unsupported there.
    static var isSupported: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        VNDocumentCameraViewController.isSupported
        #endif
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView
        init(_ parent: DocumentScannerView) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount > 0 else { parent.onClose(); return }
            parent.onImage(scan.imageOfPage(at: 0))
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { parent.onClose() }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { parent.onClose() }
    }
}
