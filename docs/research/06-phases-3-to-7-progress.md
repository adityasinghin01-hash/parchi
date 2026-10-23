# Phases 3–7: progress so far (23 Oct 2026, ~07:00 IST)
Labels: **[M]** measured by us · **[V]** checked in a source · **[A]** assumption, labelled in the data.

## Phase 5: Prices (MOSTLY DONE)
**Medicines:** live prices from MedScanner (pincode 560095), captured 23 Oct 05:10 [M]. Raw data: phase5-prices/medscanner_basket_2026-10-23.json

| Medicine (exact pack) | MRP (doctor's shop) | Cheapest online | Jan Aushadhi equivalent (same quantity) |
|---|---|---|---|
| Dolo 650 ×15 | ₹32.12 | ₹25.70 Truemeds | ₹15.47 |
| Pan 40 tab ×15 | ₹192.80 | ₹154.24 Truemeds | ₹18.71 |
| Telma 40 ×30 | ₹216.72 | ₹173.38 Truemeds | ₹37.14 |
| Glycomet SR 500 ×20 | ₹42.24 | ₹35.90 Medkart | ₹21.58 |
| Azithral 500 ×5 | ₹126.73 | ₹101.38 Truemeds | ₹65.63 |
| Montair LC ×15 | ₹419.79 | ₹335.83 Truemeds | ₹30.95 |
| **Total** | **₹1,030.40** | **₹826.43 (−19.8%)** | **₹189.48 (−81.6%, needs the doctor's OK)** |

- **Jan Aushadhi:** the full official list was downloaded from the PMBI API: **2,439 products, 343 with zero MRP ("under process")** [M]. File: phase5-prices/janaushadhi_products_2026-10-23.json
- **Competitor error evidence [M]:**
  - MedScanner's "BEST PRICE" for **Pan 40 tablet was an injection** (₹47.66).
  - For **Telma 40 it compared a 10-tablet pack against 30-tablet packs.**
  - This supports our exact form and pack check.
- **No single online pharmacy carried all 6 medicines** in the listing (Truemeds lacks Glycomet, Medkart lacks Montair LC). Only MedPlus and the doctor's shop had all 6, at MRP [M].
- **Delivery fees are not published consistently** [V]:
  - Truemeds: "shown on order summary"; free above ₹500 (CashKaro) or ₹750 (Zoutons)
  - Medkart: free above ₹500 (official)
  - PharmEasy: "depends on value and address"; free with PLUS
  - MedPlus: "by order type and location"
  - Zepto (Nov 2025): no handling or surge fees; ₹30 below ₹99
  - Blinkit: unknown, **Aditya will provide**
  - **The true price is only visible at checkout, which proves the need for Cost to Complete.**
- **Local chemists:** selling below MRP is allowed (Delhi advisory) [V]. Discounts are anecdotal (5–10%). CGHS authorised chemists give 10.5–29% off MRP (procurement terms) [V].

**Lab tests, Ghaziabad, listed prices [V; aggregator vs lab pages differ]:**

| Test | Lowest | Highest | Spread |
|---|---|---|---|
| CBC | ₹245–299 (Lal / Redcliffe) | ₹404 (Healthians, Bajaj Ghaziabad page) | ~1.4–1.6× |
| HbA1c | ₹273 (Healthians) | ₹638 (Apollo; member ₹510) | 2.3× |
| Thyroid profile (T3/T4/TSH) | ₹390 (Apollo Lal Kuan) | ₹1,224 (Max) | 3.1× |
| Lipid profile | ₹599 (Redcliffe package incl. thyroid) | ₹663 (Healthians) | — |
| **Earlier deck evidence (to re-verify)** | Thyroid ₹340 Chennai vs ₹560 Kolkata (Lal PathLabs); Free T3/T4 ≠ Total T3/T4; night visit ₹450 + 1.5× rates | | |

**Planner on real prices [M]** (ParchiCore, scenarios/real_basket_*.json; fee rules marked [A] where not published):
- **Cheapest exact plan** (6 medicines + 4 tests): **₹2,696.77, 0 trips, ₹0 fees**.
  - Medicines ₹832.77 vs ₹1,030.40 at MRP (**−19.2%**). The planner bought Glycomet at the doctor's shop rather than pay a ₹50 split-delivery fee.
  - Tests ₹1,864 vs ₹2,929 at the highest listed prices (**−36%**).
- **Plan B:** Truemeds cancels → 5 items re-routed (Medkart + doctor's shop) for **+₹165.74**; 5 items kept unchanged.
- **Fastest:** medicines from the doctor's shop in 5 minutes (the patient is already there); labs judged separately.
- **With the doctor's OK for generics:** **₹2,053.48** with 1 trip to Jan Aushadhi (3.6 km).
- **Engine: 17 of 17 tests pass** [M]. Note: the first test build after a clean can fail with "TestingMacros plugin not found". Re-running `swift test` fixes it.

## Phase 3: Text → exact item (MOSTLY DONE)
- **Catalogue coverage of prescribed brands:** 79% unique / 83% of mentions [M] (2.5-lakh dataset, Nov 2022 prices). Missing: supplements and OTC (Shelcal, Becosules, Zincovit…).
- **Jan Aushadhi equivalent (same salts + strength + form)** for MIRAGE-100 medicines [M, heuristic matcher, spot-checked]:
  - **187 of 327 mentions = 57%**
  - **187 of 263 with known composition = 71%**
  - The first naive pass (no form check) said 64% but wrongly matched forms; the corrected pass is the honest one.
  - Script: phase3-mapping/ja_cov.py
- **Brand–Strength Check** built (impossible strength → real choices) [M].
- **Still to do:** test-name standard (LOINC is a free standard [to cite]; handle Free vs Total T3/T4; a top-50 test synonym table); same-salt brand price spread from the catalogue.

## Phase 4: Nearby places (MOSTLY DONE)
- **Apple MapKit** (free, no key) [M]:
  - **KIET:** 2 places within 3 km, 6 within 5 km, **42 within 10 km** (real names and phone numbers; includes Jan Aushadhi stores at 3.6 km and 5.5 km, Thyrocare, Lal PathLabs).
  - **Ghaziabad Raj Nagar:** **27 within 3 km**.
  - Script: phase4-places/mapkit_nearby.swift
- **Jan Aushadhi Kendras:** 143 in Ghaziabad district (publicservicesmap directory) vs 75 officially in 2021 (Lok Sabha) [V]. The official locator page wasn't reachable in the browser (site slow).
- **Google Places (New):** Pro searches reportedly include **5,000 free calls a month**, and billing is required (third-party source) [V].
- **NABL directory:** official search on nabl-india.org not done yet.
- **OpenStreetMap:** Overpass servers failed twice.

## Phase 6: Automation (PARTLY DONE)
- **Search hand-off links work** [M]: 1mg / PharmEasy / Truemeds / Apollo search URLs return 200 and Zepto 202. Blinkit returns 403 to scripts (app deep link to test on the phone). Cart pre-fill is not documented anywhere.
- **WhatsApp click-to-chat** (`wa.me/<number>?text=…`) works with no API, cost ₹0 [M], for Shop Quote and Parchi Pass sharing.
  - The WhatsApp Cloud API (to read replies automatically) has free service conversations; utility messages cost about ₹0.115–0.35 each (sources conflict) [V].
- **UPI on iOS:** generic `upi://pay` can't pick the app and returns no status. Use app-specific schemes plus server verification, or hand off to the seller's checkout [V]. **Decision: hand off to seller checkout (no money held).**
- **Lab booking APIs:** no public partner API found for Thyrocare / Healthians / Redcliffe [V]. LabStack docs exist (from the handoff). **Decision:** booking by deep link to the lab page, or a call / WhatsApp to the lab; sandbox labelled for the demo.
- **TinyFish** (from the HackIIITD report):
  - Fetch is free for 1,000 URLs a day, so it can refresh live prices.
  - Agent costs $0.016 per step; signup wallet $8 ($35 for students); CAPTCHA and OTP limits apply.
  - Optional; our own server fetch also works.
- **Automations so far: 10** (AU1–AU10). Candidates to add:
  - AU11 live price refresh
  - AU12 Shop Quote WhatsApp
  - AU13 Parchi Pass share
  - AU14 lab slot to Calendar
  - AU15 dose reminders
  - AU16 refill countdown
  - AU17 Live Activity tracking

## Phase 7: Legal (STARTED)
- **E-pharmacy:**
  - The 2018 draft rules have still **not been notified** (2026 academic paper) [V].
  - The Delhi High Court's 2018 interim order covers unlicensed online sales.
  - **The Madras High Court (Jul 2024) allowed online sales routed through licensed chemists** [V].
  - **Parchi is safe by design:** it doesn't sell, it routes to licensed sellers.
- **Still to research:** Drugs Rules Schedule H/H1/X; Consumer Protection (E-Commerce) Rules 2020 (disclosing ranking parameters and affiliate links); Telemedicine Practice Guidelines 2020; whether Parchi counts as software-as-a-medical-device (it doesn't diagnose).

## Remaining work (in order)
1. Phase 6 wrap-up: final automation list and count; Blinkit fees from Aditya.
2. Phase 7 legal searches (list above) + cost per user.
3. **Phase 8: final synthesis.** Personas, need→why, minimal inputs, 24-hour feature cut and build plan by hour and role, final novelty and innovation lines, final scores (verified vs if built), demo script v2, risk list.
4. **After the lock:** synthetic dataset generator → Kaggle (free) LoRA on Qwen2.5-VL / Parrotlet → measure on MIRAGE-100 + WhatsApp copies + 12 web photos.
5. Verification tests:
   - QuickPill handwriting head-to-head (retry; its quota resets)
   - Aditya's 5-minute ChatGPT test
   - patient-name blur ≥95%
   - 5–8 person usability test (SUS)
   - 10–20 person survey
