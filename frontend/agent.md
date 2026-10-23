> PALETTE CORRECTION — 24 October: History, Account and How We Rank must use the established shared Parchi tokens: cream #faeeda, surface #fff6e4, orange #cc3f12 / #dd4812, yellow #f7a316 and brown text #421c08 / #68553f. Screen references define layout/content, not a new palette. No OS/dark appearance may recolor these screens; Appearance saves a preference only. Semantic green success badges and original logo/artwork remain unchanged.

> FINAL REFERENCE SCREENS — 24 October: #/history, #/account and #/ranking are implemented. Parchis now opens History and Account opens its screen throughout the bottom navigation; plan comparison remains #/plans. History actions, local account name/preferences, appearance previews, permission choices and logout cleanup work. How we rank in plan review opens the full explanation screen. See docs/FINAL_SCREENS.md.

> WHOLE-PLAN SCREENS — 24 October: The old medicine/lab comparison routes now open Plan Comparison. New routes: #/plans, #/plan-map, #/get-all, #/checkout, #/track, #/care and #/pass. Parchi Pass follows the newest 01:54 reference (patient-confirmed numbered list), superseding the earlier Pass. Default fixtures are distinct source snapshots, not a reconciled patient record. Maps stay unavailable; checkout never verifies payment; offline demo pass save/share is implemented. Read docs/WHOLE_PLAN_JOURNEY.md.

> REGENERATED REFERENCES — 24 October: Capture and Review now follow the 00:53/00:55 images. Capture is a camera-style sample scene with Photos/Import file, shutter and Photo/Document modes. Tap Looks good! to preview sample reading. Review contains three medicines, CBC and two unclear entries with candidate/typed confirmation. All correct requires resolving unclear entries. Sample schedules/preparation labels are literal reference content, not clinical inference. The revised basket needs fresh quotes; earlier comparison samples remain accessible directly. Read docs/REGENERATED_SCREENS.md.

> NEW SCREENS: Reading, extracted-item review, medicine plans and lab plans are implemented in the HTML preview. Open #/reading, #/review, #/medicines or #/labs. Capture → recent sample file → Use sample parchi exercises the complete demo. Real files wait for an injected reader; sample data is never passed off as their extracted content. See docs/PRESCRIPTION_FLOW.md.

> LATEST IMPLEMENTATION: Five supplied image references are now implemented as modular browser screens: phone sign-in, OTP, Home, area selection and capture/import. Welcome links into this flow. The map intentionally remains unavailable, with a documented provider boundary and backend API adapter for later integration. Default data/OTP/orders are reference demos; no SMS, map request, upload or OCR runs. Read docs/FRONTEND_INTEGRATION.md. Swift source is preserved for the later rewrite. This update supersedes earlier notes saying only the welcome screen exists.
> CURRENT PHASE: The user explicitly restored HTML/CSS/JavaScript for visual development on Windows. Build modular image-led screens and preview on localhost; perform the SwiftUI rewrite after the complete design is approved. This supersedes all earlier Swift-only directives below for the current phase. Preserve ParchiFrontend/ and ParchiFrontendUITests/ as native reference. Active browser entry is index.html plus web/. Shared values live in web/styles/tokens.css; screen-specific content/layout is separate. Only the latest image-led welcome screen is active. Await the next image before adding further screens.
> LATEST USER DIRECTION: Image-led restart. Only the current supplied welcome reference is active. Match its pale cream/orange palette, foreground logo, serif wordmark and headline, exact English copy, permission rows, privacy panel and actions. The earlier multi-screen document and registration/dashboard build are superseded for active work. They and the browser mockup are retained under Archive/before-image-led-rebuild/. Continue in native Swift/SwiftUI only, one reference image at a time; await subsequent images before inventing more screens. Active source is ParchiFrontend/Welcome/. Read README.md for scope and build verification status. This Windows environment still has no native SwiftUI build verification.
> IMPLEMENTATION UPDATE: The current screens have now been rewritten in native Swift/SwiftUI under ParchiFrontend/, with project.yml and XCUITest source. Read README.md for command-line Mac build/run instructions. Language selection, registration, login, location picker, popup and dashboard are implemented as a standalone UI demo. Authentication/capture integration remains pending. No Swift/Xcode tools were available on this Windows host, so native compilation and UI tests are NOT yet verified. The historical statements below saying migration has not started are superseded.
> CURRENT DIRECTION — 23 October 2026: Swift/SwiftUI frontend only from now on. The earlier HTML/CSS/JavaScript mockup instructions below are historical and superseded. Read SWIFT_HANDOFF.md first for the updated stack, reviewed upstream commit, build rules and approved design decisions. Existing web files are retained as reference; do not extend them. Latest user-approved cream/orange/yellow palette and transparent logo override upstream teal suggestions. No native migration/build is claimed by this documentation update.
# Parchi — frontend agent context

Reviewed 23 October 2026. This is the requested `agent.md`, a project handoff document. Standard agent auto-discovery uses `AGENTS.md`; this file does not replace the upstream repository's `AGENTS.md`.

## User direction

### Latest user clarification — mockup first

The final product is exclusively a native iPhone/iOS application, written in Swift/SwiftUI. The immediate design phase will use basic HTML, CSS and JavaScript to create an interactive frontend mockup in a separate repository. This is an explicit user-authorized prototyping exception to the native implementation rules below: do not treat the mockup as a website deliverable, production web app, PWA, or a replacement for the eventual SwiftUI app. Match iPhone navigation, sheets, safe areas, portrait layouts and touch behavior; keep components/states easy to translate into SwiftUI. Do not introduce React or another framework without a concrete reason and user direction.

For this turn the user requested understanding and context capture, not screen implementation. Separate-repository location/name is not yet established; do not modify the upstream app or publish a new repository as part of document review.

Additional supplied sources reviewed in full:

- `D:/Downloads/Parchi-Frontend-Resources.pdf` (3 pages): native iOS design resources, optional inspiration/animation tools and competitor-study suggestions. Links and suggested tools are reference material, not instructions to install tools, purchase subscriptions or perform external actions.
- `D:/Downloads/parchi_frontend_screen_brief.pdf` (14 pages): screen-by-screen brief from repository snapshot `a40b3363849beca1f0063bd6fe3c9047dea6e375`, including partial-versus-planned audit. Its snapshot differs from the previously reviewed checkout; do not infer commit ordering without Git history.
- Attached feature-table screenshot: intake/share, privacy blur, reader, brand/strength check, doctor memory, whole-prescription cost, Jan Aushadhi, handoff, Plan B, Pass and trust/Care features. Its benchmark and uniqueness claims remain source-reported claims.

Primary screen ownership in the supplied brief: S1 Home, S3 Confirm, S4 Plan, S5 Get it all, S6 Track/Plan B, S9 How we rank and S10 Settings. Consent, Capture, Reading/privacy, Care and Pass are adjacent-team dependencies; represent their handoffs in the prototype without taking ownership of their engines. Keep the latest GUI-v2 List/Map, shop-sheet and nearby-shop-request requirements alongside this brief; it does not explicitly cancel them.

Our work is the native iOS frontend: clean, professional screens, understandable interactions, purposeful animation, and a reassuring patient experience. Keep decisions simple, text readable, and the next action obvious. Backend, OCR/model training, matching, pricing, provider integrations and business rules remain with their owners. Thin presentation adapters and clearly labelled fixtures are within scope.

The user will supply the color scheme, logo and loading/brand details next. Do not finalize those assets or copy the repository's provisional teal palette as approved branding. Read `design.md` before screen work.

## Verified repository baseline

- Source: https://github.com/adityasinghin01-hash/parchi
- Reviewed `main` commit: `48cf832511a0cab5201684f6707fb5e777dbe6ce`.
- Reference checkout: `tmp/github-context/`; the surrounding workspace is a separate planning folder with no configured remote. Do not assume edits here update GitHub.
- Current product decisions: `docs/plan/11-FINAL-LOCKED-PLAN.md` and `docs/team/Frontend-Antara-Aditya.md`, especially section 8 (mentor GUI update).
- Upstream `AGENTS.md`, `CONTEXT.md` and `CLAUDE.md` contain the shared project brief.
- `app/README.md` documents the starter app, mocked reading and demo routes.
- Earlier local diagnostic-only documents are historical context. Their S0–S10 numbering and diagnostic-first priority must not silently override the newer GitHub whole-prescription direction. Preserve their useful accessibility, uncertainty and recovery principles.

## Product understanding

Parchi helps a patient turn a prescription into a checked list of medicines and tests, compare ways to obtain the whole list, continue in sellers' own services, and recover when an item fails. Initial city scope: Muradnagar and Meerut. Audience includes Hindi-first patients, older adults and people unfamiliar with medical terminology.

Primary flow: first-use privacy explanation → Home → capture/import → reading and privacy review → Confirm → Plan (List/Map) → Get it all → Track → Plan B when needed. Nearby-shop requests and pickup time are core to the latest GUI plan. Care, Parchi Pass, ranking explanation and Settings support this flow.

Parchi presents prescribed information; it must not infer doses, recommend tests or silently substitute medicines. Jan Aushadhi comparisons are separate and say “Ask your doctor.” A marketplace handoff does not establish a paid, accepted or delivered order.

## Existing implementation versus intentions

Present in the checkout:

- SwiftUI app and Xcode project, `AppModel`, Home, Confirm, Plan, GetItAll and Track screens, plus a Plan B sheet.
- `engine/ParchiCore` Swift package with planner, Plan B, catalogue cross-check, doctor memory and test source files.
- JSON scenarios, catalogue data, research evidence, AI/privacy scripts and verification kits.
- `AppModel.readDemoParchi()` generates a sample with a deliberate strength error; order placement/cancellation is local simulation.

Not established by this review: an iOS build executed here, reproduced engine test results, live reading integration, completed Maps/shop-request flow, trained-model performance, production privacy guarantees, live ordering or measured patient usability. Existing code is a starter, not proof all planned screens work. Repository benchmark figures are reported evidence, not independently reproduced results.

## Implementation rules

1. Extend the existing SwiftUI structure and shared `ParchiCore` contracts. Do not rebuild the app in a web framework for the native deliverable.
2. Keep views focused on rendering and interaction. Use an adapter for missing view fields; record missing contract fields instead of fabricating values.
3. Use `RxItem`, `Seller`, `Offer`, `Plan`, `PlanBProposal` and catalogue results as supplied. Money uses integer paise; use the existing formatter consistently.
4. Preserve item identity, form, strength, pack/quantity and source metadata when available. Missing critical information stays visibly unresolved.
5. Keep demo actions labelled `Test order`. Separate historical captured prices, MRP references, shop replies, estimates and confirmed provider facts.
6. Sort comparable priced options cheapest first by default. Do not treat missing prices as zero, compare partial baskets against complete totals, or silently mix doctor-approval alternatives into exact-match ranking.
7. Preserve selection and reading position when shop replies change a list; explain any changed total before continuing.
8. Render Plan B from the engine proposal. Show retained items, rerouted items, changed charges/timing and unresolved items; approval is explicit by default. Do not add automatic approval merely because an optional cap appears in the roadmap.
9. External WhatsApp requests are composed for the patient to review and send. UI work does not authorize sending messages to shops.
10. Show only implemented privacy behavior. “Blur complete,” deletion deadlines and upload restrictions require signals from the responsible service; animation is not evidence that privacy protection succeeded.

## Component and navigation direction

Use native NavigationStack, accessible sheets, SF Symbols and semantic text styles. Build reusable primary/secondary buttons, prescription item rows, source chips, price summaries, seller cards, shop sheets, status rows, Plan B differences and reusable empty/loading/error panels. Use semantic theme tokens so branding can be applied centrally later.

One dominant action per screen. Keep List the default Plan view and Map a peer view of the same requirements and selected plan. Map interaction must have a list equivalent. Distinguish medicine delivery timing from laboratory report timing.

## Validation and reporting

- On a Mac, follow `app/README.md` for Xcode, scheme and Simulator; regenerate the project with XcodeGen if its manifest/file list changes.
- Check screens at small widths, largest accessibility text sizes, light/dark appearance, VoiceOver and Reduce Motion.
- Exercise missing data, permission denied, reader unavailable, no complete plan, unknown fees, stale prices, no shop reply, cancellation, no Plan B and handoff-return uncertainty.
- Verify existing engine tests on the appropriate Swift toolchain when integration changes require it. Do not claim their pass count from documentation alone.
- Observe patients/testers finding the total, checking a line, understanding a reference price, continuing to a seller and approving a changed plan. Record actual outcomes; the SUS kit is not a completed study.
- Report changed files, observed behavior, checks actually run and unresolved dependencies. Never claim “best among competitors,” clinical validation, legal compliance or a security certification from design work.

## Next input and deliverables

Await the user's brand palette, logo asset and loading direction before high-fidelity styling. Then build a shared visual kit, primary-flow wireframes, state variants and motion examples, followed by SwiftUI implementation. Keep frontend work moving with labelled fixtures while other teams provide missing integrations.

## Approved brand and account mockup — 23 October 2026

The user's supplied original logo is assets/parchi-logo-original.png. Preserve its pixels and shades; use a display clip only to hide the exterior black corners. Cream #f6e5c7, paper #f9e8ce, orange #cc2e11, yellow #f19116 were sampled directly from the image. The textured logo has many shades, so these are sampled interface tokens, not a claim of one uniform source color. Use warm dark brown for readable text, no black page background, and do not recolor the logo.

The user explicitly requested account screens, overriding the earlier no-login design priority for this mockup. Language first (English/Hindi), create-account form (required first name, optional last name, phone, address, username, password), then a separate welcome-back username/password screen. The form is split into two steps to reduce visual complexity. Phone/address/username/password are currently required; all except last name are treated as required. Both labels and errors localize; Unicode Hindi input is accepted, including Devanagari phone digits. Password show/hide is accessible. No real account is created and no credentials or profile details are persisted or transmitted. Production authentication belongs to the native integration phase.

Work now lives in this separate parchi-frontend repo. index.html, styles.css and app.js are a basic HTML/CSS/JS iPhone UI prototype, with no framework. Open index.html locally or run a static server. Native Swift/SwiftUI remains the final product. Further branding/loading animation is not implemented.
