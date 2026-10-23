# KIRO report K26: seller reliability (A1) now updates by itself (24 Oct 2026)
Nothing committed. Stack restarted once on :8000 (no `browser_e2e`/`live_automations_check` was running).
## What changed
- `workflows.py`: after a seller's terminal outcome the workflow runs activity `record_outcome` (delivered = ok; cancelled, outOfStock, late at ETA+30 min, sampleRejected = fail). Guarded by `workflow.patched`, so orders already running replay fine. A failed record never blocks the order.
- `activities.py` / `worker.py`: new activity `record_outcome` -> `reliability.record_order_outcome`.
- `reliability.py` + `v2_db.py`: `bump_reliability_once` writes the dedupe key and the count in ONE SQLite transaction. New table `reliability_seen(key, install_id)`; key = sha256(order, seller, outcome), `ok` and `delivered` are the same outcome.
- `api.py` + `contract.py`: `POST /order` accepts optional `area`, `city`, `pincode` (<= 64 chars); the workflow gets the first one present, else area `unknown`.
- `POST /judge/reliability/record` unchanged; new optional `orderID` in the body = same key as the workflow (no double count). Without `orderID` it counts as before. Response shape and score formula (ok+4)/(total+5) unchanged.
- `live_automations_check.py`: no longer records by hand; orders carry an area; new check that a manual record + duplicate Deliver click count once.
## Rules
- Counted once per (order, seller, outcome) however many replays, retries, restarts or duplicate signals. confirmed/shipped count nothing. A rerouted seller counts as a failure once; the replacement seller counts for itself.
- Nothing is counted if the order is deleted or being deleted (reset wins over late retries).
- Aggregate rows (`seller_reliability`: area, seller, ok, total) hold no install or order id. Delete-everything (own install or demo scope) clears the dedupe keys and keeps the counts.
## Tests
- New `tests/test_reliability_auto.py`: 20 tests (4 outcomes, late, confirm/ship, duplicate signals + activity replay, worker restart mid-order, two areas + no area, Plan B, deleted order, manual endpoint same key, formula, no ids in rows, delete-everything, area passed on /order). `test_workflows.py` helper updated.
- Full `server/tests`: 330 passed (a mid-edit `test_scan_page.py` from another task failed once, then passed). `live_automations_check.py`: PASS 76/76 (A1 6.4 s).
## Live on :8000 (sandbox orders, judge event API, no call to `/judge/reliability/record`)
- Before: area empty. Good seller delivered: 0.8333 (1 order). Flaky cancelled: 0.6667 (1). Flaky delivered: 0.7143 (2). Second Deliver click: still 0.7143 (2).
- Order with no area went to area `unknown`; the first area was untouched.
## Not covered / please note
- The iOS app does NOT send an area yet (`LiveClient.placeOrder` body has plan, sellers, cap only) while it reads scores for `areaName` (e.g. Noida). Until the app sends `city` (or `area`) in `POST /order`, all live orders land in `unknown` and the app's chip stays empty. I did not touch Swift. One line in `LiveClient.placeOrder` fixes it.
- Test leftovers in the live DB: areas `k26 area ...`, `unknown` (+2 rows from my runs) and a key `data/k26.key`, all aggregate/test data.
- Orders that started before the restart were not backfilled; shop/lab workflows do not feed reliability.
- Real 30-minute late timer not waited for (time-skipping test covers ETA+30; the live `late` was the judge button).
