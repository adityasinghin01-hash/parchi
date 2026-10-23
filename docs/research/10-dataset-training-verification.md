# Steps (d) + (e): dataset, training notebook, verification tests (23 Oct 2026, ~14:40 IST)
Labels: **[M]** measured by us today · **[V]** sourced · **[J]** judgement.

## (d1) Synthetic Indian prescription generator — BUILT [M]
Folder `synth/` (card: `synth/README.md`). Real brands from the 2.46-lakh catalogue, 400 doctors each with their own handwriting and personal brand list, Indian layouts with regional-script letterheads and Hindi notes, trailing scrawl, phone and WhatsApp effects, automatic labels (medicines, tests, patient-name boxes).
- Speed: **0.3 s per image** on the M1 (4 workers). 4,000 images ≈ 20 min.
- **Difficulty match:** on the messy two-thirds of the set, Apple Vision finds **26.9%** of brands vs **26.3%** on real MIRAGE handwriting [M, 200 images]. All handwritten together: 36.9% (easier than real).
- Gaps: no OTC/supplement brands (about 20% of real mentions), no medicine names written in Devanagari, font handwriting is still neater than a real doctor's.

## (d2) Kaggle training notebook — BUILT, GPU part NOT RUN yet
`synth/parchi_kaggle_train.ipynb` (built by `synth/build_notebook.py`; the generator is embedded, so nothing needs uploading).
- Steps: generate 4,000 train + 150 hold-out images (new doctors) → download MIRAGE-100 (test only) + make WhatsApp copies (1600 px q70, 1280 px q50) → **test Qwen2.5-VL-3B before training** → LoRA (r 16, lr 2e-4, 1 epoch, vision + language layers, Unsloth 4-bit, T4) → test again on MIRAGE, both WhatsApp copies and the hold-out set → `parchi_lora.zip`.
- Optional: attach the 12 web photos as a **private** Kaggle dataset; their predictions are saved for a human check, since they have no answer key yet.
- **Verified on the Mac [M]:** every non-GPU cell runs (data, MIRAGE download, scoring). The scorer reproduces our earlier benchmark exactly: frontier model on the 16 → **82.1% recall, 87.3% precision, 9/16 complete**.
- **Not verified:** the GPU cells (no Kaggle account here; Unsloth versions change often). If a cell fails, send me the error.
- Why Qwen2.5-VL-3B and not Parrotlet: Unsloth has a ready 4-bit build (`unsloth/Qwen2.5-VL-3B-Instruct-bnb-4bit`), it fits a free T4, and the same family runs on the iMac through MLX (`mlx-community/Qwen2.5-VL-3B-Instruct-4bit`) [V: both exist on Hugging Face]. Parrotlet stays the alternative to test later.
- iMac path: train → `SAVE_MERGED=True` → `mlx_vlm.convert` → serve. mlx-vlm can also load adapters made by its own trainer [V: mlx-vlm source], but a Kaggle/PEFT adapter needs merging first.

## (d3) Same model on this Mac, untrained (MLX) — RUNNING
_Result goes here: recall / precision / seconds per parchi on M1 8 GB._

## (e1) QuickPill handwriting head-to-head — DONE on 16 of 20 [M]
Same 20 MIRAGE images the frontier model read blind (rx010–rx029); QuickPill stopped loading after rx025. Raw: `h2h/quickpill_2026-10-23.json`.

| On the same 12 prescriptions with medicines | Recall | Precision | All found |
|---|---|---|---|
| QuickPill (logged-in web app, 23 Oct) | **89.7%** (52/58) | 83.9% | 8/12 |
| Frontier model, blind (our earlier test) | **89.7%** (52/58) | 88.1% | 7/12 |
| Handwritten only (8): QuickPill / frontier | 84.2% / 84.2% | 76.2% / 82.1% | 4/8 / 3/8 |

- QuickPill named 2 drugs (Clexane, Bortezomib) on rx017, which MIRAGE lists as having no medicines. **On inspection, both are written on the page** (a gap in MIRAGE's answer key), so they're not errors.
- **What this means:** QuickPill already reads handwriting at frontier level (it very likely uses a frontier model). **Reading alone is not our edge over QuickPill.** Our edge stays: tests in the same plan, nearby/offline/Jan Aushadhi, full price up front, Plan B, privacy (blur on the phone, own server, no quota), and the catalogue + brand–strength check (precision).
- Demo change: the "head-to-head" beat shows **same reading, then everything QuickPill can't do**, not "we read better".

## (e2) Patient-name blur — PASSES ≥95% [M]
Tool: `verification/pii_blur.swift` (Apple Vision, two passes English + Hindi, label rules for Name/नाम/रोगी का नाम, Age, Address, Mobile; fails closed by blurring everything above the first medicine line when no Name label is found; never blurs a line that starts with Tab/Cap/Syp/टैब). Scorer: `verification/blur_eval.py` (hidden = ≥80% of the box covered).

| Test set | Patient names hidden | Age | Phone | Medicine lines blurred by mistake |
|---|---|---|---|---|
| **Final: 300 fresh synthetic images (seed 10, never used for tuning)** | **98.3%** (295/300) | 98.8% | 46.0% (23/50) | 7.1% (73/1,033) |
| 12 real web photos, checked by eye | **12/12** after adding Hindi reading (was 10/12: the 2 misses were Hindi forms) | — | — | at least 1 medicine line (web004) |

- Weak spots: handwritten patient phone numbers (46%); 7% of medicine lines get blurred too. In the app the patient sees the original on their own phone and can un-blur a line with one tap before sending.
- One run returned no text from Apple Vision for all 200 images (a rerun was fine). The app must treat "no text found" as "ask the user", never as "nothing to blur".

## (e3) Usability (SUS) kit — READY
`verification/usability-SUS-kit.md` + `verification/sus_score.py` (tested: a fake all-best and all-neutral pair scores 100 and 50, mean 75). 4 tasks, the 10 standard SUS items with our Hindi translation (not validated), and a sheet format.

## (e4) Survey kit — READY
`verification/survey-kit.md`: 15-question Google Form, one WhatsApp message to send, and the analysis plan. **Needs you:** create the form and send it today. Target 20–30 answers by noon tomorrow.

## Score changes from this step
| Criterion | Verified | If built | Why |
|---|---|---|---|
| Novelty | 6.5 → **7.0** | 8.0 → **7.5** | +: own open dataset generator exists, difficulty-matched to real [M]. −: the head-to-head shows QuickPill reads as well as frontier, so "reads better" can't be claimed |
| Security | 7.0 → **7.5** | 8.8 | Blur measured: 98.3% names hidden on new synthetic, 12/12 on real photos |
| Technical | 8.0 | 8.8 | Unchanged until the Kaggle numbers exist |
| **Average** | **7.4 → 7.5** | **8.7 → 8.6** | Problem 8.5, Innovation 7.5, Feasibility 7.5, UI/UX 6.5, Demo 7.5 unchanged |
