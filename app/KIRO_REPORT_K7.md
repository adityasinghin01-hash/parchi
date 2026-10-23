# K7 report: Phase 4 (History, Care, Settings, consent, location, How we rank)
**Tests (iMac, `swift test`):** `✔ Test run with 59 tests in 0 suites passed after 0.009 seconds.`
**BUILD (iMac, xcodegen + xcodebuild, iPhone 17 Pro sim, `~/parchi-dd-k7`):** `** BUILD SUCCEEDED **` (no warnings from Phase4 files). Sim `k7-sim` deleted afterwards.

## Files (new only)
- engine/ParchiCore/Sources/ParchiCore: Doses.swift, Purge.swift, Cities.swift
- engine/ParchiCore/Tests/ParchiCoreTests: DosesTests.swift, PurgeTests.swift, CitiesTests.swift
- app/Parchi/Support/Phase4/: HistoryStore, HistoryView, CareView, SettingsView (+AccuracyView), FirstRunConsentView, ConsentStore, TempFileStore, LocationProvider (+CityPickerView), HowWeRankView, ResetClient, EraseEverything, Phase4Routes (.swift)
- app/PHASE4_INTEGRATION.md, app/KIRO_REPORT_K7.md
- Edited: app/Parchi/ParchiApp.swift, one `.overlay` line for `-demoRoute` (no other existing file touched; nothing committed).
Lines: Doses 105, Purge 11, Cities 66; Care 162, Consent 47, Erase 25, FirstRun 76, HistoryStore 186, HistoryView 101, Rank 57, Location 137, Routes 28, Reset 57, Settings 185, Temp 55.

## Screenshots (app/verify/)
k7-history.png, k7-care.png, k7-settings.png, k7-consent.png, k7-rank.png, k7-city.png (history/care use seeded sample data).

## Unverified / notes
- Not mounted yet (Claude's job). Reopen-offline (T7) is by design (data is JSON in SwiftData) but Wi-Fi-off was not tested.
- Delete everything, ResetClient against the real server, and Location permission prompt not exercised in the Simulator. `POST /reset` shape read from server/api.py only.
- Hindi consent text is my translation; needs a native-speaker check.
- Consent sentences about blur and 24 h purge depend on Capture, which is not in the app yet (see integration doc).
- Care needs a schedule string per item; `RxItem` has none, so the mount must pass one.
- Server does not purge on its own after 24 h; no such claim is made. Unreachable server shows "Server copy not reached, try again on Wi-Fi." with a retry button.
- Accuracy screen shows no trained-model number (none in CONTEXT.md table).
