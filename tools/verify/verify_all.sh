#!/bin/zsh
# One command that proves the build on the lab iMac. Run it from the MacBook, from the repo root:
#   tools/verify/verify_all.sh            # sync + everything (about 12 minutes)
#   tools/verify/verify_all.sh --no-sync  # run on what is already on the iMac
# Needs: ssh alias `imac`, the iMac server venv, XcodeGen, Xcode 26, the iPhone 17 Pro simulator.
# Keys are read ON THE iMAC from server/data/*.key and never printed. Output ends with a one-line summary per layer.
set -u
SERVER_DIR=${PARCHI_SERVER_DIR:-${PARCHI_REMOTE_DIR:-parchi}}   # where the running server lives on the iMac (keys + Temporal database)
CODE_DIR=${PARCHI_CODE_DIR:-$SERVER_DIR}                        # where engine/ and app/ are copied and built (can be a scratch folder)
HOST=${PARCHI_HOST:-imac}
cd "${PARCHI_SRC:-$(git rev-parse --show-toplevel)}" || exit 2   # PARCHI_SRC: verify a snapshot folder instead of the working tree
if [ "${1:-}" != "--no-sync" ]; then
  # NEVER use --delete on server/ (it holds the running Temporal database in data/ and the keys).
  rsync -az --exclude .venv --exclude data --exclude __pycache__ --exclude .pytest_cache --exclude '*.db' --exclude '*.log' server/ $HOST:$SERVER_DIR/server/
  ssh $HOST "mkdir -p $CODE_DIR/docs/research/evidence"
  rsync -az --delete --exclude .build --exclude '*.log' engine/ $HOST:$CODE_DIR/engine/
  rsync -az --delete --exclude .build --exclude verify --exclude xcuserdata --exclude '*.log' app/ $HOST:$CODE_DIR/app/
  rsync -az docs/research/evidence/janaushadhi_products_2026-10-23.json $HOST:$CODE_DIR/docs/research/evidence/ 2>/dev/null
  ssh $HOST "mkdir -p /tmp/parchi_samples" && [ -d app/ParchiTests/Fixtures ] && scp -q app/ParchiTests/Fixtures/*.jpg $HOST:/tmp/parchi_samples/
fi
echo "=== 0 python tools (MacBook)"; python3 -m unittest tools/test_build_app_data.py tools/test_build_catalogue_prices.py 2>&1 | tail -3
ssh $HOST "SERVER_DIR=$SERVER_DIR CODE_DIR=$CODE_DIR FLAKE_RUNS=${PARCHI_FLAKE_RUNS:-5} zsh -l -s" <<'REMOTE_SCRIPT'
set -u
LOG=/tmp/parchi_verify; mkdir -p $LOG
echo "=== 1 server pytest"; cd ~/$SERVER_DIR/server && .venv/bin/python -m pytest -q 2>&1 | tail -1
echo "=== 2 restart server + live end-to-end scripts"
bash stop.sh >/dev/null 2>&1; bash start_all.sh >/dev/null 2>&1
for i in $(seq 1 40); do curl -sf localhost:8000/health >/dev/null && break; sleep 2; done; curl -s localhost:8000/health; echo
.venv/bin/python e2e_live.py --loops 3 2>&1 | tail -1
.venv/bin/python live_p3_check.py 2>&1 | tail -1
.venv/bin/python live_t8_privacy.py 2>&1 | tail -1
echo "--- real-browser end to end"; for PW in ~/pw-venv/bin/python ~/pw-venv2/bin/python; do [ -x $PW ] && [ -f browser_e2e.py ] && { $PW browser_e2e.py 2>&1 | tail -2; break; }; done
[ -f live_automations_check.py ] && { echo "--- live automations (A1 A5 A6 A7 A8)"; .venv/bin/python live_automations_check.py 2>&1 | tail -2; }
echo "=== 3 engine swift test"; cd ~/$CODE_DIR/engine/ParchiCore && swift test --scratch-path ~/.swiftpm-verify 2>&1 | grep -E "Test run with|✘" | tail -4
echo "=== 4 app: unit + UI tests (Live tests use the keys on this machine)"
cd ~/$CODE_DIR/app && xcodegen generate | tail -1
export TEST_RUNNER_PARCHI_BASE_URL=http://localhost:8000
export TEST_RUNNER_PARCHI_INSTALL_KEY=$(cat ~/$SERVER_DIR/server/data/sim_install.key)
export TEST_RUNNER_PARCHI_ADMIN_KEY=$(cat ~/$SERVER_DIR/server/data/admin.key)
xcodebuild test -project Parchi.xcodeproj -scheme Parchi -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath ~/parchi-dd-verify > $LOG/app_test.log 2>&1
grep -E "Test Suite '.*' (passed|failed)|Executed [0-9]+ tests|\*\* TEST|error: " $LOG/app_test.log | grep -v "All tests\|xctest" | tail -40
echo "=== 5 flake check: SimulateCancel x5"
pass=0
for n in $(seq 1 $FLAKE_RUNS); do
  xcodebuild test-without-building -project Parchi.xcodeproj -scheme Parchi -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath ~/parchi-dd-verify -only-testing:ParchiUITests/SimulateCancelUITests > $LOG/sc_$n.log 2>&1 && pass=$((pass+1))
done
echo "SimulateCancel passed $pass of $FLAKE_RUNS"
echo "=== done"
REMOTE_SCRIPT
