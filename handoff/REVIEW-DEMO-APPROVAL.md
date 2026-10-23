# Urgent read-only demo approval review

Reviewed `server/approve_guard.py`, `tests/test_approval_reproposal.py`, relevant API/workflow decision code and existing K30 tests. No code edits, full test runs or iMac operations.

## Finding

**MED — existing successful approval keys lose replay after upgrade.** `approve_guard.setup` creates `approve_receipts` empty and adds the proposal column, but does not migrate existing keyed `approve_claims`. `replay` now reads only receipts. A pre-upgrade successful keyed approval whose plan advanced returns 409 instead of its original 200 (falls through `is_claimed`). In-memory SQLite schema probe reproduced: one legacy claim survives setup, zero matching receipt rows. New test creates only fresh-schema approvals, so misses migration. Preserve old claim keys as legacy receipts during schema migration (consider pending/in-flight ambiguity explicitly). This does not establish duplicate placement and does not block a fresh reset demo.

## Concurrency / double-order assessment

- New proposal ID replaces the same-version claim, allowing the intended reproposal after commit-time rejection; equal IDs still compete through one atomic SQLite upsert. Release includes proposal ID, so an old failure cannot directly delete a different newer claim.
- API `send_signal` independently snapshots and validates plan/proposal, and workflow `on_decision` validates again; no concrete double placement bug found in this short review.
- Caveat, not reproduced: overwriting by *any different* proposal ID is not monotonic. A delayed old snapshot can replace a newer claim; API recheck should reject its stale decision, but claim arbitration may briefly permit extra signal attempts. Workflow validation remains the decisive safety barrier. Current regression uses a fake handle and serial requests; it proves the unlock path, not mixed-generation concurrency or actual fulfillment.
- Existing claim-key unique index remains scoped to order/key, while receipts retain old keys after a claim is replaced. This matches fresh replay tests; ambiguous accepted-signal/crash-before-receipt behavior remains the pre-existing distributed-acknowledgment limitation.

Demo recommendation: proceed with fresh-order live Plan B smoke; migration compatibility is a follow-up unless preserving already-approved pre-upgrade demo orders matters.
