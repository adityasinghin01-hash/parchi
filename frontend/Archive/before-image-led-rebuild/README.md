# Parchi frontend — native SwiftUI

All new frontend implementation is Swift/SwiftUI. This standalone iPhone app rewrites the approved browser mockup: English/Hindi selection, profile details (optional last name), aligned +91 phone, location sheet, account credentials, welcome-back login, brief confirmation popup, and dashboard. Uses the transparent supplied logo and approved cream/orange/yellow theme. iOS provides the real status bar and home indicator; there are no simulated browser phone controls in the app.

## Build from the command line on the Mac

Requirements: Xcode 26 (the team's lab uses 26.2), XcodeGen, iOS 17+. No third-party Swift packages or backend needed for this frontend demo.

```sh
cd parchi-frontend
xcodegen generate
xcodebuild -project ParchiFrontend.xcodeproj -scheme ParchiFrontend \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

Run in Simulator:

```sh
open -a Simulator
# If necessary, boot your chosen simulator in the Simulator app first.
xcrun simctl bootstatus booted -b
xcrun simctl install booted .build/DerivedData/Build/Products/Debug-iphonesimulator/ParchiFrontend.app
xcrun simctl launch booted in.tessanova.parchi.frontend
```

If that Simulator name is unavailable, choose an installed iPhone from `xcrun simctl list devices available` and use its name/ID in the destination. You can also open `ParchiFrontend.xcodeproj`, select scheme ParchiFrontend and Run. Generate the project after adding files; do not hand-edit it.

UI tests (Mac):

```sh
xcodebuild -project ParchiFrontend.xcodeproj -scheme ParchiFrontend \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO test
```

On a real iPhone, set your Personal Team and unique bundle identifier through `project.yml`, regenerate, and follow the upstream `docs/team/REAL-IPHONE-RUN.md` checklist. Never commit signing credentials.

## Current boundaries

- UI-only account flow: registration and login validate input and demonstrate navigation; neither authenticates a person nor creates an account. No profile/credential persistence or account network calls. Keep fictional details in demos.
- Popup closes after 2.2 seconds, or immediately via its button. VoiceOver users dismiss it themselves so the announcement is not cut off. Reduce Motion avoids the transition animation.
- Native CoreLocation asks permission only on the explicit current-location tap. Manual area/city/PIN entry and Muradnagar/Meerut shortcuts work without location permission. Coordinates remain coordinates; no fabricated reverse-geocoded place names. Connect the upstream location adapter at integration.
- Dashboard scan/share opens an honest integration notice; OCR/capture/history/business services are not recreated. No mock medical records or fake orders are generated here.
- The approved cream appearance is pinned for this first port; a distinct dark palette has not been approved/implemented. Layout uses semantic text, scrollable content, accessible controls, SF Symbols and English/Hindi strings. Device accessibility checks remain required.
- No Swift or Xcode executable exists in the current Windows environment. Native compile, tests, Simulator screenshots and device checks have **not** run here. This source must pass the above build on the Mac before being called a working iOS build.

## Upstream integration

This is a standalone frontend target, not a fork of the backend or core. The existing upstream `AppModel`, clients, ParchiCore and business rules remain untouched. At integration, copy the screen/design files and logo asset into the native app, omit this standalone `@main`, and wire the agreed account completion/capture/history routes with the lead. Real auth must replace the demo transition before production use; do not treat local form validation as authentication.

Use `SWIFT_HANDOFF.md`, `agent.md` and `design.md` for product context. Existing `index.html`, `styles.css`, `app.js` remain historical design references; the localhost browser preview is not running SwiftUI. No further web UI work is planned.
