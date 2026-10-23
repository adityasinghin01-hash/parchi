# Reader contract: what the app sends to `POST /read` and what it expects back (for Aditya Singhal's model on the iMac)
The app never sends the original photo. On the phone it first TRIES to pixelate the patient's name, age, phone and address (`app/Parchi/Support/Capture/PIIBlur.swift`), shows the result, and asks the user to check it. Only that processed JPEG is sent, and only when at least one area was hidden or the user ticked "I checked: no name, phone or address is visible". This is a best effort, not a guarantee: measured on our own samples (`docs/research/10-dataset-training-verification.md`) names were hidden on 98.3% of 300 synthetic parchis and 12/12 real photos, phone numbers on only 46.0% (23/50), and 7.1% of medicine lines were over-blurred. The whole page goes to the server, not a crop of the medicine part. Numbers are not shown in the app.

**Request** `POST http://<iMac>:8000/read`, header `X-Install-Key`, `multipart/form-data` with one file field **`image`** (`image/jpeg`, up to 2 MB; the app downscales to at most 2,000 px on the long side, JPEG quality 0.7, and sends a `Content-Length`; a chunked upload without one gets 411, a larger body 413; every other route keeps a 1 MB limit). The server (`server/api.py`) checks the key, size and type, then forwards the file unchanged to your reader at **`PARCHI_READER_URL`** (set it before `bash run.sh`; example `http://localhost:9000/read`) as the same multipart field `image`, 20 s timeout. It never logs the image and does not write it itself. Multipart parsing may spool an upload over 1 MB to the server's temp folder for the length of the request (deleted automatically).

**Your reader returns** HTTP 200 JSON:
```json
{"lines": [
  {"kind": "medicine", "name": "Telma", "strength": "40", "quantity": 30, "schedule": "1-0-0"},
  {"kind": "test", "name": "HbA1c"}
]}
```
- `kind`: `"medicine"` (default) or `"test"`. `name`: the written brand or test name, as read (no guessing, no substitution). `strength`: digits and unit as written ("40", "500 mg"), omit if absent. `quantity`: tablets/units if written. `schedule`: as written ("1-0-1", "OD", "BD", "TDS").
- Return the lines in page order. Unreadable lines: leave them out; never invent a medicine. An empty `lines` array is shown to the user as "found nothing".
- Errors: any non-2xx makes the server answer 502; if the reader is down the server answers **503 `{"detail":"reader not connected"}`** and the app falls back to the demo parchi with a clear message.

The app then checks each medicine against the catalogue (brand and strength), asks the user to confirm doubtful lines, and plans. Plans need prices: today prices exist only for the demo basket (catalogue MRP for any other medicine is plan gap U7).
