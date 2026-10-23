# PARCHI — project context (read this first: humans and AI assistants)
Team TessaNova · Swift Developers Night 2.0 (KIET Apple CoE, 24 h) · budget ₹400 · no paid API · free Apple developer account.

## What we build
**Problem:** patients get a handwritten parchi they can't read; nobody tells them where to buy or the real price, so they pay MRP at the doctor-linked shop. Same 6-medicine basket: **₹1,030 MRP · ₹826 online (−20%) · ₹189 Jan Aushadhi (−82%)** [measured 23 Oct]. After paying, 16–29% of bad pharmacy-app reviews are about late/cancelled orders [measured, 9,000 Play reviews].
**Solution:** iPhone app. Share/scan the parchi → name blurred on the phone → medicines + tests read → checked against 2.46 lakh real products → ONE plan for the whole parchi (nearby chemist, Jan Aushadhi, 10-min apps, online, labs) with the full price up front → one tap hand-off → **Plan B** re-routes only failed items.
**Pitch line:** "ChatGPT tells you what's written. Parchi gets the whole parchi done, at the price you'll actually pay, and stays with it until it's done."

## Current plan
**Target = V2** (V1 milestone on the way; recommendation engine = V3). Read `docs/plan/12-V2-MASTER-PLAN.md` (also .docx/.pdf). Automation = Temporal (free, self-hosted on the iMac) + a Python worker and API in `server/` (SQLite for app data); not LangChain/LangGraph/n8n/Zapier. V3 (after V2) = recommendation engine + automatic cart via partner APIs.

## Scope now
**Cities:** Muradnagar + Meerut (extend later). **GUI is the star** (mentor, 23 Oct): Apple Maps price map + lists sorted cheapest → most expensive; local market shops included with MRP until they reply to **Ask nearby shops** (WhatsApp + reply form + pickup time).

## System
Phone (SwiftUI): capture → Apple Vision read (en+hi) → privacy blur → printed & confident? done : send cropped medicine area to the iMac → ParchiCore (brand–strength check, doctor memory, planner, Plan B) → screens.
Lab iMac (M4, 16 GB, Xcode 26.2): our fine-tuned Qwen2.5-VL (MLX 4-bit) behind `POST /read` + sandbox sellers/labs.
Training: KIET DGX (1×A100 40 GB) / Jarvis (A100 80 GB, emergency) / Kaggle (free T4 backup).

## Hard rules (legal + honesty)
- Never sell, hold money, swap brands, or recommend tests/doses (keeps us out of medical-device + pharmacy rules). Generic savings = "ask your doctor".
- H1/X medicines: "buy in person with the original parchi".
- Every number on screen or in the deck must come from a measured file in `docs/research/evidence/` or a cited source. No invented numbers.
- MIRAGE-100 and the 12 web photos are **test only**; web photos and patient images never go into this repo.
- Sandbox orders are always labelled "Test order".

## Key measured numbers
| What | Number |
|---|---|
| Apple Vision on real handwriting (MIRAGE-100) | 26.3% recall, 12.8% precision |
| Frontier model, blind, 16 parchis | 82.1% recall, 87.3% precision |
| QuickPill vs frontier, same 12 parchis | 89.7% vs 89.7% recall (QuickPill reads at frontier level) |
| Untrained Qwen2.5-VL-3B (MLX, M1), first 30 MIRAGE | 13.6% recall, 26.2% precision, ~20 s/parchi |
| Synthetic generator difficulty (messy 2/3) | Apple Vision 26.9% vs real 26.3% |
| Patient-name blur | 98.3% hidden (300 new synthetic), 12/12 real web photos |
| Planner on real prices | cheapest whole plan ₹2,697, Plan B +₹166; engine suite 129 Swift tests pass, server 199 pytest pass (re-run 23 Oct 23:05) |
| Jan Aushadhi equivalent exists | 55.7% of 327 MIRAGE medicine mentions with the app's matcher (the Python heuristic says 57.2%); use 55.7% |

## Who owns what
| Person | Owns | Doc |
|---|---|---|
| Aditya Singh (lead) | ParchiCore in app, iMac server, sandbox + Plan B, deck, demo | docs/team/Lead-Aditya-Singh.md |
| Aditya Singhal | ALL AI + data + Drive: generate, train, test, export to iMac | docs/team/AI-Aditya-Singhal.md |
| Antara Gupta | Screens (Home, Confirm, Plan, Get it all, Track/Plan B, Care, Settings) | docs/team/Frontend-Antara-Aditya.md |
| Aditya | Capture, blur, Parchi Pass, Calendar/reminders, Hindi | docs/team/Frontend-Antara-Aditya.md |

## Repo map
`docs/plan` locked plan · `docs/research` phases 00–10 + `evidence/` (raw measured data) · `docs/team` role docs · `docs/verification` SUS + survey kits · `docs/legal` source excerpts · `engine/ParchiCore` Swift engine (`swift test`) + `engine/scenarios` real-price data · `ai/` generator, Kaggle notebook, benchmarks, drafts · `privacy/` blur tool + scorer · `data/README.md` how to get datasets (no data committed).
