> PALETTE CORRECTION — 24 October: The original shared cream/orange/yellow Parchi theme overrides the final reference images’ lighter backgrounds and all earlier dark-preview notes. History, Account and How We Rank now use shared theme tokens. Appearance saves a preference only; system/dark mode cannot recolor the approved preview. Logo and semantic success badges are preserved.

# Final reference screens — 24 October 2026

Added the user's final three image-led layouts to the active modular HTML/CSS/JavaScript prototype. SwiftUI remains the later implementation phase.

| Route | Screen and behavior |
|---|---|
| `#/history` | Your History, All/Medicines/Lab Tests/Orders filters, month grouping, date blocks, status chips and record actions. |
| `#/account` | Profile, Add/Edit name, Quick Access, language/notification/appearance preferences, privacy choices and logout. |
| `#/ranking` | How We Rank, three illustrated factors, referral disclosure, price-source sheet and contextual Back to Plan. |

The Parchis tab now opens History throughout the app; Account opens the Account screen. Plan Comparison remains `#/plans`. History is selected on the bottom bar while viewing plans as well, keeping the Parchis category consistent. Account Quick Access links to History, Saved Addresses and Pass. The existing area chooser returns to Account after confirmation. How we rank in Get it all review opens the full explanation screen and remembers the originating plan route.

## Files

- `web/profile.js`: new screen state, forms and actions.
- `web/screens/history.js`, `account.js`, `ranking.js`: semantic screen templates.
- `web/services/profile-fixtures.js`: six literal source history entries.
- `web/components/profile-ui.js`: vector icons sharing the existing icon style.
- `web/styles/profile.css`: scoped light/dark preview values, card spacing and responsive layout.
- `assets/references/{history-final,account-final,ranking-final}.jpeg`: unchanged supplied images. History/ranking illustration regions are reused through the clipped artwork helper; forms, titles, rows, tabs and navigation remain live HTML.

## Implemented states

History starts with six sample records in October, September and August 2026. Filters return five medicine records, four test records and five order records. Partial completion remains visibly distinct. The Sharma sample links to the existing four-medicine/two-test example Pass and returns to History. Missing reports open a clear unavailable sheet; no lab findings are fabricated. Reorder records without medicine names ask for the original prescription rather than comparing an unrelated basket. No older records are invented.

Account starts with the reference's demo phone and a visibly disclosed sample verification badge. Guest mode and logout do not show that badge. A successfully returned demo OTP profile supplies its own phone. Add name requires a non-whitespace first name, allows an optional last name and supports Unicode. Fields are escaped when rendered. Whitespace validation clears correctly after correction.

Language stores English/Hindi preference only; it does not claim full-app translation. Notification and privacy choices are local preferences, not device grants or scheduled notifications. Appearance stores System/Light/Dark as a preference only; all three screens keep the approved shared brand palette. System appearance changes do not recolor this preview. No personal details or preferences are placed in persistent browser storage.

Logout asks before clearing the page's unsaved data, revokes a selected file URL, invalidates pending authentication, cancels reader/quote work and resets local profile, phone/code, addresses, manual entries, order notes and preview preferences. It returns to sign-in. Signing in again restores identity without leaving the Account screen stuck in guest state. Server-session logout remains a future backend contract; the active adapter is a UI demo. Reloading the prototype starts fresh reference fixtures.

How We Rank reproduces the provided Total Price, Ready Time and Number of Trips explanation and referral copy. Its design-preview note distinguishes this copy from verified business policy or a production ranking algorithm. Price-source details explain reference/quote/estimate distinctions and explicitly retain unknown fees. No live price source or referral arrangement is claimed.

## Checks performed

Headless Microsoft Edge against localhost verified:

- History filters, record details, report-unavailable state, reorder without invented items, historical Pass navigation and return.
- Account navigation, required first-name validation and correction, Unicode names and optional last name.
- Language and notification labels, dark appearance, local privacy choices and address return routing.
- Full ranking screen, three factors, source explanation and contextual return.
- Logout clearing identity/history and a successful OTP sign-in afterward.
- All three layouts at 320, 390, 430 and 1280px without horizontal document or card-boundary overflow.
- No JavaScript errors or external requests in the default preview.

Screenshots were visually inspected, including dark Account. Native iPhone behavior, full translation, live account/history/report services, device permissions, notifications and production referral/ranking policy are not verified by these frontend checks.
