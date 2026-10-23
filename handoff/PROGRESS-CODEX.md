# Codex continuation — 24 Oct 2026

**Scope changed by user ~02:48 IST: 30-minute DEMO BLOCKERS ONLY. Full S1-S10/A1-A7 closure is deferred; see DEMO-30-MIN-PLAN.md and DEMO-DEFERRED.md.**

Recovered Claude session da0537c9-ee5b-44c1-bc13-56b1ed7e0391 and read the handoff. User explicitly asked this session to continue Claude's work. Preserve dirty work and data; no git mutations, paid APIs, or external messages.

| Task | Status |
|---|---|
| S1 received-byte cap | DONE |
| S2 true-price placement | DONE |
| S3 component recovery | DONE |
| S4 input allowlists | DONE |
| S5 history/inactivity bounds | DONE |
| S6 refill horizon | DONE |
| S7 secure deletion | DONE |
| S8 K30/K31 completion | IN PROGRESS |
| S9 fuzz/concurrency | PENDING |
| S10 server review | PENDING |

## Verification log
- Fresh baseline outside sandbox: 427 passed in 31.01s. Historical server baseline: 427 passing. Initial sandbox run could not bind local ports/start Temporal (375 passed, 51 errors, 1 failed); rerun with local networking started.
- A1 app/engine verification delegated to a Codex worker (not an actual Kiro worker). Report: REPORT-A1.md. No Kiro CLI work process found locally or on iMac. Claude CLI remains open at its session limit. iMac has running API/worker stacks on 8000, 8025/8026, 8031; these are services, no xcodebuild/pytest job observed before continuation.

- S1: chunked/false Content-Length regressions failed 4/4 on original code (422 vs expected 413); small streamed order passed. Bounded pure ASGI pre-parser guard fixes them. Focused API/photo suite: 44 passed. Full suite running to S1-tests.out.

- S1 full suite: 432 passed in 29.46s.
- S2: both unrelated/unplaced seller regressions failed before fix (200 vs 422). Existing true-price fixtures now create real placements. Focused 22 pass; full suite 434 passed in 29.80s. Live A7 already reports against its actual delivered seller.

- S3: both missing-component repros failed before (healthy API prevented worker restart and vice versa). Both now pass; startup independently starts missing API/worker and verifies API + local PIDs + workflow/activity pollers; reader must report HTTP health. Original overlapping S3 full run stalled and was interrupted; subsequent S4 full run verifies these changes.
- S4: private-marker input/signal tests both failed before. Added allowlists before Temporal start AND before signalling (cleaning only workflow memory would leave raw signal history private fields). Workflow cleaning guarded by clean-proposal-v1. Focused 25 pass; full suite 438 passed in 30.04s.
- S5: baseline proved 55 individual ignored audit rows, and no expiry after 8 days. Added 50-row budget plus one flood audit, seven-day scaled failure/approval expiry under bounded-proposal-wait-v1. Test helper now recognises expired as closed (otherwise cleanup tried terminating a completed workflow). Verification in progress.

- S5 full suite: 440 passed in 30.88s.
- S6: exact overflow plus >366-day, upper-date and lower-date cases all reproduced errors/wrong acceptance. Supply limited to 366 days; arithmetic errors mapped to 422. Focused refill suite 43 passed, full suite 444 passed in 30.59s.
- S7: confirmed raw SQLite retained a unique home-collection address after reset AND a WAL checkpoint. Enabled secure_delete on each connection and explicit WAL truncate at reset; API no longer claims success if checkpoint busy. Regression asserts marker present before reset and absent from DB/WAL immediately afterward. Focused tests green; full suite pending.

- S7 full suite 445 passed in 30.37s.
- S8 existing K30/K31 targeted suites: 77 passed. Judge login/docs/timer/proposal/history code exists; live proof pending until app UI releases iMac. Review found approval claims can block a fresh proposal after commit-time reroute rejection without a version increment. Regression/fix in progress.

- Demo scope: Plan B same-version reproposal lock reproduced (409 instead of 200), fixed with proposal-scoped atomic active claim plus separate retry receipts. Approval/proposal/K30 tests: 43 passed. Read-only review found legacy receipt migration gap, deferred for fresh-reset demo.
- App/engine combined final verification: engine 152 passed; app unit 118 passed/1 skipped; UI 25 passed/1 skipped; SimulateCancel 5/5. Checkout probe skip was internet preflight. K24 full journey passed twice. App manual reader-help preservation fix has red/green regression proof.

- Final demo server suite: 452 passed in 31.93s. Final server synced without data/delete; independent worker/API readiness passed. New build e2e: 3 loops, 72 checks in 21s; shop/lab 11/11. Live privacy initially failed only its exact count of four delete requests: persistent rehearsal tombstones correctly add earlier caller histories (returned eight); caller-row deletion and second-install isolation checks passed. Harness now accepts additional prior caller histories while still explicitly proving A's four current histories disappear and B's stay. Rerun pending.

- Final browser smoke over directly reachable iMac Wi-Fi 10.110.220.139: 85/85 passed in 27s (S1 Plan B, S2 shop, S3 lab, S6 judge login/session). Earlier Ethernet endpoint failed; switched runtime reply links to Wi-Fi. Browser fixture now names each intended new booking with a distinct key, and computes SameSite assertions from the actual BASE host. No product guard weakened.
- Final live history-erasure check stopped at scope cutoff after caller DB deletion/second-install preservation passed; background histories remain an open gate. Real timer live table deferred. Full S9 fuzz and S10 review remain incomplete.
