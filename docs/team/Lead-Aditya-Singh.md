# Lead: Aditya Singh — the independent doc, start to end
Locked 23 Oct 2026 (includes the mentor update). Read `CONTEXT.md` first. Claude writes and builds the code on the iMac over SSH; you decide, check, and own the demo.

## Your job in one line
**Make the whole thing work as one app on stage, with only real numbers, and win the 3 minutes.** Integrator · iMac backend · story.

## How to run things (the iMac)
| Do | How |
|---|---|
| See the app | iMac → Xcode → `~/parchi/app/Parchi.xcodeproj` → iPhone 17 Pro → ▶ |
| Jump to a step (rehearsal) | Scheme → Arguments → `-demoRoute confirm / plan / getItAll / track / planB` |
| Get teammates' latest code | They push to their branch → Claude merges after an iMac build passes |
| Start the iMac server (after Phase 1) | `cd ~/parchi/server && python3 server.py` → `http://<imac-ip>:8080/judge` |
| Reset before a run | Open `/reset` on the judge page, relaunch the app |

---
## Phase 0 — Setup + app skeleton ✅ DONE
SSH to the iMac, repo on MacBook + iMac + GitHub (private, 3 collaborators invited), ParchiCore 17/17 tests on the iMac, app flow Home → Confirm → Plan → Get it all → Track + Plan B on real prices (₹2,696.77; "Telma 400" caught).

---
## Phase 1 — Contracts + iMac server
**Why:** everything else plugs into this. One server on the iMac: **Temporal** runs the automations (free, self-hosted), a small Python API serves the app and the judge/shop/lab pages (see `docs/plan/12-V2-MASTER-PLAN.md` §4).

| Endpoint | Who calls it | In → Out |
|---|---|---|
| `POST /read` | App | JPEG (already blurred/cropped) → `{"medicines":[{"name","form","dose","duration"}],"tests":[...],"ms":1234,"model":"mock|parchi-7b-lora-v1"}`. Mock now; Singhal's model in Phase 4 |
| `POST /order` | App | plan lines → `{"orders":[{"seller","items","confirmation":"PX-4821","status":"placed","test":true}]}` |
| `GET /status` | App (every 2 s) | `{"orders":[...status per seller...],"shopReplies":[...]}` |
| `GET /judge` | Judge's phone/laptop | Big buttons: **Cancel Truemeds**, **Out of stock**, **Late** |
| `GET/POST /shop/<id>` | Shopkeeper (teammate's phone) | Form: price per item, "available", "ready by" → stored, shows in the app |
| `POST /reset` | You | Back to the start state |
App side: `ReaderClient` and `OrderClient` with **Mock / Live** in Settings, so the demo never depends on the server.
**Done when:** judge taps Cancel → Plan B sheet in the app within 2 s; a shop reply updates the pin within 2 s; reset works.
**You:** agree the `/read` JSON with Singhal (2 min, send him this table); open `/judge` on your phone once to test.

---
## Phase 2 — Real local data: Muradnagar + Meerut
| Task | Detail | Output |
|---|---|---|
| Places | Apple Maps search (chemist, pharmacy, medical store, Jan Aushadhi, lab, pathology) around **KIET (28.7524, 77.4990)** and **Meerut** centre; add OpenStreetMap extras; keep name, lat/lon, phone, distance | `engine/places/muradnagar.json`, `meerut.json` (dated) |
| **Phone survey** (one teammate, 30 min) | Call 5–8 chemists from the list: "Namaste, what is the price of Dolo 650 strip of 15 / Pan 40 / Telma 40 / Glycomet SR 500 / Azithral 500 / Montair LC? Any discount? Can you keep them ready?" Write name, time, prices, discount, delivery | `docs/research/evidence/shop_calls_24oct.csv` → prices labelled "called 24 Oct" |
| Demo parchis (3) | (1) the real 6-medicine + 4-test basket, (2) a short acute one (fever: 3 medicines + CBC) for the "Fastest" story, (3) one with an **H1** medicine (pick from the official Schedule H1 list, G.S.R. 588(E)) to show the "buy in person" badge | `engine/scenarios/*.json` |
| Fees | Online fees as published; **Blinkit fees from you**; unknown fee shown as "fee unknown", never ₹0 | updated scenarios |
| H1/X badge data | Small salt list from Schedule H1 / X | `engine/catalogue/schedule_h1_x.json` |
**Done when:** every price on screen has a source chip and a date; the map shows real Muradnagar shops.
**You:** choose the 3 demo parchis; send Blinkit fees; assign the caller.

---
## Phase 3 — Merge the team's work
**Branches:** `ui/antara`, `capture/aditya`, `ai/singhal`. Nobody pushes to `main` directly; Claude merges only after the iMac build passes.
| Check | When | Pass |
|---|---|---|
| **Check 1** | after Phase 2 | Share → mock read → confirm → plan (list + map) on Antara's screens |
| **Check 2** | before Phase 4 | Real photo → blur → `/read` (mock or real) → plan → test order → judge Cancel → Plan B → approve |
**You:** tell teammates the merge times; check each merged build on the iMac yourself.

---
## Phase 4 — Plug in the real reader
Singhal hands over the MLX model + `/read`. Point the server at it; measure the median seconds per parchi on 20 images; set the fallback switch: trained 7B → 3B → untrained → phone-only read + confirm.
**Done when:** a real handwritten photo is read on the iMac and the time is shown in Settings → "How accurate is Parchi?" with Singhal's measured numbers.
**You:** decide which model goes on stage, from his table (rule: it must beat the untrained model on MIRAGE-100).

---
## Phase 5 — Evidence
| Evidence | How | For the deck |
|---|---|---|
| **Survey** | Google Form from `docs/verification/survey-kit.md`; send the WhatsApp text **now** | n, % doctor-linked shop, % couldn't read, % 2+ places, % late/cancelled, % would use |
| **Usability (SUS)** | 5 people at the venue, 4 tasks, `docs/verification/usability-SUS-kit.md`, score with `sus_score.py` | "SUS X (n = 5)", taps to finish vs QuickPill |
| **ChatGPT test** | Same parchi in ChatGPT: reads it, can't order, book, see local prices or watch for a cancel. Screen-record | 15-second clip |
| **Shop calls** | Phase 2 | "We called 6 chemists near KIET" |

---
## Phase 6 — Deck + demo script
**Slides (one idea each, every number with a source line):**
1. **Parchi** + the one line
2. **Problem:** ₹1,030 at MRP vs ₹826 online vs ₹189 Jan Aushadhi; 16–29% of bad reviews = late/cancelled; legible prescriptions are an Article 21 right (P&H HC 2025)
3. **Who:** caregiver / elderly / in-a-hurry; ~400 crore consultations a year; Muradnagar + Meerut first
4. **Live demo**
5. **How it works:** phone → blur → our model on the iMac → engine → plan (diagram)
6. **The AI:** our generator (difficulty-matched to real handwriting), hand-copied real data, 7B LoRA on the DGX, before → after on 100 real parchis; blur 98.3%
7. **What's new (adopt → modify):** Plan B (payment failover), Cost to Complete (anti drip-pricing), brand–strength check (cheque idea), doctor memory (WHO P-drugs), Ask nearby shops + pickup
8. **Competitors:** QuickPill reads as well as frontier AI (89.7%), but no tests, no local shops, no Plan B
9. **Trust + law:** not a medical device (CDSCO §5.2), never swaps brands, H1/X in person, "How we rank", DPDP consent
10. **Impact + next:** cost ₹0.23/user/month after launch (estimate), more cities, referral model
11. **Team**

**Demo script v2 (3:00)**
| Time | Beat |
|---|---|
| 0:00 | Hook: messy real parchi. "₹1,030 at the doctor's shop, ₹189 at Jan Aushadhi. Nobody tells you." |
| 0:20 | Share from WhatsApp → name blurs on screen |
| 0:40 | Confirm: "Telma 400 doesn't exist: 20 / 40 / 80?" → one tap |
| 0:55 | Plan **List**: options cheapest → most expensive, full price, trips |
| 1:10 | Plan **Map**: price pins on real Muradnagar shops |
| 1:25 | **Ask nearby shops** → teammate (as shopkeeper) replies on a phone → pin updates live, "ready by 6 pm" |
| 1:50 | Get it all → test orders + lab slot |
| 2:05 | **Judge presses Cancel** → Plan B → approve |
| 2:25 | ChatGPT clip: it reads, but can't do any of this |
| 2:40 | Close: 4 measured numbers + "How we rank: price, time, trips. Nobody pays for position." |

---
## Phase 7 — Freeze + rehearse
- **Freeze:** after this, bug fixes only.
- Bug bash: every screen at the largest text size, dark mode, VoiceOver on the main flow.
- **3 clean rehearsals from reset**, each under 3:00: (1) normal, (2) Wi-Fi off (phone-only read + saved plan), (3) with the judge's Cancel and a shop reply.
- Record a 2:30 backup video (say it's recorded if you use it).
- **No known bug in the main flow at submission** (the NETRA lesson).

## Phase 8 — Submit
- [ ] Final build runs on the iMac simulator from a clean launch
- [ ] `main` tagged `v1.0-hackathon`; README updated
- [ ] Deck PDF + backup video
- [ ] Every deck number has a source line
- [ ] Submitted with 1 h spare

---
## Decision rules (decide without waiting)
| If… | Then… |
|---|---|
| Server can't be reached from the phone on venue Wi-Fi | Demo on the iMac simulator (localhost); judge page on a laptop on the same Wi-Fi |
| Model not ready when Phase 4 starts | Ship the best row from Singhal's table; phone-only read + confirm as last resort |
| A teammate's branch breaks the build | Don't merge; Claude fixes or reverts; never demo an unbuilt change |
| A number has no source | It doesn't go on a slide or a screen |
| Behind schedule | Cut: lock-screen tracking → Hindi → Care. Never cut: read, confirm, plan list+map, Ask nearby shops, Get it all, Plan B, blur |
| Phone survey gets < 3 answers | Show MRP with "shops may give 0–10% off" and say how many we called |

## Team sync points (in order)
| Sync | What |
|---|---|
| Kick-off | Survey sent, caller assigned, Singhal on DGX, frontend on competitor teardown |
| Check 1 | Core flow on the team's screens |
| Check 2 | V1 done end to end |
| Model decision | Singhal's numbers → stage model |
| Check 3 | V2 complete |
| Freeze | Bug fixes only |
| Rehearsal 3 | Final run before submit |
