# Parchi iOS app
Open `app/Parchi.xcodeproj` in Xcode 26 → scheme **Parchi** → iPhone 17 Pro simulator → Run.
If you add files or change `project.yml`, run `xcodegen generate` in `app/` (`brew install xcodegen`).

- Engine: `engine/ParchiCore` (local Swift package: planner, Plan B, brand–strength check, doctor memory).
- Demo data: `engine/scenarios/real_basket_cheapest.json` (real prices, 23 Oct 2026) + `engine/catalogue/brand_strengths.json` (1.32 lakh brands → real strengths).
- Reading is mocked (`AppModel.readDemoParchi`, with one deliberate misread "Telma 400") until the iMac `/read` server exists.
- Jump straight to a step for testing/rehearsal: launch argument `-demoRoute confirm|plan|getItAll|track|planB`
  (Xcode: Scheme → Edit Scheme → Arguments; or `xcrun simctl launch booted in.tessanova.parchi -demoRoute planB`).

Screens: `Parchi/Screens/` (Home, Confirm, Plan, Get it all, Track + Plan B sheet). Antara/Aditya restyle and extend these per `docs/team/Frontend-Antara-Aditya.md`.
