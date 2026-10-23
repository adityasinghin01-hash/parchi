# Parchi — research plan (23 Oct 2026)

**Problem:** everyone leaves the doctor with a paper parchi. Nobody tells them where to buy the medicines or get the tests done, or what a fair price is. So they go wherever the doctor points.
**Goal of the research:** a one-stop app. The user scans once and gets: where to go, the real price to pay, and the order or booking done. Everything has evidence and numbers, on paper.

## Rules for every phase
- **Depth:** 10+ targeted searches per phase, primary sources (papers, official documentation, model and dataset pages, pricing pages) and hands-on tests where possible. Each fact is labelled verified, observed, or my judgement.
- **Novelty and innovation, in order of preference:**
  1. **We create it:** a new model, dataset, method or workflow.
  2. **Otherwise we improve something that exists.** Name the existing system or feature, show with evidence what it does badly, and say exactly what our AI or automation does better.
- **Every feature passes a need → why check.** Keep it only if the "why" has a solid answer. Fewer user inputs, more output.
- **We get our own identity.** For each competitor, a "they do badly, we do well" row with evidence: a dated test, a count of user complaints, or their own published terms.
- **Scored against the judging criteria:** problem, innovation, novelty, technical depth, feasibility, UI/UX/CX, demo, security. The event hasn't published official weights.

## End-of-phase report (same every time)
1. Findings: tables with numbers and sources
2. Consolidated idea (at most 5 lines)
3. **Novelty line:** tier 1 or tier 2
4. **Innovation line:** which existing step we automate, or which AI step we improve
5. Running registers updated (see below)
6. Need → why check for any new feature
7. Scorecard: 8 criteria, change since the last phase, and why
8. Open questions, and what I need from you

## Running registers (they grow each phase)
- **AI:** task, model, size, dataset, training recipe (base model, settings, hours on which hardware), where it runs (iPhone, Mac or GPU server), target metric, evidence
- **Datasets:** name, size, licence, Indian or not, task, used for training or testing
- **Automations:** what triggers it, what it does, provider or API, whether the user approves, fallback, steps saved. Includes the total count
- **Competitor matrix:** about 15 apps × about 12 capabilities
- **Claims:** each claim, its source, whether it's verified, and the wording we're allowed to use

## Phases

| # | Phase | What we answer | How | Numbers we produce | Decision at the end |
|---|---|---|---|---|---|
| **1** | **Reading the prescription (the core)** | How do 1mg, PharmEasy, Apollo, Truemeds, Eka, Smart Bharat and others read prescriptions: with AI, or with a pharmacist reading it by hand? Which models read Indian handwriting best? What datasets exist? Can we train our own model, and how? | Papers (MIRAGE, RxHandBD and others), model pages (Apple Vision, ML Kit, TrOCR, PaddleOCR, Florence-2, Qwen-VL, Eka Parrotlet, Gemini/GPT/Claude), dataset pages, competitor help pages. **Live test:** run Apple Vision on this Mac over public prescription images and your real photos. **Borrowed technique:** check how postal-address and bank-cheque readers use a fixed word list and cross-checks, and apply that to medicine names | Datasets (images, writers, licence, Indian?); models (size, licence, runs on device?, published and measured accuracy); training recipe (base model, settings, epochs, image size, GPU hours); medicine-name match rate before and after the word list | If no method is usable on handwriting: AI drafts, the user confirms with one tap, and printed or e-prescriptions are supported first |
| **2** | **Competitors and our identity** | Who does what (e-pharmacies, quick-commerce, price comparers, labs, health records, Jan Aushadhi, plus global examples like GoodRx)? Where do they fail users? | Official feature pages, public web flows run with one fictional prescription, **mining App Store and Play Store reviews** (count each complaint theme), steps and taps per task | Matrix of about 15 apps × about 12 capabilities; complaint percentages; taps per task | Identity statement plus the "they do badly, we do well" table. If one app already compares a whole parchi (medicines and tests) across providers, we change the identity |
| **3** | **Turning text into the exact item to buy** | Map brand → salt → strength → form → pack. Same-salt cheaper options and Jan Aushadhi matches (shown as "ask your doctor", because chemists legally can't swap brands). Standard names for tests | Kaggle India medicine dataset (~2.5 lakh brands), Jan Aushadhi list, NPPA price caps, CDSCO, LOINC and lab catalogues; look-alike medicine name risks | Dataset sizes, licences and freshness; match rate and ambiguity rate on a sample | Which catalogue we use, and the matching rules |
| **4** | **Nearby labs and pharmacies (real, live)** | Where real locations come from, what it costs, and the rules | Google Places (pricing, free limits, billing needed), Apple MapKit and Maps Server API (free limits), OpenStreetMap, Mappls, Ola Maps, NABL accredited-lab list, Jan Aushadhi store list, chain store locators. **Live test:** count real labs and pharmacies within 2 km and 5 km of KIET from each source | Count per source, overlap between sources, cost per 1,000 calls, free limits, how long we may store the data | Main source plus a backup source |
| **5** | **Prices: MRP vs what you actually pay at checkout** | For one fixed basket (5 common medicines and 3 tests), the MRP, selling price, discount and every fee on each platform. How to get this data legally | Blinkit, Zepto, Instamart, 1mg, PharmEasy, Apollo 24/7, Netmeds, Truemeds, MedPlus, Jan Aushadhi; for tests, Lal PathLabs, Thyrocare, Redcliffe, Healthians, Orange, Metropolis, 1mg Labs. Each platform's partner API, affiliate or ONDC options and terms of service | Price spread per item, basket total spread, fees as a share of the total, delivery time | Which platforms we show live, which we show as estimates, and how often we refresh |
| **6** | **Automation: order, book, pay, track** | Two modes: **manual** (we fill the cart and hand off to the app) vs **auto** (we place the order or booking). Lab booking that returns a confirmation number. Payment and reminders | Partner APIs (1mg, eVitalRx, LabStack, lab-chain business APIs), ONDC, deep-link and cart-prefill support, legality of automating another site, AI call or WhatsApp booking agents, UPI intent and UPI Autopay (RBI rules), Apple calendar and reminders (EventKit) | For each automation: steps saved, provider, cost per transaction, whether the user approves, fallback. **Total count of automations** | Which automations go in the demo, and which are roadmap |
| **7** | **AI and automation list, Swift build, security, legal** | Pull together every model, dataset and setting, and every automation. How it's built in Swift. Privacy, prescription and e-pharmacy law | SwiftUI, Vision, VisionKit, Core ML/MLX, App Intents, Vapor; whether the lab iMacs have Xcode; OWASP mobile security standard (MASVS); India's data protection rules (DPDP 2025); drug and prescription rules; e-pharmacy legal status; platform terms of service | Full registers, cost per user, threat list | Final architecture |
| **8** | **Final synthesis (from the user's side)** | Who exactly the users are, every need and its why, fewest inputs, most output, the one-stop flow | Persona and need → why ladder; count inputs (target: scan, confirm, pay, so 3 or fewer); list outputs; what we build in 24 h vs later | Final scorecard with evidence | The final idea, novelty and innovation lines, identity, and demo outline |

**Time:** about 1 to 2 hours per phase, roughly 10 hours in total. If the hackathon starts sooner, phases 1, 2 and 5 are the ones that must be done.

## What I need from you
1. **When the hackathon starts**, and whether work done before it is allowed.
2. **5 to 10 real prescription photos** from family, with consent and names covered. Public datasets don't have complete Indian handwritten prescriptions, so this is the most valuable input for phase 1.
3. **For phase 5:** you'll need to log in with your phone OTP on Blinkit, 1mg and similar apps, so we can see real checkout fees.
4. **Google Cloud billing:** are you willing to add a card, yes or no? This decides the phase 4 options.
5. **Your DGX A100 access:** is it real, and from where can you use it? This decides whether we train our own model in phase 1.

## Score targets: average 8.5–9 (set 23 Oct)
Today's average is 7.1. Each criterion's number moves only when its proof exists.

| Criterion | Now | Target | What raises it | Proof needed |
|---|---|---|---|---|
| Problem | 8.0 | 9.0 | Our own measured numbers: the same parchi priced at the doctor's shop (MRP) vs the cheapest complete option; plus a 10–20 person survey (KIET or family) on how people buy today | Phase 5 basket table + survey results |
| Innovation | 7.0 | 8.5 | **Whole-parchi optimiser** (cheapest complete plan across chemists, labs, 10-minute apps and online, including fees, minimum order and number of trips) + **Plan B** + one tap from WhatsApp | Working optimiser + a live Plan B re-route |
| Novelty | 6.5 | 8.5 | Per-doctor usual-brand memory + cheque-style brand–strength check + cross-seller Plan B (none found anywhere) + **our own open dataset and generator of Indian handwritten prescriptions** (MIRAGE released only 100) | Literature/product check stays clean + dataset released + head-to-head win |
| Technical | 7.5 | 8.5 | Our own trained model (before/after numbers), running on the iMac and phone; all-Swift pipeline (SwiftUI, Vision, VisionKit, share extension, local server); optimiser | Kaggle numbers + working build |
| Feasibility | 6.5 | 8.5 | Scope locked to data we can really get: MRP catalogue, official Jan Aushadhi prices, lab chains' public price pages, Apple MapKit for real nearby places (free); manual hand-off by deep link; labelled sandbox for auto-order; ₹0 budget; dataset and training done before the event | Phase 4–6 data checks + Xcode confirmed on the lab iMac |
| UI/UX | 6.5 | 8.5 | 1 photo, 1 plan screen, 1 tap (3 inputs or fewer); Hindi UI; large text and VoiceOver; share from WhatsApp; 1-tap reorder for monthly medicines | A 5-person usability test: time and taps vs today's way |
| Demo | 7.5 | 9.0 | Live: share a handwritten parchi from WhatsApp, get a plan in under 10 s, order, simulate a cancellation, Plan B re-routes. Plus a **live head-to-head** of the same photo in QuickPill vs Parchi | 3 clean rehearsals |
| Security | 7.0 | 8.5 | Read on the phone first; own model on our own iMac (no third-party cloud); **automatic blurring of patient name and phone number on the phone** before anything leaves it; consent screen under India's data protection rules (DPDP); delete on demand; UPI hand-off (no card storage) | Threat model + tests |
| **Average** | **7.1** | **8.6** | | |
