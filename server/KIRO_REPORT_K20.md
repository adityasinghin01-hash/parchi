# KIRO report K20: real-browser end-to-end (judge page, shop reply page, lab reply page)
Not committed. Script: `server/browser_e2e.py`. Re-run (outside the server venv, server up): `~/pw-venv/bin/python server/browser_e2e.py` (`--only 2,3` for some scenarios; exit 1 on any FAIL; output scrubbed of keys and reply tokens, checked: 0 occurrences).
Last run: `RESULT PASS: 101/101 checks, 24s` (twice in a row). Headless Chromium; judge desktop 1280x800; shop/lab pages mobile 390x844, Android user agent.

| # | Scenario | Result | Time | Evidence |
|---|---|---|---|---|
| 1 | Order + judge click Cancel + Plan B + approve + reload | PASS 12/12 | 2.3 s | click -> needs_proposal 1.1 s; proposal visible (awaiting_approval) 1.4 s after the click; reload shows `placed v2`, s1 rerouted |
| 2 | Shop ask incl. `map-<uuid>` + Devanagari map id; judge Reply click; shop link on phone | PASS 24/24 | 2.6 s | prices in paise, empty item = not available, total 43050, others not_needed, 2nd reply 409 (stale tab and API), phone form stored 36175 |
| 3 | Lab: 5 judge buttons by click, lab page on phone | PASS 22/22 | 8.1 s | reminder 2026-10-24T21:00+05:30 for a 25 Oct 08:00 slot (also after "propose another slot"); Late posting reached the linked order (needs_proposal) |
| 4 | Security | PASS 21/21 | 4.5 s | XSS in shop/item/lab/test names, address, ids, readyBy: shown as text, no dialog, no JS error, `window.__xss` unset; wrong/no key 401; `?k=` on JSON 401; reply pages CSP `default-src 'none'` |
| 5 | Robustness | PASS 21/21 | 5.9 s | 3 reloads while pending; 3 races (two shops) and 3 races (same link) in two tabs: exactly one wins; judge vs phone at once: one wins; 100-letter names, 40 KB post -> 413; Hindi renders exactly |
| - | Network audit (whole run) | PASS | | every browser request went to localhost (no external host) |

## Map-shop gap (K14)
A shop id `map-<uuid>` (and the app's real format `map-<letters>-<lat>-<lon>` with Devanagari letters, plus a phone number in the body) is accepted by `/shop/ask`, shows on the judge page, can be answered by Reply click, and its reply link works on the phone. No server problem found.

## Bugs found (3, all fixed, `server/shop.py` + `server/lab.py`, 3 new pytest)
1. Lab reply page: the "Another slot" datetime input stuck out of its card by 19 px at 390 px (seen in the screenshot). Fix: labels wrap, inputs `min-width:0`.
2. A phone reload of the thank-you page re-posts the form and showed "Could not send" although the reply was saved. Now 409 with "Your reply was already sent. Thank you." (English + Hindi); first reply untouched. Shop and lab.
3. A 100-letter shop name without spaces made the phone page 1200 px wide. Fix: `overflow-wrap:anywhere`.
Tests: `test_form_reposted_after_reply_says_already_sent_not_error`, `test_inputs_cannot_push_the_phone_page_sideways` (test_shop.py), `test_form_reposted_after_answer_says_already_sent_not_error` (test_lab.py). shop+lab files: 66 -> 69 pass.
Full suite last run: 278 passed, 4 failed. The failures are in other jobs' files (`test_reader_spend_cap`, `test_eval_reader_claude`, `test_reliability_auto`); in isolation only `test_eval_reader_claude::test_refuses_over_five_then_scores` still failed. Not touched by me. The "203" in the brief is out of date (other jobs added tests).

## Screenshots (6 PNG) in `docs/verification/browser/`
s1_judge_after_planb, s2_judge_after_reply (Hindi name), s2_shop_reply_mobile, s3_lab_reply_mobile, s4_xss_judge, s4_xss_shop_mobile. `.gitignore` already allows `docs/**/*.png`, so `git add -f` is not needed. No address bar, no keys. All 16 shots are in /tmp/k20.

## Environment notes
- This computer was a MacBook Air with no running server: I ran `pip install -r requirements.txt` into `.venv`, issued `data/sim_install.key` (chmod 600), started a Temporal dev server from the SDK's downloaded binary (`/tmp/k20tmp`, port 7233, `temporal` CLI is not installed), then `start_all.sh`.
- Other jobs edit `activities.py`/`workflows.py` while the stack runs: a stale worker failed with `module 'activities' has no attribute 'record_outcome'` and the order never reached Plan B. `bash stop.sh && bash start_all.sh` fixed it; I restarted twice. A browser run against a worker older than the code will fail scenario 1.

## Could not test
- Real phone browsers (Safari/Chrome on a handset), real Devanagari font availability on Android, the camera button, and reply links with the LAN IP (`PARCHI_PUBLIC_URL` unset: links say `localhost`). Chromium emulation only; no WebKit/Firefox run.
- The shop and lab pages have no free-text note field, so "XSS in a reply note" was tested through readyBy (the only free value) and all names/ids.
- The judge page was not tested at phone width. Rate limiting (429) under browser load was not exercised.
