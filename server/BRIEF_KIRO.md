# Kiro task S: finish the Parchi Orchestrator server so ALL tests pass on the lab iMac

You are the hands; Claude is the instructor and will re-run everything you report. Work only inside `server/` (this folder). Do NOT git commit. Do NOT touch the Temporal dev server on the iMac (localhost:7233 must keep running).

## Read first (in this order)
1. `BRIEF.md` = the full approved spec (workflow, activities, API, tests, run scripts). Follow it.
2. `docs/implementation.md` = design decisions already taken (signal inbox, proposal validation, nothing-available rule, reset order).
3. `contract.py`, `db.py`, `activities.py` = already written, keep their behaviour.
4. `tests/` = the acceptance contract (written first by another agent). Read `conftest.py`, `test_workflows.py`, `test_api.py` closely: they fix names and shapes (e.g. `OrderWorkflow` in `workflows.py`, query `snapshot` with a `ready` flag, signals `seller_event`/`proposal`/`approve`/`reject`, `api.app`, `api.get_temporal`, `auth.issue_key`, `auth.limiter`).
Do not weaken or delete tests. If a test truly contradicts BRIEF.md, fix it minimally and list the change in your report.

## Files still missing (create them)
`workflows.py`, `auth.py`, `api.py`, `worker.py`, `run.sh`, `stop.sh`, `README.md` (15 lines max), `restart_check.py`, and `requirements.txt` (must include temporalio==1.34.0, fastapi, uvicorn, pytest, httpx, python-multipart).
Style: short plain Python 3.11, type hints, comments only for WHY.

## How to test (the MacBook only edits files; Python runs on the iMac)
```
rsync -az --exclude .venv --exclude data --exclude __pycache__ --exclude .pytest_cache --exclude '*.db' --exclude '*.log' ./ imac:parchi/server/
ssh imac 'zsh -lc "cd ~/parchi/server && .venv/bin/pip install -q -r requirements.txt && .venv/bin/python -m pytest -q 2>&1 | tail -40"'
```
The iMac venv is `~/parchi/server/.venv` (Python 3.11.7, temporalio 1.34.0, fastapi, uvicorn already installed). Time-skipping Temporal tests download a test-server binary on first run (internet works). NEVER rsync `.venv` or `data/` from the MacBook (it would overwrite the iMac's).
Iterate until the whole suite passes. Then:

## Live checks on the iMac (after pytest is green)
1. `restart_check.py` against the real dev server (use task queue `parchi-restart-check` and its own DB path so it never touches app data): start an order, SIGKILL the worker process, start it again, send events, assert final state and placement count; print `PASS ...` / `FAIL ...` lines. Run it and keep the output.
2. `bash run.sh` on the iMac (worker + API on 0.0.0.0:8000, logs in `data/`, pids in `data/`). run.sh must create `data/admin.key` (random, chmod 600) on first run and export it as PARCHI_ADMIN_KEY. Then issue an install key: `.venv/bin/python -m auth issue sim-app > data/sim_install.key` (chmod 600). NEVER print either key into logs or the report.
3. With curl on the iMac (read the keys from the files): `/health` -> `{"ok": true, "temporal": true}`; `POST /order` (sample 1-seller plan, Idempotency-Key header) -> 201, same request again -> 200 same orderID; `GET /status/<id>`; `POST /judge/<id>/event` cancelled with the admin key -> `/status` shows `needs_proposal`. Leave the API + worker RUNNING at the end (the app will be tested against them). Delete the test orders you created with `POST /reset` (install key) afterwards.

## Report
Write `KIRO_REPORT.md` (30 lines max): files created, the exact final pytest summary line (passed/failed/errors counts), restart_check output, the curl results (status codes + JSON shapes, no secrets), any test you changed and why, assumptions, anything not verified. Your final chat message: 6 lines max.
