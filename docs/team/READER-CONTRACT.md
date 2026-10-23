# Reader contract: what the app sends to `POST /read` and what it expects back (for Aditya Singhal's model on the iMac)
The app NEVER sends an unblurred photo: it pixelates the patient's name, age, phone and address on the phone first (`app/Parchi/Support/Capture/PIIBlur.swift`) and sends only that JPEG.

**Request** `POST http://<iMac>:8000/read`, header `X-Install-Key`, `multipart/form-data` with one file field **`image`** (`image/jpeg`, up to 4 MB). The server (`server/api.py`) checks the key, size and type, then forwards the file unchanged to your reader at **`PARCHI_READER_URL`** (set it before `bash run.sh`; example `http://localhost:9000/read`) as the same multipart field `image`, 20 s timeout. It never logs or stores the image.

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
