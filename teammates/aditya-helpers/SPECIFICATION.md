# SPEC 4: three independent modules, one 2-hour sprint. Owner: Aditya (frontend). Folder: `teammates/aditya-helpers/`
This ONE document is all you need. Everything the modules read is either in this repo or in `docs/team/specs/seed-data/`. You never need to ask the lead or touch `app/`, `server/` or `engine/`. Read `README.md` in this folder for the shared rules (branches, no secrets, honesty rules).
Lead's goal: if a module is finished and passes its tests, the lead links it into the app later. If it is not finished, nothing is linked and nothing breaks.

## 0. Paste this into Codex to start (it reads this file and builds in order)
> You are building three independent Python modules for Parchi in `teammates/aditya-helpers/`. First read `docs/team/specs/README.md`, then ALL of `docs/team/specs/SPEC-4-ADITYA-THREE-MODULES.md`, then the data in `docs/team/specs/seed-data/`. Work in this order, with these time boxes: setup 10 min, Module A 50 min, Module B 30 min, Module C 30 min (total 2 hours). For each module: write the code, write the pytest tests listed in the spec, run them, fix failures, write the module README and `RESULTS.md` with the REAL measured output. Never edit `app/`, `server/`, `engine/`. No network calls at run time. No API keys. No claim without a test or a source URL. Commit locally on branch `team/aditya/helpers` after every module. At the 2-hour mark stop, mark any unfinished module `NOT READY` in its README, and write the top-level `teammates/aditya-helpers/STATUS.md` listing each module as READY / NOT READY with the test counts.

## 1. The three modules (why each exists)
| | Module | The user need | Evidence it is a gap |
|---|---|---|---|
| A | **Order problem helper** (support + refund) | When an order goes wrong, the person has to chase support and refunds alone. Plan B re-routes the order but nothing helps get the money or an answer. | In our 9,000-review data (`docs/research/evidence/review_themes.json`, 9 apps) the averages are: delays 19.5%, customer support problems 14.8%, refund problems 6.6%, lab sample/report issues 6.6%, out of stock 3.9% (keyword counts, not audited). The app and server have no support/refund feature. |
| B | **Hindi pack** for the whole app | Our users are in Muradnagar and Meerut. The app is English only. | `app/` has no localization files at all (no `.lproj`, no `.xcstrings`); the consent screen's Hindi is hard-coded. The new frontend's language picker only saves a preference. |
| C | **Delivery check** ("does what arrived match my parchi?") | A wrong strength, wrong brand or near-expiry strip is a safety problem and the person cannot easily check. | Wrong/substituted item is a measured complaint (1.8% average, up to 3.1% for one app). We already hold the confirmed list that the delivery should match. |

## 2. Time plan (2 hours, strict)
| Minutes | What | Done means |
|---|---|---|
| 0-10 | folders, venv, pytest, read the seed data | `pytest` runs (even with 0 tests) |
| 10-60 | Module A | acceptance list A passes |
| 60-90 | Module B | acceptance list B passes |
| 90-120 | Module C (core compare + synthetic corpus; `parse_pack_text` is a stretch) | acceptance list C passes |
At 120 minutes stop. Unfinished = `NOT READY`, not linked. Do not extend a module by squeezing the next one.

## 3. Folder layout (create exactly this)
```
teammates/aditya-helpers/
  STATUS.md                      # READY / NOT READY per module, test counts, date
  problem-helper/   README.md RESULTS.md src/problem_helper/*.py tests/ data/ demo/index.html
  hindi-pack/       README.md RESULTS.md src/hindi_pack/*.py tests/ glossary.csv out/
  delivery-check/   README.md RESULTS.md src/delivery_check/*.py tests/ corpus/
```
Python 3.11, standard library + `pytest` only (add `hypothesis` if you want; nothing else). One `requirements.txt` at the top.

## 4. Module A: Order problem helper (`problem-helper/`)
### What it does
Given what went wrong with an order, it writes a clear polite message the PERSON sends from their own WhatsApp/email, lists evidence to attach, and shows the next steps in order with real contacts and follow-up dates. Parchi never sends it, never touches money, never gives legal advice, and never invents a contact or a deadline.

### Input (JSON in, JSON out)
```json
{"lang": "en|hi",
 "issue": "not_delivered|late|cancelled_by_seller|wrong_item|missing_item|expired_or_damaged|refund_pending|overcharged|no_support_reply|lab_sample_issue|lab_report_late",
 "seller": {"name": "Tata 1mg", "kind": "online_pharmacy|quick_commerce|lab|local_shop"},
 "order": {"orderId": "optional string", "placedOn": "2026-10-20", "amountPaise": 269677, "paidVia": "upi|card|cash|unknown",
           "items": [{"name": "Dolo", "strength": "650", "qty": 15}], "isTestOrder": false},
 "events": {"promisedBy": null, "cancelledOn": null, "refundRequestedOn": "2026-10-22", "supportContactedOn": null},
 "today": "2026-10-30"}
```
Output: `{"message": {"subject", "body", "lang"}, "evidence": ["..."], "ladder": [{"level": 1, "who": "...", "how": "...", "contact": {"value", "sourceUrl", "dateSeen"} | null, "when": "now|2026-11-01", "why": "..."}], "followUps": [{"dueOn", "text"}], "notes": ["..."], "disclaimer": "..."}`.

### Data you use (already in the repo)
- `docs/team/specs/seed-data/company_contacts.csv`: 24 companies, 15 with a grievance email, each with its source URL and the date seen. Cells look like `email <url> | email <url>`; write a parser, keep the URL as `sourceUrl`.
- `docs/team/specs/seed-data/official_routes.json`: the National Consumer Helpline (1915, WhatsApp 8800001915, consumerhelpline.gov.in) and the E-Commerce Rules 2020 claims (grievance officer acknowledges within 48 hours, redresses within 1 month; no refusing refunds for defective or late goods except force majeure). IMPORTANT: these are from SECONDARY sources. Show them in output with the text "check on the official site" and keep `status` visible in `notes`.

### Rules the ladder must follow
1. Level 1: the seller's own support (app chat or support email from the CSV). `when: now`.
2. Level 2 (only for `online_pharmacy`, `quick_commerce`, `lab` platforms): the grievance officer's email from the CSV. `when`: the later of "support contacted + 2 days" and today (the 2 days is an ASSUMPTION; label it). Mention that the rules say the officer acknowledges within 48 hours and resolves within 1 month, and compute `followUps`: acknowledgement check at +2 days, resolution check at +30 days from the date the complaint is sent.
3. Level 3: the National Consumer Helpline (1915 / WhatsApp / portal). Offer it when level 2 got no answer by the follow-up date, or immediately for `local_shop` (the E-Commerce Rules do not clearly apply to a local shop: do not show the 48 hour / 1 month deadlines for local shops).
4. Nothing above level 3. Never mention suing, courts, police, compensation amounts or "legal action". One neutral sentence: "If this is not resolved you can ask the helpline what the next options are."
5. If the CSV has no email for a company: say "we could not find a contact for this company", offer the helpline, never guess an address. Never state how many days a refund takes (no verified number exists; see `not_stated_anywhere_yet`).
6. Messages: factual and polite; only facts present in the input; the ask is concrete ("please refund Rs X to my original payment method", "please send the missing item", "please replace the strip"); include order id, date, amount, items; Hindi version written naturally with the "aap" form. `isTestOrder: true` puts "Test order" in the subject and no ladder at all (sandbox orders have no real seller).
7. Never medical advice; if the issue is `wrong_item` or `expired_or_damaged` add the safety note "Do not use this medicine until the seller confirms" ONLY as a plain precaution line, not as treatment advice, and mark it `reviewed: false` until a person approves the wording.

### Tests (pytest) you must write
Every issue x language x seller kind renders; no `{placeholder}` left; banned words never appear (sue, court, lawyer, police, threat, compensation, guarantee); contact parser on all 24 CSV rows; missing contact falls back and says so; ladder differs for `local_shop`; follow-up dates are exact (+2, +30 days, month and year boundaries); `isTestOrder`; golden files committed for 6 representative cases; the Hindi templates exist for every issue.
### Demo
`demo/index.html` (single static page, no network): choose an issue and a company, press Generate, see the message, the ladder and the follow-up dates (embed the CSV subset and templates as JSON in the page, or call a tiny `http.server`). It is for the judges to SEE the feature.
### Acceptance A
- [ ] All tests green; `RESULTS.md` has the test count and the 6 golden outputs.
- [ ] No contact or date appears that is not in the seed data or computed from the input.
- [ ] Official-route text carries "check on the official site"; local shops get no e-commerce deadlines.
- [ ] README: input/output contract, how to run in 3 commands, "Honest limits" (secondary-source rules, message not sent by Parchi, Hindi unreviewed).

## 5. Module B: Hindi pack (`hindi-pack/`)
### What it does
A Python tool that (1) finds every user-facing English string in the SwiftUI app, (2) makes a translation sheet, (3) after Hindi is filled in and reviewed, produces a String Catalog file the app can use as is. SwiftUI shows Hindi automatically for string LITERALS (`Text("Hello")`, `Button("Save")`, `Label("..", systemImage:)`, `.navigationTitle("..")`) when the phone is set to Hindi and a catalog entry exists.
### Extractor (`extract.py`)
Scan `app/Parchi/**/*.swift` (point it at any checkout; the lead will re-run it on the final frontend). Collect string literals passed to: `Text(`, `Label(`, `Button(`, `NavigationLink(`, `Section(`, `Toggle(`, `Picker(`, `Stepper(`, `TextField(`, `Menu(`, `ProgressView(`, `ContentUnavailableView(`, `.navigationTitle(`, `.accessibilityLabel(`, `.accessibilityHint(`, `.alert(`, `.confirmationDialog(`, `.help(`. Skip: `.accessibilityIdentifier(`, SF Symbol names (`systemImage:`/`Image(systemName:)`), `UserDefaults` keys, URLs, JSON keys, `Text(verbatim:)`, test files, `Design/ThemePreview.swift`, anything inside `#if DEBUG`, and strings that are clearly data (brand/seller names).
Handle interpolation: `"\(count) medicines"` becomes the key `"%lld medicines"` (for an Int-looking value) or `"%@ ..."` (otherwise); if you cannot tell, mark `needs_manual`. Multi-line and raw strings must work.
**Strings that are NOT localizable automatically** (assigned to a `String` variable, returned from a computed property, built by concatenation) go into `out/not-auto-localizable.md` with `file:line` and a one-line fix suggestion (`String(localized:)`/`LocalizedStringKey`). Do not edit the Swift files yourself.
### Outputs
- `out/translation-sheet.csv`: `key, english, hindi, status(draft|reviewed), screen_hint(file:line), max_ratio_note`.
- `out/Localizable.xcstrings`: Apple String Catalog JSON (`{"sourceLanguage":"en","strings":{"<key>":{"localizations":{"hi":{"stringUnit":{"state":"translated","value":"..."}}}}},"version":"1.0"}`). Only `reviewed` rows are written as `translated` by default; `--include-drafts` writes drafts as `needs_review` (for the demo only; the README must say so).
- `out/report.md`: counts (found / skipped / needs_manual / not auto-localizable), longest Hindi-to-English length ratios (layout risk), glossary violations.
### Translation (you or Codex drafts; a native speaker reviews)
Create `glossary.csv` (English term, Hindi term) first and use it everywhere: order, plan, price, seller, shop, lab, test, report, medicine, refill, doctor, parchi (keep "पर्ची"), Test order ("टेस्ट ऑर्डर"), Plan B (keep "Plan B"), Jan Aushadhi (keep), Delete everything, etc. Style: polite "आप", short sentences, common English loanwords are fine (ऑर्डर, प्लान, लैब, रिपोर्ट, फ़ोन), keep ₹ and Western digits, KEEP medicine and brand names as written. Never turn "ask your doctor" into advice; never change the meaning of the H1/X line ("buy in person with the original parchi"). Mark everything `draft`; only a native speaker flips rows to `reviewed` (record the reviewer's first name and date in `out/REVIEW-LOG.md`).
### Tests
Key extraction on a fixtures folder of small Swift snippets (every pattern above, interpolation, skipped cases); placeholder parity between English and Hindi for every row (same `%@`/`%lld` set and order markers); no empty Hindi in a `reviewed` row; glossary terms used consistently; the generated `.xcstrings` is valid JSON with the right shape; extraction on the real `app/Parchi` runs without crashing and its counts are printed into `RESULTS.md`.
### How the lead tests it later (write this into the README)
Copy `Localizable.xcstrings` into `app/Parchi/`, rebuild, launch the simulator with `-AppleLanguages "(hi)" -AppleLocale hi_IN`, and screenshot every screen to look for cut-off text.
### Acceptance B
- [ ] Extractor works on the real app; counts in `RESULTS.md`; `not-auto-localizable.md` produced.
- [ ] `translation-sheet.csv` complete with drafts for 100% of extracted keys; glossary used.
- [ ] `.xcstrings` valid; placeholder-parity tests green.
- [ ] README states clearly: drafts are NOT reviewed; nothing ships to patients until a native speaker signs off.

## 6. Module C: Delivery check (`delivery-check/`)
### What it does
Takes the confirmed parchi list and what the person says arrived (fields typed in, or text read from the strip/bill by ANY reader) and says, line by line, whether it matches. It never decides what is safe to take, never accepts a different brand silently (Parchi never swaps brands), and gives no medical advice. Reading a photo is NOT part of this module (the lead wires a reader later); you build the checking brain and test it with synthetic text.
### Data you use (already in the repo)
`engine/catalogue/brand_strengths.json` (brand -> list of real strengths), `engine/catalogue/brand_schedule.json` (brands that are Schedule H1/X, with salt), `engine/catalogue/DATA_VERSION.json`. Brand keys are UPPERCASE first words (e.g. `AUGMENTIN`, `DOLO`). Do not read `brand_mrp.json` (format not needed).
### Input / output
```json
{"confirmed": [{"itemId": "dolo", "name": "Dolo", "strength": "650", "qty": 15}],
 "received": [{"rawText": "DOLO 650 Tablet strip of 15 EXP 08/2027 B.No ABC123", "brand": null, "strength": null, "units": null, "expiry": null}],
 "options": {"today": "2026-10-24", "minMonthsToExpiry": 3, "approvedSubstituteBrands": []}}
```
Output per confirmed line: `{"itemId", "verdict": "ok|likely_ok|strength_differs|brand_differs|quantity_short|expired|expiry_soon|unreadable|missing", "message": "plain text (en)", "messageHi": "...", "severity": "info|check|stop"}`; plus `extra` for received items that match nothing on the list, and `summary` (counts + one sentence + next step). `minMonthsToExpiry` default 3 is an ASSUMPTION (label it); the person can change it.
### Rules
1. `parse_pack_text(rawText) -> {brand, strength, units, expiry, batch}`: brand = best catalogue match of the leading tokens; strength = number with optional `mg/mcg/g/ml/iu`; units = `strip of N`, `N tablets/caps`, `N ml`; expiry = `EXP|Expiry|Exp.` followed by `MM/YYYY`, `MM/YY`, `MMM YYYY`, `MMM-YY` (read as the LAST day of that month); batch optional. Unknown stays `null`, never guessed. (Stretch if time is short: you may test the comparison with already-structured fields only.)
2. OCR-tolerant brand match: normalise case and common confusions (0/O, 1/l/I, rn/m, 5/S); edit distance 0 = exact; 1-2 = `likely_ok` with message "looks like <brand>, please check the pack"; more = `brand_differs`. A DIFFERENT real brand is always `brand_differs` ("this is not the brand on your parchi; ask the seller why") unless it is in `approvedSubstituteBrands` (then `likely_ok` with "substitute you approved").
3. Strength must equal one of the confirmed strengths exactly (numeric compare, `0.5` = `.5`); a strength that is not even a real strength for that brand in `brand_strengths.json` is flagged `unreadable` ("check the strength on the pack").
4. Quantity: compare units on the pack(s) with `qty`; fewer = `quantity_short` ("fewer than ordered"); more is fine.
5. Expiry before `today` = `expired` (severity `stop`: "do not use; ask the seller to replace"); within `minMonthsToExpiry` = `expiry_soon` (severity `check`). Missing expiry = `unreadable` for expiry only.
6. Any confirmed item with no received match = `missing`. Any received item not matching the list = `extra`.
7. For brands in `brand_schedule.json` marked H1/X add the plain line "Keep your original parchi and the bill for this medicine." No other medical content anywhere.
8. Never output the words: safe, unsafe, dangerous, dose, take this, side effect, cure. (The severity `stop` text says "do not use; ask the seller", not why it is harmful.)
9. Optional adapter `to_problem_helper_input(verdict_line, order_info)` that maps `strength_differs/brand_differs/expired/missing/quantity_short` to Module A's `issue` (`wrong_item`, `expired_or_damaged`, `missing_item`) so the lead can offer "Write to the seller" next to a bad verdict.
### Synthetic corpus and measured results (`corpus/`, `RESULTS.md`)
Write `make_corpus.py` that builds at least 300 cases from the catalogue: correct pack; strength changed; a different real brand; expiry past / soon / fine; fewer units; extra item; missing item; OCR-noisy brand (single and double character errors); missing expiry; non-Latin garbage. Each case carries its gold verdict. Report: accuracy per verdict type, and the **dangerous error rate** = cases where a gold `strength_differs`, `brand_differs`, `expired` or `missing` was reported as `ok`/`likely_ok` (target 0 on the corpus; if not 0, list every case). Say that the corpus is synthetic.
### Tests
Each rule above; boundary dates (expiry this month, last day of month, leap year); parser on 30 hand-written strip texts; the dangerous-error test on the whole corpus; the banned-word test.
### Acceptance C
- [ ] Comparison engine + corpus + tests green; dangerous error rate reported honestly; README with contract and 3-command run; "Honest limits" (synthetic text only, no real photo tested, 3-month threshold is an assumption, brand list is a 2022-era catalogue so new brands are `unreadable`).

## 7. Documentation you must leave (the lead reads only these)
Per module: `README.md` (what/why in 5 lines, the contract with one full example, 3-command run, folder map, "Honest limits"), `RESULTS.md` (the real command output: test counts, corpus numbers, golden examples; no number without the command that produced it). Top level: `STATUS.md` (READY / NOT READY per module, date, test counts). If you changed your mind about a contract, write it in `NEEDS-LEAD.md` and keep your own assumption; do not wait.

## 8. How the lead links each module later (so you design for it)
- A: a "Something went wrong" button on an order (Track, Plan B, History) calls `generate(input) -> output`. The lead either ports the templates to Swift or runs your code as a tiny local service. Needs: templates as data files (JSON), not hard-coded in functions.
- B: copy `out/Localizable.xcstrings` into the app target; add `hi` to the project's known regions. Needs: valid catalog and a clean `not-auto-localizable.md`.
- C: after the lead connects a photo reader, the reader's text goes into `received[].rawText`. Needs: a pure function with the JSON contract above.

## 9. Global definition of done
- [ ] Branch `team/aditya/helpers`, only under `teammates/aditya-helpers/`, pull request to `main`, nothing else changed.
- [ ] `pytest` green from the top-level folder; `STATUS.md` honest.
- [ ] No secrets, no real patient data, no network at run time, no invented contacts/numbers/legal claims; every assumption labelled `ASSUMPTION`.
