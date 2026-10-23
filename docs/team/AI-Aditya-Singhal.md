# Parchi AI: training and testing, the independent doc (owner: Aditya Singhal)
Read `CONTEXT.md` (repo root) for the whole project in 2 minutes. This doc is everything you need to work **without waiting for anyone**.
Locked 23 Oct 2026. You write the scripts; this doc fixes **what** to build, the settings, the data, the tests and the pass/fail rules. Every number marked [M] was measured by us, [V] is from a source, [J] is an estimate to replace with your own measurement.

**You own everything AI and data:** all downloads, the team Drive (datasets, generated data, hand-copy photos, final models), data generation, training, testing, and handing the final model to the iMac. Nobody else touches the Drive data folders.

## 0. Your goal in one line
Make a model that reads Indian handwritten parchis into JSON, runs on the lab iMac, and **beats the untrained model on real handwriting** (MIRAGE-100). Report every number honestly, including the bad ones.

## 1. Machines
| Machine | What it is | Use it for |
|---|---|---|
| **KIET DGX** | JupyterHub container, **1 × A100 40 GB**, 256 CPU threads, 1 TB RAM, `/home/jovyan` = 14 TB persistent (everything else resets), NVIDIA driver **470**, CUDA 12.4 container, PyTorch NGC 24.03 [M, 6 Sep] | Data generation + main training + testing |
| **Jarvis Labs** | A100 80 GB at **$1.49/h** (₹400 ≈ 2.8 h) [V] | Emergency only (e.g. a 3B run if the DGX is busy) |
| **Kaggle** (free T4) | Notebook already built: `ai/parchi_kaggle_train.ipynb` (3B, 4k samples) | Free backup run, runs in parallel |
| **Lab iMac** | Apple **M4** (8 CPU / 8 GPU cores), **16 GB**, 332 GB free, Xcode 26.2, **44 MB/s** internet, admin account `kiet10` [M] | Serving the final model with MLX (download models directly here) |

**Driver 470 warning:** don't let pip upgrade `torch`. Install `transformers` (a version with `Qwen2_5_VLForConditionalGeneration`), `peft`, `accelerate`, `qwen-vl-utils`, `rapidfuzz` on top of the container's torch. If a package tries to pull a new torch, install it with `--no-deps`. Put the Hugging Face cache on `/home/jovyan` (`HF_HOME=/home/jovyan/hf`).

## 2. Downloads (put on the team Drive and on the DGX)
| What | Where | Size | Licence | Use |
|---|---|---|---|---|
| **Qwen2.5-VL-7B-Instruct** (main) | huggingface.co/Qwen/Qwen2.5-VL-7B-Instruct | ~16 GB | **Apache-2.0** | Train |
| Qwen2.5-VL-3B-Instruct (backup) | huggingface.co/Qwen/Qwen2.5-VL-3B-Instruct | ~7.5 GB | qwen-research (demo only) | Train if 7B is too slow |
| MLX 4-bit builds for the iMac (untrained baseline) | mlx-community/Qwen2.5-VL-7B-Instruct-4bit (5.65 GB), mlx-community/Qwen2.5-VL-3B-Instruct-4bit (3.1 GB) | | | iMac speed test |
| MIRAGE-100 (real handwriting, IIT Bombay) | huggingface.co/datasets/chaithanyakota/100-handwritten-medical-records (`data/train-00000-of-00001.parquet`) | ~90 MB | CC BY-ND 4.0 | **Test only, never train** |
| Indian medicine catalogue | raw.githubusercontent.com/junioralive/Indian-Medicine-Dataset/main/DATA/indian_medicine_data.csv | 32 MB | MIT | Generator + catalogue check |
| Bangladesh handwritten medicine words | data.mendeley.com/datasets/zjjtptvn6f/2 (download zip in a browser) | 4,680 images, ~50 MB | CC BY 4.0 | Train (word reading) |
| Our generator | `ai/parchi_synth.py` (+ `ai/GENERATOR.md`) | — | ours | Make the training data |
| Fonts for the generator | `python -I parchi_synth.py fetch --assets assets` (42 Google Fonts) | ~20 MB | OFL/Apache | Generator |
| 12 real web photos | held by Aditya Singh (never commit, never public) | 3 MB | **copyrighted, private** | Private test, never on Drive publicly |

## 3. Data
### 3a. Synthetic (our generator)
- **Train:** 40,000 images, `--seed 21 --doctors 400 --workers 120`. **Hold-out:** 2,000 images, `--seed 22 --doctors 60` (different seed, so new doctors).
- Speed: 0.3 s per image on 4 Mac cores [M] → on 120 DGX workers, expect about **15–30 min for 40k** [J]. Size ≈ 100 KB per image → ~4 GB.
- Each `labels.jsonl` line has `target` (the exact JSON answer), `medicines` (with boxes), `tests`, `pii`, `doctor_id`, `messiness`, `printed`.
- Known difficulty: on the messiest two-thirds, Apple Vision finds 26.9% of brands vs 26.3% on real MIRAGE [M].

### 3b. Hand-copied real parchis (most valuable)
1. Take 60 handwritten (not printed) records from a generated set. For each, make a **copy card**: plain typed text of that parchi (form + brand + strength + dose + duration, tests), with an ID `C001`–`C060`.
2. 30–50 people each copy 5–10 cards **by hand onto any paper, fast, like a doctor**, writing the card ID at the top. Mix pens, paper, lighting.
3. Photo on WhatsApp → save as `C014_AG.jpg` (card ID + writer initials).
4. Answers = the card's `target`. **Split by writer**: 30% of writers = test only, 70% = train (repeat each train photo ×10 in the manifest).
- Target 300–500 photos. Consent: tell writers it's for a hackathon dataset; no real patient data is involved.

### 3c. Bangladesh word images
Use as a second task: prompt "Read the medicine name in this handwritten image. Reply with the name only." → target = folder name. Max 10% of the training rows.

### 3d. Manifest
One `train.jsonl` row per sample: `{"image": path, "target": "...", "prompt": optional}`. Shuffle. Keep the test sets **out** of it (MIRAGE, hold-out, test writers, web photos).

## 4. Training (locked settings)
| Setting | Value | Why |
|---|---|---|
| Base | **Qwen2.5-VL-7B-Instruct** | Apache-2.0, stronger reader than 3B; fits A100 40 GB for LoRA |
| Method | LoRA on `q,k,v,o,gate,up,down` projections (language + vision blocks) | Fits one GPU; adapts both seeing and writing |
| Rank / alpha / dropout | 64 / 128 / 0.05 | MIRAGE used 128/256 over days [V]; 64 is cheaper for one night [J] |
| Learning rate | 1e-4, cosine, 3% warm-up | MIRAGE used 2e-5 for days; we train for hours [J] |
| Epochs | 1 | Time box |
| Batch | 2 per step × 8 accumulation = 16 | Memory |
| Precision | bf16 + gradient checkpointing, SDPA attention | A100 |
| Image size | long side ≤ 1024 px; processor `max_pixels = 1280×28×28` | ~900–1,300 image tokens |
| Loss | **only on the answer tokens** (mask everything up to `<|im_start|>assistant\n`) | Standard instruction tuning |
| Prompt | Exactly the one in §6 for training, testing and serving | Same input everywhere |
| Checkpoints | every 200 steps, keep 3, auto-resume | A cut session costs ≤ 1 h |
| Logging | seconds/step + ETA every 10 steps | Decide the final data size |

**Data size rule:** estimated 7B speed ≈ 0.38 s/sample [J] → 40k ≈ 4–6 h. After the first 30 minutes, read the real s/step and set `max_samples = (hours you can spare for training) × 3600 / (s per sample)`. If 7B is slower than 1 s/sample, switch to 3B (≈0.17 s/sample [J]) on 100k.

## 5. Testing (locked)
**Scoring (same as all our earlier numbers):** a medicine counts as found when the **first word of its brand (≥3 letters, after removing Tab/Cap/Syp…)** matches. Report recall, precision, F1, "all medicines found" per parchi, and names output on pages with no medicines. Also report the same after **snapping each name to the nearest catalogue brand** (fuzzy ≥85). Check your scorer first: on the frontier model's blind reads (`docs/research/evidence/claude_blind.json`, labels in `docs/research/evidence/labels.json`), it must give **82.1% recall / 87.3% precision / 9 of 16 complete** [M].

| Test set | Size | What it shows |
|---|---|---|
| MIRAGE-100 original | 81 with medicines | Real Indian handwriting (main number) |
| MIRAGE WhatsApp copies | 1600 px q70 and 1280 px q50 | WhatsApp doesn't break it |
| Synthetic hold-out (new doctors) | 2,000 | Learned the format, not memorised doctors |
| Hand-copied, test writers | ~100–150 | Real handwriting from unseen people |
| 12 web photos | 12 | Real phone photos (no answer key: save outputs for a human check) |
| Speed | — | Seconds per parchi on the DGX and on the iMac |

**Comparison table to fill:**
| Model | MIRAGE recall | precision | WA 1280 recall | hand-copied recall | s/parchi (iMac) |
|---|---|---|---|---|---|
| Apple Vision (on phone) | 26.3% [M] | 12.8% | 26.3% | | ~0.85 (Mac) |
| Frontier model, blind (16 imgs) | 82.1% [M] | 87.3% | | | API |
| QuickPill (12 imgs) | 89.7% [M] | 83.9% | | | web |
| Qwen2.5-VL-7B untrained | | | | | |
| **Qwen2.5-VL-7B + our LoRA** | | | | | |
| Qwen2.5-VL-3B + LoRA (Kaggle/Jarvis) | | | | | |

**Pass/fail:** the trained model goes on stage only if its MIRAGE recall beats the untrained one **and** WA-1280 recall is within 2 points of its original. Otherwise the stage uses whichever row is best, with its real number.

## 6. The prompt (use this exact text everywhere)
```
You are reading an Indian doctor's prescription (parchi). List every medicine and every lab test exactly as written. Reply with JSON only: {"medicines":[{"name":"brand and strength","form":"Tab/Cap/Syp/...","dose":"...","duration":"..."}],"tests":["..."]}. If there are none, use empty lists.
```

## 7. To the iMac
1. Merge the LoRA into the base (PEFT `merge_and_unload`), save safetensors + processor.
2. Copy to the iMac; convert with **mlx-vlm** on Apple-silicon Python: `mlx_vlm.convert` with 4-bit quantisation (check `--help` for the exact flags). 7B 4-bit ≈ 5.65 GB, fits 16 GB.
3. Serve it on the iMac and measure seconds per parchi on 20 MIRAGE images. Target ≤ 15 s [J]. If slower: send only the cropped medicine area (fewer image tokens), or use the 3B.

**Reader API for the app (agree this with Aditya Singh):**
`POST /read` · header `X-Parchi-Key: <install key>` · body = JPEG (already blurred and cropped on the phone) → `{"medicines":[{"name","form","dose","duration"}],"tests":[...],"ms":1234,"model":"parchi-7b-lora-v1"}`. Bind to localhost (Simulator on the same iMac) or the team hotspot. The phone runs the catalogue + brand–strength check (ParchiCore), not the server.

## 8. Scripts you write (names, inputs, outputs only)
| Script | In | Out |
|---|---|---|
| `parchi_synth.py` | **exists**; catalogue + fonts | images + labels.jsonl |
| `make_copy_kit` | synthetic labels.jsonl | 60 card images + cards.jsonl |
| `build_manifest` | synthetic + cards + photos + BD | train.jsonl, hand-copy test set |
| `train_lora` | train.jsonl + base model | LoRA checkpoints, s/step log |
| `eval_reader` | model (+LoRA) + test sets | results/<tag>.json + raw outputs |
| `merge_lora` | base + LoRA | merged model |
| `serve` (iMac) | MLX model | `/read` endpoint |
Reference drafts of `train_lora.py` and `eval_reader.py` are in `ai/drafts/` (untested on a GPU); use them or write your own.

## 9. Order of work (no fixed hours: move on when each step is done)
| Step | Do |
|---|---|
| 1 | DGX setup, downloads, scorer check (82.1%) |
| 2 | Generate 40k + 2k; send copy cards to the team WhatsApp |
| 3 | **Start 7B training**; start the Kaggle 3B run in parallel |
| 4 | Untrained 7B on MIRAGE-100 + WhatsApp copies (baseline) |
| 5 | Collect hand copies; build the test-writer set |
| 6 | Training finishes; optional short second pass with hand copies |
| 7 | Full tests; pick the stage model |
| 8 | Merge → MLX → iMac; measure speed; hand the API to the app |
| 9 | Fixes only; numbers into the deck and the app's "How accurate" screen |

## 10. Fallback ladder (never block the demo)
7B + LoRA → 3B + LoRA (Jarvis/Kaggle) → untrained 7B → Apple Vision for printed parchis + the confirm screen for everything else.

## 11. Risks
| Risk | Fix |
|---|---|
| pip upgrades torch and breaks on driver 470 | `--no-deps`, check `torch.cuda.is_available()` after every install |
| Session cut mid-training | Checkpoints every 200 steps + auto-resume; run with `nohup` |
| 7B too slow on the iMac | Crop to the medicine area; else 3B |
| Model invents medicines | Catalogue + brand–strength check on the phone; count "names on blank pages" |
| Overfitting to synthetic fonts | Hand-copied data + test by writer |

## 12. Latest measured result (before any training)
Untrained **Qwen2.5-VL-3B** (MLX 4-bit) on the first 30 MIRAGE images on an M1 MacBook: **recall 13.6% (16/118), precision 26.2%, ~20 s per parchi** [M] (`docs/research/evidence/mac_qwen25vl3b_untrained.json`). Training is essential; the untrained model is far below QuickPill (89.7%).

## 13. Decision rules (you decide; don't wait for the lead)
| If… | Then… |
|---|---|
| 7B training measures > 1 s/sample after 30 min | Switch to 3B on 100k, or cut 7B to what finishes in time |
| DGX install breaks torch (driver 470) | Use the container's torch; `--no-deps`; else go to Jarvis (₹400 ≈ 2.8 h on A100 80 GB) |
| DGX session dies | Resume from the last checkpoint; never restart from zero |
| Fewer than 150 hand-copied photos when training starts | Train without them; keep all of them as the test set |
| Trained model ≤ untrained on MIRAGE | Ship the better one and report both numbers honestly |
| WhatsApp-1280 recall drops > 2 points vs original | Add more photo/WhatsApp effects to synthetic data for the next run |
| Model invents names on blank pages (> 0.5 per page) | Raise the catalogue-snap threshold; report it |
| iMac takes > 15 s per parchi | Send only the cropped medicine area; else use 3B |
| Anything needs money beyond ₹400 or a paid API | Don't. Tell Aditya Singh |
| A number isn't measured | Don't put it in the deck. Write "to be measured" |

## 14. What you hand over (definition of done)
1. `parchi-reader` MLX 4-bit model folder on the iMac + a one-line command to start the server.
2. `POST /read` working on the iMac (localhost), contract in §7.
3. `results/` table filled (§5) with untrained vs trained on every test set + seconds per parchi on the iMac.
4. On Drive: the LoRA adapter (~0.4 GB), the MLX model (~5.65 GB), the datasets, the hand-copy photos + cards.
5. Three honest lines for the deck: what we trained, on how much data, the before/after number.
