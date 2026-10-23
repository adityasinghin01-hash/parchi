# KIRO_REPORT_S2b: reliability (A1), refill (A6), true price (A7)

## Files (all new; no existing file edited, no commit)
`v2_db.py`, `reliability.py`, `refill.py`, `true_price.py`, `V2_README.md`,
`tests/test_reliability.py`, `tests/test_refill.py`, `tests/test_true_price.py`

## Result on the iMac (3 runs, all identical; full suite also green: 107 passed)
`68 passed, 1 warning in 1.09s`

## Assumptions
- Reliability prior: score = (ok+4)/(total+5), neutral 0.8. Area lower-cased/trimmed. `ok|delivered` = ok; `fail` and contract FAILURES = not ok.
- `rank_with_reliability`: sellers `{sellerID, cost}`; adjustedCost = cost*(1+weight*(1-score)); unknown seller = 0.8; weight 0 = price only.
- Refill: whole-tablet doses; partial pack counts full days only (15 tabs at 2/day = 7). Start date = first dose day, today not yet taken.
  runsOutOn = start + supply days; due = runsOutOn - 3 days at 09:00 IST; several items: earliest wins; overdue fires immediately.
- `dosesPerDay` accepts a number or a schedule string ("1-0-1" = 2, "0-0-1" = 1).
- Only due time and ids go into Temporal (no medicine names). Time scale read from `PARCHI_TIME_SCALE` at API start, passed as workflow input.
- Added beyond the brief: `POST /refill/{id}/done|cancel` (otherwise the signals are unreachable); 409 if already finished.
- True price: `reports` counts only reports with `itemsPaise`; median of two middle values is floored; extra can be negative.
  One report per (order, seller); a different install gets 409 on overwrite. Install id stored for that check only.
- Admin check on `/judge/reliability/record` uses `auth.require_admin`; install routes use the `get_install_id` you pass in.

## Not done / unverified
- Not wired into `api.py` / `worker.py` (not allowed to edit). The worker must register `refill.WORKFLOWS` or `/refill/watch` workflows never run. Snippet in `V2_README.md`.
- Not run against the real dev Temporal server or real `auth.require_install`; tests use fake install dependencies and the time-skipping server.
- Refill tests use one time-skipping server per test (the API uses the real clock for "today").
