<!-- Copyright (c) Soundscape Community Contributers. -->

# Modularization Plan

Last updated: 2026-03-10

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
- `SSDataStructures`, `SSGeo`, `SSDataDomain`, and `SSDataContracts` are extracted into `apps/common`.
- Shared contract-side parameter models (`UniversalLinkParameters`, route/marker/location parameter types) now also live in `SSDataContracts`, with iOS files reduced to shims and runtime-specific extensions.
- `VectorTile` and the legacy `GDAJSONObject` parsing helper are now Swift/common types in `SSDataContracts`, with iOS retaining only CoreLocation convenience shims.
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
- In-memory contract parity is complete.
- Structural boundary checks are active and currently green.
- Sync-store compatibility registry/shim reintroduction is structurally blocked and absent from app/test code.
- App-layer `RealmHelper` usage is now zero.
- `DataContractRegistry` no longer constructs Realm adapters directly; Realm default installation is now owned from infrastructure and bootstrapped explicitly by app/test setup.
- Shared route/marker/location parameter models, `UniversalLinkParameters`, and universal-link path/version/component value types now live in `apps/common/Sources/SSDataContracts`; iOS serialization files retain only runtime-specific behavior.
- `VectorTile` and `GDAJSONObject` now live in `apps/common/Sources/SSDataContracts`; the Objective-C `GDAJSONObject` bridge has been removed from the iOS target.
- `POI`, `SelectablePOI`, `MatchablePOI`, `GenericLocation`, `SuperCategory`, portable POI matching/equality helpers, shared filter/sort/queue helpers, and the shared `PrimaryType`/`SecondaryType`/`Typeable` abstractions now live in `apps/common/Sources/SSDataDomain`; iOS files retain only Realm keys plus CoreLocation and presentation-specific shims/extensions.

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

Latest local results on 2026-03-10:
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
- Removed the retired sync-store seam from app and unit-test code and aligned the boundary script to enforce that state.
- Narrowed marker cloud dispatch to `MarkerParameters` updates and marker-ID deletes.
- Removed the last non-infrastructure `RouteRuntime` usage by routing route-guidance deactivation through `BehaviorDelegate` instead of a Realm-owned runtime wrapper.
- Removed dead Realm-typed overloads and stale `RealmReferenceEntity` references from non-infrastructure model/serialization/UI code; the remaining concrete Realm-model references outside infrastructure were then isolated and removed.
- Moved `GenericLocationSearchProvider`, `OSMPOISearchProvider`, and `AddressSearchProvider` Realm-backed implementations into `Data/Infrastructure/Realm`, then moved the remaining app-layer `RealmHelper` calls behind infrastructure-owned extensions and neutral façades.
- Renamed the route persistence error surface from `RouteRealmError` to `RouteDataError`, removing the last UI-facing Realm-branded error reference from runtime code.
- Chose the extraction direction: keep `apps/common` portable, keep `DataContractRegistry` as the composition root, and avoid using the placeholder `apps/ios/Package.swift` as an architectural boundary.
- Changed `DataContractRegistry` from direct Realm construction to installed defaults, with `configureWithRealmDefaults()` owned in Realm infrastructure and invoked explicitly from `AppContext` and tests.
- Moved shared universal-link/storage parameter models into `SSDataContracts`, leaving iOS serialization files as shim/extension layers for runtime-specific behavior.
- Rewrote `GDAJSONObject` in Swift, moved it and `VectorTile` into `SSDataContracts`, converted the portable tile API to `SSGeo` types, and reduced the iOS helper file to CoreLocation bridge overloads.
- Removed the Objective-C `GDAJSONObject` bridge/header from the iOS target.
- Moved `POI`, `GenericLocation`, and `SuperCategory` core taxonomy into `SSDataDomain`, flipping the portable POI surface to `SSGeo` while preserving iOS CoreLocation and glyph/audio convenience shims.
- Moved portable `POI` equality/matching plus `PrimaryType`/`SecondaryType`/`Typeable` into `SSDataDomain`, leaving `POIKeys`, CoreLocation distance wrappers, and UI/presentation usage in `apps/ios`.
- Moved `FilterPredicate`, `CompoundPredicate`, `SuperCategoryPredicate`, and `TypePredicate` into `SSDataDomain`, leaving only `LocationPredicate` and the `Filter` facade in `apps/ios`.
- Moved `POIQueue`, `SortPredicate`, and `LastSelectedPredicate` into `SSDataDomain`, leaving only `DistancePredicate` and the `Sort` convenience facade in `apps/ios`.
- Moved `DistancePredicate`, `Sort`, and generic `[POI]` array filtering/sorting helpers into `SSDataDomain`, leaving only `CLLocation` overloads and quadrant-specific array helpers in `apps/ios`.
- Moved `Filter` and `LocationPredicate` into `SSDataDomain`, leaving only the `CLLocation` `Filter.location` bridge in `apps/ios`.
- Moved universal-link path/version/component value types into `SSDataContracts`, leaving `UniversalLinkManager` and link handlers in `apps/ios`.
- Renamed the stable-target doc from a storage-only framing to `docs/plans/data_modularization_north_star.md` so it matches the broader shared-domain extraction work and future Android goal.
- Revalidated targeted modularization coverage with simulator-backed local runs.

## Next Steps
1. Continue extracting runtime-neutral domain/value/helper logic into `SSDataDomain` or `SSDataContracts` when it no longer depends on Apple frameworks or UI/runtime behavior.
2. Keep `DataContractRegistry` in `apps/ios` as the composition root; do not introduce new package or registry layers around it.
3. Keep the shared domain surface stable while trimming remaining iOS-only adapters around the portable `POI`, filter, and sort/query helper surfaces.
4. Extract `Data/Infrastructure/Realm/**` into a backend target/package only after the remaining iOS-specific associated-type and runtime wrapper surface is stable.
5. Refresh dependency analysis artifacts only when a meaningful dependency-shape delta is expected.

## Handoff
- Use `docs/plans/data_modularization_north_star.md` for the stable target.
- Use this file for current status only.
- Start the next slice with one focused cleanup, validate with `--output quiet`, then update this file only if the current status or next steps materially changed.
