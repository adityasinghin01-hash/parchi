# Bugs found by job KR (24 Oct)
ID | screen | steps | what happened | severity
---|---|---|---|---
KR-1 | Confirm | Home "Try the sample" or -demoRoute confirm on the fe-kr tree | ConfirmView (FE2's file) does not show `AppModel.readNote` yet, so on this branch the sample is not labelled on Confirm. FE2 has the banner in its own branch; must be verified after merge | P0 until FE2 merges (sample-as-real)
KR-2 | Judge scan page | /judge/scan/read with the reader failing | `scan_page.py` still answers plain 502/503 without `code` (outside my brief: only the `/read` handler). Admin-only page, wording only | P2
KR-3 | Capture (Live) | reader fails with cap_reached / bad_key / not_configured on a printed parchi | the on-phone reader is still tried first (brief: reader unavailable -> on-phone); if it reads lines, Confirm opens with a notice "The lab reader did not read this photo, so this phone read the printed text itself." The specific reason (e.g. spending limit) is only in that generic notice | P3
KR-4 | Capture | CapturePreviewView notice after an on-phone read | the notice is set but the sheet closes immediately, so the patient never sees it (pre-existing behaviour) | P2
KR-5 | Manual edits on the sample | setQuantity/editLine on a demo line with a changed value | the line gets a new id and is priced from the catalogue MRP (intended: no demo price for a different amount), so the total changes. Demo total Rs 2,696.77 unchanged when nothing is changed or Telma corrected to 40 (tested) | P3 (by design, note for demo)
