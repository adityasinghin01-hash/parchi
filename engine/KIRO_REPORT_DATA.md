# Kiro report D: real data shipped in the app (23 Oct 2026)

## Files created (all new; nothing in server/, AppModel, project.yml or Screens touched)
- `tools/build_app_data.py`, `tools/test_build_app_data.py`
- `engine/catalogue/`: `labs.json`, `lab_prices.json`, `product_links.json`, `tests_canonical.json`, `schedule_h1_x.json`, `brand_schedule.json` (extra, see below), `DATA_VERSION.json`
- `engine/ParchiCore/Sources/ParchiCore/`: `PriceSource.swift`, `TestNames.swift`, `ScheduleCheck.swift`
- `engine/ParchiCore/Tests/ParchiCoreTests/`: `PriceSourceTests.swift`, `TestNamesTests.swift`, `ScheduleCheckTests.swift`
- `app/Parchi/Support/AppData.swift`, `app/DATA_INTEGRATION.md`

## Results
- unittest: `Ran 12 tests ... OK`. Build run twice: output byte-identical.
- swift test (iMac, Xcode 26.2, plain `swift test`): `Test run with 43 tests in 0 suites passed` (17 old + 26 new).
- swift test (this MacBook): plain `swift test` FAILS on every test file, including the old ones, because the Command Line Tools toolchain here does not load the Swift Testing macro plugin (`plugin for module 'TestingMacros' not found`; no Xcode installed on this Mac). It passes with: `swift test -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing` (43 passed). I did not change Package.swift.
- App build on the iMac (copy in a separate folder, xcodegen + xcodebuild, iOS Simulator): `BUILD SUCCEEDED` with AppData.swift; all new JSONs are in the .app bundle. Copy deleted afterwards.
- AppData runtime check (compiled against ParchiCore, loaded engine/catalogue): Meerut 8 labs, Muradnagar 1 lab and no lab price, Apollo link keeps null price, missing folder gives empty data (no crash).

## DATA_VERSION.json counts
labs 41, lab_prices 69, product_links 32 (17 with a price), tests_canonical 29, schedule_h1_x 66, brand_schedule 253. `build_date` = newest `date_seen` (2026-10-23), so reruns stay identical.

## Brand-to-salt finding
YES: `~/dev/parchi-research/data/medlex/updated.csv` has `salt_composition` for 2.5 lakh products. The script (argv[2], optional) derives `brand_schedule.json`: 253 brands (from 386 products) with an H1/X salt; a brand is flagged if ANY product under that first word has one (errs on the safe side). `isInPersonOnly(brand:)` and `isInPersonOnly(composition:)` use it.

## Unverified / caveats
- Schedule H1/X has conditions (e.g. codeine formulations); we flag by salt name only, not by strength or dosage form.
- Test ambiguity rules (missing Free/Total, fasting/PP/random, look-alikes) are my reading of `confusable_with` plus qualifier words; words out of order ("T3 free") are `.unknown`, not guessed.
- Lab "online" source label is used for lab-page prices; no shop-reply/phone data exists yet.
- Muradnagar has no lab prices (known gap); nothing copied from Meerut.
- Integration into AppModel/screens not done (see `app/DATA_INTEGRATION.md`).
