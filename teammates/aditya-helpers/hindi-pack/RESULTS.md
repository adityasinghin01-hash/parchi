# Hindi pack — measured results

Commands from `teammates/aditya-helpers/`:
```powershell
$env:PYTHONPATH="hindi-pack/src"
python -m hindi_pack ../../app/Parchi --out hindi-pack/out --translations hindi-pack/draft-translations.json --glossary hindi-pack/glossary.csv
python -m pytest hindi-pack/tests -q
```

Python 3.11.16. Source: current main app at repository commit 0d5c1d9; rerun against the final frontend.

```text
...............................................................          [100%]
63 passed in 1.77s
```

```json
{
  "files": 63,
  "found": 275,
  "skipped": 677,
  "needs_manual": 71,
  "not_auto_localizable": 533,
  "drafts": 275,
  "translated_nonempty": 275,
  "catalog_entries": 0,
  "glossary_violations": 0
}
```

All extracted keys have nonempty draft translations with placeholder parity. Zero glossary violations in this run. The default catalog has zero entries because no human review is recorded; `Localizable.draft.xcstrings` has 275 needs_review entries for demonstration only.

Review fixes: filter standalone interpolations, date format strings, configuration keys, and clearly named sellers; preserve the production #else arm of DEBUG blocks; distinguish purchase order from ranking order; preserve savings/MRP placeholder meaning. The not-auto report is deliberately conservative and contains configuration/data false positives. Unknown interpolation types, plural suffixes and nonliteral expressions need manual checking. This is lexical analysis, not a Swift compiler or proof that the entire app is localized. No simulator, iPhone layout test or native-speaker review was performed.
