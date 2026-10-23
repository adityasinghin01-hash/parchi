# Bug log (append only; every agent adds a row, nobody deletes)
Policy: record everything, fix only P0 inside the 2-hour windows (see INTEGRATION-PLAN.md section 0). P1–P3 are fixed after hands-on, then measurements are re-run once.
P0 = crash, dead end in the demo path, wrong price/total, false claim on screen, data loss/leak, spend-guard failure, sample shown as a real scan. P1 = wrong but recoverable. P2 = cosmetic/layout. P3 = polish idea.

| ID | Time | Found by | Screen / area | Steps and what happened | Sev | Status |
|---|---|---|---|---|---|---|
| B001 | 24 Oct 04:3x | Claude | reader | Reader misread "Clobsave F" as "Ceobsave F" on a messiness-2 synthetic parchi (catalogue check should catch it) | P1 | open (verify in D3) |
| B002 | 24 Oct 05:30 | Claude (T6 probe) | Checkout Assistant | Tata 1mg shows "Switch to generic alternative / Not now" right after Add; inside Parchi's in-app browser a patient could swap the brand (Parchi never swaps brands) | P1 | open: add a reminder banner in the Checkout Assistant (FE3 area) |
| B003 | 24 Oct 05:30 | Claude (T6 probe) | Checkout Assistant | Truemeds sends a guest from /cart back to a pincode prompt; Netmeds Add control not found; Apollo cart address unknown. Guest cart/checkout path cannot be assumed | P2 | open: needs the human run in CHECKOUT-MANUAL-TEST.md |
