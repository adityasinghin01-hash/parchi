# Wiring the bundled real data (hooks for AppModel / screens)
`Support/AppData.swift` is new and not wired. Data JSONs come from `python3 tools/build_app_data.py` into `engine/catalogue/` (already a bundle-resources folder; run `xcodegen generate` once so Xcode sees the new files).
API: `AppData.shared` -> `labOptions(city:)`, `labPrice(city:test:)` (cheapest), `labPrices(city:test:)`, `labPrice(city:lab:test:)`, `productLink(medicine:seller:)`, `productPrice(medicine:seller:)`, `dataVersion`, `testCatalogue`, `scheduleCheck`.

## AppModel.swift
1. Property: `let data = AppData.shared`
2. `ReadLine` gets `var testMatch: CanonicalMatch?`; in `readDemoParchi()` / `choose` set it for tests:
   `testMatch = item.kind == .test ? canonicalTest(for: item.name, catalogue: data.testCatalogue) : nil`
3. `ReadLine.needsAnswer`: add `if case .ambiguous = testMatch { return true }`; add `func choose(test: String, for lineID: String)` that sets `lines[i].item.name = test` and `testMatch = .exact(test)` (never guess).
4. Medicines: in `check(_:)` caller add `var inPersonOnly: Schedule?` = `data.scheduleCheck.isInPersonOnly(brand: item.name)`; `planner` must not route these to delivery sellers.

## ConfirmView.swift (Tests section, line 16)
- `.ambiguous(names)`: yellow row "Which test?" with one button per name (+ "Ask my doctor"); `.unknown`: "We could not match this test".
- `LineRow` (medicines): if `line.inPersonOnly != nil` show `Schedule.inPersonMessage` ("Buy in person with the original parchi").

## PlanView.swift / GetItAllView.swift (prices)
- Wrap every shown price as `(paise, PriceSource)`: show `source.label` (use `datedLabel` for MRP); if `source.isStale(now: .now)` add `source.staleNote(now: .now)` ("may have changed", U20).
- Tests: for `city = "Meerut"` (or Muradnagar) `data.labPrices(city:test:)` -> rows cheapest first; `data.labOptions(city:)` for booking URL / phone / home collection. Muradnagar has no lab prices: show "Price not found yet", never copy Meerut's.
- Medicine hand-off: `data.productLink(medicine: "azithral_500", seller: "Blinkit")?.productURL` -> `openURL`. A nil price stays "price on seller page".

## Notes
- Demo medicine keys: azithral_500 and the other 5 in `product_links.json`. Apple Maps places are NOT bundled: use MapKit live.
- Rebuild data any time: `python3 tools/build_app_data.py` (idempotent), then `cd engine/ParchiCore && swift test`.
