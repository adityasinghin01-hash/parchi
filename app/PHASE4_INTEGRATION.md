# Phase 4 integration (K7): mount lines for Claude
All new code is in `app/Parchi/Support/Phase4/`. Each screen wraps itself with `.modelContainer(store.container)`, so no app-wide container is needed. Put them inside an existing `NavigationStack`.

## Mount lines
- Home, "Recent parchis": `NavigationLink("Recent parchis") { HistoryView(store: HistoryStore.shared) }` (or embed `HistoryView` as a section).
- Save on approve (in `AppModel.placeTestOrders`, after `approvedPlan = plan`):
  `HistoryStore.shared.saveApproved(title: scenario.title, items: lines.map { SavedItem(item: $0.item, schedule: <schedule string or nil>) }, plan: plan, sellers: scenario.sellers)`
  `RxItem` has no schedule field, so the reader must pass "1-0-1"/"BD" strings through; until then Care shows "Can't tell".
- Care entry: `CareView(store: HistoryStore.shared)` (Track screen "What next?" link or a tab).
- Settings entry (gear on Home): `SettingsView(history: HistoryStore.shared, backend: model.backend, consent: consentStore, onClearSellerSessions: { Task { await CheckoutPrivacy.clearSellerSessions() } })`
- How we rank (link from Plan): `HowWeRankView()`.
- First run, in `ParchiApp`: `@State consent = ConsentStore()`; show `FirstRunConsentView(consent: consent) { }` as `.fullScreenCover(isPresented: .constant(consent.needsConsent))` over `RootView`.
- Launch: `TempFileStore().purgeExpired()` in `ParchiApp.init` and when the scene becomes active. Write every photo crop through `TempFileStore().url(for:)`.
- Location: one `LocationProvider()` in AppModel; use `.centre` for the map and shop search; show `CityPickerView(location:)` when `needsCityPicker`.

## project.yml (Info keys, A3b owns the file)
`INFOPLIST_KEY_NSLocationWhenInUseUsageDescription: "Parchi uses your location only on this phone, to show shops and labs near you. You can pick a city instead."`
No new package: SwiftData and CoreLocation are system frameworks.

## Things to know
- Delete everything wipes the 5 shared keys plus any other `parchi.*` key (care ticks, city, `parchi.lab.address`, `parchi.shopask.phones`, `parchi.message.language`) except `parchi.backend.*` (needed to ask the server to delete). Server copy is only asked in Live mode; Mock says nothing was sent.
- Address: Settings writes `parchi.address`, but `LabReminders.AddressStore` reads `parchi.lab.address`. Point it at `parchi.address`.
- Consent text promises blur on the phone and a 24 h purge. Capture/blur and `/read` are not in the app yet: do not ship the consent screen until Capture applies `privacy/pii_blur` and writes crops via `TempFileStore`.
- Distance is not shown on PlanView today, so "How we rank" does not claim it; add a sentence when it is.
- Demo: `-demoRoute history|care|settings|consent|rank|city` is an `.overlay` in `RootView` (one line in `ParchiApp.swift`).
