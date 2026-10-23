# Parchi frontend: screens and competitor research (owners: Antara Gupta + Aditya)
Read `CONTEXT.md` (repo root) first. This doc is everything you need to design and build without waiting for anyone.
Locked 23 Oct 2026. SwiftUI, iOS 17+, **free Apple account** (so no Sign in with Apple, push notifications, App Attest or Siri; local notifications, Calendar, App Groups and Maps are fine).

## 0. Split
| Antara Gupta: screens | Aditya: capture, privacy, care |
|---|---|
| S1 Home · S3 Confirm · S4 Plan · S5 Get it all · S6 Track + Plan B sheet · S9 How we rank · S10 Settings & privacy | S0 First-run consent · Capture (scanner, WhatsApp share extension, Photos import) · S2 Reading + blur · S7 Care (Calendar, reminders, refill) · S8 Parchi Pass · Hindi strings + read-aloud |

## 1. Rules for every screen (from our research)
- **One question per screen**; the patient makes **3 decisions** in total (share, confirm, Get it all). About 5–7 taps for medicines + tests vs 12+ on QuickPill for medicines only [M].
- **Touch targets ≥ 44×44 pt**, text contrast ≥ 4.5:1, never colour alone (always text + icon), Dynamic Type up to the largest sizes, VoiceOver labels on everything ("Telma 40, confirmed, morning and night").
- **Every number explains itself:** price shows source + time ("1mg · captured 23 Oct"); every status has a one-line "what this means".
- **Every error has a next step** (table in §4).
- **No login to scan.** No ads, no trackers.
- **Never** say "take this", "switch to this" or "you need this test". Parchi shows what the doctor wrote and where to get it. Generic savings always say "ask your doctor".
- Languages: English + Hindi (device language). Hindi read-aloud for the schedule.

**Data you bind to (from ParchiCore, already built and tested):** `RxItem` (id, kind medicine/test, name, strength, quantity), `Seller` (name, channel, fees, ETA, requiresVisit, distance), `Offer` (price, inStock, exactMatch), `Plan` (lines, feesBySeller, itemsTotal, feesTotal, payable, stops, medicinesReadyMinutes, reportsReadyMinutes), `PlanBProposal` (failure, kept, rerouted, extraCost, newPlan, stillMissing), `Catalogue.check(brand:strength:)` → ok / wrong strength with real strengths / unknown + `suggestions`. Money is integer paise. Mock data: `engine/scenarios/real_basket_*.json` (6 real medicines + 4 tests, real prices captured 23 Oct).

## 2. Screens
### S0 First-run consent (Aditya)
- **Question:** "Is my data safe?"
- **Layout:** 3 short cards: "Your name is blurred on your phone before anything is sent" · "Only the medicine part goes to our own computer, never to an AI company" · "Photos are deleted after 24 hours. Delete everything anytime." → **Agree & continue** (Hindi toggle at the top).
- **Data:** none. **Taps:** 1. **Done when:** the agreement time is stored; Settings shows it.

### S1 Home (Antara)
- **Question:** "Where do I start?"
- **Layout:** big **Scan or share parchi** button (camera + WhatsApp icon) · "Recent parchis" list (date, doctor, "5 medicines · 2 tests", status chip) · small "How Parchi works" link.
- **Empty state:** illustration + "Share a parchi from WhatsApp or scan one".
- **Taps:** 1. **Done when:** a new user reaches the scanner in one tap.

### Capture (Aditya)
- **Scanner:** `VNDocumentCameraViewController` (auto edges + crop).
- **WhatsApp share:** Share Extension target accepting images/PDF; hands the file to the app through an **App Group** container; opens S2 directly.
- **Photos import:** PhotosPicker.
- **Quality check:** if the image is blurry or dark → "Move closer, more light" + Retake.

### S2 Reading (Aditya)
- **Question:** "Is it working? Is my data safe?"
- **Layout:** the photo; detected text lines light up one by one; **the patient's name visibly blurs** (the trust moment); progress text "Reading 5 lines…".
- **Logic:** Apple Vision (English + Hindi passes) → blur rules (measured 98.3% names hidden) → printed and confident → done on the phone; else send the **blurred, cropped** medicine area to the iMac `/read`.
- **States:** offline + printed → reads on the phone; offline + handwritten → "Needs internet to read handwriting. Saved; we'll read it when you're online."
- **Taps:** 0. **Done when:** a name is blurred on screen before upload, every time.

### S3 Confirm (Antara)
- **Question:** "Did it read right?"
- **Layout:** one card per item. Medicine card = form icon + **name + strength** + schedule as sun/moon icons (1-0-1) + duration. Test card = test name + "fasting?" chip. **Doubtful lines are highlighted**: the photo crop of that line + up to 3 real options + "Type it" (autocomplete from the catalogue). Brand–strength mismatch: "Telma comes in 20 / 40 / 80. Which one?" H1/X items show the badge "Buy in person with your original parchi".
- **Bottom:** "All correct" (primary).
- **Taps:** 1 + one per doubtful line.
- **Done when:** a wrong strength can't be confirmed without choosing a real one.

### S4 Plan, "Cost to Complete" (Antara)
- **Question:** "What's the best way to get all of it?"
- **Top card:** **"Everything ₹2,697 · ready by 6 pm · 0 trips"** + "You save ₹X vs MRP at the doctor's shop". The ₹ figure is `payable` and must include fees.
- **Toggles:** Cheapest / Fastest / No trips (re-plan instantly).
- **Breakdown:** grouped by seller (logo, items, fees line, ETA; distance for shops/labs; "home collection" for labs).
- **"Ask your doctor" card:** "Same salts at Jan Aushadhi: ₹189 instead of ₹1,030. Only your doctor can approve a switch." Never applied automatically.
- **Links:** "Why this plan?" (one line, e.g. "Saves ₹84 and a trip vs the nearest chemist") · "How we rank".
- **Unknown fees:** shown as "fee unknown", never ₹0.
- **Taps:** 0–1. **Done when:** the total equals items + fees, and each price shows its source and time.

### S5 Get it all (Antara)
- **Question:** "What am I agreeing to?"
- **Layout:** final list per seller/lab with price + "You'll finish payment in the seller's own app" + lab slot picker. Button **Get it all**.
- **Actions:** real mode = opens each seller/lab link in turn (hand-off); demo mode = **labelled "Test order"** to our sandbox, returns confirmation numbers.
- **Taps:** 1 (+ the seller's own payment). **Done when:** sandbox orders always show the "Test order" label.

### S6 Track + Plan B sheet (Antara)
- **Question:** "Where is it? What if it fails?"
- **Layout:** timeline per seller (Placed → Packed → Out → Delivered; lab: Booked → Sample collected → Report). Confirmation numbers.
- **Plan B sheet** (when the sandbox seller is cancelled): "Truemeds cancelled 5 items. Plan B: Medkart + nearby chemist, **+₹166**, by 7 pm. **Approve**" + "Choose myself". Optional auto-approve cap in Settings ("auto-approve up to +₹20").
- **Taps:** 1 to approve. **Done when:** the judge's cancel tap shows Plan B in under 2 s.

### S7 Care (Aditya)
- **Question:** "What next?"
- **Layout:** today's doses (from 1-0-1 × days) with checkmarks · "Refill in 3 days" (quantity ÷ daily doses) · lab slot added to Calendar (EventKit) with fasting note · report expected time.
- **Permissions:** Calendar and notifications, asked only here, with a one-line reason.

### S8 Parchi Pass (Aditya)
- **Question:** "How do I show the chemist what I need?"
- **Layout:** QR + big typed list (brand, strength, quantity) + "Confirmed by patient on 23 Oct". Brightness up automatically.
- **Done when:** a chemist can read the list from 1 m away.

### S9 How we rank (Antara)
Static: "We rank by 1) total price including fees, 2) when you get it, 3) number of trips. No seller pays to appear higher. Where we earn a referral fee we say so, and it never changes the order." Required in spirit by the E-Commerce Rules (ranking disclosure; 2026 amendment).

### S10 Settings & privacy (Antara)
Language · Delete everything · Consent record · Auto-approve cap for Plan B · "How accurate is Parchi?" (filled with Aditya Singhal's measured numbers) · Demo reset (hidden, for the team).

## 3. Navigation
```
S0 (first run) → S1 Home → Capture → S2 Reading → S3 Confirm → S4 Plan → S5 Get it all → S6 Track (+ Plan B sheet) → S7 Care
                                                                       └→ S8 Parchi Pass (from S3 / S4 / Home)
S9 How we rank (from S4) · S10 Settings (from Home)
```

## 4. Error states (each with a next step)
| Situation | Shown |
|---|---|
| Blurry or dark photo | "Move closer, more light" + Retake |
| Line can't be read | Crop + 3 options + Type it |
| Impossible strength | Real strengths to pick from |
| Not sold anywhere | "Not available in our list. Ask your doctor or chemist." |
| Seller cancels / late / out of stock | Plan B sheet |
| No internet | Printed: read on phone. Handwritten: saved, read later. Plans saved offline |
| Server down | "Our reader is busy. Showing what your phone could read; please check each line." |

## 5. Competitor research (45 minutes, before building screens)
Install or open each, **take screenshots**, and fill the table. Use one public sample parchi (from our demo set), never a family member's real one.

| App | Look at | Capture |
|---|---|---|
| **QuickPill** (quickpill.in) | Scan flow, how each medicine + price is shown, % confidence, "Add best deal" | Taps from photo to cart; login point; what happens on a bad photo |
| **MediSaathi** (mymedisaathi.com) | Handwriting beta, 7-pharmacy comparison | Same |
| **Tata 1mg** | Upload prescription, cart, delivery fee display, lab booking | Where fees appear (cart vs checkout); tracking screen |
| **PharmEasy** | Upload → "we'll call you", order tracking, cancellations | Steps; how cancellations are shown |
| **Apollo 24/7** | Pharmacy + labs in one app | How medicines and tests are separated |
| **Truemeds** | Substitute suggestions UI | How they word substitutes (we must say "ask your doctor" instead) |
| **Blinkit / Zepto** pharmacy | 10-min flow, prescription upload, fees | Handling / small-cart / delivery fee wording |
| **LabFare** (labfare.in) | Lab test comparison | How labs are compared (price, distance, report time) |
| **Jan Aushadhi Sugam** (3.2★) | Generic search + store locator | Why it's rated low (read 10 reviews) |
| **Davaio** | Whole-cart total incl. delivery | How the total is shown |
| GoodRx (US, screenshots online) | Local pharmacy price list | Price card design |

**Output table (one row per app):** taps to finish · where the real total appears · how errors are handled · one thing to **adopt** · one thing we **change** (our modification). Put screenshots in a shared folder `competitor-screens/<app>/`.

## 6. Acceptance checklist (before the feature freeze)
- [ ] WhatsApp share → S2 in one step
- [ ] Name blurred on screen before upload
- [ ] Doubtful line shows crop + 3 real options; impossible strength can't be confirmed
- [ ] S4 total = items + fees; every price shows source + time; unknown fee ≠ ₹0
- [ ] "Test order" label on every sandbox order
- [ ] Judge's cancel → Plan B sheet in under 2 s
- [ ] All screens work at the largest Dynamic Type size and with VoiceOver
- [ ] Hindi strings on S1–S6
- [ ] Demo reset restores the starting state

## 7. Competitor evidence we already have (use it in your designs)
| Competitor | What we measured / saw (23 Oct) | Design lesson |
|---|---|---|
| QuickPill | Logged-in scan works; shows each medicine with a % confidence and 4 pharmacy prices; "Add Best Deal to Cart" **once per medicine** (≈12+ taps for 5 medicines); "quota exceeded" 3 times; no tests | One "Get it all" for the whole parchi; never a per-line add button |
| MedScanner | Showed an **injection** as Pan 40 tablet "best price"; compared a 10-tablet pack against 30-tablet packs | Always show form + pack; "exact match" badge |
| 1mg / PharmEasy | Pharmacist reads it by hand and phones you; fees only at checkout | Show the full price on the Plan screen |
| Pharmacy apps (Play reviews) | Delay/cancel = 16–29% of 1–2★ reviews; support 15–22%; refunds 7–13% | Track screen + Plan B sheet are the hero |
| Jan Aushadhi Sugam | 3.2★ | Make generic savings automatic but always "ask your doctor" |
| Davaio | Cart total includes delivery | Adopt: one total. Modify: medicines + tests + trips |
Raw data: `docs/research/02-phase2-competitors-identity.md`, `docs/research/evidence/review_themes.json`, `docs/research/evidence/quickpill_2026-10-23.json`.

**Screenshot task:** put your phone screenshots of each app in `docs/competitors/<app>/` (e.g. `docs/competitors/quickpill/01-scan.png`) and commit them. Use our demo parchi, never a real family prescription.
