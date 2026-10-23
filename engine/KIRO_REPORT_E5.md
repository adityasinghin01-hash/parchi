# KIRO report E5: Jan Aushadhi matcher + printed-prescription parser

## Files (all new, in engine/ParchiCore/; nothing committed; D's files untouched)
- Sources/ParchiCore/JanAushadhi.swift: `JanAushadhiIndex(products:)`, `match(salt:strength:form:variant:) -> JAMatch?`, `matches(...)`, `products(fromJSON:)`
- Sources/ParchiCore/PrintedParser.swift: `PrintedParser(catalogue:)`, `parse(line:)`, `parse(lines:) -> [ParsedItem]`
- Tests/ParchiCoreTests/JanAushadhiTests.swift (16 tests), Tests/ParchiCoreTests/PrintedParserTests.swift (16 tests, 49 distinct lines: 22 structured with OCR noise, 12 single-line checks, 15 junk lines)
## Verify
`swift test --scratch-path ~/.swiftpm-e5` -> `✔ Test run with 91 tests in 0 suites passed after 0.169 seconds.` (59 existing tests still pass)
Known toolchain flake, present WITHOUT my files (checked on a copy): about every second `swift test` run fails to compile one test file with
"plugin for module 'TestingMacros' not found" / "Build failed". Re-run once and it passes. Not caused by this work.
## Matcher rules
Same salt set (combination order-insensitive, salt-form words like hydrochloride/sodium ignored, a few spellings unified), same strength per salt (mg/mcg/g converted; % and IU never mixed with mg), same form family, same release type (gastro-resistant counts as plain, SR/XR does not), same per-volume (5 mg per 5 ml). Rows with MRP 0, unknown form, or a salt without a strength are never matched. Result: product name, unit size, MRP in paise, `source` (PriceSource .mrp dated 2026-10-23) and source name. The type comment says: shown only as "Ask your doctor", never auto-substituted.

## Coverage measured
- Data: docs/research/evidence/janaushadhi_products_2026-10-23.json: 2439 rows, 343 without MRP, 2096 priced, 1646 understood well enough to match (78.5% of priced; the rest are devices, kits, pens, sprays, names with no unit).
- MIRAGE mentions (same 327 as ja_cov.py, brand->composition via medlex csv, one-off harness, deleted afterwards): Swift 182/327 = 55.7% (69.2% of the 263 with known composition). ja_cov.py: 187/327 = 57.2%.
  Swift is deliberately stricter than ja_cov.py: eye drops are not a syrup, per-volume must agree (Lantus 100 IU vs "per ml", Azithral 200 mg/5 ml vs JA "200 mg"), SR is not plain. It also finds 6 that ja_cov missed (Augmentin etc., "potassium clavulanate").

## Brand to salt
No usable brand-to-salt table in engine/catalogue/: brand_schedule.json maps only 253 H1/X brands to their scheduled salt; brand_strengths.json has strengths only. The only full brand->composition source is the medlex csv in ~/dev/parchi-research (not in the engine). So `match` takes the salt as input; nothing was invented.

## Parser behaviour
Fields are nil when not printed. A line is a medicine only with a dosage form, or a strength plus a schedule; any other line (doctor, date, advice) returns no fields and confidence 0.1. OCR fixes only inside numbers/schedules (4O, l-O-O, 0D), and in a brand only when exactly one repaired spelling is a real catalogue brand. Catalogue snap uses `Catalogue.check` and is reported in `check`; an unknown brand is never replaced (suggestions only) and caps confidence at 0.5. Confident means >= 0.7.

## Unverified
- Parser never run on real Apple Vision output, only on typed lines.
- Brand suffix words ("Pan D", "Augmentin Duo") are not validated; the catalogue check uses the first word only.
- Quantity from schedule x days is a hint (tablets/capsules only).
- Per-volume strictness lowers JA coverage on syrups and injections; loosening it needs a pharmacist's view.
