# A1 — Codex app/engine combined verification

Status: A1 COMPLETE (checkout probe remains skipped by its existing internet guard). Scope is A1 only; no server files, server sync, git mutations, external messages, or paid reader calls.

Environment: lab iMac Xcode 26.2/iOS 26.2, iPhone 17 Pro; isolated source `~/parchi-codex-a1`, derived data `~/parchi-dd-codex-a1`, engine scratch `~/.swiftpm-codex-a1`. Sequential test jobs.

## Fix and baseline
- Added `OnPhoneReaderK27Tests.testManualEditsPreserveUnrecognisedReaderRows`: add medicine, add test, remove line retain unresolved rows, a genuinely new read clears them.
- Baseline combined app+engine compiled. Targeted K27: 9 tests, 3 expected assertion failures in the new test (`[]` versus `["Tab Telia 40 OD"]`), all eight existing cases passed, including needs-help lifecycle, injection Rs 268 versus Rs 45 and forms.
- Root cause: manualRebuild calls loadReaderLines, whose new-reading lifecycle correctly clears readerNeedsHelp. Minimal fix saves and restores the unresolved rows only around manual rebuild.
- Evidence: remote `logs/reader-red.log`, xcresult in `~/parchi-dd-codex-a1/Logs/Test/`.
- Initial engine run: 152 tests, 3 missing-fixture errors because the isolated copy lacked the saved public Jan Aushadhi JSON in docs/research/evidence; copied that exact fixture. No test/code change for this environment error; rerun pending after app units.

## Pending
Full engine rerun, app unit outcome, K24 reproduction/fix, full UI suite, SimulateCancel five sequential runs.

## Verified so far
- Engine rerun: **152 passed**, 0 issues, 0.214 s (fresh build scratch); `logs/engine-green.log`.
- Full app units: **119 executed, 118 passed, 1 skipped, 0 failures**, 77.693 s; `logs/units.log`. The skip is the opt-in K16 measurement because `/tmp/k16/run.json` is absent.
- Existing K21 measurement opt-in was already enabled on the iMac by `/tmp/k21/run.json`; it passed in 34.444 s as part of the full unit suite. This is partial A3 evidence only; output remains at `/tmp/k21/out.json` on the iMac and has not been copied to the repo (may contain raw uncertain OCR text). No photo handling changes or private-image transfer made by A1.
- K24 baseline replay running. App unit compilation also compiled every existing UI test source successfully.
- K24 baseline **PASS**, 1 test, 207.590 s (`k24-red.log` retains the baseline filename despite green outcome). Explicitly reached Track, opened/approved Plan B, opened Care, returned Home and completed Settings/Delete. The known Track/Care failure did not reproduce; no speculative test/product changes made.
- Complete UI suite running against existing lab server, live keys read remotely only. Existing read-only CheckoutProbe included as instructed. Completed logs copied into `handoff/a1-evidence/`.

## Full UI result (before new demo-blocker scope)
- **26 executed, 25 passed, 1 skipped, 0 failures**, 498.944 s; `handoff/a1-evidence/ui.log` and remote xcresult `Test-Parchi-2026.10.24_02-39-56-+0530.xcresult`.
- Both K24 first-time journey replays passed; no Track/Care failure reproduced.
- Core live PlanB and ShopAskLive, all four PrivacyK13, ServerDown and SimulateCancel passed. CheckoutProbe skipped itself at the existing internet preflight (no internet), so seller page measurement remains unverified.
- At user-requested pause, no follow-on work launched; resumed only under the 30-minute demo-blocker scope. Five short sequential SimulateCancel checks now running.

## Integration observation for parent (read-only)
New server order `expired` is not handled in the current app: `pollOnce` only stops on `done`; `apply` does not clear a stale Plan B sheet or show an expiry message. Lab poll stops on `expired` but `LabBookingState.isFinal` excludes it, allowing resume to restart polling. Parent informed; no speculative change under demo-blocker scope (server default scale 1, seven-day expiry). Revisit if accelerated demo scale makes expiry reachable.

## Final A1 result
- Combined app/engine generated and compiled; engine **152 passed**; app unit **119 executed / 118 passed / 1 skipped / 0 failed**; full UI **26 executed / 25 passed / 1 skipped / 0 failed**; extra K24 baseline **1 passed**; SimulateCancel **5 of 5 passed** (five sequential Mock-only runs; logs `sc_1.log` ... `sc_5.log`).
- Only A1 code edits: two-line save/restore in `app/Parchi/Support/Manual/AppModel+Manual.swift`; added `testManualEditsPreserveUnrecognisedReaderRows` in `app/ParchiTests/OnPhoneReaderK27Tests.swift`. Other dirty changes were preserved. Tests not weakened; expected regression failure proved before fix.
- No server edits/sync/restart/data access beyond remote live test keys, no git mutation, no paid API or outward message. Existing iMac simulator reused sequentially; no new simulator to delete.
- Demo price regression `ManualAddTests.testDemoParchiTotalIsUntouchedWhenNothingIsEdited` passed; prices untouched.
- Parent owns final new-server integration smoke and A2 onward. No global CODEX-DONE marker created because A1 is delegated scope only.
