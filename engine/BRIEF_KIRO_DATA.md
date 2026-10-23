# Kiro task D: ship the collected real data inside the Parchi app (bundle files + loader + rules + tests)

You are the hands; Claude is the instructor and will re-run your tests himself. Run from the repo root `~/dev/parchi`. Do NOT git commit. Two other Kiro jobs are running at the same time in `server/` and `app/` (K1 server, K2 Mock/Live switch): do NOT edit anything in `server/`, do NOT edit `app/Parchi/Model/AppModel.swift`, do NOT edit `app/project.yml`, do NOT edit any file in `app/Parchi/Screens/`. Your files are NEW files only, in: `tools/`, `engine/catalogue/`, `engine/ParchiCore/Sources/ParchiCore/` (new files), `engine/ParchiCore/Tests/ParchiCoreTests/` (new files), `app/Parchi/Support/AppData.swift` (new).

## Inputs (already collected 23 Oct 2026, with source URL + date on every row)
Folder: `~/dev/parchi-research/drive-staging/Parchi Data/` (read-only for you). Read its `README.md` first (it lists every file, its columns, how it was verified, and the known gaps). Files: `labs/labs.csv`, `prices/lab_prices.csv`, `product_links/product_links.csv`, `catalogue/tests_canonical.json`, `catalogue/schedule_h1_x.json`, `places/places_<city>.csv`, `contacts/` (do NOT ship contacts). 
Do NOT ship the Apple Maps places (Apple's MapKit terms: the app must query MapKit live). Ship only: labs, lab prices, product links, canonical tests, H1/X.

## 1. Build script `tools/build_app_data.py` (Python 3 stdlib only, with `unittest` tests in `tools/test_build_app_data.py`)
Reads the folder above (path as argv[1], default the folder above) and writes into `engine/catalogue/` (an existing bundle-resources folder; do not change project.yml):
- `labs.json`: only rows with status `confirmed`: city, lab, home_collection (yes/no/unknown), booking_url, phone, source_url, date_seen.
- `lab_prices.json`: {city: {lab: {test_canonical: {price_paise (int, price_inr*100), price_text, source_url, date_seen}}}} (skip rows with no price).
- `product_links.json`: only `usable_in_app == yes`: {medicine_key: {seller: {product_url, price_paise|null, mrp_paise|null, date_seen}}}. Never invent a price: a row without a price keeps null.
- `tests_canonical.json` (copy), `schedule_h1_x.json` (schedule, salt, source_url, date).
- `DATA_VERSION.json`: counts per file, build date, input folder name.
Money is integer paise everywhere. Idempotent (running twice gives identical files). Fail loudly on missing columns.

## 2. Rules in ParchiCore (pure Swift, no UIKit; `swift test` runs on this Mac from `engine/ParchiCore`)
New files:
- `PriceSource.swift`: `struct PriceSource { kind (mrp | online | shopReply | phoneCall), dateSeen: Date, label: String }` with `label` like "MRP", "Online, 23 Oct", "Shop replied 6:40 pm", "Called 24 Oct", and `isStale(now:)` = older than 7 days -> UI shows "may have changed" (requirement U20). Never show a price without a source + date.
- `TestNames.swift`: `canonicalTest(for written: String, catalogue:) -> CanonicalMatch` using `tests_canonical.json` synonyms (case/space/punctuation-insensitive); returns `.exact`, `.ambiguous([candidates])` (Free vs Total T3/T4, HbA1c vs average glucose, fasting vs PP glucose; use the file's `confusable_with`), or `.unknown`. Ambiguous ones must be ASKED on the confirm screen, never guessed.
- `ScheduleCheck.swift`: `isInPersonOnly(salt: String) -> Schedule?` for H1/X (salt synonyms: case/space-insensitive, handle "hydrochloride" suffixes); the UI will say "buy in person with the original parchi". Check whether `engine/catalogue/` or `~/dev/parchi-research/data` contains a brand-to-salt table; if yes add `isInPersonOnly(brand:)`, if no, say so in the report (do not invent one).
Unit tests for all of the above in `engine/ParchiCore/Tests/ParchiCoreTests/` (staleness boundary at exactly 7 days, ambiguous-test cases, H1/X hits and misses, label formats).

## 3. Loader `app/Parchi/Support/AppData.swift`
Codable models + a `final class AppData` that loads the bundle JSONs once. API: `labOptions(city:)`, `labPrice(city:test:) -> (paise, PriceSource)?`, `productLink(medicine:seller:)`, `dataVersion`. No force unwraps; missing file -> empty data + a logged warning. Do not wire it into screens or AppModel: instead write `app/DATA_INTEGRATION.md` (<= 30 lines) listing the exact hook lines Claude should add to AppModel/screens.

## Verify (MacBook can run both)
```
cd ~/dev/parchi && python3 -m unittest tools/test_build_app_data.py && python3 tools/build_app_data.py
cd engine/ParchiCore && swift test 2>&1 | tail -15
```
`AppData.swift` must also compile: build it on the iMac as part of the app only if the app builds there right now (rsync `app/` + `engine/` to `imac:parchi/`, never `server/.venv`, `server/data`); if another job has the project mid-edit and the build breaks outside your files, report that and do not touch their files.

## Report
Write `engine/KIRO_REPORT_DATA.md` (30 lines max): files created, exact final `swift test` and `unittest` summary lines (counts), the `DATA_VERSION.json` counts, brand-to-salt finding, anything unverified. Final chat message: 6 lines max.
