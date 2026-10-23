#!/usr/bin/env bash
# Build / test ONE worktree's iOS app on the lab iMac, in its own scratch copy. Safe to run from several jobs at once.
#   tools/verify/fe_build.sh <job> build                       compile app + tests (max 3 builds at once)
#   tools/verify/fe_build.sh <job> unit                        build, then ParchiTests (simulator lock)
#   tools/verify/fe_build.sh <job> test <TestClass> [...]      build, then ParchiUITests/<TestClass> ... (simulator lock)
# Scratch only: ~/parchi-wt/<job> and ~/parchi-dd-<job> on the iMac. It NEVER touches ~/parchi (server, data, spend ledger).
# Prints the compiler errors / failed tests and a final line "RESULT: PASS" or "RESULT: FAIL". Full log: ~/parchi-wt/<job>/last.log on the iMac.
set -euo pipefail
JOB="${1:?usage: fe_build.sh <job> build|unit|test [TestClass...]}"; MODE="${2:-build}"; shift 2 || true
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ssh imac "mkdir -p ~/parchi-wt/$JOB/app ~/parchi-wt/$JOB/engine" 2>&1 | grep -v Pseudo || true
# --delete only ever runs against these two scratch folders on the iMac.
for d in app engine; do
  rsync -az --delete --exclude .build --exclude xcuserdata --exclude DerivedData --exclude verify --exclude '*.xcodeproj' \
    "$ROOT/$d/" "imac:parchi-wt/$JOB/$d/" 2>&1 | grep -v Pseudo || true
done
ssh imac bash -s -- "$JOB" "$MODE" "$@" <<'REMOTE' 2>&1 | grep -v Pseudo
set -uo pipefail
JOB=$1; MODE=$2; shift 2
export PATH=/opt/homebrew/bin:$PATH
cd ~/parchi-wt/$JOB/app || { echo "RESULT: FAIL (no scratch copy)"; exit 2; }
LOG=~/parchi-wt/$JOB/last.log; : > "$LOG"
DD=~/parchi-dd-$JOB
acquire() {  # $1 name, $2 slots -> prints slot number; clears locks older than 40 min (crashed job)
  while true; do
    find ~ -maxdepth 1 -name ".lock-$1-*" -mmin +40 -exec rmdir {} \; 2>/dev/null
    for i in $(seq 1 "$2"); do if mkdir ~/.lock-$1-$i 2>/dev/null; then echo "$i"; return; fi; done
    sleep 3
  done
}
xcodegen generate >> "$LOG" 2>&1 || { tail -20 "$LOG"; echo "RESULT: FAIL (xcodegen)"; exit 3; }
S=$(acquire build 3)
xcodebuild build-for-testing -scheme Parchi -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DD" \
  CODE_SIGNING_ALLOWED=NO -quiet >> "$LOG" 2>&1
RC=$?
rmdir ~/.lock-build-$S 2>/dev/null
if [ $RC -ne 0 ]; then grep -E "error:" "$LOG" | sort -u | head -40; echo "RESULT: FAIL (build)"; exit 1; fi
[ "$MODE" = build ] && { echo "RESULT: PASS (build)"; exit 0; }
ONLY=()
if [ "$MODE" = unit ]; then ONLY=(-only-testing:ParchiTests); else for t in "$@"; do ONLY+=("-only-testing:ParchiUITests/$t"); done; fi
export TEST_RUNNER_PARCHI_BASE_URL=http://localhost:8000
export TEST_RUNNER_PARCHI_INSTALL_KEY=$(cat ~/parchi/server/data/sim_install.key)   # read here, never printed
export TEST_RUNNER_PARCHI_ADMIN_KEY=$(cat ~/parchi/server/data/admin.key)
T=$(acquire sim 1)
xcodebuild test-without-building -scheme Parchi -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath "$DD" \
  "${ONLY[@]}" >> "$LOG" 2>&1
RC=$?
rmdir ~/.lock-sim-$T 2>/dev/null
grep -E "error:|failed|Executed [0-9]+ tests|TEST (SUCCEEDED|FAILED)" "$LOG" | sort -u | tail -40
[ $RC -eq 0 ] && echo "RESULT: PASS ($MODE)" || echo "RESULT: FAIL ($MODE)"
exit $RC
REMOTE
