#!/usr/bin/env bash
# Idempotent: starts Temporal (dev server) if it is not running, then the worker + API. Safe to run before every rehearsal.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p data
if ! (exec 3<>/dev/tcp/127.0.0.1/7233) 2>/dev/null; then
  echo "starting Temporal dev server"
  nohup temporal server start-dev --db-filename "$PWD/data/temporal.db" > data/temporal.log 2>&1 &
  for _ in $(seq 1 30); do (exec 3<>/dev/tcp/127.0.0.1/7233) 2>/dev/null && break; sleep 1; done
fi
# The Claude reader only runs (and the API only points at it) when a key exists; otherwise /read answers 503 as before.
if bash start_reader.sh; then
  export PARCHI_READER_URL="http://127.0.0.1:8100/read"
  export PARCHI_READER_TIMEOUT="${PARCHI_READER_TIMEOUT:-60}"   # end-to-end budget: reader 50 s < server/scan page 60 s < app 65 s
fi
bash run.sh
sleep 3
curl -s -m 5 localhost:8000/health && echo
