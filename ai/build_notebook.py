"""Builds parchi_kaggle_train.ipynb: synthetic data -> zero-shot test -> LoRA -> test again.
Run: python3 build_notebook.py   (embeds parchi_synth.py into the notebook so Kaggle needs no upload)
"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
SYNTH = open(os.path.join(HERE, "parchi_synth.py"), encoding="utf8").read()

cells = []
md = lambda s: cells.append({"cell_type": "markdown", "metadata": {}, "source": s.strip("\n")})
code = lambda s: cells.append({"cell_type": "code", "metadata": {}, "execution_count": None, "outputs": [], "source": s.strip("\n")})

md("""
# Parchi reader: train on free Kaggle GPU (₹0)
Makes synthetic Indian prescriptions, tests Qwen2.5-VL-3B **before** training on real MIRAGE-100 prescriptions,
trains a LoRA on the synthetic set, then tests again on MIRAGE-100, its WhatsApp-style copies and a synthetic
hold-out set (new doctors).

**Before you press Run all:** Settings → Accelerator **GPU T4 x2** · Internet **On** (needs a phone-verified Kaggle account).
Optional: attach the 12 web photos as a **private** dataset (never public: copyright + patient names).

Rough time on a T4: data 35 min · test before 15 min · training 60–90 min · tests after 40 min.
MIRAGE-100 is **test only** (CC BY-ND 4.0); it is never trained on.
""")

code("""
%%capture
!pip install -q unsloth rapidfuzz
""")
md("If the model cell fails on `import unsloth`, use Run → Restart & clear outputs, then Run all again (the install is cached).")

code("""
# ---- settings
N_TRAIN, N_VAL = 4000, 150          # synthetic images
MODEL = "unsloth/Qwen2.5-VL-3B-Instruct-bnb-4bit"
MAX_SIDE = 1024                     # long side in pixels fed to the model (~900 image tokens)
EPOCHS, LR, R = 1, 2e-4, 16         # LoRA settings (Unsloth vision defaults)
BATCH, ACCUM = 2, 4
RUN_BEFORE = True                   # zero-shot test before training
SAVE_MERGED = False                 # True also writes a merged 16-bit model (~7 GB) for MLX conversion
WORK = "/kaggle/working"
import os; os.chdir(WORK)
""")

cells.append({"cell_type": "code", "metadata": {}, "execution_count": None, "outputs": [],
              "source": "%%writefile parchi_synth.py\n" + SYNTH})

code("""
!python parchi_synth.py fetch --assets assets > /dev/null
!curl -sL -o catalogue.csv https://raw.githubusercontent.com/junioralive/Indian-Medicine-Dataset/main/DATA/indian_medicine_data.csv
!python -c "from PIL import features; print('raqm (Hindi/regional text):', features.check('raqm'))"
!python parchi_synth.py gen --assets assets --catalogue catalogue.csv --out synth_train --n {N_TRAIN} --seed 11 --doctors 400 --workers 4
!python parchi_synth.py gen --assets assets --catalogue catalogue.csv --out synth_val --n {N_VAL} --seed 12 --doctors 60 --workers 4
""")

code("""
# ---- MIRAGE-100 (IIT Bombay, real Indian handwriting) + WhatsApp-style copies. Test only.
import io, json, re, glob, time, collections
import pandas as pd
from PIL import Image
from huggingface_hub import hf_hub_download
p = hf_hub_download("chaithanyakota/100-handwritten-medical-records", "data/train-00000-of-00001.parquet", repo_type="dataset")
df = pd.read_parquet(p)
os.makedirs("mirage/orig", exist_ok=True); os.makedirs("mirage/wa1600q70", exist_ok=True); os.makedirs("mirage/wa1280q50", exist_ok=True)
MIRAGE = {}
for i, r in df.iterrows():
    img = r["image"]; b = img["bytes"] if isinstance(img, dict) else img
    fn = f"rx{i:03d}.jpg"
    im = Image.open(io.BytesIO(b)).convert("RGB"); im.save(f"mirage/orig/{fn}", quality=95)
    for side, q, d in [(1600, 70, "wa1600q70"), (1280, 50, "wa1280q50")]:
        c = im.copy(); c.thumbnail((side, side)); c.save(f"mirage/{d}/{fn}", quality=q)
    MIRAGE[fn] = r["medicines"] if isinstance(r["medicines"], str) else None
FRONTIER16 = [f"rx{i:03d}.jpg" for i in range(10, 30)]   # the 20 images (16 with medicines) a frontier model read blind: 82.1% recall
print(len(MIRAGE), "MIRAGE images")
""")

code('''
# ---- reading + scoring (same key as our Mac benchmark: first word of each brand, >=3 letters)
from rapidfuzz import process, fuzz
import csv
PROMPT = ("You are reading an Indian doctor's prescription (parchi). List every medicine and every lab test "
          "exactly as written. Reply with JSON only: {\\"medicines\\":[{\\"name\\":\\"brand and strength\\",\\"form\\":\\"Tab/Cap/Syp/...\\","
          "\\"dose\\":\\"...\\",\\"duration\\":\\"...\\"}],\\"tests\\":[\\"...\\"]}. If there are none, use empty lists.")
STEMS = set()
for r in csv.DictReader(open("catalogue.csv", encoding="utf8")):
    if r["Is_discontinued"].strip().upper() == "FALSE" and r["name"].split():
        s = re.sub(r"[^A-Za-z]", "", r["name"].split()[0]).upper()
        if len(s) >= 3: STEMS.add(s)
STEMS = sorted(STEMS)

def load(path):
    im = Image.open(path).convert("RGB"); im.thumbnail((MAX_SIDE, MAX_SIDE)); return im

def key(name):
    w = re.match(r"[A-Za-z]+", (name or "").strip().split()[0]) if (name or "").strip() else None
    return w.group(0).upper() if w and len(w.group(0)) >= 3 else None

def gold_mirage(lbl):
    if not isinstance(lbl, str) or not lbl.strip() or lbl == "None": return set()
    return {k for k in (key(x) for x in lbl.split(",")) if k}

def parse(text):
    m = re.search(r"\\{.*\\}", text, re.S)
    try:
        d = json.loads(m.group(0)) if m else {}
    except Exception:
        d = {}
    meds = d.get("medicines", []) if isinstance(d, dict) else []
    names = [x.get("name", "") if isinstance(x, dict) else str(x) for x in meds]
    if not names:  # fall back to "Tab X" style lines
        names = re.findall(r"(?:tab|cap|syp|inj)\\.?\\s+([A-Za-z][\\w-]+)", text, re.I)
    return names

def snap(k):
    m = process.extractOne(k, STEMS, scorer=fuzz.ratio, score_cutoff=85)
    return m[0] if m else None

def score(golds, preds, use_snap=False):
    tp = fp = fn = full = n = blank_fp = 0
    for f, g in golds.items():
        p = {k for k in (key(x) for x in preds.get(f, [])) if k}
        if use_snap: p = {snap(k) or k for k in p}
        if not g:
            blank_fp += len(p); continue
        n += 1; tp += len(g & p); fp += len(p - g); fn += len(g - p); full += g <= p
    P = tp / (tp + fp) if tp + fp else 0; Rc = tp / (tp + fn) if tp + fn else 0
    return {"images": n, "recall": round(Rc, 4), "precision": round(P, 4), "f1": round(2 * P * Rc / (P + Rc), 4) if P + Rc else 0,
            "all_found": full, "false_names_on_blank_pages": blank_fp}

def read_all(model, tok, paths):
    from unsloth import FastVisionModel
    FastVisionModel.for_inference(model)
    out, raw, t0 = {}, {}, time.time()
    msgs = [{"role": "user", "content": [{"type": "image"}, {"type": "text", "text": PROMPT}]}]
    prompt = tok.apply_chat_template(msgs, add_generation_prompt=True)
    for pth in paths:
        x = tok(load(pth), prompt, add_special_tokens=False, return_tensors="pt").to("cuda")
        y = model.generate(**x, max_new_tokens=384, use_cache=True, do_sample=False)
        txt = tok.decode(y[0][x["input_ids"].shape[1]:], skip_special_tokens=True)
        raw[os.path.basename(pth)] = txt; out[os.path.basename(pth)] = parse(txt)
    return out, raw, (time.time() - t0) / max(1, len(paths))

def synth_golds(d):
    recs = [json.loads(l) for l in open(f"{d}/labels.jsonl")]
    return {os.path.basename(r["image"]): {k for k in (key(m["name"]) for m in r["medicines"]) if k} for r in recs}

RESULTS = {}
def evaluate(tag, model, tok, sets):
    for name, (paths, golds) in sets.items():
        preds, raw, sec = read_all(model, tok, paths)
        RESULTS[f"{tag}/{name}"] = {"plain": score(golds, preds), "snapped_to_catalogue": score(golds, preds, True), "sec_per_image": round(sec, 2)}
        json.dump(raw, open(f"raw_{tag}_{name}.json", "w"), indent=1, ensure_ascii=False)
        print(tag, name, RESULTS[f"{tag}/{name}"])
    json.dump(RESULTS, open("results.json", "w"), indent=1)

GM = {f: gold_mirage(v) for f, v in MIRAGE.items()}
SETS_BEFORE = {"mirage_orig": (sorted(glob.glob("mirage/orig/*.jpg")), GM)}
SV = synth_golds("synth_val")
SETS_AFTER = {"mirage_orig": (sorted(glob.glob("mirage/orig/*.jpg")), GM),
              "mirage_wa1600q70": (sorted(glob.glob("mirage/wa1600q70/*.jpg")), GM),
              "mirage_wa1280q50": (sorted(glob.glob("mirage/wa1280q50/*.jpg")), GM),
              "synth_val_new_doctors": (sorted(glob.glob("synth_val/images/*.jpg")), SV)}
''')

code("""
from unsloth import FastVisionModel
import torch
model, tok = FastVisionModel.from_pretrained(MODEL, load_in_4bit=True, use_gradient_checkpointing="unsloth")
if RUN_BEFORE:
    evaluate("before", model, tok, SETS_BEFORE)
    sub = {f: GM[f] for f in FRONTIER16}
    print("before, frontier subset:", score(sub, {f: parse(t) for f, t in json.load(open("raw_before_mirage_orig.json")).items()}))
""")

code("""
# ---- LoRA training on the synthetic set (images loaded lazily, so RAM stays small)
from unsloth.trainer import UnslothVisionDataCollator
from trl import SFTTrainer, SFTConfig
model = FastVisionModel.get_peft_model(model, finetune_vision_layers=True, finetune_language_layers=True,
                                       finetune_attention_modules=True, finetune_mlp_modules=True,
                                       r=R, lora_alpha=R, lora_dropout=0, bias="none", random_state=3407)
recs = [json.loads(l) for l in open("synth_train/labels.jsonl")]

class RxSet(torch.utils.data.Dataset):
    def __len__(self): return len(recs)
    def __getitem__(self, i):
        r = recs[i]
        return {"messages": [
            {"role": "user", "content": [{"type": "text", "text": PROMPT}, {"type": "image", "image": load("synth_train/" + r["image"])}]},
            {"role": "assistant", "content": [{"type": "text", "text": r["target"]}]}]}

FastVisionModel.for_training(model)
CFG = dict(model=model, data_collator=UnslothVisionDataCollator(model, tok), train_dataset=RxSet())
ARGS = SFTConfig(per_device_train_batch_size=BATCH, gradient_accumulation_steps=ACCUM, warmup_ratio=0.03,
                   num_train_epochs=EPOCHS, learning_rate=LR, logging_steps=10, optim="adamw_8bit", weight_decay=0.01,
                   lr_scheduler_type="cosine", seed=3407, output_dir="outputs", report_to="none", save_strategy="no",
                   remove_unused_columns=False, dataset_text_field="", dataset_kwargs={"skip_prepare_dataset": True},
                   max_length=2048, dataloader_num_workers=2)
try:
    trainer = SFTTrainer(**CFG, processing_class=tok.tokenizer, args=ARGS)   # newer TRL
except TypeError:
    trainer = SFTTrainer(**CFG, tokenizer=tok, args=ARGS)                   # older TRL
t0 = time.time(); stats = trainer.train(); RESULTS["train_minutes"] = round((time.time() - t0) / 60, 1)
model.save_pretrained("parchi_lora"); tok.save_pretrained("parchi_lora")
print(stats)
""")

code("""
evaluate("after", model, tok, SETS_AFTER)
sub = {f: GM[f] for f in FRONTIER16}
print("after, frontier subset:", score(sub, {f: parse(t) for f, t in json.load(open("raw_after_mirage_orig.json")).items()}))
web = sorted(glob.glob("/kaggle/input/*/web*.jp*g")) + sorted(glob.glob("/kaggle/input/*/web*.png"))
if web:  # private web photos: no gold labels yet, so predictions are saved for a human check
    preds, raw, sec = read_all(model, tok, web)
    json.dump(raw, open("raw_after_web.json", "w"), indent=1, ensure_ascii=False)
    print("web photos read:", len(web), "sec/image", round(sec, 2))
""")

code("""
# ---- summary + files to download (results.json, raw_*.json, parchi_lora/)
for k, v in RESULTS.items(): print(k, v)
if SAVE_MERGED:
    model.save_pretrained_merged("parchi_merged", tok)
!zip -qr parchi_lora.zip parchi_lora results.json raw_*.json
print("download /kaggle/working/parchi_lora.zip")
""")

nb = {"cells": cells, "metadata": {"kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
                                   "language_info": {"name": "python"}}, "nbformat": 4, "nbformat_minor": 5}
for c in nb["cells"]:
    c["source"] = c["source"].splitlines(keepends=True)
json.dump(nb, open(os.path.join(HERE, "parchi_kaggle_train.ipynb"), "w"), indent=1, ensure_ascii=False)
print("wrote parchi_kaggle_train.ipynb with", len(cells), "cells")
