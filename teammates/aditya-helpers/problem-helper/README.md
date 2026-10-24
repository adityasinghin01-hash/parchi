# Order problem helper — READY (standalone module)

Drafts factual English/Hindi order complaints, with evidence and sourced next steps.
The person reviews and sends the message themselves. Nothing is sent automatically.
Works offline with the supplied dated contact snapshots.
No app integration, money handling or legal advice.
Hindi and precaution wording still require human review.

## Run in three commands
From `teammates/aditya-helpers/` (Python 3.11):
```powershell
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements.txt
.venv/Scripts/python -m pytest problem-helper/tests -q
```
On macOS/Linux use `.venv/bin/python` instead. The sprint used `.venv311` on Windows.
CLI: set `PYTHONPATH=problem-helper/src`, then run `python -m problem_helper problem-helper/example.json`. Local judge demo: `python problem-helper/demo/serve.py`, open `http://127.0.0.1:8040`. The local server makes no outgoing calls and stores no requests. It is a demonstration server, not a deployment service.

## Contract
`problem_helper.generate(payload) -> dict`; deterministic and side-effect-free. Full JSON input is in `example.json`, full corresponding output in `tests/golden/refund_en.json`. See `../SPECIFICATION.md` for all input fields and issue values. Output contains `message`, `evidence`, `ladder`, `followUps`, `notes`, `disclaimer`, plus structured `precautions` with `reviewed: false`. Invalid languages, issues, dates, negative amounts, invalid object shapes and unsupported seller kinds raise `ValueError`.

```python
from problem_helper import generate
result = generate({"lang":"en","issue":"missing_item",
 "seller":{"name":"Example local shop","kind":"local_shop"},
 "order":{"orderId":"SYN-1","placedOn":"2026-10-20",
          "amountPaise":10000,"paidVia":"cash",
          "items":[{"name":"Dolo","strength":"650","qty":15}],"isTestOrder":False},
 "events":{},"today":"2026-10-30"})
assert [step["level"] for step in result["ladder"]] == [1,3]
assert result["followUps"] == []
```
`events.grievanceSentOn` is an optional extension recording the actual send date. Without it, follow-ups are labelled `basis: planned` and must be recomputed after sending. The +2-day support wait and +30-day reminder are labelled assumptions, not verified legal deadlines. NCH is offered conditionally if no acknowledgement arrives; the module cannot observe a seller reply.

## Files
`src/problem_helper/`: generator, contact parser, JSON CLI. `data/`: supplied contacts/routes plus JSON message templates. `tests/`: acceptance/regression suite and six fixed golden cases. `demo/`: local page and Python server. `RESULTS.md` / `test-output.txt`: measured evidence.

## Honest limits
The rules are from secondary sources only and output says **check on the official site**. Contact provenance is preserved, not reverified online. No refund completion time is promised. +30 days does not mean one calendar month. A native speaker has not reviewed Hindi; precaution wording has `reviewed: false`. An issue code describes what the person reports; the helper cannot prove it happened. The supplied order amount is shown as context and is not assumed to be the refund amount. Review the draft before use.
