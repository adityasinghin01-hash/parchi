**The claim is not supported.** Read-only review; no files modified. All integration/device repros below are **UNCONFIRMED**. Only isolated `/read` function probes ran with mocks; local FastAPI/Starlette dependencies were missing.

1. **HIGH — Zero redaction still passes.** [PIIBlur.swift:16](/Users/aditya/dev/parchi/app/Parchi/Support/Capture/PIIBlur.swift:16), [125](/Users/aditya/dev/parchi/app/Parchi/Support/Capture/PIIBlur.swift:125), [95](/Users/aditya/dev/parchi/app/Parchi/Support/Capture/PIIBlur.swift:95).  
   Vision can read medicines while missing the handwritten name; fallback hides recognized boxes only. Unsupported Hindi is silently skipped, and zero boxes remain “usable.”  
   **Repro:** English medicine text plus an unreadable handwritten/Hindi name; repeat with tiny images. Inspect preview and upload.

2. **HIGH — Header exemptions expose recognized PII.** [PIIBlur.swift:34](/Users/aditya/dev/parchi/app/Parchi/Support/Capture/PIIBlur.swift:34), [96](/Users/aditya/dev/parchi/app/Parchi/Support/Capture/PIIBlur.swift:96).  
   A patient line containing “Nagar,” “Road” or “Dr” escapes fallback. Finding any name label also disables that fallback globally.  
   **Repro:** Put unlabeled “Ravi Nagar” above “Tab Dolo”; inspect whether the name survives.

3. **HIGH — Upload contradicts consent.** [CaptureView.swift:43](/Users/aditya/dev/parchi/app/Parchi/Support/Capture/CaptureView.swift:43), [consent:62](/Users/aditya/dev/parchi/app/Parchi/Support/Phase4/FirstRunConsentView.swift:62), [api.py:312](/Users/aditya/dev/parchi/server/api.py:312).  
   Every usable Live photo uploads the full processed page; there is no medicine crop or local-reading confidence gate. Configured upstream destinations are unrestricted, although callers cannot directly select them.  
   **Repro:** Import clear printed text with margin markers; capture upload dimensions. Arbitrary configured-URL forwarding was **mock-tested**.

4. **HIGH — `discard()` does not release ongoing original-image work.** [PIIBlur.swift:20](/Users/aditya/dev/parchi/app/Parchi/Support/Capture/PIIBlur.swift:20), [CaptureSession.swift:17](/Users/aditya/dev/parchi/app/Parchi/Support/Capture/CaptureSession.swift:17), [CaptureView.swift:39](/Users/aditya/dev/parchi/app/Parchi/Support/Capture/CaptureView.swift:39).  
   Detached rendering retains the original after dismissal; completion can refill the shared preview. An ongoing reader request can also populate AppModel afterward.  
   **Repro:** Start a huge image or delayed reader, immediately close, then inspect memory/model state.

5. **HIGH — Erasure leaves personal models and tasks alive.** [EraseEverything.swift:24](/Users/aditya/dev/parchi/app/Parchi/Support/Phase4/EraseEverything.swift:24), [AppModel.swift:63](/Users/aditya/dev/parchi/app/Parchi/Model/AppModel.swift:63), [LabBookingModel.swift:75](/Users/aditya/dev/parchi/app/Parchi/Support/ShopLab/LabBookingModel.swift:75).  
   AppModel lines/plans, booking addresses and tasks have no erase handler. `loadReaderLines` also preserves the previous Live order/poller.  
   **Repro:** Read/book, delete, revisit screens; import another prescription while tracking an earlier order.

6. **HIGH — Calendar, notifications and clipboard survive.** [LabReminders.swift:25](/Users/aditya/dev/parchi/app/Parchi/Support/ShopLab/LabReminders.swift:25), [46](/Users/aditya/dev/parchi/app/Parchi/Support/ShopLab/LabReminders.swift:46), [ShopAskModel.swift:206](/Users/aditya/dev/parchi/app/Parchi/Support/ShopLab/ShopAskModel.swift:206).  
   Erasure removes none of these artifacts; calendar entries contain tests/address and reminders disclose tests.  
   **Repro:** Create each artifact, delete everything, inspect Calendar, notification requests and pasteboard.

7. **MED — “Up to 24 hours” is unenforced.** [ParchiApp.swift:9](/Users/aditya/dev/parchi/app/Parchi/ParchiApp.swift:9), [TempFileStore.swift:36](/Users/aditya/dev/parchi/app/Parchi/Support/Phase4/TempFileStore.swift:36), [Purge.swift:9](/Users/aditya/dev/parchi/engine/ParchiCore/Sources/ParchiCore/Purge.swift:9).  
   Purging requires launch/foreground entry; clock rollback extends retention. Only two folders are swept, using immediate-entry timestamps.  
   **Repro:** Leave suspended beyond 24 hours, roll clock backward, or place a photo outside swept folders.

8. **MED — Server reset has incomplete scope.** [api.py:293](/Users/aditya/dev/parchi/server/api.py:293), [refill.py:164](/Users/aditya/dev/parchi/server/refill.py:164).  
   Reset deletes database rows and terminates order workflows; it neither deletes Temporal histories nor cancels refill workflows or contacts the reader. Upstream retention is unverified.  
   **Repro:** Create order/refill, reset, inspect workflow history/status.

9. **MED — Mock mode falsely implies no previous server copy.** [ResetClient.swift:38](/Users/aditya/dev/parchi/app/Parchi/Support/Phase4/ResetClient.swift:38).  
   Switching Live→Mock suppresses reset and reports nothing was ever sent.  
   **Repro:** Place Live order, switch Mock, delete; inspect server.

10. **MED — Invalid reset replies count as success.** [ResetClient.swift:49](/Users/aditya/dev/parchi/app/Parchi/Support/Phase4/ResetClient.swift:49).  
    Any 2xx, including malformed JSON or `{"ok":false}`, becomes “deleted.”  
    **Repro:** Stub those responses; check displayed success.

11. **MED — Local deletion success is unconditional.** [HistoryStore.swift:128](/Users/aditya/dev/parchi/app/Parchi/Support/Phase4/HistoryStore.swift:128), [TempFileStore.swift:49](/Users/aditya/dev/parchi/app/Parchi/Support/Phase4/TempFileStore.swift:49), [HomeView.swift:47](/Users/aditya/dev/parchi/app/Parchi/Screens/HomeView.swift:47).  
    SwiftData/filesystem failures are swallowed; WebKit clearing is unawaited. Backend and non-`parchi.` defaults survive.  
    **Repro:** Inject deletion failures/delayed WebKit clearing; observe “Everything…deleted.”

12. **MED — Server upload can touch disk.** [api.py:310](/Users/aditya/dev/parchi/server/api.py:310), [38](/Users/aditya/dev/parchi/server/api.py:38).  
    [UploadFile spools large uploads to disk](https://fastapi.tiangolo.com/tutorial/request-files/#file-parameters-with-uploadfile); chunked requests bypass the declared-length guard before endpoint limits.  
    **Repro:** Send oversized chunked multipart; instrument temporary-file rollover.

**Clean/limits:** No direct original-image logging/pasteboard sink found. EXIF orientation is normalized. Expected upstream errors redact bytes/URLs (mock-tested); access logging is disabled. Backup exclusion and file-protection class are not explicitly set; effective device values remain **UNCONFIRMED**.