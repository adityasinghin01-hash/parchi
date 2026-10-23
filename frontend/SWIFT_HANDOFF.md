> LATEST IMPLEMENTATION: Five supplied image references are now implemented as modular browser screens: phone sign-in, OTP, Home, area selection and capture/import. Welcome links into this flow. The map intentionally remains unavailable, with a documented provider boundary and backend API adapter for later integration. Default data/OTP/orders are reference demos; no SMS, map request, upload or OCR runs. Read docs/FRONTEND_INTEGRATION.md. Swift source is preserved for the later rewrite. This update supersedes earlier notes saying only the welcome screen exists.
> CURRENT PHASE: The user explicitly restored HTML/CSS/JavaScript for visual development on Windows. Build modular image-led screens and preview on localhost; perform the SwiftUI rewrite after the complete design is approved. This supersedes all earlier Swift-only directives below for the current phase. Preserve ParchiFrontend/ and ParchiFrontendUITests/ as native reference. Active browser entry is index.html plus web/. Shared values live in web/styles/tokens.css; screen-specific content/layout is separate. Only the latest image-led welcome screen is active. Await the next image before adding further screens.
> LATEST USER DIRECTION: Image-led restart. Only the current supplied welcome reference is active. Match its pale cream/orange palette, foreground logo, serif wordmark and headline, exact English copy, permission rows, privacy panel and actions. The earlier multi-screen document and registration/dashboard build are superseded for active work. They and the browser mockup are retained under Archive/before-image-led-rebuild/. Continue in native Swift/SwiftUI only, one reference image at a time; await subsequent images before inventing more screens. Active source is ParchiFrontend/Welcome/. Read README.md for scope and build verification status. This Windows environment still has no native SwiftUI build verification.
> IMPLEMENTATION UPDATE: The current screens have now been rewritten in native Swift/SwiftUI under ParchiFrontend/, with project.yml and XCUITest source. Read README.md for command-line Mac build/run instructions. Language selection, registration, login, location picker, popup and dashboard are implemented as a standalone UI demo. Authentication/capture integration remains pending. No Swift/Xcode tools were available on this Windows host, so native compilation and UI tests are NOT yet verified. The historical statements below saying migration has not started are superseded.
# Parchi — current frontend memory

Updated 23 October 2026 following the user's explicit platform change. This file supersedes prior HTML/CSS/JavaScript implementation instructions.

## Active direction

- All new frontend implementation is Swift/SwiftUI only, native iPhone, portrait, iOS 17+.
- Stop extending the browser mockup. Retain it as historical visual/interaction reference; it is not native implementation or proof of native functionality.
- Separate frontend repository: `C:/Users/Aditya/Documents/ChatGPT/parchi-frontend`. Its existing HTML/CSS/JS files must not be deleted without a reason; no migration/build is claimed by this context update.
- Latest upstream reference: https://github.com/adityasinghin01-hash/parchi, `main` commit `7ebbc495706761e528759dd282958f65dabc95f7`. Downloaded to `tmp/github-context/` for review.

## Read these first in upstream

1. `CONTEXT.md` / `AGENTS.md`.
2. `docs/team/Frontend-Antara-Aditya.md`, especially GUI-v2 section 8.
3. `docs/team/FRONTEND-TECH-STACK.md` — stack, ownership, build and handoff.
4. `docs/plan/12-V2-MASTER-PLAN.md` — current target/build order, superseding file 11's build sequence.
5. `docs/team/REAL-IPHONE-RUN.md` — signing and device checklist.
6. `app/PHASE4_INTEGRATION.md`, `app/DATA_INTEGRATION.md`, `app/README.md` — integration caveats.

## Swift stack and boundaries

- Swift/SwiftUI, Swift language mode 5 per project configuration; Xcode 26/26.2 on the Mac. iOS 17+.
- Observation `@Observable` and injected `AppModel`; shared pure-Swift `engine/ParchiCore`; integer-paise money through `Support/Money.swift`.
- SwiftData for history; MapKit/MKLocalSearch plus CoreLocation for maps/location with city fallback; EventKit plus local UserNotifications; native capture/Photos/share integration.
- URLSession async/await and existing backend/client interfaces. Current wider backend is Python/FastAPI + Temporal + SQLite on the iMac, not the old proposed Swift/Vapor system. Swift-only here refers to frontend work, not rewriting another team's backend.
- Seller checkout uses WKWebView where supported: patients themselves tap Add to cart and Pay. This is native-app embedded seller content, not a web frontend deliverable or automated purchase.
- No new packages, analytics or network calls as part of styling; use existing adapters. Screen layout/copy/animation ownership includes `Screens/*View.swift` and relevant `*View.swift`/`*Sheet.swift` under Support. Models/clients/engine/server belong to the lead. Do not alter `AppModel` or invent missing business facts to make a view work.
- Preserve test-sensitive labels `Approve`, `Choose myself`, `Re-routed (Plan B)`, model property names and accessibility identifiers/labels.

## Native build and handoff

- Generate with XcodeGen from `app/project.yml`; do not hand-edit `.xcodeproj`.
- Mac flow: `cd app`, `xcodegen generate`, open `Parchi.xcodeproj`, scheme Parchi, iPhone 17 Pro Simulator. Mock mode needs no server.
- Live configuration uses existing Developer panel and supplied backend URL/install key; never commit keys. Do not assume addresses documented on 23 October remain valid.
- Upstream handoff specifies `frontend/<your-name>` branch, small commits and PR; no direct pushes to main. Choose a concrete branch only when implementation begins.
- Before PR: actual native build, end-to-end Mock run, 2–4 screenshots including light/dark and large text. Swift Testing for core, XCUITest for UI. No such Mac checks were executed in this Windows review.
- Simulator capture/SMS limitations require Photos/share fallbacks and real-device checks. Scanner, WhatsApp/SMS, location deny/allow, Calendar and notifications must be checked on an iPhone.

## Updated product scope and important caveats

- Target is V2; V1 is a milestone. Includes whole-prescription plan, List/Map, price pins, nearby shops/pickup, Checkout Assistant, lab booking, Track/Plan B, Care, History, Settings/ranking. V3 recommendations/partner automation remain later.
- Data depth: Muradnagar/Meerut; lighter coverage for Modinagar, Ghaziabad, Hapur, Noida. No cross-city price copying; missing price remains unknown.
- Source/date on prices; older than seven days gets `may have changed` through existing `PriceSource` rules. Mock orders remain `Test order`.
- Consent must not promise implemented blur or 24-hour purge until Capture actually enforces them. Integration notes flag address-store key mismatch and unwired data hooks: confirm live code rather than trusting broad “all built” claims in summaries.
- The repo contains new implementation and test source; source existence and reported pass counts are not independently reproduced build/test results.

## User-approved design that must carry into SwiftUI

- Cream background and orange/yellow palette from supplied logo, overriding upstream provisional teal/green: cream `#f6e5c7`, paper `#f9e8ce`, orange `#cc2e11`, yellow `#f19116`, warm dark-brown readable text.
- Transparent foreground logo in `parchi-frontend/assets/parchi-logo-transparent.png`; original preserved alongside. No black corners, visible image tile, outline or border.
- English/Hindi language first; subsequent labels, errors and editable content support that language.
- Registration: required first name; optional last name; phone, location, username and password; two short steps. Welcome-back login uses username/password. This later explicit user request supersedes earlier no-login priority for the requested screens; production auth remains unimplemented.
- Remove top-right tagline everywhere, welcome subtitle, bottom assurance/plus panel and numeric `01/02` step label. Keep section label/right progress bars.
- Even +91 phone-field spacing; location picker instead of a full address textarea, current-location option and manual city/area fallback. Delivery address is a separate integration requirement in V2, not implied by city selection.
- Registration completion: short `You’re all set` popup, then dashboard automatically; no profile-preview/native-integration paragraph. Dashboard has location, greeting, scan/share and recent prescriptions/empty state. Browser scan remains a placeholder.
- Preserve Dynamic Type, VoiceOver, Reduce Motion, accessible contrast and English/Hindi in native implementation; browser checks do not establish those native qualities.

## Current action status

This turn reviews and records the updated Swift direction only. No Swift migration or native compile has been performed. Next implementation should use these docs and the existing native app interfaces, carrying forward approved visual decisions without continuing HTML/CSS/JS.
