"""T9 (data half): every bundled row shows where it came from and when. Prints counts; exits 1 on any row without a source URL or date."""
import json, sys
from pathlib import Path
cat = Path(__file__).resolve().parents[1] / "engine/catalogue"
bad, total = [], 0
def walk(name, rows, need):
    global total
    for r in rows:
        total += 1
        miss = [k for k in need if not r.get(k)]
        if miss: bad.append((name, miss, str(r)[:80]))
labs = json.load(open(cat / "labs.json")); walk("labs", labs if isinstance(labs, list) else labs.get("labs", []), ["source_url", "date_seen"])
lp = json.load(open(cat / "lab_prices.json"))
rows = [dict(v, _k=f"{c}/{l}/{t}") for c, ls in lp.items() for l, ts in ls.items() for t, v in ts.items()]
walk("lab_prices", rows, ["source_url", "date_seen"])
pl = json.load(open(cat / "product_links.json"))
rows = [dict(v, _k=f"{m}/{s}") for m, ss in pl.items() for s, v in ss.items()]
walk("product_links", rows, ["date_seen"])
h = json.load(open(cat / "schedule_h1_x.json")); walk("schedule_h1_x", h if isinstance(h, list) else h.get("entries", []), ["source_url", "date"])
print(f"checked {total} rows across labs, lab_prices, product_links, schedule_h1_x; missing source/date: {len(bad)}")
for b in bad[:10]: print("  MISSING", b)
sys.exit(1 if bad else 0)
