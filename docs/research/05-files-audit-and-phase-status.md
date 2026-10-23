# Every Parchi file on the Mac: what's in it, what we use, what we left out (audit 23 Oct 2026)

## A. Downloads (all read in full)
| File | What's in it | Used in the current plan | Left out | Useful? |
|---|---|---|---|---|
| Parchi_Final_Claude_Handoff.pdf (20 pp, 23 Oct) | Latest decision record: diagnostics-first, 4 screens, exactness/pricing rules, durable execution, security threat model, acceptance tests, honest ratings (avg 8.0 claimed) | Exactness rules (integer paise, unknown ≠ zero, fee counted once), versioned approval, uncertain-order reconciliation, MASVS/OWASP thinking, demo honesty labels | The **diagnostics-only hero** (we moved to the whole parchi); PostgreSQL/Android web client (too heavy for 24 h); its 8.0 ratings (unbacked) | **Yes.** Keep the rules and acceptance tests (A01–A10, S01–S07, M01–M09) as our test list |
| Parchi_Complete_Work_Plan.pdf (10 pp) | Teammate's plan: P0/P1/P2, 7 screens, WP1–WP6, research tasks R1–R7, 24-h board, allowed stage wording | Source-crop correction, Backup Card → **Plan B**, typed medicine/test identity, "Allowed on stage" wording | 7 forced screens (we use 4–7 by need), medicine as P1 only | **Yes.** R1 (patient interviews) and R7 (claim ledger) are still needed |
| Parchi_Final_Idea.pdf (8 pp, 22 Oct) | Follow-up Ready Plan: diagnostics, Backup Card, one next action, Swift package layout, API contract, Swift test list | ParchiCore layout (built), Backup Card idea, "one next action", accessibility rules | Follow-up-date-only framing | **Yes.** Its Swift test list merged into ours |
| Parchi_Final_Research_and_System_Blueprint.pdf (29 pp) | Medicines-first blueprint: competitor teardown (Davaio, MediSaathi, AskIt, Farmako, SmartSpend, 1mg, Truemeds…), payable-now maths, offers/eligibility, bounded agent, DPDP staging, dataset audit, 3–4 h AI window | Basket maths (payable = items + fees − eligible discounts; cashback never reduces payable), **card/offer eligibility** concept, AskIt (→ Shop Quote), Farmako, DPDP | **Card/coupon optimisation** (SmartSpend, Card Juggler): not used yet; **JanDawa foil reading**: dropped | **Partly.** Card/coupon offers could raise Innovation later (a P2 note) |
| Parchi_Module_2_AI_OCR_Datasets_Training.pdf (3 pp) | Inflated AI stack (5 models, "89–92%", "0% hallucination", BD dataset "17,431 / 480 classes") | Nothing as-is | All numbers | **No.** Proved wrong: BD set is 4,680 images / 78 names; accuracy claims have no source |
| Parchi_iOS_Developers_Night_2026_Final.pptx (9 slides) | Diagnostics deck: problem (8.28% uncollected, 43.4% out-of-pocket), journey, architecture (Swift + Vapor + Supabase), team roles | Team roles, 8.28% / 43.4% facts, honesty footers | Supabase dependency (not needed) | **Yes,** for facts and roles |
| PARCHI_JANDAWA_TessaNova_Developers_Night_2_Final.pptx (13 slides) | Parchi Care + **JanDawa AR** (foil scanning, PMBI catalogue, pharmacist gate), 16-h build | Pharmacist gate idea, "admit what it can't read" judge test | **JanDawa foil AR**: dropped (no benchmark, extra risk) | **Partly.** Its line "Best judge test: change the image, the app must admit what it can't read" is worth keeping in the demo |
| WhatsApp Image (01:51) | Two KIET lab iMacs (24-inch, Apple Silicon) | Build machines | — | Yes (Aditya confirms good specs) |

## B. Desktop and Documents (earlier Parchi version for HackIIITD, found during this audit)
| File | What's in it | Why it matters |
|---|---|---|
| Desktop/HackIIITD-deck/Parchi-TessaNova-HackIIITD-2026.pdf/.pptx (9 slides) | The **diagnostic Parchi** submitted to HackIIITD on 16 Oct | **Real judges scored it 21/30 (= 7.0/10); cutoff 25, top 29** (memory: sentinelward-unstop-hackathons). This is our only real judge calibration, and our verified 7.3 matches it |
| Same deck, slide 2 | Lab-price evidence: same thyroid test **₹340 in Chennai vs ₹560 in Kolkata** (Dr Lal PathLabs); **Free T3/T4 ≠ Total T3/T4** naming trap; night home visit **₹450 + 1.5× test rates** (Kokilaben); report times **36 h vs 6 h** (Orange Health) | **Re-use** for the lab half of the problem (to re-verify the pages) |
| Parchi-test-report.pdf | 132 automatic deck checks passed; **judge rounds, comprehension tests and persona tests were NOT run** | Lesson: run the judge-style tests this time |
| Memory note (16 Oct) | Codex judges' **unfixable gaps on that deck: no patient interviews, no live lab access, no tested end-to-end case, novelty not proven** | **These 4 gaps are exactly what we must close now** (see C) |
| Documents/HackIIITD-2026/ (master plan, 14 blueprint files, reports) | OCR decision (PaddleOCR v5 local), minimal-input journey, security/cost, TinyFish capability and budget report, idea review | PaddleOCR = another **free baseline** to measure alongside Apple Vision; TinyFish web agent = possible engine for Shop Quote / price fetching (no patient data); idea review = judging-rubric thinking |
| Desktop/HackIIITD-deck/Assessment Engine.pdf | Infosys Spring Boot quiz result | **Not Parchi.** Ignore |

## C. The 4 gaps that cost HackIIITD points, and our fix for each
| Gap (16 Oct) | Fix now | Status |
|---|---|---|
| No patient interviews | 10–20 person survey + 5–8 person usability test (needs Aditya and team) | ⚠ to do |
| No live lab/provider access | Real public prices (MedScanner, lab price pages), real nearby places (Apple Maps, done), Shop Quote via WhatsApp, Parchi Pass | ◐ partly done |
| No tested end-to-end case | ParchiCore engine built, 16 tests pass; full app on hackathon day | ◐ partly done |
| Novelty not proven | Head-to-head vs QuickPill (2 printed done; handwritten blocked by their quota), ChatGPT test, catalogue-constrained reading | ◐ partly done |

---
# Research phase status (honest)
| Phase | Status | Done | Missing |
|---|---|---|---|
| 1 Reading the prescription | ✅ Done | Apple Vision 26% vs frontier 82% (measured), datasets, models, costs, training plan, compression test, printed/handwritten split, accuracy ceiling | PaddleOCR baseline (optional) |
| 2 Competitors and identity | ✅ Done | 15 players, 9,000 reviews, identity, adopt→modify, ChatGPT/Claude differentiation | QuickPill handwriting head-to-head (blocked by their quota), MediSaathi (login hangs) |
| 3 Text → exact item | ◐ Partial | Catalogue coverage 79% measured; Brand–Strength Check built | Jan Aushadhi + same-salt mapping, test-name standard (Free vs Total T3/T4), filling the over-the-counter/supplement catalogue gap |
| 4 Nearby places | ◐ Partial | Apple Maps: 42 places within 10 km of KIET, 27 within 3 km in Ghaziabad | OpenStreetMap (server failed), NABL accredited-lab list, Jan Aushadhi store list, Google Places free-tier check |
| 5 Prices (MRP vs checkout) | ◐ Started | Source found (MedScanner, live, no login); Dolo 650 measured | Full basket, Jan Aushadhi prices, lab prices, delivery-fee rules, Blinkit fees (Aditya) |
| 6 Automation: order/book/pay | ❌ Not done | Plan B designed and built | Deep links, partner APIs, UPI hand-off, lab booking, TinyFish option, automation count |
| 7 AI list, Swift architecture, security, legal | ◐ Mostly | Architecture, security (MASVS, DPDP, STRIDE), technical-9 plan on paper | Legal: e-pharmacy rules status, Drugs Rules (Schedule H/H1/X), telemedicine; cost per user |
| 8 Final synthesis (lock the idea) | ❌ Not done | — | Personas, need→why, final feature cut for 24 h, final scores |
| After lock: own dataset + Kaggle training/test | ❌ Not started | Plan + benchmark harness ready | Generator, data, training, measured results |

**In short:** phases 1–2 done; 3, 4, 5 and 7 partly done; 6 and 8 not done; dataset and training not started.
