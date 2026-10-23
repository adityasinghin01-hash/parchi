# K16 report: on-phone reader for PRINTED parchis (no commit made)
**Files.** New: `app/Parchi/Support/Reader/OnPhoneReader.swift` (Vision, row text rules, `OnPhoneReadResult{lines,needsHelp,note}`), `Support/Reader/LineGrouper.swift` (boxes -> rows), `app/ParchiTests/OnPhoneReaderK16Tests.swift` (18 tests + a measure runner that skips unless `/tmp/k16/run.json` exists), `app/ParchiTests/Fixtures/printed_scan.jpg` (40 KB) and `printed_photo.jpg` (51 KB), both synthetic. Edited: `engine/.../PrintedParser.swift` and `PrintedParserTests.swift` (+7 tests). `*.jpg` is in `.gitignore`: use `git add -f app/ParchiTests/Fixtures/*.jpg`.
**Tests (iMac, own simulator parchi-k16, deleted after).** Engine `swift test --scratch-path ~/.swiftpm-k16`: 148 passed (141 before my 7 new). App `xcodebuild test`, full scheme: TEST SUCCEEDED, ParchiTests 85 run / 0 failed / 1 skipped (the measure runner), 18 of them K16; all UI test suites passed on this run (no flaky retry needed).
**How it works.** Vision `.accurate`, language correction off, en-US (hi-IN second pass only if supported AND the first pass found nothing medicine-shaped). Rows = boxes with >=50% vertical overlap and a gap <= 4 line-heights. Each row goes to `PrintedParser`; a line becomes a medicine only if the parser is confident (>=0.7) AND read a form AND a brand. Medicine-shaped but unsure (unknown brand, impossible strength, no form) -> `needsHelp` with the raw text. Header/doctor/patient/vitals/footer rows are dropped. In memory only: no file, no log, no network.
**Parser changes made while measuring:** combination strengths (200MG/250MG, 1 mg/125 mg/2.5 mg, 50/12.5), "T." / "C." / "E/D" / "Nasal spray", dose counts ("1 BD", "1OD", "1 tsf", "2 drops") no longer read as strengths, "500BDx1month", lotion pack size "100ML", "1GM" matched when the catalogue stores the gram number, two medicines on one row split, missing spaces after bullets restored.
## Measured (Simulator Vision on the iMac, printed parchis only; scoring = brand + strength like `ai/score_rx.py`)
| set | images | gold meds | recall | precision | needsHelp share of output rows | invented | s/image |
|---|---|---|---|---|---|---|---|
| seed 31 (tuned on) | 154 | 530 | 98.7% | 99.4% | 4.9% | 0 | 0.82 |
| seed 32 (fresh, looked at once, 1 fix) | 105 | 353 | 96.9% | 99.1% | 10.5% | 0 | 0.84 |
| both | 259 | 883 | 98.0% | 99.3% | 7.2% | 0 | 0.83 (max 1.01) |
Rounds on seed 31 (Mac Vision harness): R1 recall 74.7% / precision 96.6% / needsHelp 31% -> R2 95.5% / 97.7% / 5.2% -> R3 99.1% / 99.6% / 4.4%. Of 83 needsHelp rows only 8 look like medicines; 75 are unknown test names ("Adv: Typhidot, S. Uric acid"). "Invented" = a read medicine whose brand is not within 2 letters of any real one on that image; the 6 wrong lines are look-alike misreads (wrong strength or a typo of a real brand). Tests read: 194 of 259 (not the goal). Synthetic printed layouts only: real printed parchis (other fonts, stamps, table layouts) are NOT measured.
**10 worst (read -> expected):**
1. `ARIPRAX` (strength lost) -> Ariprax 0.25mg
2. `LIGNOX 2 %` -> Ximinox-F (not found; nearest row is another medicine)
3. `ADIPIN-L` (no strength) -> Adipin-L 50mg/5mg
4. `ARGIPRESS` (2OUNITS) -> Argipress 20units
5. `clo Loose motions x 2 dtab TYKERB 250MG 0-0-1 p.c. x 3d` -> Tykerb 250mg (to needsHelp)
6. `-Cap NEURACAL-MAX SOFTGEL 1-0-0 after food - 5` -> Neuracal-Max Softgel (needsHelp, "5" read as strength)
7. `Tab. TAC 0 4MG/10MG ...` -> Tac O 4mg/10mg (needsHelp)
8. `POLYMXE IU` -> Polymxe 1Million IU
9. `E/D BLINK 1 0.5% 2 drops TDS x 7d` -> Blink I 0.5% (needsHelp)
10. `REGEN-D 60` -> Lofen MR; `SILOSALT a.c` (strength missing) -> Silosalt 8D
**Handwriting (`/tmp/parchi_samples/*.jpg`, 2 images, Simulator):** s10_000244: 0 lines, 1 in needsHelp (`Drops olodin 2 dropê TDS x 10d`); s10_000278: 0 lines, 0 needsHelp (Vision read `Anj Ampi-es1500mg`, `tat LepacefErmmm`, dropped). Notes shown: "Handwriting could not be read on this phone..." / "Nothing could be read on this phone...". No medicine invented. Two images only: not a measurement of handwriting.
**Cannot do:** handwriting (never claimed), Hindi-script medicine names, tables/columns laid out as cells, strengths Vision misreads (IU as 1U), tests Adv-lines not in `tests_canonical.json` (go to needsHelp), prices for brands outside the demo basket (plan gap U7 is unchanged).
**Hook-in (Claude), `CaptureView.use(model:gen:)`, replace the line `if case .notConnected = error { ... }` (line ~150) with:**
```swift
if case .notConnected = error {
    let r = await OnPhoneReader().read(blurred)   // blurred: the processed UIImage already in scope
    guard gen == generation, !Task.isCancelled else { return false }
    guard !r.lines.isEmpty else { notice = r.note; model.readDemoParchi(); phase = .idle; return true }   // nothing read: demo as today
    model.loadReaderLines(r.lines); notice = r.note + (r.needsHelp.isEmpty ? "" : " Not sure: " + r.needsHelp.joined(separator: "; ")); phase = .idle; return true
}
```
Better later: show `needsHelp` as "add by hand" rows on Confirm instead of in the notice. `OnPhoneReader()` uses `Bundle.main` `brand_strengths.json` and `tests_canonical.json` (already bundled).
