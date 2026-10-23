# Parchi final: slide outline

Evidence snapshot: 23 Oct 2026. [source: docs/verification/EVIDENCE-23-OCT-2026.md:1]
Format: 12 slides for a 24-hour Swift hackathon final. [source: docs/deck/BRIEF_CODEX_C5.md:5]
Paths below are relative to the repository root. Acceptance statuses take precedence over older plans. Speaker notes are spoken copy; citations stay in the presentation notes or visible price footers.

## 1. The parchi leaves the patient with unfinished work

- The patient must decipher the handwriting, find the items and compare the payable price.
- In the PharmEasy review sample, **25.2% of low-rated reviews mentioned delay, non-delivery or cancellation**. [source: docs/research/evidence/review_themes.json:106]
- A price comparison stops helping when the selected seller cancels.

**Speaker note:** The review file calls this theme “Delay / not delivered / cancelled”, and the research explains that it used keyword matching on low-rated reviews. This is evidence of a complaint in that sample, not a delivery-failure rate for all customers. [source: docs/research/evidence/review_themes.json:106] [source: docs/research/02-phase2-competitors-identity.md:35]

## 2. What Parchi does

- Parchi aims to turn a confirmed prescription into a complete, priced plan across medicine sellers and labs, then help reroute failed items with the patient's approval.

**Speaker note:** Our context calls the goal “ONE plan for the whole parchi”. Today the demonstrated core uses a preloaded prescription and labelled test orders, because the reader is not connected and real checkout remains untested. [source: CONTEXT.md:6] [source: docs/team/DEMO-RUNBOOK.md:30] [source: docs/verification/EVIDENCE-23-OCT-2026.md:11]

## 3. The cancellation demo

- Import the demo photo, show the on-phone blur preview, confirm the doubtful medicine line and open the plan with dated price sources.
- Show a shop reply changing the plan, then open a seller page and the labelled **Test order** flow.
- Let the judge cancel a sandbox seller, inspect the Plan B proposal and tap **Approve** to move only failed items.

**Speaker note:** This is the requested **90-second** edit of the runbook's **2-minute** story, not a measured rehearsal time. [source: docs/deck/BRIEF_CODEX_C5.md:5] [source: docs/team/DEMO-RUNBOOK.md:11] Say “the reader is disconnected, so this loads the demo parchi” when that fallback appears, and say “seller page only, checkout untested” at the browser step. [source: docs/team/DEMO-RUNBOOK.md:12] [source: docs/team/DEMO-RUNBOOK.md:31]

## 4. Architecture and the intended reading path

- **SwiftUI** presents Confirm, Plan and Track, with **SwiftData** for saved parchis and **MapKit** as the map framework. [source: docs/team/FRONTEND-TECH-STACK.md:7] [source: docs/team/FRONTEND-TECH-STACK.md:10] [source: docs/team/FRONTEND-TECH-STACK.md:11]
- **ParchiCore** runs the planner, brand–strength checks and Plan B on the phone.
- **Temporal** runs durable workflows through a Python worker on the iMac, with a Python API and SQLite app records. [source: docs/plan/12-V2-MASTER-PLAN.md:88]

**Speaker note:** Describe the diagram as a phone box containing Photos import, blur, confirmation, ParchiCore and the screens, linked to an iMac box containing the API, Temporal worker and SQLite. A separate reader box connects to the API as an intended dependency, labelled “reader not connected”, while seller and lab boxes sit beyond user hand-off or labelled sandbox actions. The plan says “ParchiCore (planner, Plan B, checks) runs on the phone”, while the frontend stack still lists the Plan map as work to build. [source: docs/plan/12-V2-MASTER-PLAN.md:75] [source: docs/team/FRONTEND-TECH-STACK.md:7] [source: docs/team/FRONTEND-TECH-STACK.md:28] [source: docs/team/DEMO-RUNBOOK.md:30]

## 5. Plan B and the safety net

- Replan only failed items and show the change before approval.
- Store approvals against plan versions, audit transitions and test recovery without duplicate sandbox placements.
- The measured scenario adds **₹165.74** after the Truemeds cancellation, using the dated price snapshot and explicitly assumed fee rules. [source: docs/research/06-phases-3-to-7-progress.md:43] [source: docs/research/06-phases-3-to-7-progress.md:47]

**Speaker note:** This is our strongest demonstrated novelty candidate: whole-prescription planning coupled to recovery after a seller failure. The runbook says “only the failed items move, everything else stays”, and the acceptance record supports cancellation and approval in the live sandbox plus worker-restart recovery. We do not claim that real sellers send us cancellation events or accept automatic replacement orders. [source: docs/team/DEMO-RUNBOOK.md:17] [source: docs/verification/EVIDENCE-23-OCT-2026.md:7] [source: docs/verification/EVIDENCE-23-OCT-2026.md:8] [source: docs/research/07-phase6-automation-final.md:34]

## 6. Prices with provenance and limits

- Every bundled price has a source and date, with “may have changed” after **7 days**. [source: docs/verification/EVIDENCE-23-OCT-2026.md:14]
- Keep medicine form, strength and pack comparable, and mark fee assumptions instead of promising a guaranteed checkout total.
- A missing live price needs a dated MRP fallback, but general catalogue MRP wiring remains unfinished.

**Speaker note:** The raw basket records prices as “captured 23 Oct 2026 05:10 IST”, and its location is not the same as our target cities. [source: docs/research/evidence/medscanner_basket_2026-10-23.json:1] These are dated comparisons, not live local offers, and the runbook explicitly says catalogue MRPs still need wiring for non-demo prescriptions. [source: docs/research/06-phases-3-to-7-progress.md:23] [source: docs/team/DEMO-RUNBOOK.md:30]

## 7. Privacy with disclosed exceptions

- Photos import pixelates identifying fields on the phone before Live upload, demonstrated on **2 synthetic samples** in the Simulator. [source: docs/verification/EVIDENCE-23-OCT-2026.md:13]
- The separate blur tool hid **98.3%** of patient names on **300** synthetic images, which is not an end-to-end app privacy score. [source: docs/verification/EVIDENCE-23-OCT-2026.md:13]
- The app's Delete everything action cleared server working records in checks, but random deleted-order identifiers remain **48 h** and Temporal item/price/seller history remains **24 h**. [source: docs/verification/EVIDENCE-23-OCT-2026.md:13]

**Speaker note:** The acceptance record says “only the blurred copy is kept up to 24 h”, but the overall privacy row remains PARTIAL. [source: docs/verification/EVIDENCE-23-OCT-2026.md:13] Handwritten phone-number masking is much weaker than name masking, consent is unmounted, and camera capture and the share extension remain unbuilt. [source: docs/research/10-dataset-training-verification.md:43] [source: docs/verification/EVIDENCE-23-OCT-2026.md:13]

## 8. Acceptance evidence, including the unfinished work

- These are recorded lab results, not a claim that the complete product passed.
- Keep the table's scope qualifiers visible, especially where a PASS covers only a narrower test.

| Acceptance row | Recorded status | What the evidence actually covers |
|---|---|---|
| T1 Engine | **PASS** | 97 Swift tests. [source: docs/verification/EVIDENCE-23-OCT-2026.md:6] |
| T2 Orchestrator | **PASS** | 184 pytest tests plus worker kill/restart recovery. [source: docs/verification/EVIDENCE-23-OCT-2026.md:7] |
| T3 Cancellation and approval | **PASS, limited scope** | 3/3 real-tap Simulator runs from Track, not the complete share-to-plan path. [source: docs/verification/EVIDENCE-23-OCT-2026.md:8] |
| T4 Shop auction | **PASS** | Timeout escalation on a test clock, with live reply handling and plan changes recorded separately. [source: docs/verification/EVIDENCE-23-OCT-2026.md:9] [source: docs/verification/EVIDENCE-23-OCT-2026.md:24] |
| T5 Lab flow | **PARTIAL** | Server booking/reply/reminder works, app Calendar and notifications shown in Mock only, no real-phone run. [source: docs/verification/EVIDENCE-23-OCT-2026.md:10] |
| T6 Checkout | **NOT MET** | 11 of 13 seller pages render, but login, cart and pay never tested, UPI hand-off blocked. [source: docs/verification/EVIDENCE-23-OCT-2026.md:11] |
| T7 Offline | **PARTIAL** | Saved Mock plan reopens, parser tested on typed lines, no actual Vision-output or Wi-Fi-off capture test. [source: docs/verification/EVIDENCE-23-OCT-2026.md:12] |
| T8 Privacy | **PARTIAL** | Simulator blur samples and delete-all checks, with retained histories and missing capture/consent integration. [source: docs/verification/EVIDENCE-23-OCT-2026.md:13] |
| T9 Price provenance | **PASS for bundled data** | 208 rows checked for source/date, stale-price UI verified. [source: docs/verification/EVIDENCE-23-OCT-2026.md:14] |
| T10 Real iPhone | **NOT DONE** | Scanner, SMS and map-location device run absent. [source: docs/verification/EVIDENCE-23-OCT-2026.md:15] |

**Speaker note:** The cancellation test explicitly says “NOT covered: \"share -> confirm -> plan\" taps”. The table demonstrates useful working pieces while leaving the end-to-end product target incomplete. [source: docs/verification/EVIDENCE-23-OCT-2026.md:8] [source: docs/plan/12-V2-MASTER-PLAN.md:12]

## 9. Competitors and the actual overlap

- Prescription reading, price comparison and lab booking already exist.
- Our claimed difference is the combined plan, local shop replies and failed-item recovery demonstrated in a sandbox.

| Competitor | Existing capability in the required research file | Parchi difference and limit |
|---|---|---|
| QuickPill | AI prescription reading, online pharmacy comparison and advertised ordering/delivery, through a website. | Reading and comparison overlap. The research lists no tests or nearby shops for QuickPill, while Parchi demonstrates combined planning and sandbox recovery, without verified real checkout. [source: docs/research/02-phase2-competitors-identity.md:17] [source: docs/verification/EVIDENCE-23-OCT-2026.md:11] |
| MediSaathi | Handwritten reading in beta and online seller comparison. | Reading/comparison overlap. The research lists no lab tests or nearby shops, while Parchi adds them to its planning scope, with supplier fulfilment still unproven. [source: docs/research/02-phase2-competitors-identity.md:18] |
| Smart Bharat Lab | AI test extraction, a multi-lab cart and booking with partner labs. | Test reading and booking overlap. Its documented scope is tests, while Parchi plans medicines alongside tests, with the app lab flow still PARTIAL. [source: docs/research/02-phase2-competitors-identity.md:23] [source: docs/verification/EVIDENCE-23-OCT-2026.md:10] |
| Fullscript | **NOT IN THE FILES**: absent from the required competitor file. | Differences and overlap: **NOT IN THE FILES**. [source: docs/research/02-phase2-competitors-identity.md] |

**Speaker note:** The competitor research permits the bounded wording “no public product found”, not a universal first-ever claim. Later testing says “Reading alone is not our edge over QuickPill”, so we claim no handwriting superiority and treat competitor capabilities as a dated research snapshot. [source: docs/research/02-phase2-competitors-identity.md:89] [source: docs/research/10-dataset-training-verification.md:32]

## 10. Safety boundaries and what is still missing

- Never recommend doses or tests, switch brands, dispense medicines or hold the patient's money.
- **H1/X** items say “buy in person with the original parchi”, and Jan Aushadhi matches say “ask your doctor”. [source: CONTEXT.md:21] [source: CONTEXT.md:22]
- Reader integration, real seller checkout, camera/share capture and real-phone validation remain open.

**Speaker note:** “The reader model is not connected yet” is the runbook's explicit limit. We also cannot claim complete offline reading, real-device Calendar delivery, or a fully mounted consent flow from the current acceptance record. [source: docs/team/DEMO-RUNBOOK.md:30] [source: docs/verification/EVIDENCE-23-OCT-2026.md:10] [source: docs/verification/EVIDENCE-23-OCT-2026.md:12] [source: docs/verification/EVIDENCE-23-OCT-2026.md:13]

## 11. Roadmap after the acceptance gaps close

- **V3:** a personal recommendation engine for fulfilment preferences, within the existing ban on treatment or test recommendations. [source: docs/plan/12-V2-MASTER-PLAN.md:163] [source: CONTEXT.md:21]
- Partner APIs for pharmacies and labs, with automatic carts through authorised integrations.
- A shop dashboard and WhatsApp Business integration, followed by broader city coverage.

**Speaker note:** The master plan places “automatic cart on big apps via partner APIs” after the current target, so it is roadmap work. We first need to close the missing acceptance checks and validate with real patients and providers before promising production fulfilment. [source: docs/plan/12-V2-MASTER-PLAN.md:163] [source: docs/verification/EVIDENCE-23-OCT-2026.md:10]

## 12. Team and the ask

- **Aditya Singh:** ParchiCore integration, server, sandbox, Plan B, deck and demo.
- **Aditya Singhal:** AI, data, training, testing and model export.
- **Antara Gupta:** screens, with **Aditya** owning capture, privacy and care integration.

**Speaker note:** These are assigned responsibilities, not claims that every assigned feature has shipped. [source: CONTEXT.md:42] [source: CONTEXT.md:43] [source: CONTEXT.md:44] [source: CONTEXT.md:45] Our proposed ask is introductions to willing chemists and labs, supervised patient testing and access to a real iPhone to close the documented gaps.
