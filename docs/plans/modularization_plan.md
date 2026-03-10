<!-- Copyright (c) Soundscape Community Contributers. -->

# Modularization Plan

Last updated: 2026-03-10

## Summary
Simplify the data modularization plan around a small, stable model/API surface.
Keep Realm infrastructure isolated, keep app-facing APIs close to existing model behavior, and stop expanding guardrails into an unbounded parser project.

## Scope
In scope:
- App-facing data API shape and naming stability.
- Realm isolation boundaries.
- Contract behavior confidence via focused tests.
- Low-noise validation workflows.

Out of scope:
- New abstraction families (DTO layers, extra shim/protocol hierarchies).
- Endless edge-case regex/state-machine hardening beyond practical risk.
- Broad UI or behavior architecture rewrites.

## Reset Decision (2026-03-06)
1. Freeze new seam-edge-case hardening work in `check_data_contract_boundaries.sh` unless a concrete production-risk bypass is discovered.
2. Prioritize API/model clarity and migration completion over guardrail permutation coverage.
3. Keep only high-signal enforcement and test confidence gates.

## Architecture North Star (Condensed)
- App ingress remains `DataContractRegistry`.
- App-facing models remain canonical domain/value types (`Route`, `RouteWaypoint`, `ReferenceEntity`, existing readable models).
- Realm object models remain infrastructure-local under `Data/Infrastructure/Realm`.
- Contracts remain async-first and explicit (`async`/`throws`).

## Current Status
Completed:
- `SSDataStructures`, `SSGeo`, `SSDataDomain`, and `SSDataContracts` are extracted into `apps/common`.
- In-memory contract parity milestone is complete.
- Core boundary checks are in place and active.

Active:
- Milestone 3 simplification and closure: consolidate to minimal boundaries and finish migration with stable behavior.

Known non-blocking local full-suite failures:
- `AudioEngineTest.testDiscreteAudio2DSimple`
- `AudioEngineTest.testDiscreteAudio2DSeveral`

## Minimal Boundary Rules (Keep)
1. No `RealmSwift` imports outside `Data/Infrastructure/Realm/**`.
2. No global sync-store compatibility registry reintroduction.
3. No non-registry/non-test `RealmSpatial*Contract()` construction.
4. No app-facing Realm model types in `Data/Contracts`.

## Guardrail Simplification Policy
- Keep existing guardrail script coverage as-is.
- Do not add new seam-shape detectors unless:
  - the bypass is reproducible,
  - the bypass is practically likely, and
  - it cannot be covered more simply by test + structural boundary rules.
- Prefer deleting/merging brittle checks when equivalent protection exists through stronger structural rules.

## Validation Strategy (Low-Noise)
Default local workflow:
1. `bash apps/ios/Scripts/ci/run_local_validation.sh -- --output quiet`
2. `bash apps/ios/Scripts/ci/run_local_ios_build_test.sh --build-only --derived-data-path /tmp/ss-index-derived --output errors`
3. `bash tools/SSIndexAnalyzer/Scripts/export_analysis_report.sh --store-path /tmp/ss-index-derived/Index.noindex/DataStore --top 40 --min-count 2 --file-top 40 --external-top 25`
4. `bash apps/ios/Scripts/ci/run_data_modularization_targeted_tests.sh --output quiet`

Execution notes:
- Prefer concise output modes (`quiet`, `summary`, `errors`).
- Use `xcpretty` only when readable per-test output is explicitly required.
- Treat one-off targeted-suite flakes as intermittent only if immediate rerun passes.

## Milestones
### Milestone A: Plan and Guardrail Reset
Status: In progress

Tasks:
- Freeze further seam-permutation expansion.
- Define minimal high-signal boundary set.
- Keep existing checks but stop speculative hardening.

Acceptance:
- Plan/docs reflect reset policy.
- No new speculative seam slices are opened.

### Milestone B: API Surface Consolidation
Status: In progress

Tasks:
- Keep app-facing data APIs close to prior Realm-backed model behavior.
- Remove/avoid redundant abstractions and temporary shims where not required.
- Ensure naming and behavior stay readable/stable for callers.

Acceptance:
- No new DTO family or extra protocol layering introduced for this work.
- Call sites remain straightforward and behaviorally equivalent.

### Milestone C: Behavior Confidence and Closure
Status: In progress

Tasks:
- Focus on dispatch/integration behavior tests rather than seam-shape regex growth.
- Close remaining migration items with small, test-backed slices.

Acceptance:
- Targeted data suites pass reliably.
- Boundary checks stay green without additional parser-like complexity.

## Progress Updates
- 2026-03-10: Validated the guardrail-alignment slice with `bash apps/ios/Scripts/ci/run_local_validation.sh --skip-ios-build-test -- --output quiet`; apps/common tests passed (22 tests, 0 failures) and the iOS seam/boundary scripts all passed with the updated `SpatialDataCache` infrastructure rule.
- 2026-03-10: Aligned `check_spatial_data_cache_seam.sh` with the simplified post-reset boundary so validation now matches the current architecture: `SpatialDataCache` usage is allowed anywhere under `GuideDogs/Code/Data/Infrastructure/Realm/**`, and the retired sync-store seam symbols (`SpatialDataStoreRegistry`, `DefaultSpatialDataStore`, `SpatialDataStore`) must remain absent from `GuideDogs/Code` and `UnitTests`.
- 2026-03-09: Local targeted iOS validation is currently blocked by CoreSimulatorService/device-set failures on this machine; syntax validation of touched Swift files passed with `xcrun swiftc -parse apps/ios/GuideDogs/Code/Data/Infrastructure/Realm/SpatialDataCache.swift` and `xcrun swiftc -parse apps/ios/UnitTests/Data/RouteStorageProviderDispatchTests.swift`.
- 2026-03-09: Retired the deprecated sync-store compatibility shim (`SpatialDataStore`, `DefaultSpatialDataStore`, `SpatialDataStoreRegistry`) from production/test code and removed shim-only dispatch coverage from `RouteStorageProviderDispatchTests`, keeping behavior coverage focused on persistence-local and contract-first paths.
- 2026-03-09: Revalidated after dispatch-helper consolidation with low-noise output restored (`run_data_modularization_targeted_tests.sh --output quiet`: 82 tests, 0 failures; build-for-testing warnings reduced to 13).
- 2026-03-09: Refactored `RouteStorageProviderDispatchTests` to funnel deprecated compatibility-shim access through local helper methods (`configureSpatialDataStore`, `resetSpatialDataStoreRegistry`, `spatialDataStore`) so shim usage stays explicit and concentrated in dispatch-verification scaffolding.
- 2026-03-09: Validated shim-narrowing + seam-deprecation slices with `bash apps/ios/Scripts/ci/run_data_modularization_targeted_tests.sh --output quiet` (82 tests, 0 failures).
- 2026-03-09: Verified remaining `SpatialDataStoreRegistry.store` references are confined to dispatch-verification coverage (`RouteStorageProviderDispatchTests`) rather than behavior/setup tests.
- 2026-03-09: Narrowed test-only shim usage by removing `DestinationManagerTest` setup/cleanup calls to `SpatialDataStoreRegistry.store` and using persistence-local helpers (`RealmReferenceEntity.addTemporary(...)`, `RealmReferenceEntity.removeAllTemporary()`).
- 2026-03-09: Marked `SpatialDataStoreRegistry` compatibility shim deprecated with migration guidance (`SpatialDataCache` + `DataContractRegistry`), aligning with seam-deprecation policy while retaining dispatch-test support during transition.
- 2026-03-09: Validated DestinationManager shim-narrowing slice with `bash apps/ios/Scripts/ci/run_data_modularization_targeted_tests.sh --output quiet` (82 tests, 0 failures).
- 2026-03-09: Validated canonical provider-safe `searchByKey(key:)` consolidation with `bash apps/ios/Scripts/ci/run_data_modularization_targeted_tests.sh --output quiet` (82 tests, 0 failures).
- 2026-03-09: Updated persistence-local callsites (`RealmSpatialReadContract`, `LocationDetailStoreAdapter`, `RealmReverseGeocoderLookup`, `RealmReferenceEntity`, `GDASpatialDataResultEntity`, `SpatialDataContext`) to use canonical provider-safe `searchByKey(key:)`.
- 2026-03-09: Consolidated provider-safe POI lookup API by removing the temporary `SpatialDataCache.searchByKeyIfAvailable(key:)` seam and making canonical `SpatialDataCache.searchByKey(key:)` provider-safe (nil when providers are unconfigured).
- 2026-03-09: Validated default-store provider-safe search slice with `bash apps/ios/Scripts/ci/run_data_modularization_targeted_tests.sh --output quiet` (82 tests, 0 failures).
- 2026-03-09: Added regression coverage for default-store search with no registered providers to validate nil/no-crash behavior (`SpatialDataStoreRegistry.store.searchByKey(...)`).
- 2026-03-09: Hardened `DefaultSpatialDataStore.searchByKey(_:)` to provider-safe behavior by routing through `SpatialDataCache.searchByKey(key:)` instead of assert-based search path.
- 2026-03-09: Validated provider-safe POI/reverse-geocoder slice with `bash apps/ios/Scripts/ci/run_data_modularization_targeted_tests.sh --output quiet` (81 tests, 0 failures).
- 2026-03-09: Added provider-bootstrap regression coverage for `LocationDetailStoreAdapter` and `ReverseGeocoderLookup` with no registered search providers, validating nil/no-crash behavior and no injected-store fallback dispatch.
- 2026-03-09: Removed assert-based reverse-geocoder lookup seam by routing `RealmReverseGeocoderLookup.poi(by:)` through `SpatialDataCache.searchByKey(key:)` and routing road lookup through `SpatialDataCache.road(withKey:)`.
- 2026-03-09: Removed remaining assert-based POI lookup seam in `LocationDetailStoreAdapter.poi(byKey:)` by routing through provider-safe persistence helper `SpatialDataCache.searchByKey(key:)` (no forced provider bootstrap requirement on location-detail reads).
- 2026-03-09: Residual production sync-store fallback dispatch is now zero in `apps/ios/GuideDogs/Code` (`rg "SpatialDataStoreRegistry.store" apps/ios/GuideDogs/Code` returns no matches).
- 2026-03-09: Validated the `RealmSpatialReadContract` fallback-removal slice with `bash apps/ios/Scripts/ci/run_data_modularization_targeted_tests.sh --output quiet` (78 tests, 0 failures).
- 2026-03-09: Added persistence-first regression coverage for default `DataContractRegistry.spatialRead` route/reference-nearby lookup paths to assert no injected `SpatialDataStoreRegistry.store` fallback dispatch.
- 2026-03-09: Removed `RealmSpatialReadContract` injected-store fallback dispatch by routing route/reference/marker/nearby/tile/generic-location read methods directly through persistence-local `SpatialDataCache` helpers (including provider-safe POI lookup via `searchByKey(key:)`).
- 2026-03-09: Removed `SpatialDataContext` injected-store fallback reads by routing destination POI resolution (`activeDestinationPOI`), tile/data-view queries (`getDataView`), and POR tile merge paths (`checkForTiles`, `storeTile`) through persistence-local `SpatialDataCache` helpers, with regression coverage for `checkForTiles` no-fallback dispatch.
- 2026-03-09: Validated the above `SpatialDataContext` fallback-removal slice with `bash apps/ios/Scripts/ci/run_data_modularization_targeted_tests.sh --output quiet` (74 tests, 0 failures).
- 2026-03-09: Removed `GDASpatialDataResultEntity.entrances` injected-store lookup fallback by routing entrance-key resolution through persistence-local `SpatialDataCache.searchByKey(key:)`.
- 2026-03-09: Removed remaining sync `RealmReferenceEntity` store-lookup fallback reads (`poi`/`_poi`/entity-key add lookup) by introducing persistence-local `SpatialDataCache.searchByKey(key:)` for provider-safe POI resolution without injected store dispatch.
- 2026-03-09: Removed road/intersection model lookup injected-store fallback by routing `Intersection.roads`/`distinctRoads`, `Road.intersections`, and `Road.intersection(atCoordinate:)` through persistence-local `SpatialDataCache` helpers.
- 2026-03-09: Removed road-adjacent marker read fallback by routing `RoadAdjacentDataStoreAdapter.markersNear(...)` through `SpatialDataCache.referenceEntitiesNear(...)` with persistence-first regression coverage.
- 2026-03-09: Removed compatibility fallback for marker-ID cloud delete dispatch by requiring explicit `referenceRemoveFromCloud(markerID:)` runtime-provider implementations (no placeholder `ReferenceEntity` synthesis in `ReferenceEntityRuntimeProviding` default extension).
- 2026-03-09: Removed sync marker-add cloud payload fallback for entity/location adds by dispatching marker-parameter cloud writes (`updateReferenceInCloud(_ markerParameters: MarkerParameters)`) from persistence-local marker snapshots, with regression coverage for `SpatialWriteContract.addReferenceEntity(location:...)` marker-parameter dispatch.
- 2026-03-09: Removed `LocationDetailStoreAdapter` injected-store fallback dispatch by routing POI/reference lookups through persistence-local helpers (`SpatialDataCache`, `RealmReferenceEntity.entity(byID:)`) and routing selection updates through `RealmReferenceEntity.markSelected(id:)`.
- 2026-03-09: Removed sync first-waypoint marker lookup fallback by routing `Route.markerCoordinate(forMarkerID:)` through persistence-local `SpatialDataCache.referenceEntityByKey(_:)` (no injected `SpatialDataStoreRegistry.store` dependency).
- 2026-03-09: Removed sync marker add lookup fallback for existing entity-key/generic-location markers by routing `RealmReferenceEntity.addSynchronously(...)` lookups through persistence-local `SpatialDataCache` helpers.
- 2026-03-08: Removed route sync lookup fallback dispatch by routing `Route.objectKeys(sortedBy: .distance)`, `Route.deleteAll()`, and `Route.updateWaypointInAllRoutes(markerId:)` through persistence-local `SpatialDataCache` lookups instead of `SpatialDataStoreRegistry.store`.
- 2026-03-08: Removed destination focused read/selection fallback dispatch by routing `SpatialDataDestinationEntityStore` (`destinationPOI`, destination metadata reads, `markReferenceEntitySelected`) through persistence-local `RealmReferenceEntity` helpers.
- 2026-03-08: Updated `RouteStorageProviderDispatchTests` coverage to assert persistence-first behavior and no injected-store fallback for the above route/destination slices.
- 2026-03-07: Removed destination-store temporary-flag mutation fallback by routing `SpatialDataDestinationEntityStore.setReferenceEntityTemporary(...)` to `RealmReferenceEntity.setTemporary(id:temporary:)` (no injected-store mutation dispatch).
- 2026-03-07: Removed async cloud-delete payload fallback by routing marker removal through marker-ID dispatch (`referenceRemoveFromCloud(markerID:)`) instead of `ReferenceEntity` payload hydration.
- 2026-03-07: Converted async marker add/update cloud serialization and recents hydration to contract-first POI reads (`ReferenceReadContract.poi(byKey:)`) and marker-parameter dispatch, including no-op update early return parity.
- 2026-03-07: Removed async destination temporary add/remove/clear-new/remove-all-routes sync-store fallbacks by using persistence-local helpers plus contract route enumeration.
- 2026-03-07: Removed async route distance and route-containment fallback scans by using `SpatialReadContract` (`routes`, `routes(containingMarkerID:)`, `distanceToClosestLocation(...)`).
- 2026-03-06: Plan reset completed: guardrail expansion frozen, low-noise targeted wrapper introduced, and seam-by-seam history intentionally moved to git history.
- Historical detailed update log remains in git history for this file.

## Immediate Next Steps
1. Keep `bash apps/ios/Scripts/ci/check_spatial_data_cache_seam.sh` green; it now enforces both the `SpatialDataCache` infrastructure boundary and continued absence of the retired sync-store seam in `GuideDogs/Code` and `UnitTests`.
2. Keep targeted data coverage focused on persistence-local and contract-first behavior rather than retired shim dispatch scaffolding.
3. Keep local validation low-noise by default (`--output quiet`) and report only outcome + log paths unless debugging failures.
4. Refresh dependency analysis artifacts only when a meaningful dependency-shape delta is expected.

## Context-Clear Handoff
- Use `docs/plans/data_storage_api_north_star.md` as the stable contract and this file for active status only.
- Start next session with:
  1. `bash apps/ios/Scripts/ci/run_local_ios_build_test.sh --list-simulators`
  2. `bash apps/ios/Scripts/ci/run_data_modularization_targeted_tests.sh --output quiet`
- Default execution mode: low-noise (`--output quiet`) unless failure diagnosis requires richer output.
- Continue with one focused provider-safety/compatibility-seam simplification slice, then update this file and validate with targeted suites.
