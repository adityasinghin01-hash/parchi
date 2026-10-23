# KIRO_REPORT_K12: capture entry points (scanner + Open in Parchi)
**BUILD (iMac, xcodegen + xcodebuild, `~/parchi-dd-k12`, own simulator device, deleted at the end):** `** BUILD SUCCEEDED **` (also with K11's in-progress AppModel/PlanView/AppData changes in the tree).

## Files
- NEW `Support/Capture/DocumentScannerView.swift` (41): VisionKit wrapper; page 1 only for multi-page scans. `isSupported` is forced false in the Simulator (iOS 26 sim reports true but has no camera).
- NEW `Support/Capture/CaptureSession.swift` (80): shared `CaptureSession` (one capture model + one preview sheet for every source), `open(url:)`, `.captureInbox(path:)` modifier (`onOpenURL` + sheet).
- EDIT `Support/Capture/CaptureView.swift` (156): `CaptureEntry` = Photos row + "Scan with the camera" (or disabled row + "The scanner needs a real iPhone"); sheet moved to the root; `-captureImagePath` kept.
- EDIT `ParchiApp.swift`: ONE line (`.captureInbox(path: $path)` in `RootView`). `HomeView.swift` needed NO edit. `project.yml`: `NSCameraUsageDescription`, `CFBundleDocumentTypes` (public.image, Viewer, Alternate), `LSSupportsOpeningDocumentsInPlace: false`.
- NEW `ParchiUITests/CaptureUITests.swift` (33): blurred preview via `-captureImagePath`; scanner row text + disabled in Simulator.
- Launch aid: `-captureOpenURL /path.jpg` goes through the same `open(url:)` as "Open in Parchi".

## Privacy path traced (every place an image can land)
Photos / scanner / Open in / `-captureImagePath` -> in-memory `UIImage` -> `CaptureModel.load(_:)` -> `PIIBlur` -> only `blurred` is kept (memory). Disk: only on "Use this photo", `TempFileStore` `crop-*.jpg` = blurred JPEG (24 h purge). Open in: file read into memory via `Data(contentsOf:)`, original never copied; the inbox file is deleted right after loading (only if its path contains `/Inbox/` inside this app's container, so a `/tmp` or user file is never deleted). Verified on the Simulator: inbox file gone after load, `/tmp/parchi_samples` intact, 0 `crop-*` and 0 image files in the container before "Use". No logging of images. No share extension (free account, no App Groups): WhatsApp "Share > Open in Parchi" style hand-off via document types is the supported route.

## Screenshots (`app/verify/`)
`k12-home.png` (new rows), `k12-preview-278.png`, `k12-preview-244.png` (blurred preview via `-captureImagePath`), `k12-openin-handler.png` (Open-in handler, inbox copy of s10_000244, 5 areas hidden), `k12-openurl-simctl.png` (see below).

## What ran vs needs a real iPhone
- RAN: build, blur preview for both samples, Open-in handler incl. inbox deletion, Simulator disabled scanner row.
- `xcrun simctl openurl file:///tmp/...jpg` opened Apple's Preview app, not Parchi (Simulator offers no "Open in" chooser for a bare file URL), so iOS's own dispatch to Parchi is NOT proven. Needs a real iPhone: camera scan, WhatsApp/Files/Photos "Open in Parchi", the Info.plist registration showing in the share sheet (plist keys verified present in the built `Info.plist`).

## UI tests (`-only-testing:ParchiUITests`, own device, serial, live test with keys read inside ssh)
Passing run: `** TEST SUCCEEDED **`, 8 tests (Capture x2, HistoryAndCare x2, PlanBFlow, ServerDown, ShopAskLive, SimulateCancel). It took 3 attempts: `SimulateCancelUITests` is FLAKY and unrelated to this change. On an untouched `git archive HEAD` build it failed 3 of 5 runs (my build: about 4 of 7). Cause not found (when it fails, no Plan B sheet appears after the tap; `TrackView`/`AppModel` are not mine). I tried a settle-and-retry in the test, it did not help, and I reverted it: no existing test file is changed.

## Unverified
Sheet presented from the root while a child screen (Track, Plan) has its own sheet open when a file arrives; multi-page scans (page 1 only); whether VisionKit leaves temp files of its own; Hindi strings for the new rows.
