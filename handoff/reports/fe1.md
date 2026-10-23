# FE1 report: design foundation (Theme + shared components)
Branch `fe-1`. THEME commit: `1c801ed THEME: Theme tokens, shared components ...` at 04:46 IST (started 04:42).

## 1. Done
- `app/Parchi/Design/Theme.swift`: `Theme.Color` cream #f6e5c7, paper #f9e8ce, accent #cc2e11, gold #f19116, ink #421c08, muted #68553f, surface #fff6e4 (tokens.css), plus `onAccent`, `line`, `success`, `warning`, `danger`. All are dynamic: light = approved brand palette, dark = warm dark-brown variant (cream→#1F150D, accent→#EF6A43, ink→cream). `Theme.Spacing` xs…xxl (4/8/12/16/24/32), `Theme.Radius.card = 16` (+ `sheet`, `chip`), `Theme.minTarget = 44`, `Theme.Font.title/headline/body/footnote()` (+ `largeTitle`, `caption`), Dynamic Type text styles only. The hex helper is `private`, so it cannot clash with other jobs.
- `app/Parchi/Design/Components.swift`: `ParchiPrimaryButtonStyle` (52 pt min height, accent fill, `onAccent` label, pressed/disabled states, scale animation turned off under Reduce Motion), `ParchiSecondaryButtonStyle` (outlined, 48 pt), shorthands `.parchiPrimary` / `.parchiSecondary`, `ParchiCard { }` (optional `padding:`), `ParchiChip(text:tone:)` with `ParchiChipTone` `.neutral/.success/.warning/.danger` (non-neutral tones add an SF Symbol so the meaning is not carried by colour alone), `SampleBadge()` (id `sampleBadge`, VoiceOver "Sample data"), `ParchiHeader(title:subtitle:)` (header trait), `ParchiTab` + `ParchiTabBar(selection:onSelect:)` (Home/Parchis/Care/Account; plain view, ids `tab_home` …, selected trait), `LogoMark(size:)`.
- `app/Parchi/Assets.xcassets`: `ParchiLogo` (transparent logo, 600 px RGBA, not recoloured), `AccentColor` (light #CC2E11 / dark #EF6A43), `AppIcon` (original opaque logo at 1024 px; needed because xcodegen's default AppIcon setting fails the build once a catalog exists).
- `app/Parchi/ParchiApp.swift`: one line, `.tint(Theme.Color.accent)` on `RootView()`.
- `app/Parchi/Design/ThemePreview.swift`: `ThemeCatalogue` (DEBUG only) with previews Light / Dark / Large text.
- `app/Parchi/Design/README.md`: the API in 16 lines.
- No existing screen restyled.

## 2. Results
- `tools/verify/fe_build.sh fe1 build` → `RESULT: PASS (build)`. The first run failed on the missing AppIcon; it passed after I added it.
- `tools/verify/fe_build.sh fe1 unit` → `Executed 119 tests, with 1 test skipped and 0 failures` / `RESULT: PASS (unit)` (118 pass, 1 skip).
- UI tests: not run (my brief does not require them). Nothing visible to them changed: no strings or identifiers.

## 3. Tests changed and why
None.

## 4. Not done / unverified
- Not visually checked on a simulator or in Xcode previews (the MacBook has no Xcode). Contrast ratios are calculated from the hex values, not measured on screen.
- The tint change on existing screens compiles, but how it looks is unverified. System buttons and links are now orange instead of blue.

## 5. Bugs
In `handoff/bugs/fe1.md`: FE1-1 (P2, dark-mode contrast of system `.borderedProminent`), FE1-2 (P3, README.md is bundled as a resource), FE1-3 (fixed, AppIcon needed).

## 6. NEEDS-* requests
- NEEDS-LEAD/integrator (project.yml, not mine): think about `excludes: ["**/*.md"]` under the Parchi sources (FE1-2).
- To screen jobs: use `.buttonStyle(.parchiPrimary)` instead of `.borderedProminent` for readable dark mode (FE1-1).
