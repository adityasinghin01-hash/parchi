# KIRO_REPORT_K18: type it in yourself (add / remove a medicine or test on Confirm)
No git commit. Edited only `Screens/ConfirmView.swift` + NEW files in `Support/Manual/`, `ParchiTests/`, `ParchiUITests/`.

## Built
- `ConfirmView.swift`: "Add a medicine" / "Add a test" buttons below the lines (44 pt+, labels exactly those texts). Each line: swipe action AND a "..." menu with "Remove" (label "Remove <name>", menu button "Options for <name>"). A blank list shows a hint and a disabled "Add a medicine or test first". Existing labels ("All correct", "Answer the highlighted line", "Confirmed", strength buttons) unchanged.
- `Support/Manual/ManualBrandIndex.swift` (98): reads bundled `brand_mrp.json` off the main thread (actor, once). Only letters-only keys of 3+ letters (the ones the price lookup can match). Suggestions: prefix first, then contains, alphabetical, case-insensitive, max 20.
- `AddMedicineSheet.swift` (165): search + live suggestions ("Loading..." until loaded), strengths from the catalogue (intersected with the Confirm check's list so a pick never says "doesn't exist"; none -> number field), stepper "Tablets / units" (default 10, 1-1000), "Add". No brand match: `Add "xyz" as typed` -> existing "couldn't find" rule applies.
- `AddTestSheet.swift` (55): the 29 canonical tests + search; adds with the existing test matching.
- `AppModel+Manual.swift` (67): `addManualMedicine`, `addManualTest`, `removeManualLine`: rebuild via `loadReaderLines`, keeps name/strength/quantity/kind, re-applies "Ask my doctor" with `askDoctorAbout`. H1/X (Alprax) untouched: in-person message, no online price. Demo total Rs 2,696.77 unchanged (tested).

## Tests (iMac, own simulator, `~/parchi-dd-k18`, device deleted; synced to `~/parchi-k18`, not `~/parchi`)
- Full run, keys read inside ssh: `** TEST SUCCEEDED **`. Unit 66 tests, 0 failures (16 new `ManualAddTests`: ranking, cap 20, priceable only, rebuild keeps strengths/quantities, remove, Alprax message, typed unknown, 29 tests, ask-doctor kept). UI 23 tests, 0 failures (3 new `ManualAddUITests`). `SimulateCancelUITests` passed first time (no re-run needed).
- `ManualAddUITests`: blank Confirm (`-demoRoute confirm -demoReader ""`) -> Dolo 650 x 15 via real sheet + CBC -> remove CBC from menu -> plan shows "Catalogue MRP · check at the shop" and "Everything ₹34.27"; swipe "Remove Dolo 650"; Alprax 0.25 shows "Buy in person with the original parchi"; "Xyzzyqq" as typed blocks Continue.

## Screenshots `app/verify/k18-*.png`
confirm-blank, add-medicine-suggestions, add-medicine-details, add-test, confirm-dolo-cbc, remove-menu, swipe-remove, plan, alprax-in-person, unknown-as-typed.

## Lost on rebuild / note for the lead
- Ids are renumbered r1..rN. Strengths, quantities, chosen tests and "Ask my doctor" survive. Lost: the DEMO basket's ids ("dolo", "telma"...), so after any add/remove on the demo parchi the remaining demo lines are priced from catalogue MRP, not the demo scenario prices (total no longer 2,696.77; also `demoSchedules` for history). Untouched demo parchi is exact.
- Fix after K13 (6 lines in `AppModel`, keeps ids): `func addLine(_ item: RxItem) { var l = ReadLine(id: item.id, item: item, check: check(item)); l.testMatch = item.kind == .test ? canonicalTest(for: item.name, catalogue: data.testCatalogue) : nil; l.inPersonOnly = item.kind == .medicine ? data.scheduleCheck.isInPersonOnly(brand: item.name) : nil; lines.append(l); plan = nil }` and `func removeLine(_ id: String) { lines.removeAll { $0.id == id }; plan = nil }` (new ids e.g. "m\(UUID)"). NOTE: `lines` is currently plain `var` in the tree (the brief said `private(set)`), so this works today.

## Not done / found
- A parchi with a TEST plus medicines still gets NO plan: the planner has no offer for a test outside the demo (existing `CataloguePlanTests.testTestsKeepUsingLabPricesFromAppData`). So "Dolo + CBC -> plan with total" cannot hold; the UI test removes CBC before continuing. Owner: K13/K14 (AppModel/PlanView).
- Unknown-brand message reads "Did you mean ?" when there are no suggestions (existing text in ConfirmView, left as is).
- Hindi strings for the new texts; VoiceOver on a real iPhone not checked.
