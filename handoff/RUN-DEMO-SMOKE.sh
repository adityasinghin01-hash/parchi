#!/usr/bin/env bash
# Final core proof on iMac; call after the server is synced and no UI test uses it.
set -euo pipefail
cd "$HOME/parchi/server"
mkdir -p "$HOME/parchi-demo-verification"
LOG="$HOME/parchi-demo-verification"
bash stop.sh > "$LOG/restart.out" 2>&1
export PARCHI_PUBLIC_URL="${PARCHI_PUBLIC_URL:-http://$(ipconfig getifaddr en1 || ipconfig getifaddr en0):8000}"
bash start_all.sh >> "$LOG/restart.out" 2>&1
curl -fsS http://127.0.0.1:8000/health
printf '\n'
PARCHI_APP="$HOME/parchi-dd-codex-a1/Build/Products/Debug-iphonesimulator/Parchi.app" .venv/bin/python e2e_live.py --loops 3 > "$LOG/e2e.out" 2>&1
tail -1 "$LOG/e2e.out"
.venv/bin/python live_p3_check.py > "$LOG/shop-lab.out" 2>&1
tail -1 "$LOG/shop-lab.out"
.venv/bin/python live_t8_privacy.py > "$LOG/privacy.out" 2>&1
tail -1 "$LOG/privacy.out"
.venv/bin/python live_timers_check.py > "$LOG/timers.out" 2>&1
tail -12 "$LOG/timers.out"
