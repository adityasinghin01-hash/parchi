# Parchi Design (Theme + shared components)
Source: `frontend/web/styles/tokens.css`, `frontend/web/components/*.js`, logo palette in `frontend/SWIFT_HANDOFF.md`. Light mode = approved brand palette; dark mode = readable warm-brown variant.

- `Theme.Color.cream / paper / surface / line` backgrounds and hairlines; `accent` (#cc2e11) + `onAccent` (label on accent fill); `gold` (#f19116, not for body text); `ink` text, `muted` secondary text; `success / warning / danger` status (always with text or icon).
- `Theme.Spacing.xs 4 · s 8 · m 12 · l 16 · xl 24 · xxl 32`; `Theme.Radius.card 16 · sheet 26`; `Theme.minTarget 44`.
- `Theme.Font.title() / headline() / body() / footnote()` (+ `largeTitle()`, `caption()`): Dynamic Type text styles only.
- `Button("…") {}.buttonStyle(.parchiPrimary)` / `ParchiPrimaryButtonStyle()`: full width, >= 52 pt, pressed + disabled states, Reduce Motion safe.
- `.buttonStyle(.parchiSecondary)` / `ParchiSecondaryButtonStyle()`: outlined orange, >= 48 pt.
- `ParchiCard { … }` (optional `padding:`): rounded surface container.
- `ParchiChip(text:tone:)`, tones `.neutral / .success / .warning / .danger` (non-neutral tones add an icon).
- `SampleBadge()` (or `SampleBadge(text:)`): "SAMPLE" tag, id `sampleBadge`. Put it on every sample/demo item.
- `ParchiHeader(title:subtitle:)`: screen title (header trait) + optional muted subtitle.
- `ParchiTabBar(selection: $tab, onSelect: { tab in … })` with `ParchiTab.home / .parchis / .care / .account`. Plain view, not a navigation container; ids `tab_home` etc.
- `LogoMark(size:)`: transparent logo from the asset catalog (`ParchiLogo`), never recoloured.
- App tint: `.tint(Theme.Color.accent)` on `RootView` in `ParchiApp.swift`; `AccentColor` asset matches.
- Catalogue: `ThemePreview.swift` (`ThemeCatalogue`, previews Light / Dark / Large text, DEBUG only).
