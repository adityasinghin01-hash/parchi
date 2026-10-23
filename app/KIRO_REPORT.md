# KIRO report: task A (Mock/Live backend switch)
Build: `xcodebuild … iPhone 17 Pro` on the iMac -> **BUILD SUCCEEDED** (after xcodegen; one fix: ServerStatus can't be Equatable because PlanBProposal isn't).

## Files (lines)
- NEW `Parchi/Support/Backend.swift` (53): BackendMode, BackendSettings (UserDefaults; launch args `-backendMode/-backendURL/-installKey` override for that run only, never saved)
- NEW `Parchi/Support/LiveClient.swift` (188): health, placeOrder, status, postProposal, approve, reject; 5 s timeout; typed LiveError with plain messages; lenient ServerStatus decoding
- NEW `Parchi/Support/BackendSwitchView.swift` (71): collapsed "Developer" disclosure, Mock|Live, URL, key, Test connection (/health), backendError. `-backendPanelOpen YES` opens it (screenshots)
- EDIT `Parchi/Model/AppModel.swift` (+156, additive): live order, 2 s polling, status mapping, Plan B proposal post, approve/reject, backendError
- EDIT `Parchi/ParchiApp.swift` (+1): `.onChange(of: path)` starts/stops polling when Track is on/off screen
- EDIT `Parchi/Screens/HomeView.swift` (+1): `.safeAreaInset(edge: .bottom) { BackendDeveloperPanel() }`
- EDIT `project.yml` (+6): ATS NSAllowsLocalNetworking via generated `app/Info.plist`; NSLocalNetworkUsageDescription

## Screenshots (`app/verify/`)
mock-track.png, mock-planB.png (look as before), switch-home.png (panel open, Live selected), live-fallback-track.png (Live + dummy key, server down: Track still shows demo, no crash)

## Live mode today
Place order -> POST /order with a UUID Idempotency-Key kept per approved plan -> poll /status every 2 s while Track is visible -> server seller status mapped to OrderStatus -> on `needs_proposal` the phone runs the existing `PlanB.reroute`, POSTs it with the server's planVersion, and shows it in the existing sheet -> Approve also POSTs /approve. If the server is unreachable, backendError is set and the Mock state stays on screen.

## NOT verified (server not up)
- `curl localhost:8000/health` on the iMac failed (connection refused), `server/api.py` did not exist yet, no `sim_install.key`. So **no live-track.png** and no end-to-end Live run. I did not fake it.
- Request/response shapes were checked only against `server/BRIEF.md` and `server/contract.py` (validate_order/validate_proposal), not against api.py. Please diff once api.py exists.

## Assumptions / gaps
- All scenario sellers are sent in `sellers` so Plan B replacements pass the server's seller check. autoApproveCapPaise is nil.
- `rejectPlanB()` exists but the sheet's "Choose myself" is not wired to it (that would need a Screens edit).
- "Simulate cancel" stays local; in Live mode a local cancel is not sent to the server (use the judge page), and approve is only POSTed for a proposal the server holds.
- Install key is in UserDefaults as the brief asks (Keychain would be better for real use).
- No test target exists in the project, so no unit tests added.
