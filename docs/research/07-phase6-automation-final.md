# Phase 6: Automation — final list and count (23 Oct 2026, ~12:00 IST)
Labels: **[M]** measured by us · **[V]** checked in a source · **[J]** judgement · **[A]** assumption.

## 1. New facts that decide what can be automated
| Fact | Evidence | What it changes |
|---|---|---|
| PharmEasy's terms ban **"any automated means such as data scraper, deep-link, robot, spider… for any purpose"** | [V] pharmeasy.in/legal/terms-and-conditions, clause saved in phase6-automation/pharmeasy_terms_automation_clause_2026-10-23.txt | Our server must not fetch PharmEasy prices or fill its cart automatically |
| **5 of 5** pharmacy sites block bots from `/search`; 4 of 5 also block `/cart` or `/checkout` (1mg, PharmEasy, Truemeds, Apollo, Netmeds) | [M] their robots.txt, 23 Oct | Auto-ordering on a seller's site is out. Real mode = **hand-off** (user taps, the seller's own app/site does checkout) |
| 1mg product pages are **allowed** to bots (`Allow: /`), search is not | [M] robots.txt | A product-page link is fine; live price-scraping at scale is still a terms risk → **dated price snapshot** in the demo, partner/affiliate feed later |
| Affiliate links exist (1mg via EarnKaro: up to ₹150 per order, 30-day cookie — promo page, undated) | [V, weak] earnkaro.com blog | Legal hand-off link **and** the business model (same as GoodRx/Davaio) |
| No public lab-booking API (Thyrocare, Healthians, Redcliffe); Thyrocare is 66.1% owned by PharmEasy's parent and books through partners | [V] Wikipedia, Thyrocare earnings call | Real lab booking = hand-off to the lab page or WhatsApp/call; demo = labelled sandbox with a confirmation number |
| No public eVitalRx order API (pharmacy billing software used by 20,000+ chemists) | [V] app listings | Roadmap partner for local-chemist stock, not for the demo |
| ONDC: only PhonePe Pincode had pharmacies (2023); no 2026 pharmacy-ordering source | [V] The Ken | Roadmap only |
| **Free Apple account can't use:** App Attest, Push notifications, Sign in with Apple, Siri, Associated domains, Time-sensitive notifications, MapKit routing directions. **Can use:** App Groups (share extension), Background modes, Data protection, Keychain, Maps, HealthKit | [M] parsed Apple's capability table (developer.apple.com/help/account/reference/supported-capabilities-ios) | Paid program ≈ **₹8,700/yr** [V, forum posts] = 22× our ₹400 budget. Unless KIET's Apple CoE has a paid team, **drop App Attest, Sign in with Apple, push tracking, Siri intents** |
| Live Activities need only an Info.plist key; the app can update them locally (no push) | [V] Apple forums + vendor docs | Lock-screen tracking possible without a paid account; test on build day |
| AI phone-call agents (Bolna) ₹1.75–5.5 per minute, Hindi supported | [V] Inc42, bolna.ai | Paid API → roadmap (breaks "no paid API") |
| WhatsApp click-to-chat `wa.me/<no>?text=` works free; reading replies needs the Cloud API | [M] earlier, [V] | Shop Quote = we write and address the message, the user presses send; replies typed in by the user (demo: 1 reply) |
| UPI on iOS: generic `upi://pay` can't pick the app or return status | [V] earlier | Payment = seller's own checkout. Parchi holds no money |
| Blinkit fees | **Not published; Aditya to provide** from his app at checkout | Fee rule stays [A] in the planner until then |

## 2. Final automation list
"Steps saved" = what the patient does today by hand [J, counted from today's flow: read the parchi, search each item, compare, etc.].

| # | Automation | Trigger | What it does | Provider / tool | User approves? | Fallback | Steps saved | In demo |
|---|---|---|---|---|---|---|---|---|
| AU1 | Capture + crop | Scan or WhatsApp share | Finds the page, straightens it, checks blur/light | VisionKit, Vision (free) | No | Retake prompt | 1–2 | ✅ real |
| AU2 | Read into a list | Photo ready | Printed → read on phone; handwritten → our model | Apple Vision + our model on the iMac | No | Type with autocomplete | ~5 (one per item) | ✅ real |
| AU3 | Catalogue + brand–strength check | Each read line | Snaps to a real product; "Telma 400" → 20/40/80 | ParchiCore (built, tested) | No | Ask the user | 1 per error | ✅ real |
| AU4 | Flag only doubtful lines | Low confidence | Photo crop + top 3 real options | ParchiCore | **Yes** (1 tap) | Type | — | ✅ real |
| AU5 | Doctor memory + new brands | Confirmed scan | Learns the doctor's usual brands; adds missing brands | ParchiCore (built) | No | — | taps over time | ✅ real |
| AU6 | Compare every channel | List confirmed | Chemist, Jan Aushadhi, 10-min apps, online, labs | Planner (built) | No | — | ~5–10 searches | ✅ real (prices = dated snapshot, labelled) |
| AU7 | True final price | Plan built | Fees, minimum order, free-delivery thresholds, trips | Planner (built) | No | Unknown fee shown as "unknown", never ₹0 | checkout trial per seller | ✅ real |
| AU8 | Plan B re-route | Cancel / out of stock / late / sample rejected | Re-plans only failed items; auto-approve under a user cap | ParchiCore (built) | **Yes** (or cap) | Manual choice | whole re-search | ✅ real logic, failure triggered from the sandbox |
| AU9 | Order | "Get it all" | **Real:** opens each seller's own page/app with the item (hand-off). **Sandbox:** places a labelled test order | Links + sandbox server | **Yes** | Manual hand-off | search per item | ✅ hand-off real, auto = sandbox |
| AU10 | Lab booking | "Get it all" | **Real:** opens the lab page / WhatsApp. **Sandbox:** slot + confirmation number | Links + sandbox | **Yes** | Call the lab | 1 call | ✅ sandbox |
| AU11 | Parchi Pass | Confirmed list | QR + one-page typed list for any counter | CoreImage QR (free) | No | Show list on screen | chemist misreading | ✅ real |
| AU12 | Lab slot → Calendar | Booking confirmed | Adds the slot with fasting note | EventKit (free) | Permission once | — | 1 | ✅ real |
| AU13 | Dose reminders | List confirmed | From "1-0-1 × 5 days" | Local notifications (free) | Permission once | — | daily | ✅ real |
| AU14 | Refill countdown | List confirmed | Quantity ÷ daily doses → "refill in 3 days" | ParchiCore rule | No | — | — | ✅ real |
| AU15 | Name/phone blur | Before anything leaves the phone | Blurs patient identity, crops item lines | Vision text boxes + rules | No | Manual blur | privacy | ✅ real |
| AU16 | Share from WhatsApp | Share sheet | Parchi opens straight to Reading | Share extension + App Groups (free) | No | Save photo, then import | 3–4 | ✅ real |
| AU17 | "Ask your doctor" generic card | Plan built | Jan Aushadhi same-salt price; never swaps | PMBI list (2,439 products) | Doctor's OK | — | separate search | ✅ real |
| AU18 | Photo auto-delete | 24 h after scan | Deletes the raw photo unless saved | App sandbox | No | — | privacy | ✅ real |
| AU19 | Shop Quote | User taps "Ask 3 shops" | Writes and addresses the WhatsApp message with the list | wa.me (free) | Sends it himself | Call | 3 calls | ◐ stretch |
| AU20 | Lock-screen tracking | Order placed | Live Activity per order/lab slot | ActivityKit, local updates | No | Track screen | app-opening | ◐ stretch |
| AU21 | Live price refresh | Plan opened | Fresh prices | Partner/affiliate feed | No | Snapshot | — | ❌ roadmap (terms) |
| AU22 | AI call to book a lab or ask a chemist | No online booking | Hindi voice call | Bolna-type, ₹1.75–5.5/min | Yes | Manual call | 1 call | ❌ roadmap (paid) |
| AU23 | Read WhatsApp shop replies | Shop replies | Prices go into the plan | WhatsApp Cloud API | No | User types the price | — | ❌ roadmap |

## 3. Count
| Bucket | Count | Which |
|---|---|---|
| In the demo, real | **16** | AU1–AU7, AU11–AU18 (+ AU8's logic) |
| In the demo, labelled sandbox | **3** | AU8 trigger, AU9 auto-order, AU10 booking |
| Stretch (cut first) | **2** | AU19, AU20 |
| Roadmap | **3** | AU21, AU22, AU23 |
| **Total designed** | **23** | (AU8 counted once, in "sandbox") |

**User inputs for the whole job:** share/scan 1 · confirm 1 (+1–2 fixes) · "Get it all" 1 · approve Plan B 1 if needed. Payment happens in the seller's own checkout.

## 4. Changes to earlier phases
- **Security (file 03):** App Attest and Sign in with Apple are **not available** without the paid program. Replace with: per-install key in the Keychain + server token + rate limit (weaker than App Attest; say so). Guest scanning stays.
- **Technical (file 04, T10):** drop "Siri intents" and push-driven Live Activities unless the lab has a paid team. App Shortcuts (App Intents) seem not to need the Siri entitlement [V, forum only] — test on build day, cut if it fails.
- **Maps:** no in-app routing without the paid program → show straight-line distance, open Apple Maps for directions (free link).
- **Prices on stage:** every price says "captured 23 Oct, source MedScanner/lab page". No live scraping.

## 5. What I need from Aditya
1. **Blinkit at checkout** (pincode 201206 or your home): delivery fee, handling fee, small-cart fee, free-delivery threshold, and whether Dolo 650 / Pan 40 / Telma 40 are listed.
2. **Does KIET's Apple CoE have a paid Apple Developer team** you can be added to? If yes: App Attest, push, Sign in with Apple come back.

Sources: PharmEasy T&C https://pharmeasy.in/legal/terms-and-conditions · robots.txt of 1mg.com, pharmeasy.in, truemeds.in, apollopharmacy.in, netmeds.com (fetched 23 Oct) · Apple capabilities https://developer.apple.com/help/account/reference/supported-capabilities-ios · Apple fee (forum) https://developer.apple.com/forums/thread/746357 · EarnKaro https://earnkaro.com/blog/pharmacy-affiliate-programs/ · Thyrocare https://en.wikipedia.org/wiki/Thyrocare · ONDC pharmacies https://the-ken.com/techxpolicy/ondc-is-playing-it-safe-with-pharmacies/ · Bolna https://www.bolna.ai/pricing · https://inc42.com/features/the-unit-economics-of-indias-voice-ai-boom/ · Live Activities https://developer.apple.com/forums/thread/715138 · eVitalRx https://apps.apple.com/app/id1637429769
