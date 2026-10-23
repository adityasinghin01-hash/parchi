# Regenerated capture and confirmation — 24 October 2026

These references supersede the earlier capture/import landing screen and medicine-selection review layout:

- `WhatsApp Image 2026-10-24 at 00.53.00.jpeg`: camera-style Capture parchi screen.
- `WhatsApp Image 2026-10-24 at 00.55.45.jpeg`: Did we read it right? confirmation screen.

Implementation remains modular HTML/CSS/JavaScript for visual approval on Windows. SwiftUI is deferred. Shared orange/cream branding and the existing transparent logo are retained; these two screens use the new reference's lighter cream surfaces and compact sans-serif wordmark. Outer photographed device frames are not duplicated inside the existing phone shell.

## Capture — `#/capture`

Compact header, round back control, wood/prescription sample scene, framing advice, flash control, glowing document corners, Looks good! chip, Photos, shutter, Import file and Photo/Document modes.

- Photos opens image selection.
- Shutter opens the browser's camera-capable image picker in Photo mode; on Windows this normally opens a file picker. Document mode opens image/PDF selection.
- Import file accepts images/PDFs. The existing local preview and reader adapter are preserved.
- Flash explains that native camera control is not connected; it never pretends to switch hardware.
- The scene is clearly marked Sample preview. Tap **Looks good!** to run the simulated reading journey with the new reference sample. There is no image-quality detector or live camera stream.

The source prescription, plant and wood texture are reused only as artwork regions of the unchanged user image. The header, advice, flash, framing guides, status chip, shutter, imports and modes are semantic HTML/SVG/CSS controls. No whole-screen image overlay or generated replacement logo is used.

## Review — `#/review`

Initial sample: four confirmed entries (three medicines and CBC) and two unresolved entries. Medicines, forms, written schedules and the CBC label reproduce the supplied reference. They are fixture content, never generated treatment instructions, inferred schedules or a universal fasting rule.

Unclear medicine candidates: Telma 40, Telma 80, Telsar 40. Unclear test candidates: T3, Free T3, Total T3. The first candidate is visually highlighted as in the reference but has `aria-pressed=false` until explicitly selected. It is not automatically confirmed.

- Tapping a candidate confirms that literal choice and updates the summary.
- Type it opens a required name field and saves the patient's explicit correction.
- Resolved cards remain visible with Confirmed by you; unconfirmed counts update.
- All correct checks unresolved entries. It shows a clear error/focuses the first unresolved card instead of silently accepting uncertain extraction.
- Confirmed rows open the edit/remove sheet, including quantity for medicines. Editing clears the fixture Exact match/preparation badge; the edited value is only Confirmed by you.
- After all unclear entries are resolved, All correct emits `parchi:prescription-confirmed` with `{items,demo}` and opens comparison. No order, booking or external message occurs.

The new prescription differs from the older comparison reference. Accordingly, that journey shows unknown prices until fresh quotes are supplied. It does not reuse the old five-medicine price for the revised basket. Opening `#/medicines` or `#/labs` in a fresh page still previews the older supplied comparison fixture in isolation.

## Modules and integration

- `web/components/scan-ui.js`: shared new header and icons.
- `web/screens/capture.js`, `review.js`: replacements for the superseded layouts.
- `web/styles/scan.css`: isolated new layout values, sharing existing theme variables.
- `web/services/review-fixtures.js`: literal reference values and unresolved candidate metadata.
- `web/prescription-flow.js`: confirmation state/actions and existing reader/planner boundaries.
- `assets/references/capture-camera.jpeg`, `review-regenerated.jpeg`: original references, unchanged.

Reader item fields may include `unresolved`, `reviewTitle`, `reviewReason`, `reviewNumber`, `candidates`, `form`, `schedule`, `matchStatus` and `badge`. Show exact-match and preparation facts only when supplied by the responsible service. User correction does not establish a catalogue match or clinical validation. Artwork crops are sample-only metadata. Existing read/compare AbortSignal contracts and the unavailable map adapter remain unchanged; see PRESCRIPTION_FLOW.md.

## Checks actually performed

Headless Microsoft Edge on localhost: Photo/Document selection and keyboard switching, Photos file-picker event, flash explanation, sample capture → reading → new review, initial counts, blocking unresolved continuation, candidate confirmation, typed correction, edit clearing exact-match claim, revised basket invalidating stale prices, actual files waiting for the reader adapter, 320/390/430/1280px layouts, reduced-motion spinner and no browser JavaScript errors. Inspected screenshots at 390px for both screens.

The C: drive filled during image copying. Only temporary QA screenshots generated by this agent were removed; the reference was then successfully copied. No user originals were removed. Native camera, OCR, secure redaction, live catalogue/pricing and physical iPhone behavior remain unverified integrations.
