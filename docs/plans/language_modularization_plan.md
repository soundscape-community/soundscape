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
- `apps/common` does not yet contain a language/localization module.
- Portable candidates currently live under `apps/ios/GuideDogs/Code/Language` and adjacent helper folders.
- Shared helper resources still live in app-owned assets:
  - `Assets/Localization/*.lproj/Localizable.strings`
  - `Assets/PropertyLists/StreetSuffixAbbreviations_{en,fr}.plist`
- `LocalizationContext` currently mixes portable string lookup/locale helpers with iOS-only state, notifications, accessibility, and SwiftUI helpers.

## Progress Updates
- 2026-03-10: Plan created and linked from `AGENTS.md` before implementation, per repo workflow requirements.

## Next Steps
1. Add `SSLanguage` to `apps/common/Package.swift` with localized resources and tests.
2. Move portable language types and helpers into `SSLanguage`, converting the common API to explicit locale/unit inputs and `SSGeo` coordinates.
3. Migrate shared language-helper localization keys and postal-abbreviation resources into package-owned resources.
4. Narrow iOS `LocalizationContext` and related wrappers to app-state/UI responsibilities while routing portable formatting through `SSLanguage`.
5. Validate with package tests, forbidden-import checks, and local iOS validation, then update this plan and the modularization status docs with results.
