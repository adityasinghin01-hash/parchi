# Parchi: hostile judge questions

Evidence: recorded lab runs of 23 Oct 2026, updated with the latest fix reports and code; final suite counts from the 24 Oct 01:20 full run. [source: docs/verification/EVIDENCE-23-OCT-2026.md] [source: app/KIRO_REPORT_K13.md] [source: engine/KIRO_REPORT_K17.md]
There are 30 questions, as requested. [source: docs/deck/BRIEF_CODEX_C5.md:6]
Paths are relative to the repository root. Answers describe recorded evidence, not new test runs or legal certification. Newer fix reports and code take precedence over stale descriptions; plans do not upgrade acceptance.

## 1. “ChatGPT can read a prescription, what is new?”

Reading already exists. Our demonstrated contribution is medicine planning with separate lab prices, local shop replies that change the plan, and failed-item recovery with approval and durable sandbox state. Real automatic pharmacy fulfilment is not demonstrated.

**Evidence:** [source: docs/research/10-dataset-training-verification.md:32] [source: docs/verification/EVIDENCE-23-OCT-2026.md]

## 2. “Do you actually read better than QuickPill?”

We have no evidence for that. QuickPill and the frontier baseline both achieved **89.7% recall** on the same **12** prescriptions with medicines, and neither is a result from our deployed reader. The research says “Reading alone is not our edge over QuickPill”.

**Evidence:** [source: docs/research/10-dataset-training-verification.md:25] [source: docs/research/10-dataset-training-verification.md:27] [source: docs/research/10-dataset-training-verification.md:28] [source: docs/research/10-dataset-training-verification.md:32]

## 3. “Is this a medical device?”

The team's interpretation is that reading, formatting, price comparison and scheduling stay outside medical-purpose software, provided we never recommend treatment, doses or additional tests. That is a documented design interpretation, not a regulator's determination. A formal classification decision for Parchi is **NOT IN THE FILES**.

**Evidence:** [source: docs/research/08-phase7-legal-cost.md:18] [source: docs/research/08-phase7-legal-cost.md:21]

## 4. “Who is liable if the price is wrong?”

A contractual allocation of liability or compensation policy is **NOT IN THE FILES**, so we cannot promise that the seller alone is liable. Our present safeguards are dated sources, stale-price warnings and seller-controlled payment, with assumptions disclosed. Those controls do not guarantee the checkout price.

**Evidence:** [source: docs/verification/EVIDENCE-23-OCT-2026.md] [source: docs/research/06-phases-3-to-7-progress.md:23] [source: docs/team/FRONTEND-TECH-STACK.md:13]

## 5. “Why would a chemist reply to your message?”

The proposed incentive is a concrete confirmed list and pickup time from a nearby buyer. The reply mechanism works in the demo, but measured participation by real chemists and proof of that incentive are **NOT IN THE FILES**. We need a provider pilot.

**Evidence:** [source: docs/plan/12-V2-MASTER-PLAN.md:97] [source: docs/verification/EVIDENCE-23-OCT-2026.md]

## 6. “What happens when shops ignore you?”

The tested workflow asks the next **3** shops after **10 min** without a reply, using a test clock. Live reply tests cover the first complete reply winning and duplicate replies being rejected. This proves workflow behaviour, not that shops will answer.

**Evidence:** [source: docs/verification/EVIDENCE-23-OCT-2026.md]

## 7. “Does it work offline?”

Only partly verified. A saved plan reopens in Mock mode and the printed parser works on typed lines, but actual Apple Vision output and capture with Wi-Fi off were not tested. The acceptance row is PARTIAL, not complete offline prescription reading.

**Evidence:** [source: docs/verification/EVIDENCE-23-OCT-2026.md]

## 8. “What if Temporal or the iMac dies?”

The app can fall back to the local demo and perform Plan B on the phone, which the server-down UI test covers. Worker kill/restart recovery passed, and server restart preserves orders through Temporal history and SQLite. An unavailable iMac still prevents live reading and server orchestration, and a local demo reroute is not an external order.

**Evidence:** [source: docs/verification/EVIDENCE-23-OCT-2026.md] [source: docs/team/DEMO-RUNBOOK.md:22]

## 9. “What did you NOT build?”

The reader is not connected and our own training is not working yet. Real iPhone checks for scanner, Open in, WhatsApp, Calendar and notifications are not done; Checkout Assistant login/cart/pay were never tested. Hindi screens are limited to consent text, a plain translation not reviewed by a native speaker; final HTML design is due **3 am, 24 Oct**, with SwiftUI conversion after that. Recommendations and partner carts remain roadmap work.

**Evidence:** [source: docs/verification/EVIDENCE-23-OCT-2026.md] [source: app/KIRO_REPORT_K13.md] [source: docs/team/HTML-HANDOFF.md] [source: docs/plan/12-V2-MASTER-PLAN.md]

## 10. “Your acceptance table says PASS, so is the whole app tested?”

No. Final counts are **148 engine, 256 server, 86 app unit (+1 skipped measurement runner), 24 app UI and 34 Python tools**, from the full run of 24 Oct 01:20. The recorded live server Plan B loop passed **3 times in a row, 72 checks, about 19 s**, with a proposal **about 1.9 s** after judge cancel; shop/lab checks were **11/11**, privacy/delete **5/5**. These scripts and Simulator paths do not establish complete scan-to-purchase acceptance; lab/offline/privacy stay PARTIAL, checkout NOT MET and the real iPhone run NOT DONE.

**Evidence:** [source: docs/deck/NUMBERS-AUDIT.md] [source: docs/verification/EVIDENCE-23-OCT-2026.md]

## 11. “Where is the accuracy of your actual deployed model?”

There is no deployed-reader accuracy: **the reader is not connected and our own training is not working yet**. Candidates being tested are Eka **Parrotlet-v-2.5-pro** (**Apache-2.0**), a frontier vision API fallback and small OCR models. Eka's own **85.03** score is from its **1,147-page**, **five-document-type**, AI-graded test, not independent evidence; handwriting and Hindi are not broken out. A Claude baseline measured **82.1% recall / 87.3% precision on 16 real handwritten records**, a small sample, not an integrated API test.

No downloadable model has independently shown **≥80%** on messy Indian prescriptions in our repo evidence. Actual training-data size is **to be measured**; planned synthetic data, hold-out and hand copies are not completed training data. The demo parchi is built in; other parchis can be typed in.

**Evidence:** [source: docs/research/01-phase1-reading-the-prescription.md] [source: docs/research/10-dataset-training-verification.md] [source: docs/team/AI-Aditya-Singhal.md] [source: docs/team/DEMO-RUNBOOK.md] [source: docs/deck/NUMBERS-AUDIT.md]

## 12. “What if you misread a strength and someone buys the wrong medicine?”

The demo asks about **Telma 400 vs 40** instead of silently selecting a strength. The check concerns whether a catalogue product exists, not whether a dose is medically safe, and we must not substitute for the doctor's or pharmacist's judgement. A real-world clinical safety outcome is **NOT IN THE FILES**.

**Evidence:** [source: docs/team/DEMO-RUNBOOK.md:13] [source: docs/research/08-phase7-legal-cost.md:22]

## 13. “Are your cheap Jan Aushadhi matches genuinely equivalent?”

They are candidate catalogue matches shown as “Ask your doctor”, never automatic substitutions. The app's matcher found candidates for **55.7% of 327 real handwritten medicine mentions**, checking salt, strength, form, release and per-volume details; that is catalogue coverage, not clinical interchangeability. Separately, **6/6 demo medicines** had an equivalent and **103 of a sample of 200 catalogue brands** did; that sample is not real prescriptions.

**Evidence:** [source: engine/KIRO_REPORT_E5.md] [source: docs/verification/EVIDENCE-23-OCT-2026.md] [source: engine/KIRO_REPORT_K17.md]

## 14. “Does your name-blur result mean the whole prescription is private?”

No. The app **tries to hide name, age, phone and address on the phone; the user must look at the preview**. The separate tool hid **98.3%** of names on **300 synthetic parchis** and **12/12 real web photos by eye**, but phones only **46.0% (23/50)**; **7.1% (73/1,033)** of medicine lines were over-blurred. In Live mode the whole processed picture goes through our lab server to Anthropic's Claude service to be read (Anthropic's own terms apply to that copy), with no medicine crop or confidence gate; those tool scores are not an app privacy guarantee.

**Evidence:** [source: docs/research/10-dataset-training-verification.md] [source: docs/verification/CODEX-REVIEW-4-PRIVACY.md] [source: app/KIRO_REPORT_K13.md]

## 15. “Does Delete everything really delete everything immediately?”

It clears phone data and asks our server to delete; server failure must not be reported as success. Photo copies are removed **the next time the app opens after 24 hours**; random deleted-order identifiers remain **48 h**, Temporal workflow history stays up to **24 h**, and Calendar events cannot be removed by the app.

The independent Codex review found **12 problems**; most are reported fixed. The report's partly/not-fixed limits remain: finding a name label still disables the wider fallback (unmeasured); Calendar events stay; refill workflows are not cancelled; multipart uploads may temporarily spool to server disk. Backend address/key are deliberately kept. Real-device pasteboard/notification removal and observed WebKit clearing remain unverified; the preview's VoiceOver label still overstates what was hidden.

**Evidence:** [source: docs/verification/CODEX-REVIEW-4-PRIVACY.md] [source: app/KIRO_REPORT_K13.md] [source: docs/verification/EVIDENCE-23-OCT-2026.md]

## 16. “Have real patients consented to this full data flow?”

The consent gate now appears once before the first photo, with **Not now** to decline. It explains attempted masking, the user's preview check and the whole processed picture going through our lab server to Anthropic's Claude service in Live mode (consent version 2). That is an implemented gate, not evidence of consent validation with real patients; Hindi consent is a plain translation, not native-reviewed, and the real-iPhone run is still missing.

**Evidence:** [source: app/Parchi/Support/Capture/CaptureSession.swift] [source: app/Parchi/Support/Phase4/FirstRunConsentView.swift] [source: app/KIRO_REPORT_K13.md] [source: docs/verification/EVIDENCE-23-OCT-2026.md]

## 17. “How can you call prices current?”

We should call them dated snapshots. Prices show source/date and warn after **7 days**; catalogue fallback is **“Catalogue MRP · check at the shop”**, not that shop's quote. Catalogue lookup is now wired beyond the demo: **6/6 demo medicines** priced, and **175 of a sample of 200 catalogue brands** priced. Independent review's combination-strength, unit, pack-size, huge-quantity and product-salt H1/X bugs have recorded fixes; missing/unsafe matches remain unpriced, and stock or final checkout price still needs the seller.

**Evidence:** [source: docs/verification/EVIDENCE-23-OCT-2026.md] [source: docs/verification/CODEX-REVIEW-5-CATALOGUE.md] [source: engine/KIRO_REPORT_K17.md] [source: app/Parchi/Model/AppModel.swift] [source: app/KIRO_REPORT_K14.md]

## 18. “Is your cheapest complete plan a real checkout quote?”

No. **₹2,696.77** is the historical computed demo scenario for **6 medicines and 4 tests**, using dated listed prices and explicitly assumed fee rules. It is not a live checkout quote or stock guarantee; tests typed onto other parchis are shown lab by lab below the medicine plan and are not in its total. Do not carry the demo total onto a different parchi.

**Evidence:** [source: docs/research/06-phases-3-to-7-progress.md] [source: docs/team/DEMO-RUNBOOK.md] [source: app/Parchi/Screens/PlanView.swift] [source: app/Parchi/Model/AppModel.swift]

## 19. “Are your savings just a misleading generic-price comparison?”

The separate **6-medicine** listing comparison was **₹1,030.40 MRP**, **₹826.43 online** and **₹189.48** for Jan Aushadhi equivalents, an **81.6%** reduction against MRP for the equivalent basket. These are dated listed medicine totals, not matched-brand checkout totals including every fee, and the generic comparison requires the doctor's approval.

**Evidence:** [source: docs/research/06-phases-3-to-7-progress.md:9] [source: docs/research/06-phases-3-to-7-progress.md:15] [source: docs/research/06-phases-3-to-7-progress.md:22] [source: docs/research/evidence/medscanner_basket_2026-10-23.json:1]

## 20. “Can you actually reach every seller's checkout?”

No, that acceptance test is NOT MET. **11 of 13** seller pages rendered, but “Login, add to cart and pay were never tested”, and UPI hand-off is blocked. Showing a browser page is not a completed checkout.

**Evidence:** [source: docs/verification/EVIDENCE-23-OCT-2026.md]

## 21. “Are you secretly clicking Buy or handling our money?”

The rule is that the user taps Add to cart and Pay in the seller's own page. Automatic placements in our demonstration are labelled “Test order”, not purchases from an actual pharmacy. Real payment hand-off has not passed acceptance.

**Evidence:** [source: docs/team/FRONTEND-TECH-STACK.md:13] [source: docs/team/FRONTEND-TECH-STACK.md:34] [source: docs/verification/EVIDENCE-23-OCT-2026.md]

## 22. “Will you swap brands or route restricted medicines online?”

Our rules prohibit brand substitution and label **H1/X** medicines “buy in person with the original parchi”. Jan Aushadhi is price information plus “ask your doctor”. These are product boundaries, not a claim of clinical validation or regulatory certification.

**Evidence:** [source: CONTEXT.md:21] [source: CONTEXT.md:22] [source: docs/team/FRONTEND-TECH-STACK.md:33]

## 23. “What stops a retry from ordering the same medicine twice?”

The final server-suite count is **256** (full run of 24 Oct 01:20). The recorded worker kill/restart check showed exactly **2 placements** without a duplicate; idempotency checks and an audit log support that sandbox result. Seller-side duplicate protection is **NOT IN THE FILES** because partner ordering is not integrated.

**Evidence:** [source: docs/deck/NUMBERS-AUDIT.md] [source: docs/verification/EVIDENCE-23-OCT-2026.md] [source: docs/plan/12-V2-MASTER-PLAN.md]

## 24. “Will the lab slot and fasting reminder actually reach my phone?”

The server booking/reply/reminder side passed, but app Calendar and notifications were shown only in Mock and never run on a real phone. The acceptance row is PARTIAL. The independent review also leaves lab reversed-event ordering unresolved.

**Evidence:** [source: docs/verification/EVIDENCE-23-OCT-2026.md]

## 25. “Could a stale approval or rejected proposal cause the wrong reroute?”

The review records fixes for stale sheets, server refusal and proposals that reused failed or cancelled sellers. It also explicitly leaves reject-replay ambiguity, which needs a proposal identifier. We cannot claim all proposal-ordering edge cases are closed.

**Evidence:** [source: docs/verification/EVIDENCE-23-OCT-2026.md]

## 26. “Where is the polished price map and proof patients can use it?”

Plan **List | Map**, live Apple Maps shops, price pins and a shop sheet with **Call / Directions / Ask this shop** are built. Map results are searched live and not saved by Parchi, with **Map data © Apple**; catalogue MRP pins say “check at the shop”, not a shop quote, and MapKit sends the search area to Apple. The final HTML design is due **3 am, 24 Oct**, then needs SwiftUI conversion; real-device actions and measured patient usability are still unverified.

**Evidence:** [source: app/KIRO_REPORT_K14.md] [source: docs/team/HTML-HANDOFF.md] [source: docs/research/10-dataset-training-verification.md]

## 27. “Is this production-secure if your judge key is in the URL?”

No. The acceptance record explicitly leaves the judge key in the page URL for the LAN demo, and the runbook warns against sharing the address bar. Install keys, throttling and input hardening are documented, but TLS and App Attest are roadmap work rather than present production guarantees.

**Evidence:** [source: docs/verification/EVIDENCE-23-OCT-2026.md] [source: docs/team/DEMO-RUNBOOK.md:9] [source: docs/plan/12-V2-MASTER-PLAN.md:163]

## 28. “Do you have a business or just free lab hardware?”

Measured revenue, signed supplier agreements and validated production unit economics are **NOT IN THE FILES**. The legal/cost research discusses affiliate revenue as a weakly sourced possibility and labels scan-time assumptions. The free self-hosted demo does not prove a sustainable operating business.

**Evidence:** [source: docs/research/08-phase7-legal-cost.md:29] [source: docs/research/08-phase7-legal-cost.md:36] [source: docs/research/08-phase7-legal-cost.md:48]

## 29. “Do you meet the hackathon's official pass scores?”

The event's real rubric is not public. The team brief describes **7–8 criteria**, while naming **8**: problem, innovation, novelty, technical depth, feasibility, UI/UX, demo and security, with internal pass lines **≥7.5** for innovation/novelty and **≥8** for the others. These are team thresholds, not official rules or achieved scores, and incomplete acceptance prevents us from presenting conditional paper ratings as measured results.

**Evidence:** [source: docs/deck/BRIEF_CODEX_C5.md:3] [source: docs/research/00-research-plan.md:13] [source: docs/plan/12-V2-MASTER-PLAN.md:159]

## 30. “Isn't this just QuickPill, MediSaathi, Smart Bharat Lab or Fullscript?”

The required research file documents overlapping reading/comparison for QuickPill and MediSaathi, and test extraction plus multi-lab booking for Smart Bharat Lab. Our narrower demonstrated difference is medicine planning with separate lab prices, shop quotes affecting that plan and sandbox recovery after cancellation. Fullscript features, overlap and differences are **NOT IN THE FILES**, so we cannot claim superiority over it.

**Evidence:** [source: docs/research/02-phase2-competitors-identity.md:17] [source: docs/research/02-phase2-competitors-identity.md:18] [source: docs/research/02-phase2-competitors-identity.md:23] [source: docs/verification/EVIDENCE-23-OCT-2026.md]
