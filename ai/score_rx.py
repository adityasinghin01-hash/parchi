"""Score OCR output against MIRAGE-100 medicine labels.
Usage: python -I score_rx.py <labels.json> <ocr.json> <medicine_csv> [threshold]
Modes:
  raw      brand word appears verbatim in OCR text
  lexicon  every OCR word snapped to the nearest catalogue brand (>= threshold)
  guided   lexicon snap only for words after a dosage-form cue (tab/cap/syp/inj...)
           or followed by a strength the catalogue actually lists for that brand
"""
import sys, json, re, csv, collections
from rapidfuzz import process, fuzz

labels = json.load(open(sys.argv[1]))
ocr = json.load(open(sys.argv[2]))["results"]
TH = float(sys.argv[4]) if len(sys.argv) > 4 else 85

# catalogue: brand stem -> set of strength numbers seen in product names
strengths = collections.defaultdict(set)
for r in csv.DictReader(open(sys.argv[3], encoding="utf8")):
    if r["Is_discontinued"].strip().upper() != "FALSE":
        continue
    parts = r["name"].split()
    if not parts:
        continue
    stem = re.sub(r"[^A-Za-z]", "", parts[0]).upper()
    if len(stem) < 3:
        continue
    for n in re.findall(r"\d+(?:\.\d+)?", r["name"]):
        strengths[stem].add(n)
    strengths[stem]  # register stem even without numbers
STEMS = list(strengths)

CUES = {"TAB", "TABS", "TABLET", "CAP", "CAPS", "CAPSULE", "SYP", "SYR", "SYRUP", "INJ", "OINT", "GEL",
        "DROP", "DROPS", "NEB", "MDI", "INH", "SUSP", "CREAM", "LOTION", "SACHET", "PWD", "T", "C"}
STOP = {"ALLERGIES", "HISTORY", "COMPLAINTS", "EXAMINATION", "PROVISIONAL", "FINAL", "DIAGNOSIS", "DRUG",
        "ORDERS", "ADVICE", "DIET", "LIFESTYLE", "REHAB", "INVESTIGATIONS", "HEIGHT", "WEIGHT", "BMI",
        "BEFORE", "AFTER", "MEAL", "MEALS", "DAYS", "DAILY", "MORNING", "NIGHT", "WEEK", "MONTH", "TIMES",
        "FOLLOW", "REVIEW", "WITH", "FOR", "AND", "THE", "NAME", "AGE", "SEX", "DATE", "PATIENT", "DOCTOR",
        "SIGNATURE", "HOSPITAL", "CLINIC", "PULSE", "TEMP"}

def tokens(lines):
    toks = []
    for l in lines:
        for w in re.findall(r"[A-Za-z]+|\d+(?:\.\d+)?", l["text"]):
            toks.append(w)
    return toks

def snap(word):
    m = process.extractOne(word.upper(), STEMS, scorer=fuzz.ratio, score_cutoff=TH)
    return m[0] if m else None

def predict(lines, mode):
    toks = tokens(lines)
    up = [t.upper() for t in toks]
    pred = set()
    if mode == "raw":
        return set(t for t in up if t in strengths)
    for i, t in enumerate(up):
        if not t.isalpha() or len(t) < 4 or t in STOP or t in CUES:
            continue
        if mode == "lexicon":
            s = snap(t)
            if s:
                pred.add(s)
        elif mode == "guided":
            cue = i > 0 and up[i - 1] in CUES
            nxt = up[i + 1] if i + 1 < len(up) else ""
            s = snap(t)
            if not s:
                continue
            strength_ok = bool(re.fullmatch(r"\d+(?:\.\d+)?", nxt)) and nxt in strengths[s]
            if cue or strength_ok:
                pred.add(s)
    return pred

def gold_keys(lbl):
    if not lbl or lbl == "None":
        return set()
    keys = set()
    for item in lbl.split(","):
        w = item.strip().split()
        if w:
            m0 = re.match(r"[A-Za-z]+", w[0]); k = m0.group(0).upper() if m0 else ""
            if len(k) >= 3:
                keys.add(k)
    return keys

for mode in ["raw", "lexicon", "guided"]:
    tp = fp = fn = 0
    per_img_full = 0
    n_img = 0
    for fname, lbl in labels.items():
        g = gold_keys(lbl)
        if not g:
            continue
        n_img += 1
        p = predict(ocr.get(fname, []), mode)
        tp += len(g & p); fp += len(p - g); fn += len(g - p)
        per_img_full += (g <= p)
    prec = tp / (tp + fp) if tp + fp else 0
    rec = tp / (tp + fn) if tp + fn else 0
    f1 = 2 * prec * rec / (prec + rec) if prec + rec else 0
    print(f"{mode:8s} images={n_img} gold={tp+fn} tp={tp} fp={fp} recall={rec:.1%} precision={prec:.1%} F1={f1:.1%} all-meds-found={per_img_full}/{n_img}")
