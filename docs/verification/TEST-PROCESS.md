# How Parchi is tested, layer by layer (what each layer proves and what it does NOT)
Run everything on the lab iMac from the MacBook with one command: `tools/verify/verify_all.sh` (about 12 minutes; `--no-sync` reuses what is already on the iMac). It prints one line per layer. Keys are read on the iMac from `server/data/*.key` and never printed.

| # | Layer | Command (inside verify_all.sh) | Expected on 24 Oct 2026 | Proves | Does NOT prove |
|---|---|---|---|---|---|
| 0 | Python data tools | `python3 -m unittest tools/test_build_*.py` | 34 OK | the data builders (H1/X table, catalogue prices) | that the source data is right |
| 1 | Server unit tests | `pytest -q` in `server/` | 256 passed (1 skipped) | state machines, timers, no double order, hardening, judge page HTML | behaviour in a real browser |
| 2 | Live server scripts | `e2e_live.py --loops 3`, `live_p3_check.py`, `live_t8_privacy.py` | 72 checks / 11 of 11 / 5 of 5 | order, judge cancel, Plan B within about 2 s, shop ask, lab booking, delete-everything against a running server | the app screens |
| 2b | Real-browser end to end | `server/browser_e2e.py` (Playwright, K20) | see `server/KIRO_REPORT_K20.md` | judge, shop-reply and lab-reply pages by clicking, on a phone-sized screen; XSS and key checks | a real phone's browser engine |
| 3 | Engine tests | `swift test` in `engine/ParchiCore` | 148 passed | planner, Plan B, checks, Jan Aushadhi matcher, parser, catalogue prices, H1/X, purge | anything on the phone |
| 4 | App unit tests | `xcodebuild test` (ParchiTests) | 87 run (86 pass, 1 skipped) (the K16 measure runner) | model rules: catalogue plans, consent gate, privacy, pin prices, manual add, H1 second check, Jan Aushadhi card | real Vision on handwriting, a real iPhone |
| 5 | App UI tests (Simulator, real taps) | `xcodebuild test` (ParchiUITests) | 24 passed | the flows a person taps: capture and blur preview, consent gate, Confirm, Plan List/Map, shop sheet, Plan B (Live and Mock), server-down, typed entry, printed photo read on the phone | camera, share sheet, Call, Directions, Calendar, notifications (all need a real iPhone) |
| 6 | Flake check | `SimulateCancelUITests` x5 | 5 of 5 | the Mock "Simulate cancel" demo button is stable (it failed 3 of 5 before the 24 Oct test fix) | |

## Known limits of the harness
- The Simulator has no camera, no Hindi text recognition, no Wi-Fi switch and no Calendar delivery; the Apple Maps search needs internet.
- Live UI tests need the server running on the iMac (`bash start_all.sh`) and the sample images in `/tmp/parchi_samples` (the script copies the fixtures there).
- `rsync --delete` must never be used on `server/` (it deletes the running Temporal database in `server/data/`; this happened once on 23 Oct).
- The tests use synthetic parchis. MIRAGE-100 (real handwriting, test only) and the 12 private web photos are used only for measurement, never for training, and never committed.

## Tested only by hand (cannot be automated here)
1. Real iPhone run: `docs/team/REAL-IPHONE-RUN.md` (scanner, Open in Parchi from WhatsApp/Files, Call, Directions, Calendar and notification delivery, location fix, Dynamic Type, dark mode). No iPhone is available yet.
2. Seller checkout login / cart / payment page, by hand, stopping at the payment page: `docs/team/CHECKOUT-MANUAL-TEST.md` (K21).
3. A shop owner replying from a real phone browser: open the reply link from the judge page on any phone (Android works) and submit the form.
4. The trained reader on handwriting: not connected yet; see `docs/research/11-reader-model-survey-24-oct.md` for the candidates and the decision rule (below 60% recall on MIRAGE-100 drop it, 60 to 80% one time-boxed adaptation, 80% or more keep it).
