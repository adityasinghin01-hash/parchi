# Delivery check — measured results

Commands from `teammates/aditya-helpers/`:
```powershell
python delivery-check/corpus/make_corpus.py
python delivery-check/corpus/evaluate.py
python -m pytest delivery-check/tests -q
```

Runtime: Python 3.11.16.

```text
........................................................................ [ 15%]
........................................................................ [ 31%]
........................................................................ [ 46%]
........................................................................ [ 62%]
........................................................................ [ 77%]
........................................................................ [ 93%]
...............................                                          [100%]
463 passed in 3.39s
```

```json
{
  "synthetic": true,
  "cases": 390,
  "correct": 390,
  "accuracy": 1.0,
  "perVerdict": {
    "ok": {
      "correct": 60,
      "total": 60,
      "accuracy": 1.0
    },
    "strength_differs": {
      "correct": 30,
      "total": 30,
      "accuracy": 1.0
    },
    "brand_differs": {
      "correct": 30,
      "total": 30,
      "accuracy": 1.0
    },
    "expired": {
      "correct": 30,
      "total": 30,
      "accuracy": 1.0
    },
    "expiry_soon": {
      "correct": 30,
      "total": 30,
      "accuracy": 1.0
    },
    "quantity_short": {
      "correct": 30,
      "total": 30,
      "accuracy": 1.0
    },
    "missing": {
      "correct": 30,
      "total": 30,
      "accuracy": 1.0
    },
    "likely_ok": {
      "correct": 60,
      "total": 60,
      "accuracy": 1.0
    },
    "unreadable": {
      "correct": 90,
      "total": 90,
      "accuracy": 1.0
    }
  },
  "criticalCases": 120,
  "dangerousErrors": 0,
  "dangerousErrorRate": 0.0,
  "criticalErrorCases": [],
  "errors": []
}
```

The dangerous-error denominator is the 120 cases whose gold verdict is strength_differs, brand_differs, expired or missing. A dangerous error is one of those reported as ok/likely_ok. Every error would be listed in corpus/metrics.json. **This is a synthetic corpus, not real prescription, photo, package or patient validation.** Gold labels are assigned by scenarios, not copied from engine predictions. Thirty fixed, hand-authored strip strings separately test the parser.

Review fixes: avoid reading a strength followed by Tablet as the pack quantity; do not repair a different real brand as an OCR typo; retain all findings behind the primary verdict; flag conflicting raw/structured fields and expiry labels; require quantity dimensions to agree; do not infer a missing confirmed strength unit from the numeric catalogue. Leap-year, month-end and threshold boundaries are covered.
