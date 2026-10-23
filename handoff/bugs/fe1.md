# Bugs noticed by FE1
ID | screen | steps | what happened | severity
---|---|---|---|---
FE1-1 | any screen using system `.borderedProminent` (not `ParchiPrimaryButtonStyle`) | dark mode | system draws a white label on the dark-mode accent #EF6A43, about 3:1 contrast. `ParchiPrimaryButtonStyle` uses `Theme.Color.onAccent` (dark brown) and is fine. Screens should move to `.parchiPrimary` when restyled. | P2
FE1-2 | build | xcodegen copies `app/Parchi/Design/README.md` into the app bundle as a resource | harmless now, but a second `README.md` anywhere under `app/Parchi` would cause "Multiple commands produce README.md". Fix would be an `excludes: ["**/*.md"]` in project.yml (not FE1's file). | P3
FE1-3 | build | the project had no asset catalog; xcodegen's default `ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon` failed the build once a catalog existed | fixed by adding `AppIcon.appiconset` (original logo, 1024 px, opaque). Noted so nobody deletes it. | fixed
