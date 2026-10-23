# Demo blocker checkpoint — 24 Oct 2026

User narrowed this pass to demo-blocking bugs, with a 30-minute verification window beginning ~02:48 IST. This is not full product acceptance.

## Fixed / integrated
- Plan B late-delivery reconciliation, replacement placement/item accounting, target recheck, complete item coverage and committed-fee accounting from Claude's interrupted work.
- Same-version fresh Plan B proposal can be approved after an earlier replacement becomes unavailable; one proposal still has one atomic approval claim, keyed retries retain their answer.
- Lab booking retries recover a missing Temporal workflow, retain committed rows after uncertain failures, and reject duplicate executions. A committed collection is preserved if an expiry activity races it; report/chase timers continue.
- Shop-round close and lab reply/reconcile fixes from the interrupted work.
- Manual medicine/test edits preserve the reader's unresolved lines.
- Retained server hardening: actual-byte request cap, workflow input field allowlists, true-price placement eligibility, independent API/worker recovery, refill overflow rejection, secure SQLite deletion.

## Fresh verification
| Layer | Result |
|---|---|
| Server full suite | 452 passed, 31.93 s |
| Engine | 152 passed |
| App unit | 118 passed, 1 measurement runner skipped |
| App UI | 25 passed, 1 checkout internet preflight skipped |
| Mock cancellation stability | 5/5 passed |
| K24 Track/Plan B/Care/settings journey | passed twice |
| Python data tools | 34 passed |
| Final live app Plan B | 3 consecutive loops, 72 checks, 21 s |
| Final live shop/lab | 11/11 passed |
| Reset SQLite rows / ownership | caller rows gone; other install intact/readable |
| Temporal history erasure | incomplete; deferred from demo-only scope |
| Final browser smoke (direct Wi-Fi) | 85/85 passed; judge/login, Plan B, shop replies, lab replies |

App evidence: REPORT-A1.md, local logs in a1-evidence/. Server and live command logs remain local. No paid reader calls, real purchases, patient-image uploads, or changes to keys/spend ledgers.

## Open / deferred
See DEMO-DEFERRED.md. Device/checkout/real-reader acceptance, broad fuzz and full accessibility matrices are outside the final demo-only scope. GitHub source checkpoint follows the verified demo gates. Asynchronous history erasure and the other deferred gates remain open.

Verified demo URL: http://10.110.220.139:8000 (Wi-Fi en1). Runbook includes the required PARCHI_PUBLIC_URL export; Ethernet en0 address was unreachable from MacBook. The final direct Wi-Fi browser run supersedes the earlier failed Ethernet/tunnel harness attempts. Browser booking helper now supplies distinct Idempotency-Key values for intentional new bookings; CSRF expected statuses follow the actual target host, while preserving order-unchanged/CORS/header assertions.
