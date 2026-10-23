#!/usr/bin/env bash
# Starts worker + API in the background. Logs and pids live in data/.
set -euo pipefail
umask 077   # database, logs and keys readable by this user only
cd "$(dirname "$0")"
mkdir -p data
chmod 700 data; chmod 600 data/*.db* data/*.key 2>/dev/null || true
PY=.venv/bin/python
[ -x "$PY" ] || PY=python3

alive() { [ -f "$1" ] && kill -0 "$(cat "$1")" 2>/dev/null; }

if [ ! -f data/admin.key ]; then
  (umask 077; "$PY" -c 'import secrets; print(secrets.token_urlsafe(32))' > data/admin.key)
  chmod 600 data/admin.key
fi
export PARCHI_ADMIN_KEY
PARCHI_ADMIN_KEY="$(cat data/admin.key)"

if ! alive data/worker.pid; then
  nohup "$PY" worker.py >> data/worker.log 2>&1 < /dev/null &
  echo $! > data/worker.pid
fi
if ! alive data/api.pid; then
  # No access logs: legacy judge bookmarks may still contain a one-time key bridge.
  nohup "$PY" -m uvicorn api:app --host 0.0.0.0 --port 8000 --no-access-log >> data/api.log 2>&1 < /dev/null &
  echo $! > data/api.pid
fi
"$PY" service_ready.py
echo "started worker $(cat data/worker.pid), api $(cat data/api.pid) on :8000"
