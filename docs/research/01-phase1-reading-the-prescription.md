# Phase 1: Reading the prescription (23 Oct 2026)

Labels used below: **[M]** I measured it myself today, **[V]** checked in the primary source, **[J]** my judgement.

## 1. How existing players read a prescription

| Player | How they read it | Evidence |
|---|---|---|
| Tata 1mg | **Pharmacists check it by hand**: registered doctor, expiry, quantity. Then it goes to a partner pharmacy. The original must be shown at delivery | 1mg FAQ [V] |
| PharmEasy | Upload, then **the partner retailer phones you to confirm**. If the prescription lists salts, a pharmacist calls you about substitutes | PharmEasy order steps [V] |
| Google Lens "doctor handwriting" | Announced Dec 2022 as a **research prototype** to help pharmacists. No launch has been found | 9to5Google, BGR [V] |
| Smart Bharat Lab | "Our AI reads the tests" (tests only, not medicines) | Website [V] |
| Eka Care | Their own open model, Parrotlet-v-2.5-pro | Hugging Face model page [V] |

**What this means [J]:** the big apps still read prescriptions with a human pharmacist and a phone call. The AI readers out there are either unreleased (Google), tests-only (Smart Bharat), or a model with no consumer flow around it (Eka).

## 2. What I measured on 100 real Indian handwritten prescriptions [M]

- **Dataset:** MIRAGE-100, the public part of IIT Bombay's MIRAGE work (`chaithanyakota/100-handwritten-medical-records`, licence CC BY-ND 4.0).
- **Coverage:** 81 of the prescriptions list medicines, with 323 medicine names in total.
- **Scoring:** a medicine counts as found if its brand name was read correctly.

| Method | Prescriptions | Found (recall) | Correct when named (precision) | F1 | Every medicine found |
|---|---|---|---|---|---|
| Apple Vision, as read | 81 | **26.3%** | 12.8% | 17.2% | 3 / 81 |
| Apple Vision + match each word to the brand list | 81 | 34.1% | 11.3% | 17.0% | 7 / 81 |
| Apple Vision + match only words after "Tab/Cap/Syp" or before a real strength | 81 | 17.0% | 54.5% | 25.9% | 1 / 81 |
| **Frontier vision model (Claude Opus 5.5), read without seeing answers** | 16 | **82.1%** | **87.3%** | **84.7%** | 9 / 16 |
| Apple Vision on the same 16 | 16 | 28.6% | 14.9% | 19.6% | 1 / 16 |

- **Speed:** Apple Vision took 84.7 s for 100 images on an M1 MacBook Air, about 0.85 s per image [M].
- **No false medicines on blank prescriptions:** the frontier model correctly listed nothing on all 4 prescriptions that had no medicines [M].
- **Brand list coverage:** a 2.5-lakh medicine catalogue (MIT licence, prices as of Nov 2022) contains only **79.4%** of the brands prescribed (82.9% of mentions). Missing ones include Shelcal, Becosules, Zincovit, Gaviscon and Enterogermina, mostly supplements and over-the-counter products [M].
- **Matching against the brand list fixed 3 of the 11 names the model got wrong.** 5 of those 11 brands aren't in the catalogue at all [M].
- **Limits of this test:**
  - Only 16 prescriptions for the frontier model.
  - The reader was me, not a tuned API call.
  - Some answer lists are incomplete. For example, Betadine gargle isn't labelled on rx013, so a few of the "wrong" names may actually be right.

## 3. Published results (different setups, so not directly comparable)

| Work | Result | Status |
|---|---|---|
| MIRAGE, 2024 (743,118 simulated prescriptions handwritten by 1,133 doctors) | Without training: LLaVA 1.6 **2.0%**, Gemini 1.5 Pro **5.53%**, GPT-4o **7.57%** F1. Their trained model: **82%** on medicine names and doses | [V] arXiv 2410.09729 |
| MIRAGE training settings | LoRA rank 128, alpha 256, learning rate 2e-5, warm-up 0.03; LLaVA trained on 7 A6000 GPUs for 3.5 days; Idefics2 on 6 A6000s for 13 days | [V] |
| Earlier word-list method | 74.13% accuracy with a 520-word list | [V] cited in MIRAGE |
| Eka Parrotlet-v-2.5-pro (based on Gemma-4-E2B; 6B total, about 2B active parameters) | Prescription score **85.03** vs Gemini 3.6 Flash 84.06, on their own 1,147-page test set graded by an AI. Untrained base model: 46.17 | [V] Hugging Face page. **Their own test, not independent** |
| RxVLM, 2026 | 91.43% on the Bangladesh 78-name word-image set | [V] Springer abstract |

**Correction to Parchi_Module_2.pdf:**
- The Bangladesh dataset is **4,680 images across 78 names**, not "17,431 / 480".
- Its claims of "89–92% verified match" and "0% silent hallucination" have **no source**. Drop them.

## 4. Datasets

| ID | Dataset | Size | Licence | Indian? | Use |
|---|---|---|---|---|---|
| D1 | MIRAGE-100 | 100 full prescriptions | CC BY-ND 4.0 | Yes | **Testing only** (the licence bars derivative works) |
| D2 | Doctor's Handwritten Prescription BD | 4,680 word images, 78 names, 128×128 | CC BY 4.0 (description says research use only) | Bangladesh | Training word-level reading |
| D3 | Indian Medicine Dataset (2,53,973 rows) | 2.46 lakh active products, 1.18 lakh brands | MIT on GitHub (data likely scraped; where it came from is unclear) | Yes | Brand list and strength cross-check |
| D4 | Jan Aushadhi product list | about 2,110 medicines | Government website | Yes | Generic matches (phase 3) |
| D5 | Eka medical-records test set | 288 documents | Gated | Yes | External test |
| D6 | **Our own synthetic set** | Target 20,000 images | Ours | Yes | Training: brand names from D3 written into prescription templates in handwriting styles (MIRAGE showed simulated data works) |
| D7 | **Our own set grown from user confirmations** | Grows with use | Ours, with consent | Yes | Real handwriting over time |

## 5. Models

| ID | Model | Size | Licence | Runs on | Role |
|---|---|---|---|---|---|
| A1 | Apple Vision text recognition | Built into iOS | Free | iPhone, offline | Finds text lines and boxes so we can show the source crop. **Not for reading names (26%)** |
| A2 | Claude Haiku 5.5 / Sonnet 5.5 / Opus 5.5 | API | Paid per use | Cloud | Main reader. Opus measured at 82% recall; Haiku and Sonnet **not tested yet** |
| A3 | Eka Parrotlet-v-2.5-pro | 6B total (~2B active), ~11 GB, ~10.7 GB GPU memory | Apache-2.0, not gated | GPU (Jarvis Labs) | Open, India-specific reader; base for our training |
| A4 | Qwen2.5-VL / Qwen3-VL | 3B to 8B | Apache-2.0 (check each size) | GPU or Mac | Backup base model for training |
| A5 | Our cross-check engine (rules, no AI) | — | Ours | iPhone and server | Snaps each name to the brand list, checks the strength is a real product, applies the doctor's usual list |

## 6. Cost per scan (1500×1500 photo) [V for prices and token formula, J for usage]

- **Image tokens:** ⌈1500/28⌉ × ⌈1500/28⌉ = **2,916**. Shrinking the photo to 1,092 px brings that down to 1,521.
- **Assumed per scan:** about 3,300 input tokens and about 600 output tokens.

| Model | Price (input/output per 1M tokens) | Cost per scan |
|---|---|---|
| Haiku 5.5 | $0.10 / $0.50 | **≈ $0.0006** (about 5 paise) |
| Sonnet 5.5 | $2 / $10 | ≈ $0.013 (about ₹1.1) |
| Opus 5.5 | $4 / $20 | ≈ $0.025 (about ₹2.2) |

₹ figures assume ₹88 = $1 (not verified).

## 7. Training our own model: plan and honest verdict

- **Base:** Parrotlet-v-2.5-pro, since it's already trained on Indian prescriptions. Backup: Qwen2.5-VL-7B.
- **Method:** LoRA rank 128, alpha 256, learning rate 2e-5, warm-up 0.03, cosine schedule, 3 epochs, images up to 980 px. These settings come from MIRAGE.
- **Data:**
  - D6 synthetic: 20,000 images
  - D2 word images: 4,680
  - Testing on D1 only, never trained on
- **Compute:**
  - Jarvis Labs A100 80GB at $1.49/hour, or H100 at $2.69/hour [V].
  - A 3–4 hour window costs **about $6–11**.
  - MIRAGE needed days on 6–7 GPUs with 5 lakh real records. We won't come close to that in 4 hours [J].
- **Verdict [J]:**
  - Training our own reader is **not needed for the demo**: a frontier model reading cold already gets 82%.
  - The make-or-break piece we build ourselves is **the cross-check layer plus the doctor memory** (A5). It needs no GPU and fixes the errors that matter most.
  - Train the LoRA on Jarvis Labs only as a measured experiment: before and after numbers on D1.

## 8. Techniques borrowed from other fields (each checked to exist in its own field)

1. **Bank-cheque cross-check:**
   - Banks read the amount written in words and the amount written in figures, and accept the cheque only if they agree. A Buffalo system reported 67% read at 1% error [V].
   - **Applied to Parchi:** the brand name and the strength must agree with a real product. "Telma 40" exists; "Telma 400" doesn't, so it gets flagged.
2. **WHO "P-drugs" (personal drugs):**
   - The WHO Guide to Good Prescribing (1994) says every doctor regularly prescribes from a personal list [V].
   - **Applied to Parchi:** learn each doctor's list from earlier confirmed scans (doctor identified from the letterhead), and favour those brands when reading.
   - **None of my searches found this used in prescription reading** [V: absence in searches only, not proof].
3. **Keyboard personal dictionary / crowd-sourced word lists:**
   - When a user confirms a brand that isn't in the catalogue, it's added. This targets the measured 20% catalogue gap [J, mechanism].

## 9. End-of-phase report

**Consolidated idea:**
1. Snap the parchi.
2. Apple Vision marks the lines on the phone.
3. A vision model reads them.
4. Our cross-check snaps each name to the 2.5-lakh catalogue, checks brand and strength agree, and favours that doctor's usual brands.
5. Only doubtful lines come back to the user, with the source crop and the top 3 options.
6. Every confirmation teaches the system.

**Novelty line:**
- **Tier 1 candidate:** per-doctor reading using a learned personal-drug list, plus cheque-style brand–strength cross-checking, plus a catalogue that grows from confirmations.
- Not found in my searches; claim it as "no public product found", never "first".

**Innovation line (tier 2):**
- **Today:** 1mg and PharmEasy have **a pharmacist check it and phone you**, and Google's reader was **never launched**.
- **Parchi:** reads in seconds. In the measured test, 87% of the names it gave were correct, and it only asks the user about doubtful lines.

**Automations so far (5):**
- AU1 auto-capture and crop (VisionKit)
- AU2 auto-read into structured data
- AU3 auto-match to the catalogue and cross-check
- AU4 auto-flag only doubtful lines, with crop and options
- AU5 auto-learn each doctor's list and add new brands

**User input for this step:** 1 photo, plus taps only on flagged lines. With 87% precision, that's about 1–2 lines on a typical 5-medicine prescription [J].

**Need → why:**

| Need | Why | Keep? |
|---|---|---|
| Read handwriting | A patient can't read it, and buying the wrong medicine is a safety risk | Yes |
| Show the source crop | An AI misread must be easy to catch. The model still gets about 13% of names wrong | Yes |
| Doctor memory | The same doctors write the same brands, so it cuts errors and taps | Yes, measure it |
| Train our own model in 24 h | It won't beat 82% in 4 GPU hours | No, keep it as an experiment |

**Scorecard** (previous score → now):

| Criterion | Score | Why |
|---|---|---|
| Problem | 8.0 | Unchanged |
| Innovation | 6.5 → **7.0** | Measured improvement over pharmacist checks |
| Novelty | 6.0 → **6.5** | Doctor memory not found anywhere, but AI reading itself exists |
| Technical | **7.5** | Benchmark done, nothing built yet |
| Feasibility | 6.0 → **6.5** | No training needed, but needs an API and internet; lab iMac Xcode still unknown |
| UI/UX | **6.5** | Not designed yet |
| Demo | 7.0 → **7.5** | Scanning real handwriting with crop and one-tap fix is very visual |
| Security | 7.5 → **7.0** | Sending prescriptions to a cloud API needs consent and safeguards under India's data protection rules (DPDP) |
| **Average** | **7.1** | |

**Open questions:**
1. Test Haiku 5.5 and Sonnet 5.5 on all 81 prescriptions. Needs an API key; costs about $0.05 to $1.
2. Test Parrotlet on Jarvis Labs, about 1 hour at $1.49.
3. Phase 3 needs a fresher, fuller catalogue that includes over-the-counter products and supplements.

## Sources
- MIRAGE: https://arxiv.org/abs/2410.09729 · data: https://huggingface.co/datasets/chaithanyakota/100-handwritten-medical-records
- BD dataset: https://data.mendeley.com/datasets/zjjtptvn6f/2
- Indian Medicine Dataset: https://github.com/junioralive/Indian-Medicine-Dataset
- Parrotlet: https://huggingface.co/ekacare/parrotlet-v-2.5-pro
- RxVLM: https://link.springer.com/article/10.1007/s00371-026-04420-2
- 1mg FAQ: https://1mg.com/faq · PharmEasy: https://pharmeasy.in/online-medicine-order
- Google prototype: https://9to5google.com/2022/12/19/google-lens-will-soon-be-able-to-decipher-prescriptions-from-your-doctors-bad-handwriting/ · https://www.bgr.com/tech/brilliant-new-google-lens-feature-translates-your-doctors-handwriting/
- Claude vision token cost: https://platform.claude.com/docs/en/build-with-claude/vision
- Jarvis Labs: https://jarvislabs.ai/gpu/nvidia-h100 · https://jarvislabs.ai/blog/a100-price
- Cheque cross-check: https://researchconnect.buffalo.edu/en/publications/bankcheck-recognition-using-cross-validation-between-legal-and-co/
- WHO P-drugs: https://haiweb.org/encyclopaedia/who-guide-to-good-prescribing/
- Measurement code and outputs: /Users/aditya/dev/parchi-research/phase1-bench/ (vision_ocr.swift, score_rx.py, labels.json, vision_plain.json, claude_blind.json)

## Addendum, 23 Oct: decisions after talking it through
- **Plan:** our **own fine-tuned model runs on the lab iMac** as a local server: free, and prescriptions stay private. A paid API is only a backup for doubtful lines.
- **Two ways in, both needed:**
  - (a) A photo shared from WhatsApp. WhatsApp's standard quality shrinks images (2023 reports: 1600×1052, or 1536×2040, or 960×1280 depending on device; HD about 4096 px; the numbers conflict).
  - (b) The in-app scanner (VisionKit document camera).
  - Training and testing must include WhatsApp-style shrunk and recompressed copies.
- **Base models to test before training** (about 0.5 h each on Jarvis): Parrotlet-v-2.5-pro (Gemma-4-E2B), DeepSeek-OCR / OCR-2 (MIT, open), Qwen2.5-VL. mlx-vlm lists all three families, so they can run on Apple Silicon [V: third-party docs].
- **Dataset size does matter.** In MIRAGE (LLaVA), medicine-name F1 was **6% with 10k records, 29% with 100k, 49% with 528k** [V: Table 3]. A better base model needs less data, and synthetic data is cheap to make in bulk. The thing we're short of is **labelled real Indian handwriting**, not storage. The 5 TB Drive holds the synthetic data and checkpoints.
- **Using the DeepSeek API** (V4.1 Flash with image input, experimental, about $0.15–0.22 in / $0.60–0.65 out per 1M off-peak per aggregator sites) is **not cheaper per token than Claude Haiku 5.5** ($0.10 / $0.50). It also sends health data to a China-based provider's servers.
- **Event email** has no rule on preparing before the event. Prepare in advance, and keep a record of what was done beforehand.
- **Jarvis estimate:** 6–9 A100 hours ≈ $9–13.5; about $15–20 with buffer. Running on the iMac costs $0.

## Addendum 2, 23 Oct: budget of ₹400 and real-world images
- **Budget:** at ₹95.95 to $1 (actual rate on 16 Sep 2026), ₹400 is about $4.17.
  - Training on Kaggle's free GPUs (about 30 h a week reported, 12-hour sessions) or free Colab (T4) costs **₹0**.
  - Unsloth publishes free Colab vision notebooks for Qwen2.5-VL, Qwen3-VL and Gemma 3n.
  - Jarvis Labs is emergency only: 2 h on an A100 is about ₹286.
  - No paid API. Anthropic's top-up would be about ₹480 (if the minimum is $5), which is over budget.
- **Real-world test set** collected from Google and Bing image search: 19 images in webrx-testset/, of which 12 are Indian and usable (3 written in Hindi). What they show, which the synthetic generator must copy:
  - Phone photos: hands, background, tilt and shadows. So we need document detection for photos as well as the live scanner (Apple Vision has a still-image document-detection request).
  - Printed letterheads in regional scripts with English handwriting.
  - Some prescriptions fully in Hindi.
  - Line patterns: Rx, numbered lines, Tab/Cap/Syp, doses like "1-0-1", "x 5 days", and "Adv:" for tests.
- **Reddit** threads (r/indianmedschool, r/india) have real prescriptions with decodings in the comments, but they need a login to view. Not scraped.
- **Roboflow Universe** hosts a "Doctor Prescription" detection dataset (free account needed to download). To check in phase 3.

## Addendum 3, 23 Oct: scanner vs WhatsApp, and printed vs handwritten [M]
- **WhatsApp-style shrinking has no measurable effect.** Apple Vision found the same share of medicines (26.3%) on the originals, on copies shrunk to 1600 px at JPEG quality 70, and on copies shrunk to 1280 px at quality 50. With brand-list matching it dropped only from 34.1% to 31.9% at the heaviest setting. **The bottleneck is handwriting, not image quality.** Not tested yet: tilt, shadows and background. The 12 real phone photos in webrx-testset/ will cover that.
- **Printed vs handwritten split.** Apple Vision read 80% or more of the medicines on **12 of 81** prescriptions (15%), the printed or neat ones (rx010, 011, 015 and 025 are visibly printed), and **0% on 36 of 81** (44%). Design: read on the phone first, free and offline. If the page is printed and the read is confident, we're done. Otherwise send it to our model.
