# Reader model survey, 24 Oct 2026 (Codex R6, read-only research; Claude spot-checked the Parrotlet, LightOnOCR and DeepSeek-prescription claims on their Hugging Face pages)
VERIFIED = Codex opened the primary source. Claude re-opened: Parrotlet card (85.03 on 1,147 held-out pages across five document types, LLM rubric judge, handwriting and Hindi not stated; Eka table: GPT-5.6 Terra 84.73, Gemini 3.6 Flash 83.81, GPT-5.6 Luna 82.55, Claude Sonnet 5 81.81), LightOnOCR-3-4B card (olmOCR-Bench 86.3, Apache-2.0), and the community DeepSeek-OCR prescription fine-tune (14.9 0rug-name accuracy on 47 rows).

VERIFIED = I opened and read the cited primary source; it does not mean I reproduced its results. UNVERIFIED = unavailable, unsupported, or an untested proposal. Repository findings are labelled VERIFIED—local. Research cutoff: 24 October 2026. No files changed, models downloaded, or GPU jobs run.

VERIFIED search finding: I found no downloadable model with independently demonstrated ≥80% medicine-name recall on messy Indian prescriptions. Parrotlet is the strongest domain-specific lead, but its 85.03 does not establish that threshold.

1. Shortlist and survey

All benchmark figures below are developer-reported unless stated otherwise. Download sizes describe the indicated weights/repository, not runtime RAM. “No recipe found” means UNVERIFIED availability, not proof that none exists.

| Model and release/update | Licence; parameters; download | What it reads; claimed benchmark | LoRA evidence | Apple M4 route |
|---|---|---|---|---|
| VERIFIED [Parrotlet-v-2.5-pro](https://huggingface.co/ekacare/parrotlet-v-2.5-pro); launched 2026-08-10, updated Aug 11 | Apache-2.0; Gemma-4-E2B, approximately 6B total/~2B effective; 11 GB BF16 | Indian medical records → structured extraction. Prescription rubric 85.03; handwriting-only/Hindi results UNVERIFIED | Generic Gemma4 vision recipe exists; Parrotlet-specific recipe UNVERIFIED | Gemma4 supported by mlx-vlm; exact Parrotlet conversion, memory and latency UNVERIFIED |
| VERIFIED [LightOnOCR-3-4B](https://huggingface.co/lightonai/LightOnOCR-3-4B); released 2026-10-08 | Apache-2.0; marketed 4B, HF rounds total to 5B; 9.08 GB weights | Document transcription/layout; developer olmOCR-Bench 86.3. French handwriting-category score 46.1, not prescription recall | Generic Qwen3.5 vision recipe; model-specific recipe UNVERIFIED | Actual [MLX build](https://huggingface.co/prithivMLmods/LightOnOCR-3-4B-MLX), with 4bit/ subfolder; runtime UNVERIFIED |
| VERIFIED [PaddleOCR-VL-1.6](https://huggingface.co/PaddlePaddle/PaddleOCR-VL-1.6); released 2026-05-28 | Apache-2.0; marketed 0.9B, 958M reported by converter; 1.92 GB weights | Text, tables, formulas, charts, spotting; developer OmniDocBench v1.6 score 96.33. Indian prescription recall UNVERIFIED | Explicit [Axolotl QLoRA recipe](https://docs.axolotl.ai/docs/models/paddleocr-vl.html) | Actual [MLX 4-bit build](https://huggingface.co/mlx-community/PaddleOCR-VL-1.6-4bit), 0.68 GB; prescription fidelity UNVERIFIED |
| VERIFIED [MedOCR-Vision](https://huggingface.co/naazimsnh02/medocr-vision); weights 2025-12-20, card Dec 21 | MIT card; PaddleOCR-VL derivative, ~1B; 1.92 GB weights | Trained on 2,462 mixed documents, including 1,000 claimed handwritten prescriptions. Validation loss 0.5787 is not accuracy; Indian provenance UNVERIFIED | Actual [training notebook](https://github.com/Naazimsnh02/medocr-vision/blob/main/medocr-paddle-training-notebook.ipynb) | Base architecture supported; this checkpoint’s conversion/build UNVERIFIED |
| VERIFIED [medical-prescription-ocr-india](https://huggingface.co/KushagraWadhwa/medical-prescription-ocr-india); date UNVERIFIED | Apache card tag; Qwen2.5-VL-3B parent restrictions still require attention; 7.51 GB weights | Claims Indian English/Hindi handwritten/printed → JSON. Same mixed dataset as MedOCR; no numerical medicine recall | Card documents rank 16, alpha 32, learning rate 2e-4; linked project | Qwen2.5-VL supported; exact fine-tune’s MLX build UNVERIFIED |
| VERIFIED [DeepSeek-OCR-2](https://huggingface.co/deepseek-ai/DeepSeek-OCR-2); January 2026, exact release day UNVERIFIED | Apache-2.0; approximately 3B; 6.78 GB weights | Document OCR/compression; prescription-specific benchmark UNVERIFIED | Model-specific LoRA recipe UNVERIFIED | Actual [MLX 4-bit build](https://huggingface.co/mlx-community/DeepSeek-OCR-2-4bit), repository 2.56 GB |
| VERIFIED [Chandra OCR 2](https://huggingface.co/datalab-to/chandra-ocr-2); released 2026-03-18 | Modified OpenRAIL-M; marketed 4B/HF rounds 5B; 10.6 GB weights | Handwriting and multilingual document OCR; own olmOCR score 85.8, own Hindi document score 78.4. Neither is prescription recall | Model-specific recipe UNVERIFIED; Qwen3.5 ancestry | Actual [MLX 8-bit build](https://huggingface.co/mlx-community/chandra-ocr-2-oQ8), 5.14 GB; runtime UNVERIFIED |
| VERIFIED [dots.mocr](https://huggingface.co/dots-studio/dots.mocr); March 2026 | MIT; 3B; repository 6.09 GB | Multilingual document/layout OCR, successor to dots.ocr 1.5; reported olmOCR 83.9 ± 0.9. Indian handwriting result UNVERIFIED | Reusable LoRA recipe UNVERIFIED | [mlx-vlm implementation](https://github.com/Blaizzy/mlx-vlm/blob/main/mlx_vlm/models/dots_ocr/README.md); exact checkpoint build UNVERIFIED |
| VERIFIED [olmOCR-2-7B-1025](https://huggingface.co/allenai/olmOCR-2-7B-1025); October 2025 checkpoint | Apache-2.0; marketed 7B; BF16 repository 16.6 GB | English-tagged document OCR, scans/math/tables; author pipeline 82.3 ± 1.1 BF16, including pipeline processing. Not prescription recall | Training toolkit exists; minimal prescription LoRA recipe UNVERIFIED | Actual [MLX 4-bit build](https://huggingface.co/mlx-community/olmOCR-2-7B-1025-4bit); M4 latency UNVERIFIED |
| VERIFIED [Parrotlet-v-lite-4b](https://huggingface.co/ekacare/parrotlet-v-lite-4b); launched 2025-07-24, updated 2026-01-20 | MIT card; MedGemma ancestry brings upstream HAI-DEF terms; gated; download size UNVERIFIED | Card explicitly lists DIGITAL prescription parsing. Handwritten-prescription competence UNVERIFIED | Historical LoRA settings published; reusable training script UNVERIFIED | Gemma-family support alone does not verify this custom checkpoint; exact build UNVERIFIED |

VERIFIED licence qualification: Chandra’s modified terms permit research/personal use and qualifying startups, but prohibit competitive use against its API; OpenRAIL metadata alone does not describe those restrictions. [Chandra terms summary](https://huggingface.co/datalab-to/chandra-ocr-2)

Additional candidates considered—well over 20 checkpoints overall:

- VERIFIED: [Qwen3-VL-4B](https://huggingface.co/Qwen/Qwen3-VL-4B-Instruct), Apache-2.0, repository 8.89 GB, [MLX 4-bit](https://huggingface.co/mlx-community/Qwen3-VL-4B-Instruct-4bit) 3.11 GB; [Qwen3.5-4B](https://huggingface.co/Qwen/Qwen3.5-4B), Apache-2.0, repository 9.34 GB, [MLX 4-bit](https://huggingface.co/mlx-community/Qwen3.5-4B-MLX-4bit) 3.06 GB. Both are general VLMs with OCR capabilities; neither establishes Indian prescription recall. Keep them as controls, not prescription-trained recommendations.
- VERIFIED: [Qwen2.5-VL-3B](https://huggingface.co/Qwen/Qwen2.5-VL-3B-Instruct) and [7B](https://huggingface.co/Qwen/Qwen2.5-VL-7B-Instruct) considered; 7B is Apache-2.0. VERIFIED—local: your 3B result is a measured weak baseline, not evidence against every newer OCR-specialised derivative.
- VERIFIED: [GOT-OCR 2.0](https://huggingface.co/stepfun-ai/GOT-OCR2_0), Apache-2.0, approximately 0.7B, has linked training code; [Florence-2-large-ft](https://huggingface.co/microsoft/Florence-2-large-ft), MIT, offers OCR task tokens; [Donut-CORD](https://huggingface.co/naver-clova-ix/donut-base-finetuned-cord-v2), MIT, is receipt parsing. No qualifying Indian prescription result found for these.
- VERIFIED: [TrOCR-base-handwritten](https://huggingface.co/microsoft/trocr-base-handwritten), MIT, is IAM-trained SINGLE-LINE recognition. It needs line detection/crops and a separate extraction stage; IAM CER/WER cannot establish whole-prescription medicine recall.
- VERIFIED: [SmolDocling-256M](https://huggingface.co/docling-project/SmolDocling-256M-preview), CDLA-Permissive-2.0, and [Granite-Docling-258M](https://huggingface.co/ibm-granite/granite-docling-258M), Apache-2.0, target document conversion. Prescription handwriting performance UNVERIFIED.
- VERIFIED: [Surya’s older recognition checkpoint](https://huggingface.co/vikp/surya_rec2), CC-BY-NC-SA-4.0, [original Chandra](https://huggingface.co/datalab-to/chandra), [dots.ocr](https://huggingface.co/dots-studio/dots.ocr), [PaddleOCR-VL-1.5](https://huggingface.co/PaddlePaddle/PaddleOCR-VL-1.5), and [LightOnOCR-2-1B](https://huggingface.co/lightonai/LightOnOCR-2-1B) were considered; newer successors are more relevant to this pilot.
- VERIFIED: [LightOnOCR-3-0.8B/1B](https://huggingface.co/blog/lightonai/lightonocr-3) are useful smaller fallbacks. Their developer French-handwriting scores are 33.3/37.0, versus 46.1 for 4B; these are benchmark scores, not medicine recall.
- VERIFIED: [MedGemma-1.5-4B](https://huggingface.co/google/medgemma-1.5-4b-it) adds medical-document capabilities but supplies no qualifying prescription-handwriting result; HAI-DEF terms apply. [LLaVA-Med](https://huggingface.co/microsoft/llava-med-v1.5-mistral-7b) targets biomedical image understanding, not prescription OCR.
- VERIFIED: [chinmays18’s Donut prescription model](https://huggingface.co/chinmays18/medical-prescription-ocr) claims 84% word accuracy without adequate benchmark detail; [khedim’s TrOCR prescription model](https://huggingface.co/khedim/Medical-Prescription-OCR) claims 97.56% line-word accuracy, but source provenance, writer-separated evaluation and licence are UNVERIFIED. Neither meets your recall requirement.
- VERIFIED: [Rahul3736’s DeepSeek prescription fine-tune](https://huggingface.co/Rahul3736/deepseek-ocr-medical-prescription) reports only 14.9% drug-name accuracy on 47 confirmed rows. [phi3-prescription-reader](https://huggingface.co/Muizzzz8/phi3-prescription-reader) demonstrates OCR-text input rather than image reading. Reject both as starting points.
- VERIFIED: [MIRAGE’s trained Idefics2](https://arxiv.org/html/2410.09729v2) reports 82% medicine-name-and-dose F1 on its own doctor-written simulated records. Downloadable trained weights were UNVERIFIED; this is not an available ≥80%-recall checkpoint.

Public training-data options:

| Status | Dataset, size, licence and usable scope |
|---|---|
| VERIFIED | [RxHandBD v3](https://data.mendeley.com/datasets/dsb5r6vskg/3): 5,578 physician-written word crops, 1,559-word vocabulary; CC BY 4.0; Bangladesh. Best small real-handwriting supplement found; preserve its official test split. |
| VERIFIED | [Bilingual Medical Prescriptions v2](https://data.mendeley.com/datasets/tg2hm7n2bs/2): 1,000 handwritten prescriptions, Bangladesh, English/Bangla; CC BY 4.0, research/education stated. Bangla is not Hindi; archive-specific conditions remain UNVERIFIED. |
| VERIFIED | [Doctor’s Handwritten Prescription BD](https://data.mendeley.com/datasets/zjjtptvn6f/2): 4,680 word images, 78 medicine classes; CC BY 4.0 displayed, description says research/education only. Suitable demo-research supplement, not whole-page extraction training. |
| VERIFIED | [African Medical Records](https://huggingface.co/datasets/Nigeria-Health-data-OCR-pipeline/African-Medical-Records): 62 volunteer-produced/synthesised handwritten/transcription pairs; CC BY 4.0; not Indian patient prescriptions. |
| VERIFIED | [Medical Prescription Handwritten Words](https://huggingface.co/datasets/avi-kai/Medical_Prescription_Handwritten_Words): 46 word images; MIT; very small. [Synthetic Indian clinical notes](https://data.mendeley.com/datasets/bzgjmph5n2/1): 10,000 text notes; CC BY 4.0; requires rendering, supplies no real handwriting. |
| VERIFIED | [MedOCR dataset](https://huggingface.co/datasets/naazimsnh02/medocr-vision-dataset): 2,462 mixed samples, MIT tag. However, its [prescription source](https://huggingface.co/datasets/chinmays18/medical-prescription-dataset) supplies no verified licence. Do not assume the aggregate MIT tag establishes upstream training permission or Indian provenance. |
| VERIFIED | [MIRAGE-100](https://huggingface.co/datasets/chaithanyakota/100-handwritten-medical-records): 100 images, CC BY-ND 4.0. TEST ONLY under your rule, regardless of HF’s “train” split name. [Eka’s 288-image validation set](https://huggingface.co/datasets/ekacare/medical_records_parsing_validation_set) is gated, MIT-tagged and labelled test; preserve it for evaluation. |

UNVERIFIED: IAM’s current official access/licence terms could not be retrieved; I would not add an arbitrary HF mirror to training on this evidence.

2. Parrotlet findings

VERIFIED: 85.03 is Eka’s prescription-category rubric score. The overall metric averages coverage and grounding, using per-page LLM judging. The 1,147 held-out pages cover FIVE document types; prescription-only count, handwriting fraction, Hindi breakdown and medicine-name recall are undisclosed. This is Eka’s evaluation, not independent validation. [Model card](https://huggingface.co/ekacare/parrotlet-v-2.5-pro)

UNVERIFIED: indexed launch-blog text names GPT-5.6 Luna as grader and describes clinician references/~110,000 rubric items. I opened the [launch URL](https://info.eka.care/services/releasing-parrotlet-open-models-open-weights-for-medical-document-intelligence), but retrieval exposed only its title/date/footer, so those body-only details do not meet your verification standard.

VERIFIED: input is an image followed by the exact tag <prescription>, through the processor’s chat template. The model selects its native extraction schema. The inspected card does not publish that complete prescription schema; its exact keys are UNVERIFIED. Do not invent a medications path or replace the tag with your existing generic prompt. [Usage](https://huggingface.co/ekacare/parrotlet-v-2.5-pro)

VERIFIED: BF16 download is approximately 11 GB; the card reports approximately 10.7 GiB peak VRAM. It requires transformers>=5.14 and warns that 5.5.0 can silently initialise missing layers. [Requirements](https://huggingface.co/ekacare/parrotlet-v-2.5-pro)

VERIFIED: [mlx-vlm implements Gemma4 E2B vision](https://github.com/Blaizzy/mlx-vlm/blob/main/mlx_vlm/models/gemma4/README.md). UNVERIFIED: these exact Parrotlet weights converted correctly, their 4-bit prescription accuracy, total memory on a 16 GB M4, and ≤15-second latency. Effective parameters do not equal resident weight memory.

VERIFIED: [generic Gemma4 vision LoRA documentation](https://unsloth.ai/docs/models/gemma-4/train) exists. UNVERIFIED: a Parrotlet-specific working recipe. The opened [E2B example](https://github.com/unslothai/notebooks/blob/main/python_scripts/Gemma4_(E2B)-Vision.py) pins Transformers 5.5.0, conflicting with Parrotlet’s explicit warning; copying it unchanged is unsafe.

VERIFIED search finding: the current [Eka organisation](https://huggingface.co/ekacare) exposes pro and older lite as reader VLMs; no newer public reader was found. Lite explicitly targets digital prescriptions, uses model.process(image_path, task="prescription-parsing"), and has no verified handwritten-prescription subgroup result.

3. Concrete budget plan

UNVERIFIED proposal: test Parrotlet first, LightOnOCR-3-4B second, PaddleOCR-VL-1.6 third; train only ONE winner. These are alternative training branches, not three two-hour runs.

UNVERIFIED time allocation: reserve 45 minutes for initial evaluation/loading, 120 minutes for calibration plus training, and 15 minutes for post-training evaluation/export. This fits three paid hours only if measured evaluation throughput permits; otherwise finish baselines/post-tests on free Kaggle or the Mac and shorten training. Downloads, installation and generation on a paid instance also consume its clock. Pre-stage them free where possible.

UNVERIFIED pricing assumption from your brief: three hours × $1.49 = $4.47 before other charges; check the actual credit balance and stop timer. No published benchmark guarantees this complete experiment finishes within ₹450.

VERIFIED native inference interfaces and proposed settings:

| Branch | Source-supported library/version and prompt | UNVERIFIED pilot/training choices |
|---|---|---|
| Parrotlet | Transformers >=5.14; AutoModelForImageTextToText + AutoProcessor; image then <prescription>; greedy generation, native example 2,048 output tokens | LoRA rank 16/alpha 32, LR 2e-5; freeze vision initially; microbatch 1 × accumulation 8; medicine/test crop around 1,024 px; allow up to 1,024 answer tokens and measure total sequence length |
| LightOnOCR-3-4B | Transformers >=5.5.4; Qwen3_5ForConditionalGeneration; thinking disabled; EMPTY prompt for transcription | Rank 16/alpha 32, LR 2e-5; batch 1 × 8; around 1,024 px training crops; aim ≤1,024 image + 512 answer tokens, without truncating labels |
| PaddleOCR-VL-1.6 | Transformers >=5; AutoModelForImageTextToText; OCR: prompt; direct HF path is element-level recognition | Rank 16/alpha 32, LR 5e-5; batch 2 × 4; medicine-line crops, roughly 512–1,024 px; aim ≤2,048 total tokens |

VERIFIED caveat: LightOn explicitly says other prompts are out of distribution. Do not force Parchi JSON during its zero-shot OCR test. Paddle’s full-page headline score uses a pipeline; its direct HF recogniser is not equivalent. Use the official page pipeline or fixed medicine/test crops and report which. [LightOn modes](https://huggingface.co/lightonai/LightOnOCR-3-4B), [Paddle interfaces](https://huggingface.co/PaddlePaddle/PaddleOCR-VL-1.6)

UNVERIFIED proposed evaluation driver below: save as probe_rx.py outside the read-only research checkout. Its native API calls follow the cards, but I have not run this combined driver or verified a complete package lock. It saves native output plus the exact envelope score_rx.py expects.

```python
import glob, json, os, sys, time, torch
from PIL import Image
from transformers import AutoProcessor, AutoModelForImageTextToText, Qwen3_5ForConditionalGeneration
repo, prompt, image_dir, labels_path, output_path = sys.argv[1:]
light = "LightOnOCR" in repo
cls = Qwen3_5ForConditionalGeneration if light else AutoModelForImageTextToText
model = cls.from_pretrained(repo, dtype=torch.bfloat16, device_map="auto").eval()
processor = AutoProcessor.from_pretrained(repo)
labels = json.load(open(labels_path))
saved = {"results": {}, "raw": {}, "seconds": {}}
for filename in labels:
    image = Image.open(os.path.join(image_dir, filename)).convert("RGB")
    content = [{"type": "image", "image": image}]
    if prompt:
        content.append({"type": "text", "text": prompt})
    extra = {"enable_thinking": False} if light else {}
    inputs = processor.apply_chat_template(
        [{"role": "user", "content": content}], add_generation_prompt=True,
        tokenize=True, return_dict=True, return_tensors="pt", **extra).to(model.device)
    torch.cuda.synchronize(); started = time.perf_counter()
    with torch.inference_mode():
        generated = model.generate(**inputs, do_sample=False,
                                   max_new_tokens=2048 if "parrotlet" in repo else 1024)
    torch.cuda.synchronize()
    text = processor.decode(generated[0][inputs["input_ids"].shape[-1]:],
                            skip_special_tokens=True)
    saved["raw"][filename] = text
    saved["results"][filename] = [{"text": text}]
    saved["seconds"][filename] = time.perf_counter() - started
    with open(output_path, "w") as handle:
        json.dump(saved, handle, ensure_ascii=False)
```

UNVERIFIED proposed commands; use a fresh environment and record pip freeze plus HF revision hashes after the smoke test:

```bash
python -m pip install torch torchvision 'transformers>=5.14' accelerate pillow rapidfuzz
python probe_rx.py ekacare/parrotlet-v-2.5-pro '<prescription>' MIRAGE_IMAGES LABELS_JSON parrotlet.json
python probe_rx.py lightonai/LightOnOCR-3-4B '' MIRAGE_IMAGES LABELS_JSON lighton.json
python probe_rx.py PaddlePaddle/PaddleOCR-VL-1.6 'OCR:' FIXED_MEDICINE_TEST_CROPS LABELS_JSON paddle.json
python -I ai/score_rx.py LABELS_JSON parrotlet.json MEDICINE_CSV
```

VERIFIED—local: score_rx.py’s raw mode retains only recognised catalogue stems and skips gold-empty pages. Report its raw/lexicon/guided rows for continuity, but also score extracted medicine names without catalogue filtering, count blank-page outputs separately, and preserve failures/truncated outputs. Your drafts use a different entity-scoring path; the numbers are not automatically interchangeable. [Scorer](/Users/aditya/dev/parchi/ai/score_rx.py), [draft evaluator](/Users/aditya/dev/parchi/ai/drafts/eval_reader.py)

UNVERIFIED proposed app contract: {"medicines":[{"name":"as written","strength":null,"form":null,"dose":null,"frequency":null,"duration":null}],"tests":[]}. Preserve raw source text; leave unreadable fields null. Map Parrotlet’s observed native schema into this contract. LightOn/Paddle require an extraction adapter; their native OCR output alone does not establish correct structured doses or tests.

VERIFIED—local data gap: target_json currently emits name/form/dose/duration/tests, omitting separate strength and timing; dose mixes schedules such as BD with quantities. Exact rendered duration text is not retained. Export exact rendered strings before OCR SFT, and define frequency/quantity labels before JSON SFT. Otherwise “training every requested field” would be an unsupported claim. [Generator](/Users/aditya/dev/parchi/ai/parchi_synth.py:506)

UNVERIFIED generation proposal: start with 4,000 training images plus 200 held-out images, not 40,000. At your recorded 0.3 seconds/image, 4,000 takes approximately 20 minutes on four cores; faster Jarvis scaling is unmeasured. Inspect allocated CPUs, start at min(8, available cores), benchmark 200 images, and increase workers only if throughput improves.

```bash
python -I ai/parchi_synth.py gen --assets assets --catalogue MEDICINE_CSV --out synth_train --n 4000 --seed 21 --doctors 400 --workers 4
python -I ai/parchi_synth.py gen --assets assets --catalogue MEDICINE_CSV --out synth_val --n 200 --seed 22 --doctors 60 --workers 4
```

UNVERIFIED training capacity: measure 50 warm updates, including image loading, then calculate sample presentations = floor(remaining_training_seconds × effective_batch / measured_seconds_per_update). With 6,000 seconds left, 1/2/4 seconds per sample permits 6,000/3,000/1,500 presentations respectively—arithmetic examples, not performance predictions. Save time for checkpointing; stop within the time budget even if an epoch is incomplete.

VERIFIED recipe entry points: Parrotlet can investigate the [Gemma4 E2B vision script](https://github.com/unslothai/notebooks/blob/main/python_scripts/Gemma4_(E2B)-Vision.py), and LightOn the [Qwen3.5 vision script](https://github.com/unslothai/notebooks/blob/main/python_scripts/Qwen3_5_(4B)_Vision.py). UNVERIFIED: substituting these fine-tunes into those scripts, especially their older pinned dependencies. Require one finite-loss backward pass and save/reload before spending the training allocation.

VERIFIED: Paddle has the concrete command axolotl train examples/paddleocr-vl/paddleocr-vl-1_6-qlora.yaml. Its [published configuration](https://raw.githubusercontent.com/axolotl-ai-cloud/axolotl/main/examples/paddleocr-vl/paddleocr-vl-1_6-qlora.yaml) uses different defaults from my proposed conservative adaptation; replace the example dataset and validate the resulting configuration first. Do not enable unsupported Liger/Cut Cross Entropy paths.

UNVERIFIED T4 fallback: use 4-bit QLoRA, microbatch 1, and FP16 where BF16 is unsupported. Lower image/token budgets only after checking that handwriting remains readable. Free GPU availability and the adapted recipes are not guaranteed.

UNVERIFIED safeguards: hold out writers, doctor styles and some fonts; 400 simulated styles are not 400 real writers. Add legally usable real word crops or consented hand copies. Keep an untouched base and replay some permitted clean examples to detect forgetting. Audit scrawled examples whose full-name labels exceed visible information; otherwise synthetic training can reward guessing. MIRAGE and web photos never enter training.

VERIFIED Mac commands exist; successful conversion and ≤15-second performance remain UNVERIFIED. Merge PEFT adapters into unquantised weights before conversion, retain the vision processor, and compare quantised versus BF16 recall:

```bash
python -m mlx_vlm.convert --hf-path MERGED_MODEL --mlx-path parchi-mlx --quantize --q-bits 4 --q-group-size 64
python -m mlx_vlm generate --model prithivMLmods/LightOnOCR-3-4B-MLX --subfolder 4bit --image crop.jpg --prompt "" --max-tokens 1024 --temperature 0
```

UNVERIFIED decision procedure: if zero-shot recall is below 60%, check version warnings, native prompt, truncation and crop quality once; then reject that branch for this budget. Do not assume font SFT will bridge the gap. Between 60–80%, allow one time-boxed adaptation. At ≥80%, first establish precision, blank-page behaviour and M4 speed; retain the base if adaptation regresses. MIRAGE medicine labels do not validate strength, dose, frequency, duration or lab-test accuracy—those need separately labelled checks.

4. Top 3 things I am least sure of

1. UNVERIFIED: Parrotlet’s handwriting-only performance, complete native prescription schema, exact judge details and independent medicine recall.
2. UNVERIFIED: Parrotlet’s exact MLX conversion and all three candidates’ end-to-end latency on your 16 GB base M4.
3. UNVERIFIED: real-handwriting gains and sample throughput within two training hours; prescription fine-tune cards provide insufficient evidence, and some upstream data rights remain unclear.

Recommendation—UNVERIFIED judgement: test Parrotlet-v-2.5-pro first because it is specifically trained for Indian medical extraction; test LightOnOCR-3-4B second, then PaddleOCR-VL-1.6 as the small deployment candidate. Choose using measured medicine recall and unfiltered precision, followed by actual M4 latency. Train only the strongest eligible base, retain it unless the adapter improves real handwriting without extra false medicines, and abandon any branch still below 60% after its configuration/crop check.