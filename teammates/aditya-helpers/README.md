# Aditya helpers

Three independent Python 3.11 modules for Parchi. Read `STATUS.md` for readiness and measured results. Changes stay inside this folder; the lead integrates finished modules later.

## Run all tests in three commands
From this folder:
```powershell
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements.txt
.venv/Scripts/python -m pytest -q
```
On macOS/Linux use `.venv/bin/python`. The implementation sprint used the isolated `.venv311` environment on Windows.

- `problem-helper/README.md`: complaint drafts, sources and local judge demo.
- `hindi-pack/README.md`: extraction, draft sheet and reviewed-only catalog export.
- `delivery-check/README.md`: structured/text comparison and synthetic corpus.
- `NEEDS-LEAD.md`: explicit contract extensions, assumptions and integration decisions.
- `SPECIFICATION.md`: supplied SPEC-4 snapshot from team/specs 599319e.

No app integration is included. Hindi needs native review. Legal-route claims remain secondary-source and unconfirmed. Delivery measurements are synthetic only.
