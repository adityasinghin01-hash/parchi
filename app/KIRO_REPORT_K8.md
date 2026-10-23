# KIRO_REPORT_K8: Phase 3-5 wired into the real app flow, UI test target added
**BUILD (iMac, xcodegen + xcodebuild, `~/parchi-dd-k8`, iPhone 17 Pro sim):** `** BUILD SUCCEEDED **`
**swift test (iMac):** `✔ Test run with 91 tests in 0 suites passed after 0.111 seconds.`
**UI test x3 (exact brief command, server on :8000):** each run `Test Case '-[ParchiUITests.PlanBFlowUITests testJudgeCancelShowsPlanBAndApproveReroutes]' passed` (9.308 s / 8.051 s / 8.012 s), `Executed 1 test, with 0 failures (0 unexpected)`, `** TEST SUCCEEDED **`. Assertions unchanged (real tap on Approve -> "Re-routed (Plan B)" -> server planVersion 2, state placed).

## Wired (file -> change)
- AppModel: `data`, `location` (LocationProvider), `consent`; `ReadLine.testMatch/inPersonOnly/askDoctor`; `choose(test:)`, `askDoctorAbout`; H1/X offers never from delivery sellers (`plannerOffers`); `skipSeller` (excluded sellers + replan, keeps old plan if none left); `priceSource`, `productLink`; `saveApproved` on approve (schedule nil); Live `/order` gets `autoApproveCapPaise` from `parchi.autoApproveCapPaise` (0 -> nil); screenshot-only `-demoTestRead <text>`.
- ConfirmView: test rows ("Which test?" + one button per name + "Ask my doctor", "We could not match this test"); H1/X "Buy in person with the original parchi".
- PlanView: source chip + "may have changed" (>7 days) on every line; LabPricesSection (Meerut/Muradnagar, cheapest first, "Price not found yet"); How we rank link; "Searching around" -> CityPickerView. GetItAllView: chip + product-page links ("Seen ₹x" or "Price on seller page"). New `Support/PriceChips.swift`.
- HomeView: gear -> Settings, Recent parchis, Care. TrackView: "What next?" -> Care. SettingsView: K7's sign-out block replaced by `SignOutSellersRow()`.
- ParchiApp: `TempFileStore().purgeExpired()` at launch and when active. LabReminders address key -> `parchi.address`. CheckoutRouteView: `onSkip` -> `model.skipSeller`. project.yml: location Info key, `ParchiUITests` target, shared scheme `Parchi` with it.
- Delete everything: already calls `POST /reset` (K7 `ResetClient`). Run in the app (Live, UI-driven): "Server copy deleted (4 test orders)."; sqlite `orders` count 0 afterwards. Also curl: 1 -> 0.

## Decisions / skipped
- First-run consent NOT mounted: its text promises name blur and a 24 h purge, and the app has no Capture/blur yet. Reachable only via `-demoRoute consent`.
- Item 6 (Jan Aushadhi index) skipped though E5 is done: RxItem has no salt and no brand->salt table exists in the app (E5 report says the same), so no medicine has a known salt. The plan keeps the aggregate "ask your doctor" line. Needs a brand->salt table.
- Demo basket has no ambiguous test, so the Confirm screenshot uses `-demoTestRead T3` (Free T3 / Total T3).
- Price dates: scenario prices use 23 Oct 2026 (fixed constant); Jan Aushadhi/doctor shop shown as MRP, others as "Online".

## Screenshots (app/verify/k8-*.png)
confirm-tests, confirm-ambiguous-test, plan-top, plan-labs-meerut (real prices), plan-labs-muradnagar ("Price not found yet"), plan-bottom, plan-after-skip, settings, settings-bottom, delete-dialog, delete-result, history, care, home, track, checkout, planb-live (Live, judge cancel of Truemeds).

## Unverified
- Care shows "Can't tell": no dose schedules from the reader yet. Skip re-plan seen once in Simulator (total 2,696.77 -> 2,806.17); a skipped seller's replan after orders are placed is not handled. Hindi UI, real-phone location prompt, product links opening in Safari, and the stale ("may have changed") label were not exercised. The screenshot-only UI test file was removed after use.
