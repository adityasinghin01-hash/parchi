# KIRO_REPORT_S2a: shop-ask + lab-booking server (Phase 3)

Files (all new; no existing file edited, no commit): `p3_db.py`, `shop.py`, `shop_workflows.py`, `lab.py`, `lab_workflows.py`, `tests/test_shop.py`, `tests/test_lab.py`, `P3_README.md` (mount/worker/reset steps).
Test run on the iMac: `63 passed, 1 warning in 1.06s` (tests/test_shop.py + tests/test_lab.py). Whole suite there: `174 passed, 1 warning in 2.84s`.
Covered: first reply wins/others not_needed, noReply + nextGroup + `next`, double/late/closed/incomplete replies, XSS escaping, lab confirm/propose/decline, fasting reminder 21:00 IST, lab noReply at 30 min, chase at reportDueAt+6h, judge sample_rejected/phlebotomist_late -> `seller_event` on a fake order handle.

Assumptions:
- SQLite is the truth for replies/states (first reply wins inside BEGIN IMMEDIATE); workflows own timers and are signalled afterwards (signal failure is logged, the reply is never lost). Status endpoints read SQLite only.
- A complete reply with every item "not available" still wins (contract says first complete reply). Claude may want to change that.
- Shops in state no_reply can still answer late; after a win or after `closed`, replies get 409. `closed` = last group silent (or 60 min after noReply with no tap on `next`).
- `next` is allowed any time while waiting and shops remain (409 otherwise); earlier groups become no_reply.
- Lab: propose -> state `confirmed` with the new slot, fee, note "Lab proposed another slot" (contract has no accept step). `sample_rejected` -> state `rejected`, note "Sample rejected". reportDueAt = judge `collected` body `reportDueAt`, else slot + 24 h. report_due / report_chase_due are written by the workflow.
- Shop phone is accepted but not stored. Limits I chose: items 1..30, names 100 chars, bodies 32 KB. `orderID` on /lab/book must belong to the caller (else 422).
- Reply link base = `PARCHI_PUBLIC_URL` or the request base URL.
- Form "Ready by" is `<input type=time>` read as today in IST (tomorrow if more than 1 h past).

Not done / unverified:
- Not mounted: api.py's `POST /shop/{shop_id}` and `POST /lab/{lab_id}` 501 stubs shadow `/shop/ask` and `/lab/book` until removed (see P3_README.md). Worker lists and the `/reset` hook (`p3_db.delete_install`) are for Claude to wire.
- Not run against the real dev server or a real phone browser; pages not viewed on a device. Auth is only covered by one smoke test of the default `auth.require_install`.
