# Integration decisions and assumptions

- Scope: independent offline Python modules; no app integration is performed here.
- A: optional events.grievanceSentOn records an actually sent complaint. Without it, follow-ups are explicitly planned, not claims of sending. NCH availability after escalation uses the +2-day acknowledgement check; it does not assert the complaint has gone unanswered.
- A: +30 days is the specification’s calculation, not a calendar-month interpretation or verified legal deadline. Contacts and rules retain their supplied source status; no independent legal verification claimed.
- B: only a native reviewer may change draft to reviewed. Generated Hindi is not cleared for patient use.
- C: deterministic verdict priority is expired, brand_differs, strength_differs, unreadable, quantity_short, expiry_soon, likely_ok, ok; all findings remain in the output.

- C: structured `received[].itemId` is an optional identity hint; without one, a single unmatched pair is shown as a mismatch, but multiple unmatched pairs remain missing + extra. All findings are retained even when one primary verdict is chosen.
- C: no unit conversion. If a received strength has a unit but confirmed strength has none, the result is unreadable until confirmed units are supplied. Numeric catalogue strengths do not establish the unit. Use `unitsKind: ml` explicitly on confirmed liquid-volume quantities; otherwise quantity means count.
- C: the parser leaves an unrecognized leading brand null and exposes `brandCandidate` for tentative comparison; it never silently changes it to a catalogue brand. Raw/structured contradictions and conflicting expiry labels require checking. Two-digit years mean 2000–2099.
