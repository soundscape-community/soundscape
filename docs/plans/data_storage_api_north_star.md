<!-- Copyright (c) Soundscape Community Contributers. -->

# Data Storage API North Star

Last updated: 2026-02-26

## Purpose
Define a stable, minimal, app-facing data API before deeper Realm extraction work so incremental seams do not produce a fragmented contract surface.

## Current State (Observed)
- App-facing ingress is now mostly consolidated:
  - Non-infrastructure `SpatialDataStoreRegistry.store` usage is zero, and the staged allowlist is empty.
  - `SpatialDataStoreRegistry.store` remains an infrastructure adapter detail under `Data/Infrastructure/Realm/**`.
- Storage behavior is still split across multiple abstractions:
  - `DataContractRegistry` async contracts for app/runtime callers.
  - `DestinationEntityStore` destination-focused seam used by `DestinationManager`.
- Canonical domain value models (`Route`, `RouteWaypoint`, `ReferenceEntity`) are now outside Realm infrastructure (`Data/Models/Temp Models`), with Realm-prefixed object models retained infrastructure-local.
- Dependency analysis (report `20260226-114625Z-ssindex-4aab0d0`) still shows reverse layering pressure:
  - `Data -> App`: 278
  - `Data -> Visual UI`: 66
  - `Behaviors -> Visual UI`: 126
  - `Data -> Behaviors`: below top-40 edge threshold in this snapshot
- Contract boundary checks now detect no Realm infrastructure model type references in `Data/Contracts` (temporary infra-type allowlist is empty).

## Design Principles
- Keep a single app-facing storage ingress: `DataContractRegistry` contracts.
- Keep protocol count small and capability-oriented; avoid API growth via parallel seams.
- Keep canonical domain/value models; avoid DTO proliferation.
- Keep Realm object models and `RealmSwift` imports infrastructure-local.
- Keep async-first contracts for all app/runtime call sites.

## Target API Shape
- App-facing storage protocols remain limited to:
  - `SpatialReadContract`
  - `SpatialWriteContract`
  - `SpatialMaintenanceWriteContract`
- `SpatialDataStoreRegistry.store` becomes adapter-internal only (Realm adapter implementation detail).
- `DestinationManager` storage operations route through app-facing contracts (or a contract-backed adapter), not a separate long-lived parallel API surface.
- App-facing contracts expose domain/value types only; no Realm object types or Realm-local model families.

## 2026-02-26 Checkpoint: Remaining Sync Callers
- Remaining staged non-infrastructure `SpatialDataStoreRegistry.store` callers: none (allowlist is empty).
- `AutoCalloutGenerator` now uses current `SpatialDataView.markedPoints` marker context instead of direct `SpatialDataStoreRegistry.store` marker-existence lookups.
- `SpatialDataView` now consumes pre-resolved storage payloads from infrastructure (`SpatialDataContext`) and no longer calls `SpatialDataStoreRegistry.store` directly.
- `POICallout` now consumes pre-resolved POI/marker context from behavior producers and no longer calls `SpatialDataStoreRegistry.store` directly.
- `Roundabout` now routes region filtering through `road.intersections` and no longer calls `SpatialDataStoreRegistry.store` directly.
- `Road` now declares intersection lookup requirements while infrastructure provides the default store-backed implementations (`RealmSpatialReadContract.swift`), removing direct store ingress from `Road.swift` without changing sync callers.
- `SpatialReadContract` no longer exposes unused road-graph/tile-data methods that returned infrastructure types (`Intersection`, `TileData`), and infra-type guardrails now report zero contract-side Realm model references.
- `RoadAdjacentDataView` now resolves marker callout data and nearby marker scans through infrastructure adapter helpers (`RoadAdjacentDataStoreAdapter`) instead of direct store access in preview-layer code.
- `LocationDetail` now resolves POI/marker lookup and marker-selection writes through infrastructure adapter helpers (`LocationDetailStoreAdapter`) instead of direct store access in UI-layer code.
- `OnboardingCalloutGenerator` and destination tutorial-page hydration now resolve destination POIs via keyed lookup (`destinationPOI(forReferenceID:)`) rather than direct `destinationPOI` property reads.
- `BeaconDemoHelper` now snapshots/restores destination context using keyed destination POI lookup (`destinationPOI(forReferenceID:)`) instead of direct `destinationPOI` property reads.
- `SpatialDataContext` now resolves active destination POI context for data-view composition and destination-tile selection via keyed lookup (`destinationPOI(forReferenceID:)`) instead of direct `destinationPOI` property reads.
- `DestinationManagerProtocol` no longer requires `destinationPOI` as an app-facing property; callers use keyed destination lookup (`destinationPOI(forReferenceID:)`) for destination POI reads.
- `DestinationManager` now keeps active-destination POI hydration as an internal helper (`activeDestinationPOI`) and keeps keyed lookup (`destinationPOI(forReferenceID:)`) as the explicit destination POI read surface.
- `DestinationManagerProtocol` now exposes keyed temporary-state lookup (`destinationIsTemporary(forReferenceID:)`), and active-beacon temporary checks in `BeaconActionHandler`/`BeaconDemoHelper` now use keyed destination ID reads instead of active-destination temporary property reads.
- `DestinationManagerProtocol` now exposes keyed destination metadata lookup (`destinationNickname(forReferenceID:)`, `destinationEstimatedAddress(forReferenceID:)`), and destination metadata reads in `AppContext`, `BeaconDemoHelper`, and `DestinationTutorialPage` now use keyed destination ID reads instead of active-destination metadata properties.
- `DestinationManagerProtocol` no longer exposes `isDestinationSet`; protocol-driven callers now derive destination-set state from `destinationKey != nil`.
- `DestinationManager` no longer exposes concrete `isDestinationSet`; destination-set checks now read `destinationKey != nil` directly in remaining concrete/test callers.
- Realm import boundary guardrail now scans all `GuideDogs/Code` files and strictly enforces `RealmSwift` usage to `Data/Infrastructure/Realm/**` (no non-infrastructure allowlist path).
- Non-infrastructure `RealmSwift` imports are now zero: preview/bootstrap callsites in marker/route UI views use infrastructure-local helper `RealmSampleDataBootstrap.bootstrap()`.
- `SpatialDataStoreRegistry.store` seam guardrail now enforces strict infrastructure-only usage (no staged allowlist path) across `GuideDogs/Code/**`.
- `ShareRouteAlertObserver` route-import existing-route check now uses async contract ingress (`DataContractRegistry.spatialRead.route(byKey:)`) instead of direct `SpatialDataCache.routeByKey(...)` from Notifications-layer alert flow.
- `RouteCell` route-row hydration now uses async contract ingress (`DataContractRegistry.spatialRead.route(byKey:)`) in `RouteModel.update()` instead of direct `SpatialDataCache.routeByKey(...)` from Visual UI list-model flow.
- `WaypointAddList` preview marker-ID seeding now uses `RealmReferenceEntity.samples` instead of `SpatialDataCache.referenceEntities()`, removing one preview-layer cache ingress.
- `SoundscapeDocumentAlert.shareRoute(_ routeDetail:)` now builds a `Route` from `RouteDetail` data (`displayName`, `description`, `waypoints.asRouteWaypoint`) instead of direct `SpatialDataCache.routeByKey(...)` lookup.
- `RouteRecommender` now resolves candidate routes through async contract ingress (`DataContractRegistry.spatialRead.routes()`), then applies the same nearby-distance and recency sort behavior in-memory instead of direct `SpatialDataCache.routesNear(...)` reads.
- `MarkersAndRoutesListHostViewController` now clears marker/route `isNew` flags via `DataContractRegistry.spatialMaintenanceWrite.clearNewReferenceEntitiesAndRoutes()` instead of direct `SpatialDataCache.clearNewReferenceEntities()/clearNewRoutes()` calls.
- These paths are sync today because they sit behind sync callout/rendering helpers or model convenience APIs.
- Forcing ad-hoc sync wrappers around async contracts would fragment the API and create hidden scheduling behavior.

## Decision for Sync Paths
- Keep the three async-first contracts as the only app-facing ingress surface.
- Do not introduce a parallel sync read protocol.
- Migrate remaining sync callers by one of two patterns:
  - Move lookup earlier to an async producer and pass resolved value data into sync callout/rendering structs.
  - Convert the owning API boundary to async when the call chain can absorb it without broad churn.
- If neither pattern is feasible for a caller, treat it as a temporary compatibility seam and track it explicitly in `modularization_plan.md`.

## Scope Control Rules
- New storage behavior required by `App`, `Behaviors`, `Visual UI`, or `Notifications` must be added to `DataContractRegistry` contracts first.
- Do not add new global registries for data access.
- Do not add protocol layers unless they replace an existing larger seam and reduce total surface area.

## Migration Sequence
1. Lock ingress (completed for non-infrastructure callers; keep enforced):
   - Migrate non-infrastructure `SpatialDataStoreRegistry.store` usages to `DataContractRegistry` contracts or infrastructure-local sync adapter seams.
   - Keep CI guardrail blocking `SpatialDataStoreRegistry.store` usage outside `Data/Infrastructure/Realm/**` with strict infrastructure-only enforcement.
2. Unify storage-facing domain models (completed for first set):
   - Move `Route`, `RouteWaypoint`, `ReferenceEntity` value models out of Realm infrastructure files.
   - Keep Realm object models (`RealmRoute`, `RealmRouteWaypoint`, `RealmReferenceEntity`) infrastructure-local.
3. Shrink contract leakage (completed for current known infrastructure model types; keep enforced):
   - Keep `Data/Contracts` infrastructure-type allowlist empty and reject regressions via `check_data_contract_infra_type_allowlist.sh`.
4. Realm isolation hardening (completed for import-boundary enforcement; keep enforced):
   - Realm import boundary checks now run across whole `GuideDogs/Code` with strict infrastructure-only `RealmSwift` import policy.
5. Extractable adapter boundary (in progress):
   - Ensure swapping persistence backend only requires a new adapter conforming to the three app-facing contracts.

## Done Criteria for “Realm Split Ready”
- `App`, `Behaviors`, `Visual UI`, and `Notifications` do not reference `Data/Infrastructure/Realm/**` directly.
- `DataContractRegistry` contracts contain no Realm infrastructure types.
- `RealmSwift` imports are confined to adapter/infrastructure files.
- A non-Realm in-memory adapter passes contract behavior tests without special-case shims.
