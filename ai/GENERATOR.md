# Parchi synthetic Indian prescriptions (v1, 23 Oct 2026)

**What it is:** a generator for photo-like Indian OPD prescriptions with automatic labels, for training a prescription reader. Unlimited size, ₹0. It never uses MIRAGE-100 or the web test set.

## How to run
```
python3 -m venv .venv && .venv/bin/python -m pip install pillow numpy
.venv/bin/python -I parchi_synth.py fetch --assets assets            # 42 Google Fonts (OFL/Apache)
.venv/bin/python -I parchi_synth.py gen --assets assets --catalogue indian_medicine_data.csv --out out --n 1000 --seed 1 --doctors 400
```
Speed on an M1 MacBook Air: **200 images in 62 s** with 4 workers (≈0.3 s each), about 100 KB per image.

## What's in each image
| Part | How it's made |
|---|---|
| Medicines | Real active allopathy products from the 2.46-lakh Indian catalogue (MIT licence, Nov 2022 prices). Salts are sampled by √(number of brands) as a popularity stand-in, then a brand at random |
| Doctor | 400 synthetic doctors, each with **one handwriting style** (font, size, slant, messiness 0–3, ink) and a **personal list of 20–40 brands** used for 80% of lines (WHO "P-drugs"), so doctor-memory experiments are possible |
| Layout | Letterhead (70%) in English with Hindi/Telugu/Bengali/Malayalam/Tamil lines, Name/Age/Date row, complaints/BP/diagnosis column, Rx, numbered or dashed lines, Tab/Cap/Syp/Inj abbreviations, 1-0-1/BD/TDS, AF/BF, "x 5 days", "Adv: CBC, HbA1c", Hindi notes ("खाने के बाद"), signature, footer. 15% printed (computer) prescriptions |
| Handwriting | 30 handwriting fonts, per-letter size/height jitter, slant, elastic warping, pen thickness, and **trailing scrawl** (the doctor writes the first letters and the rest becomes a wavy line) |
| Photo | 40% scanner style; 60% phone photo with perspective, background, shadow gradient and hand/phone shadow, colour cast, blur, noise, JPEG quality 35–92, long side 960–2048 px (WhatsApp sizes) |

## Labels (`labels.jsonl`, one line per image)
`medicines` (name, catalogue name, form, strength, salts, dose, timing, duration, written abbreviation, scrawled yes/no, box), `tests` (canonical + as written), `pii` (patient name, age and phone boxes for the blur test), `doctor_id`, style fields, and `target` (the JSON the reader model should output).

## How hard is it? Measured against real handwriting
Apple Vision's brand recall, the same measurement as on MIRAGE-100 (real: **26.3%**):

| Synthetic subset (200 images, seed 8) | Apple Vision recall |
|---|---|
| Printed | 100% |
| Messiness 0 / 1 / 2 / 3 | 88.9% / 51.7% / 29.5% / 21.7% |
| **Messiness 2–3 (69% of handwritten mentions)** | **26.9%**, close to real (26.3%) |
| All handwritten | 36.9%, easier than real |

This is a difficulty match on one reader only, not proof the images look real. Visual check: layouts look right, but the handwriting is still neater and more font-like than real doctors' scrawl.

## Known gaps (v1)
- Brands only from the catalogue: supplements/OTC missing from it (Shelcal, Becosules…, about 20% of real mentions) never appear.
- No medicine names written in Devanagari yet (only Hindi notes and letterheads).
- Font handwriting is more regular than real; no crossed-out words or overwriting.
