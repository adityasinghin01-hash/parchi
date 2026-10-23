# Parchi frontend: tech stack, rules and how to hand work to Aditya Singh (23 Oct 2026)
For **Antara** and **Aditya** (screens, design, capture). The lead (Aditya Singh) integrates. Everything below is what the repo does TODAY (checked against `app/project.yml` and `app/Parchi/`).

## 1. Stack (no third-party packages, no accounts, nothing to pay for)
| Layer | Use | Notes |
|---|---|---|
| Language / UI | **Swift + SwiftUI**, iPhone only, portrait, **iOS 17.0+** | Xcode 26.2 on the lab iMac; Swift language mode 5 (`SWIFT_VERSION: "5.0"`) |
| App state | **Observation** (`@Observable`) | one `AppModel` (`app/Parchi/Model/AppModel.swift`), injected into screens |
| Engine | local **Swift package `ParchiCore`** (`engine/ParchiCore`) | planner, Plan B, brand-strength check, doses, price source + 7-day stale rule, test names, H1/X, purge, cities; pure Swift, `swift test` |
| Saved parchis (History) | **SwiftData** | `Support/Phase4/HistoryStore.swift` |
| Maps / places | **MapKit** (SwiftUI `Map`) + live `MKLocalSearch`, **CoreLocation** (when-in-use) | Apple Maps data is NOT bundled (terms); OSM extras optional; show "Map data © Apple, © OpenStreetMap contributors" |
| Calendar / reminders | **EventKit** (write-only) + **UserNotifications** (local) | lab slot + fasting reminder |
| Seller checkout | **WKWebView** (in-app browser) | the USER taps Add to cart and Pay; Parchi never clicks for them |
| Network | **URLSession async/await** | `Support/LiveClient.swift` + `ShopLab/*Client.swift`; server = Python/FastAPI + Temporal on the lab iMac |
| Project file | **XcodeGen** (`app/project.yml`) | never edit the `.xcodeproj` by hand; add files to the folders and run `xcodegen generate` |
| Tests | **Swift Testing** in ParchiCore (`swift test`, run on the iMac), **XCUITest** target `ParchiUITests` | |
| Design | **SF Symbols only**, Dynamic Type, light + dark, 8-pt grid, 16-pt card radius, English + Hindi | spec: `docs/team/Frontend-Antara-Aditya.md` section 8; resources: `docs/team/resources/Parchi-Frontend-Resources.*` |

## 2. Who owns what (so merges stay clean)
| Area | Owner | Files |
|---|---|---|
| Look, layout, animation, copy of every screen | **Antara + Aditya** | `app/Parchi/Screens/*View.swift` and the `*View.swift` / `*Sheet.swift` files under `Support/` (History, Care, Settings, HowWeRank, ShopAsk, LabBooking, CheckoutAssistant) |
| Capture (scanner, share extension, Photos), blur, location UX, Hindi strings | **Aditya** | new files under `app/Parchi/Capture/` (create it) |
| Models, clients, engine, server, data, tests | **Lead + Kiro/Codex** | `AppModel.swift`, `Support/Backend.swift`, `LiveClient.swift`, `*Model.swift`, `*Client.swift`, `Support/AppData.swift`, `engine/`, `server/` |
**Restyle freely, but do not rename or delete** what the logic needs: model property names, button labels used by tests (**"Approve"**, **"Choose myself"**, status text **"Re-routed (Plan B)"**), accessibility labels. Need a new field from the model? Ask the lead; do not edit `AppModel.swift`.

## 3. Screens and the data each one reads (all exist today, plain and functional; restyle them)
Home `HomeView` (+ History link, Settings gear, Developer panel) · Confirm `ConfirmView` · Plan `PlanView` (List | Map to build) · Get it all `GetItAllView` (+ Checkout Assistant) · Track `TrackView` (+ Plan B sheet) · Ask nearby shops `ShopAskSheet` · Lab booking `LabBookingView` · Care `CareView` · History `HistoryView` · Settings `SettingsView` · How we rank `HowWeRankView` · First-run consent `FirstRunConsentView` (NOT shipped until blur + 24 h purge exist in Capture).
To see any screen without clicking through: launch with `-demoRoute confirm|plan|getItAll|track|planB|askShops|lab|checkout|history|care|settings|consent|rank|city`.

## 4. Rules the UI must follow (legal + honesty; from `CONTEXT.md`)
- Money is **integer paise**; format with `Support/Money.swift`. Every price shows its **source and date** ("MRP", "Online, 23 Oct", "Shop replied 6:40 pm"); older than 7 days adds "may have changed" (`PriceSource`).
- Never swap brands or recommend doses/tests. Same-salt / Jan Aushadhi appears only as **"ask your doctor"**. H1/X medicines: **"Buy in person with the original parchi"**.
- Sandbox orders are labelled **"Test order"**. No sentence on screen that the code does not honour.
- Lists sort **cheapest to most expensive**; one big action per screen; large text; colour is never the only signal.

## 5. Build and run
1. Any Mac with **Xcode 26** + `brew install xcodegen` (Mock mode needs no server), or the lab iMac.
2. `cd app && xcodegen generate && open Parchi.xcodeproj` (scheme **Parchi**, iPhone 17 Pro simulator).
3. **Mock vs Live:** Home, collapsed **Developer** panel: Mock (offline demo, no network) | Live (iMac server). Launch arguments for scripted runs: `-backendMode live|mock -backendURL http://<iMac-ip>:8000 -installKey <key> -backendPanelOpen YES`. Keys come from the lead; never commit a key.
4. Lab iMac loop (lead/Kiro): `rsync -az --exclude .build ~/dev/parchi/ imac:parchi/` then `ssh imac 'cd ~/parchi/app && xcodegen generate && xcodebuild -project Parchi.xcodeproj -scheme Parchi -destination "platform=iOS Simulator,name=iPhone 17 Pro" -derivedDataPath ~/parchi-dd build'`.
5. Simulator limits: SMS composer and document scanner do not work in the Simulator (use Photos import / share sheet; test those on a real iPhone); set the simulated location to KIET: `xcrun simctl location booted set 28.7524,77.4990`.

## 6. Hand-off protocol (so the lead only integrates)
- Work on a branch `frontend/<your-name>` (e.g. `frontend/antara`), small commits, push, open a PR to `main`. **No direct pushes to `main`.**
- Before the PR: it builds (`xcodegen generate` + build), Mock demo still runs end to end, and you attach 2-4 screenshots (light + dark, one with large text).
- Touch only the files in your column of section 2. If you must edit a shared file, say which line in the PR.
- Strings: English + Hindi in one place per screen (`LocalizedStringKey` or a small `Strings` struct); the lead merges Hindi review notes from `engine/catalogue/message_templates.json`.
- Do not add packages, analytics, or network calls. Ask first.

## 7. Day-one checklist (do these in order)
1. **Accept the GitHub invite** to the private repo `adityasinghin01-hash/parchi` (check your email / github.com/notifications). Then: `git clone https://github.com/adityasinghin01-hash/parchi.git && cd parchi && git checkout -b frontend/<your-name>`.
2. Read, in this order: `CONTEXT.md` (what and why, 5 min) -> `docs/team/Frontend-Antara-Aditya.md` section 8 (the mentor's GUI direction; it wins over older sections) -> this file.
3. Build and run the Mock demo (section 5). You should see Home -> Confirm -> Plan -> Get it all -> Track + Plan B with real prices (Total Rs 2,696.77). Open the Developer panel on Home once so you know where Mock | Live is.
4. Open `app/Parchi/Screens/` and the `*View.swift` files listed in section 3: they are **plain on purpose**. Your job is to make them look like a consumer app.
Sample data for design work: `engine/scenarios/real_basket_cheapest.json` (the demo parchi, real prices) and `engine/catalogue/*.json` (labs, lab prices, product links, test names; every row has a source and date). The server API (only needed for Live mode) is in `server/CONTRACT_P3.md` and `server/V2_README.md`.

## 8. Your task list (from the mentor spec; screens that already exist are restyles, the rest are new)
| # | Task | Owner | Spec |
|---|---|---|---|
| 1 | Design system: colour tokens (teal/green primary, amber = attention, red = failed), type scale, spacing, dark mode | Antara | spec 8.7 |
| 2 | **Plan screen: List | Map.** List = whole-parchi option cards sorted cheapest first with tags (Cheapest / Fastest / Lowest, needs doctor's OK). Map = SwiftUI `Map` with **price pins** (icon + text, never colour alone), delivery-only sellers in a bottom strip, chosen plan's stops joined by a line | Antara | 8.2 |
| 3 | **Shop sheet** (bottom sheet): name, distance, open/closed if known, price per item cheapest first, source chip, buttons Call / Directions / WhatsApp / Ask this shop | Antara | 8.3 |
| 4 | Restyle Home, Confirm (highlight doubtful lines, test "which one?" rows), Get it all, Track, the Plan B sheet (slide-up + haptic on approve) | Antara + Aditya | 4, 5, S3-S6 |
| 5 | Restyle the functional screens: Ask nearby shops sheet, Lab booking (slot picker), Care, History, Settings, How we rank, Checkout Assistant | Aditya | 8.4, 8.5 |
| 6 | **Capture** (not built yet): document scanner, WhatsApp share extension, Photos import, then the on-phone name blur (`privacy/` has the tool and the measured 98.3%) and writing crops through `TempFileStore`. Only after this works do we turn on the first-run consent screen | Aditya | S0, S2 |
| 7 | Hindi/English strings, Dynamic Type, Reduce Motion, read-aloud | both | 8.1, 8.7 |
| 8 | Animations: price re-sort, Plan B sheet slide, success haptics | both | 8.7 |

## 9. Ask the lead when
You need a new value from the model (a field, a sort, a flag) · a screen needs data that is not in the API · something in a `*Model.swift` or `*Client.swift` looks wrong · a UI test fails after your change. Do not work around it inside a view.
