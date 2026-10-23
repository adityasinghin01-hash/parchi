# HTML/CSS handoff for the Parchi screens (Antara, Aditya, Singhal): how to deliver so the lead converts it to SwiftUI in about 1 hour
Deadline: 3 am, 24 Oct. The lead turns each HTML screen into SwiftUI and wires it to the real data. Every rule below exists to make that mapping mechanical.

## Where and how to deliver
- Branch `frontend/<yourname>`, folder `design/html/`, then open a PR (the lead merges). Do not touch `app/`, `server/`, `engine/`.
- ONE shared `design/html/tokens.css` (Antara owns it) with CSS variables only: colours (light and dark, via `@media (prefers-color-scheme: dark)`), spacing (4, 8, 12, 16, 24, 32), corner radius, type scale (largeTitle 34, title 28, headline 17 bold, body 17, footnote 13). Primary teal/green, amber = attention, red = failed. Colour is never the only signal.
- ONE HTML file per screen, named exactly as below, viewport 390 x 844, system font stack (`-apple-system`), no frameworks, no build step, no JavaScript except tiny toggles (segment control, sheet open). Icons: write the SF Symbols name in `data-sf="shield.lefthalf.filled"` and draw it with any SVG; the lead uses the name.
- Keep every text string EXACTLY as in the app (copy from the .swift file named below) unless you are improving the wording on purpose; then add the old text in a comment. Hindi goes in `data-hi="..."` next to the English; leave `data-hi` empty if unsure. The language the app ships in is decided later.
- Show the states in the same file as separate blocks with a heading comment: `default`, `loading`, `empty`, `error`, and (where it exists) `large text` (Dynamic Type) and `dark`.
- Tap targets at least 44 x 44 px, one big action per screen, lists sorted cheapest first. Put a screenshot of each screen (light + dark) next to the HTML as `<name>.png`.
- Numbers on screen must be the real ones. Mock demo basket total is Rs 2,696.77; do not invent prices; use the placeholder `{{price}}` where data comes from the app.

## Screens (HTML file name = SwiftUI file; `-demoRoute` shows the current plain version)
| HTML file | Today's SwiftUI file | demoRoute | Owner (suggested) |
|---|---|---|---|
| `home.html` | Screens/HomeView.swift | (launch) | Antara |
| `capture-preview.html` | Support/Capture/CaptureView.swift | (Home > Photos) | Aditya |
| `consent.html` | Support/Phase4/FirstRunConsentView.swift | consent | Aditya |
| `confirm.html` | Screens/ConfirmView.swift | confirm | Antara |
| `plan-list.html` | Screens/PlanView.swift | plan | Antara |
| `plan-map.html` + `shop-sheet.html` | Screens/PlanMapView.swift, shop sheet (new) | plan, `-planView map` | Antara |
| `ask-shops.html` | Support/ShopLab/ShopAskSheet.swift | askShops | Aditya |
| `get-it-all.html` + `checkout-assistant.html` | Screens/GetItAllView.swift, Support/CheckoutAssistant/CheckoutAssistantView.swift | getItAll, checkout | Antara |
| `track.html` + `plan-b-sheet.html` | Screens/TrackView.swift (Plan B sheet inside) | track, planB | Antara |
| `lab-booking.html` | Support/ShopLab/LabBookingView.swift | lab | Aditya |
| `care.html`, `history.html` | Support/Phase4/CareView.swift, HistoryView.swift | care, history | Aditya |
| `settings.html`, `how-we-rank.html`, `city.html` | Support/Phase4/SettingsView.swift, HowWeRankView.swift, CityPickerView | settings, rank, city | Aditya |
| `how-accurate.html` (new) | not built | - | Singhal: the honest reader numbers screen, from his measured results only |

## What the lead does with it (so you know what NOT to spend time on)
Maps your tokens to a SwiftUI `Theme`, rebuilds each screen from your HTML structure with the real data and buttons already wired, keeps all accessibility labels, then runs the UI tests. Animations (price re-sort, Plan B slide-up, success haptic) are described in a comment in the HTML, not built in CSS.
