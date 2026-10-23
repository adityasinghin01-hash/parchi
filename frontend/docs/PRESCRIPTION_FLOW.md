# Image-led prescription flow

The four supplied references dated 23 October, 23:27–23:30 are implemented in HTML/CSS/JavaScript, continuing the user's browser-first visual workflow. SwiftUI remains a later rewrite. The lab reference has an outer device frame: the app renders its content within the existing shared phone shell rather than duplicating that frame.

## Preview

- `#/reading`: staged sample reading, cancel/back, visually blurred sample photo and privacy card. Advances to review after about 4.4 seconds. Reduced-motion mode stops spinner animation.
- `#/review`: five sample medicines and two tests, selection, quantities (1–99), medicine/test tabs, image preview, edit/remove sheet and continuation.
- `#/medicines`: four sample pharmacy offers, selected plan, details, sorting, completeness filter, unavailable map and selection event.
- `#/labs`: four sample lab offers, collection/report labels, badges, completeness/home-collection filters and selected plan.
- Full sample journey: Capture → any recent sample thumbnail → **Use sample parchi** → Reading → Review → Continue to stores → comparison tabs.
- Real local image/PDF: Capture → choose file → Use photo or file. With no reader adapter, the reading screen explains that no upload occurred and offers the explicit sample journey. It never returns the sample's medicines as extraction from the user's file.
- Manual entry: save list → Review. Provider quotes are unavailable until an adapter supplies them; no sample medicines or prices are substituted.

The comparison sample is the exact reference list order, initially selecting the reference's Best value provider. The initial sort label reproduces the reference. Explicit sorting applies the chosen metric, grouping complete baskets before partial baskets. Unknown prices are never zero. Price is held in integer paise.

Changing quantity, text, strength, pack or selection invalidates the fixture quote for that basket. Providers then show unknown prices and require refreshed quotes; Continue is disabled. A partial offer also cannot continue as a complete plan. These prototype guards are presentation logic, not a replacement for the planner or matching engine. No doses, substitutions or test recommendations are generated.

Default prices, stock, timing, distances, city names, logos and provider badges come from the supplied images. They are marked as reference samples, not current offers, verified local coverage, commercial affiliations or medical advice. The default sample offers retain the reference's HSR Layout labels; changing the area does not make those samples live local offers. The screen's map remains unavailable and no external map requests run.

## Replaceable reader/planner boundary

Inject `window.PARCHI_PRESCRIPTION_SERVICE` before `web/app.js`:

```js
window.PARCHI_PRESCRIPTION_SERVICE = {
  async read({file, signal, onProgress}) {
    // Honour abort, perform consented processing, then return confirmed fields.
    // onProgress(1|2|3) is presentation progress, not evidence of redaction.
    return {items: [], privacy: {redacted: false}};
  },
  async compare({items, kind, area, signal}) {
    // kind is 'medicine' or 'test'; items preserve identity and quantities.
    return [];
  }
};
```

Items: `{id, name, kind:'medicine'|'test', detail, quantity}`. Unknown prescription details must stay explicit in `detail`; the adapter must not infer doses. Views add `selected` for local selection only. Quotes are a separate service request from reading.

Offer shape: `{id, name, kind, pricePaise:null|integer, distance, area, availableCount:null|integer, requiredCount, readyLabel, readyMinutes:null|number, badges:[[icon,label,tone]], bestValue?}`. Icon keys include `home`, `flask`, `calendar`, `clock`. Tones include `green`, `amber`, `red`, `blue`, `warm`, `neutral`. `crop`/`sourceName` are reference artwork metadata and unnecessary for live providers. Readiness and collection/report statements must come from the service; no UI-generated promise or timestamp conversion occurs. Final fees and handoff remain future integrations.

Both requests receive AbortSignal. Cancelling/backing out invalidates late read responses and clears demo timers; switching comparison routes invalidates late quote responses. Quote responses should correspond exactly to the submitted basket and area.

Map uses the existing `window.PARCHI_MAP_PROVIDER.mount(element,{area,onSelect,onStatus})` boundary and calls its cleanup on close. No SDK or keys are introduced. Selecting an area returns to the comparison route that opened it.

Continue emits `parchi:plan-selected` with `{offer,items,area,demo}` and opens a review sheet. There is no checkout, order, reservation, payment or external seller message. The combined Get It All screen awaits the next user reference; its tab currently opens an explanatory sheet.

## Visual implementation

- `web/screens/reading.js`, `review.js`, `compare.js`: screen templates.
- `web/styles/prescription.css`: shared flow components on the existing 735-unit artboard and theme tokens.
- `web/prescription-flow.js`: cancellable flow state and interactions.
- `web/services/prescription.js`: isolated reference fixtures and service boundary.
- `assets/references/{reading,review,medicine-options,lab-options}.jpeg`: original user references, unchanged. The helper reuses only prescription imagery, medicine pack artwork and provider logo regions. Titles, controls, cards, checkboxes, timers, prices and navigation are live semantic HTML.

CSS blur is a local visual effect only. It is not secure image redaction. The sample reproduces the reference's privacy copy as a marked demo; real local files get an explicit processing-unavailable state until the responsible service is connected. Selected files remain in page memory, and object URLs are revoked when replaced/unloaded.

## Verification — 24 October 2026

Verified in headless Microsoft Edge against localhost:

- Sample capture → staged reading → seven-item review → medicine/lab comparison.
- Complete/partial provider selection, selected price, details and non-ordering continuation sheet.
- Completeness and home-collection filters; unavailable map sheet.
- Quantity change invalidates reference prices and disables continuation.
- Cancel prevents the delayed demo transition; real file without adapter stays unavailable rather than receiving sample extraction.
- Manual text survives review; missing quotes render an explicit integration state.
- Edit/remove, empty selection, keyboard tab navigation and focus retention.
- All four routes fit 320, 390, 430 and 1280px browser widths without horizontal document overflow or clipped card boundaries. Visual screenshots inspected at 390px and lab layout at 320px.
- Injected mock adapter returns its own items; an empty quote result requests once; cancellation aborts and ignores a late reader result.
- Area confirmation returns to the originating comparison; welcome/sign-in/home/capture still render.
- No browser JavaScript errors during those checks.

Not verified: production OCR/redaction, live prices/stock, maps, provider checkout, native SwiftUI compilation, physical iPhone or patient usability. Screens are reconstructed UI rather than pixel-identical screenshot overlays; platform fonts and accessible control sizing affect exact line metrics.
