# Bug log (append only; every agent adds a row, nobody deletes)
Policy: record everything, fix only P0 inside the 2-hour windows (see INTEGRATION-PLAN.md section 0). P1–P3 are fixed after hands-on, then measurements are re-run once.
P0 = crash, dead end in the demo path, wrong price/total, false claim on screen, data loss/leak, spend-guard failure, sample shown as a real scan. P1 = wrong but recoverable. P2 = cosmetic/layout. P3 = polish idea.

| ID | Time | Found by | Screen / area | Steps and what happened | Sev | Status |
|---|---|---|---|---|---|---|
| B001 | 24 Oct 04:3x | Claude | reader | Reader misread "Clobsave F" as "Ceobsave F" on a messiness-2 synthetic parchi (catalogue check should catch it) | P1 | open (verify in D3) |
