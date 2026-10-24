# Hindi extraction report

Drafts require a native speaker. Lexical extraction is not a Swift compiler; review manual candidates and rerun against the final frontend.

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

## Longest Hindi/English character ratios (layout risk)
- 2.33x: Placed
- 2.18x: How we rank
- 2.12x: Booking…
- 2.00x: Add
- 2.00x: Call
- 2.00x: Save
- 2.00x: Seen %@
- 2.00x: Track
- 1.88x: Probing…
- 1.88x: Testing…
- 1.78x: Ask shops
- 1.77x: Choose myself
- 1.75x: No trips
- 1.75x: Plan for
- 1.71x: Asking…
- 1.67x: Ask
- 1.67x: No shops to show yet.
- 1.65x: Nothing to track yet
- 1.65x: No fasting needed
- 1.62x: No reply

## Glossary violations
None in supplied translations.

## Needs manual interpolation/expression review
- Screens/ConfirmView.swift:76: Add a medicine or test first — interpolation type or nonliteral expression requires review
- Screens/ConfirmView.swift:76: All correct — interpolation type or nonliteral expression requires review
- Screens/ConfirmView.swift:76: Answer the highlighted line — interpolation type or nonliteral expression requires review
- Screens/ConfirmView.swift:161: %@ %@ doesn't exist. It comes in %@. Which one? — interpolation type or nonliteral expression requires review
- Screens/ConfirmView.swift:171: We couldn't find "%@". Check the spelling, or remove this line and add the medicine by hand. — interpolation type or nonliteral expression requires review
- Screens/ConfirmView.swift:172: We couldn't find "%@". Did you mean %@? — interpolation type or nonliteral expression requires review
- Screens/ConfirmView.swift:206: Left out of your plan. Ask your doctor which test they meant. — interpolation type or nonliteral expression requires review
- Screens/ConfirmView.swift:206: Which test? — interpolation type or nonliteral expression requires review
- Screens/GetItAllView.swift:37: Seen %@ — interpolation type or nonliteral expression requires review
- Screens/GetItAllView.swift:37: Price on seller page — interpolation type or nonliteral expression requires review
- Screens/PlanMapView.swift:109: Ask — interpolation type or nonliteral expression requires review
- Screens/PlanMapView.swift:135: in your plan data — interpolation type or nonliteral expression requires review
- Screens/PlanMapView.swift:164: Ask — interpolation type or nonliteral expression requires review
- Screens/PlanMapView.swift:165: In your plan — interpolation type or nonliteral expression requires review
- Screens/PlanMapView.swift:165: Not in your plan — interpolation type or nonliteral expression requires review
- Screens/PlanView.swift:57: Medicines %@ · reports %@ · %@ trips — interpolation type or nonliteral expression requires review
- Screens/ShopSheet.swift:55: Not available — interpolation type or nonliteral expression requires review
- Screens/ShopSheet.swift:60: Not available, the shop replied — interpolation type or nonliteral expression requires review
- Screens/ShopSheet.swift:156: no price — interpolation type or nonliteral expression requires review
- Screens/TrackView.swift:19: Placed — interpolation type or nonliteral expression requires review
- Support/BackendSwitchView.swift:44: Testing… — interpolation type or nonliteral expression requires review
- Support/BackendSwitchView.swift:44: Test connection — interpolation type or nonliteral expression requires review
- Support/Capture/CaptureView.swift:265: We could not find a name, phone or address to hide. — interpolation type or nonliteral expression requires review
- Support/Capture/CaptureView.swift:266: We hid %@ area%@ on this phone. — interpolation type or nonliteral expression requires review
- Support/Capture/CaptureView.swift:272: When you continue, this picture goes to the Parchi lab server to be read. A copy stays on this phone and is removed the next time you open Parchi after 24 hours. — interpolation type or nonliteral expression requires review
- Support/Capture/CaptureView.swift:273: Demo mode: this picture stays on this phone. It is removed the next time you open Parchi after 24 hours. — interpolation type or nonliteral expression requires review
- Support/CheckoutAssistant/CheckoutAssistantView.swift:98: Send this list to %@ — interpolation type or nonliteral expression requires review
- Support/CheckoutAssistant/CheckoutAssistantView.swift:120: This is %@'s real website. You tap Add to cart and Pay yourself. Parchi never clicks for you. — interpolation type or nonliteral expression requires review
- Support/CheckoutAssistant/CheckoutAssistantView.swift:121: You send the message and pay the shop yourself. — interpolation type or nonliteral expression requires review
- Support/CheckoutAssistant/CheckoutPrivacy.swift:22: Done. Seller logins and carts opened in Parchi are cleared. — interpolation type or nonliteral expression requires review
- Support/CheckoutAssistant/CheckoutPrivacy.swift:23: Clears logins and cookies of the seller websites you opened inside Parchi. — interpolation type or nonliteral expression requires review
- Support/CheckoutAssistant/SellerProbeView.swift:56: No page loaded — interpolation type or nonliteral expression requires review
- Support/CheckoutAssistant/SellerProbeView.swift:86: Probing… — interpolation type or nonliteral expression requires review
- Support/CheckoutAssistant/SellerProbeView.swift:86: Probe all — interpolation type or nonliteral expression requires review
- Support/Manual/AddMedicineSheet.swift:85: Add "%@" as typed — interpolation type or nonliteral expression requires review
- Support/Phase4/CareView.swift:93: Slot not confirmed yet — interpolation type or nonliteral expression requires review
- Support/Phase4/CareView.swift:96: Report expected %@ — interpolation type or nonliteral expression requires review
- Support/Phase4/FirstRunConsentView.swift:17: Your data stays yours — interpolation type or nonliteral expression requires review
- Support/Phase4/FirstRunConsentView.swift:42: Agree & continue — interpolation type or nonliteral expression requires review
- Support/Phase4/FirstRunConsentView.swift:49: Not now — interpolation type or nonliteral expression requires review
- Support/Phase4/FirstRunConsentView.swift:52: You can delete everything any time in Settings. — interpolation type or nonliteral expression requires review
- Support/Phase4/HistoryView.swift:45: %@ medicines · %@ tests — interpolation type or nonliteral expression requires review
- Support/Phase4/SettingsView.swift:64: Always ask me first — interpolation type or nonliteral expression requires review
- Support/Phase4/SettingsView.swift:64: Auto-approve up to ₹%@ extra — interpolation type or nonliteral expression requires review
- Support/Phase4/SettingsView.swift:101: Deletes saved parchis, doses, settings, your agreement, photo copies, seller logins, reminders Parchi scheduled and the message it copied on this phone, and asks our lab server to delete this phone's test orders. The server address and key stay so the server can be asked again. %@ — interpolation type or nonliteral expression requires review
- Support/Phase4/SettingsView.swift:105: Version %@ — interpolation type or nonliteral expression requires review
- Support/PriceChips.swift:40: Lab prices in %@ — interpolation type or nonliteral expression requires review
- Support/PriceChips.swift:77: No labs found yet for %@. — interpolation type or nonliteral expression requires review
- Support/ShopLab/LabBookingView.swift:28: Booking… — interpolation type or nonliteral expression requires review
- Support/ShopLab/LabBookingView.swift:28: Request booking · %@ — interpolation type or nonliteral expression requires review
- Support/ShopLab/LabBookingView.swift:81: Preferred: %@. The lab confirms or proposes another time. — interpolation type or nonliteral expression requires review
- Support/ShopLab/LabBookingView.swift:96:  · report %@ — interpolation type or nonliteral expression requires review
- Support/ShopLab/LabBookingView.swift:161: Home collection — interpolation type or nonliteral expression requires review
- Support/ShopLab/LabBookingView.swift:161: Visit the lab — interpolation type or nonliteral expression requires review
- Support/ShopLab/LabBookingView.swift:173: Fasting reminder will be set for %@ — interpolation type or nonliteral expression requires review
- Support/ShopLab/LabBookingView.swift:190: Demo mode: no lab was contacted. The confirmation is scripted so the flow can be shown offline. — interpolation type or nonliteral expression requires review
- Support/ShopLab/LabBookingView.swift:190: The lab confirms on a web page. Parchi never books or pays for you. — interpolation type or nonliteral expression requires review
- Support/ShopLab/LabBookingView.swift:199: Waiting for the lab to confirm · preferred %@ — interpolation type or nonliteral expression requires review
- Support/ShopLab/LabBookingView.swift:207: Collected around %@ — interpolation type or nonliteral expression requires review
- Support/ShopLab/LabBookingView.swift:211: Confirmed %@ — interpolation type or nonliteral expression requires review
- Support/ShopLab/ShopAskSheet.swift:36: Asking… — interpolation type or nonliteral expression requires review
- Support/ShopLab/ShopAskSheet.swift:36: Send to %lld shop%@ — interpolation type or nonliteral expression requires review
- Support/ShopLab/ShopAskSheet.swift:60: Keep ready by %@ — interpolation type or nonliteral expression requires review
- Support/ShopLab/ShopAskSheet.swift:72: Distance not known — interpolation type or nonliteral expression requires review
- Support/ShopLab/ShopAskSheet.swift:125: Keep ready by %@ · round %@ — interpolation type or nonliteral expression requires review
- Support/ShopLab/ShopAskSheet.swift:127: Demo mode: no message was sent. The reply below is scripted so the flow can be shown offline. — interpolation type or nonliteral expression requires review
- Support/ShopLab/ShopAskSheet.swift:127: Shops reply on a web page. The first complete reply wins. — interpolation type or nonliteral expression requires review
- Support/ShopLab/ShopAskSheet.swift:134: Ask next %@? — interpolation type or nonliteral expression requires review
- Support/ShopLab/ShopAskSheet.swift:143: %lld price%@ from this shop are ready to go into the plan. — interpolation type or nonliteral expression requires review
- Support/ShopLab/ShopAskSheet.swift:162: Replied %@ · ready by %@ — interpolation type or nonliteral expression requires review
- Support/ShopLab/ShopAskSheet.swift:167: Not available — interpolation type or nonliteral expression requires review
