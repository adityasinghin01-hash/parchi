# KIRO_REPORT_K19: Claude reader (built and tested with a fake client; no key, no money spent, nothing committed)
Done on the MacBook (`Adityas-MacBook-Air-2`), not the iMac: `server/.venv` here was empty, so I installed `requirements.txt` + `anthropic==2.2.0` + `rapidfuzz` into it. On the iMac run `.venv/bin/pip install -r requirements.txt rapidfuzz` (rapidfuzz only for the eval script).

## Files
- New: `reader_claude.py` (service), `start_reader.sh`, `eval_reader_claude.py`, `tests/test_reader_claude.py` (31), `tests/test_eval_reader_claude.py` (1), `tests/stub_anthropic.py` (fake Anthropic upstream).
- Edited: `start_all.sh` (starts the reader only if a key exists, then exports `PARCHI_READER_URL` + `PARCHI_READER_TIMEOUT=75`), `stop.sh` (also stops the reader), `requirements.txt` (`anthropic>=2.2,<3`), `README.md` (reader lines).
- Also edited, beyond the brief: `api.py` and `scan_page.py` forwarded to the reader with a hard 20 s timeout, but Claude may take longer (reader allows 60 s + 1 retry). It is now `PARCHI_READER_TIMEOUT` (default 20, unchanged unless set). `tests/test_scan_page.py`: its log filter also ignores the `httpx2` logger (installing `anthropic` makes the test client log under that name; same test-client-only log).
- Schema choice: all 5 fields are required, `strength`/`quantity`/`schedule` are nullable; null/empty is dropped by the hygiene function, so the contract output omits them.
- HEIC: the API takes only jpeg/png, and converting would write the photo to disk. The bytes are sniffed: a "heic" label on jpeg/png bytes works; real HEIC bytes get 415. The app sends JPEG, so this should not occur.
## Tests (no network, no key)
- `pytest -q` whole `server/tests`: **251 passed** (the 203 plus K22's scan tests plus 32 new).
- Covered: contract shape, SDK call parameters (no temperature/top_p/top_k/thinking/tool_choice), hygiene rules, cap 30, refusal and max_tokens -> 502, invalid JSON/no text block -> 502, empty list, 415, 413 (exactly 2,000,000 passes), missing key = 503, key from env then file, retry once on 429/5xx/connection/timeout then success, retry once then 502, 4xx not retried, usage math per model, and a log-capture test proving no key, image bytes (raw or base64), model text, upstream error text or prompt appear in any log or output.
- Eval: refuses 7 images without `--yes-spend` (exit 2, zero calls), 5 images scored through `ai/score_rx.py` against the stub.

## Curl chain (stub upstream on :8199, reader :8100, API :8010, fake key)
```
$ curl -H "X-Install-Key: <key>" -F image=@p.jpg;type=image/jpeg localhost:8010/read     # server -> reader -> stub
{"lines":[{"kind":"medicine","name":"Telma","strength":"40","quantity":30,"schedule":"1-0-0"},{"kind":"medicine","name":"Glimy","strength":"4 mg","schedule":"OD"},{"kind":"test","name":"HbA1c"}]}  HTTP 200
$ curl localhost:8100/usage
{"calls":1,"inputTokens":1900,"outputTokens":120,"costUsd":0.01,"costInr":0.88,"inrPerUsd":88,...}
$ curl localhost:8100/health   {"ok":true,"keyConfigured":true,"model":"claude-opus-5-5"}
```
The stub saw `model claude-opus-5-5, max_tokens 4000, output_config {effort low, json_schema}`, `image/jpeg`, auth header present. `start_reader.sh` twice: second says "already running"; with no key: exit 3, nothing started. `stop.sh` stopped the reader. I did not run `start_all.sh` itself (no `temporal` binary on this MacBook); its hook is `bash -n` checked only.

## Steps for you (on the iMac)
1. `cd server && .venv/bin/pip install -r requirements.txt rapidfuzz`
2. `(umask 077; read -rs k; echo "$k" > data/anthropic.key)` (paste the key, Enter)
3. `bash stop.sh && bash start_all.sh`, then `curl localhost:8100/health` must show `"keyConfigured":true`.
4. `mkdir -p ~/parchi-data && rsync -a macbook:dev/parchi-research/data/mirage100/img/ ~/parchi-data/mirage100/` then the eval line from the README with `--limit 5` (about INR 7). Eval needs the medicine CSV (`--catalogue`, default `~/dev/parchi-research/data/medlex/indian_medicine_data.csv`).
## Cost per prescription (price table in the brief, not checked against Anthropic's site)
Assumption: ~1,600 image tokens (a 1000x1100 px page is ~1,450; the API shrinks to 1568 px) + ~500 prompt/schema = 2,100 in; ~600 out. Opus: $0.020 = **INR 1.8**; Sonnet: $0.010 = INR 0.9; Haiku: $0.0005 = INR 0.05 (INR = USD x 88). The eval's pre-run estimate uses 2,000 in / 400 out (opus INR 1.4/image). Real tokens are unmeasured: `/usage` will show them.

## Privacy wording that must change
`FirstRunConsentView.swift:68` says the picture "goes to our own computer (the Parchi lab server)". With this reader the photo is also sent from that computer to Anthropic's API (a third party, outside our control) to be read. Say so, plus: whatever name/phone the blur missed goes with it. Also in `READER-CONTRACT.md`, `DEMO-RUNBOOK.md`, JUDGE-QA ("prescriptions stay private", research doc addendum 23 Oct). Anthropic's retention terms were not checked by me. Risk: `127.0.0.1:8100` has no login; anyone with a shell on the iMac can spend the key.
