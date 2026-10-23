# Orchestrator step 1

The supplied brief is the approved design. No commits; all changes stay in server/.

1. Write database, API, and Temporal acceptance tests before implementation.
2. SQLite owns install keys, order ownership, unique placements, unique audit sequences,
   and approvals. Activities run SQLite work in threads and retry at most five times.
3. The workflow serializes a signal inbox and seller deadlines in one deterministic
   loop. Parallel initial placement activities are the only parallel mutations.
   Signals never wait on activities, so approvals cannot interleave with a transition.
4. Validate the phone's proposal without calculating a replacement plan: preserve
   unaffected lines, account for every failed item, and use known candidate sellers.
   Initial sellers includes unused replacement candidates; only plan sellers are placed.
5. API derives stable order IDs from install plus idempotency key. SQLite reserves
   ownership before start; replay always attempts the same Temporal workflow ID with
   duplicate reuse rejected. Reset marks orders deleting before terminating them,
   drains pending activities, then cascades SQLite deletion. No seller API is called.
6. Add launch/stop scripts and an isolated real-server worker restart check.
7. Verify syntax, available unit tests, shell syntax and workflow sandbox preparation;
   time-skipping and restart integration runs belong on the iMac.

Nothing-available approval closes the failed seller as cancelled, stores approval,
advances the version, and leaves the current plan unchanged. Already active/delivered
replacement sellers are not placed again. Replacement sellers that failed, rerouted,
or were cancelled cannot be reused in this step. All placements are Test orders.
