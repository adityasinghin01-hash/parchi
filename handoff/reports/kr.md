# Report: job KR (reader + scan engine, model contract). Branch `fe-kr`, nothing pushed.

## 1. Done
- STEP 1 CONTRACT commit `6e8667b` at 05:14 IST (message starts `CONTRACT:`).
  - `Model/AppModel.swift`: `enum ReadSource { reader, onPhone, sample, manual }`, `readSource` (default `.manual`), `readNote`. `loadReaderLines(_:source:assumedIndices:)` (default `.reader`), `readDemoParchi` -> `.sample` + "Sample parchi, not your photo", `eraseAll` resets both. `quantityAssumed` (medicine line with `quantity == nil`), `setQuantity(_:_:)` clamps 1...`maxEditQuantity` (= min(99, maxManualQuantity) = 99), clears the mark, resets the plan. `editLine(_:name:strength:)` re-runs the brand–strength check, test match and H1/X check. `startManualList()` (empty Confirm). A demo line changed to a different name/strength/quantity gets a new id so it never keeps the demo price (the "Telma 40" correction keeps it; total stays Rs 2,696.77, tested).
  - `Support/Manual/AppModel+Manual.swift` (needed so manual add/remove keep source + assumed marks through the rebuild; small change).
  - New `Support/Capture/ReaderFailure.swift` (`notConfigured, capReached, badKey, readerError, offline, timeout, empty, noReaderInMock, slowDown`, `init?(code:)`, `message`, `canRetry`) and `Support/Capture/ReaderCopy.swift` (all reader/scan strings; live upload note names Anthropic's Claude service and says Anthropic's own terms apply, no retention claim).
  - `ReaderClient.swift`: throws `ReaderFailure`; server `code` wins, status is the fallback; network error -> `.offline`, URL timeout -> `.timeout`. Old `ReaderError` removed (no other users).
  - `CaptureModel`: `failure: ReaderFailure?` set with `phase = .failed(String)`; `retry(model:onUse:)`, `continueManually(model:) -> Bool`, `useSampleInstead(model:) -> Bool`.
- G2: no automatic sample anywhere after a failed/empty read. Mock: on-phone reader -> else `.noReaderInMock`. Live: reader failure -> on-phone reader -> else `.failed(<specific failure>)`. Home sample button and `-demoRoute` still use `readDemoParchi()` (labelled `.sample`). Minimal buttons in `CapturePreviewView`'s failed case (ids `readerRetry`, `readerTypeIn`, `readerUseSample`) so the path is not a dead end; FE2 owns the look.
- G3/G4: `reader_claude.py` + `/read` in `api.py` return `{"detail","code"}` with `not_configured`, `cap_reached` (ledger cap, Anthropic 400 "usage limits", 429 `enforced_spend_limit_reached`: never retried), `bad_key` (401/403), `reader_error`, `timeout` (504), `slow_down`.
- G10: `/read` 6 per minute per install key (in-memory sliding window), 429 + `Retry-After` + `slow_down`; refused requests never reach the reader.
- G9: `max_tokens` 2000, `RESERVE_USD` opus 0.07 / sonnet 0.04 / haiku 0.005, `INR_PER_USD` 97 (env `PARCHI_INR_PER_USD`), `/usage` still says "estimate". `server/data/reader_spend.json` not touched (tests use tmp ledger; scratch rsync excluded `data`).
- G6: `ConsentStore.currentVersion = 2`; consent card text (EN + HI) names Anthropic's Claude service. Docs: CLAUDE.md/AGENTS.md/CONTEXT.md line 2, READER-CONTRACT.md (60 s, code table, Anthropic, cost), DEMO-RUNBOOK.md, docs/deck/JUDGE-QA.md ("our own lab computer" -> Anthropic via lab server).

## 2. Results (measured on the iMac)
- App unit after CONTRACT: `RESULT: PASS (unit)` — 133 tests, 1 skipped, 0 failures.
- App unit final: `RESULT: PASS (unit)` — 135 tests, 1 skipped, 0 failures (baseline 118/1; +17 in `ReaderContractTests`, incl. URLProtocol code mapping).
- UI: `CaptureUITests PrintedReadUITests ConsentGateUITests PrivacyK13UITests ManualAddUITests` -> `RESULT: PASS (test)` (12 tests, 0 failures).
- UI: `K24Journey1UITests ServerDownUITests PlanBFlowUITests SimulateCancelUITests` -> `RESULT: PASS (test)` (4 passed).
- Server pytest (scratch copy `~/parchi-wt/kr/server`): `473 passed, 2 skipped` (baseline 452; +21 in `tests/test_reader_codes.py`).

## 3. Tests changed and why
- `test_reader_claude.py`: `max_tokens == 2000` (G9); `/usage` rate 97 not 88 (G9); deadline test expects 504 + `timeout` instead of 502 (G3); error bodies now include `code`.
- `test_reader_spend_cap.py`: reserve 0.07/0.04 (G9); cap arithmetic re-done (4.43 + 0.07 = 4.50; 7 slots in 0.5 instead of 8). Same invariants, new numbers.
- `test_api.py`, `test_hardening2.py`: `/read` 503 body now includes `"code": "not_configured"`.
- `tests/conftest.py`: autouse fixture clears the `/read` rate window per test.
- UI tests `CaptureUITests`, `PrintedReadUITests`, `PrivacyK13UITests`, `CheckoutProbeUITests`: launch arg `-parchi.consentVersion 2` (consent v2).
- `K24Journey1UITests`: after "Use this photo" in Mock, taps `readerUseSample` if shown (the old test relied on the auto-sample, now forbidden by G2).

## 4. Not done / partial
- Confirm "Sample parchi, not your photo" banner and "assumed 1, check" are FE2's ConfirmView; NOT on this branch (bug KR-1). Verify after merging fe-2.
- No dedicated UI test for each Live failure code (covered by unit URLProtocol tests + server tests, STUB level). D2 end-to-end through the app with a stub upstream not run.
- `scan_page.py` judge page does not forward codes (KR-2). No real Anthropic calls made (by rule).
- Hindi consent text is my translation, not native-reviewed; consent wording needs Aditya's approval before hands-on.

## 5. Bugs: see `handoff/bugs/kr.md` (KR-1 P0 until FE2 merge, KR-2 P2, KR-3 P3, KR-4 P2, KR-5 P3).

## 6. NEEDS-* requests
- NEEDS-FE2: Confirm shows `model.readNote` as a banner whenever non-nil (always for `.sample`); "assumed 1, check" for `model.quantityAssumed`; quantity via `setQuantity`, name/strength via `editLine`. In the failed phase use `capture.failure` (+ `canRetry`), `retry(model:onUse:)`, `continueManually(model:)`, `useSampleInstead(model:)` (only for `.noReaderInMock`), strings from `ReaderCopy`; keep ids `readerRetry`/`readerTypeIn`/`readerUseSample` or update K24Journey1UITests. Live preview note = `ReaderCopy.liveUploadNote`.
- NEEDS-FE5: consent card text is in `FirstRunConsentView.cards` (my edit, version 2); keep it when restyling.
