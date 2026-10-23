#!/usr/bin/env bash
# Stops the worker and API started by run.sh, and the Claude reader if it runs. Leaves the Temporal dev server alone.
cd "$(dirname "$0")"
for name in api worker reader; do
  pidfile="data/$name.pid"
  if [ -f "$pidfile" ]; then
    kill "$(cat "$pidfile")" 2>/dev/null || true
    rm -f "$pidfile"
    echo "stopped $name"
  fi
done
