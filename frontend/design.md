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
# Parchi — patient frontend design foundation

Status: pre-brand design specification, 23 October 2026. Based on GitHub `main` at `48cf832511a0cab5201684f6707fb5e777dbe6ce`, especially the locked plan and frontend brief section 8, plus the user's request for a clean and professional patient experience. This is a design direction, not implemented screens or a measured usability result.

## Experience goal

### Delivery clarification from the user

Final platform: **native iPhone/iOS app in Swift/SwiftUI**, not a website. Immediate artifact: **basic HTML/CSS/JavaScript interactive UI mockup in a separate repository**, used to agree on screens and interactions before native implementation. Browser rendering is only the prototyping medium. Build app screens and transitions, not a marketing site, desktop dashboard or responsive website navigation. Do not begin implementation merely from the attached briefs; the current request is to absorb the context.

For the mockup, emulate portrait iPhone viewports, safe-area spacing, back navigation, native-style sheets, touch-sized actions and keyboard/scroll behavior. A desktop may show a centered phone preview. Keep structure, tokens, components and named states suitable for translation into SwiftUI; web preview checks do not prove native VoiceOver, Dynamic Type, MapKit, share extension, Calendar or notification behavior. Platform integrations are labelled demonstrations until implemented natively.

The 3-page frontend resources PDF and 14-page frontend screen brief were reviewed on 23 October 2026. The latter covers snapshot `a40b3363849beca1f0063bd6fe3c9047dea6e375`. It focuses this frontend work on S1, S3, S4, S5, S6/Plan B, S9 and S10; show adjacent-team screens as handoffs when needed. Its partial-implementation audit is snapshot-specific. Preserve the GUI-v2 map/shop flow from the reviewed repository unless the user changes it.

Suggested design priority after branding: shared tokens/components → Confirm → Plan → Track/Plan B → Get it all/Home → How we rank/Settings → complete state and localization coverage. Use the source scenario for demo prices and label simulated events. Resource links, competitive claims and screenshot benchmark figures are reference content, not independently verified facts or authorization to install, purchase, send messages or alter scope.

A patient should know what was read, what needs checking, what the whole prescription will cost under the stated evidence, where to obtain it, and what happens if something fails. The interface should feel calm and clear even when the underlying task involves several sellers and labs.

Use a simple visual hierarchy: screen question → key information → next action → optional explanation. Present complexity progressively without hiding material fees, uncertainty or medicine identity. Avoid dense dashboards, promotional banners, countdown pressure and unexplained scores.

## Product scope and information architecture

The current product combines medicines and diagnostic tests in one prescription plan. The older local follow-up-only proposal is historical. Keep one continuous journey and open secondary detail in sheets or dedicated detail screens.

```text
First-use notice → Home → Capture/import → Reading/privacy → Confirm
  → Plan [List | Map] → Get it all → Track → Plan B review
             ↳ Shop details → Ask shops → Pickup time → Reply status
Confirm / Plan / Home → Parchi Pass
Track → Care
Plan → How we rank
Home → Settings & privacy
```

Use the repository's S0–S10 screen names when coordinating with its frontend team. Capture is a separate step. Avoid adding a large tab bar until persistent destinations justify it; the existing NavigationStack is a suitable foundation.

## Screen specifications

| Screen | Patient question | Essential layout and action |
|---|---|---|
| S0 Privacy notice | What happens to my photo? | Short, accurate explanation of local processing and any upload; review/continue action; accessible language control. Claims follow implemented capabilities. |
| S1 Home | Where do I start? | One large “Scan or share parchi” action, recent prescriptions with date and text status, quiet Settings access. No login barrier to scanning. |
| Capture | How do I add it? | Scan, Photos and supported file/share entry; preview, retake and continue. Explain permission only when requested. |
| S2 Reading | What is happening? | Photo/processed crop, actual stage label and truthful progress. Visible privacy review before any supported upload. Keep corrections/manual continuation available when reading fails. |
| S3 Confirm | Did it read correctly? | Medicines and tests in separate sections; name, strength, form and quantity where supplied; uncertain source crop with up to three valid choices and manual entry. “All correct” follows supplied validation. All items remain inspectable. |
| S4 Plan — List | What will it cost to get everything? | List/Map control; comparable complete plans sorted by known total; primary total, medicine ETA, report ETA, trips and fee/source disclosure. Selected card opens seller breakdown. |
| S4 Plan — Map | Where can I get it nearby? | Native Apple map, price/distance pins, selected stops, delivery-only option strip and list fallback. Only known locations/prices appear. |
| Shop sheet | Can this shop supply my items? | Name, distance, known opening status, covered/missing items, per-item prices and source/time. Call, Directions, WhatsApp and Ask actions where supported. |
| Ask shops | Can they keep it ready? | Up to three selected shops, explicit pickup date/time, editable request preview and “Open WhatsApp.” Show waiting/replied/no-reply states using actual events. Opening WhatsApp does not mean sent. |
| S5 Get it all | What happens when I continue? | Exact selected terms grouped by seller, fees and totals; next seller action and handoff explanation. Use “Place test orders” only for sandbox mode, with visible “Test order.” |
| S6 Track | What is happening, and what do I do next? | One next-action panel plus seller/item timelines. Distinct medicine and lab status language; last update and confirmation references if provided. |
| Plan B sheet | What changes after a failure? | Failed items, retained items, replacement source and cost/time difference, unresolved items; explicit approval and choose-myself/cancel route. Keep completed items visually stable. |
| S7 Care | What is next? | Supplied prescription schedule, lab appointment and reminder controls. Ask Calendar/notification permission here; never invent dosage or fasting advice. |
| S8 Parchi Pass | What do I show at the counter? | Large confirmed typed list, confirmation date and supported QR. Avoid encoding unnecessary identity; QR is not proof of a valid prescription or fulfilled order. |
| S9 How we rank | Why is this first? | Plain explanation matching the selected objective and real ranking rules; disclose commercial relationships when applicable. |
| S10 Settings | What can I control? | Language, implemented privacy controls, consent record, accurate capability information and clearly separated demo controls. Confirm destructive deletion and report success only after completion. |

## Plan comparison rules

- Default to cheapest first for comparable complete baskets. Provide explicit Fastest/Fewer trips preferences backed by the engine; indicate when changing preference changes order or selection.
- “No trips” is appropriate only when the selected plan actually requires zero visits. Otherwise use “Fewer trips.”
- Each option identifies what its total covers. Separate medicine-only and test-only options from whole-prescription options.
- Unknown fees read “Fee not confirmed.” A subtotal cannot be styled or labelled as a final payable amount.
- A local MRP reference is not a shop quote, stock confirmation or pickup promise. Show these as separate facts.
- Keep Jan Aushadhi doctor-approval comparisons in a clearly labelled separate section, outside actionable exact-brand rankings.
- Replace broad “ready by” language with separate delivery/pickup and report estimates. Show dates when “tomorrow” could be ambiguous.
- Incoming shop replies may update and reorder options, but should not move a card beneath a finger during a tap. Preserve the chosen option and announce changed terms.

## Visual foundation — branding pending

The repository suggests teal/green, but the user will provide the actual palette. No final hex values, logo treatment or branded loading animation are approved.

| Token group | Foundation |
|---|---|
| Color roles | `background`, `surface`, `textPrimary`, `textSecondary`, `border`, `actionPrimary`, `attention`, `failure`, `success`, `focus`; supply accessible light/dark pairs after palette input. |
| Typography | iOS semantic system text styles with Dynamic Type. Title for the question, headline for item/seller, body for essential facts, readable secondary text for source metadata. Monospaced digits for stable amounts. |
| Spacing | Proposed 8-point rhythm with 4-point refinements; 16–20-point page insets and generous separation between decisions. Adapt to size and text scale. |
| Shape | Proposed 16-point card radius; native controls/sheets; restrained borders and elevation. Avoid a card inside every card. |
| Icons | SF Symbols with visible text where meaning is uncertain. Text and icons carry status together. |
| Actions | One dominant filled action; quiet secondary actions. Minimum 44×44-point targets; aim for 50–56-point main buttons. Never cover content or keyboard with a fixed footer. |

Keep critical medicine names, strength, cost and action labels fully readable. The upstream “two lines per row” suggestion applies only when content fits; accessibility text sizes and exact identity take priority over fixed card heights or truncation.

## Components

Build a shared set: primary/secondary button, prescription item row, source chip, attention panel, plan summary, seller card, fee breakdown, price pin, shop sheet, pickup picker, quote status, next-action card, timeline row, Plan B difference row, permission panel and empty/error/loading state.

Source chips use patient language: “MRP reference,” “Captured [date],” “Shop replied [time],” “Fee not confirmed,” “Test order,” “Patient uploaded.” Longer explanations open on tap. A catalogue match alone must not imply that the entire prescription line, dose or source has been verified.

## Writing and customer experience

Use familiar words and direct actions: “Check this line,” “See fees,” “Ask this shop,” “Review Plan B.” Explain “parchi” as “prescription” when useful. Keep brand, form, strength and quantity intact when translating.

Every interruption answers: what happened, what remains safe/available, and what the patient can do next. Preserve entered information and selected pickup time after a recoverable failure. Returning from a seller opens the same prescription and shows “Confirmation not received” when the result is unknown.

Avoid “guaranteed cheapest,” “medically cleared,” invented savings, model-confidence percentages presented as safety, and claims that an upload is an authenticated provider report. Repository statistics and price snapshots need their date, scope and evidence; they are not evergreen product promises.

## Loading and motion

Brand-specific loading visuals remain pending. Use functional loading states meanwhile:

- Initial load: show known content and a simple placeholder/progress indicator for pending sections.
- Reading: use actual stages such as “Checking photo” and “Reading prescription.” Do not invent line counts, percentages or a blur-complete signal.
- Sending/approval: disable repeat submission, show a short action label, and wait for confirmation before success.
- Waiting for shops: show request state and last update; avoid an endless full-screen spinner.
- Long wait/failure: explain the issue and offer retry, manual review or return without losing work.

Motion should connect a tap to its detail, distinguish changed Plan B terms, or acknowledge a completed action, then stop. Proposed short transitions are roughly 150–250 ms, subject to device review. Avoid counting prices up, looping scan effects, confetti and auto-scrolling lists. Respect Reduce Motion; meaning survives without animation or haptics. Announce asynchronous status changes accessibly without repeatedly interrupting reading.

## Accessibility and localization

Target at least 4.5:1 contrast for body text; verify the actual approved palette. Support largest accessibility text sizes with flexible vertical layouts, full labels and scrolling. Maintain logical VoiceOver order; announce item, strength, status and relevant action. Do not group multiple buttons into an inaccessible card.

Map pins require accessible labels and a full list alternative. Selection uses text/icon/border as well as color. Check light/dark mode, Reduce Motion and increased contrast. Provide English/Hindi strings without fixed-width assumptions; read-aloud repeats confirmed source information rather than generating instructions.

## Required state inventory

Every primary screen needs populated, empty, loading, recoverable-error and unavailable-data states as appropriate. Specifically cover camera/location denial, poor photo, unreadable line, source image unavailable, reader timeout, offline, unknown form/strength, no complete plan, unknown fee, expired price, missing map data, shop request not sent, waiting/no reply, partial reply, seller cancellation, no replacement, changed terms and unknown handoff outcome.

Do not predesign success as the only path. Retrying an uncertain external action must be governed by the integration owner's reconciliation result.

## Review gates

Before calling screens ready:

1. A new tester can start, correct an uncertain item and explain the total and its scope.
2. The tester can distinguish reference prices, shop replies, estimates and test orders.
3. List and Map maintain the same prescription/selection; incomplete coverage is visible.
4. Shop requests show pickup time and actual handoff/reply state.
5. Plan B clearly identifies retained versus changed items and requires an informed action.
6. Key content works on a small iPhone, largest text, VoiceOver, dark mode and Reduce Motion.
7. The starter app runs in Simulator and its complete route is rehearsed on a Mac; document real checks separately from repository-reported results.

Use `docs/verification/usability-SUS-kit.md` and the survey kit as research tools. Record participant count, tasks, mistakes and changes; do not claim competitor superiority or a usability score before testing.

## Next design input

Pending from the user: approved colors and appearance variants; logo assets and usage; loading direction/assets. After these arrive, apply theme tokens, make the core-flow wireframes/high-fidelity screens, define state variants and validate the patient journey before expanding secondary features.

## Approved brand and account mockup — 23 October 2026

The user's supplied original logo is assets/parchi-logo-original.png. Preserve its pixels and shades; use a display clip only to hide the exterior black corners. Cream #f6e5c7, paper #f9e8ce, orange #cc2e11, yellow #f19116 were sampled directly from the image. The textured logo has many shades, so these are sampled interface tokens, not a claim of one uniform source color. Use warm dark brown for readable text, no black page background, and do not recolor the logo.

The user explicitly requested account screens, overriding the earlier no-login design priority for this mockup. Language first (English/Hindi), create-account form (required first name, optional last name, phone, address, username, password), then a separate welcome-back username/password screen. The form is split into two steps to reduce visual complexity. Phone/address/username/password are currently required; all except last name are treated as required. Both labels and errors localize; Unicode Hindi input is accepted, including Devanagari phone digits. Password show/hide is accessible. No real account is created and no credentials or profile details are persisted or transmitted. Production authentication belongs to the native integration phase.

Work now lives in this separate parchi-frontend repo. index.html, styles.css and app.js are a basic HTML/CSS/JS iPhone UI prototype, with no framework. Open index.html locally or run a static server. Native Swift/SwiftUI remains the final product. Further branding/loading animation is not implemented.


Latest refinement: removed the welcome subtitle, bottom plus/assurance panel and header tagline on all screens. Removed numeric registration step text while retaining the section label and right-hand progress bars. Phone uses a fixed +91 prefix and flexible aligned input. Address is replaced by a location-selection sheet: current device location with permission, manual area/city/PIN entry, and Muradnagar/Meerut shortcuts. Live place search/reverse-geocoding is not connected; current location displays actual coordinates, and manual selection is retained only in page memory. English/Hindi labels and recovery states are included.


Registration now shows a brief modal confirmation, then opens Home automatically after 2.2 seconds or on the dashboard action. Removed the profile-preview paragraph. Home shows name, location, scan/share action and an empty recent-parchis state. Capture remains a next-screen placeholder. All screens use assets/parchi-logo-transparent.png, edited with the built-in image tool to remove black corners and the cream tile while preserving the foreground logo. Original retained. No pixel-identical claim is made for the edited cutout. Profile stays only in page memory; credentials clear after submit.
