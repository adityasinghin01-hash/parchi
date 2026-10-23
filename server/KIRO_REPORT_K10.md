# KIRO report K10: judge tools for shop asks and lab bookings + live "Ask nearby shops" UI test
No git commits. Touched: `server/judge_tools.py` (new), `server/api.py` (judge page + mount), `server/tests/test_judge_tools.py` (new), `app/ParchiUITests/ShopAskLiveUITests.swift` (new). `AppModel.swift`, `PlanView.swift`, `engine/` and `project.yml` untouched by me.

## Server
- `GET /judge/shop/asks` -> newest 10 `{askID,state,round,shops:[{shopID,name,state}],items:[{itemID,name,quantity}]}`.
- `GET /judge/lab/bookings` -> newest 10 `{bookingID,labName,state,slot?,orderID?,sellerID?}`.
- Both need `X-Admin-Key` (header only; `?k=` and install keys give 401). No tokens, install ids, phones or addresses in the output (tests assert this).
- `GET /judge?k=` now has **Shop asks** (per asked shop a "Reply" button opening an inline form: rupees per item, empty = not available, plus ready-by time; posts to `POST /judge/shop/{askID}/reply`) and **Lab bookings** (Confirm / Collected / Report ready / Sample rejected / Late posting -> `POST /judge/lab/{id}/event`). Plain HTML+JS, no CDN, everything escaped server-side, the script builds no HTML. Order buttons unchanged (test checks).
- Ready-by is built in the browser as today's IST date + the chosen time + `+05:30`.

## Tests
- iMac: `199 passed, 1 warning in 3.28s` (187 before + 12 new: admin key, shape, newest-first/cap 10, no secrets, page sections/buttons, order buttons kept, reply form only for open shops, XSS).

## Live (iMac, after `bash stop.sh; bash start_all.sh`)
- live_p3_check.py: `RESULT PASS 11/11 checks`
- live_t8_privacy.py: `RESULT PASS 5/5`
- e2e_live.py --loops 3: `RESULT PASS: 3 loops in a row, 72 checks, 18s`

## UI test (`-only-testing:ParchiUITests/ShopAskLiveUITests`, `-derivedDataPath ~/parchi-dd-k10`)
Three in a row on a dedicated simulator, each `Executed 1 test, with 0 failures (0 unexpected)`, `** TEST SUCCEEDED **` (25.5 s, 21.8 s, 21.3 s). Earlier passes on the shared simulator: 3/3 at 18.1 s, 18.0 s, 18.1 s.
- Finding: "Pick the nearest 3" sits partly under the bottom "Send to N shops" bar, so a centre tap hit Send by mistake. The test scrolls the list first, then taps Pick.
- The test asserts "Replied" for the answering shop and N-1 "Not needed any more", then taps Done and checks the sheet closes.

## Unverified / caveats
- Other jobs (K12) ran xcodebuild on the same simulator and server at the same time. Several of my runs died with "Test crashed with signal kill" (runner killed, not an assertion). Their `/reset?scope=demo` can also wipe my ask mid-test. The final 3 runs used a separate temporary simulator (deleted afterwards) and waited for the other jobs to finish.
- The judge page forms were tested through the server-rendered HTML only, not by clicking in a browser.
- I did not test a reply to a lab booking from the judge page through the UI test.
