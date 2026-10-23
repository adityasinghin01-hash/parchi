# KIRO report A3a: Checkout Assistant (A4)
**BUILD: SUCCEEDED** on the iMac (iPhone 17 Pro, `-derivedDataPath ~/parchi-dd-a3a`). Nothing committed.
Files (new, `app/Parchi/Support/CheckoutAssistant/`): CheckoutFlow 206 · CheckoutAssistantView 232 · WebViewHost 189 · SellerProbeView 126 · SellerSites 81 · CheckoutPrivacy 33 (`clearSellerSessions()` + `SignOutSellersRow`) · CheckoutRouteView 28. Also `engine/catalogue/seller_confirm_patterns.json` (empty `patterns`) and `app/CHECKOUT_INTEGRATION.md`.
Mount edits (3 tiny lines in ParchiApp.swift: Route case, switch case, `-demoRoute checkout` jump; 1 line in GetItAllView: "Open Checkout Assistant" button). AppModel and project.yml untouched.
Launch flags: `-demoRoute checkout [-checkoutStep 2] [-checkoutScreen probe] [-probeAuto 1]`.
Screenshots (`app/verify/`): a3a-step1.png (Truemeds, live product page), a3a-step2.png (Apollo lab booking page), a3a-probe.png (probe list with verdicts), a3a-probe-page.png (probe with the real Truemeds page loaded).
Seller probe (Simulator, product link from product_links.json, else home; auto-classified, 40 s timeout):
| Seller | Result |
|---|---|
| Truemeds | renders (21.5k chars; Login button shown; page never fires "finished", one run timed out on the product page) |
| Tata 1mg | renders (2k chars) |
| PharmEasy | renders (12k chars) |
| Medkart | renders, thin page (937 chars; may be a landing or soft wall) |
| MedPlus | blocked/blank: nothing rendered in 40 s on 2 of 3 runs |
| Netmeds | renders (product page 22.8k chars) |
| Apollo Pharmacy | home renders; product link timed out |
| Blinkit, Swiggy Instamart | render (product pages) |
| Redcliffe, Healthians, Apollo Diagnostics, Max Lab | render (booking/home pages) |
"Needs login" is NOT tested: nobody logged in, added to cart or paid. The probe has a manual per-row menu for it.
Assumptions: step order = online, then labs, then local shops. "Go to checkout" only changes state (no cart URLs known; none invented). Non-https links are cancelled, so UPI app hand-off (`upi://`) is blocked. Lab page = labs.json entry for Ghaziabad, else the lab home page. Shop SMS has no phone number yet.
Unverified: SMS composer on a real iPhone (Simulator uses the share sheet; share path not tapped); "Find on page" highlight not screenshotted; tapping Added/Ordered/Skip not UI-tested; `onSkip` has no re-plan wired; SignOutSellersRow not mounted in Settings. Probe rows for Apollo Diagnostics/Max Lab come from an earlier run (the shared Simulator killed the app mid-run; the last run stopped at MedPlus). Medkart/MedPlus verdicts are weakest.
