# Parchi: numbers audit

Scope: every number, numeric identifier and editorial count used in `SLIDES.md` and `JUDGE-QA.md`. Paths are relative to the repo root. This update reads the acceptance record, independent reviews, newer fix reports and relevant code; it does not rerun app, engine or server tests. Source filenames and line locators are navigation metadata.

**VERIFIED** means the opened repo file contains the number in the stated context. It does not turn a plan, vendor score, baseline or tool benchmark into a measured app outcome. **UNVERIFIED / PLACEHOLDER** means the required result or source is missing. Newer fix reports and code override stale completion descriptions; the complete product has not passed acceptance.

## Number register

| Number used | Meaning and usage | Opened source file:line | Status and scope |
|---|---|---|---|
| 23 Oct 2026 | Recorded-run date in both headers, not a new execution date. | `docs/verification/EVIDENCE-23-OCT-2026.md:1` | **VERIFIED**, recorded date. |
| 12 slides; 30 questions; ordinals 1–12 and 1–30 | Existing document structure. | `docs/deck/BRIEF_CODEX_C5.md:5`; `docs/deck/BRIEF_CODEX_C5.md:6` | **VERIFIED**, editorial counts. |
| 24-hour | Hackathon format, slide header. | `docs/deck/BRIEF_CODEX_C5.md:5` | **VERIFIED**, format rather than elapsed build time. |
| 25.2% | PharmEasy low-rated review complaint share, slide 1. | `docs/research/evidence/review_themes.json:106`; `docs/research/02-phase2-competitors-identity.md:35` | **VERIFIED**, keyword-coded share in the low-rated sample, not order-failure probability. |
| 90-second; 2-minute | Requested demo edit versus runbook heading, slide 3. | `docs/deck/BRIEF_CODEX_C5.md:5`; `docs/team/DEMO-RUNBOOK.md:11` | **VERIFIED** durations as editorial targets only; completed timed rehearsal **UNVERIFIED**. |
| First photo / once; Not now | Consent gate timing, slide 3 and Q16. | `app/Parchi/Support/Capture/CaptureSession.swift:46`; `app/Parchi/Support/Phase4/FirstRunConsentView.swift:7` | **VERIFIED** in code, not patient consent validation. |
| ₹165.74 | Scenario Plan B cost increase, slide 5. | `docs/research/06-phases-3-to-7-progress.md:47`; `docs/research/06-phases-3-to-7-progress.md:43` | **VERIFIED**, computed dated scenario with fee assumptions, not a checkout quote. |
| 6/6 priced; 6/6 Jan Aushadhi | Demo-medicine catalogue coverage, slide 6 and Q13/Q17. | `engine/KIRO_REPORT_K17.md:14` | **VERIFIED**, demo medicines only. |
| 200; 175; 103 | Sample of catalogue brands: sample size, MRP-priced and Jan Aushadhi candidates, slide 6 and Q13/Q17. | `engine/KIRO_REPORT_K17.md:14` | **VERIFIED**, catalogue-brand sample, NOT real prescriptions; no universal coverage claim. |
| 55.7%; 327 | App matcher coverage on real handwritten medicine mentions, slide 6 and Q13. | `engine/KIRO_REPORT_E5.md:16`; `docs/verification/EVIDENCE-23-OCT-2026.md:36` | **VERIFIED**, candidate catalogue matches, not clinical equivalence or prescription-level success. |
| 7 days | Stale-price warning threshold, slide 6 and Q17. | `docs/verification/EVIDENCE-23-OCT-2026.md:14` | **VERIFIED**, bundled-price behaviour, not continuous live pricing. |
| 98.3%; 300 | Names hidden by the separate tool on fresh synthetic parchis, slide 7 and Q14. | `docs/research/10-dataset-training-verification.md:40` | **VERIFIED**, tool result, not an end-to-end app privacy score. |
| 12/12 real web photos | Names hidden, checked by eye, slide 7 and Q14. | `docs/research/10-dataset-training-verification.md:41` | **VERIFIED**, small visual check, test-only images. |
| 46.0%; 23/50 | Phone masking by the separate tool, slide 7 and Q14. | `docs/research/10-dataset-training-verification.md:40` | **VERIFIED**, weak result kept visible. |
| 7.1%; 73/1,033 | Medicine lines over-blurred by the separate tool, slide 7 and Q14. | `docs/research/10-dataset-training-verification.md:40` | **VERIFIED**, collateral masking. |
| 24 hours / 24 h | Photo purge on next app open after the interval; Temporal workflow-history retention, slide 7 and Q15. | `app/KIRO_REPORT_K13.md:6`; `app/KIRO_REPORT_K13.md:2` | **VERIFIED**, different retention rules; no guaranteed background photo deletion. |
| 48 h | Random deleted-order identifiers retained, Q15. | `docs/verification/EVIDENCE-23-OCT-2026.md:13` | **VERIFIED**, retained identifiers, not a photograph-retention timer. |
| 12 problems | Independent privacy review of the first version, slide 7 and Q15. | `docs/verification/CODEX-REVIEW-4-PRIVACY.md:47`; `app/KIRO_REPORT_K13.md:2` | **VERIFIED**, numbered findings; most reported fixed, partial/unchanged limits listed separately. |
| 3 times; 72 checks; about 19 s | Live server Plan B loops, slide 8 and Q10. | `docs/verification/EVIDENCE-23-OCT-2026.md:19` | **VERIFIED**, server loop scope, not full scan-to-purchase or a final suite total. |
| About 1.9 s | Plan B proposal after judge cancel, slide 8 and Q10. | `docs/verification/EVIDENCE-23-OCT-2026.md:8` | **VERIFIED**, rounded recorded range, not a response-time guarantee. |
| 11/11; 5/5 | Live shop/lab and privacy/delete script checks, slide 8 and Q10. | `docs/verification/EVIDENCE-23-OCT-2026.md:9`; `docs/verification/EVIDENCE-23-OCT-2026.md:13` | **VERIFIED**, scoped checks; delete result does not establish PII masking coverage. |
| 11 of 13 | Seller pages rendering, slide 8 and Q20. | `docs/verification/EVIDENCE-23-OCT-2026.md:11` | **VERIFIED** aggregate, not checkout success; login/cart/pay never tested. |
| 208 | Bundled rows checked for source/date, slide 8. | `docs/verification/EVIDENCE-23-OCT-2026.md:14` | **VERIFIED**, provenance rows, not live offers or catalogue coverage. |
| T1–T10 | Acceptance row labels, slide 8. | `docs/verification/EVIDENCE-23-OCT-2026.md:6`; `docs/verification/EVIDENCE-23-OCT-2026.md:15` | **VERIFIED**, identifiers; real iPhone remains NOT DONE. |
| H1/X; V3 | Restricted-medicine identifiers and roadmap version. | `CLAUDE.md:22`; `docs/plan/12-V2-MASTER-PLAN.md:162` | **VERIFIED**, labels rather than counts or completion claims. |
| 3 am, 24 Oct | Final HTML design handoff deadline, slides 10 and Q9/Q26. | `docs/team/HTML-HANDOFF.md:2` | **VERIFIED** planned handoff, not received design or completed SwiftUI conversion. |
| 89.7%; 12 prescriptions | QuickPill and frontier recall on the same medicine-bearing subset, Q2. | `docs/research/10-dataset-training-verification.md:25`; `docs/research/10-dataset-training-verification.md:27`; `docs/research/10-dataset-training-verification.md:28` | **VERIFIED**, neither is the deployed Parchi reader. |
| 3 shops; 10 min | Next shop group after no reply, Q6. | `docs/verification/EVIDENCE-23-OCT-2026.md:9` | **VERIFIED** test-clock escalation; not real-provider response evidence. |
| Parrotlet-v-2.5-pro; Apache-2.0 | Candidate model version and licence identifiers, Q11. | `docs/research/01-phase1-reading-the-prescription.md:72` | **VERIFIED** in repo research; not a tested Parchi deployment. |
| 85.03; 1,147 pages | Eka self-reported prescription score and test-set size, Q11. | `docs/research/01-phase1-reading-the-prescription.md:47` | **VERIFIED** as reported vendor result on its own AI-graded test, not independent validation or Parchi accuracy; do not add a percent sign to the score. |
| 82.1% recall; 87.3% precision; 16 records | Claude frontier baseline on real handwritten records, Q11. | `docs/research/10-dataset-training-verification.md:14`; `docs/research/01-phase1-reading-the-prescription.md:37` | **VERIFIED**, small baseline sample, not a connected fallback API or own trained model. |
| Telma 400 vs 40 | Doubtful strength example, Q12. | `docs/team/DEMO-RUNBOOK.md:13` | **VERIFIED**, demo strings, not medical dose advice. |
| ₹2,696.77; 6 medicines; 4 tests | Historical computed demo scenario, Q18. | `docs/research/06-phases-3-to-7-progress.md:44` | **VERIFIED**, scenario with fee assumptions; not the total for a newly typed parchi. Typed tests are outside its medicine-plan total. |
| 6-medicine basket; ₹1,030.40; ₹826.43; ₹189.48; 81.6% | Separate dated medicine-only listing comparison, Q19. | `docs/research/06-phases-3-to-7-progress.md:15`; `docs/research/06-phases-3-to-7-progress.md:22` | **VERIFIED**, same-brand MRP/online versus doctor-approved equivalents; no promised net checkout savings. |
| Exactly 2 placements | Worker kill/restart result, Q23. | `docs/verification/EVIDENCE-23-OCT-2026.md:7` | **VERIFIED**, sandbox only. |
| 7–8 criteria; 8 named; ≥7.5; ≥8 | Internal team judging criteria and pass lines, Q29. | `docs/deck/BRIEF_CODEX_C5.md:3` | **VERIFIED**, team thresholds, not public event rules or achieved scores. |
| 148 | Final engine-suite count, slide 8 and Q10. | `docs/verification/EVIDENCE-23-OCT-2026.md`; `engine/KIRO_REPORT_K17.md` | **VERIFIED**: 148 passed in the full run of 24 Oct 02:04. |
| 329 | Final server-suite count, slide 8 and Q10/Q23. | `docs/verification/EVIDENCE-23-OCT-2026.md`; `app/KIRO_REPORT_K13.md` | **VERIFIED**: 329 passed, 1 skipped, on the lab iMac, full run of 24 Oct 02:04. |
| 92 | Final app-unit count, slide 8 and Q10. | `app/KIRO_REPORT_K14.md`; `app/KIRO_REPORT_K18.md` | **VERIFIED**: 93 run, 92 passed, 1 skipped (the K16 measurement runner), full run of 24 Oct 02:04. |
| 24 | Final app-UI count, slide 8 and Q10. | `app/KIRO_REPORT_K13.md`; `app/KIRO_REPORT_K14.md`; `app/KIRO_REPORT_K18.md` | **VERIFIED**: 24 of 24 UI tests passed in the full run of 24 Oct 02:04; the Mock Simulate-cancel test passed 5 of 5 on repeat after its test fix (it failed 3 of 5 before).|
| 34 | Final Python-tool count, slide 8 and Q10. | `engine/KIRO_REPORT_K17.md` | **VERIFIED**: 34 OK, full run of 24 Oct 02:04. |
| five | Number of document types in Eka's own test, Q11. | `docs/research/01-phase1-reading-the-prescription.md` records the score/page count, not this count. | **VERIFIED** on the Hugging Face model page (24 Oct): "1,147 held-out pages across five document types"; saved in `docs/research/11-reader-model-survey-24-oct.md`. |
| ≥80% | Independent messy-Indian-prescription threshold, Q11. | `docs/research/01-phase1-reading-the-prescription.md` has model results in different setups, not proof of this downloadable-model claim. | **OUR TARGET, not a result**: 80% medicine recall is the threshold we set; the model survey (`docs/research/11-reader-model-survey-24-oct.md`) found no downloadable model that independently shows it on messy Indian prescriptions. |
| To be measured | Actual reader training-data size, slide 10 and Q11. | `docs/team/AI-Aditya-Singhal.md:35`; `docs/research/10-dataset-training-verification.md:10` | **UNVERIFIED actual size**. Generation targets, hold-out and hand-copy plans are not completed data or a training result. |

## Discrepancies, stale snapshots and misleading comparisons

| Topic | Older claim / source | Newer evidence or limitation | Resolution for the deck |
|---|---|---|---|
| Jan Aushadhi | `CONTEXT.md` and early research use rounded Python-heuristic coverage. | `engine/KIRO_REPORT_E5.md` and the acceptance record give **55.7% of 327** with the app's stricter matcher. | Use **55.7%** throughout; heuristic and app methods differ, not merely rounding. |
| Suite totals | Acceptance, E5 and Kiro reports contain different job-specific snapshots. | No final combined run is supplied in this brief. | All suite totals use the five requested placeholders; no old totals carried into the deck or presented as current. |
| Catalogue prices | Old runbook limits say non-demo MRP is unfinished. | K17 records **6/6** demo medicines priced; **175/200** catalogue-brand sample priced, **103/200** with JA candidates. `AppModel.refreshCatalogue` wires lookup and salt-based H1/X checks. | Catalogue pricing is wired beyond the demo; no claim that every brand prices or that these are real prescriptions. |
| Wrong prices | Independent catalogue review found unsafe strength/unit/form/pack/quantity matches and H1/X gaps. | K17 records engine/data fixes and app handoffs; current `AppModel.swift` checks product salts and compares this parchi's JA lines. | Say recorded fixes, not universal correctness or a fresh independent retest. Unknown matches stay unpriced. |
| Tests in total | Historical scenario includes **6 medicines + 4 tests** at **₹2,696.77**; K18 initially reported typed tests blocking the plan. | Updated runbook, `PlanView.swift` and `AppModel.swift` put typed tests lab by lab below the medicine plan, outside its total. The built-in demo still has bundled test offers. | Keep the historical demo total scoped to that scenario; disclose separate lab prices for typed parchis. |
| Privacy / upload | Context and plans describe guaranteed hiding, crop-only upload and a confidence gate. | Independent privacy review and K13 say the whole processed picture is uploaded in Live; masking can miss PII. | “Tries to hide”; user must inspect preview; no crop, no confidence gate; tool scores are not app privacy success. |
| Deletion | Old copy promises a photo lifetime of at most **24 h** and complete deletion. | K13: photo purge needs next app open after **24 h**; Calendar events stay, refill workflows are not cancelled; Temporal history up to **24 h**. Acceptance retains random deleted-order ids **48 h**. | State each exception; server deletion is requested, not guaranteed on failure. |
| Partly/not-fixed privacy findings | Independent review lists **12 problems** in the first version. | K13 leaves the name-label fallback, Calendar events, refill workflow cancellation and temporary multipart disk spooling partly/unchanged; device checks remain unverified. | Most reported fixed; known limits remain in Q15, with no blanket privacy pass. |
| Consent | T8 and K14 describe an unmounted gate. | `CaptureSession.swift` now gates the first photo with `ConsentStore`, mounting `FirstRunConsentView` with Agree / Not now. | Gate is built; patient validation and native-reviewed Hindi are not. |
| Map | Old frontend stack says List/Map is to build. | K14 records live MapKit shops, price pins and shop sheet, memory-only Apple results and Apple attribution. | Say built, with real-phone actions unverified; search area goes to Apple. |
| Reader / training | Context calls the intended reader “our fine-tuned” model; data docs list generation targets. | Reader disconnected; no measured trained-reader outcome or final dataset inventory in supplied repo evidence. Today's brief says own training is not working yet and candidates are being tested. | Say not connected / training not working yet; size “to be measured”; candidate tests are not deployed accuracy. |
| Offline / real phone / checkout | Older plans describe finished capture, offline reading and buying. | Acceptance is PARTIAL offline, NOT DONE real iPhone, NOT MET checkout; **11 of 13** seller pages rendering proves no login/cart/pay path. | Keep those limits; scanner/Open in/WhatsApp/Calendar/notifications need a real phone. |
| Design / Hindi | Functional draft screens exist; broader Hindi support is planned. | HTML handoff due **3 am, 24 Oct**; K13 says Hindi consent is a plain, non-native-reviewed translation. | Final HTML and its SwiftUI conversion are pending; no claim of full Hindi screens. |

## Values that should not be called contradictions

| Apparent mismatch | Opened evidence | Interpretation |
|---|---|---|
| **82.1% / 87.3%** frontier recall/precision on **16** records versus **89.7%** recall on **12** in the head-to-head | `docs/research/10-dataset-training-verification.md:14`, `:25`–`:28` | Different cohorts, neither a deployed Parchi reader. |
| Demo JA **6/6**, catalogue-brand sample **103/200**, handwritten mentions **55.7% of 327** | `engine/KIRO_REPORT_K17.md:14`; `engine/KIRO_REPORT_E5.md:16` | Different inputs and denominators; never merge into a universal matching percentage. |
| Separate listing basket **₹1,030.40 / ₹826.43 / ₹189.48** versus historical plan **₹2,696.77** and Plan B **+₹165.74** | `docs/research/06-phases-3-to-7-progress.md:15`, `:44`, `:47` | Medicine-only listing comparison versus a scenario including tests and assumed fees. Neither guarantees checkout totals. |
| Recorded passes versus final suite placeholders | Acceptance and K13/K14/K17/K18 reports | Completed job-specific checks are evidence; final combined suite counts are in the full run of 24 Oct 02:04. |

## Required source excerpts

These short excerpts anchor the copy changes; plans remain plans.

| Opened file | Exact short excerpt | Why it matters |
|---|---|---|
| `docs/verification/EVIDENCE-23-OCT-2026.md` | “Login, add to cart and pay were never tested” | Checkout stays NOT MET. |
| `app/KIRO_REPORT_K13.md` | “We try to hide the name, age, phone and address we can find.” | No guarantee of hidden personal details. |
| `app/KIRO_REPORT_K13.md` | “Photo copies on this phone are removed the next time you open Parchi after 24 hours.” | No background retention guarantee. |
| `app/KIRO_REPORT_K14.md` | “Catalogue MRP · check at the shop” | Printed price is not a shop quote. |
| `engine/KIRO_REPORT_K17.md` | “Sample 200: MRP 175” | Catalogue-brand sample, not prescription performance. |
| `engine/KIRO_REPORT_E5.md` | “Swift 182/327 = 55.7%” | Use the app matcher result. |
| `docs/team/DEMO-RUNBOOK.md` | “Tests are priced lab by lab below the plan and are not in its total.” | Do not claim a typed-parchi combined total. |
| `docs/team/HTML-HANDOFF.md` | “Deadline: 3 am, 24 Oct.” | Design delivery and conversion are future work. |
| `docs/research/01-phase1-reading-the-prescription.md` | “Their own test, not independent” | Eka's score is vendor evidence only. |

## Facts intentionally left unsupported

Final suite counts, Eka's document-type count, the universal independent downloadable-reader threshold claim, actual training-data size and deployed-reader accuracy have no sufficient repo measurement here. The two reader numbers stay placeholders; candidate testing / own training not working yet and the absent Hindi/handwriting breakdown are supplied by today's verified brief, not a fresh experiment in this docs task.

Fullscript capabilities, a formal Parchi medical-device classification, price-liability allocation, real-chemist response rates, clinical safety outcomes, current-app usability results, signed supplier agreements and measured business revenue remain **NOT IN THE FILES**. Internal judging thresholds are not official rules or achieved results.
