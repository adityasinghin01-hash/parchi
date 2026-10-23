"""Test a reader (untrained or LoRA) on Parchi test sets. Same scoring as our Mac benchmark:
a medicine counts as found when the first word of its brand (>= 3 letters) matches.

Usage:
  python eval_reader.py --base Qwen/Qwen2.5-VL-7B-Instruct [--lora runs/7b_lora/final_lora] --tag 7b_after \
      --catalogue data/indian_medicine_data.csv \
      --set mirage=data/mirage/orig:data/mirage/labels.json \
      --set mirage_wa1600=data/mirage/wa1600q70:data/mirage/labels.json \
      --set mirage_wa1280=data/mirage/wa1280q50:data/mirage/labels.json \
      --set synth_val=data/synth_val/images:data/synth_val/labels.jsonl \
      --set handcopy_test=data/handcopy/test:data/handcopy/test_labels.json
Labels: MIRAGE-style {"file.jpg": "BRAND A, BRAND B"} or our labels.jsonl. Writes results/<tag>.json + raw outputs.
"""
import argparse, csv, glob, json, os, re, time

import torch
from PIL import Image
from rapidfuzz import fuzz, process
from transformers import AutoProcessor, Qwen2_5_VLForConditionalGeneration

from parchi_prompt import PROMPT

ap = argparse.ArgumentParser()
ap.add_argument("--base", required=True)
ap.add_argument("--lora")
ap.add_argument("--tag", required=True)
ap.add_argument("--catalogue", required=True)
ap.add_argument("--set", action="append", required=True, help="name=image_dir:labels_file")
ap.add_argument("--max-side", type=int, default=1024)
ap.add_argument("--batch", type=int, default=8)
a, _ = ap.parse_known_args()

STEMS = set()
for r in csv.DictReader(open(a.catalogue, encoding="utf8")):
    if r["Is_discontinued"].strip().upper() == "FALSE" and r["name"].split():
        s = re.sub(r"[^A-Za-z]", "", r["name"].split()[0]).upper()
        if len(s) >= 3:
            STEMS.add(s)
STEMS = sorted(STEMS)
FORM = r"^(tab\.?|tablet|t\.|cap\.?|capsule|c\.|syp\.?|syrup|syr\.?|inj\.?|injection|sachet|susp\.?|drops?|oint\.?)\s+"


def key(name):
    n = re.sub(FORM, "", (name or "").strip(), flags=re.I)
    w = re.match(r"[A-Za-z]+", n)
    return w.group(0).upper() if w and len(w.group(0)) >= 3 else None


def load_labels(path):
    if path.endswith(".jsonl"):
        out = {}
        for l in open(path, encoding="utf8"):
            r = json.loads(l)
            out[os.path.basename(r["image"])] = {k for k in (key(m["name"]) for m in r["medicines"]) if k}
        return out
    d = json.load(open(path, encoding="utf8"))
    return {f: ({k for k in (key(x) for x in v.split(",")) if k} if isinstance(v, str) and v.strip() and v != "None" else set())
            for f, v in d.items()}


def parse(text):
    m = re.search(r"\{.*\}", text, re.S)
    try:
        d = json.loads(m.group(0)) if m else {}
    except Exception:
        d = {}
    meds = d.get("medicines", []) if isinstance(d, dict) else []
    return [x.get("name", "") if isinstance(x, dict) else str(x) for x in meds]


def snap(k):
    m = process.extractOne(k, STEMS, scorer=fuzz.ratio, score_cutoff=85)
    return m[0] if m else None


def score(golds, preds, use_snap=False):
    tp = fp = fn = full = n = blank_fp = 0
    for f, g in golds.items():
        p = {k for k in (key(x) for x in preds.get(f, [])) if k}
        if use_snap:
            p = {snap(k) or k for k in p}
        if not g:
            blank_fp += len(p)
            continue
        n += 1; tp += len(g & p); fp += len(p - g); fn += len(g - p); full += g <= p
    P = tp / (tp + fp) if tp + fp else 0
    R = tp / (tp + fn) if tp + fn else 0
    return {"images": n, "recall": round(R, 4), "precision": round(P, 4), "f1": round(2 * P * R / (P + R), 4) if P + R else 0,
            "all_found": full, "names_on_blank_pages": blank_fp}


processor = AutoProcessor.from_pretrained(a.lora or a.base, min_pixels=128 * 28 * 28, max_pixels=1280 * 28 * 28)
processor.tokenizer.padding_side = "left"
model = Qwen2_5_VLForConditionalGeneration.from_pretrained(a.base, torch_dtype=torch.bfloat16, attn_implementation="sdpa").cuda()
if a.lora:
    from peft import PeftModel
    model = PeftModel.from_pretrained(model, a.lora)
model.eval()
msgs = [{"role": "user", "content": [{"type": "image"}, {"type": "text", "text": PROMPT}]}]
prompt = processor.apply_chat_template(msgs, tokenize=False, add_generation_prompt=True)

os.makedirs("results", exist_ok=True)
results = {}
for spec in a.set:
    name, rest = spec.split("=", 1)
    img_dir, lab = rest.split(":", 1)
    golds = load_labels(lab)
    files = [f for f in sorted(golds) if os.path.exists(os.path.join(img_dir, f))]
    raw, t0 = {}, time.time()
    for i in range(0, len(files), a.batch):
        chunk = files[i:i + a.batch]
        ims = []
        for f in chunk:
            im = Image.open(os.path.join(img_dir, f)).convert("RGB"); im.thumbnail((a.max_side, a.max_side)); ims.append(im)
        enc = processor(text=[prompt] * len(ims), images=ims, return_tensors="pt", padding=True).to("cuda")
        with torch.no_grad():
            out = model.generate(**enc, max_new_tokens=384, do_sample=False)
        for f, o in zip(chunk, processor.batch_decode(out[:, enc["input_ids"].shape[1]:], skip_special_tokens=True)):
            raw[f] = o
    preds = {f: parse(t) for f, t in raw.items()}
    golds = {f: golds[f] for f in files}
    results[name] = {"plain": score(golds, preds), "snapped_to_catalogue": score(golds, preds, True),
                     "sec_per_image": round((time.time() - t0) / max(1, len(files)), 2)}
    json.dump(raw, open(f"results/{a.tag}_{name}_raw.json", "w"), indent=1, ensure_ascii=False)
    print(a.tag, name, results[name], flush=True)
json.dump(results, open(f"results/{a.tag}.json", "w"), indent=1)
