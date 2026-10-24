# Delivery check — READY (standalone, synthetic validation)

Compares a confirmed list with received text or structured fields.
Checks brand, strength, units and expiry without replacing brands silently.
Unknown fields require checking; every finding remains visible.
Includes a conservative pack-text parser and a complaint-helper adapter.
Does not read photos or decide what someone should take.

## Run in three commands
From `teammates/aditya-helpers/` (Python 3.11):
```powershell
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements.txt
.venv/Scripts/python -m pytest delivery-check/tests -q
```
On macOS/Linux use `.venv/bin/python`; this sprint used `.venv311`.
With `PYTHONPATH=delivery-check/src`, run `python -m delivery_check delivery-check/example.json`. Rebuild evidence with `python delivery-check/corpus/make_corpus.py` and `python delivery-check/corpus/evaluate.py`.

## Contract and full example
`delivery_check.compare(payload, catalogue_dir=None) -> dict`. Pure JSON-shaped input/output, no network or input mutation. Reads `brand_strengths.json`, `brand_schedule.json` and `DATA_VERSION.json` from the repo catalogue, or the caller's `catalogue_dir`. Unknown confirmed names/strengths remain unreadable. Full runnable input: `example.json`.
```python
from delivery_check import compare
result = compare({
 "confirmed":[{"itemId":"dolo","name":"Dolo","strength":"650","qty":15}],
 "received":[{"rawText":"DOLO 650 Tablet strip of 15 EXP 08/2027 B.No ABC123"}],
 "options":{"today":"2026-10-24","minMonthsToExpiry":3,"approvedSubstituteBrands":[]}
})
assert result["lines"][0]["verdict"] == "ok"
assert result["lines"][0]["receivedIndices"] == [0]
assert result["extra"] == []
```
Output: `lines` with itemId/verdict/message/messageHi/severity, plus all `findings` and their received indices; `extra`; `summary`; assumptions in `notes`; catalogue build date. The complete example output is in `example-output.json`.

Optional fields: `received[].itemId` explicitly associates a pack with a line. Exact brand/strength matches are associated first; a single unmatched pair can show a mismatch. Multiple unassociated mismatches stay missing + extra. Multiple packs of the same matched item contribute their units, but any pack's expired/unknown fields remain findings.

Primary verdict priority: expired, brand_differs, strength_differs, unreadable, quantity_short, expiry_soon, likely_ok, ok. Missing applies when no pack was associated. Original findings are never discarded. Real catalogue brand identity precedes OCR tolerance. Approved alternatives remain tentative.

No unit conversion occurs. Bare numeric strengths compare numerically (0.5 equals .5). If the received strength specifies a unit while the confirmed value omits it, the result is unreadable until the confirmed unit is supplied. Explicit unequal units produce a mismatch. `unitsKind` defaults to count for confirmed quantities; use `unitsKind: ml` explicitly for liquid volumes.

`parse_pack_text(text)` returns brand, strength, units, expiry and batch plus `brandCandidate` and `unitsKind`. Unknown brand stays null; its observed token can be tentatively compared. Month-only expiry means its last day. Two-digit years mean 2000–2099. Conflicting expiry labels remain unknown.

`to_problem_helper_input(line, order_info)` maps supported bad verdicts to A's issue codes; returns None for other verdicts. It does not send anything.

## Files
`src/delivery_check/`: parser, comparison function, adapter and CLI. `tests/`: rules, boundaries, 30 hand-authored strip texts, synthetic gold and regression checks. `corpus/`: reproducible scenario generator, 390 cases, evaluator and metrics. `RESULTS.md` / `test-output.txt`: measured output.

## Honest limits
Synthetic text only: **no real photo or delivered package was tested**. The 3-month expiry threshold is an ASSUMPTION and configurable. The 2022-era source catalogue can miss newer brands; its 2026 build date does not establish current completeness. New confirmed brands and ambiguous pack text remain unreadable. The parser expects one pack's text per received entry; it does not count physical packs or independently verify typed details. English/Hindi messages are not clinical advice; Hindi is unreviewed. Matching checked fields is not a judgement about using a medicine. Lead integration and further real-text testing remain separate.
