<!-- Copyright (c) Soundscape Community Contributers. -->

# Language Modularization Plan

Last updated: 2026-03-10

## Summary
Extract the portable language and localization helper surface from `apps/ios/GuideDogs/Code/Language` into a new `SSLanguage` module under `apps/common`.
Keep package-owned localized resources with the shared helpers, keep the common API portable and `SSGeo`-first, and leave UIKit/SwiftUI/app-state localization concerns in `apps/ios`.

## Scope
In scope:
- Create `SSLanguage` in `apps/common`.
- Move portable language helpers, locale helpers, and shared localized resources into `SSLanguage`.
- Keep app-locale persistence, accessibility language wiring, and UI/XIB localization support in iOS shims.
- Update modularization docs and agent instructions to track the new module.

Out of scope:
- Broad migration of unrelated app UI strings into `apps/common`.
- Skip-specific tooling or build-system changes.
- Extraction of UIKit/SwiftUI/XIB localization support from iOS.

## Current Status
Current assessment as of 2026-03-10:
- `apps/common` now contains `SSLanguage`, a portable localization/language helper module.
- Shared portable language helpers now live in `apps/common/Sources/SSLanguage`.
- `SSLanguage` owns package resources for shared localized helper strings plus `StreetSuffixAbbreviations_{en,fr}.plist`.
- iOS now imports `SSLanguage` directly at call sites for portable distance/direction/postal-abbreviation types and retains only one app-composition wrapper in `LanguageFormatter` plus a small set of CoreLocation/app-locale convenience extensions around `SSLanguage` types.
- Duplicated shared helper keys for distance formatting, cardinal/directional strings, and locale display names have been removed from the iOS app localization assets; the remaining lookups now resolve through `SSLanguage`.
- Shared intersection/roundabout road-name phrases and beacon-detail street-address summary phrases now also live in `SSLanguage`, with iOS callers routed through `LanguageFormatter`.
- Shared cardinal-movement phrases (`directions.traveling.*`, `directions.facing.*`, `directions.heading.*`, and `directions.along.*`) now also live in `SSLanguage`, with the location callouts routed through the shared formatter.
- `LocalizationContext` still owns app-locale persistence, notifications, accessibility language wiring, and app-bundle localization behavior.
- The localization validator now checks both iOS app assets and `SSLanguage` resources, and it blocks reintroducing `SSLanguage`-owned helper keys into the iOS app bundle.

## Progress Updates
- 2026-03-10: Plan created and linked from `AGENTS.md` before implementation, per repo workflow requirements.
- 2026-03-10: Added `SSLanguage` to `apps/common`, moved portable distance/direction/codeable-direction/postal-abbreviation/locale helpers into the new module, and added package-owned localized resources plus `SSLanguageTests`.
- 2026-03-10: Replaced iOS `DistanceFormatter`, `DistanceUnit`, `LanguageFormatter`, `PostalAbbreviations`, `Direction`, `CardinalDirection`, and `CodeableDirection` implementations with compatibility shims over `SSLanguage`, and added the `SSLanguage` package dependency to the iOS app target.
- 2026-03-10: Validation completed with `swift test --package-path apps/common`, `bash apps/common/Scripts/check_forbidden_imports.sh`, and `bash apps/ios/Scripts/ci/run_local_validation.sh -- --output quiet`; the only remaining full-suite test failures were the pre-existing non-blocking `AudioEngineTest.testDiscreteAudio2DSimple` and `AudioEngineTest.testDiscreteAudio2DSeveral`.
- 2026-03-10: Removed the redundant alias-based iOS `SSLanguage` shims for `DistanceFormatter` and `PostalAbbreviations`, converted the remaining helper files to true iOS-only convenience extensions/helpers, and migrated iOS callers to direct `SSLanguage` imports while keeping app-locale/app-context composition behavior in iOS.
- 2026-03-10: Audited the remaining direct uses of shared language-helper keys in `apps/ios`, rerouted those lookups through `SSLanguage` helpers and `LanguageLocalizer`, and removed the duplicated helper-key entries from every iOS `Localizable.strings` asset.
- 2026-03-10: Revalidated the shared-key cleanup with `swift Scripts/LocalizationLinter/main.swift`, `bash apps/ios/Scripts/ci/run_local_validation.sh -- --output quiet`, and the existing common/iOS build steps; the only remaining full-suite test failures were again the pre-existing non-blocking `AudioEngineTest.testDiscreteAudio2DSimple` and `AudioEngineTest.testDiscreteAudio2DSeveral`.
- 2026-03-10: Extended `apps/ios/Scripts/LocalizationLinter/main.swift` to validate `apps/common/Sources/SSLanguage/Resources`, compare locale coverage with the iOS app bundle, verify `SSLanguage` source keys against its base strings file, and fail if shared helper keys are reintroduced into `apps/ios/GuideDogs/Assets/Localization/**`; revalidated with `swift Scripts/LocalizationLinter/main.swift`, `swift test --package-path apps/common`, and `bash apps/ios/Scripts/ci/run_local_validation.sh -- --output quiet`, with only the pre-existing non-blocking `AudioEngineTest.testDiscreteAudio2DSimple` and `AudioEngineTest.testDiscreteAudio2DSeveral` failures remaining.
- 2026-03-10: Moved the shared intersection/roundabout road-name phrases and beacon-detail street-address summary phrases into `SSLanguage`, migrated `IntersectionCallout` and `BeaconDetailLocalizedLabel` to the shared helpers, removed those duplicated keys from every iOS `Localizable.strings` asset, and revalidated with `swift test --package-path apps/common`, `swift Scripts/LocalizationLinter/main.swift`, and `bash apps/ios/Scripts/ci/run_local_validation.sh -- --output quiet`, again reaching only the pre-existing non-blocking `AudioEngineTest.testDiscreteAudio2DSimple` and `AudioEngineTest.testDiscreteAudio2DSeveral` failures.
- 2026-03-10: Moved the shared cardinal-movement phrase families (`directions.traveling.*`, `directions.facing.*`, `directions.heading.*`, and `directions.along.*`) into `SSLanguage`, migrated `LocationCallout`, `InsideLocationCallout`, and `AlongRoadLocationCallout` to the shared formatter, removed those duplicated keys from every iOS `Localizable.strings` asset, and revalidated with `swift test --package-path apps/common`, `swift Scripts/LocalizationLinter/main.swift`, and `bash apps/ios/Scripts/ci/run_local_validation.sh -- --output quiet`, again reaching only the pre-existing non-blocking `AudioEngineTest.testDiscreteAudio2DSimple` and `AudioEngineTest.testDiscreteAudio2DSeveral` failures.

## Next Steps
1. Keep app-owned UI/XIB localization, locale-persistence behavior, and app-default composition in `apps/ios`; do not move those concerns into `apps/common`.
2. Keep `apps/ios/Scripts/LocalizationLinter/main.swift` as the enforcement point for the iOS/`SSLanguage` localization boundary; update it in the same change when new shared helper-key families move into `SSLanguage`.
3. Audit the remaining direction/location helper families such as `directions.nearest_road_*`, `directions.poi_name_*`, `directions.intersection_with_*`, and `directions.roundabout_with_*` next; they are the most likely remaining runtime-neutral phrase families if further extraction is worthwhile.
