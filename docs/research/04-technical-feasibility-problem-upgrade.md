# Upgrade: Technical to 9, Feasibility, Problem, Novelty, Innovation (23 Oct 2026)
Same rules as before: every claim is measured [M], sourced [V] or a design choice [D]. "If built" scores hold only when each verification test passes.

---
## 1. Why Xcode on the lab iMac affects Feasibility (and how we remove the risk)
- **An iPhone app can only be built with Xcode**, plus an iOS Simulator if there's no physical iPhone.
- **Aditya's MacBook (M1, 8 GB)** has Swift 6.4 command-line tools but **no Xcode** [M]. It has **13 GB free disk** [M, `df`].
- **Xcode is about 13 GB to download** (Packt, Xcode 26), and **each iOS Simulator runtime is another 5–10 GB**; setup guides recommend 40 GB free [V]. **It won't fit on the MacBook.**
- So the **lab iMacs are the only build machines.** If they lack Xcode, or lab logins block installing it (the photo shows KIET single-sign-on screens [M]), the iOS app can't be built in the 24 hours. That single unknown costs about 0.5 on Feasibility.
- **How to remove it (10 minutes, before the event):** on a lab iMac, open About This Mac (chip, memory), then check that `xcodebuild -version` and `xcrun simctl list runtimes` work. **If yes, Feasibility gains the 0.5.**
- **Fallback if no:**
  - free about 30 GB on the MacBook (see the Mac cleanup notes) and install Xcode tonight; **or**
  - ask the lab admin.
  - The planner engine (ParchiCore) already builds and tests **without Xcode** [M], so no logic work is blocked.

---
## 2. Problem: adding the safety half (from the Parchi files + new research)
The earlier Parchi documents flagged **medicine-name confusion** (WHO look-alike/sound-alike medicines), **failed test samples** and **uncollected reports**. These are the "safety issues" left out of the price-focused framing. Newer evidence makes them strong:

| Evidence | Number | Source |
|---|---|---|
| Illegible prescriptions are now a **legal right-to-health issue** | Punjab & Haryana High Court, 27 Aug 2025: legible prescriptions are part of the **Article 21 right to health**; doctors must write in capitals until digital, **electronic prescriptions within 2 years** | [V] Medical Dialogues |
| The regulator acted | **NMC directive, 15 Dec 2025:** every medical college must form a sub-committee to **monitor prescription legibility** and generic-name use. Compliance is **mandatory** | [V] Careers360, Business Standard |
| How common bad handwriting is | Indian studies: **2–25%** of prescriptions illegible (Gujarat OPD: **24.41%** poor handwriting); **17.6–44.18%** prescription error rates reported across Indian studies | [V] PMC4963665 and others |
| Medicine-name confusion is a known safety risk | WHO look-alike/sound-alike medicines report (2023) | [V] |
| Reports and tests fall through | **8.28%** of tests uncollected in one polyclinic; **21%** of those were abnormal | [V] PubMed 42491590 |
| Price: patients can't choose | CCI: consumers "follow doctors' brand prescriptions… deters price competition"; doctor-run pharmacies push high-margin brands | [V] CCI market study |
| Price: huge markups | Cetirizine MRP ₹21.06 vs ₹2 to stockist (+953%) | [V] Parliament committee report |
| After-order failures | **16–29%** of 1–2★ pharmacy-app reviews are about delays or cancellations | [M] 9,000 Play reviews |

**The problem in one line:** *Every patient leaves the doctor with a paper parchi that may be unreadable, that the chemist may misread, that nobody prices fairly, and that nobody follows up. A court now calls legible prescriptions part of the right to health.*

**How Parchi answers the safety half:**
- **Brand–Strength Check:** "Telma 400" doesn't exist, so it can't be dispensed by mistake. Built, 16 tests [M].
- **Parchi Pass:** the chemist sees a **typed, patient-confirmed list** instead of guessing the handwriting.
- **Doctor Memory:** resolves the doctor's scrawl toward brands he actually prescribes.
- **Plan B:** covers failed samples (reroute) and lab-report tracking (Care screen).
- **Policy tailwind:** the court asked for **electronic prescriptions within 2 years**. Parchi Pass is the **patient-held digital copy** of today's paper parchi, a bridge that works now, with no doctor software.

---
## 3. Technical: the full system that earns a 9 (if built and measured)
| Layer | What we build | Model / tool / parameters | Proof |
|---|---|---|---|
| T1 Capture | VisionKit scanner + **document detection on still photos** (WhatsApp images) + on-phone blur/glare check | Apple VisionKit; Vision document segmentation | Works on the 12 real web photos |
| T2 Privacy | **On-phone blur** of name, age, phone, address and registration number; crop medicine lines only | Vision text boxes + pattern rules + header-zone rule | **Blur recall ≥95%** on the 12 web photos |
| T3 Routing | Printed → read on the phone; handwritten → our model | Apple Vision confidence + catalogue hit rate | Apple Vision ≥80% on printed [M] |
| T4 **Our reader** | Fine-tuned vision-language model | Base: Qwen2.5-VL-3B or Parrotlet-v-2.5-pro (pick by zero-shot test). LoRA r=128, α=256, lr 2e-5, warm-up 0.03, 2–3 epochs, images ≤980 px (MIRAGE recipe [V]). Data: 10–20k synthetic + 4,680 BD word crops. **Free Kaggle T4/P100** | Before/after on MIRAGE-100 (test only) |
| T5 **Catalogue-constrained reading** | The model can only output **real products**: decoding is restricted to a prefix tree of 1.18 lakh Indian brands and their real strengths | Token masking at each step (trie decoding, as in generative retrieval [V]; lexicon OCR beats lexicon-free "by a large margin" where a lexicon applies [V]) | Impossible names/strengths: **0** by construction; recall measured |
| T6 **Calibrated confidence** | Auto-accept a line only when confident, otherwise ask | Agreement across 3 samples + Brand–Strength Check + Doctor Memory prior; precision–coverage curve | **≥95% correct on auto-accepted lines** (today's simple check: 89.2% [M]) |
| T7 Data engine | Synthetic Indian prescription generator: real layouts (letterhead in regional scripts, Rx, Tab/Cap/Syp, 1-0-1, ×5 days), handwriting fonts incl. Devanagari, phone-photo + WhatsApp effects | Python + Pillow; labels automatic | Dataset card + samples |
| T8 Planner | Exact best plan across all channels, fees, minimum order, trips | Subset search + local improvement **(built)** | **16 of 16 tests pass [M]** |
| T9 Plan B | Failover for cancel / out-of-stock / late / sample rejected; approval caps; no double orders | State machine **(built)** | Tests pass [M] |
| T10 iOS-native | SwiftUI · **Share Extension** (from WhatsApp) · **App Intents / Siri** · **Live Activities + Dynamic Island** for order and lab tracking · EventKit (lab slot) · notifications (doses, refills) · Hindi speech · **MapKit local search (proven: 42 places within 10 km of KIET [M])** · Sign in with Apple | Apple frameworks | Working build |
| T11 Server on our iMac | Vapor (Swift) API + model served with MLX; **App Attest** check; TLS + pinning | mlx-vlm (supports Qwen2.5-VL, Gemma, DeepSeek-OCR [V]) | Latency ≤10 s per parchi |
| T12 Benchmarks | One command runs every test set | Our harness (exists for Apple Vision [M]) | MIRAGE-100, WhatsApp copies, 12 web photos, QuickPill + ChatGPT comparison |

**Why this is a 9 and not an 8:**
- **Our own trained model**, with **catalogue-constrained decoding** and **calibrated selective acceptance**: real ML engineering, measured.
- An **all-Swift, iOS-native** stack (Share Extension, Live Activities, App Intents, App Attest).
- A built and tested optimiser and failover engine.
- A reproducible benchmark with competitor comparisons.

**What makes it real:** each "Proof" cell passes.

---
## 4. Feasibility: primary, so every risk has an owner
| Risk | Status | Removal |
|---|---|---|
| Xcode on lab iMacs | ⚠ unknown | 10-minute check (section 1) |
| Budget | ✅ ₹0 planned (Kaggle/Colab free, Apple Maps free, no paid API) [V] | — |
| Local shop prices aren't online | ✅ designed around: **Shop Quote** (WhatsApp replies) + Parchi Pass | — |
| Online prices | ✅ public (MedScanner shows 4–6 pharmacies live, no login [M]) | — |
| Ordering access | ✅ manual hand-off by deep link (real); auto-order = labelled sandbox | — |
| Model quality | ⚠ unknown until the Kaggle run | Fallback: Apple Vision for printed + catalogue-constrained confirm screen; never blocks the flow |
| 24-hour scope | ⚠ large | **Cut order:** (1) Shop Quote, (2) Live Activities, (3) Siri, (4) LoRA training (use the zero-shot model). Never cut: read → confirm → plan → Plan B → blur |
| Engine logic | ✅ built + tested [M] | — |

---
## 5. Novelty and Innovation: the adopt-then-modify list (final)
| Idea | Adopted from (exists) | Our modification | Found in competitors? |
|---|---|---|---|
| **Catalogue-constrained reading** (new) | Trie decoding (generative retrieval); lexicon OCR | Applied to a vision-language model over **1.18 lakh Indian brands + real strengths**, so it can't output a fake medicine | Not found in searches [V, absence only] |
| Doctor Memory | WHO P-drugs | Learned per doctor from confirmed scans | Not found |
| Brand–Strength Check | Bank-cheque cross-validation | Brand ↔ strength must be a real product | Not found |
| Plan B | Payment smart routing (Juspay) | Medicines + lab slots | Not found in 15 players |
| Cost to Complete | Supply-chain total landed cost; Davaio cart total | + tests, trips, time | Partly (Davaio: medicines + delivery only) |
| Parchi Pass | ABDM Scan & Share QR | Confirmed medicine list for any chemist or lab; patient-held bridge to the court-ordered e-prescriptions | Not found |
| Shop Quote | AskIt local quotes | Automatic from the parchi, merged into the plan | Partly (AskIt) |
| Live tracking on the lock screen | Food-delivery Live Activities | Medicines + lab slot + Plan B in one Live Activity | Not found in pharmacy apps (by inspection) ⚠ |

---
## 6. Scores

| Criterion | Verified now | **If built as written** | Main proof |
|---|---|---|---|
| Problem | **8.5** (research-backed now) | **9.0** | + our measured price basket |
| Innovation | 7.5 | **8.5** | Plan B + Cost to Complete + Parchi Pass + Live Activities working |
| Novelty | 6.5 | **8.0** | Catalogue-constrained reading + head-to-head + ChatGPT test |
| Technical | 8.0 | **9.0** | Section 3 proof cells (trained model, constrained decoding, ≥95% auto-accept precision, iOS-native stack) |
| Feasibility | 7.0 | **8.0** (8.5 once Xcode is confirmed) | Xcode check + cut order + ₹0 |
| UI/UX | 6.5 | **9.0** | SUS ≥80 |
| Demo | 7.5 | **9.0** | 3 clean rehearsals |
| Security | 7.0 | **9.2** | Blur ≥95% + interception test + App Attest |
| **Average** | **7.3** | **8.7** | |

Uncertainty about ±0.5 per criterion. The event's judging weights aren't published.

Sources: Punjab & Haryana HC https://medicaldialogues.in/news/health/doctors/legible-prescriptions-a-fundamental-right-punjab-and-haryana-hc-directs-doctors-to-use-capital-letters-154332 · NMC directive https://news.careers360.com/nmc-medical-colleges-directive-sub-committee-dtc-monitor-prescription-legible-handwriting-generic-drugs-right-to-health · Business Standard https://www.business-standard.com/health/nmc-asks-medical-colleges-to-form-panels-to-track-prescription-practices-125121601291_1.html · Gujarat legibility study https://pmc.ncbi.nlm.nih.gov/articles/PMC4963665/ · Karnataka prescription errors https://ijcap.in/archive/volume/8/issue/2/article/3375 · Xcode size https://www.packtpub.com/en-ic/product/ios-26-programming-for-beginners-9781806023929 · Simulator runtimes https://mehmetbaykar.com/posts/how-to-install-simulator-runtimes-via-terminal/ · Trie decoding https://arxiv.org/pdf/2602.22647 · Lexicon OCR https://arxiv.org/pdf/1805.11161 · Post-OCR constrained decoding https://www.researchgate.net/publication/393741701_Post-OCR_Correction_Using_Large_Language_Models_with_Constrained_Decoding
