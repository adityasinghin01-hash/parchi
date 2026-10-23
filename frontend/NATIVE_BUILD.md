# Parchi — reference-led SwiftUI screens

The active app has been restarted from the user's supplied welcome-screen image (WhatsApp Image, 23 October 2026 at 22:35:39). Future screens will follow the user's next images. The earlier registration/dashboard flow and HTML prototype are archived and excluded from the active app target.

## Active screen

`ParchiFrontend/Welcome/ReferenceWelcomeView.swift` recreates the supplied composition: pale cream background, orange corner waves, transparent Parchi logo, Georgia serif wordmark/headline, exact English text, four permission rows, privacy panel, orange agree button and guest action. Native iOS draws the real status bar, Dynamic Island and home indicator; they are not duplicated in the view.

Permission rows open native SwiftUI sheets. Location, camera, Photos and notification access are requested only when the user taps the relevant sheet action. Usage data is optional, off by default and stores only a local preference; there is no analytics collection. Continue saves a preference timestamp and emits a navigation callback; the current app acknowledges that choice without adding an unrequested next screen. Guest access does not require permission grants.

The privacy-blur copy matches the supplied image. **This screen is a design implementation, not a completed blur or prescription-processing system.** It has no capture/upload path. Do not ship this consent copy into a connected production flow until on-device blur is implemented and verified by the responsible integration team. Permission approval is not proof of that protection.

## Mac command-line build

Requirements: Xcode 26, XcodeGen, an iPhone Simulator. iOS 17+; Swift language mode 5. No third-party packages.

```sh
cd parchi-frontend
xcodegen generate
xcodebuild -project ParchiFrontend.xcodeproj -scheme ParchiFrontend \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

Run:

```sh
open -a Simulator
xcrun simctl bootstatus booted -b
xcrun simctl install booted .build/DerivedData/Build/Products/Debug-iphonesimulator/ParchiFrontend.app
xcrun simctl launch booted in.tessanova.parchi.frontend
```

Use an installed simulator name from `xcrun simctl list devices available` if necessary. Or open the generated project and Run the ParchiFrontend scheme. For a real iPhone, configure Personal Team signing via `project.yml` and regenerate. Never hand-edit the generated project.

Run UI checks on the Mac with the same xcodebuild command replacing `build` with `test`. Native compilation, screenshots and these tests have not run on the current Windows host because Swift/Xcode are unavailable. SwiftUI `#Preview` declarations cover the regular and accessibility-size screen. The visual match needs final Simulator comparison at the reference proportions; no pixel-perfect result is claimed before that check.

## Preserved material

`Archive/before-image-led-rebuild/` preserves the earlier native screens, tests and browser mockup. `assets/` retains original and transparent logo assets. Only `ParchiFrontend/` and `ParchiFrontendUITests/` are included in the active XcodeGen targets. The source reference image is in `DesignReferences/` and is not used as a full-screen raster substitute.
