"""Score the Parchi usability sheet. Usage: python3 sus_score.py sus_results.csv"""
import csv, statistics, sys

T95 = {2: 12.71, 3: 4.30, 4: 3.18, 5: 2.78, 6: 2.57, 7: 2.45, 8: 2.36, 9: 2.31, 10: 2.26, 12: 2.20, 15: 2.14, 20: 2.09}

rows = list(csv.DictReader(open(sys.argv[1], encoding="utf8")))
sus = []
for r in rows:
    q = [int(r[f"q{i}"]) for i in range(1, 11)]
    sus.append(2.5 * sum((v - 1) if i % 2 == 0 else (5 - v) for i, v in enumerate(q)))
n = len(sus)
mean = statistics.mean(sus)
print(f"SUS n={n} mean={mean:.1f} median={statistics.median(sus):.1f}", end="")
if n > 1:
    t = T95.get(n, T95[max(k for k in T95 if k <= n)])
    half = t * statistics.stdev(sus) / n ** 0.5
    print(f" 95% CI {mean - half:.1f}–{mean + half:.1f}")
else:
    print()
for k in ["T1", "T2", "T3", "T4"]:
    ok = [r[f"{k}_ok"].strip().upper() in ("Y", "1", "YES") for r in rows]
    secs = [float(r[f"{k}_s"]) for r in rows if r[f"{k}_s"]]
    taps = [float(r[f"{k}_taps"]) for r in rows if r[f"{k}_taps"]]
    print(f"{k}: success {sum(ok)}/{n}, median {statistics.median(secs) if secs else '-'} s, median {statistics.median(taps) if taps else '-'} taps")
