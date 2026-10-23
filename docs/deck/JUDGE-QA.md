# Parchi: hostile judge questions

Evidence snapshot: 23 Oct 2026. [source: docs/verification/EVIDENCE-23-OCT-2026.md:1]
There are 30 questions, as requested. [source: docs/deck/BRIEF_CODEX_C5.md:6]
Paths are relative to the repository root. Answers describe the supplied evidence snapshot, not fresh test runs or legal certification. A plan or research claim cannot upgrade a PARTIAL, NOT MET or NOT DONE acceptance row.

## 1. “ChatGPT can read a prescription, what is new?”

Reading already exists. Our demonstrated contribution is the whole-prescription planner, local shop replies that change the plan, and failed-item recovery with approval and durable sandbox state. Real automatic pharmacy fulfilment is not demonstrated.

**Evidence:** [source: docs/research/10-dataset-training-verification.md:32] [source: docs/verification/EVIDENCE-23-OCT-2026.md:8] [source: docs/verification/EVIDENCE-23-OCT-2026.md:24]

## 2. “Do you actually read better than QuickPill?”

We have no evidence for that. QuickPill and the frontier baseline both achieved **89.7% recall** on the same **12** prescriptions with medicines, and neither is a result from our deployed reader. The research says “Reading alone is not our edge over QuickPill”.

**Evidence:** [source: docs/research/10-dataset-training-verification.md:25] [source: docs/research/10-dataset-training-verification.md:27] [source: docs/research/10-dataset-training-verification.md:28] [source: docs/research/10-dataset-training-verification.md:32]

## 3. “Is this a medical device?”

The team's interpretation is that reading, formatting, price comparison and scheduling stay outside medical-purpose software, provided we never recommend treatment, doses or additional tests. That is a documented design interpretation, not a regulator's determination. A formal classification decision for Parchi is **NOT IN THE FILES**.

**Evidence:** [source: docs/research/08-phase7-legal-cost.md:18] [source: docs/research/08-phase7-legal-cost.md:21]

## 4. “Who is liable if the price is wrong?”

A contractual allocation of liability or compensation policy is **NOT IN THE FILES**, so we cannot promise that the seller alone is liable. Our present safeguards are dated sources, stale-price warnings and seller-controlled payment, with assumptions disclosed. Those controls do not guarantee the checkout price.

**Evidence:** [source: docs/verification/EVIDENCE-23-OCT-2026.md:14] [source: docs/research/06-phases-3-to-7-progress.md:23] [source: docs/team/FRONTEND-TECH-STACK.md:13]

## 5. “Why would a chemist reply to your message?”

The proposed incentive is a concrete confirmed list and pickup time from a nearby buyer. The reply mechanism works in the demo, but measured participation by real chemists and proof of that incentive are **NOT IN THE FILES**. We need a provider pilot.

**Evidence:** [source: docs/plan/12-V2-MASTER-PLAN.md:97] [source: docs/verification/EVIDENCE-23-OCT-2026.md:9]

## 6. “What happens when shops ignore you?”

The tested workflow asks the next **3** shops after **10 min** without a reply, using a test clock. Live reply tests cover the first complete reply winning and duplicate replies being rejected. This proves workflow behaviour, not that shops will answer.

**Evidence:** [source: docs/verification/EVIDENCE-23-OCT-2026.md:9]

## 7. “Does it work offline?”

Only partly verified. A saved plan reopens in Mock mode and the printed parser works on typed lines, but actual Apple Vision output and capture with Wi-Fi off were not tested. The acceptance row is PARTIAL, not complete offline prescription reading.

**Evidence:** [source: docs/verification/EVIDENCE-23-OCT-2026.md:12]

## 8. “What if Temporal or the iMac dies?”

The app can fall back to the local demo and perform Plan B on the phone, which the server-down UI test covers. Worker kill/restart recovery passed, and server restart preserves orders through Temporal history and SQLite. An unavailable iMac still prevents live reading and server orchestration, and a local demo reroute is not an external order.

**Evidence:** [source: docs/verification/EVIDENCE-23-OCT-2026.md:18] [source: docs/verification/EVIDENCE-23-OCT-2026.md:19] [source: docs/team/DEMO-RUNBOOK.md:22]

## 9. “What did you NOT build?”

The reader is not connected, camera/scanner and WhatsApp share are not built, consent is unmounted, and general catalogue MRP wiring remains unfinished. Real login/cart/payment and a real-iPhone run are untested. Recommendation and automatic carts through partner APIs are roadmap work.

**Evidence:** [source: docs/team/DEMO-RUNBOOK.md:30] [source: docs/verification/EVIDENCE-23-OCT-2026.md:11] [source: docs/verification/EVIDENCE-23-OCT-2026.md:13] [source: docs/verification/EVIDENCE-23-OCT-2026.md:15] [source: docs/plan/12-V2-MASTER-PLAN.md:163]

## 10. “Your acceptance table says PASS, so is the whole app tested?”

No. The real-tap cancellation test passed **3/3** Simulator runs, but it starts at Track and explicitly excludes “share -> confirm -> plan” taps. The table also retains PARTIAL lab/offline/privacy rows and NOT MET checkout.

**Evidence:** [source: docs/verification/EVIDENCE-23-OCT-2026.md:8] [source: docs/verification/EVIDENCE-23-OCT-2026.md:10] [source: docs/verification/EVIDENCE-23-OCT-2026.md:11] [source: docs/verification/EVIDENCE-23-OCT-2026.md:12] [source: docs/verification/EVIDENCE-23-OCT-2026.md:13]

## 11. “Where is the accuracy of your actual deployed model?”

It is **NOT IN THE FILES** because the reader is not connected. The context's phrase “our fine-tuned” describes the intended system, and baseline or competitor results cannot establish production reader accuracy. We disclose the demo-data fallback.

**Evidence:** [source: CONTEXT.md:17] [source: docs/team/DEMO-RUNBOOK.md:12] [source: docs/team/DEMO-RUNBOOK.md:30]

## 12. “What if you misread a strength and someone buys the wrong medicine?”

The demo asks about **Telma 400 vs 40** instead of silently selecting a strength. The check concerns whether a catalogue product exists, not whether a dose is medically safe, and we must not substitute for the doctor's or pharmacist's judgement. A real-world clinical safety outcome is **NOT IN THE FILES**.

**Evidence:** [source: docs/team/DEMO-RUNBOOK.md:13] [source: docs/research/08-phase7-legal-cost.md:22]

## 13. “Are your cheap Jan Aushadhi matches genuinely equivalent?”

They are candidate catalogue matches shown as “Ask your doctor”, never automatic substitutions. The stricter Swift matcher reports **182/327 = 55.7%** of medicine mentions, checking salt, strength, form, release and per-volume details. It needs a salt input rather than resolving every brand itself, and its coverage does not establish clinical interchangeability.

**Evidence:** [source: engine/KIRO_REPORT_E5.md:12] [source: engine/KIRO_REPORT_E5.md:16] [source: engine/KIRO_REPORT_E5.md:20] [source: docs/verification/EVIDENCE-23-OCT-2026.md:31]

## 14. “Does your name-blur result mean the whole prescription is private?”

No. The separate tool hid **98.3%** of patient names on **300** synthetic images, while phone masking reached only **46.0% (23/50)** and it mistakenly blurred **7.1% (73/1,033)** of medicine lines. The app has only the limited Simulator evidence recorded in the PARTIAL privacy row.

**Evidence:** [source: docs/research/10-dataset-training-verification.md:40] [source: docs/verification/EVIDENCE-23-OCT-2026.md:13]

## 15. “Does Delete everything really delete everything immediately?”

It clears the working database and the app action was checked against the server, but the label needs the retention exceptions stated clearly. Random deleted-order identifiers remain for **48 h**, and Temporal keeps item/price/seller workflow history for **24 h**. We cannot describe this as immediate erasure of all retained state.

**Evidence:** [source: docs/verification/EVIDENCE-23-OCT-2026.md:13] [source: docs/team/DEMO-RUNBOOK.md:33]

## 16. “Have real patients consented to this full data flow?”

Completed consent validation is **NOT IN THE FILES**. The first-run consent screen is unmounted, and in-app blur was demonstrated on only **2 synthetic** Simulator samples. The privacy acceptance row remains PARTIAL, and the context reserves public prescription images for testing.

**Evidence:** [source: docs/verification/EVIDENCE-23-OCT-2026.md:13] [source: CONTEXT.md:24]

## 17. “How can you call prices current?”

We should call them dated snapshots. Bundled prices show source and date, with a warning after **7 days**, and the acceptance result covers bundled data rather than continuous live seller pricing. Freshness and stock still need seller confirmation.

**Evidence:** [source: docs/verification/EVIDENCE-23-OCT-2026.md:14] [source: docs/research/07-phase6-automation-final.md:65]

## 18. “Is your cheapest complete plan a real checkout quote?”

No. **₹2,696.77** is the computed scenario for **6 medicines and 4 tests**, using real listed prices with some fee rules explicitly marked as assumptions. It demonstrates planner arithmetic for those inputs, not a guaranteed payable total or live stock.

**Evidence:** [source: docs/research/06-phases-3-to-7-progress.md:43] [source: docs/research/06-phases-3-to-7-progress.md:44] [source: docs/verification/EVIDENCE-23-OCT-2026.md:11]

## 19. “Are your savings just a misleading generic-price comparison?”

The separate **6-medicine** listing comparison was **₹1,030.40 MRP**, **₹826.43 online** and **₹189.48** for Jan Aushadhi equivalents, an **81.6%** reduction against MRP for the equivalent basket. These are dated listed medicine totals, not matched-brand checkout totals including every fee, and the generic comparison requires the doctor's approval.

**Evidence:** [source: docs/research/06-phases-3-to-7-progress.md:9] [source: docs/research/06-phases-3-to-7-progress.md:15] [source: docs/research/06-phases-3-to-7-progress.md:22] [source: docs/research/evidence/medscanner_basket_2026-10-23.json:1]

## 20. “Can you actually reach every seller's checkout?”

No, that acceptance test is NOT MET. **11 of 13** seller pages rendered, but “Login, add to cart and pay were never tested”, and UPI hand-off is blocked. Showing a browser page is not a completed checkout.

**Evidence:** [source: docs/verification/EVIDENCE-23-OCT-2026.md:11]

## 21. “Are you secretly clicking Buy or handling our money?”

The rule is that the user taps Add to cart and Pay in the seller's own page. Automatic placements in our demonstration are labelled “Test order”, not purchases from an actual pharmacy. Real payment hand-off has not passed acceptance.

**Evidence:** [source: docs/team/FRONTEND-TECH-STACK.md:13] [source: docs/team/FRONTEND-TECH-STACK.md:34] [source: docs/verification/EVIDENCE-23-OCT-2026.md:11]

## 22. “Will you swap brands or route restricted medicines online?”

Our rules prohibit brand substitution and label **H1/X** medicines “buy in person with the original parchi”. Jan Aushadhi is price information plus “ask your doctor”. These are product boundaries, not a claim of clinical validation or regulatory certification.

**Evidence:** [source: CONTEXT.md:21] [source: CONTEXT.md:22] [source: docs/team/FRONTEND-TECH-STACK.md:33]

## 23. “What stops a retry from ordering the same medicine twice?”

The recorded orchestrator suite has **184 tests**, and a worker kill/restart test recorded exactly **2 placements** without a duplicate. Idempotency checks and an audit log support that sandbox result. Actual seller-side duplicate protection is **NOT IN THE FILES** because partner ordering is not integrated.

**Evidence:** [source: docs/verification/EVIDENCE-23-OCT-2026.md:7] [source: docs/verification/EVIDENCE-23-OCT-2026.md:27] [source: docs/plan/12-V2-MASTER-PLAN.md:163]

## 24. “Will the lab slot and fasting reminder actually reach my phone?”

The server booking/reply/reminder side passed, but app Calendar and notifications were shown only in Mock and never run on a real phone. The acceptance row is PARTIAL. The independent review also leaves lab reversed-event ordering unresolved.

**Evidence:** [source: docs/verification/EVIDENCE-23-OCT-2026.md:10] [source: docs/verification/EVIDENCE-23-OCT-2026.md:24]

## 25. “Could a stale approval or rejected proposal cause the wrong reroute?”

The review records fixes for stale sheets, server refusal and proposals that reused failed or cancelled sellers. It also explicitly leaves reject-replay ambiguity, which needs a proposal identifier. We cannot claim all proposal-ordering edge cases are closed.

**Evidence:** [source: docs/verification/EVIDENCE-23-OCT-2026.md:23] [source: docs/verification/EVIDENCE-23-OCT-2026.md:24]

## 26. “Where is the polished price map and proof patients can use it?”

The frontend stack still describes Plan's List/Map as work to build, so MapKit in the stack does not establish a finished price map. The usability document is a kit, not completed patient results. A measured usability outcome for the current app is **NOT IN THE FILES**.

**Evidence:** [source: docs/team/FRONTEND-TECH-STACK.md:28] [source: docs/team/FRONTEND-TECH-STACK.md:62] [source: docs/research/10-dataset-training-verification.md:46]

## 27. “Is this production-secure if your judge key is in the URL?”

No. The acceptance record explicitly leaves the judge key in the page URL for the LAN demo, and the runbook warns against sharing the address bar. Install keys, throttling and input hardening are documented, but TLS and App Attest are roadmap work rather than present production guarantees.

**Evidence:** [source: docs/verification/EVIDENCE-23-OCT-2026.md:27] [source: docs/team/DEMO-RUNBOOK.md:9] [source: docs/plan/12-V2-MASTER-PLAN.md:163]

## 28. “Do you have a business or just free lab hardware?”

Measured revenue, signed supplier agreements and validated production unit economics are **NOT IN THE FILES**. The legal/cost research discusses affiliate revenue as a weakly sourced possibility and labels scan-time assumptions. The free self-hosted demo does not prove a sustainable operating business.

**Evidence:** [source: docs/research/08-phase7-legal-cost.md:29] [source: docs/research/08-phase7-legal-cost.md:36] [source: docs/research/08-phase7-legal-cost.md:48]

## 29. “Do you meet the hackathon's official pass scores?”

The event's real rubric is not public. The team brief describes **7–8 criteria**, while naming **8**: problem, innovation, novelty, technical depth, feasibility, UI/UX, demo and security, with internal pass lines **≥7.5** for innovation/novelty and **≥8** for the others. These are team thresholds, not official rules or achieved scores, and incomplete acceptance prevents us from presenting conditional paper ratings as measured results.

**Evidence:** [source: docs/deck/BRIEF_CODEX_C5.md:3] [source: docs/research/00-research-plan.md:13] [source: docs/plan/12-V2-MASTER-PLAN.md:159]

## 30. “Isn't this just QuickPill, MediSaathi, Smart Bharat Lab or Fullscript?”

The required research file documents overlapping reading/comparison for QuickPill and MediSaathi, and test extraction plus multi-lab booking for Smart Bharat Lab. Our narrower demonstrated difference is combined planning, shop quotes affecting that plan and sandbox recovery after cancellation. Fullscript features, overlap and differences are **NOT IN THE FILES**, so we cannot claim superiority over it.

**Evidence:** [source: docs/research/02-phase2-competitors-identity.md:17] [source: docs/research/02-phase2-competitors-identity.md:18] [source: docs/research/02-phase2-competitors-identity.md:23] [source: docs/verification/EVIDENCE-23-OCT-2026.md:24]
