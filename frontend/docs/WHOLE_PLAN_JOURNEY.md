# Whole-plan screens — 24 October 2026

The active prototype remains modular HTML/CSS/JavaScript. Native SwiftUI source is preserved for the later rewrite. These screens implement the latest images, including the **01:54:57 regenerated Pass**, which supersedes the earlier verified-prescription/seller-group Pass image.

| Route | Implementation |
|---|---|
| `#/plans` | Plan Comparison, List view, three complete-plan reference cards, selection, price/source expansion and four sort/filter chips. |
| `#/plan-map` | Same selected plan and requirements, compact cards, provider chips and unavailable map with the existing provider boundary. |
| `#/get-all` | Selected-plan summary, provider groups, collection preference, ranking sheet and sign-in dismissal. |
| `#/checkout` | Expandable seller stages, item selection/search, price breakdown, handoff control, explicit self-reported order updates and skipping. |
| `#/track` | Sample pharmacy/lab timelines, expandable item lists, detail/help sheets and unavailable delivery map. |
| `#/care` | Source-only dose schedule, self-reported taken status, category tabs, lab details, refill preference and reminder settings. |
| `#/pass` | Latest patient-confirmed numbered list, four medicines/two tests, real demo QR, user-controlled share and offline save. |

Old `#/medicines` and `#/labs` links display the replacement Plan Comparison. Their earlier templates remain unused reference source. The bottom Parchis/Track/Care tabs navigate to the new screens. Plan selection → Get it all review → Checkout Assistant is connected. Track → Need help → Open Parchi Pass also exposes the Pass.

## Modular implementation

- `web/journey.js`: view state, sorting, interactions, boundary hooks and offline export.
- `web/components/journey-ui.js`: shared header, navigation, provider artwork, icons, prices and status chips.
- `web/screens/{plans,get-all,checkout,tracking,care,pass}.js`: semantic HTML templates.
- `web/styles/journey.css`: isolated screen values using existing theme tokens and 735-unit artboard.
- `web/services/journey-fixtures.js`: literal source snapshots, not inferred medical or commercial data.
- `assets/references/`: unchanged supplied references; only artwork/logo regions are reused. The helper clips each source region to prevent surrounding screenshot UI leaking into logos.

Outer photographed iPhone frames are not duplicated within the shared phone shell. System fonts, touch targets, viewport length and the deliberately unavailable map prevent literal pixel identity. The design is rendered with real HTML controls rather than whole-screen screenshot overlays.

## Source inconsistencies and guarantees

The references are different snapshots. They cannot be treated as one reconciled patient order:

- Plan 1 says eight medicines. Get it all review allocates four plus three medicines, leaving one unspecified.
- Its total is ₹1,248, while the three displayed seller amounts total ₹1,198. The remaining ₹50 has no stated source. Expanded price details expose this; it is not silently labelled as a fee.
- Checkout's Apollo estimate is ₹830 while the three supplied item prices total ₹130. The ₹700 difference is disclosed in its expanded estimate.
- Tracking, Care and Pass have different item counts and names. They remain clearly labelled independent sample snapshots, not live consequences of payment, OCR or dose inference.

The screenshot's “Live price” chips become “Sample price” until a real provider supplies a verified price. Comparison crossed-out prices/savings are reference labels, not proven current discounts. No trips returns an empty result because all three source plans require trips. Readiness ordering and Best fit use explicit fixture metadata; no planner algorithm or clinical ranking is introduced.

A new confirmed prescription from the reader invalidates the old sample plans and shows Fresh plans are needed. Exploring the reference plans is an explicit separate action. Unknown quantities/fees stay unknown; changed checkout selection hides the stale estimate and disables checkout. No substitute medicine is chosen automatically.

## Integration boundaries

The existing `window.PARCHI_MAP_PROVIDER.mount(element,{area,onSelect,onStatus})` is retained. Default maps, directions and location remain unavailable; no SDK, tile request or keys are added. `onSelect({planId})` can select a known plan, and cleanup runs on rerender/navigation.

Optional `window.PARCHI_JOURNEY_SERVICE.loadPlans({items,area,signal})` returns `{plans}`. Plans need `{id,number,total,referenceTotal,saving,sellerCount,labCount,medicineCount,testCount,trips,ready,readyRank,bestRank,providers,cheapest?}` with integer paise for prices and exact basket/area attribution. No fixture prices are merged into a real result. Live review/checkout/Pass remain gated until their full data contracts are connected; the current downstream templates are reference snapshots. AbortSignal and response version checks prevent late results replacing a different route's state.

Optional `window.PARCHI_CHECKOUT_PROVIDER.prepare({sellerId,itemIds})` returns an HTTPS seller handoff URL. The user sees a link to open and reviews final items/payment on the seller service. Without a provider, checkout explains it is unavailable. It never claims a seller cart was prefilled or payment succeeded. No phone number, directions link or seller message is invented.

Mark as ordered requires the user's explicit completion checkbox and can record an optional order reference. This changes local self-reported state only. Skip leaves a visible incomplete stage. Neither action changes the reference tracking record or proves payment. Issue reports, slot preferences, reminder switches and auto-refill preferences remain in page memory; no booking, notification, purchase or external message is sent.

## Latest Parchi Pass

Uses Patient confirmed list rather than Prescription verified. Four numbered medicine rows include Tablet/10 tablets and two numbered test rows include 1 test. No seller affiliation or medical verification is inferred.

`assets/parchi-pass-demo-qr.svg` is a genuine generated QR with a JSON payload containing the sample pass ID, patient, area, medicines and tests. It does not point to a tracking URL or a verified partner registry. `assets/parchi-pass-demo-payload.json` records its content. The QR was generated from the bundled ReportLab encoder; the user's source images were not edited.

Save to phone downloads **Parchi-Pass-DEMO.html**, a standalone document with the QR embedded as a data URI and all item text. It opens offline and is visibly marked as a demo, not a verified medical record. Native share is used when available; otherwise a copy/save sheet is provided. Nothing is sent to a recipient automatically. Production partner acceptance, authenticated identity, expiry and privacy requirements remain service-owned.

## Verification

Headless Microsoft Edge on localhost verified selection across List/Map, sorting, no-trip empty state, expanded price discrepancy, three seller groups, collection preference, sign-in dismissal, checkout item search and invalidation, unavailable handoff, self-reported stage progression, skipped seller state, tracking expansion, taken-status update, confirmed refill preference, Care tabs, latest Pass wording/six numbered rows and a standalone download containing its embedded QR and all items.

All seven layouts were checked at 320, 390, 430 and 1280px for document/card boundary overflow. Screenshots were visually inspected. No JavaScript errors or external requests occurred in the default preview. This is not native compilation, physical-iPhone testing, production OCR/redaction, live order tracking, payment verification, clinical verification or completed usability research.
