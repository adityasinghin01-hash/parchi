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
reader_status=0
bash start_reader.sh || reader_status=$?
if [ "$reader_status" -eq 0 ]; then
  export PARCHI_READER_URL="http://127.0.0.1:8100/read"
  export PARCHI_READER_TIMEOUT="${PARCHI_READER_TIMEOUT:-60}"   # end-to-end budget: reader 50 s < server/scan page 60 s < app 65 s
elif [ "$reader_status" -ne 3 ]; then
  echo "reader failed to become ready" >&2; exit 1
fi
bash run.sh
