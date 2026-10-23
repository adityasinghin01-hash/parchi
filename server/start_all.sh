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
bash run.sh
sleep 3
curl -s -m 5 localhost:8000/health && echo
