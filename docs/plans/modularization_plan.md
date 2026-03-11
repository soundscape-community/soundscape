<!-- Copyright (c) Soundscape Community Contributers. -->

# Modularization Plan

Last updated: 2026-03-11

## Summary
Continue extracting shared data/domain logic into `apps/common` while keeping Realm isolated behind a stable app-facing storage boundary.
Keep `DataContractRegistry` as the iOS composition root, keep Realm implementation details under `Data/Infrastructure/Realm`, and prefer deleting compatibility seams over adding new ones.

## Scope
In scope:
- Shared domain/value/helper extraction into `apps/common`.
- App-facing data API shape and naming stability.
- Realm isolation boundaries.
- Contract behavior confidence through focused validation.
- Low-noise local validation and handoff hygiene.

Out of scope:
- New abstraction families such as DTO stacks or extra shim hierarchies.
- Parser-style seam hardening beyond clear structural boundary checks.
- Broad UI or behavior architecture work unrelated to the shared data/domain boundary.

## Current Assessment
Progress is materially good:
- `SSDataStructures`, `SSGeo`, `SSLanguage`, `SSDataDomain`, and `SSDataContracts` are extracted into `apps/common`.
- Shared language/localization helpers now live in `SSLanguage`, with iOS retaining only app-state and UI-specific localization behavior.
- Shared contract-side parameter models (`UniversalLinkParameters`, route/marker/location parameter types) now also live in `SSDataContracts`, with iOS files reduced to shims and runtime-specific extensions.
- `VectorTile` and the legacy `GDAJSONObject` parsing helper are now Swift/common types in `SSDataContracts`, with iOS retaining only CoreLocation convenience shims.
- `Quadrant`, `CompassDirection`, the shared heading-to-quadrant bucketing helpers, the runtime-neutral path/centroid math, and the shared Web-Mercator projection helpers extracted from `GeometryUtils` now live in `SSGeo`, with iOS retaining only app- or Apple-framework-specific geometry wrappers.
- `POI`, `GenericLocation`, `SuperCategory`, portable POI equality/matching, portable filter/sort/queue constructors and generic array-query helpers, and the primary/secondary POI typing abstractions now live in `SSDataDomain`, with iOS retaining Realm keys plus CoreLocation and glyph/audio extensions only.
- `DataContractRegistry` is the app-facing data ingress.
- Default backend installation is centralized and guarded.
- The retired sync-store seam has been removed from `apps/ios/GuideDogs/Code` and `apps/ios/UnitTests`.

Current extraction decision:
- `apps/common` remains the portable core for domain models, geo types, storage contracts, and runtime-neutral contract-side parameter models.
- `DataContractRegistry` remains the single composition root in `apps/ios`; do not force it into the portable core.
- Do not use `apps/ios/Package.swift` as a modularization boundary; it is editor/tooling scaffolding, not the extraction plan.
- Realm replacement readiness now depends on continuing pure-type extraction into `apps/common` while keeping iOS-only runtime behavior local to `apps/ios`.

Local evidence as of 2026-03-10:
- `RealmSwift` imports outside `Data/Infrastructure/Realm/**`: `0`
- `SpatialDataCache` usage outside `Data/Infrastructure/Realm/**`: `0`
- `RealmHelper` usage outside `Data/Infrastructure/Realm/**`: `0`
- `RealmSpatial*Contract()` construction outside registry/tests: `0`
- Residual sync-store seam symbols in app/test Swift sources: `0`
- `spatialReadCompatibility` / `spatialWriteCompatibility` references: `0`

Plan sanity assessment:
- The north star is still correct after broadening beyond storage cleanup: shared domain/contracts/helpers in `apps/common`, `DataContractRegistry` as the iOS composition root, and Realm kept infrastructure-local.
- The previous plan had become too historical and noisy. It is now trimmed to current status, current rules, and current next steps.
- The main design choice is now settled: prefer portable common modules plus an iOS app composition root, rather than introducing an intermediate iOS package layer or another registry abstraction.

## Current Status
Completed:
- Common data modules are extracted and tested in `apps/common`.
- `SSLanguage` is extracted with package-owned localization resources and iOS compatibility shims.
- In-memory contract parity is complete.
- Structural boundary checks are active and currently green.
- Sync-store compatibility registry/shim reintroduction is structurally blocked and absent from app/test code.
- App-layer `RealmHelper` usage is now zero.
- `DataContractRegistry` no longer constructs Realm adapters directly; Realm default installation is now owned from infrastructure and bootstrapped explicitly by app/test setup.
- Shared route/marker/location parameter models, `UniversalLinkParameters`, and universal-link path/version/component value types now live in `apps/common/Sources/SSDataContracts`; iOS serialization files retain only runtime-specific behavior.
- `VectorTile` and `GDAJSONObject` now live in `apps/common/Sources/SSDataContracts`; the Objective-C `GDAJSONObject` bridge has been removed from the iOS target.
- `Quadrant`, `CompassDirection`, the heading-to-quadrant bucketing math, the portable path/centroid helpers, and the shared Web-Mercator projection/closest-edge/polygon-containment helpers now live in `apps/common/Sources/SSGeo`; iOS call sites use the shared helpers, the former helper files are reduced to compatibility aliases, and `GeometryUtils`/`VectorTile` now bridge only the remaining compatibility-specific pieces.
- `POI`, `SelectablePOI`, `MatchablePOI`, `GenericLocation`, `SuperCategory`, portable POI matching/equality helpers, shared filter/sort/queue helpers, and the shared `PrimaryType`/`SecondaryType`/`Typeable` abstractions now live in `apps/common/Sources/SSDataDomain`; iOS files retain only Realm keys plus CoreLocation and presentation-specific shims/extensions.
- `DistanceFormatter`, `DistanceUnit`, `LanguageFormatter`, `PostalAbbreviations`, `Direction`, `CardinalDirection`, `CodeableDirection`, and portable locale/bundle helpers now live in `apps/common/Sources/SSLanguage`; iOS now imports `SSLanguage` directly for portable types and retains only app-locale/app-context composition wrappers plus UI localization behavior.
- The duplicated shared distance/direction/locale-helper string entries have been removed from `apps/ios/GuideDogs/Assets/Localization/**`; those lookups now resolve from `SSLanguage` resources.
- Shared intersection/roundabout road-name phrases and beacon-detail street-address summary phrases also now live in `apps/common/Sources/SSLanguage`; iOS callers route through the shared helpers and the duplicated asset entries have been removed from `apps/ios/GuideDogs/Assets/Localization/**`.
- Shared cardinal-movement phrase families (`directions.traveling.*`, `directions.facing.*`, `directions.heading.*`, and `directions.along.*`) also now live in `apps/common/Sources/SSLanguage`; iOS location callouts route through the shared helpers and the duplicated asset entries have been removed from `apps/ios/GuideDogs/Assets/Localization/**`.
- Shared named-location and junction-summary phrase families (`directions.nearest_road_name_*`, `directions.poi_name_*`, `directions.intersection_with_name*`, and `directions.roundabout_with_exits*`) also now live in `apps/common/Sources/SSLanguage`; iOS location callouts route through the shared helpers and the duplicated asset entries have been removed from `apps/ios/GuideDogs/Assets/Localization/**`.
- The localization validator now checks both the iOS app bundle and `apps/common/Sources/SSLanguage/Resources`, and fails if `SSLanguage`-owned helper keys are duplicated back into the iOS app assets.

In progress:
- Continue moving runtime-neutral domain/contract types into `apps/common` instead of building an iOS package shell.
- Keep app-level storage usage readable and contract-first.
- Close remaining migration steps in small validated slices.

Known non-blocking local full-suite failures:
- `AudioEngineTest.testDiscreteAudio2DSimple`
- `AudioEngineTest.testDiscreteAudio2DSeveral`

## Boundary Rules
1. No `RealmSwift` imports outside `Data/Infrastructure/Realm/**`.
2. No global sync-store compatibility registry or equivalent seam reintroduction.
3. No non-registry/non-test `RealmSpatial*Contract()` construction.
4. No app-facing Realm model types in `Data/Contracts`.
5. Keep cloud marker dispatch value-shaped (`MarkerParameters` updates, marker-ID deletes) unless a concrete production caller requires something else.
6. Keep `DataContractRegistry` as the single composition root; do not add a second registry layer for modularization.
7. Prefer moving runtime-neutral value types into `apps/common` and keep iOS-specific composition/runtime code in `apps/ios`; do not use `apps/ios/Package.swift` as a modularization boundary.

## Validation Snapshot
Preferred local workflow:
1. `bash apps/ios/Scripts/ci/run_local_validation.sh -- --output quiet`
2. `bash apps/ios/Scripts/ci/run_data_modularization_targeted_tests.sh --output quiet`
3. Refresh dependency analysis only when dependency shape meaningfully changes.

Latest local results on 2026-03-11:
- `bash apps/ios/Scripts/ci/run_data_modularization_targeted_tests.sh --output quiet`: passed, `61` tests, `0` failures.
- `bash apps/ios/Scripts/ci/run_local_validation.sh -- --output quiet`: boundary scripts green, iOS build-for-testing passed, full-suite test phase reached only the two known non-blocking `AudioEngineTest` failures.

## Milestone Status
### Milestone A: Reset and Guardrail Simplification
Status: Completed

Outcome:
- The plan is reset around high-signal structural rules instead of speculative seam permutations.
- Validation defaults are low-noise.

### Milestone B: API Surface Consolidation
Status: In progress

Remaining focus:
- Keep app-facing call sites stable and readable.

### Milestone C: Portable Contract-Type Extraction
Status: In progress

Remaining focus:
- Continue moving runtime-neutral contract-side value types into `apps/common/Sources/SSDataContracts`.
- Keep iOS-specific associated types and runtime resolution helpers in `apps/ios` until they are genuinely portable.

### Milestone D: Behavior Confidence and Closure
Status: In progress

Remaining focus:
- Keep targeted data suites reliable.
- Keep the boundary scripts green while closing the remaining cleanup slices.

## Recent Completed Work
- Removed the retired sync-store seam from app and unit-test code, aligned the boundary scripts to enforce that state, and kept Realm confined to infrastructure-owned implementations and installers.
- Moved the remaining portable route/marker/location/universal-link contract-side value models into `SSDataContracts`, including universal-link path/version/component parsing types, while leaving only runtime managers/handlers in `apps/ios`.
- Rewrote `GDAJSONObject` in Swift, moved it and `VectorTile` into `SSDataContracts`, and reduced the iOS helper surface to CoreLocation bridge overloads.
- Moved `Quadrant`, `CompassDirection`, and the heading-to-quadrant bucketing helpers into `SSGeo`, replaced the `SpatialDataView`-owned heading helper logic with the shared API, and reduced the iOS helper files to compatibility aliases.
- Moved the runtime-neutral `GeometryUtils` path/bearing/interpolation/centroid math into `SSGeo`, left `GeometryUtils` in `apps/ios` as the Apple-framework bridge for polygon/VectorTile-specific work, and added focused `SSGeo` test coverage for the extracted path helpers.
- Moved the shared Web-Mercator projection, closest-edge, and polygon-containment math into `SSGeo`, rewired `VectorTile` and `GeometryUtils` to delegate to those shared helpers, and restored the legacy two-point containment behavior covered by the iOS unit tests.
- Moved the shared POI/domain helper surface into `SSDataDomain`: `POI`, `GenericLocation`, `SuperCategory`, type/filter/sort/queue/query helpers, and generic `[POI]` array helper logic now live in `apps/common`, while iOS retains only Realm keys, CoreLocation bridges, quadrant-specific wrappers, and presentation mapping.
- Kept `DataContractRegistry` as the single iOS composition root and moved default Realm installation behind infrastructure-owned setup (`configureWithRealmDefaults()`).
- Renamed the stable-target doc to `docs/plans/data_modularization_north_star.md` so it matches the broader shared-domain extraction work and future Android goal.
- Revalidated targeted modularization coverage with simulator-backed local runs.

## Next Steps
1. Continue extracting runtime-neutral domain/value/helper logic into `SSDataDomain` or `SSDataContracts` when it no longer depends on Apple frameworks or UI/runtime behavior.
2. Use `SSLanguage` for future runtime-neutral localization helpers instead of reintroducing shared language logic under `apps/ios`.
3. Keep `DataContractRegistry` in `apps/ios` as the composition root; do not introduce new package or registry layers around it.
4. Keep the shared domain surface stable while trimming remaining iOS-only adapters and only extract additional helpers when the module boundary is clearly cleaner afterward.
5. Extract `Data/Infrastructure/Realm/**` into a backend target/package only after the remaining iOS-specific associated-type and runtime wrapper surface is stable.
6. Refresh dependency analysis artifacts only when a meaningful dependency-shape delta is expected.

## Handoff
- Use `docs/plans/data_modularization_north_star.md` for the stable target.
- Use this file for current status only.
- Start the next slice with one focused cleanup only when the target type/helper cluster is clearly portable, validate with `--output quiet`, then update this file only if the current status or next steps materially changed.
