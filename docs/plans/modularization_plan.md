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
- `GeometryType`, the raw GeoJSON coordinate-shape aliases, and the shared GeoJSON coordinate parser now live in `SSDataContracts`, with iOS retaining only compatibility wrappers and app-specific GeoJSON model behavior.
- `Quadrant`, `CompassDirection`, the shared heading-to-quadrant bucketing helpers, the runtime-neutral path/centroid math, and the shared Web-Mercator projection helpers extracted from `GeometryUtils` now live in `SSGeo`, with iOS retaining only app- or Apple-framework-specific geometry wrappers.
- `POI`, `GenericLocation`, `SuperCategory`, portable POI equality/matching, portable filter/sort/queue constructors and generic array-query helpers, and the primary/secondary POI typing abstractions now live in `SSDataDomain`, with iOS retaining Realm keys plus CoreLocation and glyph/audio extensions only.
- `DataContractRegistry` is the app-facing data ingress.
- Default backend installation is centralized and guarded.
- The retired sync-store seam has been removed from `apps/ios/GuideDogs/Code` and `apps/ios/UnitTests`.

Current extraction decision:
- `apps/common` remains the portable core for domain models, geo types, storage contracts, and runtime-neutral contract-side parameter models.
- `DataContractRegistry` remains the single composition root in `apps/ios`; do not force it into the portable core.
- Do not use `apps/ios/Package.swift` as a modularization boundary; it is editor/tooling scaffolding, not the extraction plan.
- Realm replacement readiness now depends on two things: continuing pure-type extraction into `apps/common`, and eliminating non-infrastructure dependencies on Realm-backed entities/caches in favor of contracts plus shared value types.
- Realm backend readiness audit result on 2026-03-11: `20` Realm infrastructure files classified as `9` backend-ready, `8` mixed, and `3` runtime-owned; see `docs/plans/artifacts/2026-03-11-realm-readiness-audit.md`.

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
- `GeometryType`, the raw GeoJSON coordinate-shape aliases, and `GeoJSONGeometryParser` now live in `apps/common/Sources/SSDataContracts`; `GeometryUtils` and `GeoJsonGeometry` now delegate to the shared parser while retaining only iOS compatibility behavior.
- Imported `LocationParameters` entity materialization now routes through `DataContractRegistry.spatialMaintenanceWrite.materializePointOfInterest(from:)`; the serialization layer no longer calls `GDASpatialDataResultEntity.addOrUpdateSpatialCacheEntity(...)` directly.
- Marker and route serialization now resolve persisted marker data through async `DataContractRegistry.spatialRead` lookups instead of synchronous `LocationDetailStoreAdapter` access, and route sharing serializes from already-loaded `RouteDetail` data rather than re-querying persistence synchronously for share payloads.
- Marker serialization now gets OSM share-entity metadata through a protocol-based POI capability implemented by the Realm OSM entity type, instead of directly casting to `GDASpatialDataResultEntity` from the serialization layer.
- `LocationDetail.updateLastSelectedDate()` now goes through boundary-neutral `DataContractRegistry.spatialWrite` selection APIs instead of direct `LocationDetailStoreAdapter` selection writes.
- Database/cache-backed `RouteDetail` waypoint hydration now resolves through async `DataContractRegistry.spatialRead` lookups, `RouteStore` forwards those async updates into SwiftUI, and route-list sharing now fetches the domain `Route` value directly instead of assuming a freshly-created `RouteDetail` is synchronously hydrated.
- Route first-waypoint fallback coordinate helpers and imported-route waypoint comparison now use marker IDs/imported `ReferenceEntity` coordinates directly instead of materializing sync `LocationDetail` values, and `LocationDetail` also has an async `load(entityId:)` path through `DataContractRegistry.spatialRead`.
- `RouteWaypoint.asLocationDetail` and the deprecated sync `LocationDetail` marker/entity ID initializers have been removed; persisted detail loading now goes through the async `LocationDetail.load(...)` entry points.
- Search/nearby/home/current-location detail construction now has async `LocationDetail.load(entity:)` / `load(location:)` builders that pre-resolve matching markers through `DataContractRegistry.spatialRead`, and the first migrated controllers now use those builders before presenting detail/action flows.
- The remaining production edit/import/tutorial/cell-configuration `LocationDetail` callers now resolve marker-aware state through async contract-backed loads, POI table cells refresh marker presentation/accessibility with reuse-safe async updates instead of sync adapter lookups, and destination-key matching no longer queries the sync store when a marker has already been resolved on the detail.
- The deprecated sync `LocationDetail.init?(markerId:)` / `init?(entityId:)` compatibility loaders have been removed, and the last preview call site now constructs its sample marker detail without those sync seams.
- `Quadrant`, `CompassDirection`, the heading-to-quadrant bucketing math, the portable path/centroid helpers, and the shared Web-Mercator projection/closest-edge/polygon-containment helpers now live in `apps/common/Sources/SSGeo`; iOS call sites use the shared helpers, the former helper files are reduced to compatibility aliases, and `GeometryUtils`/`VectorTile` now bridge only the remaining compatibility-specific pieces.
- `POI`, `SelectablePOI`, `MatchablePOI`, `GenericLocation`, `SuperCategory`, portable POI matching/equality helpers, shared filter/sort/queue helpers, and the shared `PrimaryType`/`SecondaryType`/`Typeable` abstractions now live in `apps/common/Sources/SSDataDomain`; iOS files retain only Realm keys plus CoreLocation and presentation-specific shims/extensions.
- `DistanceFormatter`, `DistanceUnit`, `LanguageFormatter`, `PostalAbbreviations`, `Direction`, `CardinalDirection`, `CodeableDirection`, and portable locale/bundle helpers now live in `apps/common/Sources/SSLanguage`; iOS now imports `SSLanguage` directly for portable types and retains only app-locale/app-context composition wrappers plus UI localization behavior.
- The duplicated shared distance/direction/locale-helper string entries have been removed from `apps/ios/GuideDogs/Assets/Localization/**`; those lookups now resolve from `SSLanguage` resources.
- Shared intersection/roundabout road-name phrases and beacon-detail street-address summary phrases also now live in `apps/common/Sources/SSLanguage`; iOS callers route through the shared helpers and the duplicated asset entries have been removed from `apps/ios/GuideDogs/Assets/Localization/**`.
- Shared cardinal-movement phrase families (`directions.traveling.*`, `directions.facing.*`, `directions.heading.*`, and `directions.along.*`) also now live in `apps/common/Sources/SSLanguage`; iOS location callouts route through the shared helpers and the duplicated asset entries have been removed from `apps/ios/GuideDogs/Assets/Localization/**`.
- Shared named-location and junction-summary phrase families (`directions.nearest_road_name_*`, `directions.poi_name_*`, `directions.intersection_with_name*`, and `directions.roundabout_with_exits*`) also now live in `apps/common/Sources/SSLanguage`; iOS location callouts route through the shared helpers and the duplicated asset entries have been removed from `apps/ios/GuideDogs/Assets/Localization/**`.
- The localization validator now checks both the iOS app bundle and `apps/common/Sources/SSLanguage/Resources`, and fails if `SSLanguage`-owned helper keys are duplicated back into the iOS app assets.
- Realm replaceability readiness is now explicitly audited: the caller boundary is largely clean, but backend extraction is still blocked by mixed Realm files that directly use `DataRuntimeProviderRegistry`, `NotificationCenter`, `GDATelemetry`, or app-lifecycle globals; the current classification lives in `docs/plans/artifacts/2026-03-11-realm-readiness-audit.md`.

In progress:
- Keep app-level storage usage readable, contract-first, and free of direct Realm object-model dependencies.
- Peel app/runtime side effects out of the mixed Realm backend files before attempting backend extraction.
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
- `bash apps/ios/Scripts/ci/check_spatial_data_cache_seam.sh`: passed.
- `bash apps/ios/Scripts/ci/run_local_ios_build_test.sh --build-only --output quiet`: passed.
- `bash apps/ios/Scripts/ci/run_data_modularization_targeted_tests.sh --output quiet`: passed, `64` tests, `0` failures.
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
- Keep the boundary scripts green while closing the remaining Realm replaceability cleanup slices.

## Recent Completed Work
- Removed the retired sync-store seam from app and unit-test code, aligned the boundary scripts to enforce that state, and kept Realm confined to infrastructure-owned implementations and installers.
- Moved the remaining portable route/marker/location/universal-link contract-side value models into `SSDataContracts`, including universal-link path/version/component parsing types, while leaving only runtime managers/handlers in `apps/ios`.
- Rewrote `GDAJSONObject` in Swift, moved it and `VectorTile` into `SSDataContracts`, and reduced the iOS helper surface to CoreLocation bridge overloads.
- Moved `GeometryType`, the raw GeoJSON coordinate-shape aliases, and the shared `GeoJSONGeometryParser` into `SSDataContracts`, rewired `GeometryUtils` and `GeoJsonGeometry` to delegate to the shared parser, and added focused contract tests for the extracted GeoJSON surface.
- Added `materializePointOfInterest(from:)` to the maintenance-write contract, implemented it in the Realm adapter, and routed `LocationParameters.fetchEntity` through `DataContractRegistry` instead of direct serialization-layer cache writes.
- Converted marker and route serialization onto async contract-backed reads: `MarkerParameters` marker/entity lookups now use `DataContractRegistry.spatialRead`, route backup/share parameter assembly now uses async contract resolution, and share-document payloads build directly from loaded `RouteDetail` data where that avoids persistence round-trips.
- Replaced the remaining direct `GDASpatialDataResultEntity` cast in marker serialization with a protocol-based entity-parameter capability owned by the OSM Realm entity type, so serialization no longer depends on that infrastructure class by name.
- Added boundary-neutral selection-write APIs to `SpatialWriteContract`, implemented them in the Realm backend, updated contract tests/mocks, and routed `LocationDetail.updateLastSelectedDate()` through `DataContractRegistry` instead of `LocationDetailStoreAdapter`.
- Reworked `RouteDetail` so database/cache-backed waypoint loading goes through async contract reads rather than `RouteWaypoint.asLocationDetail`, updated `RouteStore`/`RouteEditView` to handle async detail hydration, and changed route-list sharing to fetch the route value directly before presenting the share controller.
- Removed the remaining production uses of `RouteWaypoint.asLocationDetail` from first-waypoint coordinate fallback and imported-route comparison, changed recent-callout history lookup to use `LocationDetail.entity` rather than `source.entity`, and added `LocationDetail.load(entityId:)` so entity-key based detail loading also has an async contract-first path.
- Deleted the now-unused `RouteWaypoint.asLocationDetail` compatibility property/array helper and later removed the deprecated sync `LocationDetail.init?(markerId:)` / `init?(entityId:)` loaders entirely once the remaining preview path had a direct replacement.
- Added async `LocationDetail.load(entity:)` and `LocationDetail.load(location:)` builders that hydrate matching marker state through `DataContractRegistry`, updated the first search/nearby/home/current-location controller flows to use them, and added regression coverage for entity-based generic-location marker resolution.
- Migrated additional production `LocationDetail` construction paths onto the async builders: search waypoint/result selection, current-location user actions, beacon destination resolution/edit flows, marker-parameter fetch resolution, NaviLens handoff, and markers/routes accessibility-action handling now call `LocationDetail.load(entity:)` / `load(location:)` instead of direct sync construction.
- Migrated the remaining production edit/import/tutorial/configuration call sites onto async marker-aware `LocationDetail` loads, rewired POI table cells to update marker/accessibility state through reuse-safe async refresh instead of sync adapter lookups, removed the last synchronous `MarkerEditViewRepresentable(entity:...)` convenience entry point, and trimmed the destination-key lookup fallback inside `LocationDetail`.
- Removed the remaining internal `LocationDetail` sync fallbacks by dropping `Source.entity`/`referenceEntity(source:)` storage lookups, moving closest-location resolution onto `LocationDetail`, and updating route/tour guidance to rely on the detail's async-resolved entity/marker state instead of re-querying Realm-backed adapters.
- Rewired the remaining `WaypointAddList` preview to construct its sample marker detail directly and removed the deprecated sync `LocationDetail` marker/entity ID loaders, leaving no callers on those sync entry points.
- Audited every file under `Data/Infrastructure/Realm/**`, recorded the current backend-ready vs mixed vs runtime-owned classification in `docs/plans/artifacts/2026-03-11-realm-readiness-audit.md`, and fixed the next backend-proof slice on the `DataRuntimeProviderRegistry` chokepoints in `RealmRoute.swift` and `RealmReferenceEntity.swift`.
- Moved `Quadrant`, `CompassDirection`, and the heading-to-quadrant bucketing helpers into `SSGeo`, replaced the `SpatialDataView`-owned heading helper logic with the shared API, and reduced the iOS helper files to compatibility aliases.
- Moved the runtime-neutral `GeometryUtils` path/bearing/interpolation/centroid math into `SSGeo`, left `GeometryUtils` in `apps/ios` as the Apple-framework bridge for polygon/VectorTile-specific work, and added focused `SSGeo` test coverage for the extracted path helpers.
- Moved the shared Web-Mercator projection, closest-edge, and polygon-containment math into `SSGeo`, rewired `VectorTile` and `GeometryUtils` to delegate to those shared helpers, and restored the legacy two-point containment behavior covered by the iOS unit tests.
- Moved the shared POI/domain helper surface into `SSDataDomain`: `POI`, `GenericLocation`, `SuperCategory`, type/filter/sort/queue/query helpers, and generic `[POI]` array helper logic now live in `apps/common`, while iOS retains only Realm keys, CoreLocation bridges, quadrant-specific wrappers, and presentation mapping.
- Kept `DataContractRegistry` as the single iOS composition root and moved default Realm installation behind infrastructure-owned setup (`configureWithRealmDefaults()`).
- Renamed the stable-target doc to `docs/plans/data_modularization_north_star.md` so it matches the broader shared-domain extraction work and future Android goal.
- Revalidated targeted modularization coverage with simulator-backed local runs.

## Next Steps
1. Split the mixed `RealmRoute.swift` and `RealmReferenceEntity.swift` files so their `DataRuntimeProviderRegistry` usage moves behind iOS-owned runtime adapters or explicit backend callback dependencies while the persistence/model logic stays backend-local.
2. Isolate notification/telemetry side effects next in `Route+Realm.swift`, `RealmSpatialWriteContract.swift`, and `RealmMigrationTools.swift`; do not let backend extraction depend on `NotificationCenter` or `GDATelemetry` directly.
3. Keep `SpatialDataContext.swift`, `Samplable.swift`, and `DataContractRegistry+RealmDefaults.swift` in `apps/ios` runtime/composition code and exclude them from the first backend target/package candidate.
4. Extract the remaining backend-ready Realm infrastructure into a backend target/package only after the mixed files above no longer depend on app/runtime globals.

## Handoff
- Use `docs/plans/data_modularization_north_star.md` for the stable target.
- Use this file for current status only.
- Use `docs/plans/artifacts/2026-03-11-realm-readiness-audit.md` for the current file-by-file Realm replaceability inventory and the agreed first decoupling slice.
- Start the next slice with one focused cleanup only when the target type/helper cluster is clearly portable, validate with `--output quiet`, then update this file only if the current status or next steps materially changed.
