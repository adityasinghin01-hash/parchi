# SPEC 2: Personal recommendation engine (V3 in the master plan). Owner: Aditya Singhal. Folder: `teammates/recommendation-engine/`
Read `README.md` in this folder first (working agreement + iMac rules). Background: `docs/plan/12-V2-MASTER-PLAN.md` section 11 ("Personal recommendation engine: learns each user's habits").

## Why (the user need)
Parchi already builds good whole-parchi plans (cheapest, fastest, fewer trips, reliability-weighted). But people differ: one patient will pay Rs 100 more to have it delivered today, another walks to the shop for the lowest price, a third was burnt by a cancelled order and wants only sellers that delivered before. Today everyone gets the same default ranking and no explanation of the trade-off. The engine ranks the plans for THIS person, says in one plain sentence why, shows what they give up, and quietly learns from the person's own choices. The person can always pick any plan ("Choose myself").

## Where it sits
`Planner (Swift, on the phone)` -> candidate plans -> **Recommendation engine** -> ranked list + reasons -> screen. The planner stays the only thing that decides what is a valid plan. The engine never invents a plan, never changes what is bought, never touches medical content. The person's profile lives ON THE PHONE (history never goes to the server); the engine is a pure function so the lead can port it to Swift (`ParchiCore/Recommender.swift`) or call your service when online. Your Python version is the reference and the test oracle.

## Hard rules for this engine (tested, see Safety tests)
1. No medical advice: no doses, no tests, no brand swaps. "Ask your doctor about a Jan Aushadhi equivalent" is a flag the planner already produces; you pass it through, you never add one.
2. A plan that uses a substitute is never recommended unless the input says the doctor approved substitutes.
3. Unknown stays unknown: an unknown price/fee/stock is never treated as 0 or as "good". Such plans carry a warning and cannot be rank 1 while a fully priced complete plan exists.
4. An incomplete basket is never ranked as if complete (it goes to `excluded` or is clearly marked partial).
5. No seller pays to change a ranking: seller identity is NOT a feature; only measurable facts about the plan and this user's own history are. There must be no field called commission/referral/sponsored anywhere.
6. No personal data: no name, phone, address, medicine names or report content in the profile, the logs or the output (plan lines use item ids). Delete-everything on the phone wipes the profile.
7. Every number in the output appears in the input or is computed from it; every recommendation can be explained from its own score parts. No LLM in v1.

## Contract (JSON; write JSON Schemas in `schemas/` and Pydantic models)
`POST /recommend`
```json
{"candidates": [{"planId": "A", "label": "cheapest", "totalPaise": 269677, "readyMinutes": 95, "trips": 1,
   "complete": true, "missingItemIds": [], "usesSubstitute": false,
   "fees": {"knownPaise": 4000, "unknownCount": 0},
   "lines": [{"itemId": "dolo", "sellerId": "doctorshop", "channel": "localChemist", "pricePaise": 3212,
              "priceSource": "mrp|online|shop_quote|catalogue", "seenDate": "2026-10-23", "exact": true}]}],
 "profile": {"version": 1, "weights": {"price": 0.45, "time": 0.20, "trips": 0.15, "reliability": 0.20},
             "choices": 0, "sellerStats": {"medkart": {"delivered": 3, "failed": 1}},
             "prefs": {"urgent": false, "doctorApprovedSubstitutes": false}},
 "context": {"nowIso": "2026-10-24T10:00:00+05:30", "areaId": "muradnagar", "visitCostPaise": 5000,
             "reliability": [{"sellerID": "medkart", "score": 0.90, "orders": 14}],
             "shopsNotYetAsked": 3, "planBPenaltyPaise": 16574}}
```
Response: `{"ranked": [{"planId", "rank", "score", "headline", "reasons": [{"factor", "text"}], "tradeoffs": [{"vs", "text"}], "confidence": "high|medium|low", "warnings": [], "expectedTotalPaise"}], "excluded": [{"planId", "why"}], "nextActions": [{"kind": "ask_shops|refresh_price", "text"}], "engineVersion": "x"}`.
`POST /learn` `{profile, shown: [candidate features], recommendedPlanId, chosenPlanId, outcome?: {delivered: bool, failedSellerIds: []}}` -> `{profile}` (stateless: the caller stores the new profile). `GET /health`.
`planBPenaltyPaise` default 16574 (Rs 165.74) is the ONE measured value: the demo basket's Plan B extra in `docs/team/DEMO-RUNBOOK.md` step 6 (a single measurement on sandbox data; say so in the README and expose it as a parameter). `reliability` is the server's `GET /reliability?area=` answer as it is (`[{sellerID, score, orders}]`, read-only).

## Algorithm (explainable first; keep it small)
1. **Filter**: apply rules 2-4 above.
2. **Expected total** = `totalPaise` + sum over sellers used of `(1 - p_seller) * planBPenaltyPaise`, where `p_seller` blends the area score from the server (weighted by its `orders`) with this person's history using a Beta prior (neutral 0.8, same as the planner: prior alpha 4, beta 1; add delivered/failed counts). This is how "cheapest" and "reliable" are put on one scale: a cheap seller who cancels often is not actually cheap.
3. **Features** per plan, scaled 0..1 across the candidates (higher = better): price (expected total), time (readyMinutes), trips (each visit also priced by `visitCostPaise`), reliability (product of `p_seller`). Freshness (price older than 7 days, the app's existing rule) is a WARNING, not a weight.
4. **Score** = sum of `weight_i * feature_i` with the person's weights (defaults above are ASSUMPTIONS: label them so; they are tuned only through the simulator below).
5. **Learning** (`/learn`): when the person picks a plan other than the recommended one, update weights with a pairwise logistic (Bradley-Terry) step on the feature difference (chosen minus each shown plan). Learning rate 0.15, pull toward the defaults (L2 0.5), clamp each weight to 0.05-0.70, renormalise to sum 1, no change until at least 3 recorded choices, at most 0.10 change in any weight per step. Delivery outcomes update `sellerStats` only. NO exploration: never show a worse plan to "learn"; learn only from explicit choices and real outcomes.
6. **Explain**: reasons are the two largest weighted advantages of this plan over the next one, each with real numbers ("Rs 112 more than the cheapest, but ready 2 hours sooner and 1 trip fewer"); tradeoffs state what the person gives up. Texts come from fixed templates (English now; Hindi keys ready). Confidence = high when the margin to rank 2 is large and the profile has 5+ choices, low when there are fewer than 2 complete candidates or warnings exist.
7. **nextActions**: `ask_shops` when shops have not been asked and a local MRP price could beat the best plan by more than the visit cost; `refresh_price` when a line is older than 7 days. Nothing else in v1 (refill reminders already exist in Care).

## What the person sees (plain words; the app team will use these)
A "Recommended for you" tag on one plan with ONE sentence of why, a line "What you give up", and a link "Choose myself". With no history the sentence says "Based on price, time and reliability" (not "for you"). The tag never replaces the full price or its source/date.

## Test candidate generator (for tests only; the real planner is Swift)
`candidates_from_scenario(path)` builds plans from `engine/scenarios/*.json` (`items`, `sellers`, `offers`, `preferences`): cheapest, fastest, fewest-sellers, each single-seller basket that is complete, and the plan after a seller fails (Plan B). Read `engine/ParchiCore/Sources/ParchiCore/Planner.swift` and reproduce its cost accounting (fees, visit cost, collection fee). Acceptance check: the cheapest plan for `real_basket_cheapest.json` totals exactly 269677 paise (Rs 2,696.77, the demo total; if your number differs, stop and write why in `NEEDS-LEAD.md`).

## Safety tests (property tests with `hypothesis`; all must pass)
Never ranks incomplete as complete; never recommends a substitute plan without approval; unknown price never rank 1 when a priced complete plan exists; same input gives same output (stable tie-break by planId); lowering one plan's total never lowers its rank; permuting seller IDs (identical features, no history) leaves the order unchanged; no key named commission/referral/sponsored is read; every number in `reasons` is traceable to input; schema rejects name/phone/address keys; banned medical words never appear in any generated text; +-1% price noise flips the top rank in at most X% of cases (measure X, report it).

## Evaluation (synthetic users: SAY SO in the results; no real-user claim)
Simulate 6 personas with hidden weights plus noise: price-first elderly, time-first worker, reliability-first (burnt before), pickup-lover near a shop, family arranger, low-data user. For each, 200 simulated parchis from perturbations of the three scenarios (prices, fees, one seller failing). Report for 0, 3, 5, 10, 20 recorded choices: top-1 agreement with the persona's true best plan, mean regret in rupees, and the same for two baselines (always cheapest; engine with default weights and no learning). Also report: explanation faithfulness (must be 100%), rank stability, runtime per request. Target to beat the baselines AND not to be worse than "always cheapest" on price-first personas; if it is worse, say so and why.

## End-to-end check on the iMac (`~/teammates/recommendation-engine/`)
1. Run the service on `127.0.0.1:8043`. 2. With `PARCHI_TEST_KEY` read the real reliability scores read-only: `GET http://localhost:8000/reliability?area=<area>` (use the area ids the server accepts; see `server/reliability.py`). 3. Build candidates from the three scenario files plus "seller cancelled" variants, call `/recommend`, check the safety invariants on every response. 4. Run the persona simulation through `/learn` over HTTP and save the learning curve (`learning_curve.csv`). 5. Show 3 worked examples (request, response, the sentence the person would see) in `RESULTS.md`. Never write to the demo server.

## Non-goals
Medical or dosing advice, brand substitution, automatic cart/partner APIs, an LLM, Zep or any server-side memory, seller commissions, anything that stores personal data.

## Acceptance
- [ ] Schemas + service + generator + simulator + property tests; all green; `RESULTS.md` with the numbers above and the three worked examples.
- [ ] Demo cheapest total = 269677 paise from your generator; Plan B variant recommends only sellers that did not fail.
- [ ] Every default weight, penalty and threshold is labelled "assumption" or traced to a measured file.
- [ ] README: three-command run; "Honest limits" (synthetic users only, weights are assumptions, no real-user accuracy yet, reliability data is sandbox data in the demo).

## Order of work
M1 contract + schemas + candidate generator + scoring without learning + safety tests. M2 reasons/tradeoffs + warnings + nextActions. M3 learning + simulator + evaluation. M4 service + iMac end-to-end + `RESULTS.md`. M5 (lead's call) port to Swift against your example pairs as golden tests.
