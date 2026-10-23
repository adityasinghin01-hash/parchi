# V2 server modules (S2b): reliability (A1), refill (A6), true price (A7)
Each module exposes `register(app, get_temporal, get_install_id)`; pass `api.get_temporal` and `auth.require_install`
(tests pass their own dependency). Wiring into `api.py` and `worker.py` is not done here (those files are not edited):
```python
import reliability, refill, true_price
for m in (reliability, refill, true_price): m.register(app, get_temporal, auth.require_install)
# worker.py: workflows=[OrderWorkflow, *refill.WORKFLOWS]
```
Own SQLite tables live in `v2_db.py` (same `PARCHI_DB` file, CREATE IF NOT EXISTS, created on first use).

- Reliability: `score = (ok + 4) / (total + 5)`, a neutral 0.8 prior (a new seller is never ranked perfect, one failure is not fatal).
  Area = pincode or city, lower-cased. Outcomes: `ok|delivered` count as ok; `fail|cancelled|outOfStock|late|sampleRejected` as not ok.
  `GET /reliability?area=` (install key); `POST /judge/reliability/record` `{area,sellerID,outcome}` (admin key).
  `rank_with_reliability(sellers, scores, weight)`: sellers `{sellerID, cost}`; adjustedCost = cost * (1 + weight * (1 - score)).
- Refill: `POST /refill/watch` `{items:[{name,quantity,dosesPerDay|"1-0-1"}], startDate}` -> 201 `{refillID, daysLeft, runsOutOn, refillDueAt, items}`.
  `GET /refill/{id}/status` -> `{refillID, state: waiting|due|done|cancelled, refillDueAt, dueFiredAt}`.
  Extra: `POST /refill/{id}/done|cancel` (409 if already finished). Medicine names are not sent to Temporal.
  Time scale from env `PARCHI_TIME_SCALE` (same meaning as orders/shop/lab: waits are MULTIPLIED, 0.01 = 100x faster; refill used to divide, fixed in K23); task queue from `PARCHI_TASK_QUEUE`.
  "Delete everything" (`POST /reset`) terminates the install's running refill watches in Temporal (`refill.cancel_watches`).
- True price: `POST /orders/{orderID}/paid` `{sellerID, paidPaise, itemsPaise?, pincode}`; `GET /true_price?seller=&pincode=`
  -> `{sellerID, pincode, reports, enough, medianExtraPaise}`; null until 3 reports that include `itemsPaise`.
  One report per (order, seller); only the same install may replace it. No name/phone stored.
