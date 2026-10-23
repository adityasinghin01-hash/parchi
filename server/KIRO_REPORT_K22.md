# KIRO_REPORT_K22: phone scan-and-read test page
**Built**
- `server/scan_page.py` (new, an `APIRouter`): `GET /judge/scan?k=<admin key>` and `POST /judge/scan/read` (header `X-Admin-Key`).
- The page has a warning banner, "Take a photo" (`accept="image/*" capture="environment"`), "Choose from gallery" (no `capture`), a preview, and a canvas downscale (long side at most 2000 px, JPEG 0.7, shrinks further if it is still over 2 MB).
- It also has a "Read this parchi" button, a result table (kind, name, strength, quantity, schedule), the time in seconds, "Nothing was found", the exact error text, and "Try another photo". Touch targets are at least 48 px.
- No external requests. The script has no `innerHTML`; names go in via `textContent`. A CSP (`default-src 'none'`) is set. The key is read by the script from its own address, never written into the page.
- `/judge/scan/read` forwards like `/read` (same types, 2 MB limit, 20 s timeout, `READER_TRANSPORT`) and returns the reader's JSON plus `ms` and `reader` (host:port only). It answers 503 `reader not connected` (the page says "The reader is not connected yet."), 415, 413, 502. Nothing is logged or stored.
- `server/api.py`: 3 small edits. A `PHOTO_PATHS` tuple makes the 2 MB body limit and the 411 rule apply to `/judge/scan/read` as well as `/read`, plus an `include_router` line. `/read` behaves as before. `README.md` has the 4-line note at the top.
**URL**: `http://<iMac LAN IP>:8000/judge/scan?k=<admin key>` (`ipconfig getifaddr en0`/`en1`; same Wi-Fi).
**Tests**
- `tests/test_scan_page.py` (16 new tests): 401 without or with a wrong key (an app key is not enough), 503 with no reader, success shape, 413 (by size and by declared length), 415, 411, 502/503 from the reader, XSS name returned as data, served JS has no innerHTML or external URL, nothing in logs, nothing written to disk, `/read` unchanged.
- Whole `server/tests`: 257 passed. This includes tests other agents added.
- Real browser (Playwright Chromium, 390x844, Android UA and touch): `/tmp/k22/e2e.py` printed "E2E OK".
  - Uploaded `printed_photo.jpg` through `#cam` against a stub reader on 127.0.0.1:9055. The table showed both lines (the `<b>` in a name stayed literal text) and "Read in 0.7 s".
  - A 4000x3000 photo reached the reader as a 2000x1500 JPEG of 1.0 MB.
  - A wrong key gave "Error 401: invalid admin key". With no reader the page said "The reader is not connected yet." There were no external requests and no JS errors.
  - Server logs hold no key.
- Screenshots: `/tmp/k22/1_initial.png`, `2_preview.png`, `3_result.png`, `4_error.png`, `5_not_connected.png`.
**Limits**
- No blur on this page, so the patient's name is sent to the reader. Use test parchis only.
- Plain http and `capture`: I could NOT test this on a real Android phone, and headless desktop Chromium ignores `capture`.
  - From what I know of the platform (not verified here): `<input capture>` hands off to the phone's camera app and is not the secure-context camera API. So it should work over plain http on Android Chrome.
  - Some browsers or iOS versions may still show only the gallery or file picker. The fallback is "Choose from gallery", which uses the same pipeline.
- The table is cramped at 390 px: headers wrap mid-word. The admin key is in the URL, over plain http.
**Notes**
- `server/.venv` was empty when I started. K19 and K20 were installing into it, so I waited and then ran the tests.
- No `~/pw-venv` existed, so I created `~/pw-venv2` (Playwright and Pillow). `playwright install chromium` removed an older `chromium_headless_shell-1243` from `~/Library/Caches/ms-playwright`. If K20 needs it, re-run `playwright install`.
- I did not touch the running server and nothing is committed. The e2e used temporary uvicorn instances on ports 8022/8023 with a temp DB, now stopped.
