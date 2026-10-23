#!/usr/bin/env bash
# Idempotent: starts the Claude reader on 127.0.0.1:8100 ONLY if a key exists. Logs (no content) go to data/reader.log.
# The reader never starts in "free" mode by itself: PARCHI_ANTHROPIC_BASE_URL alone is counted and capped like the real API;
# only a local stub needs PARCHI_READER_TEST_UPSTREAM=1 together with PARCHI_ANTHROPIC_BASE_URL (never set it for real use).
# Exit 0 = running (started now or already), 3 = no key so nothing started.
set -euo pipefail
umask 077
cd "$(dirname "$0")"
mkdir -p data
unset ANTHROPIC_LOG   # the SDK would log the whole request, photo included, at debug (K28/15)
PY=.venv/bin/python
[ -x "$PY" ] || PY=python3

alive() { [ -f "$1" ] && kill -0 "$(cat "$1")" 2>/dev/null; }
if alive data/reader.pid; then
  if curl -fsS -m 2 http://127.0.0.1:8100/health >/dev/null 2>&1; then
    echo "reader already running (pid $(cat data/reader.pid))"; exit 0
  fi
  echo "reader process is alive but unhealthy" >&2; exit 1
fi
if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -z "$(head -n1 data/anthropic.key 2>/dev/null | tr -d '[:space:]')" ]; then
  echo "no Anthropic key (ANTHROPIC_API_KEY or data/anthropic.key): reader not started"; exit 3
fi
nohup "$PY" -m uvicorn reader_claude:app --host 127.0.0.1 --port 8100 --no-access-log >> data/reader.log 2>&1 < /dev/null &
echo $! > data/reader.pid
for _ in $(seq 1 20); do
  if curl -fsS -m 1 http://127.0.0.1:8100/health >/dev/null 2>&1; then
    echo "started reader $(cat data/reader.pid) on 127.0.0.1:8100"; exit 0
  fi
  sleep 0.5
done
echo "reader failed to become ready" >&2; exit 1
