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
- `LocalizationContext` still owns app-locale persistence, notifications, accessibility language wiring, and app-bundle localization behavior.

## Progress Updates
- 2026-03-10: Plan created and linked from `AGENTS.md` before implementation, per repo workflow requirements.
- 2026-03-10: Added `SSLanguage` to `apps/common`, moved portable distance/direction/codeable-direction/postal-abbreviation/locale helpers into the new module, and added package-owned localized resources plus `SSLanguageTests`.
- 2026-03-10: Replaced iOS `DistanceFormatter`, `DistanceUnit`, `LanguageFormatter`, `PostalAbbreviations`, `Direction`, `CardinalDirection`, and `CodeableDirection` implementations with compatibility shims over `SSLanguage`, and added the `SSLanguage` package dependency to the iOS app target.
- 2026-03-10: Validation completed with `swift test --package-path apps/common`, `bash apps/common/Scripts/check_forbidden_imports.sh`, and `bash apps/ios/Scripts/ci/run_local_validation.sh -- --output quiet`; the only remaining full-suite test failures were the pre-existing non-blocking `AudioEngineTest.testDiscreteAudio2DSimple` and `AudioEngineTest.testDiscreteAudio2DSeveral`.
- 2026-03-10: Removed the redundant alias-based iOS `SSLanguage` shims for `DistanceFormatter` and `PostalAbbreviations`, converted the remaining helper files to true iOS-only convenience extensions/helpers, and migrated iOS callers to direct `SSLanguage` imports while keeping app-locale/app-context composition behavior in iOS.

## Next Steps
1. Keep app-owned UI/XIB localization, locale-persistence behavior, and app-default composition in `apps/ios`; do not move those concerns into `apps/common`.
2. Audit any remaining direct app-bundle uses of shared helper keys before removing duplicated language-helper strings from the iOS localization assets.
3. Extract additional language-related helpers into `SSLanguage` only when they are clearly runtime-neutral and do not introduce Apple-framework coupling.
