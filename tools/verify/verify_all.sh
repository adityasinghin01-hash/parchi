#!/bin/zsh
# One command that proves the build on the lab iMac. Run it from the MacBook, from the repo root:
#   tools/verify/verify_all.sh            # sync + everything (about 12 minutes)
#   tools/verify/verify_all.sh --no-sync  # run on what is already on the iMac
# Needs: ssh alias `imac`, the iMac server venv, XcodeGen, Xcode 26, the iPhone 17 Pro simulator.
# Keys are read ON THE iMAC from server/data/*.key and never printed. Output ends with a one-line summary per layer.
set -u
REMOTE=${PARCHI_REMOTE_DIR:-parchi}
HOST=${PARCHI_HOST:-imac}
cd "$(git rev-parse --show-toplevel)" || exit 2
if [ "${1:-}" != "--no-sync" ]; then
  # NEVER use --delete on server/ (it holds the running Temporal database in data/ and the keys).
  rsync -az --exclude .venv --exclude data --exclude __pycache__ --exclude .pytest_cache --exclude '*.db' --exclude '*.log' server/ $HOST:$REMOTE/server/
  rsync -az --delete --exclude .build --exclude '*.log' engine/ $HOST:$REMOTE/engine/
  rsync -az --delete --exclude .build --exclude verify --exclude xcuserdata --exclude '*.log' app/ $HOST:$REMOTE/app/
  rsync -az docs/research/evidence/janaushadhi_products_2026-10-23.json $HOST:$REMOTE/docs/research/evidence/ 2>/dev/null
  ssh $HOST "mkdir -p /tmp/parchi_samples" && [ -d app/ParchiTests/Fixtures ] && scp -q app/ParchiTests/Fixtures/*.jpg $HOST:/tmp/parchi_samples/
fi
echo "=== 0 python tools (MacBook)"; python3 -m unittest tools/test_build_app_data.py tools/test_build_catalogue_prices.py 2>&1 | tail -3
ssh $HOST "REMOTE=$REMOTE zsh -l -s" <<'REMOTE_SCRIPT'
set -u
LOG=/tmp/parchi_verify; mkdir -p $LOG
echo "=== 1 server pytest"; cd ~/$REMOTE/server && .venv/bin/python -m pytest -q 2>&1 | tail -1
echo "=== 2 restart server + live end-to-end scripts"
bash stop.sh >/dev/null 2>&1; bash start_all.sh >/dev/null 2>&1
for i in $(seq 1 40); do curl -sf localhost:8000/health >/dev/null && break; sleep 2; done; curl -s localhost:8000/health; echo
.venv/bin/python e2e_live.py --loops 3 2>&1 | tail -1
.venv/bin/python live_p3_check.py 2>&1 | tail -1
.venv/bin/python live_t8_privacy.py 2>&1 | tail -1
[ -f browser_e2e.py ] && ~/pw-venv/bin/python browser_e2e.py 2>&1 | tail -3
echo "=== 3 engine swift test"; cd ~/$REMOTE/engine/ParchiCore && swift test --scratch-path ~/.swiftpm-verify 2>&1 | grep -E "Test run with|✘" | tail -4
echo "=== 4 app: unit + UI tests (Live tests use the keys on this machine)"
cd ~/$REMOTE/app && xcodegen generate | tail -1
export TEST_RUNNER_PARCHI_BASE_URL=http://localhost:8000
export TEST_RUNNER_PARCHI_INSTALL_KEY=$(cat ~/$REMOTE/server/data/sim_install.key)
export TEST_RUNNER_PARCHI_ADMIN_KEY=$(cat ~/$REMOTE/server/data/admin.key)
xcodebuild test -project Parchi.xcodeproj -scheme Parchi -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath ~/parchi-dd-verify > $LOG/app_test.log 2>&1
grep -E "Test Suite '.*' (passed|failed)|Executed [0-9]+ tests|\*\* TEST|error: " $LOG/app_test.log | grep -v "All tests\|xctest" | tail -40
echo "=== 5 flake check: SimulateCancel x5"
pass=0
for n in 1 2 3 4 5; do
  xcodebuild test-without-building -project Parchi.xcodeproj -scheme Parchi -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath ~/parchi-dd-verify -only-testing:ParchiUITests/SimulateCancelUITests > $LOG/sc_$n.log 2>&1 && pass=$((pass+1))
done
echo "SimulateCancel passed $pass of 5"
echo "=== done"
REMOTE_SCRIPT
