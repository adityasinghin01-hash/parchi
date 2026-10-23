# Focused Kiro lab fixes — integrated by Codex

Kiro Sonnet session ran ~7 minutes and was stopped by the coordinator for integration and final verification. No active Kiro editor remains.

- Booking retry: every replay ensures the same workflow exists with REJECT_DUPLICATE; existing/completed execution is accepted. A failed/ambiguous start retains its committed SQLite booking and returns 503, so retry can recover it.
- Expiry/collection race: honor authoritative collection state and reconcile report timers. Coordinator corrected callers to preserve old replay behavior and avoid spinning when no state changed.
- Coordinator replaced two week-long tests that did not isolate the actual race with a controlled expiry-activity result test. The original give_up code was separately reproduced returning expired after a committed collection; the regression verifies collected state and exact two/eight-hour report/chase deadlines.
- Existing FakeTemporal adapter now models duplicate-start rejection. The old test expecting deletion after an uncertain start now verifies retained booking and successful retry; this is the intentional recovery contract, not a disabled check.
- Final focused lab suites: 49 passed in 11.25 s (test_demo_lab_recovery, test_r8_lab_idempotency, test_lab, test_r8_lab).
- Full server and live results are recorded in DEMO-RESULT.md when complete. Never used real patient photos or a paid reader API.
