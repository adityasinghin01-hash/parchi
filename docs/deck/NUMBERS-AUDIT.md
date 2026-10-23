# Parchi: numbers audit

Scope: every quantitative claim, date, numeric identifier and editorial count in `SLIDES.md` and `JUDGE-QA.md`. Paths are relative to the repository root. Sources were opened for this task, including all research phase documents and the JSON evidence directory. This is a documentary audit, not a rerun of the recorded experiments.

**VERIFIED** means the opened source contains the stated number in the relevant context. It does not turn a plan, assumption, baseline, tool benchmark or team threshold into a measured product outcome. **UNVERIFIED** means the requested claim lacks the necessary recorded measurement or source fact. Citation filenames and their line locators are navigation metadata, not additional quantitative claims.

## Number register

| Number used | Meaning and usage | Opened source file:line | Status and scope |
|---|---|---|---|
| 23 Oct 2026 | Evidence snapshot in both document headers. | `docs/verification/EVIDENCE-23-OCT-2026.md:1` | **VERIFIED** as the acceptance-record date, not a fresh execution date. |
| 12 | Requested slide count, SLIDES header. | `docs/deck/BRIEF_CODEX_C5.md:5` | **VERIFIED**, editorial requirement. |
| 24-hour | Hackathon format, SLIDES header. | `docs/deck/BRIEF_CODEX_C5.md:5`; `CONTEXT.md:2` | **VERIFIED**, event format stated in the files, not elapsed build time. |
| 25.2% | PharmEasy low-rated reviews mentioning delay/non-delivery/cancellation, slide 1. | `docs/research/evidence/review_themes.json:106`; denominator context `docs/research/02-phase2-competitors-identity.md:35` | **VERIFIED** keyword-coded complaint share, not all-order failure probability. |
| ONE / one complete plan | Product goal quoted on slide 2 and described elsewhere. | `CONTEXT.md:6`; `docs/research/09-phase8-locked-idea.md:7` | **VERIFIED** as the design goal, not full fulfilment acceptance. |
| 90-second | Requested demo edit, slide 3 note. | `docs/deck/BRIEF_CODEX_C5.md:5` | **VERIFIED** as requested duration only. |
| 90-second completed rehearsal | Whether the condensed live story has actually run within that duration. | **NOT IN THE FILES**. The source runbook supplies a differently timed story. | **UNVERIFIED**. The slide explicitly calls this an edit, not a measured rehearsal. |
| 2-minute | Original runbook story duration, slide 3 note. | `docs/team/DEMO-RUNBOOK.md:11` | **VERIFIED** as the runbook heading, not an independently timed result. |
| ₹165.74 | Incremental Plan B cost after Truemeds cancels in the scenario, slide 5. | `docs/research/06-phases-3-to-7-progress.md:47`; assumption disclosure `docs/research/06-phases-3-to-7-progress.md:43` | **VERIFIED** scenario delta, not a live checkout quote. |
| 7 days | Stale-price warning threshold, slide 6 and Q17. | `docs/verification/EVIDENCE-23-OCT-2026.md:14`; `docs/team/FRONTEND-TECH-STACK.md:32` | **VERIFIED** for bundled data/UI, not a freshness guarantee. |
| 23 Oct 2026, 05:10 IST | Raw basket capture date/time quoted on slide 6. | `docs/research/evidence/medscanner_basket_2026-10-23.json:1` | **VERIFIED** snapshot timestamp. |
| 2 synthetic samples | In-app blur demonstration in the Simulator, slide 7 and Q16. | `docs/verification/EVIDENCE-23-OCT-2026.md:13` | **VERIFIED**, limited demonstration, not a real-patient or real-phone trial. |
| 98.3% | Patient names hidden by the separate blur tool, slide 7 and Q14. | `docs/research/10-dataset-training-verification.md:40`; `docs/verification/EVIDENCE-23-OCT-2026.md:13` | **VERIFIED**, name masking only, not overall privacy. |
| 300 | Synthetic image count for that tool evaluation, slide 7 and Q14. | `docs/research/10-dataset-training-verification.md:40`; `docs/verification/EVIDENCE-23-OCT-2026.md:13` | **VERIFIED**, separate from the app samples. |
| 48 h | Retention of random deleted-order identifiers, slide 7 and Q15. | `docs/verification/EVIDENCE-23-OCT-2026.md:13` | **VERIFIED** retention exception. |
| 24 h | Temporal workflow-history retention, slide 7 and Q15. | `docs/verification/EVIDENCE-23-OCT-2026.md:13`; `docs/team/DEMO-RUNBOOK.md:33` | **VERIFIED** retention exception. |
| Up to 24 h | Retention of the blurred photo copy, slide 7 note. | `docs/verification/EVIDENCE-23-OCT-2026.md:13` | **VERIFIED** as the recorded app behaviour. Overall privacy stays PARTIAL. |
| 97 | Engine Swift tests in acceptance, slide 8. | `docs/verification/EVIDENCE-23-OCT-2026.md:6` | **VERIFIED** recorded suite count. |
| 184 | Orchestrator pytest tests, slide 8 and Q23. | `docs/verification/EVIDENCE-23-OCT-2026.md:7` | **VERIFIED** recorded suite count, not external-seller integration coverage. |
| 3/3 | Real-tap cancellation/approval Simulator runs, slide 8 and Q10. | `docs/verification/EVIDENCE-23-OCT-2026.md:8` | **VERIFIED**, starts at Track, excludes share/confirm/plan taps. |
| 11 of 13 | Seller pages that rendered, slide 8 and Q20. | `docs/verification/EVIDENCE-23-OCT-2026.md:11` | **VERIFIED** as the file's aggregate, not checkout success. The same row's seller-name parenthesis is ambiguous, so do not reconstruct a per-seller pass list from it. |
| 208 | Bundled rows checked for source/date, slide 8. | `docs/verification/EVIDENCE-23-OCT-2026.md:14` | **VERIFIED** provenance count, not a count of live offers. |
| H1/X | Restricted-medicine schedule identifiers, slide 10 and Q22. | `CONTEXT.md:22`; `docs/team/FRONTEND-TECH-STACK.md:33` | **VERIFIED** identifiers, not a medicine count. |
| V3 | Future recommendation engine and partner integrations, slide 11. | `docs/plan/12-V2-MASTER-PLAN.md:13`; `docs/plan/12-V2-MASTER-PLAN.md:163` | **VERIFIED** roadmap label, not shipped functionality. |
| 30 | Requested Q&A count, JUDGE-QA header. | `docs/deck/BRIEF_CODEX_C5.md:6` | **VERIFIED**, editorial requirement. |
| 89.7% | Recall for both QuickPill and frontier baseline on the matched subset, Q2. | `docs/research/10-dataset-training-verification.md:27`; `docs/research/10-dataset-training-verification.md:28` | **VERIFIED**, neither value is deployed Parchi reader accuracy. |
| 12 prescriptions | Matched medicine-bearing subset for the head-to-head, Q2. | `docs/research/10-dataset-training-verification.md:25` | **VERIFIED**, not the full blind baseline cohort. |
| 3 shops | Next shop group after no reply, Q6. | `docs/verification/EVIDENCE-23-OCT-2026.md:9` | **VERIFIED** test-clock escalation. |
| 10 min | No-reply interval for that escalation, Q6. | `docs/verification/EVIDENCE-23-OCT-2026.md:9` | **VERIFIED** test-clock interval, not measured real-shop response time. |
| First complete reply | Winner rule in Q6. | `docs/verification/EVIDENCE-23-OCT-2026.md:9` | **VERIFIED** workflow rule, not provider participation evidence. |
| Telma 400 vs 40 | Doubtful strength example, Q12. | `docs/team/DEMO-RUNBOOK.md:13` | **VERIFIED** demo strings, not dose advice. |
| 182/327 | Swift Jan Aushadhi matched mentions and denominator, Q13. | `engine/KIRO_REPORT_E5.md:16` | **VERIFIED** documented harness result. |
| 55.7% | Stricter Swift Jan Aushadhi coverage, Q13. | `engine/KIRO_REPORT_E5.md:16`; `docs/verification/EVIDENCE-23-OCT-2026.md:31` | **VERIFIED**, catalogue coverage, not clinical equivalence. |
| 46.0%, 23/50 | Patient phone-number masking in the separate tool evaluation, Q14. | `docs/research/10-dataset-training-verification.md:40` | **VERIFIED** weak result, not hidden by the name metric. |
| 7.1%, 73/1,033 | Medicine lines mistakenly blurred by the separate tool, Q14. | `docs/research/10-dataset-training-verification.md:40` | **VERIFIED** collateral masking. |
| ₹2,696.77 | Cheapest exact scenario plan total, Q18. | `docs/research/06-phases-3-to-7-progress.md:44` | **VERIFIED** computed scenario using dated prices and some assumed fee rules. |
| 6 medicines, 4 tests | Composition of that scenario, Q18. | `docs/research/06-phases-3-to-7-progress.md:44` | **VERIFIED**, distinct from the medicine-only listing comparison. |
| 6-medicine basket | Separate listed-price basket, Q19. | `docs/research/06-phases-3-to-7-progress.md:9` through `:15`, explicit count at `:22` | **VERIFIED**, exact-brand MRP/online comparison versus doctor-approved equivalent products. |
| ₹1,030.40 | Medicine-only MRP basket total, Q19. | `docs/research/06-phases-3-to-7-progress.md:15` | **VERIFIED**, not an actual receipt from a doctor's shop. |
| ₹826.43 | Medicine-only cheapest online listing total, Q19. | `docs/research/06-phases-3-to-7-progress.md:15` | **VERIFIED**, excludes unverified checkout fees. |
| ₹189.48 | Jan Aushadhi equivalent basket total, Q19. | `docs/research/06-phases-3-to-7-progress.md:15` | **VERIFIED**, needs doctor's approval, not the same brands. |
| 81.6% | Equivalent basket reduction from MRP, Q19. | `docs/research/06-phases-3-to-7-progress.md:15` | **VERIFIED**, listed-price comparison, not promised net savings. |
| Exactly 2 placements | Worker-restart test's placement count, Q23. | `docs/verification/EVIDENCE-23-OCT-2026.md:7` | **VERIFIED** recorded sandbox result. |
| 7–8 criteria | Team brief's description of the internal judging scale, Q29. | `docs/deck/BRIEF_CODEX_C5.md:3` | **VERIFIED** as the team's wording, not an event rubric. |
| 8 named criteria | Complete named internal criterion list, Q29. | `docs/deck/BRIEF_CODEX_C5.md:3`; `docs/research/00-research-plan.md:22` | **VERIFIED**, all named in Q29. |
| ≥7.5 | Internal pass line for innovation and novelty, Q29. | `docs/deck/BRIEF_CODEX_C5.md:3` | **VERIFIED** team threshold only, not an achieved score. |
| ≥8 | Internal pass line for the other criteria, Q29. | `docs/deck/BRIEF_CODEX_C5.md:3` | **VERIFIED** team threshold only, not an official rule. |
| Slide ordinals 1–12; question ordinals 1–30 | Document structure. | `docs/deck/BRIEF_CODEX_C5.md:5`; `docs/deck/BRIEF_CODEX_C5.md:6` | **VERIFIED** requested counts and sequential editorial numbering, not research statistics. |
| T1, T2, T3, T4, T5, T6, T7, T8, T9, T10 | Acceptance row identifiers, slide 8. | `docs/verification/EVIDENCE-23-OCT-2026.md:6` through `:15` | **VERIFIED** row labels. Preserve T10's exact status, NOT DONE. |

## Discrepancies, stale snapshots and misleading comparisons

The acceptance file governs current completion. Where it supplies no comparable numerical outcome, the table says so rather than manufacturing a disagreement.

| Topic | CONTEXT/research value or claim | Acceptance value or limitation | Resolution for the deck |
|---|---|---|---|
| Jan Aushadhi coverage | **57%** in `CONTEXT.md:37`, `docs/research/06-phases-3-to-7-progress.md:55` and `docs/research/09-phase8-locked-idea.md:33`. The form-aware raw file records **187/327** at `docs/research/evidence/mirage_janaushadhi_coverage_formaware.json:3` and `:5`. | **55.7% of 327** for Swift, versus **57.2%** for the Python heuristic in `docs/verification/EVIDENCE-23-OCT-2026.md:31`. E5 records **182/327** versus **187/327** at `engine/KIRO_REPORT_E5.md:16`. | Flag a method-dependent difference, not a rounding-only change. Use **55.7%** for the app engine, and state that it requires salt input. |
| Naive Jan Aushadhi result | Earlier **64%** explicitly rejected at `docs/research/06-phases-3-to-7-progress.md:57`; naive raw count **208/327** at `docs/research/evidence/mirage_janaushadhi_coverage.json:2` and `:5`. | Current Swift **182/327 = 55.7%**, `engine/KIRO_REPORT_E5.md:16`, reaffirmed at `docs/verification/EVIDENCE-23-OCT-2026.md:31`. | The naive matcher confused forms. Do not resurrect its larger result. |
| Engine suite size | **17/17** in `CONTEXT.md:36` and `docs/research/06-phases-3-to-7-progress.md:50`; earlier **16/16** at `docs/research/04-technical-feasibility-problem-upgrade.md:51`. | **97 Swift tests**, plus a separately stated **12** Python data tests, `docs/verification/EVIDENCE-23-OCT-2026.md:6`. | Historical suite growth, not a failure-rate disagreement. Use the acceptance count without adding unrelated suites into a single coverage claim. |
| E5 suite snapshot | E5's **91** total tests at `engine/KIRO_REPORT_E5.md:8`. | **97** at `docs/verification/EVIDENCE-23-OCT-2026.md:6`. | Same dated-snapshot issue. E5 remains the source for its matcher harness numbers, not the latest whole-engine test count. |
| Claimed end-to-end repetitions | Older demo plan requires **3** complete rehearsals at `docs/research/03-onpaper-ux-demo-security.md:108` and `docs/research/09-phase8-locked-idea.md:88`. | **3/3** UI runs from Track, plus **3** server loops, but share/confirm/plan excluded at `docs/verification/EVIDENCE-23-OCT-2026.md:8`. | Counts overlap in appearance but measure different paths. No evidence of the complete rehearsal target being met. |
| Checkout / one-tap ordering | Research labels ordering and hand-off as demo functionality, `docs/research/07-phase6-automation-final.md:34`, and earlier flow promises one tap plus payment. | **11/13** pages render, **NOT MET**, login/cart/pay untested and UPI blocked, `docs/verification/EVIDENCE-23-OCT-2026.md:11`. | Rendering is not checkout. Do not convert a browser probe count into order success. |
| Privacy evaluation scope | **98.3%** of **300** names and **12/12** real photos in `CONTEXT.md:35`; the research also records phones at **46.0% (23/50)** and medicine damage at **7.1% (73/1,033)**, `docs/research/10-dataset-training-verification.md:40` and `:41`. | Overall **PARTIAL**, app demonstrated on **2** synthetic Simulator samples, with tool results quoted separately, `docs/verification/EVIDENCE-23-OCT-2026.md:13`. | Tool percentages agree with acceptance. The mismatch is scope, not arithmetic: never call the tool score an app privacy pass. |
| Blanket deletion after 24 h | Raw-photo deletion after **24 h** in `docs/research/03-onpaper-ux-demo-security.md:122` and `docs/research/07-phase6-automation-final.md:43`. | Blurred copy up to **24 h**, deleted-order random identifiers **48 h**, Temporal history **24 h**, plus delete-all **5/5**, `docs/verification/EVIDENCE-23-OCT-2026.md:13`. | Distinguish the datasets. A blanket “everything disappears immediately/on the photo timer” would contradict the retained-state exceptions. |
| Offline reading and printed accuracy | Earlier **≥80%** printed claim, `docs/research/03-onpaper-ux-demo-security.md:57`; research detail is **12/81** printed/neat successes, `docs/research/01-phase1-reading-the-prescription.md:215`. | Offline **PARTIAL**: typed-line parser has **16** tests, no real Vision-output run, no Wi-Fi-off capture validation, `docs/verification/EVIDENCE-23-OCT-2026.md:12`. | OCR subset performance is not offline app acceptance. No comparable offline success percentage exists in acceptance. |
| Frontend capture timing within the acceptance file | Older research flow assumes scanner/share capture, `docs/research/09-phase8-locked-idea.md:25` and `:26`. | T7 still says no Capture screen; the updated T8 records Photos import and blur on **2** synthetic samples, while camera/share remain absent, `docs/verification/EVIDENCE-23-OCT-2026.md:12` and `:13`. | Use the more specific updated Photos-import description. Do not imply that camera or WhatsApp share therefore shipped. |
| Lab Calendar/reminder completion | Research lists Calendar as real demo functionality, `docs/research/07-phase6-automation-final.md:37`. | **PARTIAL**, real-phone Calendar/notification run absent, `docs/verification/EVIDENCE-23-OCT-2026.md:10`. | Server and Mock functionality do not establish device delivery. No comparable real-phone success count exists. |
| Number of automations | **23 designed**, **16 real**, **3 sandbox**, **2 stretch**, **3 roadmap** in `docs/research/07-phase6-automation-final.md:53` through `:57`. The later master plan groups work into **8** automations at `docs/plan/12-V2-MASTER-PLAN.md:91`. | Acceptance has no total “shipped automations” count and retains PARTIAL/NOT MET rows, `docs/verification/EVIDENCE-23-OCT-2026.md:10` through `:15`. | These are different groupings plus planned buckets, not comparable shipped counts. Do not announce either number as completed automations. |
| Conditional scores | Research's **8.6** “if built” average, `docs/research/10-dataset-training-verification.md:58`; master plan's **8.85** paper average, `docs/plan/12-V2-MASTER-PLAN.md:158`. | Acceptance supplies test statuses, no achieved judge score, `docs/verification/EVIDENCE-23-OCT-2026.md:6` through `:15`. | No numerical judge-score counterpart exists. The conditional scores cannot establish the team's pass thresholds or an official result. |

## Values that should not be called contradictions

| Apparent mismatch | Opened evidence | Interpretation |
|---|---|---|
| **82.1%** frontier recall versus **89.7%** matched-subset recall | `CONTEXT.md:31` has **16** prescriptions; `CONTEXT.md:32` has the same **12** for the head-to-head. Confirmed by `docs/research/10-dataset-training-verification.md:14` and `:25` through `:28`. | Different cohorts. Neither is deployed Parchi reader accuracy. Acceptance has no deployed-reader metric. |
| **26.3%** real handwriting versus **26.9%** synthetic messy subset | `CONTEXT.md:30` and `:34`; `docs/research/10-dataset-training-verification.md:7`. | Different test sets, used as a generator-difficulty check, not a claim of model improvement. |
| Rounded basket **₹1,030 / ₹826 / ₹189**, **20% / 82%** savings | `CONTEXT.md:5`; exact **₹1,030.40 / ₹826.43 / ₹189.48**, **19.8% / 81.6%**, `docs/research/06-phases-3-to-7-progress.md:15`. | Consistent rounding, with a clinically different equivalent basket requiring doctor's approval. Acceptance does not independently price this basket. |
| Rounded plan **₹2,697** and Plan B **+₹166** | `CONTEXT.md:36`; exact **₹2,696.77** and **+₹165.74**, `docs/research/06-phases-3-to-7-progress.md:44` and `:47`. | Consistent rounding. Explicit fee assumptions prevent a guaranteed live-price claim. |
| Review range **16–29%** versus exact pharmacy endpoints **15.7%** and **29.3%** | `CONTEXT.md:5`; `docs/research/02-phase2-competitors-identity.md:49`; raw endpoints `docs/research/evidence/review_themes.json:74` and `:26`. | Rounded keyword-coded complaint range. Slide 1 uses the exact **25.2%** PharmEasy share instead. |
| H1 count **≥52 entries** versus **50 salts**, plus X **16 salts** | `docs/research/08-phase7-legal-cost.md:8`; `docs/verification/EVIDENCE-23-OCT-2026.md:29`. | Legal entries and collected salt records are different units. Files do not establish a same-unit conflict or a fully complete current legal list. Do not claim one from these counts. |
| Target cities versus data coverage | `CONTEXT.md:13` names Muradnagar and Meerut. Acceptance lists **6 cities**, `docs/verification/EVIDENCE-23-OCT-2026.md:29`. | Core focus and broader data coverage differ. City data does not prove available stock, live partners or device location tests. |

## Required source excerpts

These short quotations anchor the source reading and status decisions. Quotations from plans remain plans. All research phase files were opened, and every JSON file in the evidence directory was opened and parsed without downloading or embedding patient photos.

| Opened file | Exact short excerpt | Why it matters |
|---|---|---|
| `CONTEXT.md:25` | “Sandbox orders are always labelled \"Test order\".” | Stage honesty rule. |
| `docs/plan/12-V2-MASTER-PLAN.md:159` | “If V2 is only partly built, score the parts that work.” | Conditional paper scores cannot become achieved results. |
| `docs/verification/EVIDENCE-23-OCT-2026.md:11` | “Login, add to cart and pay were never tested” | Checkout stays NOT MET. |
| `docs/team/DEMO-RUNBOOK.md:30` | “The reader model is not connected yet” | Disclose preloaded demo data. |
| `docs/team/FRONTEND-TECH-STACK.md:34` | “No sentence on screen that the code does not honour.” | Copy must reflect implementation evidence. |
| `engine/KIRO_REPORT_E5.md:16` | “Swift 182/327 = 55.7%” | Use the stricter engine result. |
| `docs/research/00-research-plan.md:13` | “The event hasn't published official weights.” | Team scale is not the event's official rubric. |
| `docs/research/01-phase1-reading-the-prescription.md:130` | “no public product found” | Bounded novelty wording. |
| `docs/research/02-phase2-competitors-identity.md:7` | “not stated on their page” | Missing competitor facts cannot become invented capabilities. |
| `docs/research/03-onpaper-ux-demo-security.md:2` | “but not built yet” | Keep old specifications distinct from acceptance. |
| `docs/research/04-technical-feasibility-problem-upgrade.md:63` | “each \"Proof\" cell passes” | Technical ambitions need their own proof. |
| `docs/research/05-files-audit-and-phase-status.md:10` | “accuracy claims have no source” | Do not revive rejected accuracy figures. |
| `docs/research/06-phases-3-to-7-progress.md:30` | “The true price is only visible at checkout” | Dated listings cannot guarantee seller totals. |
| `docs/research/07-phase6-automation-final.md:18` | “Parchi holds no money” | Payment boundary. |
| `docs/research/08-phase7-legal-cost.md:24` | “only your doctor can approve a switch” | Generic matching is not substitution authority. |
| `docs/research/09-phase8-locked-idea.md:8` | “re-routes only that item” | Failed-item recovery is the pitch's centre. |
| `docs/research/10-dataset-training-verification.md:32` | “Reading alone is not our edge over QuickPill.” | No unsupported OCR-superiority claim. |
| `docs/research/evidence/medscanner_basket_2026-10-23.json:1` | “captured 23 Oct 2026 05:10 IST” | Raw price provenance. |
| `docs/research/evidence/review_themes.json:106` | `"Delay / not delivered / cancelled": 25.2` | The opening slide's measured statistic. |
| `docs/research/evidence/mirage_janaushadhi_coverage_formaware.json:5` | `"ja_equivalent": 187` | Older heuristic result remains visible and attributable. |

## Facts intentionally left unsupported

Fullscript's capabilities and differences, a formal Parchi medical-device classification, price-liability allocation, real-chemist response rates, deployed-reader accuracy, clinical safety outcomes, current-app usability results, signed supplier agreements and measured business revenue are **NOT IN THE FILES**. The supplied brief says the event's real rubric is not public, so its internal thresholds must never appear as official judging rules.
