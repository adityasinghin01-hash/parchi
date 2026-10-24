#!/usr/bin/env bash
# Screenshot ONE app screen on the iMac's iPhone 16e simulator (390x844 pt, the same as the HTML preview), 9:41 status bar like the design,
# copy it to .work/fidelity/<job>/<name>.png and, if a web render exists, score it against frontend/specs/web/<name>.png.
#   tools/fidelity/app_shot.sh <job> <name> [launch args...]      default launch args: -fidelityScreen <name>
# Build first:  tools/verify/fe_build.sh <job> build
# Parallel-safe: a lock serialises use of the simulator (a few seconds per shot).
set -euo pipefail
JOB="${1:?job}"; NAME="${2:?web route name}"; shift 2
ARGS=("$@"); [ ${#ARGS[@]} -eq 0 ] && ARGS=(-fidelityScreen "$NAME")
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; OUT="$ROOT/.work/fidelity/$JOB"; mkdir -p "$OUT"
ssh imac bash -s -- "$JOB" "$NAME" "${ARGS[@]}" <<'REMOTE' 2>&1 | grep -v Pseudo
set -u
JOB=$1; NAME=$2; shift 2
SIM=$(xcrun simctl list devices available | grep "iPhone 16e" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[ -n "$SIM" ] || { echo "no iPhone 16e simulator"; exit 3; }
while true; do
  find ~ -maxdepth 1 -name ".lock-fidsim" -mmin +5 -exec rmdir {} \; 2>/dev/null
  mkdir ~/.lock-fidsim 2>/dev/null && break; sleep 2
done
trap 'rmdir ~/.lock-fidsim 2>/dev/null' EXIT
xcrun simctl boot "$SIM" 2>/dev/null; xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1
xcrun simctl status_bar "$SIM" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4 --cellularMode active >/dev/null 2>&1
APP=$(find ~/parchi-dd-$JOB/Build/Products -maxdepth 3 -name Parchi.app | head -1); [ -n "$APP" ] || { echo "no built app for job $JOB: run tools/verify/fe_build.sh $JOB build"; exit 4; }
xcrun simctl install "$SIM" "$APP"
xcrun simctl terminate "$SIM" in.tessanova.parchi >/dev/null 2>&1
xcrun simctl launch "$SIM" in.tessanova.parchi "$@" >/dev/null
sleep 6
mkdir -p ~/parchi-wt/fidelity && xcrun simctl io "$SIM" screenshot ~/parchi-wt/fidelity/$JOB-$NAME.png >/dev/null 2>&1 && echo "screenshot taken ($NAME, args: $*)"
REMOTE
scp -q "imac:parchi-wt/fidelity/$JOB-$NAME.png" "$OUT/$NAME.png"
if [ -f "$ROOT/frontend/specs/web/$NAME.png" ]; then
  /usr/bin/python3 "$ROOT/tools/fidelity/compare.py" "$ROOT/frontend/specs/web/$NAME.png" "$OUT/$NAME.png" "$OUT/$NAME" || true
  echo "side-by-side (web | app | diff): $OUT/${NAME}_sbs.png"
fi
