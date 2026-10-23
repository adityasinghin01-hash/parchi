# COMMON RULES for every Kiro job (read fully before doing anything)
You are one of 6 parallel builders on Parchi (iPhone app: reads a parchi, makes one plan, tracks it, re-routes on failure). Lead: Aditya Singh. Integrator/bug-fixer: Claude. Read, in this order: `handoff/INTEGRATION-PLAN.md` (sections 0, 3, 4, 5), your own `handoff/briefs/BRIEF_<JOB>.md`, then the frontend you convert: `frontend/README.md`, `frontend/SWIFT_HANDOFF.md`, `frontend/docs/*.md`, `frontend/web/**` (screens, styles/tokens.css, components) and the reference images `frontend/assets/references/*.jpeg` (open the ones for your screens if you can view images).

## Where you work
- You are in YOUR OWN git worktree (the folder you were started in) on YOUR OWN branch. Commit locally every ~20 minutes with clear messages. NEVER push. NEVER `git checkout`/`switch` to another branch, never touch `/Users/aditya/dev/parchi` (the main checkout) or other worktrees.
- Other jobs run at the same time. Edit ONLY the files your brief gives you. A needed change in someone else's file = write `// NEEDS-<JOB>: what` in your own file, use a local stub, and list it in your report. The model contract (plan section 3, corrected by BRIEF_KR) is committed by job KR on branch `fe-kr` in a commit whose message starts `CONTRACT:`. Check with `git log fe-kr --oneline | grep CONTRACT` (all worktrees share one repository, no network needed). When it appears, run `git merge fe-kr`. Until then write your views against the names in BRIEF_KR and build later.
- Theme/Components come from job FE1 on branch `fe-1` in a commit starting `THEME:`. Same way: when `git log fe-1 --oneline | grep THEME` shows it, run `git merge fe-1`. Until then you may use a tiny private placeholder with a DIFFERENT file name (e.g. `Local<Job>Theme.swift`) and delete it right after the merge.
- Merge conflicts: resolve them keeping BOTH sides' intent; if a conflict is in a file you do not own, take the other job's version of that file.

## Build and test (iMac only; the MacBook has no Xcode)
- From your worktree root: `tools/verify/fe_build.sh <job> build` (compile), `... <job> unit` (ParchiTests), `... <job> test <TestClass> [...]` (UI tests; serialized by a lock; wait politely). `<job>` = your job id in lower case (kr, fe1 … fe5). It syncs to `~/parchi-wt/<job>` on the iMac, regenerates the project with xcodegen (never edit the `.xcodeproj`), builds with its own DerivedData, and prints `RESULT: PASS|FAIL`.
- Never run anything that writes to `~/parchi` on the iMac (server, `data/`, spend ledger, keys). Never `rsync --delete` a server folder. Never reset databases. Never call the Anthropic API. Never print or log keys.
- If the same build error survives 3 honest fixes, stop, write it in your report, and finish what you can.

## Non-negotiable product rules
1. All data comes from `AppModel`/engine/server. NEVER copy web fixtures (HSR Layout, Aarav Mehta, sample prices, "482931"). Money is integer paise through `Support/Money.swift`. The demo basket total stays Rs 2,696.77.
2. Anything that is sample/demo is labelled so on screen. A failed scan never shows sample data as if it were read.
3. No false claims in copy: no "referral fee", no "partner pharmacies", no "your picture never leaves", no promised savings. Use the copy decisions in plan section 5. Sandbox orders say "Test order". Never recommend doses or tests; never swap brands; H1/X = "buy in person with the original parchi".
4. Keep every accessibility identifier and label that tests use. Before renaming/removing any visible string or identifier run `grep -rn "<text>" app/ParchiUITests app/ParchiTests`. Preserve at least: `Approve`, `Choose myself`, `Re-routed (Plan B)`, `noPersonalDetailsToggle`, `needsHelpCard`, `needsHelpAddMedicine`, `addMedicine`, `addTest`, `Use this photo`, `Agree & continue`.
5. If a behaviour change is intended and an existing test must change, change the TEST deliberately and list it under "Tests changed and why" in your report. Never delete/skip/weaken a test to get green.
6. Do NOT change navigation structure (`NavigationStack` + `Route` in `ParchiApp.swift`, `-demoRoute` jumps) except where your brief says so.
7. No new packages, no new network calls, no analytics. Swift 5 language mode, iOS 17+, `@Observable` + injected `AppModel`.

## Design rules (from the approved frontend)
Colours/spacing/type come from `frontend/web/styles/tokens.css` (cream `#f6e5c7`, paper `#f9e8ce`, orange `#cc2e11`, yellow `#f19116`, warm dark-brown text). Dynamic Type (no fixed font sizes for body text), VoiceOver labels on every control, Reduce Motion respected, tap targets >= 44 pt, contrast readable, no information by colour alone. Layout follows the web screens and reference images, rebuilt with real SwiftUI controls (never a screenshot as UI).

## Bugs (do NOT fix small ones)
Record every bug you notice (yours or anyone's) in `handoff/bugs/<job>.md`: `ID | screen | steps | what happened | severity (P0 crash/dead end/wrong price/false claim/data leak/sample-as-real, P1 wrong but recoverable, P2 cosmetic, P3 idea)`. Fix only what blocks YOUR screen from building or from working in the demo path.

## Finish
Deadline: write your report by the time given in your launch prompt even if unfinished. Report file `handoff/reports/<job>.md`: (1) what is done, per screen/file; (2) exact `RESULT:` lines of the builds/tests you ran; (3) "Tests changed and why"; (4) what is NOT done or only partly done; (5) bugs found (also in handoff/bugs); (6) NEEDS-* requests to other jobs. Be honest: unverified = say unverified. Commit everything locally, then stop. Do not start other agents.
