# KIRO REPORT K28 (Codex R7 rows 12-17). No commit, no real API call, no key. `server/data/` untouched.
Whole `server/tests`: 328 passed (17 s). Reader: 41 + 37, scan page: 20 (new in K28: 6 + 22 + 5; includes 1 Playwright test).
Note: my first full run, before any edit, had 4 failures in test_workflows.py (they pass alone; K26's area, not touched).

12 HIGH reserve before dispatch: `Usage.reserve()` under one lock sets aside Opus $0.06 / Sonnet $0.03 / Haiku $0.005 before the call;
  refused (503 "reader spending cap reached") if spent + reserved + estimate > cap. Success swaps the reservation for the real cost in
  one locked step; any failure releases it. Tests: 10 threads at $4.40 -> exactly 1 call, 9 x 503; 40 threads with room for 8 -> never
  more than 8 in flight, reserved + spent <= 4.5 at every call; release on 401/429/odd error; per-model and env estimates.
  Consequence: a read at $4.49 is now refused (it cannot fit its reservation). A real Opus call can cost more than $0.06 in the worst
  case (4000 output tokens = $0.08 + input), so spent can pass the cap by a few cents; the Rs 500 limit has Rs 44 of slack ($0.50).
13 MED fail closed: unreadable/corrupt/negative/NaN/bool/directory/permission-denied ledger, or a failed save, -> 503 "reader spending
  ledger unavailable" with a count-only warning (no path); missing file at first start = 0 (but must be writable). It re-checks on the
  next call and never goes below what memory knows. `/usage` shows `ledgerOk`, `reservedUsd`. Tests: 10 bad contents, dir, unwritable.
14 MED test upstream: free only if `PARCHI_READER_TEST_UPSTREAM` is exactly `1` AND `PARCHI_ANTHROPIC_BASE_URL` is set and its host is
  not anthropic.com / *.anthropic.com. A base URL alone (even the real API) is counted and capped. Updated test_eval_reader_claude.py,
  stub_anthropic.py docstring, start_reader.sh comment, README. 11-row parametrized test.
15 MED logging: `ANTHROPIC_LOG` is removed before `import anthropic` (and unset in start_reader.sh); `anthropic/httpx/httpx2/httpcore`
  loggers (and children, and root handlers) forced to WARNING with a filter. Proved with the REAL SDK in a subprocess: control run
  (bare SDK, ANTHROPIC_LOG=debug) prints the base64 photo; guarded run prints nothing; plus an in-process run with levels forced to DEBUG.
16 MED budget: reader deadline 50 s covering the retry, no retry unless >= 15 s would remain after the 1 s pause; each attempt's
  connect+read timeout is cut to what is left (connect 10 s). `PARCHI_READER_TIMEOUT` default 20 -> 60 in `api.py` (/read; one literal,
  outside your file list but required) and `scan_page.py`; `start_all.sh` no longer forces 75. Scan page JS wait 40 s -> 65 s
  (so the server's 60 s answer wins). App `ReaderClient.swift` `timeoutInterval` 25 -> 65 (that one line only; not built or run).
  Tests on a fake clock: boundary 15 s, no-retry at 14.9 s, worst case total <= 50 s, default 60 on both routes.
17 MED stale answers: page script has a counter (`seq`); choosing a photo or reading takes a new number, aborts the request in flight,
  and any reply/error/prepare result with an old number is dropped; the clicked photo (`sent`) is what is posted. Tests: served JS
  contains the guard; Playwright (~/pw-venv2, headless chromium, mocked routes): old page showed A's list under B (reproduced), new does not.

New env vars: PARCHI_READER_TEST_UPSTREAM (=1, tests only), PARCHI_RESERVE_USD (override reservation). Changed default: PARCHI_READER_TIMEOUT 60.
Not verified: the Swift change (no Xcode build run); real Anthropic behaviour (no key).
