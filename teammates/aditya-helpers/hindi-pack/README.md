# Hindi pack — READY (tooling and drafts only)

Finds supported SwiftUI text literals and creates a translation sheet.
Drafts cover every extracted key in this app snapshot.
Exports reviewed rows to an Apple String Catalog.
Reports interpolation uncertainties and String expressions needing source changes.
Does not edit Swift source or enable Hindi in the app.

## Run in three commands
From `teammates/aditya-helpers/`, with Python 3.11:
```powershell
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements.txt
.venv/Scripts/python -m pytest hindi-pack/tests -q
```
On macOS/Linux substitute `.venv/bin/python`. The sprint used `.venv311`.

## Extract / export
With the environment active, set `PYTHONPATH=hindi-pack/src`. Full example:
```powershell
python -m hindi_pack ../../app/Parchi --out hindi-pack/out --translations hindi-pack/draft-translations.json --glossary hindi-pack/glossary.csv
```
Input is any folder containing Swift files. Output is the CSV sheet, `Localizable.xcstrings`, counts/report, extraction details and `not-auto-localizable.md` with source locations and fixes. Extraction reads the selected checkout; rerun it on the final frontend.

For human-reviewed CSV rows, use `--sheet path/to/reviewed-sheet.csv` instead of the initial draft map. The tool preserves their statuses and translations; it never invents a review. Record the native reviewer's first name, date and keys in `out/REVIEW-LOG.md`.

Default export contains **reviewed rows only**; currently it is intentionally empty. `out/Localizable.draft.xcstrings` is a separate demo artifact with `needs_review` units. To create another draft demo export, use `--include-drafts --out path/to/demo-output`; do not replace the production catalog with it. Placeholder mismatch or empty reviewed translations stop export.

## Later app check by the lead
After native review and manual source fixes, copy `Localizable.xcstrings` into `app/Parchi/`, include it in the app target and add `hi` to known regions. Rebuild and launch the simulator with `-AppleLanguages "(hi)" -AppleLocale hi_IN`. Screenshot every screen, checking clipping, Dynamic Type and interpolation meaning.

## Files
`src/hindi_pack/`: lexical extractor, CSV/catalog validation and CLI. `tests/fixtures/`: Swift snippets covering every specified call, exclusions, raw/multiline strings and expressions. `glossary.csv`: contextual terms. `draft-translations.json`: draft mapping. `out/`: generated artifacts and review log. `RESULTS.md` / `test-output.txt`: measured results.

## Honest limits
**Drafts are NOT reviewed. Nothing ships to patients until a native speaker signs off.** The tool is a conservative lexical scan, not Swift syntax/type resolution. Unknown interpolation types and dynamic expressions require manual review. The not-auto report intentionally includes possible non-UI configuration/data; review those candidates before changing source. Plural suffixes carried as `%@` need rewriting by the lead for natural Hindi. The longest-length ratios flag possible layout risks, not measured clipping. No Xcode build or device/simulator check ran on Windows. This module does not claim that installing a catalog alone translates every screen.
