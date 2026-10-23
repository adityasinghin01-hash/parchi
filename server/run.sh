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
if alive data/worker.pid || alive data/api.pid; then
  echo "already running (use stop.sh first)"; exit 0
fi

if [ ! -f data/admin.key ]; then
  (umask 077; "$PY" -c 'import secrets; print(secrets.token_urlsafe(32))' > data/admin.key)
  chmod 600 data/admin.key
fi
export PARCHI_ADMIN_KEY
PARCHI_ADMIN_KEY="$(cat data/admin.key)"

nohup "$PY" worker.py >> data/worker.log 2>&1 < /dev/null &
echo $! > data/worker.pid
# --no-access-log: the judge page takes the admin key in the query string.
nohup "$PY" -m uvicorn api:app --host 0.0.0.0 --port 8000 --no-access-log >> data/api.log 2>&1 < /dev/null &
echo $! > data/api.pid
echo "started worker $(cat data/worker.pid), api $(cat data/api.pid) on :8000"
