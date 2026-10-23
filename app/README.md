# Parchi iOS app
Open `app/Parchi.xcodeproj` in Xcode 26 → scheme **Parchi** → iPhone 17 Pro simulator → Run.
If you add files or change `project.yml`, run `xcodegen generate` in `app/` (`brew install xcodegen`).

- Engine: `engine/ParchiCore` (local Swift package: planner, Plan B, brand–strength check, doctor memory).
- Demo data: `engine/scenarios/real_basket_cheapest.json` (real prices, 23 Oct 2026) + `engine/catalogue/brand_strengths.json` (1.32 lakh brands → real strengths).
- Reading is mocked (`AppModel.readDemoParchi`, with one deliberate misread "Telma 400") until the iMac `/read` server exists.
- Jump straight to a step for testing/rehearsal: launch argument `-demoRoute confirm|plan|getItAll|track|planB`
  (Xcode: Scheme → Edit Scheme → Arguments; or `xcrun simctl launch booted in.tessanova.parchi -demoRoute planB`).

Screens: `Parchi/Screens/` (Home, Confirm, Plan, Get it all, Track + Plan B sheet). Antara/Aditya restyle and extend these per `docs/team/Frontend-Antara-Aditya.md`.

## Phase 3: Ask nearby shops + lab booking (`Parchi/Support/ShopLab/`)
- Entry: "Ask shops" / "Labs" buttons on the Plan screen (`.shopLabActions()`); launch routes `-demoRoute askShops|lab` (screenshot aids: `-demoSend 1`, `-demoBook 1`, `-demoSchedule 1`).
- Mock mode needs no network: a scripted "Demo reply" / "Demo confirmation" arrives after 5 s. Live mode never falls back to the demo.
- Message wording: `engine/catalogue/message_templates.json` (30 drafts, en/hi/hinglish, not yet native-reviewed).
- Permission strings (in `project.yml`): `NSCalendarsWriteOnlyAccessUsageDescription` (EventKit write-only, adds the confirmed slot). Local notifications (fasting reminder) need no Info.plist key; iOS asks at first use (Simulator uses quiet/provisional permission).
- Planner hook: `AppModel.shopReplyOffers` + `shopReplySource` (not merged into the planner yet).
