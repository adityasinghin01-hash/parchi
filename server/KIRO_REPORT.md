# KIRO_REPORT (task S, server/)

Files created: workflows.py, auth.py, api.py, worker.py, run.sh, stop.sh, README.md (14 lines), restart_check.py. requirements.txt gained python-multipart. No commits; Temporal dev server untouched.

## pytest (iMac, Python 3.11.7)
Final line: `39 passed, 1 warning in 1.01s` (0 failed, 0 errors; the warning is a Starlette/httpx deprecation). Run 3 times, same result.

## restart_check.py (real dev server, queue parchi-restart-check, temp DB)
PASS order placed and s1 confirmed before the kill / PASS worker killed with SIGKILL / PASS state rebuilt from history after restart / PASS final state is done / PASS both sellers delivered / PASS exactly 2 placements, no doubles / PASS audit sequence contiguous (8 rows) / RESULT PASS.
A signal sent while the worker was dead was kept and applied after the restart.

## Live (run.sh on iMac, API + worker left RUNNING; admin.key and sim_install.key are chmod 600)
- GET /health -> 200 `{"ok":true,"temporal":true}`
- POST /order (Idempotency-Key live-1) -> 201 `{"orderID":"<32 hex>"}`; same request again -> 200, same orderID
- GET /status/<id> -> 200 `{orderID,state:"placed",planVersion:1,sellers:[{etaMinutes,id,status}],pending:null,proposal:null,nothingAvailable:false,needsCheck:[],waitingSince:null,audit:[...]}`
- POST /judge/<id>/event cancelled (admin key) -> 200 `{"ok":true}`; /status then: state `needs_proposal`, pending `{failure:"cancelled",sellerID:"s1"}`, s1 `failed`
- GET /judge?k=<admin> -> 200 (HTML); POST /reset (install key) -> 200 `{"ok":true,"deleted":1}`; /status after reset -> 404
- Grep of data/api.log and data/worker.log for both keys: 0 matches.

## Test changed (1)
tests/test_workflows.py::test_nothing_available_requires_explicit_approval: the proposal used `newPlan=plan([])`, `extraCost=-100`. That contradicts contract.py and test_contract.py (nothing-available must keep the original plan, extraCost 0), so the workflow correctly rejected it. Changed to `newPlan=plan(), extraCost=0`. Assertions are unchanged.

## Assumptions / not verified
- uvicorn runs with `--no-access-log` because /judge takes the admin key in the query string.
- A failed seller is marked `failed` as soon as it is queued, so a proposal cannot reroute to it.
- An approval is stored under the new plan version (the one it creates).
- Replaying an Idempotency-Key after /reset returns 200 but the order is not restarted (REJECT_DUPLICATE); noted in README.
- Not verified: Swift app against the API, behaviour after the iMac reboots, load or concurrent-client behaviour, the judge page buttons in a browser (only the HTTP 200 was checked), /order/{id}/proposal|approve|reject against real Temporal (covered only by mocked API tests plus workflow tests).
