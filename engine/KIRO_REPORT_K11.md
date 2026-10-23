# KIRO_REPORT_K11: catalogue MRP + Jan Aushadhi equivalent for any medicine (U7, U6)
**Result (iMac, own sim + `~/parchi-dd-k11`, `~/.swiftpm-k11`):** `swift test`: `Test run with 129 tests in 0 suites passed` (97 old + 32 new). `xcodebuild test` (scheme Parchi, all targets, live env set): ParchiTests 8/8, ParchiUITests 8/8 (incl. PlanBFlow + ShopAskLive live), `** TEST SUCCEEDED **`. Python: `tools.test_build_catalogue_prices` 16 + `test_build_app_data` 12 OK.
## Files
- New: `tools/build_catalogue_prices.py` (+`test_...py`), `engine/catalogue/brand_mrp.json` (5.61 MB), `janaushadhi_products.json` (0.47 MB, copy of the 23 Oct list), `ParchiCore/.../PackSize.swift`, `CatalogueMRP.swift`, tests `CatalogueMRPTests.swift` + `CatalogueSample.swift`, `app/ParchiTests/CataloguePlanTests.swift` (new unit target in `project.yml`).
- Edited: `PriceSource.swift` (+`note`, `catalogueMRP`), `DATA_VERSION.json` (+`janaushadhi_list_date`, `brand_mrp` counts; re-running `build_app_data.py` rewrites it, so run it first), `AppData.swift` (lazy loaders, `catalogueOffer`, `janAushadhiEquivalent`), `AppModel.swift`, `PlanView.swift`. `ConfirmView.swift` not needed.
## Bundle size (12.4 MB first try -> 5.6 MB)
Non-discontinued allopathy only; descriptions/side effects dropped; one pack per brand+strength+extra words+form+release; one string per brand ("strength,m,p,form*4+release,salt,extras"), pack/salt/extra tables by index, most used first. 132,037 brands, 187,599 strengths, 215,604 entries, 189,220 of them with a salt composition. Loaded lazily on a background task.
## Coverage (measured by `measureCoverageOnDemoMedicinesAndSample`)
- 6 demo medicines: MRP 6/6, Jan Aushadhi 6/6 (Dolo 650 Rs15.47, Pan 40, Telma 40, Glycomet SR 500 (prolonged release), Azithral 500, Montair LC).
- Sample of 200: Python `random.seed(20261023)`, `random.sample` of non-discontinued rows sorted by id, name as printed + first number as strength: MRP 181/200, salt known 158, Jan Aushadhi 105 (listed one by one and checked by eye: same salt, strength, form, release). The 19 misses: numberless syrups of a brand that also has numbered products, 1-2 letter brand words, extra words that match nothing.
- Every `brand_strengths.json` brand has an MRP entry except 12.
## Rules I applied (please check)
- Pack pick = lowest MRP per unit (not the cheapest strip: a 1-tablet strip would make 15 tablets cost 15 strips). Telma 40 therefore uses the 30-strip Rs 245.95.
- "Telma 40" never gets "Telma H 40" (extra words must be equal). Exception: plain brand + only marketing-word products with ONE common salt ("Augmentin 625" -> "Augmentin 625 Duo").
- Written SR/MR/DT must exist, else no price. Plain written + only SR exists: priced, no Jan Aushadhi. Letter codes MR/OD/LA/TR: priced, never matched. No form written: tablet/capsule preferred; two oral forms = no Jan Aushadhi.
- Numberless products kept only for brands with no numbered product. H1/X lines: no Jan Aushadhi line. Unreadable pack size: 1 pack, chip says so. A medicine with no price blocks the plan with "No catalogue price found yet for ..." (never an invented price). Tests unchanged (lab prices; a reader test not in the demo still blocks the plan as before).
- Chip text exactly "Catalogue MRP · check at the shop" (no date in the text; the 7-day "may have changed" still applies). Jan Aushadhi line shows the cost of the line quantity (cheapest pack combination).
## Screenshots `app/verify/`
`k11-demo-plan.png` (Everything Rs 2,696.77, unchanged; a Jan Aushadhi line now sits under Glycomet SR), `k11-nondemo-plan.png` (Dolo 650 / Augmentin 625 / Pantop 40: total Rs 412.69, catalogue chip, pack text, Jan Aushadhi lines). Made with new screenshot-only `-demoReader "Dolo:650:15;..."`.
## Skipped / not verified
Confirm screen shows no price; GetItAll not edited (shows the catalogue chip per shop via `priceSource(sellerID:)`); no real-phone run; Hindi untested; gel vs cream count as one Jan Aushadhi "topical" family (existing index rule).
