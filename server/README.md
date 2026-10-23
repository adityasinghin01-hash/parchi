# Parchi Orchestrator server
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
