# PARCHI — FINAL LOCKED PLAN (23 Oct 2026, 16:00 IST)
Team TessaNova · Swift Developers Night 2.0 · 24 h · Budget ₹400 · No paid API.
Every number below is measured by us [M] or sourced [V] in files 01–10. [J] = judgement, [A] = assumption to be measured.

---
## 1. The idea (locked)
**Problem.** Every patient leaves the doctor with a paper parchi they often can't read (2–25% of Indian prescriptions illegible; the P&H High Court called legible prescriptions part of the Article 21 right to health in Aug 2025) [V]. Nobody tells them where to buy or the real price, so they pay MRP at the doctor-linked shop. The same 6-medicine basket costs **₹1,030 at MRP, ₹826 online (−20%), ₹189 at Jan Aushadhi (−82%)** [M]. After paying, **16–29% of bad pharmacy-app reviews are about late or cancelled orders** [M, 9,000 reviews].

**Solution.** Parchi, an iPhone app: share the parchi from WhatsApp (or scan it), and Parchi reads every medicine **and** test, checks each one is a real product, and builds **one plan for the whole parchi** across the nearby chemist, Jan Aushadhi, 10-minute apps, online pharmacies and labs, with the **full price up front**. One tap hands everything off; if a seller cancels, **Plan B** moves only that item.

**One line:** *"ChatGPT tells you what's written. Parchi gets the whole parchi done, at the price you'll actually pay, and stays with it until it's done."*

---
## 2. End-to-end system
```
 iPHONE (SwiftUI, free Apple account)                       LAB iMAC (16 GB, our server)            DGX A100 / Jarvis (training only)
 ┌──────────────────────────────────────────┐   crop of     ┌───────────────────────────────┐       ┌──────────────────────────────┐
 │ 1 Capture: VisionKit scanner / WhatsApp  │   medicine    │ 6 Reader: Qwen2.5-VL (our     │       │ Synthetic generator (100k)   │
 │   share extension / Photos               │   lines only  │   fine-tune, MLX 4-bit)       │◄──────│ + hand-copied real parchis   │
 │ 2 Quality check (blur/light)             │ ────────────► │ 7 JSON out → catalogue snap   │ model │ + BD word images             │
 │ 3 On-phone read (Apple Vision en+hi)     │  localhost or │   (2.46 lakh products)        │       │ LoRA on Qwen2.5-VL-7B / 3B   │
 │ 4 Name/phone BLUR (98.3% measured)       │  hotspot LAN  │ 8 Sandbox sellers + labs      │       │ Test: MIRAGE-100 + WhatsApp  │
 │ 5 Printed & confident? → done on phone   │ ◄──────────── │   (cancel button = Plan B)    │       │ copies + new-doctor set +    │
 │ 9 ParchiCore on phone: brand–strength    │   items JSON  └───────────────────────────────┘       │ hand-copied test writers     │
 │   check, doctor memory, planner, Plan B  │                                                       └──────────────────────────────┘
 │10 Confirm → Plan → Get it all → Track → Care → Parchi Pass                                        │
 └──────────────────────────────────────────┘
```
**What never leaves the phone:** the full page, the patient's name/age/phone. **What Parchi never does:** sell, hold money, swap brands, recommend tests or doses (keeps it outside medical-device and pharmacy rules, file 08).

---
## 3. Features, start to end (what it is · what exists · how ours differs)
| # | Feature | What it is | What exists today | How Parchi differs | Build |
|---|---|---|---|---|---|
| 1 | **Share from WhatsApp** | Parchi photo opens straight in Parchi | Upload buttons inside each app | Share sheet; tested: WhatsApp compression doesn't hurt reading [M] | 24 h |
| 2 | **Scanner** | Apple's document camera, auto edges | QuickPill/1mg photo upload | On-device, no login to scan | 24 h |
| 3 | **Privacy blur** | Patient name/age/phone blurred on the phone before upload | Others upload the whole photo | **98.3% of names hidden** (300 new synthetic), **12/12** real photos [M] | Built (Swift CLI) → port |
| 4 | **Smart reading** | Printed → Apple Vision on phone (offline). Handwritten → our trained model on our iMac | 1mg/PharmEasy: pharmacist reads + phones you [V]; QuickPill: cloud AI | Own model, own server, no quota, works offline for printed | Train tonight |
| 5 | **Brand–strength check** | "Telma 400" doesn't exist → "20 / 40 / 80?" | Bank cheques: words vs figures must match [V] | Applied to 2.46-lakh catalogue | **Built, tested** |
| 6 | **Doctor memory** | Learns each doctor's usual brands to break ties | WHO "P-drugs" (1994) [V] | Not found in any prescription reader [V, searches] | **Built** |
| 7 | **Confirm screen** | Only doubtful lines, with photo crop + 3 real options | QuickPill shows a % per line | Crop + real options + 1 tap | 24 h |
| 8 | **Whole-parchi plan (Cost to Complete)** | Medicines + tests + fees + trips in one number; toggles Cheapest / Fastest / No trips | Davaio: medicine cart total; LabFare: tests only | Medicines **and** tests, offline **and** online, fees counted; drip pricing is banned (CCPA 2023) and this is the fix [V] | **Engine built** (₹2,697 real basket) |
| 9 | **Jan Aushadhi card** | "Same salt costs ₹X at Jan Aushadhi, ask your doctor" | Sugam app (3.2★), search by hand | Automatic from the parchi, never swaps (swaps unlawful) [V] | 24 h (57% coverage measured) |
| 10 | **H1/X badge** | "Buy in person with the original parchi" | Drugs Rules (paper) | Automatic legal safety | 24 h |
| 11 | **Get it all** | One tap: hand-off links to each seller + lab; auto-order in labelled sandbox | Sellers' own carts | Neutral across sellers; seller does checkout (terms-safe) [V] | 24 h |
| 12 | **Plan B** | Cancel / out-of-stock / late → re-route only that item, 1 tap or auto under a cap | Juspay payment failover [V] | Not found in 15 players [V] | **Engine built** (+₹166 measured) |
| 13 | **Parchi Pass** | QR + typed list to show any chemist/lab | ABDM Scan & Share (6.64 cr tokens) [V] | Patient-held, any counter, no integration | 24 h |
| 14 | **Care** | Lab slot → Calendar, dose reminders, refill countdown | Separate reminder apps | From the same parchi, zero typing | 24 h (cut 4th) |
| 15 | **How we rank** | "Price, then time, then trips. No seller pays for position." | E-Commerce Rules 2020 + 2026 amendment require ranking disclosure [V] | Compliance as a trust feature | 24 h (static) |
| 16 | **Hindi** | Hindi UI + read-aloud of the schedule | Mostly English apps | For elderly/Hindi-first users | Cut 3rd |
| 17 | Shop Quote | WhatsApp message to 3 nearby chemists | AskIt | From the parchi | Cut 1st |
| 18 | Lock-screen tracking | Live Activity | Food apps | Medicines + lab in one | Cut 2nd |

**Never cut:** 1, 3, 4, 5, 7, 8, 11, 12. **Cut order if late:** 17 → 18 → 16 → 14.

---
## 4. Us vs competitors
| Competitor | What they do well | What they don't do | Parchi's difference |
|---|---|---|---|
| **QuickPill** | Reads handwriting at frontier level (**89.7%**, same as frontier on our 12 [M]); compares 4 online pharmacies; 60-min delivery | No tests, no nearby shops, no Jan Aushadhi, no Plan B, web only, whole photo to cloud, "quota exceeded" seen [M] | Whole parchi, offline + online, Plan B, privacy blur, own server |
| MediSaathi | Compares 7 online pharmacies, handwriting beta | Medicines only, web, login hung [M] | Same as above |
| Davaio / MedScanner | Price comparison (5–6 sellers) | Type it in; MedScanner showed an **injection** as Pan 40 tablet "best price" [M] | Reads the parchi; exact form + pack check |
| 1mg / PharmEasy / Apollo / Truemeds | Huge catalogues, delivery, labs | Only their own catalogue; pharmacist reads by hand and phones you [V]; delay/cancel = 25–29% of bad reviews [M] | Neutral across all; reads in seconds; Plan B |
| Blinkit / Zepto pharmacy | 10-minute delivery | Own stock only; fees only at checkout | One option inside our plan, fees counted |
| LabFare / Smart Bharat Lab | Compare / book lab tests | Tests only | Tests + medicines in one plan |
| Jan Aushadhi Sugam | Generic prices + store locator | Manual search, 3.2★ [M] | Automatic "ask your doctor" card |
| Eka Care (Parrotlet) | Open Indian prescription model | No buying/booking flow | Model + the whole action flow |
| ChatGPT / Claude | Reads it (82% recall, frontier) [M] | Can't order, book, track, see local prices; whole photo uploaded | Acts, tracks, re-routes, private |
| GoodRx (US) | Local pharmacy prices + coupons | Not in India, no labs | India version, medicines + labs |

---
## 5. The model (final)
- **Model:** **Qwen2.5-VL-7B-Instruct** (Alibaba, **Apache-2.0**, free for commercial use) fine-tuned with **LoRA** on the KIET DGX (1 × A100 40 GB). **Backup/fast:** Qwen2.5-VL-3B (licence is "qwen-research" = demo/research only, so not for a product) [V: Hugging Face cards].
- **In simple words:** it's an AI that already knows how to look at a picture and read text. We show it tens of thousands of Indian parchis with the right answers, so it learns *Indian doctors' handwriting and our exact output format*. Then a rules layer (catalogue + brand–strength + doctor memory) throws out anything that isn't a real Indian medicine.
- **Runs on:** the lab iMac (16 GB) with MLX in 4-bit: 7B ≈ **5.65 GB**, 3B ≈ 3.1 GB [V: file sizes]. Speed on the iMac **to be measured** [A].
- **Recipe:** LoRA rank 64, alpha 128, lr 1e-4, cosine, warm-up 3%, 1 epoch, bf16, gradient checkpointing, images ≤1024 px (MIRAGE used rank 128 / lr 2e-5 over days; we train for hours, so a higher lr) [J].
- **How much data it can take in time:** 7B ≈ 0.38 s per sample on one A100 [J, 4·params·tokens at ~100 TFLOPS] → **40k samples ≈ 4–6 h**. We measure s/step in the first 30 min and set the final size so training ends by H+10.
- **Pass/fail:** must beat the untrained model on MIRAGE-100 recall **and** stay within 2 points on the WhatsApp copies. Whichever of 7B/3B/untrained scores best on MIRAGE-100 goes on stage, with its number.
- **Honest expectation:** frontier models and QuickPill read ~82–90% [M]. Our 7B after one night's training may land below that. The confirm screen + catalogue check is what keeps the demo safe.

---
## 6. Dataset (final)
| ID | Data | Size | Where from | Licence | Use |
|---|---|---|---|---|---|
| D1 | **Synthetic parchis** (our generator) | **40k train** + 2k hold-out (new doctors) | Generated on the DGX (≈15–30 min, 120 workers) | Ours | Train |
| D2 | **Hand-copied real parchis** | Target **300–500** photos, 30–50 writers | Print/share our "copy cards", people copy them by hand, WhatsApp photo; answers known | Ours (with consent) | 70% train (oversampled ×10), **30% test by writer** |
| D3 | Bangladesh medicine-word images | 4,680 images, 78 names | data.mendeley.com/datasets/zjjtptvn6f/2 | CC BY 4.0 | Train (word reading) |
| D4 | Indian medicine catalogue | 2.54 lakh rows (2.46 lakh active) | github.com/junioralive/Indian-Medicine-Dataset (DATA/indian_medicine_data.csv) | MIT | Generator + catalogue check |
| D5 | Jan Aushadhi product list | 2,439 products | PMBI API (saved 23 Oct) | Govt | JA card |
| D6 | **MIRAGE-100** (IIT Bombay, real handwriting) | 100 parchis (81 with medicines) | huggingface.co/datasets/chaithanyakota/100-handwritten-medical-records | CC BY-ND 4.0 | **Test only** |
| D7 | MIRAGE WhatsApp copies | 2 × 100 | Made from D6 (1600 px q70, 1280 px q50) | — | Test |
| D8 | Real web photos | 12 | Saved 23 Oct (webrx-testset) | Copyrighted | Private test only |
| D9 | Fonts for the generator | 42 | Google Fonts | OFL/Apache | Generator |

**Why D2 matters most:** MIRAGE's own numbers show more data helps (medicine-name F1 6% → 29% → 49% at 10k → 100k → 528k) [V], but our gap is *real* handwriting. Hand-copied parchis give real handwriting with free answer keys, the same method IIT Bombay used with doctors.

---
## 7. Security & legal (final)
| Area | Control | Evidence |
|---|---|---|
| Patient identity | On-phone blur of name/age/phone (en + hi) before anything leaves; user can un-blur a line locally | 98.3% / 12 of 12 [M] |
| Data minimised | Only the cropped medicine area goes to **our** iMac; nothing to third-party AI | Design |
| Storage | Raw photo auto-deleted after 24 h; Delete-all; no trackers/ads | Design |
| Server access | Per-install key in Keychain + token + rate limit (App Attest needs the paid program: not used) | Apple capability table [M] |
| Transport | Simulator on the same iMac = localhost; phone via hotspot + TLS self-signed + pinning | Design |
| AI output | Must pass JSON schema + catalogue + brand–strength check before display | Built [M] |
| Consent | Itemised DPDP notice (Hindi + English) on first scan | DPDP Rules 2025 [V] |
| Medical-device line | Never recommend tests/doses; only read, compare, order, schedule | CDSCO MDSW guidance §5.2 [V] |
| Pharmacy law | No sale, no money held, no brand swap, H1/X in person | Drugs Rules, CCI [V] |
| Ranking | Public "How we rank"; no sponsored slots | E-Commerce Rules 5(3)(f), G.S.R. 789(E) [V] |

---
## 8. Scores (on paper = if built and every test passes)
| Criterion | Verified now | **On paper** | Evidence the on-paper number rests on |
|---|---|---|---|
| Problem | 8.5 | **9.0** | Measured basket, CCI, Parliament, HC Art. 21, NMC; + survey (to run) |
| Innovation | 7.5 | **8.5** | Cost to Complete + Plan B (engine built, real prices) |
| Novelty | 7.0 | **8.0** | Own dataset (synthetic + hand-copied), catalogue check, doctor memory, Plan B, whole-parchi planning; none found in 15 players |
| Technical | 8.0 | **9.0** | 7B fine-tune on DGX with before/after on real handwriting, blur measured, engine tested, iOS-native |
| Feasibility | 7.5 | **8.5** | DGX + Jarvis + iMac 16 GB confirmed; ₹0 path; cut order |
| UI/UX | 6.5 | **9.0** | Needs SUS ≥ 80 |
| Demo | 7.5 | **9.0** | Needs 3 clean rehearsals |
| Security | 7.5 | **8.8** | Blur measured; App Attest unavailable |
| **Average** | **7.5** | **8.73** | |

**Why not 8.86:** the extra 0.13 has no evidence. It becomes ≈8.84 only if (a) our model beats QuickPill on the hand-copied test (Novelty → 8.5) **and** (b) App Attest is added (Security → 9.2, needs the ₹8,700 Apple program). Real-judge calibration: the earlier diagnostic Parchi scored 21/30 = 7.0 at HackIIITD.

---
## 9. Team and the 24 hours
| Who | Owns | Doc |
|---|---|---|
| **Aditya Singh** (lead) | ParchiCore into the app, iMac server + sandbox sellers/labs + Plan B trigger, price data, deck, demo, rehearsals | this file |
| **Aditya Singhal** | All AI: data, training (DGX/Jarvis), testing, export to iMac, the reader server | team/AI-Aditya-Singhal.md |
| **Antara Gupta** | Screens: Home, Confirm, Plan, Get it all, Track/Plan B, Care, How we rank, Settings | team/Frontend-Antara-Aditya.md |
| **Aditya** | Capture + privacy: scanner, WhatsApp share, blur port, Parchi Pass, Calendar/reminders, Hindi | team/Frontend-Antara-Aditya.md |

| Hour | AI (Singhal) | Frontend (Antara + Aditya) | Lead |
|---|---|---|---|
| H0–1 | DGX setup, download models + data to Drive/DGX | Competitor teardown (45 min, see doc), Xcode project | iMac specs check, repo, ParchiCore package |
| H1–2 | Generate 40k + 2k; print/share copy cards | Home, Reading, Confirm (mock) / scanner + share ext | Scenario data, sandbox server |
| H2–3 | **Start 7B training** (log s/step); collect hand copies | Plan screen / blur port | Plan B wiring |
| H3–4 | Untrained 7B on MIRAGE-100 (baseline) | **Check 1:** share → mock read → confirm → plan | |
| H4–10 | Training runs; add hand copies at checkpoint; 3B on Jarvis if 7B is slow | Get it all, Track, Plan B sheet, Parchi Pass, Care | Integration, deck v1 |
| H10–12 | Test trained model on all sets; merge → MLX on iMac | **Check 2:** real photo → iMac read → plan → sandbox order → Plan B | |
| H12–15 | iMac server latency; fix | Hindi, accessibility; **bug bash; freeze at H15** | Demo script |
| H15–21 | Final numbers into the app's "How accurate" screen | 3 rehearsals (one offline, one with failure) | Deck numbers from measured files only |
| H21–24 | Buffer | Buffer, backup recording, submit | Submit |
