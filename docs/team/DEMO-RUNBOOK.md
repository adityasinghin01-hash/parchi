# Demo runbook (lead): start, show, reset, and what to do when something breaks
Everything below was run on the lab iMac on 23 Oct 2026 (see `docs/verification/EVIDENCE-23-OCT-2026.md`).

## Before the demo (5 min)
1. On the iMac: `cd ~/parchi/server && bash start_all.sh` (starts Temporal, worker and API if they are not up). Check `curl localhost:8000/health` -> `{"ok":true,"temporal":true}`. Temporal's own page: `http://localhost:8233`.
2. Keys live only on the iMac: `data/admin.key` (judge) and `data/sim_install.key` (app). Never paste them into chat or git.
3. Reset to a clean demo: `curl -X POST "localhost:8000/reset?scope=demo" -H "X-Admin-Key: $(cat data/admin.key)"`.
4. Phone/Simulator: open Parchi, Home > Developer > **Live**, URL `http://<iMac-ip>:8000` (iMac addresses: `ipconfig getifaddr en0` / `en1`), install key, **Test connection**. Mock mode needs none of this.
5. Judge page on a second screen: `http://<iMac-ip>:8000/judge?k=<admin key>` (LAN only; the key is in the URL, so do not screen-share the address bar).

## The 2-minute story (Live)
1. **Choose a photo** of the demo parchi. The FIRST time, the consent screen appears (read it aloud: we try to hide the details we can find, you must check the picture, the picture goes to our own lab computer in Live mode, photo copies are removed after 24 hours, Delete everything is in Settings); tap Agree. Then the preview shows what was hidden -> Use this photo. (With no reader connected the app says so and loads the demo parchi: say it plainly.)
2. Confirm: the doubtful line (Telma 400 vs 40) is asked, not guessed; the H1/X line says "buy in person with the original parchi".
3. Plan: one plan, full price up front (**List | Map** switch at the top: the Map shows live Apple Maps shops with price pins, tap a pin for the shop sheet with Call / Directions / Ask this shop; the map needs internet, the list still works), every price with its source and date ("Online, 23 Oct", "MRP, seen 23 Oct"), Smart Router chip ("Delivers about 9 of 10 ... Demo" in Mock; real counts in Live).
4. **Ask nearby shops**: pick 3, set a pickup time, send. On the second screen, open the reply link and answer as the shop (or use the judge page). The plan re-sorts with the shop's price ("Shop replied").
5. Get it all: Checkout Assistant walks seller by seller (the user taps Add to cart and Pay).
6. **The wow moment:** on the judge page press **Cancel** on one seller. Within about 2 seconds the Plan B sheet appears on the phone ("Truemeds cancelled 5 items. Plan B: Medkart + doctor's shop, +Rs 165.74"). Tap **Approve**: only the failed items move, everything else stays.

## If the reader cannot read a parchi (it is not connected yet)
On Confirm use **Add a medicine** (search by brand, pick the strength, set the quantity) and **Add a test**; each line has Remove. Any medicine in the catalogue then gets a plan at the catalogue MRP ("Catalogue MRP · check at the shop") with a Jan Aushadhi "ask your doctor" line. Tests are priced lab by lab below the plan and are not in its total.

## Before every rehearsal
`curl -X POST "localhost:8000/reset?scope=demo" -H "X-Admin-Key: $(cat data/admin.key)"` on the iMac. The order engine (Temporal) database was recreated on 23 Oct night (`server/data/temporal.db`): old rehearsal orders are gone, which is expected.

## If something breaks
| Symptom | Do this |
|---|---|
| Server/iMac unreachable | The app falls back to the demo by itself; the Plan B sheet still works on the phone (UI test `ServerDownUITests` passes with no server). Say "offline mode". |
| Temporal down | `bash start_all.sh` again (about 10 s). Running orders resume from their saved history. |
| Phone cannot reach `http://<iMac-ip>:8000` | Same Wi-Fi? Try the phone hotspot for both; `curl` the health URL from Safari on the phone. |
| 429 "rate limited" in the Developer panel | Wait 1 minute (120 requests/min per key). |
| Wrong data from earlier rehearsals | Step 3 reset. |
| App shows nothing for a shop/lab link | Set `PARCHI_PUBLIC_URL=http://<iMac-ip>:8000` and `bash run.sh` again so links use the iMac address. |

## Honest limits to say out loud if asked
- The reader model is not connected yet (`docs/team/READER-CONTRACT.md`): non-demo parchis cannot be planned until it is, and until catalogue MRPs are wired (plan gap U7).
- Checkout Assistant: 11 of 13 seller pages render in the in-app browser; login, add-to-cart and pay were not tested.
- No real iPhone run yet (`docs/team/REAL-IPHONE-RUN.md`); camera scanner and WhatsApp share are not built.
- Temporal keeps workflow history 24 h (item ids, prices, seller ids; no names or phones); "Delete everything" clears our database immediately.
