<!-- Copyright (c) Soundscape Community Contributers. -->

# Modularization Plan

Last updated: 2026-02-27

## Summary
Modularize iOS code incrementally while keeping behavior stable, tightening architectural boundaries, and extracting platform-neutral data/domain contracts into `apps/common`.

## Scope
In scope:
- Shared Swift package work under `apps/common`.
- Data-first modularization for domain models and storage contracts.
- Realm isolation and adapter-bound persistence details.
- Guardrail and dispatch-test enforcement.

Out of scope (current phase):
- Broad UI architecture rewrites.
- Localization/resource migration.
- Non-essential behavior redesign.

## Plan Execution Rules
- After each scoped step: run validation, stage only that slice, and commit before the next step.
- Keep each slice small enough to reason about regressions quickly.

## Boundary Rules
- `apps/common/Sources` remains platform-agnostic.
- No Apple UI/platform imports in `apps/common/Sources`.
- `Data/Contracts` stays free of Realm infrastructure types.
- `RealmSwift` imports stay in `Data/Infrastructure/Realm/**`.
- `SpatialDataStoreRegistry.store` stays infrastructure-only.

## Model and API Policy
- Keep canonical domain/value models readable and stable (`Route` remains app-facing value type).
- Keep app ingress unified at `DataContractRegistry` async contracts.
- Avoid parallel sync contract surfaces.
- Add abstractions only when they materially improve boundaries/readability.

## Current Status
Completed foundations:
- `SSDataStructures`, `SSGeo`, and initial `SSDataDomain` extraction are in `apps/common` with package tests.
- Data seam guardrails active in CI:
  - `check_spatial_data_cache_seam.sh`
  - `check_realm_infrastructure_boundary.sh`
  - `check_data_contract_boundaries.sh`
  - `check_data_contract_infra_type_allowlist.sh`
  - `check_route_mutation_seam.sh`
- Async-first storage contracts in production use:
  - `SpatialReadContract`
  - `SpatialWriteContract`
  - `SpatialMaintenanceWriteContract`
- Strict infra-only enforcement in place for `SpatialDataStoreRegistry.store` and `RealmSwift` imports.

Current architecture baseline (latest report `20260227-104958Z-ssindex-34a06c4`):
- `Data -> App`: 248
- `Data -> Visual UI`: 51
- `Behaviors -> Visual UI`: 126
- `Sensors -> App`: 74

## Progress Updates
Historical micro-slice log was intentionally condensed to keep this plan context-clear-ready.

Milestone ledger:
- 2026-02-06 to 2026-02-10: `SSDataStructures` and `SSGeo` extraction completed with package-test and boundary-check integration.
- 2026-02-09 to 2026-02-11: Data contract/guardrail baseline established and wired to CI.
- 2026-02-18 to 2026-02-26: Destination and storage-ingress migration moved app callers onto async contracts; strict infra-only guardrails landed.
- 2026-02-27: `Data -> Visual UI` reduced to 34 via marker-parameter serializer boundary cleanup; `Data -> App` reduced to 245 via GPX/data helper decouplings.
- 2026-02-27: Remaining small `Sensors -> App` `AppContext` seams were reduced via runtime-integration hooks in geolocation/headphone paths.
- 2026-02-27: Milestone 1 first extraction slice landed: `Route`, `RouteWaypoint`, and `ReferenceEntity` now live in `apps/common/Sources/SSDataDomain` with iOS bridge extensions preserved in `Temp Models`.
- 2026-02-27: Milestone 2 first extraction slice landed: shared contract-side value types moved to `apps/common/Sources/SSDataContracts` and bridged in iOS via compile-safe typealiases.
- 2026-02-27: Milestone 2 second extraction slice landed: shared route/reference/write/maintenance storage protocol surfaces moved into `apps/common/Sources/SSDataContracts` and iOS storage contracts now inherit shared protocols while retaining iOS-only members.
- 2026-02-27: Milestone 2 third extraction slice landed: shared tile-read surface introduced as `SpatialTileReadContract` in `SSDataContracts` with iOS constrained specialization (`Tile == VectorTile`, `NearbyLocation == POI`).
- 2026-02-27: Milestone 2 fourth extraction slice landed: shared marker-parameter read surface introduced as `SpatialReferenceMarkerReadContract` in `SSDataContracts` with iOS specialization (`MarkerParametersValue == MarkerParameters`).
- 2026-02-27: Milestone 2 fifth extraction slice landed: shared POI/generic-location read surface introduced as `SpatialPointOfInterestReadContract` in `SSDataContracts` with iOS specialization (`PointOfInterestValue == POI`, `GenericLocationValue == GenericLocation`).
- 2026-02-27: Local `xcodebuild test-without-building` currently fails in `AudioEngineTest` (`testDiscreteAudio2DSeveral`, `testDiscreteAudio2DSimple`) while modularization-targeted data suites pass.

Most recent completed slices (latest first):
- 2026-02-27: Added shared `SpatialPointOfInterestReadContract` in `SSDataContracts` and rewired iOS `ReferenceReadContract` to inherit it via constrained specialization.
- 2026-02-27: Added shared `SpatialReferenceMarkerReadContract` in `SSDataContracts` and rewired iOS `ReferenceReadContract` to inherit it while keeping `POI`/`GenericLocation` reads iOS-local.
- 2026-02-27: Added shared `SpatialTileReadContract` in `SSDataContracts` and rewired iOS `TileReadContract` to a constrained specialization while keeping `POI`/`VectorTile` iOS-local.
- 2026-02-27: Added shared storage protocol surfaces in `SSDataContracts` (`SpatialRouteReadContract`, `SpatialReferenceReadContract`, `SpatialRouteWriteContract`, `SpatialRouteMaintenanceWriteContract`, `SpatialAddressMaintenanceWriteContract`) and rewired iOS `Spatial*Contract` protocols to inherit from them.
- 2026-02-27: Added `SSDataContracts` module and migrated `SpatialIntersectionRegion`/`RouteReadMetadata`/`ReferenceReadMetadata`/`ReferenceCalloutReadData`/`EstimatedAddressReadData`/`AddressCacheRecord`.
- 2026-02-27: Added shared `SSDataDomain` module and migrated canonical route/reference models (`Route`, `RouteWaypoint`, `ReferenceEntity`) behind compile-safe iOS aliases/extensions.
- 2026-02-27: `BoseFramesMotionManager` event dispatch decoupled from direct `AppContext.process(...)` via runtime integration hook.
- 2026-02-27: `HeadphoneCalibrator` heading source decoupled from direct `AppContext.shared.geolocationManager`.
- 2026-02-27: `HeadphoneMotionManager` event dispatch decoupled from direct `AppContext.process(...)`.
- 2026-02-27: `SignificantChangeMonitoringOrigin` POI lookup decoupled from direct `AppContext.shared.spatialDataContext`.
- 2026-02-27: `GeolocationManager`/`GPXSimulator` simulation integration decoupled from direct `AppContext` motion wiring.

Validation baseline for each slice:
- `bash apps/common/Scripts/check_forbidden_imports.sh`
- `swift test --package-path apps/common`
- `swift Scripts/LocalizationLinter/main.swift`
- iOS seam/boundary scripts listed above
- deterministic `xcodebuild build-for-testing -derivedDataPath /tmp/ss-index-derived`
- targeted suites: `RouteStorageProviderDispatchTests`, `DataContractRegistryDispatchTests`, `CloudSyncContractBridgeTests`

## Decoupling Plan (Data-First)
### Milestone 1: Extract Domain Models to `SSDataDomain`
Tasks:
- Move canonical data domain/value models from `apps/ios/.../Data/Models/Temp Models` into `apps/common/Sources/SSDataDomain`.
- Keep public names/shapes stable (`Route`, `RouteWaypoint`, `ReferenceEntity`).
- Add Swift Testing coverage for moved model invariants.

Acceptance:
- iOS compiles against `SSDataDomain` with no behavior regressions.
- No new DTO family introduced for moved models.

### Milestone 2: Extract Contracts to `SSDataContracts`
Tasks:
- Move contract protocols and contract-side shared types into `apps/common/Sources/SSDataContracts`.
- Keep contracts async-first and Realm-free.
- Update iOS call sites/imports to consume shared contracts.

Acceptance:
- Contract targets compile in `apps/common` with platform-agnostic boundaries.
- Existing dispatch/behavior tests continue passing.

### Milestone 3: Realm Adapter Isolation Hardening
Tasks:
- Keep Realm mapping and persistence implementation strictly in `Data/Infrastructure/Realm`.
- Ensure app/runtime layers consume only contracts/domain models.
- Maintain strict seam guardrail compliance.

Acceptance:
- No non-infrastructure `RealmSwift` imports.
- No non-infrastructure `SpatialDataStoreRegistry.store` usage.

### Milestone 4: In-Memory Contract Parity
Tasks:
- Expand non-Realm in-memory contract behavior coverage.
- Verify contract semantics independent of Realm adapter specifics.

Acceptance:
- In-memory adapter passes contract behavior suite without adapter-specific shims.

## Immediate Next Steps
1. Continue Milestone 2 by addressing remaining iOS-local contract signatures outside read surfaces, especially write/maintenance signatures that still depend on `POI`/`GenericLocation`/`MarkerParameters`.
2. Evaluate whether `POI`-family abstractions should move to `apps/common` (domain-shaped and minimal) or remain iOS-local behind constrained shared protocols; avoid DTO proliferation either way.
3. Keep running the validation baseline plus dependency-report export for each slice; keep tracking full-suite `AudioEngineTest` failures explicitly alongside targeted pass suites.

## Context-Clear Handoff
Current branch state:
- Milestone 2 fifth extraction slice is complete (shared POI/generic-location read contract surface added; remaining work is write/maintenance iOS-local signature cleanup).

Latest dependency artifact:
- `docs/plans/artifacts/dependency-analysis/20260227-104958Z-ssindex-34a06c4.txt`
- `docs/plans/artifacts/dependency-analysis/latest.txt` points to that report.

Resume checklist:
1. Re-open this file and `docs/plans/data_storage_api_north_star.md`.
2. Continue Milestone 2 by extracting/normalizing remaining write/maintenance signatures that depend on iOS-local `POI`/`GenericLocation`/`MarkerParameters` types.
3. Run validation baseline and export dependency report from `/tmp/ss-index-derived/Index.noindex/DataStore`.
4. Update this plan's `Progress Updates` and commit.
