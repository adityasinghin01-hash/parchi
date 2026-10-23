# SPEC 3: Shop reply page + "reply in one sentence". Owner: Antara Gupta. Folder: `teammates/shop-reply/`
Read `README.md` in this folder first (working agreement). You need no Mac and no server: a text editor, a browser and `python3 -m http.server`.

## Why (the user need)
The cheapest and fastest option for many patients in Muradnagar and Meerut is the local chemist. We send the shop a WhatsApp message with a reply link (Ask nearby shops). Today that link opens a plain form. Real shopkeepers use cheap Android phones, often with slow data, and they answer WhatsApp in a sentence ("paracetamol 28 rs mil jayega, 5 baje tak") rather than fill a form. If the page is slow, in English or hard to tap, shops do not reply and the patient loses the best price. Make replying take 20 seconds.

## What you build
1. **`reply.html` (+ `reply.css`, `reply.js`)**: the page a shop opens. Hindi first with the English line under it. One card per medicine: name, strength, quantity asked; two huge buttons "है / उपलब्ध नहीं" ; a price box with the numeric keypad ("एक पैक का दाम, Rs") ; at the bottom "कब तक तैयार?" with quick chips (30 मिनट, 1 घंटा, 2 घंटे, शाम) that fill an HH:MM time, and one sticky "भेजें / Send" button. Then a clear thank-you page and clear errors in Hindi (no network, already answered, link expired).
2. **`parse-reply.js`**: the "type your reply in one sentence" box. Input: free text (Hindi, Roman Hindi/Hinglish, English, typos) and the item list. Output (shown as EDITABLE fields for the shop to check; never auto-sent): `{items:[{itemID, available: true|false|null, pricePaise: integer|null, evidence: "28 rs"}], readyBy: "HH:MM"|null, flags: [], unparsed: []}`.
3. **A test corpus + a test page** (`tests.html`, runs in the browser, prints accuracy) with at least 150 synthetic replies and gold answers (60% Hinglish, 25% Hindi, 15% English; typos; multi-item sentences; negatives).
4. A tiny **mock server** (`mock_server.py`, standard library only) that serves your page and prints what a POST would deliver, so you can test the whole thing alone.

## The contract you must match (so the lead can plug it in later without changes)
The real endpoint is `POST /shop/reply/{token}` (see `server/CONTRACT_P3.md`, "Ask nearby shops"). It accepts EITHER form fields: for item number n (1, 2, 3...): `a{n}` = `"1"` available or `"0"` not available, `p{n}` = price per pack in RUPEES as a decimal (only when available), plus `readyBy` = `HH:MM`; OR JSON `{"items":[{"itemID","available":true|false,"pricePaise":int}],"readyBy":"HH:MM"}`. The server today renders the item list into its own page; yours reads it from a data island that the lead will fill from the server later:
`<script type="application/json" id="ask">{"shopName":"...","pickupBy":"2026-10-24T17:30:00+05:30","items":[{"itemID":"dolo","name":"Dolo","strength":"650","quantity":15}]}</script>` and `<form method="post" action="">`. Build with a sample island of your own (synthetic medicines). Also keep a **no-JavaScript fallback**: the same `<form>` with the same field names must work without any script (very old phones).

## Hard constraints
- Total size (HTML+CSS+JS, uncompressed) at most 30 KB. No external request of any kind: no CDN, no web fonts (system fonts only), no analytics, no images over 2 KB (inline SVG is fine). Must work offline once loaded.
- **ES5 JavaScript only** (no arrow functions, `let/const`, optional chaining, modules, `fetch`-only code paths: use `XMLHttpRequest` or the plain form post). Targets: Android 6+ Chrome, UC Browser, Samsung Internet. Check at 320, 360 and 412 px wide, and with the system font set to Large.
- Tap targets at least 56 px, contrast at least 4.5:1 (palette from `frontend/web/styles/tokens.css`: cream `#f6e5c7`, orange `#cc2e11`, dark brown text), visible focus, labels on every field, nothing that relies on colour alone. Hindi must render correctly with no font download.
- Privacy: collect nothing but the answers; do not ask for the shop's phone number; do not store anything.

## Parser rules (the part that needs care)
- Match each asked medicine in the sentence by name (fuzzy: up to 1-2 character errors, Devanagari and Roman spellings, strength tokens "650", "500mg"); several medicines in one sentence must not mix up each other's prices.
- Availability words (examples, extend them): available = "hai", "mil jayega", "stock me hai", "ha", "haan", "available", "है", "मिल जाएगा", "हाँ"; not available = "nahi", "nhi", "khatam", "out of stock", "नहीं", "नही है", "ख़त्म". Anything unclear = `null`, never a guess.
- Price: numbers next to "rs", "Rs.", "₹", "rupay", "rupaye", "रु", "रुपये", "ka", "me", or a bare number right after the name. Convert to paise exactly (28 -> 2800, 28.50 -> 2850). A price is NEVER 0 and never invented.
- **Per-tablet trap**: if the text says per tablet/goli/strip-of-N/"ek goli" etc., set flag `price_unit_unclear` and leave `pricePaise` null so the shop is asked "एक पूरे पैक का दाम?". Our prices are per pack.
- **Substitute trap**: "dusri company ka hai", "same salt ka hai", "alternate" means the shop offers a DIFFERENT brand. Parchi never swaps a brand, so set `available: null` and flag `substitute_offered`; show it to the shop as "हम दूसरी कंपनी की दवा नहीं ले सकते; क्या यही दवा उपलब्ध है?".
- Time: "5 baje", "शाम 5 बजे", "1 ghante me", "aadhe ghante me", "kal subah 10", "by 6pm", "abhi", "evening" -> `HH:MM` (today, IST). Ambiguous am/pm: choose the next occurrence that is after "now", set flag `time_assumed`, shop confirms.
- Everything the parser produced is shown in the editable fields with the shop's original words beside it. If confidence is low, say "कृपया जाँच लें" and highlight the fields.

## Tests and measured results (put in `RESULTS.md`, with the raw output file)
On your 150+ corpus report: item-match accuracy, availability accuracy, exact price accuracy, time accuracy, and the **dangerous error rate**: a wrong price or wrong availability that is NOT flagged for the shop to check. Target for dangerous errors on the corpus: 0 (if not 0, list every case). Also report page weight in bytes, and screenshots at 320/360/412 px (normal and Large font) of: the form, the one-sentence box with a parsed result, the thank-you page, an error page. State clearly that the corpus is synthetic and that real shop messages will differ.

## End-to-end check (alone, no server needed)
Run `python3 mock_server.py`, open it in a desktop browser and in Chrome DevTools phone mode with network throttled to "Slow 3G", fill the form once by tapping and once by typing a sentence, and confirm the mock server prints exactly the fields in the contract above (both the form and the JSON variants). Then, if Aditya Singh gives you access, open a real reply link from the demo server (`/shop/reply/<token>`) to see how the current page looks, but do not post to the live server.

## Acceptance
- [ ] Page works with and without JavaScript; posts exactly the contract fields; sample island + mock server included.
- [ ] 30 KB and no external request (show the network tab); ES5 only (show a check or a grep for forbidden syntax).
- [ ] Parser corpus (150+) with the metrics above; dangerous error rate reported honestly.
- [ ] Screenshots at three widths; accessibility notes (contrast, focus, labels).
- [ ] README: three-command run; "Honest limits" (synthetic corpus, no real shop tested, Hindi wording needs a native speaker's review, WhatsApp itself is not read, no real phone testing unless you did it).

## Order of work
M1 page + no-JS form + mock server. M2 quick-time chips, errors, thank-you, accessibility pass. M3 parser + corpus + test page. M4 flags (per-tablet, substitute, assumed time) wired into the page + measured `RESULTS.md` + screenshots.

## Later integration (lead, not you)
The server fills the data island and serves your files in place of its current page; the one-sentence box later gets reused inside the app's "paste the shop's WhatsApp reply" button.
