(A) CONFIRMED means traced in current code and bundled data; outputs below are code-derived. No files modified, suites rerun, or simulator runs performed.

Severity | Status | Location | Concrete failing input → wrong output
HIGH | CONFIRMED | tools/build_catalogue_prices.py:260; engine/ParchiCore/Sources/ParchiCore/CatalogueMRP.swift:171 | Glycomet-GP PR, strength “2/500”, quantity 15 → ₹193.50 for the selected 2/850 product. Builder collapses both combinations under “2”; the 2/500 source pack costs ₹170.75.
HIGH | CONFIRMED | app/Parchi/Model/AppModel.swift:191; app/Parchi/Model/AppModel.swift:279; tools/build_app_data.py:160 | Aaram 0.5, quantity 10 → Jan Aushadhi alprazolam suggestion at ₹7.94, without the H1 warning. AARAM is missing from brand_schedule; catalogue composition correctly identifies alprazolam. Schedule generation ignores short-composition columns used by the new catalogue.
HIGH | CONFIRMED | app/Parchi/Model/AppModel.swift:404; app/Parchi/Screens/PlanView.swift:70 | A prescription containing only Dolo 650 ×15 → basket card claims “same salts” cost ₹189.48 at Jan Aushadhi. That is the old six-medicine total; this line’s calculated JA price is ₹15.47. The card also appears for an Alprax-only prescription despite suppression of its individual JA suggestion.
HIGH | CONFIRMED | engine/ParchiCore/Sources/ParchiCore/CatalogueMRP.swift:171 | Dolo, strength “650 mcg”, quantity 15 → ₹34.27 and a ₹15.47 JA suggestion for 650 mg tablets. Only the leading number is checked; incompatible units are discarded.
HIGH | CONFIRMED | engine/ParchiCore/Sources/ParchiCore/PackSize.swift:37; engine/ParchiCore/Sources/ParchiCore/CatalogueMRP.swift:67 | Gonal-F 75, quantity 3 → complete plan prices one vial at ₹2,089.67. Its “5.5 µcg” pack label is unparsed; three catalogue vials total ₹6,269.01. The one-pack disclaimer does not make the displayed whole-plan total complete.
MED | CONFIRMED | engine/ParchiCore/Sources/ParchiCore/CatalogueMRP.swift:140; engine/ParchiCore/Sources/ParchiCore/JanAushadhi.swift:408 | “Pan cap”, strength 40, quantity 15 → tablet price ₹155 and tablet JA suggestion. “cap” is discarded as an extra word but is not recognized as a stated capsule form.
MED | CONFIRMED | engine/ParchiCore/Sources/ParchiCore/PackSize.swift:38; engine/ParchiCore/Sources/ParchiCore/CatalogueMRP.swift:67 | Dolo 650 with quantity Int.max → overflow trap during ceiling calculation. Quantity 50,000,000,000,000,000 reaches multiplication overflow instead. Reader quantities have no upper bound (app/Parchi/Model/AppModel.swift:188).
MED | CONFIRMED | app/Parchi/Support/AppData.swift:116; app/Parchi/Model/AppModel.swift:241 | Confirm immediately after cold launch → MainActor synchronously loads catalogue data or waits for the prewarm task’s lock. Background prewarming does not guarantee a nonblocking first plan; latency was not measured.

CONFIRMED: ordinary missing offers block completion (engine/ParchiCore/Sources/ParchiCore/Planner.swift:43); PlanView disables checkout at app/Parchi/Screens/PlanView.swift:108.
CONFIRMED: recognized H1/X lines exclude online/quick-commerce offers at app/Parchi/Model/AppModel.swift:334. The Aaram classification gap prevents a blanket safety guarantee.
CONFIRMED: LazyValue loads once per instance, including concurrent access (app/Parchi/Support/AppData.swift:116). Catalogue-chip staleness still applies strictly after seven days (engine/ParchiCore/Sources/ParchiCore/PriceSource.swift:53; app/Parchi/Support/PriceChips.swift:12).

(B) UNCONFIRMED — most likely TEST hit-point problem: app/ParchiUITests/SimulateCancelUITests.swift:12 stops scrolling at isHittable, then line 14 taps the element’s geometric centre. Partial visibility does not establish that this centre clears Track’s bottom inset (app/Parchi/Screens/TrackView.swift:35). Repeating that coordinate would repeat the miss.
CONFIRMED: simulateCancel synchronously sets cancelled status and a proposal on MainActor (app/Parchi/Model/AppModel.swift:424); polling cannot start in Mock mode (app/Parchi/Model/AppModel.swift:519). I found no Mock polling/state-overwrite race.
UNCONFIRMED second candidate: sheet presentation during the launch-route navigation transition (app/Parchi/ParchiApp.swift:54; app/Parchi/ParchiApp.swift:65; app/Parchi/Screens/TrackView.swift:44). Live cancellation waits for server readiness first (app/ParchiUITests/PlanBFlowUITests.swift:26).
The evidence does not establish a real demo race or conclusively exclude one. Proposed test patch is unexecuted; it clears the footer and records whether cancellation actually ran:

--- a/app/ParchiUITests/SimulateCancelUITests.swift
+++ b/app/ParchiUITests/SimulateCancelUITests.swift
@@ -11,5 +11,12 @@
         let cancel = app.buttons["Simulate cancel"].firstMatch
-        for _ in 0..<8 where !(cancel.exists && cancel.isHittable) { app.swipeUp() }
+        let footer = app.buttons["What next? Doses and refills"]
+        for _ in 0..<8 {
+            if cancel.exists && cancel.isHittable
+                && cancel.frame.maxY < footer.frame.minY { break }
+            app.swipeUp()
+        }
         XCTAssertTrue(cancel.isHittable, "the demo cancel button should be reachable by scrolling")
+        XCTAssertLessThan(cancel.frame.maxY, footer.frame.minY)
         cancel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
-        XCTAssertTrue(app.buttons["Approve"].waitForExistence(timeout: 8), "tapping Simulate cancel should open the Plan B sheet")
+        XCTAssertTrue(app.buttons["Approve"].waitForExistence(timeout: 8),
+                      "cancel remains=\(cancel.exists); cancelled status=\(app.staticTexts["Cancelled by seller"].exists)")

Top 3 things to fix first: H1 classification gaps; combination-strength collapse; stale Jan Aushadhi basket total.