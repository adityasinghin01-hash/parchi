#!/usr/bin/env bash
# Idempotent: starts the Claude reader on 127.0.0.1:8100 ONLY if a key exists. Logs (no content) go to data/reader.log.
# Exit 0 = running (started now or already), 3 = no key so nothing started.
set -euo pipefail
umask 077
cd "$(dirname "$0")"
mkdir -p data
PY=.venv/bin/python
[ -x "$PY" ] || PY=python3

alive() { [ -f "$1" ] && kill -0 "$(cat "$1")" 2>/dev/null; }
if alive data/reader.pid; then
  echo "reader already running (pid $(cat data/reader.pid))"; exit 0
fi
if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -z "$(head -n1 data/anthropic.key 2>/dev/null | tr -d '[:space:]')" ]; then
  echo "no Anthropic key (ANTHROPIC_API_KEY or data/anthropic.key): reader not started"; exit 3
fi
nohup "$PY" -m uvicorn reader_claude:app --host 127.0.0.1 --port 8100 --no-access-log >> data/reader.log 2>&1 < /dev/null &
echo $! > data/reader.pid
for _ in $(seq 1 20); do
  curl -s -m 1 http://127.0.0.1:8100/health >/dev/null 2>&1 && break; sleep 0.5
done
echo "started reader $(cat data/reader.pid) on 127.0.0.1:8100"
