# Parchi Orchestrator server
> **Phone test page (K22):** on a phone on the same Wi-Fi open `http://<iMac LAN IP>:8000/judge/scan?k=<admin key>`; take or pick a TEST parchi photo, tap "Read this parchi".
> LAN IP: `ipconfig getifaddr en0` (or `en1`); admin key: `data/admin.key`. The page does NOT hide the patient's name, so use test parchis only.
> It forwards the photo to `PARCHI_READER_URL` (503 "reader not connected" if unset). Nothing is stored or logged.
> The key is in the URL: do not screenshot the address bar. Plain http: some phone browsers block the camera button (use "Choose from gallery").
Durable order state machine (Temporal) + audit log (SQLite) + FastAPI. It never re-plans: the phone sends the Plan B proposal.
- Needs a Temporal server on localhost:7233 (`PARCHI_TEMPORAL` to change) and Python 3.11.
- Install: `python3 -m venv .venv && .venv/bin/pip install -r requirements.txt`
- Run: `bash run.sh` (worker + API on 0.0.0.0:8000, logs/pids/keys in `data/`); stop: `bash stop.sh`
- Issue an app key (printed once): `.venv/bin/python -m auth issue <label> > data/app.key`
- Admin key is created in `data/admin.key` on first run (header `X-Admin-Key`, judge page `/judge?k=...`).
- App endpoints (header `X-Install-Key`): `POST /order` (+`Idempotency-Key`), `GET /status/{id}`,
  `POST /order/{id}/proposal|approve|reject`, `POST /reset`.
- Admin: `GET /judge`, `POST /judge/{id}/event`, `POST /reset?scope=demo`. `GET /health` is open.
- `/read`, `/shop/{id}`, `/lab/{id}` return 501 (not built yet). All placements are Test orders.
- Tests: `.venv/bin/python -m pytest -q` (time-skipping tests download a Temporal test server once).
- Known limits: plain HTTP on the LAN; rate limit (60/min per key) is in memory and resets on restart.
- Replaying an Idempotency-Key after `/reset` returns 200 but does not restart the order.
- Claude reader (K19, `reader_claude.py`, 127.0.0.1:8100 only): add the key with `(umask 077; read -rs k; echo "$k" > data/anthropic.key)` (or `export ANTHROPIC_API_KEY`), then `bash stop.sh && bash start_all.sh`. No key = the reader is not started and `/read` answers 503.
- Switch model: `export PARCHI_READER_MODEL=claude-sonnet-5-5` (or `claude-haiku-5-5`; default `claude-opus-5-5`) and restart the reader (`bash stop.sh && bash start_all.sh`). Check with `curl localhost:8100/health`.
- Spend so far (calls, tokens, USD, INR = USD x 88): `curl localhost:8100/usage` (resets on restart). Measure accuracy: `.venv/bin/python eval_reader_claude.py --images ~/parchi-data/mirage100 --labels ../docs/research/evidence/labels.json --limit 5`.
- Stop spending: `bash stop.sh` (stops the reader; `/read` goes back to 503) or delete `data/anthropic.key`. Revoking the key in the Anthropic console is the hard stop.
- The reader has no login of its own (it listens on this computer only): anyone with shell access here can spend the key. The photo goes to Anthropic's API; the app's privacy text must say so.
- Reader tests: `.venv/bin/python -m pytest -q tests/test_reader_claude.py tests/test_eval_reader_claude.py` (fake client, no network, no key).
