# Lead plan: Aditya Singh (with Claude doing the coding on the iMac)
Locked 23 Oct 2026. H0 = when we start Phase 1.

## What your work actually is
You own **the whole thing working as one app on stage.** Three jobs:
1. **Integrator:** the app skeleton, the engine, the teammates' screens, the AI reader and the fake sellers must join into one flow that never breaks: share → read → confirm → plan → Get it all → Plan B → Care.
2. **The iMac "backend":** one small server on the iMac that (a) passes photos to Singhal's model, (b) pretends to be the sellers and labs ("Test order", confirmation numbers), and (c) has a **Cancel** button a judge presses to trigger Plan B.
3. **The story:** every number in the app and the deck is real; the deck, demo script, rehearsals, survey/usability evidence and the submission.

You decide and check. Claude writes and builds the code on the iMac over SSH and pushes to GitHub.

## Phases
| # | Phase | Hours | What gets built | Done when |
|---|---|---|---|---|
| **0** | Setup + app skeleton | done | SSH to the iMac, repo on both machines, ParchiCore in the app, 5 screens on real prices, Plan B sheet, `-demoRoute` jumps | ✅ builds on iPhone 17 Pro sim (commit fcd4cf1) |
| **1** | **Contracts + iMac server** | H0–H2 | (a) Reader contract with Singhal: `POST /read` → `{medicines[{name,form,dose,duration}], tests[], ms, model}`. (b) **iMac server** (Python standard library, nothing to install): `/read` (mock now, Singhal's model later), `/order` (Test order + confirmation numbers), `/status`, **`/judge`** web page with a big "Cancel Truemeds" button, **`/shop/<id>` reply form** (shopkeeper types prices + "ready by" time, which go live into the app), `/reset`. (c) App `ReaderClient` + `OrderClient` with a Mock/Live switch in Settings | Judge taps Cancel on a laptop or phone → Plan B sheet appears in the app within 2 s; reset restores the start state |
| **2** | **Real local data** | H2–H4 | (a) 2–3 demo parchis (one with an **H1** medicine from the official list, one with tests only). (b) **Muradnagar + Meerut** places: Apple Maps search (primary) + OpenStreetMap extras, saved as dated files. (b2) **Phone survey:** one teammate calls 5–8 chemists (numbers from Apple Maps) for the 6 demo medicines → real local prices labelled "called 24 Oct". (c) "Source · captured date" on every price. (d) Blinkit fees when you get them (fee shown as "unknown", never ₹0, until then). (e) H1/X salt list → badge | Plan screen shows only real, sourced numbers; H1 badge appears |
| **3** | **Merge the team's work** | H4–H10 | Pull Antara's screens and Aditya's capture/blur/Pass/Care into the flow; one shared design style; fix merge breaks; Integration **Check 1 (H4)** and **Check 2 (H9)** from the master plan | Real photo → (mock) read → plan → order → Plan B, all from teammates' screens |
| **4** | **Plug in the real reader** | H10–H12 | Point `/read` at Singhal's model; time each read; fallback ladder (trained 7B → 3B → untrained → phone-only read + confirm) behind one switch | A real handwritten photo is read on the iMac; median seconds per parchi measured |
| **5** | **Evidence** | H0 send · H12 analyse · H15–H17 test | Survey sent at H0 (form + WhatsApp text in `docs/verification/survey-kit.md`); results → 5 numbers for the deck. **Usability test** with 5 people at the venue → SUS score. **ChatGPT test** (5 min, record it) | Survey n ≥ 20; SUS measured; ChatGPT recording saved |
| **6** | **Deck + demo script** | H8–H14 | 8–10 slides: problem (measured basket, court/NMC), live demo, how it works (system diagram), the AI (before/after numbers), what's new (adopt → modify table), competitors, legal/privacy (blur 98.3%, not a medical device), team. Demo script v2 (3:00) | Every number has a source line; one slide per idea |
| **7** | **Freeze + rehearse** | H15–H21 | Feature freeze at H15; bug bash; **3 clean rehearsals from reset** (one with Wi-Fi off, one with the judge's Cancel); 2:30 backup screen recording | Zero known bugs in the main flow (the NETRA lesson) |
| **8** | **Submit** | H21–H24 | Final build on the iMac + simulator, repo tagged, deck PDF, recording | Submitted with 1 h spare |

## What you do yourself in each phase (Claude does the rest)
| Phase | You |
|---|---|
| 1 | Agree the `/read` contract with Singhal (2 min); test the judge page on your phone |
| 2 | Choose the 2–3 demo parchis; send Blinkit fees |
| 3 | Tell teammates when to push; check the merged app on the iMac |
| 4 | Decide which model goes on stage, from Singhal's numbers |
| 5 | Send the survey; run the 5-person test; record the ChatGPT test |
| 6 | Approve the slide story; practise the 3-minute script |
| 7 | Run the rehearsals; say "freeze" |
| 8 | Submit |

## Risks you watch
| Risk | Fix |
|---|---|
| Phone can't reach the iMac on venue Wi-Fi | Demo on the iMac simulator (localhost); judge page opened on the iMac or your MacBook on the same Wi-Fi |
| Model not ready by H12 | Fallback ladder; the demo still runs on the phone-only read + confirm screen |
| Teammates' code breaks the build | Merge only through the iMac build; Claude fixes; never demo an unbuilt change |
| Stale or invented numbers | Every number comes from `docs/research/evidence/` or a cited source |
| Running out of time | Cut order: Shop Quote → lock-screen tracking → Hindi → Care |
