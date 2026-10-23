# Phase 8: The locked idea (23 Oct 2026, ~13:00 IST)
Labels: **[M]** measured · **[V]** sourced · **[J]** judgement · **[A]** assumption. Every number here is already backed in files 01–08.

## 1. The idea in 4 lines
1. Share or scan the paper parchi. The patient's name is blurred on the phone.
2. Parchi reads every medicine and test, checks each one is a real product, and asks only about doubtful lines.
3. It shows **one plan for the whole parchi** across the nearby chemist, Jan Aushadhi, 10-minute apps, online pharmacies and labs, with the **full price up front** (fees and trips included).
4. One tap hands every item to the seller or lab. If anything fails, **Plan B** re-routes only that item.

**One-line pitch:** *"ChatGPT tells you what's written. Parchi gets the whole parchi done, at the full price you'll actually pay, and stays with it until it's done."*

## 2. Users
| Persona | Who (precise) | Today | Pain, with evidence | What Parchi gives |
|---|---|---|---|---|
| **P1 Caregiver** | 20–35, smartphone-first, handles a parent's monthly BP/sugar medicines and quarterly tests; the parchi arrives on WhatsApp | Buys at the doctor's shop at MRP, or retypes items into 1mg, then a lab app | Same basket: MRP ₹1,030 vs ₹826 online (−20%) vs ₹189 Jan Aushadhi (−82%) [M]; 2–3 apps; fees only visible at checkout [M] | Share from WhatsApp → plan in seconds → one tap |
| **P2 Elderly patient** | 60+, Hindi-first, low digital confidence | Hands the parchi to the clinic's chemist | Can't read the handwriting (2–25% of Indian prescriptions illegible; 24.41% poor handwriting in one Gujarat OPD [V]); legibility is now an Article 21 issue (P&H HC, Aug 2025) [V] | Hindi UI + read-aloud, large text, **Parchi Pass** to show any chemist |
| **P3 Acute, in a hurry** | Student or young worker with fever: 5-day antibiotic + CBC | Doctor's shop, or a 10-minute app | Delay/cancellation = **16–29%** of bad pharmacy-app reviews [M] | "Fastest" toggle, Plan B if it's late |
| Counter side: **local chemist** | Neighbourhood pharmacy | Guesses the handwriting | Misreading risk; brand swaps are unlawful [V, CCI] | A typed, patient-confirmed list (Parchi Pass) |

**Scale:** about **400 crore consultations a year** in India [V, Praxis 2021, file 00]. Every one ends with a parchi.

## 3. Every feature: need → why → 24-hour decision
| # | Feature | Need | Why (evidence) | 24 h |
|---|---|---|---|---|
| F1 | Share from WhatsApp | Parchis travel as WhatsApp photos | WhatsApp-style shrinking doesn't hurt reading [M] | **Build** |
| F2 | In-app scanner | Paper in hand | VisionKit, free | **Build** |
| F3 | On-phone name/phone blur | Privacy before upload | DPDP; a chatbot gets the whole photo [V] | **Build** (test ≥95%) |
| F4 | Reader: phone for printed, our model for handwriting | Patients can't read it | Apple Vision 26% on handwriting, ≥80% on printed; frontier model 82% [M] | **Build** |
| F5 | Brand–strength check | Catch "Telma 400" | Cheque cross-check idea; built, tested [M] | **Built** |
| F6 | Doctor memory | Same doctor, same brands | WHO P-drugs [V]; built [M] | **Built**, show once |
| F7 | Confirm with photo crop | Model still wrong ~13% of the time | 87% precision [M] | **Build** |
| F8 | Cost to Complete plan (Cheapest / Fastest / No trips) | "Where do I go and what will I really pay?" | Fees appear only at checkout [M]; drip pricing banned 2023 [V] | **Build** (engine built) |
| F9 | "Ask your doctor" Jan Aushadhi card | Biggest saving, but no swapping | Equivalent for 57% of medicines, −82% on the basket [M]; swaps unlawful [V] | **Build** |
| F10 | Get it all (hand-off; sandbox for auto) | One action, not 10 searches | Sites block bots; PharmEasy's terms ban automation [V/M] | **Build** |
| F11 | Plan B | #1 complaint | 16–29% of bad reviews [M]; engine built [M] | **Built**, wire to UI |
| F12 | H1 / X badge: "buy in person with the original parchi" | Legal safety | Schedules H1/X, draft e-pharmacy rules [V] | **Build** (small salt list) |
| F13 | Parchi Pass (QR + typed list) | Any counter, no integration | ABDM Scan & Share pattern [V] | **Build** |
| F14 | "How we rank" screen | Trust + 2027 e-commerce rules | Rule 5(3)(f), G.S.R. 789(E) [V] | **Build** (static) |
| F15 | Calendar slot, dose reminders, refill countdown | After-buying care | EventKit / local notifications, free [V] | Should |
| F16 | Hindi UI + read-aloud | P2 | iOS Hindi voice [V, check on device] | Should |
| F17 | Shop Quote by WhatsApp | Local prices aren't online | wa.me free [M] | Stretch |
| F18 | Lock-screen tracking (Live Activity) | Glanceable status | Local updates, no paid account [V] | Stretch |
| — | Family profiles, App Attest, Sign in with Apple, push, Siri, live price refresh, AI phone call | — | Paid account or paid API, or terms risk (file 07) | **Cut** (roadmap) |

**Never cut:** F1–F4, F7, F8, F10, F11. **Cut order if late:** F17 → F18 → F16 → F15.

## 4. Minimum inputs
| Input | Required? | Taps |
|---|---|---|
| Share or scan the parchi | Yes | 1–2 |
| Confirm the list (+ fix flagged lines) | Yes, for safety | 1 (+1–2) |
| Location | Asked once (or pincode once) | 0 after the first time |
| Preference | Default "Cheapest" | 0 |
| "Get it all" | Yes | 1 |
| Payment | In the seller's own checkout, not in Parchi | — |
| Approve Plan B | Only if something fails (or auto under a cap) | 0–1 |
| **Total** | **3 decisions, about 5–7 taps** vs ≈12+ taps for medicines only on QuickPill [M] | |

## 5. Novelty and innovation (adopt → modify), final
| Tier | Idea | Adopted from | Our change | Proof we'll show |
|---|---|---|---|---|
| 1, we create | **Synthetic Indian prescription dataset + generator** | MIRAGE (IIT Bombay) released only 100 real samples [V] | Open generator: real brands from 1.18 lakh, Indian layouts, Hindi, phone + WhatsApp effects | Dataset card + samples + before/after numbers |
| 1 | **Catalogue-constrained reading** | Trie decoding in generative retrieval; lexicon OCR [V] | The reader can only output a real Indian product + real strength | Fake names/strengths = 0; recall measured |
| 1 | **Doctor memory** | WHO P-drugs (1994) [V] | Learned per doctor from confirmed scans | Second scan from same doctor: fewer flags |
| 2, we improve | **Plan B** | Juspay payment failover [V] | For medicines and lab slots, only failed items move | Live: judge presses cancel |
| 2 | **Cost to Complete** | Supply-chain landed cost; Davaio cart total [V] | Whole parchi: medicines + tests + fees + trips; the anti-drip-pricing price | Real basket ₹2,697 vs MRP route [M] |
| 2 | **Brand–strength check** | Bank cheque words-vs-figures [V] | Brand ↔ strength must be a real product | 17 tests pass [M] |
| 2 | **Parchi Pass** | ABDM Scan & Share QR (6.64 crore tokens) [V] | Patient-held typed list for any chemist/lab | Shown at a mock counter |
| 2 | **Schedule-aware routing** | Drugs Rules H1/X | Automatic in-person badge from the parchi | H1 item in the demo parchi |

**Novelty line:** *"No public product we found reads an Indian parchi against the real product catalogue and that doctor's usual brands, then plans and re-routes the whole parchi. We built the open dataset to train it."*
**Innovation line:** *"Today a pharmacist reads it by hand and calls you (1mg, PharmEasy); comparers price online medicines only (QuickPill 4 sellers, MediSaathi 7); nobody re-routes a failed order (16–29% of bad reviews). Parchi reads in seconds, plans everything with the full price up front, and re-routes failures by itself."*

## 6. 24-hour build plan (Fri 24 Oct 15:00 → Sat 25 Oct 15:00)
**Roles** (map names yourselves): **R1 App UI** · **R2 Capture & privacy** · **R3 Model & server (iMac)** · **R4 Engine, data & pitch**.
**Ready before 15:00 (prep, disclosed):** ParchiCore engine (built), real-price scenarios (built), trained/zero-shot model + benchmark (step d), survey results, Blinkit fees, iMac check.

| Clock | Hour | R1 App UI | R2 Capture & privacy | R3 Model & server | R4 Engine, data & pitch |
|---|---|---|---|---|---|
| 15–16 | H0 | Xcode project, design tokens, navigation | App Group, share-extension target | mlx-vlm server up on the iMac, health check | Add ParchiCore package, load scenario JSON |
| 16–19 | H1–3 | Home, Reading, Confirm screens (mock data) | VisionKit scanner, share-in from Photos/WhatsApp | `/read` returns JSON for 3 test images; catalogue snap | Plan screen bound to the planner (3 toggles) |
| 19–20 | H4 | **Check 1:** share → mock read → confirm → plan | | | |
| 20–24 | H5–8 | Plan, Get it all, Track screens | Blur + crop; on-phone read for printed; H1/X badge | Sandbox sellers/lab with a "cancel" button; confirmation numbers | Plan B wiring, hand-off links, Jan Aushadhi card, "How we rank" |
| 00 | H9 | **Check 2:** real photo → iMac read → plan → sandbox order → Plan B | | | |
| 00–04 | H9–12 | Care screen, Hindi strings, Dynamic Type, VoiceOver labels | Parchi Pass QR, Calendar, reminders | Latency to ≤10 s; benchmark numbers into "How accurate" screen | Deck v1, demo script, numbers from measured files only |
| 04–06 | H13–14 | **Bug bash → feature freeze 06:00** | | | |
| 06–08 | H15–16 | Sleep in shifts; stretch (F17/F18) only if everything is green | | | |
| 08–11 | H17–19 | **3 rehearsals from reset** (one offline, one with injected failure); fix demo-flow bugs only | | | |
| 11–13 | H20–21 | Backup screen recording; 3-person SUS at the venue if allowed | | | |
| 13–15 | H22–23 | Buffer + submission | | | |

## 7. Demo script v2 (3:00)
| Time | Beat | On screen | Proves |
|---|---|---|---|
| 0:00 | Hook | Real messy parchi (4 medicines incl. one H1, + 2 tests). "Same basket: ₹1,030 at the doctor's shop, ₹826 online, ₹189 Jan Aushadhi. Nobody tells you." | Problem [M] |
| 0:20 | Share from WhatsApp | Lines light up; **name blurs** | UX, privacy |
| 0:40 | Confirm | One flagged line with its crop + 3 real options → 1 tap; "Telma 400 doesn't exist: 20/40/80?" | Safety, novelty |
| 0:55 | Plan | "Everything ₹X · ready by 6 pm · 0 trips". Flip to Fastest. Jan Aushadhi card: "ask your doctor". H1 badge | Innovation, legal |
| 1:25 | Get it all | Hand-off + labelled sandbox order + lab slot → Calendar | One-stop |
| 1:45 | **Plan B live** | Judge presses "cancel" on the sandbox seller → "+₹X, by 7 pm. Approve?" | Innovation |
| 2:05 | Airplane mode | Printed parchi still reads on the phone | Feasibility, privacy |
| 2:20 | ChatGPT beat | Recording: ChatGPT reads it fine, can't order, can't watch for a cancel | Not a wrapper |
| 2:40 | Close | 4 measured numbers: accuracy on 100 real Indian parchis · 6 taps vs 12+ · ₹ saved · 0 trips. "How we rank: price, time, trips. Nobody pays for position." | Credibility, trust |

## 8. Scores (verified today vs if built and tested)
| Criterion | Verified | If built | Change since file 06 | Why |
|---|---|---|---|---|
| Problem | 8.5 | 9.0 | — | Basket measured; survey still missing (HackIIITD gap) |
| Innovation | 7.5 | 8.5 | — | Plan B + Cost to Complete built in the engine, not yet in the app |
| Novelty | 6.5 | 8.0 | — | Dataset + constrained reading not built; head-to-head incomplete |
| Technical | 8.0 | **8.8** | −0.2 | Free Apple account: no App Attest, push, Siri |
| Feasibility | **7.5** | 8.5 | +0.5 verified | Legal path clear (not a medical device), hand-off path real, ₹0 |
| UI/UX | 6.5 | 9.0 | — | Needs SUS ≥80 |
| Demo | 7.5 | 9.0 | — | Needs 3 clean rehearsals |
| Security | 7.0 | **8.8** | −0.4 | App Attest + Sign in with Apple unavailable |
| **Average** | **7.4** | **8.7** | | Real-judge calibration: earlier Parchi scored 21/30 = 7.0 at HackIIITD |

## 9. Risks
| # | Risk | Likelihood | Hit | Fix | Owner |
|---|---|---|---|---|---|
| 1 | Our trained model isn't better than zero-shot | Medium | Technical −0.5 | Ship whichever measures best; show both numbers honestly | R3 |
| 2 | KIET Wi-Fi blocks phone → iMac traffic | Medium | Live read fails | Run Simulator and model on the same iMac (localhost); phone hotspot as backup | R3 |
| 3 | iMac RAM too small for the model | Low–Med | Slow or no read | 3B model in 4-bit ≈ 3 GB; check RAM before the event | R3 |
| 4 | Xcode or install rights missing on the lab iMac | Low (Aditya says fine) | Can't build | Check today; admin contact | R1 |
| 5 | Free provisioning (7-day profile, 3 apps) | Low | Can't install on phone | Simulator for the demo; install on a phone the night before | R1 |
| 6 | Blur misses a name | Medium | Security claim fails | Test ≥95% before the event (step e); fail closed: blur the whole header zone | R2 |
| 7 | Scope too big | High | Unfinished flow | Freeze at 06:00; cut order F17→F18→F16→F15 | R4 |
| 8 | Judges read it as "a ChatGPT wrapper" | Medium | Novelty | ChatGPT beat + Plan B live | R4 |
| 9 | Judges ask "do you earn from sellers?" | Medium | Trust | "How we rank" screen; affiliate disclosed, ranking ignores it | R4 |
| 10 | Prices are stale | Certain | Credibility | Every price shows "source · captured 23 Oct" | R4 |
| 11 | No user evidence (HackIIITD gap) | High now | Problem/UX | Survey + SUS kits (step e) before the event | Team |
| 12 | A known bug in the main flow at submission | Medium | NETRA-type loss | No-known-bugs rule; reset button; backup recording | All |
