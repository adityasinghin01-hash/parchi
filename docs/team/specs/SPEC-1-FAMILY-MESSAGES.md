# SPEC 1: "Tell my family" messages and reminders. Owner: Aditya Singhal. Folder: `teammates/family-messages/`
Read `README.md` in this folder first (working agreement + iMac rules).

## Why (the user need)
Many patients are elderly or not comfortable with phones. The person who pays, arranges pick-up or worries is often a son, daughter or neighbour who is not in the room. Today everything lives on one phone. Parchi should let the patient (or whoever holds the phone) tell one trusted person, in one tap, what is happening: plan ready, order placed, a Plan B change that needs a decision, a lab visit tomorrow (fasting?), a refill due. Local reminders on the phone already exist; this adds a human in the loop.

## What you build (scope)
A small, stateless **message library + link builder + sandbox**, in Python, that the lead can later call (as a tiny local service) or port to Swift (it is just templates and string rules).
1. `compose(event, lang, fields, options) -> Message`: fixed, reviewed message templates for 7 events in English and Hindi.
2. `links(message, phone) -> {whatsapp, sms}`: ready-to-open links: `https://wa.me/<digits>?text=<percent-encoded UTF-8>` and `sms:<digits>?&body=<encoded>`. The PATIENT's own phone sends the message when they tap Send. Parchi never sends it. This works today with no provider and no approval.
3. `SmsProvider` interface + `SandboxProvider` (writes to an outbox: in-memory list + a JSON-lines file inside your folder) + `RealProvider` stub that raises `NotConfigured`. Reason: sending SMS automatically from a server to Indian numbers requires DLT registration by an Indian registered entity (sender ID and pre-approved templates); this is stated in provider guides, not a TRAI primary source, and cannot be done in a day. So the module must be READY for it (fixed templates with placeholders, see below) but must not depend on it.
4. A sandbox web page `GET /outbox` (FastAPI, `127.0.0.1:8042`) listing composed messages, so a judge can see them without a phone.
5. `should_send(event, prefs, now) -> bool`: respects opt-in per event, quiet hours (default 22:00 to 07:00 IST; `plan_b_needed` may break quiet hours only if the user ticked "urgent alerts"), and a minimum gap between messages (default 10 min) so the family member is never spammed.

## Events (input contract; JSON, all fields minimal and non-identifying)
```json
{"event": "plan_ready|order_placed|plan_b_needed|plan_b_done|lab_slot_tomorrow|refill_due|report_ready",
 "lang": "en|hi",
 "fields": {"itemCount": 6, "testCount": 2, "totalPaise": 269677, "sellerNames": ["Medkart", "Doctor's shop"],
            "readyByIso": "2026-10-24T17:30:00+05:30", "labName": "Dr Lal PathLabs", "slotIso": "2026-10-25T07:30:00+05:30",
            "fasting": true, "refillInDays": 3, "isTestOrder": true, "priceDate": "2026-10-23"},
 "options": {"includeMedicineNames": false, "medicineNames": [], "senderLabel": "Aditya"}}
```
Rules the templates MUST follow:
- Default = counts, not medicine names (a WhatsApp/SMS message is not private). Medicine names only when `includeMedicineNames` is true, and then only the written brand names given.
- No patient name unless the person typed `senderLabel`; never a phone number, address or report result in the text.
- If `isTestOrder` is true the text says "Test order" (sandbox orders are always labelled).
- No doses, no "you should take", no recommendation of a test or brand. Fasting is stated only as "the lab asks you to fast; please check with them" when `fasting` is true.
- Prices are shown with their date: "about Rs 2,696.77 (prices of 23 Oct)". Unknown price = "price not confirmed", never 0.
- No urgency tricks. `plan_b_needed` says what happened and what decision is waiting, nothing more.
- Hindi: write natural, polite Hindi ("आप" form). Mark every Hindi template `reviewed: false` until a native speaker signs it off in `HINDI-REVIEW.md`; the lead will not ship unreviewed Hindi.

## Template design (DLT-ready)
Store each template as a FIXED string with named placeholders and a stable `template_id`, e.g. `plan_ready.en.v1`: `"Parchi: your plan is ready. {itemCount} medicines, about Rs {total} (prices of {priceDate}). Nothing is ordered yet."` Keep the fixed text separate from variables so the same file can later be submitted for DLT template approval. Provide `templates/*.json` and a test that no template renders an unfilled `{placeholder}`.

## SMS length (this is where people get surprised)
Hindi (Devanagari) is sent as UCS-2: 70 characters per single SMS (67 per part when concatenated); English GSM-7: 160 (153 per part). Implement `segments(text)` correctly (detect GSM-7 vs UCS-2, count extension characters twice), expose `charCount` and `segments` in the `Message`, and add a warning when a message needs more than 1 segment. Target: every default template is 1 segment in English and at most 2 in Hindi.

## Phone numbers
`normalize_in_phone(s) -> "91XXXXXXXXXX" | None`: accept `98XXXXXXXX`, `+91 98XXXXXXXX`, `091…`, spaces/dashes; reject anything that is not a 10-digit Indian mobile starting 6 to 9. Stateless: never store a number beyond the request, never log one.

## Tests (pytest) you must write
- Every event x language x (names on/off) renders; no `{placeholder}` left; no forbidden words (dose, mg per day, "take", "should") in default output; Rs formatting with Indian grouping (Rs 2,69,677.00 style is NOT used: use plain Rs 2,696.77 as the app does).
- `segments()` against hand-counted cases (English, Hindi, mixed, emoji, `{}`/`[`/`^` extension characters).
- Link builder: percent-encoding of Hindi, `+`/`&`/newline handling, URL stays under 2,000 characters.
- `should_send`: quiet hours across midnight, opt-out, min gap, urgent override.
- Golden files for every default message (committed), so a wording change is visible in review.

## End-to-end check on the iMac (in `~/teammates/family-messages/`)
1. Start your service on `127.0.0.1:8042`; `POST /compose` with the 7 example events (both languages) and open `/outbox` in the iMac browser.
2. Take the status words from a REAL demo order read-only: with `PARCHI_TEST_KEY` call `GET http://localhost:8000/status/{orderId}` on an order Aditya created, map its state to an event, compose. Show the mapping table in `RESULTS.md`. (If no order exists, say so; do not fake one.)
3. Open 3 generated WhatsApp links on a real phone with a test number Aditya gives you and confirm the text arrives intact, including Hindi. Record yes/no per link.

## Acceptance
- [ ] 7 events x 2 languages, golden files, all tests green; `RESULTS.md` has the test count and the segment table.
- [ ] No default message contains a medicine name, patient name, phone or address.
- [ ] `RealProvider` exists and raises `NotConfigured`; `SandboxProvider` works; nothing in the repo contains a provider key.
- [ ] Hindi templates flagged unreviewed until `HINDI-REVIEW.md` is signed by a native speaker.
- [ ] README: how to run in three commands; "Honest limits" (no real SMS until DLT; WhatsApp link needs the person to tap Send; delivery is not tracked).

## Order of work
M1 contract + templates + `compose` + tests. M2 link builder + segments + phone rules. M3 provider slot + sandbox + `/outbox`. M4 iMac end-to-end + `RESULTS.md`.

## Later integration (lead, not you)
App shows "Tell my family" after the plan is approved and when Plan B needs a decision; the lead either ports the templates to Swift or calls your service. A server-sent SMS path is switched on only after DLT registration.
