# PARCHI V2 — MASTER PLAN (end to end)
Locked 23 Oct 2026, 18:30 IST. Replaces the build order in file 11 (file 11 stays as the idea/evidence record).
**Target = V2.** V1 is the first milestone on the way. The recommendation engine is V3 (after V2).
Every claim is measured [M], sourced [V], or a design choice [D]. Drive = **preetichauhan1977** account, folder **"Parchi Data"**, shared with the team.

---
## 0. Versions

| Version | What it is | Done when |
|---|---|---|
| **V1** | The whole flow works end to end on real data for **Muradnagar + Meerut**: share/scan → blur → read → confirm → plan (List \| Map, cheapest first) → Get it all (Checkout Assistant) → Track → Plan B; lab booking; Ask nearby shops + pickup; judge Cancel | A judge can run it start to finish on the iMac simulator and on one real iPhone, no known bugs |
| **V2** (target) | V1 + the full **Orchestrator** (8 automations with timers and memory), Checkout Assistant for every seller that allows it, data for 6 cities, all 12 gaps + the 20 user-side gaps below closed, trained model plugged in | Every V2 acceptance test in §9 passes |
| V3 (after) | Recommendation engine, shop dashboard, partner APIs (labs, pharmacies, WhatsApp Business), more cities | Post-hackathon |

---
## 1. What we were leaving out (now added)
**From the plan review (12):** Checkout Assistant · Orchestrator automations · big data collection to Drive · Muradnagar/Meerut lab prices · Plan B for labs (sample rejected) · order status after hand-off · server security (install key, rate limit) · owner for 24 h auto-delete + consent record · doctor memory wired into reading · catalogue-constrained reading (build it or drop the claim) · hand-copy writers assigned · real iPhone install.

**Found now, thinking as the user (20):**

| # | Gap | Fix in V2 |
|---|---|---|
| U1 | Location permission and "no permission" path | Ask on the Plan screen with a reason; fallback = pick city/area (Muradnagar, Meerut, …) |
| U2 | Delivery / home-collection **address** | One saved address on the phone (Settings); used in lab SMS and hand-offs |
| U3 | **History** of parchis on Home | Saved on the phone (SwiftData); reopen any old plan |
| U4 | **Printed parchi → items** (offline path) | On-phone parser: Apple Vision lines → "Tab/Cap/Syp + brand + strength + dose" → catalogue snap |
| U5 | **Test names** (CBC, HbA1c, "Free vs Total T3/T4" trap) | Canonical test list with synonyms; ambiguous ones asked on Confirm |
| U6 | **Jan Aushadhi match for any medicine** (not only the demo 6) | Salt + strength + form matcher in the engine (port of `ja_cov.py`, 57% coverage measured) |
| U7 | **Price coverage**: medicines with no live/snapshot price | Show catalogue MRP with its date ("MRP, Nov 2022 list"), mark "check at shop"; never invent |
| U8 | Lab Plan B ("sample rejected", "phlebotomist late") | Same Plan B sheet: next lab/slot |
| U9 | Status when the app is in the background | No push on a free account → status refreshes when the app opens + local notification for reminders; documented limit |
| U10 | **Sign out of all sellers** (in-app browser keeps logins) | Settings button that clears the in-app browser data |
| U11 | iOS "Local Network" permission when talking to the iMac | Add the Info.plist reason text; test on device |
| U12 | HTTP to the iMac blocked by iOS security (ATS) | Allow local networking only (`NSAllowsLocalNetworking`); V3 = TLS |
| U13 | **SMS sheet doesn't work in the Simulator** | Demo SMS on the real iPhone; Simulator falls back to the share sheet |
| U14 | **Document scanner doesn't work in the Simulator** | Simulator demo uses Photos import / WhatsApp share; scanner on the real iPhone |
| U15 | Map in the Simulator shows California | Set the simulated location to KIET (28.7524, 77.4990) |
| U16 | Which phone runs the live demo | One teammate's iPhone, free signing (7-day profile), installed the night before |
| U17 | Automated tests for "no known bugs" | Engine unit tests + one UI test of the main flow + the Orchestrator tests (§9) |
| U18 | Hindi for the automation messages (SMS/WhatsApp to shops and labs) | Templates in Hindi + English |
| U19 | Data deletion covers server data too | "Delete everything" also clears our iMac records for that install |
| U20 | Stale-price warning | Any price older than 7 days shows "may have changed" |

---
## 2. Research first (do all of it at the start, H0–H3, in parallel with V1 building)

| ID | Question | How | Output | Owner |
|---|---|---|---|---|
| R1 | Which sellers allow login + medicine checkout **inside an in-app browser**? (1mg, Truemeds, Apollo, PharmEasy, Netmeds, MedPlus) | Try each in the Simulator's in-app browser | Table: login ✓/✗, add-to-cart ✓/✗, checkout ✓/✗, UPI hand-off ✓/✗ | Lead + Claude |
| R2 | Do Blinkit/Zepto web take medicine orders in Muradnagar/Meerut? | Same test + their help pages | Yes/no per city; fallback = open their app | Lead |
| R3 | Lab booking pages + phone/WhatsApp per lab per city | Lal PathLabs, Thyrocare, Redcliffe, Healthians, Apollo Diagnostics, Max, Metropolis + local labs from Apple Maps | `labs_<city>.csv` | Claude |
| R4 | Lab test prices per city (top 25 tests) | Their public price pages, dated | `lab_prices_<city>.csv` | Claude |
| R5 | Product-page link per demo medicine per seller (exact pack/form) | Public product pages | `product_links.csv` | Claude |
| R6 | Shops + labs + Jan Aushadhi Kendras in 6 cities | Apple Maps search grid + OpenStreetMap | `places_<city>.json` | Claude |
| R7 | Test-name standard + synonyms | Lab menus + LOINC-style names | `tests_canonical.json` | Claude |
| R8 | Schedule H1 / X salt list | Official notifications (G.S.R. 588(E) + later additions) | `schedule_h1_x.json` | Claude |
| R9 | SMS / WhatsApp templates (Hindi + English) that shops actually answer | Draft + 3 real tries during the phone survey | `templates.json` | Lead |
| R10 | Catalogue-constrained reading: can we force the model to output only real brands? | HF `prefix_allowed_tokens_fn` / MLX logits processor test | Go / no-go (no-go → drop the claim, keep catalogue snap) | Singhal |
| R11 | How do we learn an order went through after a hand-off? | Seller confirmation page URL patterns in the in-app browser + user tap "Ordered ✓" | Rule per seller | Lead + Claude |
| R12 | Local-shop prices (phone survey) | 5–8 chemists per city, scripted call | `shop_calls_<city>.csv` | 1 teammate |
| R13 | Automation engine choice | Done (§4) | Own engine | — |

**Cities for data:** Muradnagar, Meerut (deep), plus Modinagar, Ghaziabad, Hapur, Noida (lighter). **Drive layout:** `Parchi Data/places/`, `labs/`, `prices/`, `product_links/`, `catalogue/`, `calls/`, `README` (source + date per file).

---
## 3. System V2
```
iPHONE APP (SwiftUI)                                   LAB iMAC                                      DRIVE + DGX
Capture · blur · on-phone read · parser ──crop──►  READER  (Singhal's MLX model, /read)             Parchi Data (all research data)
Confirm (catalogue, brand–strength, doctor memory)  ORCHESTRATOR (Python, standard library)          DGX: training + testing
Plan (List | Map) · Checkout Assistant (in-app web) │  jobs + timers + states in SQLite
Ask shops (SMS/WhatsApp) · Lab booking · Track     │  8 automations (§4) · safety net
Care (reminders, refill) · Parchi Pass · Settings  │  endpoints: /read /plan-events /order /status
        ▲  every 2 s /status  ◄──────────────────────│  /judge /shop/<id> /lab/<id> /reset
        └──────────────── ParchiCore (planner, Plan B, checks) runs on the phone
```

---
## 4. Automation engine (answer: we build our own)

| Option | Verdict | Why |
|---|---|---|
| LangChain / LangGraph | **No** | For chaining LLM calls and agents. Our automations are rules + timers, not AI reasoning; an LLM would add delay, randomness and cost, and the only AI we need is the reader |
| n8n (self-hosted) | Not for V2 | Free and visual, but another server to install and keep alive on the iMac; workflows live outside our code |
| Zapier | **No** | Paid cloud; can't see our iMac; sends health data to a third party |
| Temporal / Inngest / Trigger.dev | Not for V2 | Proper durable-workflow engines, but heavy to install for 24 h |
| **Own engine** (Python standard library + SQLite on the iMac) | **Yes** | Nothing to install; deterministic; works offline; every step logged (our safety net); we copy the durable-workflow idea (states, timers, retries, no double runs) without the weight |

**Engine design:** each automation = a **state machine** (states + allowed moves), **timers** stored in SQLite (survive restarts), **idempotency keys** (one order never placed twice), **approval records** (who approved what plan version), an **event log** the app reads. V3 can swap in n8n or Temporal if we outgrow it.

---
## 5. The 8 automations (V2 spec)

| # | Automation | Trigger → steps | Timers / rules | Data it keeps | V |
|---|---|---|---|---|---|
| A1 | **Smart Router** | Plan built → score each seller = price + fees + trips + **reliability** | Reliability = successful ÷ total orders per seller per area (starts at a neutral prior) | Seller reliability per area | V2 |
| A2 | **Plan B** | Cancel / out of stock / late / sample rejected → re-plan only failed items → ask approval (or auto under the user's cap) | Late = past promised ETA + 30 min | Failure events | V1 |
| A3 | **Shop auction** | Ask 3 nearest shops (SMS/WhatsApp + reply link + pickup time) | No reply in 10 min → next 3; first complete reply wins; others get "thanks, not needed" | Shop prices, stock, reply time | V1 (single round) → V2 (rounds) |
| A4 | **Checkout Assistant** | Get it all → seller by seller inside Parchi: product page → user adds → next → checkout → "Ordered ✓" | Detect confirmation page (R11) or user tap | Exact product links, which sellers completed | V1 |
| A5 | **Lab concierge** | Book (SMS/web) → lab confirms via reply link → Calendar → fasting reminder 9 pm the night before → collection day check → report-due chase | Reminder times; chase at report due + 6 h | Lab response time, report collected yes/no | V1 booking, V2 rest |
| A6 | **Refill autopilot** | Doses × days → 3 days before running out: re-plan with today's prices, ask the last shop to keep it ready, 1 tap | Daily check | Repeat orders | V2 |
| A7 | **True-price learner** | After checkout: "What did you pay?" (or read the bill on the phone) | Once per order | Real fees per seller per pincode | V2 |
| A8 | **Safety net** | Every automation step | No double orders, every approval stored with plan version, "did this go through?" check after 15 min | Full audit log | V1 |

---
## 6. Checkout Assistant (A4) screen spec
Top bar: "Step 2 of 4 · Truemeds · 3 items" + item checklist. Body: the seller's own website (in-app browser). Buttons: **Find on page** (highlights the item name), **Added ✓**, **Go to checkout**, **Skip this seller** (re-plans). Rule: **the user taps "Add to cart" and "Pay" themselves**; Parchi never clicks for them (seller terms; PharmEasy bans automation [V]). Local shop step = in-app SMS (real iPhone) or share sheet (Simulator). Lab step = lab page or booking SMS.

---
## 7. Who does what, V1 → V2 (hours from start)

| H | Lead (Aditya Singh) + Claude | Aditya Singhal (AI) | Antara (screens) | Aditya (capture/care) |
|---|---|---|---|---|
| 0–3 | **Research R1, R2, R9, R11**; Claude R3–R8 + data to Drive; Orchestrator skeleton (SQLite, state machines, /status, /judge) | DGX setup, 40k data, start 7B training; R10 constrained-reading test | Competitor teardown (resources doc), design system, Home + Confirm | Scanner, WhatsApp share, blur port, location + address |
| 3–6 | A2 Plan B + A8 safety net + A3 single-round shop ask + reply form; /lab booking + reply | Baseline on MIRAGE-100; hand-copy cards out | Plan List \| Map, price pins, shop sheet | On-phone printed parser (U4), consent + auto-delete |
| 6 | **Check 1 (V1 core)** | | | |
| 6–10 | A4 Checkout Assistant; A5 booking; real data into the app (6 cities, labs, prices, links) | Training runs; hand-copy photos | Get it all, Track, Plan B sheet, lab options | Parchi Pass, Care, Hindi |
| 10 | **Check 2 = V1 DONE** (end to end, real data, Simulator + iPhone) | | | |
| 10–15 | V2: A1 Router + reliability, A3 rounds, A5 reminders/chase, A6 refill, A7 true-price, U1–U20 fixes | Tests → pick model → MLX on iMac → `/read` live | Polish + dark mode + Dynamic Type + animations | History (U3), sign-out (U10), stale warnings (U20) |
| 15 | **Check 3 = V2 feature-complete** | | | |
| 15–18 | Tests (§9), bug bash, deck numbers | Final numbers + "How accurate" | Fixes only | Fixes only |
| **18** | **FREEZE** | | | |
| 18–22 | 3 rehearsals, usability test (SUS), backup video | | | |
| 22–24 | Submit with 1 h spare | | | |

**Cut line (if Check 3 is late):** A7 → A6 → A5 chase → A3 rounds → A1 reliability fall back to V1 behaviour. **Never cut V1.**

---
## 8. Lead's work, end to end
1. **Research (H0–3):** R1 in-app checkout test per seller, R2 Blinkit/Zepto, R9 templates, R11 order-confirmation signals. Decide the seller list for the Checkout Assistant.
2. **Orchestrator (H0–15):** engine + 8 automations + endpoints + judge page + shop/lab reply forms + install key + rate limit; tests for every state machine.
3. **Data in the app (H6–10):** places, labs, prices, product links, H1/X, tests from Drive → app bundles with dates.
4. **Integration (H6, H10, H15 checks):** merge branches only after an iMac build passes; real iPhone install (U16).
5. **Evidence (H0 send, H12 analyse, H18–21 test):** survey, phone survey (R12), SUS, ChatGPT clip.
6. **Deck + demo (H12–18):** slides per file 11 + Lead doc; demo v3 adds the Checkout Assistant and the shop auction.
7. **Freeze + rehearse + submit (H18–24).**

---
## 9. V2 acceptance tests

| # | Test | Pass |
|---|---|---|
| T1 | Engine unit tests (planner, Plan B, checks, JA matcher, parser) | All pass |
| T2 | Orchestrator tests: each state machine, timers after restart, no double order | All pass |
| T3 | UI test: share → confirm → plan → Get it all (sandbox) → judge Cancel → Plan B approve | Passes 3× in a row |
| T4 | Shop auction: no reply 10 min → next 3 asked (test clock) | ✓ |
| T5 | Lab: booking → reply → Calendar → fasting reminder scheduled | ✓ |
| T6 | Checkout Assistant on every seller marked ✓ in R1 | Reaches each seller's checkout |
| T7 | Offline: printed parchi read + saved plan shown with Wi-Fi off | ✓ |
| T8 | Privacy: name blurred before upload; delete-all clears phone + iMac | ✓ |
| T9 | Every price shows source + date; >7 days shows warning | ✓ |
| T10 | Real iPhone run (scanner, SMS, map location) | ✓ |

---
## 10. Scores (on paper = V2 built and every test passes)

| Problem | Innovation | Novelty | Technical | Feasibility | UI/UX | Demo | Security | **Avg** |
|---|---|---|---|---|---|---|---|---|
| 9.0 | **9.0** | **8.5** | 9.0 | 8.5 | 9.0 | 9.0 | 8.8 | **8.85** |
Conditions: Novelty 8.5 rests on the live local-shop network + reliability routing + shop auction (none found in 15 players [V]); Technical 9.0 needs R10 built or the "constrained reading" claim removed; UI/UX needs SUS ≥ 80. If V2 is only partly built, score the parts that work.

---
## 11. V3 (after V2)
Recommendation engine · shop dashboard (shops answer in 10 s, mark ready) · partner APIs (labs, pharmacies, ONDC) · WhatsApp Business API to read replies · push notifications (paid Apple account) · App Attest · TLS · more cities.
