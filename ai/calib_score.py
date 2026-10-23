"""Brand recall of Apple Vision on a synthetic set, split by style. Same key as score_rx.py (first word of the brand)."""
import json, re, sys, collections
d = sys.argv[1]
recs = [json.loads(l) for l in open(f"{d}/labels.jsonl")]
ocr = json.load(open(f"{d}/vision.json"))["results"]
def gold(r):
    s = set()
    for m in r["medicines"]:
        w = re.match(r"[A-Za-z]+", m["name"].split()[0])
        if w and len(w.group(0)) >= 3:
            s.add(w.group(0).upper())
    return s
agg = collections.defaultdict(lambda: [0, 0])
for r in recs:
    f = r["image"].split("/")[-1]
    g = gold(r)
    p = set(t.upper() for l in ocr.get(f, []) for t in re.findall(r"[A-Za-z]+", l["text"]))
    keys = ["all", "handwritten" if not r["printed"] else "printed", r["mode"]]
    if not r["printed"]:
        keys.append(f"messiness={r['messiness']}")
        keys.append("messiness 2-3" if r["messiness"] >= 2 else "messiness 0-1")
    for k in keys:
        agg[k][0] += len(g & p); agg[k][1] += len(g)
for k in sorted(agg):
    tp, n = agg[k]
    print(f"{k:15s} recall {tp / n:6.1%}  ({tp}/{n})")
