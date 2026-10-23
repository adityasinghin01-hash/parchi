# Kiro task A: add a Mock/Live backend switch to the Parchi iPhone app (SwiftUI) and prove it on the iMac simulator

You are the hands; Claude is the instructor and will re-run the build and read the screenshots himself. Run from the repo root `~/dev/parchi`. Work ONLY in `app/` (plus `app/project.yml`). Do NOT git commit. Another agent (Kiro task S) is writing the Python server in `server/` at the same time: do not edit `server/`.

## Ground rules
- Screens in `app/Parchi/Screens/` belong to the design teammates (Antara, Aditya). Do NOT restyle or move anything there. You may add at most ONE line to a screen to mount a small self-contained settings control.
- Keep the existing demo (Mock) behaviour byte-for-byte: with mode = Mock nothing changes and no network call happens.
- Money is integer paise. All sandbox orders stay labelled "Test order".

## What to build
1. `app/Parchi/Support/Backend.swift`: `enum BackendMode: String { case mock, live }`; a small `BackendSettings` (mode, baseURL default `http://localhost:8000`, installKey) persisted in UserDefaults; read launch arguments `-backendMode live|mock`, `-backendURL <url>`, `-installKey <key>` (for screenshots/tests).
2. `app/Parchi/Support/LiveClient.swift`: async URLSession client for the server API described in `server/BRIEF.md` section "API" (read that section; if `server/api.py` exists by the time you finish, compare against it and report differences). Implement: `health()`, `placeOrder(plan:sellers:autoApproveCapPaise:idempotencyKey:) -> orderID` (POST /order, headers `X-Install-Key` + `Idempotency-Key`), `status(orderID:)` (GET /status/{id}) with a Codable `ServerStatus` (orderID, state, planVersion, sellers[{id,status,etaMinutes}], pending{sellerID,failure}?, proposal?, nothingAvailable, needsCheck, waitingSince?, audit[]), `postProposal`, `approve`, `reject` (POST /order/{id}/proposal|approve|reject with `{planVersion,...}`). Timeouts 5 s. Typed errors, no force unwraps, no crashes when the server is down.
3. `AppModel` integration (keep it small and additive):
   - In Live mode `placeTestOrders()` also calls `placeOrder` (idempotency key = a UUID stored per approved plan) and then polls `status` every 2 s while Track is on screen (cancel the task on leave / when state == done).
   - Map server seller status -> existing `OrderStatus` (`placed`, `rerouted` as "Re-routed (Plan B)", failed/cancelled -> "Cancelled by seller").
   - When the server reports `state == needs_proposal` with `pending`, compute the Plan B proposal on the phone with the EXISTING `PlanB(planner:).reroute(...)` and POST it to `/order/{id}/proposal` with the server's `planVersion`; surface it through the existing `planB` property so the existing Plan B sheet shows it.
   - `approvePlanB()` in Live mode also POSTs `/approve` (current planVersion). Reject likewise if a reject action exists.
   - Expose `backendError: String?` (plain-language message, e.g. "Can't reach the server. Showing the demo.") and fall back to Mock behaviour when the server is unreachable. Never block the UI.
4. A tiny self-contained `BackendSwitchView` (Mock | Live segmented control, server URL field, install key field, a "Test connection" button that shows OK/failed using `/health`, and the `backendError`), mounted with one line behind a collapsed "Developer" disclosure on Home.
5. Info.plist via `project.yml`: `NSAppTransportSecurity` -> `NSAllowsLocalNetworking = true`; `NSLocalNetworkUsageDescription` = "Parchi talks to the lab server on your local network for order tracking."

## Build and prove it on the iMac (MacBook only edits files)
```
rsync -az --exclude .build --exclude '*.xcodeproj/xcuserdata' app/ imac:parchi/app/     # run from ~/dev/parchi
ssh imac 'zsh -lc "cd ~/parchi/app && xcodegen generate && xcodebuild -project Parchi.xcodeproj -scheme Parchi -destination \"platform=iOS Simulator,name=iPhone 17 Pro\" -derivedDataPath ~/parchi-dd build 2>&1 | tail -15"'
```
(Check how the existing project is laid out first: the earlier flow rsynced the whole repo to `imac:parchi/` and ran xcodegen/xcodebuild from `~/parchi/app`. Never rsync `server/.venv` or `server/data`.) Simulator UDID `12B6A285-914E-44DE-A52A-9577A9265B50` (iPhone 17 Pro). Install/launch with `xcrun simctl install/launch` and the existing `-demoRoute confirm|plan|getItAll|track|planB` arguments, then `xcrun simctl io <udid> screenshot <file>`; copy PNGs to `app/verify/` on the MacBook (scp).
Required evidence: BUILD SUCCEEDED; screenshots `mock-track.png` and `mock-planB.png` (must look exactly like before), `switch-home.png` (the Developer control open). If `curl http://localhost:8000/health` on the iMac returns ok (the server may or may not be up yet), also run Live: launch with `-backendMode live -backendURL http://localhost:8000 -installKey $(cat ~/parchi/server/data/sim_install.key)` and capture `live-track.png`. If the server is not up, say so; do not fake it.
Unit tests: add a few XCTest-free checks only if the project already has a test target; otherwise skip tests and say so.

## Report
Write `app/KIRO_REPORT.md` (30 lines max): files changed (with line counts), build result, list of screenshots, what Live mode does today vs what still needs the server, assumptions, anything unverified. Final chat message: 6 lines max.
