# On-paper upgrade: UX, Demo, Security (plus the one-stop workflow that lifts Innovation and Novelty)
23 Oct 2026. "On paper" means fully specified, with every claim sourced or measured, but not built yet. Each section ends with the test that turns the on-paper score into a verified one.

---
## 0. First, the one-stop workflow (it raises all five scores at once)

**Principle: zero typing, one decision.** The patient makes exactly **one** real decision ("Get it all") and confirms anything doubtful with a tap.

```
WhatsApp photo ─┐
Camera scanner ─┼─► READ (on phone first) ─► CONFIRM ─► PLAN ─► GET IT ALL ─► TRACK + PLAN B ─► CARE
Photos / PDF ───┤    page detect → blur name    doubtful   Cost to   orders + lab   cancel/late →    dose reminders,
"Hey Siri" ─────┘    → read → cross-check        lines only Complete  slot + UPI     1-tap reroute    refill, reports
```

### New ideas created by improving existing ones (Aditya's rule: adopt, then modify)
| Our concept | Adopted from (exists today, checked) | What we change | Score it lifts |
|---|---|---|---|
| **Cost to Complete** | "Total landed cost" in supply chains (item + freight + fees); Davaio shows a cart total including delivery [V] | The cost to *finish the whole parchi*: medicines + tests + fees + **trips + time**, in one number | Innovation, UX |
| **Plan B** | Payment smart routing: Juspay automatically routes to a healthy backup gateway [V] | Failover for medicines and lab slots: cancel / out of stock / late leads to a 1-tap re-route | Innovation, Demo |
| **Doctor Memory** | WHO "P-drugs", each doctor's personal list (WHO Guide to Good Prescribing, 1994) [V] | Learn the list from confirmed scans; break reading ties | Novelty, Technical |
| **Brand–Strength Check** | Bank cheques: amount in words must agree with amount in figures [V] | A read medicine is accepted only if brand + strength is a real product | Novelty, Security (safety) |
| **Parchi Pass** | ABDM "Scan & Share": a hospital QR gives OPD tokens without forms; 6.64 crore tokens by Nov 2024 [V] | A QR or one-page card of the *patient-confirmed* list for **any** local chemist or lab counter. No integration needed, and no misreading at the counter | Feasibility, UX, Novelty |
| **Shop Quote** | AskIt collects quotes from local pharmacies [V, phase 2] | Parchi sends the confirmed list (Parchi Pass) to 3 nearby shops on WhatsApp; their replies go into the Cost to Complete comparison | Feasibility (fixes "local prices aren't online") |
| **Trip cost** | Classic "value of time" in transport economics [J] | The planner charges a trip at the patient's own value, so ₹5 savings never cost an extra trip | UX, Innovation |

---
## 1. UI/UX: on-paper target 9.0

### 1.1 Screens (7, each answers one question)
| # | Screen | The patient's question | What's on it | Taps |
|---|---|---|---|---|
| 1 | Home | "Where do I start?" | One big **Scan / Share parchi** button + recent parchis + family switcher | 1 |
| 2 | Reading (≈5–10 s) | "Is it working? Is my data safe?" | Lines light up as they're read; **the patient's name blurs visibly** (a trust moment) | 0 |
| 3 | Confirm | "Did it read right?" | Cards per medicine/test; **only doubtful lines** are highlighted, with the photo crop and 3 real options; schedule (1-0-1) shown as sun/moon icons | 1 + ~1–2 fixes |
| 4 | Plan | "What's the best way to get all of it?" | One card: **"Everything ₹X · ready by 6 pm · 0 trips"**, the saving vs doctor's-shop MRP, toggles **Cheapest / Fastest / No trips**, an "Ask your doctor" card for Jan Aushadhi savings, the source and time of every price | 0–1 |
| 5 | Get it all | "What am I agreeing to?" | Summary of exactly what's ordered or booked, from whom, for how much → UPI | 1 + UPI |
| 6 | Track | "Where is it?" | Timeline per item, lab slot added to the calendar, confirmation numbers; **Plan B sheet** when something fails | 1 (approve) |
| 7 | Care | "What next?" | Dose reminders, refill countdown (from quantity × schedule), lab report arrival, next-visit packet | 0 |

### 1.2 Measured friction vs today's best competitor
| Task: 5 medicines + 2 tests from one parchi | QuickPill (observed 23 Oct) | Parchi (spec) |
|---|---|---|
| Login before scanning | **Required** (Google sign-in) [M] | **Not needed.** Scan as a guest; Sign in with Apple only at checkout |
| Taps to reach a cart for the medicines | ≈12+ (login ≈3, scan 3, "Add Best Deal to Cart" once per medicine ×5, cart 1) [M, count from the observed screens] | **≈5–7 for everything**: share 2, confirm 1, fixes 1–2, Get it all 1, UPI 1 |
| Tests on the same parchi | **Not supported**, needs a 2nd app [V] | Included |
| Apps needed | 2–3 | **1** |
| Nearby shop, Jan Aushadhi, 10-minute app | No [V] | Yes |
| Typing | Search box | **Zero** (brand autocomplete only as a fallback) |

### 1.3 Accessibility and inclusion (standards-based)
- **Touch targets** of 44×44 pt or more (Apple HIG). WCAG 2.2 AA minimum is 24 CSS px [V, handoff R35].
- **Contrast** of at least 4.5:1 for text (WCAG AA); **colour never used alone** for status. Every status has text plus an icon.
- **Dynamic Type** up to the largest accessibility sizes; full **VoiceOver** labels ("Telma 40, confirmed, morning and night").
- **Hindi + English interface**, matching device language; the **medicine schedule is read aloud in Hindi** (iOS Hindi speech voice) for elderly or low-literacy users.
- **Family mode:** manage a parent's parchi from your phone.
- **Offline:** printed prescriptions read on the phone with no network (Apple Vision was ≥80% on printed ones [M]); plans are saved for offline viewing.

### 1.4 Every error state has a next step (Nielsen heuristic: "help users recover")
| Situation | What the user sees |
|---|---|
| Blurry or dark photo | Instant on-phone quality check: "Move closer, more light". Retake in 1 tap |
| A line can't be read | Photo crop + 3 real options + "Type it" (with autocomplete from the 2.5-lakh catalogue) |
| Brand read but strength impossible ("Telma 400") | "Telma comes in 20 / 40 / 80. Which one?" [built and tested, Brand–Strength Check] |
| Medicine not available anywhere | Shown plainly, never hidden; "Ask your doctor for an alternative" card |
| Seller cancels / late / out of stock | Plan B sheet: "+₹6, by 7 pm. Approve?" |
| No internet | On-phone reading still works for printed parchis; saved plans viewable |

### 1.5 Trust
- Every price shows **its source and time** ("1mg · 4:42 am today").
- Ranking is **neutral** and says so ("We earn the same from every seller" or "We earn nothing", whichever is true).
- "Why this plan?" gives a one-line reason ("Saves ₹84 and a trip vs your nearest chemist").

### 1.6 On-paper score: **9.0**
- **Why:** 1 decision; about 5–7 taps for medicines + tests vs about 12+ for medicines only today (observed); no login to scan; zero typing; Hindi + voice; standards-based accessibility; every error recoverable.
- **Verify (turns 9.0 into a measured score):** a 5–8 person test (at least 1 elderly user).
  - Tasks: scan and confirm, pick a plan and order, handle Plan B.
  - Measure: success rate, time, taps, errors, and **SUS (target ≥80; industry average is 68 [V])**.
  - Compare against the same parchi done with QuickPill + LabFare.

---
## 2. Demo: on-paper target 9.0

### 2.1 Three-minute script, five wow moments
| Time | Beat | What judges see | Proves |
|---|---|---|---|
| 0:00 | Hook | A real messy handwritten parchi (4 medicines + 2 tests): "Today this takes 3 apps, phone calls, and you pay MRP at the doctor's shop" (numbers from our phase 5 table) | Problem |
| 0:20 | **Wow 1: WhatsApp → Parchi** | Share from WhatsApp; lines light up; **the patient's name blurs on screen** | UX, Security |
| 0:40 | Confirm | One doubtful line with its photo crop and 3 options → 1 tap | AI + human safety |
| 0:55 | **Wow 2: Cost to Complete** | "Everything ₹X, ready by 6 pm, 0 trips" vs doctor's-shop MRP ₹Y; flip to *Fastest* → 10-minute app | Innovation |
| 1:25 | Get it all | One tap → orders placed (sandbox, **labelled**) + lab slot booked → appears in Calendar | One-stop |
| 1:45 | **Wow 3: Plan B live** | **A judge presses "cancel"** on one seller → push notification → Plan B sheet "+₹6, by 7 pm" → approve | Innovation, Demo |
| 2:10 | **Wow 4: Airplane mode** | Scan a printed parchi with no network → still reads | Security, Feasibility |
| 2:25 | **Wow 5: Head-to-head** | Same handwritten photo: QuickPill vs Parchi (dated recording + measured numbers on 100 prescriptions) | Novelty, Technical |
| 2:45 | Close | 4 numbers: accuracy measured on 100 real Indian prescriptions · taps 6 vs 12+ · ₹ saved · 0 trips | Credibility |

**Optional judge test:** the judge writes any 3 medicines from a printed list on our pad, and Parchi reads them live. Fallback: a pre-scanned copy.

### 2.2 What makes it un-breakable
- **Demo reset** button (admin-only) restores the same starting state.
- **Labelled sandbox sellers** for auto-order; real deep links shown for manual mode.
- **Offline path:** reading on the phone plus a cached plan.
- **Backup:** a 2:30 screen recording of the full run, disclosed as recorded if used.
- **Every number on screen comes from our measured files** (no hand-typed figures).

### 2.3 On-paper score: **9.0**
- **Why:** 5 wow moments in 3 minutes, a judge takes part (Plan B, the optional judge test), a live comparison against a real competitor, and fallbacks for every network or AI failure.
- **Verify:** 3 clean rehearsals from reset, each under 3:00, including one with Wi-Fi off and one with an injected failure.

---
## 3. Security & privacy: on-paper target 9.2

### 3.1 Data flow: "send lines, not the page"
1. **On the phone:** detect the page → **blur patient name, age, phone, address and registration number** (Apple Vision text boxes + pattern rules) → cut out only the medicine and test lines.
2. **If on-phone reading isn't confident:** only the **cropped medicine lines** go to *our own* model server (KIET iMac, TLS). Not the whole page, and not to a third-party AI cloud.
3. **Planner** sees only the item list + pincode. No name, no phone.
4. **Sellers** see only the order, through their own licensed checkout. Parchi never holds card details (UPI hand-off).

### 3.2 Controls mapped to OWASP MASVS v2.1 (all 8 categories [V])
| MASVS | Our control | How we test it |
|---|---|---|
| STORAGE | Photos stored in the app sandbox with full file protection; **raw photo auto-deleted after 24 h** unless saved; no health text in logs | Inspect the device file system and logs |
| CRYPTO | Only Apple's built-in crypto (Keychain, Secure Enclave, CryptoKit); no home-made crypto | Code review |
| AUTH | **No account needed to scan**; Sign in with Apple at checkout; optional Face ID app lock; short-lived server tokens | Token-expiry test |
| NETWORK | TLS 1.3, Apple's transport security on, **certificate pinning** to our server | A proxy (mitmproxy) must fail to read traffic |
| PLATFORM | The share extension accepts images/PDF only; no clipboard reading; deep links validated | Fuzz the deep links |
| CODE | AI output must pass a schema plus the Brand–Strength Check before display; dependencies pinned | Feed malformed model output |
| RESILIENCE | **App Attest** on server calls, so only the real app can use our model | Call the server with a script (must be rejected) |
| PRIVACY | On-phone blur, crop-only upload, itemised consent, delete-all, export, Apple privacy manifest, **no ads or trackers** | Privacy checklist + blur recall test |

### 3.3 India-specific compliance (DPDP Act 2023 + Rules 2025)
- **Itemised, plain-language consent notice** in Hindi and English [V].
- Retention tied to purpose; **48 hours' warning before erasure** of inactive data [V].
- **Breach:** inform the Data Protection Board and users promptly; **detailed report to the Board within 72 hours** [V].
- **Children:** family mode for minors runs under the parent's account with verifiable parental consent [V].
- **Medicine safety:**
  - Parchi never dispenses.
  - Licensed partner pharmacies verify the original prescription; the 1mg FAQ shows this is the norm [V].
  - No substitution without the doctor; every order is tied to its approval.
  - Plan B needs a tap, unless the user sets an automatic cap (for example "auto-approve up to +₹20").

### 3.4 Threat model (STRIDE)
| Threat | Example | Control |
|---|---|---|
| Spoofing | A script pretends to be the app | App Attest + server tokens |
| Tampering | Changing price or quantity in transit | TLS + pinning; server re-checks the plan before ordering |
| Repudiation | "I never approved that order" | Each approval tied to a plan version and stored |
| Information disclosure | A leaked photo reveals the patient | On-phone blur + crop-only upload + 24 h deletion |
| Denial of service | Scanner overloaded (QuickPill showed "quota exceeded" 23 Oct [M]) | Our own model on our own iMac; on-phone fallback for printed parchis |
| Elevation of privilege | Patient B opens patient A's parchi | Per-user ownership checks on every object |

### 3.5 On-paper score: **9.2**
- **Why:** privacy by design ("send lines, not the page", on-phone blur, own model, no account, no cards, no trackers), all 8 MASVS categories covered, DPDP mapped, a STRIDE threat model, and safety rules for medicines.
- **Verify:**
  - Blur recall on the 12 real web prescriptions (target ≥95% of names/phones blurred).
  - Pinning test fails under a proxy.
  - Delete-all and App Attest rejection tests pass.
  - Optional automated static security scan (MobSF).

---
## 4. Scores

| Criterion | Verified today (evidence in hand) | **On paper now** | What turns on-paper into verified |
|---|---|---|---|
| Problem | 8.0 | 8.0 | Phase 5 price basket → 9.0 |
| Innovation | 7.5 | **8.0** | Cost to Complete + Plan B demo on real prices |
| Novelty | 6.5 | **7.5** | Head-to-head win + dataset published → 8.0+ |
| Technical | 8.0 | 8.0 | Trained model numbers + app build → 8.5 |
| Feasibility | 7.0 | **7.5** | Parchi Pass + Shop Quote remove the "local shops aren't online" blocker; Xcode on the lab iMac |
| UI/UX | 6.5 | **9.0** | 5–8 person test, SUS ≥80 |
| Demo | 7.5 | **9.0** | 3 clean rehearsals |
| Security | 7.0 | **9.2** | Blur recall test + pinning/App Attest tests |
| **Average** | **7.3** | **8.3** | |

Sources: DPDP Rules (SCC Online) https://www.scconline.com/blog/post/2025/11/14/meity-notified-digital-personal-data-protection-rules-2025/ · DPDP (Mondaq) https://www.mondaq.com/india/data-protection/1568122/the-digital-personal-data-protection-rules-2025-key-takeaways · DPDP (EY) https://www.ey.com/content/dam/ey-unified-site/ey-com/en-in/pdf/2025/11/ey-india-dpdp-act-2023-and-rules-2025-pov.pdf · OWASP MASVS https://mas.owasp.org/MASVS/ · ABDM Scan & Share (MoHFW) https://mohfw.gov.in/press-info/7476 · SUS (Lewis 2018) https://uxpajournal.org/wp-content/uploads/sites/7/pdf/JUS_Lewis_May2018.pdf · Juspay https://docs.juspay.io/ec-api-global/docs/overview/understanding-juspay · WHO P-drugs https://haiweb.org/encyclopaedia/who-guide-to-good-prescribing/ · Cheque cross-check https://researchconnect.buffalo.edu/en/publications/bankcheck-recognition-using-cross-validation-between-legal-and-co/

---
## 5. The "ChatGPT / Claude can do this too" test (added 23 Oct)
**Honest starting point:** general AI chatbots *can* read a parchi. We measured a frontier model (Claude) at 82% recall and 87% precision on 16 real Indian prescriptions. **So reading alone is not our moat.**

### What a chatbot structurally can't do, which is where Parchi lives
| Need after reading | ChatGPT / Claude / Gemini today | Parchi |
|---|---|---|
| **Act**: order medicines and book the lab, across sellers | No pharmacy checkout. Instant Checkout launched only in the US for retail, and a secondary report says it was ended in 2026 (unconfirmed); no India pharmacy ordering found [V] | One tap, "Get it all": orders + lab slot + UPI hand-off |
| **Remember state**: track orders, notice a cancellation | A chat has no order status, and nothing watches the seller after you close it | Track + **Plan B** auto re-route with push notification |
| **Local, live data** | Web search sees online pharmacies at best; **cannot see your nearby chemist's price or stock** | Apple Maps places + **Shop Quote** replies from nearby chemists (data that exists nowhere online) |
| **Learn from everyone's scans** | Each chat starts fresh; no memory of what your doctor usually writes | **Doctor Memory** gets better with every confirmed scan from that doctor's patients (a network effect) |
| **Safety checks against Indian catalogues** | Free text, can hallucinate a brand or strength | Brand–Strength Check against 2.5 lakh products; no substitutes without the doctor |
| **Privacy** | You upload the **whole photo with the patient's name** to a cloud chat | Blur on the phone; only medicine lines go to **our own** model |
| **Effort** | You have to know what to ask and type follow-ups, in English mostly | Zero typing, one decision, Hindi voice |
| **Offline / counter use** | Needs internet; nothing to show the chemist | Printed parchis read offline; **Parchi Pass** QR for the shop counter |
| **Health-records product** | ChatGPT Health (Jan 2026) is **US-only**, linking US records systems; no India launch found [V] | Built for Indian parchis, chemists, labs, Jan Aushadhi |

**One-line answer for judges:** *"ChatGPT tells you what's written. Parchi gets it done, and stays with you until it's done."*

### Demo beat (replaces part of Wow 5)
Same parchi in ChatGPT: it reads it fine. Then ask "order these and book the CBC near me, and tell me if anything is cancelled", and it can't. Then Parchi does it in one tap, and Plan B fires when the judge cancels. Run this live, or use a dated recording.

### Measurable check (Aditya can run it in 5 minutes with the ChatGPT app)
Give ChatGPT the same 3 test parchis and record five things:
- (a) medicines read
- (b) whether it gives a full payable price, including fees, for your pincode
- (c) whether it shows nearby chemists' prices
- (d) whether it can place an order or book a lab
- (e) whether it can alert you on a cancellation

Expected: (a) yes, (b)–(e) no. Save screenshots as evidence.

---
## 6. Evidence check: every claim in this spec and what backs it (audited 23 Oct)
Key: **M** we measured it · **V** checked in an official, primary or secondary source · **D** design choice (not a fact claim) · **⚠** still needs checking.

| Claim | Status | Backing |
|---|---|---|
| A frontier chatbot reads 82% of medicines | M | Our blind test on 16 MIRAGE prescriptions |
| Apple Vision reads ≥80% of printed prescriptions | M | 12 of 81 prescriptions |
| WhatsApp-style compression doesn't hurt reading | M | 26.3% recall at all 3 settings |
| QuickPill needs login before scanning; one "Add Best Deal" tap per medicine | M | Observed 23 Oct. Checkout steps after the cart **not observed**, so "≈12+ taps" is a lower bound |
| QuickPill scanner hit "quota exceeded" | M | Observed 23 Oct, 3 times |
| QuickPill/MediSaathi don't cover tests | V | Their own pages |
| 44×44 pt touch targets | V | Apple HIG, as reported by Deque and Uxcel (Apple's page itself still to open) |
| WCAG 2.2 AA target 24 px; contrast 4.5:1 | V | W3C (handoff R35); contrast is the standard WCAG AA rule |
| Hindi speech voice on iOS | V | hi-IN listed in Apple developer forum voice lists. **Check at runtime** (voices vary by device) |
| SUS industry average 68 | V | Lewis 2018 (JUS), Sauro data |
| Cost to Complete ← total landed cost | D + V | Davaio's cart total including delivery checked |
| **Trip cost default ₹50 per trip** | V | Value of time in India: ADB Nagpur Metro uses ₹87/h; a Bengaluru experiment found ₹609/h. ₹50 ≈ half an hour at the ADB figure, already the planner's default |
| Plan B ← Juspay failover | V | Juspay docs (their success-rate uplift is a vendor claim) |
| Doctor Memory ← WHO P-drugs | V | WHO Guide to Good Prescribing 1994; no prescription-reading use found in searches |
| Brand–Strength Check ← cheque cross-check | V + M | Buffalo paper; our check built, with 16 passing tests |
| Parchi Pass ← ABDM Scan & Share (6.64 crore tokens) | V | MoHFW, Nov 2024 |
| Shop Quote ← AskIt local quotes | V (secondary) | AskIt site via the research blueprint (S11). ⚠ re-open their page |
| App Attest proves requests come from the real app | V | Apple DeviceCheck docs. **Limit:** can't detect a compromised OS (Apple says so) |
| Apple privacy manifest required | V (secondary) | Vendor docs: required since spring 2024. ⚠ Apple's page still to open |
| MASVS v2.1 has 8 categories, 24 controls | V | OWASP MAS |
| DPDP: itemised notice, 72-h Board report, parental consent, 48-h erasure notice | V | SCC Online, EY, Mondaq. User-notice timing differs between sources |
| ChatGPT Health is US-only; no Indian pharmacy checkout in ChatGPT | V | OpenAI's announcement; TechCrunch. The "Instant Checkout ended" report is unconfirmed |
| Licensed pharmacy verifies the original prescription | V | 1mg FAQ |

### When "if it's built, we get this score" holds
1. **Built as written.** Each feature above exists and works. If the 24-hour build covers only part of it, the score drops by that part's share (a build-priority list comes in phase 8).
2. **Every verification test passes at its threshold:**
   - SUS ≥80 with 5–8 users
   - patient-name blur ≥95% on the 12 web prescriptions
   - 3 clean rehearsals under 3:00
   - the interception (pinning) test fails as expected
   - App Attest rejects a script
3. **The scores are our best expert estimate (±0.5).** The event hasn't published judging weights, and no one can guarantee a judge's number.
4. **Known risks that could still pull scores down:**
   - our own model's accuracy (measured on Kaggle later)
   - Xcode on the lab iMacs
   - venue Wi-Fi (the offline path covers this)
