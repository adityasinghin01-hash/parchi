> PALETTE CORRECTION — 24 October: The original shared cream/orange/yellow Parchi theme overrides the final reference images’ lighter backgrounds and all earlier dark-preview notes. History, Account and How We Rank now use shared theme tokens. Appearance saves a preference only; system/dark mode cannot recolor the approved preview. Logo and semantic success badges are preserved.

> FINAL REFERENCE SCREENS — 24 October: #/history, #/account and #/ranking are implemented. Parchis now opens History and Account opens its screen throughout the bottom navigation; plan comparison remains #/plans. History actions, local account name/preferences, appearance previews, permission choices and logout cleanup work. How we rank in plan review opens the full explanation screen. See docs/FINAL_SCREENS.md.

> WHOLE-PLAN SCREENS — 24 October: The old medicine/lab comparison routes now open Plan Comparison. New routes: #/plans, #/plan-map, #/get-all, #/checkout, #/track, #/care and #/pass. Parchi Pass follows the newest 01:54 reference (patient-confirmed numbered list), superseding the earlier Pass. Default fixtures are distinct source snapshots, not a reconciled patient record. Maps stay unavailable; checkout never verifies payment; offline demo pass save/share is implemented. Read docs/WHOLE_PLAN_JOURNEY.md.

> REGENERATED REFERENCES — 24 October: Capture and Review now follow the 00:53/00:55 images. Capture is a camera-style sample scene with Photos/Import file, shutter and Photo/Document modes. Tap Looks good! to preview sample reading. Review contains three medicines, CBC and two unclear entries with candidate/typed confirmation. All correct requires resolving unclear entries. Sample schedules/preparation labels are literal reference content, not clinical inference. The revised basket needs fresh quotes; earlier comparison samples remain accessible directly. Read docs/REGENERATED_SCREENS.md.

> NEW SCREENS: Reading, extracted-item review, medicine plans and lab plans are implemented in the HTML preview. Open #/reading, #/review, #/medicines or #/labs. Capture → recent sample file → Use sample parchi exercises the complete demo. Real files wait for an injected reader; sample data is never passed off as their extracted content. See docs/PRESCRIPTION_FLOW.md.

# Parchi frontend — browser design preview

Current phase: modular HTML/CSS/JavaScript. The approved screens will be rewritten in native SwiftUI after the visual design is complete. Swift source is preserved under ParchiFrontend/ and its build notes are in NATIVE_BUILD.md.

Start the preview from this folder:

    python -m http.server 8765 --bind 127.0.0.1

Open http://127.0.0.1:8765/. ES modules require HTTP; do not open index.html using a file URL.

Structure:
- web/styles/tokens.css: shared colors, typefaces, radii and motion tokens.
- web/styles/components.css: reusable controls, cards, device preview and dialogs.
- web/components/icons.js: reusable decorative/icon artwork.
- web/screens/welcome.js and welcome.css: reference-specific screen content and layout.
- web/app.js: interactions and navigation events.

Current screen follows DesignReferences/01-welcome-reference.jpeg. The transparent logo is reused without changing its file. It is a semantic interactive layout, not a screenshot pasted as the screen.

Permission switches are design previews held in memory only; they do not request device access or collect analytics. The privacy-blur paragraph matches the supplied reference, but no OCR, redaction or upload pipeline is implemented here. Continue emits parchi:welcome-complete; the next screen awaits its reference. No real account or consent to external data processing is created.

The UI is intended as an iPhone app mockup, not a production website. Browser rendering and static checks do not establish native SwiftUI behavior or a native build.


## Next five screens

Welcome now connects to phone sign-in, six-digit OTP, Home, Choose your area and Capture/import. Open the root URL and click through, or use #/signin, #/home, #/area and #/capture. Verify requires a phone challenge first. Demo OTP: 482931; no SMS is sent.

The map is deliberately unavailable. Manual area selection works, and web/services/map.js exposes a replaceable provider mount/cleanup boundary. Backend request contracts and source-artwork handling are documented in docs/FRONTEND_INTEGRATION.md. The current adapter is a local demo, not a connected authentication or order service.

Form fields, numeric keypad, navigation, area controls, search and file pickers are interactive. Selected files stay local; no OCR/upload runs. Reference illustrations are reused only as artwork crops, while the interface is live semantic HTML/CSS.
