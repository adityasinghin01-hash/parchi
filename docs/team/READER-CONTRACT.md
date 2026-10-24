# Reader contract: what the app sends to `POST /read` and what it expects back
Today the reader behind `/read` is `server/reader_claude.py`: the processed picture goes from the lab server to **Anthropic's Claude API** (model `claude-opus-5-5`), with a hard spend cap in `server/data/reader_spend.json`. Anthropic's own terms apply to that copy (how long Anthropic keeps it is not verified by us, so the app does not state it).
The app never sends the original photo. On the phone it first TRIES to pixelate the patient's name, age, phone and address (`app/Parchi/Support/Capture/PIIBlur.swift`), shows the result, and asks the user to check it. Only that processed JPEG is sent, and only when at least one area was hidden or the user ticked "I checked: no name, phone or address is visible". This is a best effort, not a guarantee: measured on our own samples (`docs/research/10-dataset-training-verification.md`) names were hidden on 98.3% of 300 synthetic parchis and 12/12 real photos, phone numbers on only 46.0% (23/50), and 7.1% of medicine lines were over-blurred. The whole page goes to the server, not a crop of the medicine part. Numbers are not shown in the app.

**Request** `POST http://<iMac>:8000/read`, header `X-Install-Key`, `multipart/form-data` with one file field **`image`** (`image/jpeg`, up to 2 MB; the app downscales to at most 2,000 px on the long side, JPEG quality 0.7, and sends a `Content-Length`; a chunked upload without one gets 411, a larger body 413; every other route keeps a 1 MB limit). The server (`server/api.py`) checks the key, size and type, then forwards the file unchanged to your reader at **`PARCHI_READER_URL`** (set it before `bash run.sh`; example `http://localhost:9000/read`) as the same multipart field `image`, **60 s timeout** (the app waits 65 s; the Claude reader's own deadline is 50 s). It never logs the image and does not write it itself. Multipart parsing may spool an upload over 1 MB to the server's temp folder for the length of the request (deleted automatically).

**Your reader returns** HTTP 200 JSON:
```json
{"lines": [
  {"kind": "medicine", "name": "Telma", "strength": "40", "quantity": 30, "schedule": "1-0-0"},
  {"kind": "test", "name": "HbA1c"}
]}
```
- `kind`: `"medicine"` (default) or `"test"`. `name`: the written brand or test name, as read (no guessing, no substitution). `strength`: digits and unit as written ("40", "500 mg"), omit if absent. `quantity`: tablets/units if written. `schedule`: as written ("1-0-1", "OD", "BD", "TDS").
- Return the lines in page order. Unreadable lines: leave them out; never invent a medicine. An empty `lines` array is shown to the user as "found nothing".
- Errors: every failure answer is JSON `{"detail": "...", "code": "<code>"}`. The app shows a distinct message for each code and NEVER shows the sample parchi in place of a failed read:

| code | HTTP | when | app retries? |
|---|---|---|---|
| `not_configured` | 503 | no Anthropic key, `PARCHI_READER_URL` unset, or the reader service is down | no |
| `cap_reached` | 503 | our ledger cap, or Anthropic's own spend limit (HTTP 400 "You have reached your specified ... usage limits", or 429 `enforced_spend_limit_reached`); never retried upstream | no |
| `bad_key` | 502 | Anthropic answered 401/403 | no |
| `reader_error` | 502 | 5xx / 529 / connection error after one retry, other 4xx, refusal, bad JSON | yes |
| `timeout` | 504 | the reader or Anthropic took too long | yes |
| `slow_down` | 429 + `Retry-After` | more than 6 `/read` requests in 60 s from one install key (in memory, sliding window) | after the wait |

  A network failure on the phone is shown as "Can't reach the Parchi lab server" (`offline`); no other failure uses that text. After any reader failure the app first tries the on-phone reader (Apple Vision + the printed-line parser, `app/Parchi/Support/Reader/`, printed parchis only, nothing leaves the phone). If it reads nothing, the app shows the failure with explicit choices: Try again (when it can help), Type the medicines in (Confirm with an empty list), and in Mock mode Use the sample parchi (Confirm then shows "Sample parchi, not your photo"). Measured on 259 synthetic printed parchis: recall 98.0%, precision 99.3%, nothing invented; real printed parchis and handwriting are not claimed.
- Cost (estimate, fixed ₹97 per USD, env `PARCHI_INR_PER_USD`): measured on 5 real calls about 2,500 input + 250 output tokens, $0.015 and 5.8 s per scan; `max_tokens` 2000; worst-case reservation per call Opus $0.07 / Sonnet $0.04 / Haiku $0.005.

The app then checks each medicine against the catalogue (brand and strength), asks the user to confirm doubtful lines, and plans. Plans need prices: today prices exist only for the demo basket (catalogue MRP for any other medicine is plan gap U7).
