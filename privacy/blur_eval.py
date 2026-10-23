"""Blur recall on synthetic parchis with known PII boxes. A PII box counts as hidden if >= 80% of its area is under blur.
Also reports over-blur: medicine boxes with >= 30% of their area blurred (that would hurt reading).
Usage: python -I blur_eval.py <labels.jsonl> <blur.json>"""
import json, sys, collections
import numpy as np
recs = [json.loads(l) for l in open(sys.argv[1])]
blur = json.load(open(sys.argv[2]))
def covered(box, boxes, W, H):
    x0, y0, x1, y1 = [int(v) for v in box]
    x0, y0, x1, y1 = max(0, x0), max(0, y0), min(W, x1), min(H, y1)
    if x1 <= x0 or y1 <= y0: return 0.0
    m = np.zeros((y1 - y0, x1 - x0), bool)
    for b in boxes:
        a0, b0, a1, b1 = max(b[0], x0), max(b[1], y0), min(b[2], x1), min(b[3], y1)
        if a1 > a0 and b1 > b0: m[b0 - y0:b1 - y0, a0 - x0:a1 - x0] = True
    return m.mean()
agg = collections.defaultdict(lambda: [0, 0]); over = [0, 0]; rules = collections.Counter(); misses = []
for r in recs:
    f = r["image"].split("/")[-1]; W, H = r["size"]; b = blur.get(f, {"boxes": [], "rule": "missing"})
    rules[b["rule"]] += 1
    for p in r["pii"]:
        c = covered(p["box"], b["boxes"], W, H)
        for k in [p["type"], "all_pii"] + (["names_" + r["mode"]] if p["type"] == "patient_name" else []):
            agg[k][0] += c >= 0.8; agg[k][1] += 1
        if p["type"] == "patient_name" and c < 0.8: misses.append((f, round(c, 2), b["rule"]))
    for m in r["medicines"]:
        if m["box"]:
            over[1] += 1; over[0] += covered(m["box"], b["boxes"], W, H) >= 0.3
for k in sorted(agg): print(f"{k:22s} hidden {agg[k][0] / agg[k][1]:6.1%} ({agg[k][0]}/{agg[k][1]})")
print(f"medicine lines over-blurred: {over[0] / over[1]:.1%} ({over[0]}/{over[1]})")
print("rule used:", dict(rules))
print("name misses (first 12):", misses[:12])
