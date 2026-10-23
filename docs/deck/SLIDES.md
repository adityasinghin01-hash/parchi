# Parchi final: slide outline

Evidence: recorded lab runs of 23 Oct 2026, updated with the latest fix reports and code. Final suite counts await Claude’s final run. [source: docs/verification/EVIDENCE-23-OCT-2026.md] [source: app/KIRO_REPORT_K13.md] [source: engine/KIRO_REPORT_K17.md]
Format: 12 slides for a 24-hour Swift hackathon final. [source: docs/deck/BRIEF_CODEX_C5.md:5]
Paths below are relative to the repository root. Newer fix reports and current code update stale acceptance descriptions; plans do not establish completion. Speaker notes are spoken copy; citations stay in the presentation notes or visible price footers.

## 1. The parchi leaves the patient with unfinished work

- The patient must decipher the handwriting, find the items and compare the payable price.
- In the PharmEasy review sample, **25.2% of low-rated reviews mentioned delay, non-delivery or cancellation**. [source: docs/research/evidence/review_themes.json:106]
- A price comparison stops helping when the selected seller cancels.

**Speaker note:** The review file calls this theme “Delay / not delivered / cancelled”, and the research explains that it used keyword matching on low-rated reviews. This is evidence of a complaint in that sample, not a delivery-failure rate for all customers. [source: docs/research/evidence/review_themes.json:106] [source: docs/research/02-phase2-competitors-identity.md:35]

## 2. What Parchi does

- Parchi aims to help finish a confirmed parchi: price the medicines, show lab prices separately, ask nearby shops and reroute failed items with the patient's approval.

**Speaker note:** The whole-parchi plan is the goal; today tests typed onto a parchi are priced lab by lab below the medicine plan and are not in its total. The demo parchi is built in, other parchis can be typed in, the reader is disconnected and real checkout is untested. [source: docs/team/DEMO-RUNBOOK.md] [source: docs/verification/EVIDENCE-23-OCT-2026.md]

## 3. The cancellation demo

- On the first photo, show consent with **Not now**, then the preview: we try to hide personal details; the user must check. Say plainly that the reader is disconnected and this loads the built-in demo parchi.
- Confirm the doubtful line; show **Add a medicine / Add a test / Remove**, then **Plan List | Map** and a shop sheet with **Call / Directions / Ask this shop**.
- Show a shop reply changing the plan, a seller page and a labelled **Test order**; let the judge cancel, inspect Plan B and tap **Approve** to move only failed items.

**Speaker note:** This is the requested **90-second** edit of the runbook's **2-minute** story, not a measured rehearsal time. [source: docs/deck/BRIEF_CODEX_C5.md] [source: docs/team/DEMO-RUNBOOK.md] Say “seller page only, checkout untested”; scanner, Open in, WhatsApp, Calendar and notifications still need a real iPhone run. [source: app/KIRO_REPORT_K14.md] [source: app/KIRO_REPORT_K18.md] [source: app/Parchi/Support/Capture/CaptureSession.swift] [source: app/Parchi/Support/Phase4/FirstRunConsentView.swift] [source: docs/verification/EVIDENCE-23-OCT-2026.md]

## 4. Architecture and the current reading path

- **SwiftUI** screens, **SwiftData** saved parchis and **MapKit** live shop search; Parchi does not save Apple Maps results. **Map data © Apple.** [source: docs/team/FRONTEND-TECH-STACK.md] [source: app/KIRO_REPORT_K14.md]
- **ParchiCore** runs brand–strength checks, the planner and Plan B on the phone; **Temporal**, a Python worker/API and SQLite run on our lab computer. [source: docs/plan/12-V2-MASTER-PLAN.md]
- In Live mode the **whole processed picture** goes to our own lab computer to be read: no medicine crop and no confidence gate. **Reader not connected.** [source: app/KIRO_REPORT_K13.md]

**Speaker note:** Draw a phone box containing import, attempted privacy masking, preview, confirmation, ParchiCore and screens, linked to a lab-computer box containing the API, Temporal and SQLite; mark the reader box “not connected”. Our own training is not working yet; Eka, a frontier vision API fallback and small OCR models are being tested, while the demo uses built-in lines or typed entry. [source: docs/research/01-phase1-reading-the-prescription.md] [source: docs/research/10-dataset-training-verification.md] [source: docs/team/DEMO-RUNBOOK.md]

## 5. Plan B and the safety net

- Replan only failed items and show the change before approval.
- Store approvals against plan versions, audit transitions and test recovery without duplicate sandbox placements.
- The measured scenario adds **₹165.74** after the Truemeds cancellation, using the dated price snapshot and explicitly assumed fee rules. [source: docs/research/06-phases-3-to-7-progress.md:43] [source: docs/research/06-phases-3-to-7-progress.md:47]

**Speaker note:** This is our strongest demonstrated novelty candidate: whole-prescription planning coupled to recovery after a seller failure. The runbook says “only the failed items move, everything else stays”, and the acceptance record supports cancellation and approval in the live sandbox plus worker-restart recovery. We do not claim that real sellers send us cancellation events or accept automatic replacement orders. [source: docs/team/DEMO-RUNBOOK.md:17] [source: docs/verification/EVIDENCE-23-OCT-2026.md] [source: docs/research/07-phase6-automation-final.md:34]

## 6. Prices with provenance and limits

- Catalogue MRP lookup now works beyond the demo: **6/6 demo medicines** priced and **6/6** with a Jan Aushadhi equivalent; in a **sample of 200 catalogue brands**, **175** priced and **103** had an equivalent. [source: engine/KIRO_REPORT_K17.md]
- The app's matcher found Jan Aushadhi candidates for **55.7% of 327 real handwritten medicine mentions**; candidates say **ask your doctor**, never automatic substitution. [source: engine/KIRO_REPORT_E5.md] [source: docs/verification/EVIDENCE-23-OCT-2026.md]
- Prices carry a source and date, with a warning after **7 days**; catalogue prices say **“Catalogue MRP · check at the shop”**, not a shop quote. [source: docs/verification/EVIDENCE-23-OCT-2026.md] [source: app/KIRO_REPORT_K14.md]

**Speaker note:** The catalogue-brand sample is not a prescription test, and missing or unsafe matches stay unpriced. Independent review found wrong-price bugs in combination strengths, units, pack sizes, huge quantities and H1/X checks from product salts; fixes are recorded, but they do not prove live stock or a guaranteed checkout total. [source: docs/verification/CODEX-REVIEW-5-CATALOGUE.md] [source: engine/KIRO_REPORT_K17.md] [source: app/Parchi/Model/AppModel.swift]

## 7. Privacy with disclosed exceptions

- The app **tries** to hide name, age, phone and address on the phone; **the user must check the preview**. Live mode sends the whole processed picture to our own lab computer. [source: app/KIRO_REPORT_K13.md]
- Separate tool: names hidden **98.3% of 300 synthetic parchis**, **12/12 real web photos by eye**; phones only **46.0% (23/50)**; **7.1%** of medicine lines over-blurred. [source: docs/research/10-dataset-training-verification.md]
- Photo copies are removed **the next time the app opens after 24 hours**. Delete everything clears phone data and asks the server to delete; Temporal history stays up to **24 h**, and Calendar events must be deleted in Calendar. [source: app/KIRO_REPORT_K13.md]

**Speaker note:** An independent Codex review found **12 problems** in the first version; most are reported fixed, but privacy remains PARTIAL. Known limits include the name-label fallback, Calendar events, uncancelled refill workflows, retained server histories and temporary upload files; these are detailed in the judge answers, and the tool measurements are not an app privacy guarantee. [source: docs/verification/CODEX-REVIEW-4-PRIVACY.md] [source: app/KIRO_REPORT_K13.md]

## 8. Acceptance evidence, including the unfinished work

- Recorded lab evidence, not a complete-product pass; final suite counts await Claude’s final run.
- Suites: engine **148**, server **256**, app unit **86** (+1 skipped runner), app UI **24**, Python tools **34**. [source: docs/deck/NUMBERS-AUDIT.md]
- Live server Plan B loop: **3 times in a row, 72 checks, about 19 s**; proposal **about 1.9 s** after judge cancel. Shop/lab **11/11**; privacy/delete **5/5**, within their scripted scopes. [source: docs/verification/EVIDENCE-23-OCT-2026.md]

| Acceptance row | Recorded status | What the evidence actually covers |
|---|---|---|
| T1 Engine | **PASS** (final run 24 Oct 01:20) | Engine 148; Python tools 34; app unit 86. [source: docs/deck/NUMBERS-AUDIT.md] |
| T2 Orchestrator | **PASS** (final run 24 Oct 01:20) | Server 256; worker kill/restart recovery in the sandbox. [source: docs/verification/EVIDENCE-23-OCT-2026.md] |
| T3 Cancellation and approval | **PASS, limited scope** | Live Simulator approval starts at Track; share-to-plan taps excluded. Final app UI count 24; the Mock cancel test has a recorded flake. [source: docs/verification/EVIDENCE-23-OCT-2026.md] [source: app/KIRO_REPORT_K14.md] |
| T4 Shop auction | **PASS** | Timeout escalation on a test clock; live reply handling and shop quotes changing the plan. [source: docs/verification/EVIDENCE-23-OCT-2026.md] |
| T5 Lab flow | **PARTIAL** | Server booking/reply/reminder works; Calendar/notifications still need a real phone. [source: docs/verification/EVIDENCE-23-OCT-2026.md] |
| T6 Checkout | **NOT MET** | 11 of 13 seller pages render; login/cart/pay never tested, UPI hand-off blocked. [source: docs/verification/EVIDENCE-23-OCT-2026.md] |
| T7 Offline | **PARTIAL** | Saved Mock plan reopens; no verified complete offline-reading path. [source: docs/verification/EVIDENCE-23-OCT-2026.md] |
| T8 Privacy | **PARTIAL** | Attempted masking, preview and consent gate; delete checks have retained-history and Calendar exceptions. [source: app/KIRO_REPORT_K13.md] [source: app/Parchi/Support/Capture/CaptureSession.swift] |
| T9 Price provenance | **PASS for bundled data** | 208 rows checked for source/date; not a live-shop price guarantee. [source: docs/verification/EVIDENCE-23-OCT-2026.md] |
| T10 Real iPhone | **NOT DONE** | Scanner, Open in, WhatsApp, Calendar and notifications not run on a real iPhone. [source: docs/verification/EVIDENCE-23-OCT-2026.md] [source: docs/team/REAL-IPHONE-RUN.md] |

**Speaker note:** The server loops do not establish a complete scan-to-purchase rehearsal, and the privacy/delete script does not measure how much personal information the app hides. Newer fix reports and current consent code update stale rows in the acceptance file; none closes checkout or the real-phone gap. [source: docs/verification/EVIDENCE-23-OCT-2026.md] [source: app/KIRO_REPORT_K13.md] [source: app/Parchi/Support/Capture/CaptureSession.swift]

## 9. Competitors and the actual overlap

- Prescription reading, price comparison and lab booking already exist.
- Our claimed difference is medicine planning with separate lab prices, local shop replies and failed-item recovery demonstrated in a sandbox.

| Competitor | Existing capability in the required research file | Parchi difference and limit |
|---|---|---|
| QuickPill | AI prescription reading, online pharmacy comparison and advertised ordering/delivery, through a website. | Reading and comparison overlap. The research lists no tests or nearby shops for QuickPill, while Parchi shows medicine planning, separate lab prices and sandbox recovery, without verified real checkout. [source: docs/research/02-phase2-competitors-identity.md:17] [source: docs/verification/EVIDENCE-23-OCT-2026.md] |
| MediSaathi | Handwritten reading in beta and online seller comparison. | Reading/comparison overlap. The research lists no lab tests or nearby shops, while Parchi adds them to its planning scope, with supplier fulfilment still unproven. [source: docs/research/02-phase2-competitors-identity.md:18] |
| Smart Bharat Lab | AI test extraction, a multi-lab cart and booking with partner labs. | Test reading and booking overlap. Its documented scope is tests, while Parchi also plans medicines and shows separate lab prices; the app lab flow remains PARTIAL. [source: docs/research/02-phase2-competitors-identity.md:23] [source: docs/verification/EVIDENCE-23-OCT-2026.md] |
| Fullscript | **NOT IN THE FILES**: absent from the required competitor file. | Differences and overlap: **NOT IN THE FILES**. [source: docs/research/02-phase2-competitors-identity.md] |

**Speaker note:** The competitor research permits the bounded wording “no public product found”, not a universal first-ever claim. Later testing says “Reading alone is not our edge over QuickPill”, so we claim no handwriting superiority and treat competitor capabilities as a dated research snapshot. [source: docs/research/02-phase2-competitors-identity.md:89] [source: docs/research/10-dataset-training-verification.md:32]

## 10. Safety boundaries and what is still missing

- Never recommend doses or tests, switch brands, dispense medicines or hold money; **H1/X** says “buy in person with the original parchi”. [source: CLAUDE.md]
- **Reader not connected; own training not working yet.** Training-data size: **to be measured**. The built-in demo and typed entry work without a reader. [source: docs/research/10-dataset-training-verification.md] [source: docs/team/AI-Aditya-Singhal.md] [source: docs/team/DEMO-RUNBOOK.md]
- No real iPhone run; Checkout Assistant login/cart/pay never tested; Hindi only in consent as a plain, non-native-reviewed translation. Final team HTML design is due **3 am, 24 Oct**, then needs conversion to SwiftUI. [source: docs/verification/EVIDENCE-23-OCT-2026.md] [source: app/KIRO_REPORT_K13.md] [source: docs/team/HTML-HANDOFF.md]

**Speaker note:** No independently validated downloadable reader for messy Indian prescriptions is established by our repo evidence; candidate and baseline scores are not our deployed reader's accuracy. The existing screens are functional drafts; final design conversion, Hindi review and physical-device checks still need people. [source: docs/research/01-phase1-reading-the-prescription.md] [source: docs/team/HTML-HANDOFF.md] [source: docs/verification/EVIDENCE-23-OCT-2026.md]

## 11. Roadmap after the acceptance gaps close

- **V3:** a personal recommendation engine for fulfilment preferences, within the existing ban on treatment or test recommendations. [source: docs/plan/12-V2-MASTER-PLAN.md:163] [source: CONTEXT.md:21]
- Partner APIs for pharmacies and labs, with automatic carts through authorised integrations.
- A shop dashboard and WhatsApp Business integration, followed by broader city coverage.

**Speaker note:** The master plan places “automatic cart on big apps via partner APIs” after the current target, so it is roadmap work. We first need to close the missing acceptance checks and validate with real patients and providers before promising production fulfilment. [source: docs/plan/12-V2-MASTER-PLAN.md:163] [source: docs/verification/EVIDENCE-23-OCT-2026.md]

## 12. Team and the ask

- **Aditya Singh:** ParchiCore integration, server, sandbox, Plan B, deck and demo.
- **Aditya Singhal:** AI, data, training, testing and model export.
- **Antara Gupta:** screens, with **Aditya** owning capture, privacy and care integration.

**Speaker note:** These are assigned responsibilities, not claims that every assigned feature has shipped. [source: CONTEXT.md:42] [source: CONTEXT.md:43] [source: CONTEXT.md:44] [source: CONTEXT.md:45] Our proposed ask is introductions to willing chemists and labs, supervised patient testing and access to a real iPhone to close the documented gaps.
