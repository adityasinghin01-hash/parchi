"""Read MIRAGE-100 with a local MLX vision model on Apple Silicon; same prompt and scoring as the Kaggle notebook.
Usage: .venv-mlx/bin/python mac_read_mirage.py <image_dir> <labels.json> <catalogue.csv> <out.json> [model] [adapter]
"""
import csv, json, os, re, sys, tempfile, time
from PIL import Image
from rapidfuzz import process, fuzz
from mlx_vlm import load, generate
from mlx_vlm.prompt_utils import apply_chat_template

img_dir, labels_path, cat_path, out_path = sys.argv[1:5]
MODEL = sys.argv[5] if len(sys.argv) > 5 else "mlx-community/Qwen2.5-VL-3B-Instruct-4bit"
ADAPTER = sys.argv[6] if len(sys.argv) > 6 else None
MAX_SIDE = 1024
PROMPT = ("You are reading an Indian doctor's prescription (parchi). List every medicine and every lab test "
          "exactly as written. Reply with JSON only: {\"medicines\":[{\"name\":\"brand and strength\",\"form\":\"Tab/Cap/Syp/...\","
          "\"dose\":\"...\",\"duration\":\"...\"}],\"tests\":[\"...\"]}. If there are none, use empty lists.")

STEMS = set()
for r in csv.DictReader(open(cat_path, encoding="utf8")):
    if r["Is_discontinued"].strip().upper() == "FALSE" and r["name"].split():
        s = re.sub(r"[^A-Za-z]", "", r["name"].split()[0]).upper()
        if len(s) >= 3:
            STEMS.add(s)
STEMS = sorted(STEMS)


def key(name):
    w = re.match(r"[A-Za-z]+", (name or "").strip().split()[0]) if (name or "").strip() else None
    return w.group(0).upper() if w and len(w.group(0)) >= 3 else None


def gold(lbl):
    if not isinstance(lbl, str) or not lbl.strip() or lbl == "None":
        return set()
    return {k for k in (key(x) for x in lbl.split(",")) if k}


def parse(text):
    m = re.search(r"\{.*\}", text, re.S)
    try:
        d = json.loads(m.group(0)) if m else {}
    except Exception:
        d = {}
    meds = d.get("medicines", []) if isinstance(d, dict) else []
    names = [x.get("name", "") if isinstance(x, dict) else str(x) for x in meds]
    if not names:
        names = re.findall(r"(?:tab|cap|syp|inj)\.?\s+([A-Za-z][\w-]+)", text, re.I)
    return names


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
            "all_found": full, "false_names_on_blank_pages": blank_fp}


labels = json.load(open(labels_path))
model, processor = load(MODEL, ADAPTER) if ADAPTER else load(MODEL)
prompt = apply_chat_template(processor, model.config, PROMPT, num_images=1)
done = json.load(open(out_path)) if os.path.exists(out_path) else {"raw": {}, "sec": {}}
tmp = tempfile.mkdtemp()
for f in sorted(labels):
    if f in done["raw"]:
        continue
    im = Image.open(os.path.join(img_dir, f)).convert("RGB")
    im.thumbnail((MAX_SIDE, MAX_SIDE))
    p = os.path.join(tmp, f)
    im.save(p, quality=95)
    t0 = time.time()
    res = generate(model, processor, prompt, [p], max_tokens=384, temperature=0.0, verbose=False)
    done["raw"][f] = getattr(res, "text", res)
    done["sec"][f] = round(time.time() - t0, 2)
    json.dump(done, open(out_path, "w"), indent=1, ensure_ascii=False)
    print(f, done["sec"][f], "s", flush=True)

preds = {f: parse(t) for f, t in done["raw"].items()}
golds = {f: gold(labels[f]) for f in done["raw"]}
front = {f: golds[f] for f in golds if 10 <= int(f[2:5]) <= 29}
secs = sorted(done["sec"].values())
summary = {"model": MODEL, "adapter": ADAPTER, "plain": score(golds, preds), "snapped_to_catalogue": score(golds, preds, True),
           "frontier_subset_plain": score(front, preds), "median_sec_per_image": secs[len(secs) // 2]}
done["summary"] = summary
json.dump(done, open(out_path, "w"), indent=1, ensure_ascii=False)
print(json.dumps(summary, indent=1))
