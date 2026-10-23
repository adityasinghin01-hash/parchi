import Foundation

/// Every user-facing reader / scan string in one place. Views read these; tests compare against them.
/// Rules: honest and specific. Do NOT state how long Anthropic keeps a picture (unverified): say Anthropic's own terms apply.
enum ReaderCopy {
    // MARK: Preview notes (shown under the photo before "Use this photo")

    /// Live mode: the picture is uploaded through our lab server to Anthropic's Claude service.
    static let liveUploadNote = "When you continue, this picture (with the details we covered) goes through the Parchi lab server to Anthropic's Claude service to be read. Anthropic's own terms apply to that copy. A copy also stays on this phone and is removed the next time you open Parchi after 24 hours."
    /// Mock mode: nothing is uploaded.
    static let mockNote = "Demo mode: this picture stays on this phone. It is removed the next time you open Parchi after 24 hours."

    // MARK: Progress

    static let reading = "Reading your parchi…"
    static let readingOnPhone = "Reading the printed text on this phone…"

    // MARK: Sample

    /// Confirm banner when `AppModel.readSource == .sample` (also `AppModel.readNote`).
    static let sampleBanner = "Sample parchi, not your photo"
    static let useSampleButton = "Use the sample parchi"
    static let continueManuallyButton = "Type the medicines in"
    static let retryButton = "Try again"
    static let failedTitle = "Can't read this photo"

    // MARK: Photo problems (before any reading)

    static let photoNotOpened = "That photo could not be opened."
    static let noTextOnPhoto = "No text could be read on this photo, so nothing was kept. Try again in better light, flat on a table."
    static let notAPhoto = "Parchi can only open photos. Nothing was kept."

    /// Notice when the lab reader failed but the phone read the printed text itself.
    static func onPhoneAfterFailure(_ failure: ReaderFailure) -> String {
        switch failure {
        case .offline: return "The Parchi lab server could not be reached, so this phone read the printed text itself."
        default: return "The lab reader did not read this photo, so this phone read the printed text itself."
        }
    }

    // MARK: Failures

    static func failureMessage(_ failure: ReaderFailure) -> String {
        switch failure {
        case .notConfigured:
            return "The reader is not set up on the Parchi lab server yet, so this photo was not read. You can type the medicines in instead."
        case .capReached:
            return "The reader has reached its spending limit for now, so it cannot read more photos. You can type the medicines in instead."
        case .badKey:
            return "The reading service did not accept the Parchi lab server's key, so this photo was not read. Please tell the Parchi team. You can type the medicines in meanwhile."
        case .readerError:
            return "The reading service had a problem with this photo. Wait a moment and try again, or type the medicines in."
        case .offline:
            return "Can't reach the Parchi lab server. Check that you are on the same Wi-Fi as the lab iMac, then try again."
        case .timeout:
            return "Reading took too long and was stopped. Try again, or type the medicines in."
        case .empty:
            return "No medicines or tests were found on this photo. Try a sharper photo, or type them in."
        case .noReaderInMock:
            return "Demo mode has no reader, and the phone could not read this photo by itself (it reads printed parchis only). You can type the medicines in, or look at the sample parchi (it is not your photo)."
        case .slowDown:
            return "Too many photos in a short time. Wait a minute, then try again."
        }
    }
}
