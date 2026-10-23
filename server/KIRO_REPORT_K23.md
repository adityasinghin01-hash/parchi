# KIRO report K23: live proof of A1, A5, A6, A7, A8 (24 Oct 2026)
Re-run (about 80 s, from `server/`, stack up, no `browser_e2e` running): `.venv/bin/python live_automations_check.py`
Last run: RESULT PASS 75/75 checks (also run once before the fixes: it found the failures below). pytest: 258 passed (was 256). Nothing committed.
| Automation | What was proved live (real Temporal + worker + SQLite) | Result | Secs |
|---|---|---|---|
| A1 reliability | 5 sandbox orders (delivered x3, cancelled, late) for 2 sellers in one area: endpoint moves 0.8 prior to 0.8571 / 0.625 exactly as (ok+4)/(total+5); :8000 returns the same; weight 0 ranks cheapest first, weight 1 flips it (good 1200, new 1320, flaky 1375) | PASS | 3.8 |
| A6 refill | Watch posted as the app does (30 tabs, 1-0-1): runs out in 3 days, 09:00 IST. waiting -> due after the shortened timer (40 s), 1 timer started / 1 fired in Temporal history, same dueFiredAt later, worker was killed while it waited. Delete-everything: A's watch TERMINATED, B's untouched, B's own delete stops B's | PASS | 18 |
| A7 true price | After 4 delivered orders: 2 reports not enough, 3rd gives median 1000 paise, 4th moves it to 1500. Refused: negative, Rs 1 crore+, text, fractional, bad pincode, negative items (422), other install (409), no key (401). Delete-everything removes the rows | PASS | 3.8 |
| A8 safety net | Same Idempotency-Key: 201 then 200, one order, 2 placements; different body 409. Worker SIGKILL + restart while awaiting approval: state rebuilt. Approve once: 1 approval, 3 placements, no doubles; late replay 409. "Did this go through?" raised after 18 s (15 min x 0.02), once, cleared by confirm; audit 1..8 contiguous | PASS | 19.5 |
| A5 chase | Lab booked, confirmed via reply link, collected: report_due after 1.1 s, chase 20.9 s later (6 h x 0.001 = 21.6 s), still once 8 s later (2 state moves in history), report_ready closes it | PASS | 30.3 |
## Bugs found and fixed (small, all with pytest)
1. Codex R4 is TRUE: `/reset` only terminated orders. Shown live on :8000 (watch still RUNNING after reset). Fix: `refill.cancel_watches` (lists running RefillWorkflow, matches the install via its snapshot) called from `api.py` reset; pytest in `test_api.py`. Live after restart: TERMINATED.
2. `PARCHI_TIME_SCALE` meant opposite things: orders/shop/lab multiply, refill divided (a demo scale of 0.01 made refill 100x slower). Refill now multiplies; test and V2_README updated.
3. A7: another install could pre-claim a real order id before its owner reported (blocking the owner). Now 409 if the order exists and belongs to someone else; pytest added.
## Not proved / limits
- A1: finished orders do NOT feed reliability by themselves; only `POST /judge/reliability/record` does. The script records the outcomes after each order, so "scores change" is proved, "orders update scores automatically" is NOT (nothing calls it). The planner check uses the server formula `rank_with_reliability`, which the Swift Planner mirrors; the Swift engine itself was not run here.
- A7: order ids that are not in the orders table are still accepted (needed by sandbox mode and the old tests), so one install can make up reports; 3 fake reports can set a median.
- A8: two approvals sent at once can both return 200 (API check races); the workflow ignores the second (audit `ignored_signal`), so no double effect.
- Timers use time scale, not real hours: the script starts extra copies of the same API on :8010/:8011/:8012 (shared DB, Temporal, worker). The real 15 min / 3 days / 6 h values were not waited for.
- Shop-ask and lab-booking workflows are still not terminated by delete-everything (rows are deleted, workflows idle out); not changed.
## Stack notes
- `server/data/` had been wiped and rebuilt by K20 before I started (new Temporal dev server, new keys); I did not touch the Temporal database. `brew install temporal` was still running when I began.
- I restarted the worker (twice, plus once per script run) and the :8000 API once, only when no `browser_e2e` process existed; K20 was still installing Playwright. The script uses its own installs (`data/k23_{a,b,c,d}.key`).
