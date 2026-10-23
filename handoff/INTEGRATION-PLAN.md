# Parchi integration plan: reader + scanner, then HTML → SwiftUI frontend (24 Oct 2026)
Owner: Aditya Singh (lead, reviewer). Planner/integrator: Claude. Builders: Kiro (frontend), Codex (frontend, no iMac access), Claude (reader/scan engine, then frontend verification).
Baseline: GitHub main `0d5c1d9` (verified demo checkpoint, see DEMO-RESULT.md). Frontend source: branch `origin/codex/frontend-screens` commit `9f5a70b` (`frontend/web/` HTML/CSS/JS, 21 reference JPEGs in `frontend/assets/references/`, docs in `frontend/docs/`).
NOTHING IS PUSHED. All work is on local branches/worktrees until Aditya says "push".

## 0. Clock and rules of the window
| Window | Length | Content |
|---|---|---|
| BUILD | 2 h from "go" (T0) | reader/scan fixes + frontend conversion, in parallel |
| VERIFY | ≤ 2 h, starts as pieces land (pipelined), hard stop T0+4 h | major demo checks only (section 6) |
| HANDS-ON | after VERIFY | real iPhone + real parchis, Aditya + Claude |
Cut-back rule at T0+2 h: any screen not green is reverted to the existing SwiftUI view. Nothing half-done ships.
Bug policy: EVERY bug found goes into `handoff/BUGLOG.md` (append only). Only P0 is fixed inside the window. P1–P3 are fixed after hands-on, then all measurements are re-run once.
P0 = crash, dead end in the demo path, wrong price/total, a false claim on screen, data loss/leak, spend-guard failure, sample data shown as a real scan.

## 1. What exists (verified 24 Oct)
- Reader chain works: phone → server `/read` → `reader_claude.py` → Anthropic. Key valid, model `claude-opus-5-5`, ledger cap $4.50, API restarted pointing at the reader. iMac internet = Wi-Fi only (Ethernet is behind a Sophos TLS-inspection firewall; do NOT trust its CA).
- Real smoke test (5 synthetic parchis, not a statistical result): 5/5 HTTP 200, 12,656 in / 1,253 out tokens, $0.0757 total (about Rs 7), avg $0.0151 and 5.8 s per scan, medicine recall 15/19 = 79%, precision 15/16 = 94%. It left out unreadable lines (honest) but misread one brand ("Ceobsave F" for "Clobsave F").
- Frontend: 17 web screens (welcome, signin, verify, home, area, capture, reading, review, medicines/labs compare, plans, get-all, checkout, tracking, care, history, account, ranking, pass). Palette cream `#f6e5c7` / orange `#cc2e11` / yellow `#f19116` (tokens in `frontend/web/styles/tokens.css`). Web data is FIXTURES (HSR Layout, Aarav Mehta, sample prices): never copied into the app.

## 2. Ownership
| Who | Does | Does NOT |
|---|---|---|
| Claude | model contract (AppModel/engine/server), reader+scan fixes G1–G10, consent wording draft, stub E2E tests, regression gate, merge + verify all frontend branches, polish | build screens first; push |
| Kiro (new account, 0/2000 credits at T0) | K-FE-1…K-FE-4: SwiftUI conversion, build + test on the iMac | edit AppModel / engine / server / reader |
| Codex (read-write sandbox, cannot reach the iMac, <= 2 jobs at once) | C-FE-1/2: pure SwiftUI view files for the profile group, written in a worktree on the MacBook | compile (no Xcode on the MacBook); anything outside its folders |
| Aditya | reviews, answers decisions, reads Console usage number, hands-on testing | |

## 3. Model contract (Claude adds in the first 20 min; frontend codes against these names)
- `AppModel.readSource: ReadSource` = `.reader | .onPhone | .sample | .manual`; `AppModel.readNote: String?` (banner text; Confirm MUST show a "Sample parchi, not your photo" banner when `.sample`).
- `AppModel.setQuantity(_ lineID: String, _ qty: Int)`, `AppModel.quantityAssumed: Set<String>` (lines whose quantity was not read; show "assumed 1, check").
- `AppModel.editLine(_ id: String, name: String, strength: String?)`.
- `enum ReaderFailure { notConfigured, capReached, readerError, offline, timeout, empty }` with `.message` and `.canRetry`, surfaced through `CaptureModel.phase = .failed(ReaderFailure)`. Distinct text for each; never "can't reach the server" for a reader error.
- Anything else a view needs: write `// NEEDS-MODEL: <what>` in the view, use a local stub, and tell Claude; target turnaround 15 min.
Frontend agents may only edit: `app/Parchi/Screens/*View.swift`, `app/Parchi/Support/**/**View.swift` and `*Sheet.swift`, new files in `app/Parchi/Design/`. Preserve every accessibility identifier and label the UI tests use (`Approve`, `Choose myself`, `Re-routed (Plan B)`, `noPersonalDetailsToggle`, `needsHelpCard`, `addMedicine`, `addTest`, …). Grep `app/ParchiUITests` before renaming anything.

## 4. Screen map and tiers
| Web screen | SwiftUI target | Tier | Builder |
|---|---|---|---|
| tokens + shared components | `Design/Theme.swift`, `Design/Components.swift` (colours, fonts with Dynamic Type, ParchiButtonStyle, card, chip, SampleBadge, tab bar, header) | 1 | K-FE-1 (lands first, ~15 min) |
| home | HomeView (big button = capture; sample moved to "Try the sample parchi") | 1 | K-FE-2 |
| capture, reading | CaptureEntry, CapturePreviewView (phases blurring/preview/reading/failed) | 1 | K-FE-2 |
| review | ConfirmView (quantities visible + editable, banner, uncertain lines) | 1 | K-FE-2 |
| medicines/labs compare, plans | PlanView, PlanMapView, ShopSheet | 1 | K-FE-3 |
| get-all, checkout | GetItAllView, CheckoutAssistantView | 1 | K-FE-3 |
| tracking (+ Plan B) | TrackView + Plan B sheet | 1 | K-FE-4 |
| history, care | HistoryView, CareView | 2 | C-FE-1 |
| ranking | HowWeRankView | 2 | C-FE-1 |
| account | SettingsView (account part) | 2 | C-FE-1 |
| pass (QR) | NEW `ParchiPassView` (CoreImage QR, no packages) | 2 | C-FE-2 |
| area | CityPickerView / location | 2 | C-FE-2 |
| welcome, signin, verify | FirstRunConsentView + NEW demo sign-in shell, guest first | 3 | C-FE-2 |
Jobs run in separate git worktrees on branches off `integration/24-oct`: `fe-kiro-1..4`, `fe-codex-1..2`. Kiro builds with own `-derivedDataPath`, own simulator device, `xcodegen generate`; simulator TEST runs are serialized with a lock (`mkdir ~/.sim.lock` / `rmdir`). Max 4 concurrent xcodebuilds (iMac 16 GB).

## 5. Honest-copy decisions (defaults apply unless Aditya overrides)
1. Ranking screen says "We may earn a small referral fee from some partners": Parchi has no seller agreement and takes no money. Default text: "No seller pays Parchi to change the order of results."
2. Pass says "Show this pass at partner pharmacies and labs": we have no partners yet. Default: "Show this list at the shop or lab." QR holds ONLY the confirmed list (no patient name unless the person types one; the web sample name is dropped). "Save to phone" = share sheet / save image.
3. Sign-in/OTP/Account: demo shell, labelled "Demo sign-in. No SMS is sent." Guest path first. Not connected to the backend (identity stays the install key). Tier 3, may be cut.
4. Reader model `claude-opus-5-5` (measured). Sonnet 5.5 / Haiku 5.5 comparison is a measurement AFTER hands-on, with a separate OK.
5. Consent / preview / Hindi wording must say the picture goes to Anthropic through our server; `ConsentStore.currentVersion` → 2; Claude drafts, Aditya approves before hands-on. Docs sweep: CLAUDE.md/AGENTS.md/CONTEXT.md ("no paid API"), READER-CONTRACT.md (60 s), DEMO-RUNBOOK, deck.
6. Sample data is always labelled sample, never shown as a successful scan. Prices keep source + date. Mock basket total stays Rs 2,696.77.

## 6. Verification (major demo items only; each result tagged STUB / MOCK / SIM / REAL)
| # | Check | How |
|---|---|---|
| D1 | Real reader through the app (Live mode, simulator, synthetic photo): consent → blur → preview → read → Confirm | 1–2 real calls |
| D2 | Failure paths: no key, cap reached, 500, 429, spend-limit 400, timeout, empty, non-prescription: right message, retry works, sample never shown as real | stub upstream, $0 |
| D3 | Confirm: edit quantity/strength, remove, add by hand, uncertain line, H1/X "buy in person" | UI test |
| D4 | Plan: demo total Rs 2,696.77 unchanged; non-demo medicine at catalogue MRP; Jan Aushadhi "ask your doctor" line | unit + UI |
| D5 | Ask nearby shops + lab booking hand-offs | live shop/lab 11/11 |
| D6 | Track → judge Cancel → Plan B → Approve, 3 loops | live 72 checks |
| D7 | Regression on the final tree: server 452, engine 152, app unit 118/1 skip, UI 25/1 skip, cancellation 5/5, browser 85/85 | iMac snapshot gate |
| D8 | Frontend look: every converted screen at 390×844 light + large text; 2 Hindi screens; VoiceOver labels; Reduce Motion | screenshots |
| D9 | Spend guard: ledger vs Anthropic Console (Aditya reads the Console number), cap refuses at the limit | stub + Console |
| D10 | NOT in window (needs a real iPhone): scanner, Open-in, call/maps/calendar, Wi-Fi reach over http | hands-on |
Evidence goes to `handoff/INTEGRATION-RESULT.md`.

## 7. Reader/scan work list (Claude)
G1 Home big button → capture. G2 sample never shown as a real scan; `readSource` + banner. G3/G4 distinct failure messages (Anthropic 400 spend limit, 429 enforced limit, 401 key, 5xx, timeout). G5 Retry / Cancel / "type it in" on failed or empty. G6 consent wording + version 2 + docs sweep. G7 quantity shown + editable, "assumed 1". G8 measure only (no confidence field; unknown-brand check is the net). G9 reserve table recalibrated from measured tokens (Opus holdback 0.06 → 0.07, max_tokens 4000 → 2000) and ₹ rate shown as ~97 not 88. G10 per-install `/read` limit (proposed: 6 per minute). Then stub E2E, regression, merge frontend.

## 8. Risks
- 17 screens in 2 h is tight: Tier 1 must be green, Tier 2 likely, Tier 3 may be cut.
- Codex output is uncompiled until Kiro/Claude build it on the iMac.
- The venue network may block Anthropic (as the iMac's Ethernet does): phone hotspot is the fallback; the on-phone reader still works for printed parchis.
- Plan B on real sellers is still simulated (sandbox sellers). Stated plainly in the demo.
