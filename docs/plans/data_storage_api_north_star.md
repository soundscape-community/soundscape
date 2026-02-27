<!-- Copyright (c) Soundscape Community Contributers. -->

# Data Storage API North Star

Last updated: 2026-02-27

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

## 2026-02-27 Checkpoint: Sync-Compatibility Migration
- Remaining staged non-infrastructure `SpatialDataStoreRegistry.store` callers: none (allowlist is empty).
- Remaining non-infrastructure direct `SpatialDataCache.*` callers: none (all direct usage is now confined to `Data/Infrastructure/Realm/SpatialDataCache.swift`).
- `AutoCalloutGenerator` now uses current `SpatialDataView.markedPoints` marker context instead of direct `SpatialDataStoreRegistry.store` marker-existence lookups.
- `SpatialDataView` now consumes pre-resolved storage payloads from infrastructure (`SpatialDataContext`) and no longer calls `SpatialDataStoreRegistry.store` directly.
- `POICallout` now consumes pre-resolved POI/marker context from behavior producers and no longer calls `SpatialDataStoreRegistry.store` directly.
- `Roundabout` now routes region filtering through `road.intersections` and no longer calls `SpatialDataStoreRegistry.store` directly.
- `Road` now declares intersection lookup requirements while infrastructure provides the default store-backed implementations (`RealmSpatialReadContract.swift`), removing direct store ingress from `Road.swift` without changing sync callers.
- `SpatialReadContract` no longer exposes unused road-graph/tile-data methods that returned infrastructure types (`Intersection`, `TileData`), and infra-type guardrails now report zero contract-side Realm model references.
- `RoadAdjacentDataView` now resolves marker callout data and nearby marker scans through infrastructure adapter helpers (`RoadAdjacentDataStoreAdapter`) instead of direct store access in preview-layer code.
- `LocationDetail` now resolves POI/marker lookup and marker-selection writes through infrastructure adapter helpers (`LocationDetailStoreAdapter`) instead of direct store access in UI-layer code.
- `OnboardingCalloutGenerator` now resolves destination POIs via keyed lookup (`destinationPOI(forReferenceID:)`) rather than direct `destinationPOI` property reads.
- `OnboardingCalloutGenerator` now pre-resolves destination POI context through async contract ingress (`DataContractRegistry.spatialRead.poi(byKey:)`) when a destination entity key is available, with keyed destination-manager lookup kept as compatibility fallback.
- `InteractiveBeaconViewModel` now pre-resolves destination POI context through async contract ingress (`DataContractRegistry.spatialRead.poi(byKey:)`) on destination changes, and no longer performs repeated sync keyed destination-POI fallback reads while processing heading updates.
- `BeaconActionHandler.callout(detail:)` now pre-resolves destination POI context through async contract ingress (`DataContractRegistry.spatialRead.poi(byKey:)`) when beacon destination entity key context is available, with keyed destination-manager lookup retained as compatibility fallback.
- `BeaconDetailStore` now pre-resolves destination POI context through async contract ingress (`DataContractRegistry.spatialRead.poi(byKey:)`) for initial destination-backed beacon hydration and destination-change updates, with keyed destination-manager lookup retained as compatibility fallback.
- `BeaconDemoHelper.prepare(disableMelodies:)` now pre-resolves temporary destination POI context through async contract ingress (`DataContractRegistry.spatialRead.poi(byKey:)`) when destination entity-key context is available, with keyed destination-manager lookup retained as compatibility fallback.
- `BeaconCalloutGenerator` now hydrates destination POI cache via async contract ingress (`DataContractRegistry.spatialRead.poi(byKey:)`) for active-destination updates and initialization, so automatic location/geofence callout paths consume cached event/contract context instead of repeatedly performing sync destination-manager POI reads in hot loops.
- Onboarding selected-beacon callout events now carry pre-resolved destination POI context from `InteractiveBeaconViewModel`, and `OnboardingCalloutGenerator` now consumes this payload first before contract/keyed-manager fallback lookup.
- `OnboardingCalloutGenerator` and destination tutorial callout resolution (`DestinationTutorialPage`, `DestinationTutorialInfoPage`) now use contract-only fallback resolution (`referenceEntity(byID:)` + `poi(byKey:)` or `GenericLocation(ref:)`) when destination entity-key lookup is unavailable, removing app-layer keyed destination-manager POI fallback reads from these sync-compatibility paths.
- Beacon UI destination resolution paths (`BeaconActionHandler.createMarker`, `BeaconActionHandler.callout(detail:)`, `BeaconDetailStore` destination hydration, and `InteractiveBeaconViewModel` destination refresh fallback) now use contract-only fallback resolution (`referenceEntity(byID:)` + `poi(byKey:)` or `GenericLocation(ref:)`) when destination entity-key lookup is unavailable, removing keyed destination-manager POI fallback reads from these app-layer beacon compatibility flows.
- `PreviewBehavior.destinationPOI(forReferenceID:)` and `BeaconDemoHelper` temporary-destination snapshot hydration now use contract-only fallback resolution (`referenceEntity(byID:)` + `poi(byKey:)` or `GenericLocation(ref:)`) when destination entity-key lookup is unavailable, removing keyed destination-manager POI fallback reads from these compatibility flows.
- `BeaconCalloutGenerator.refreshDestinationPOI(for:)` now uses contract-only fallback resolution (`referenceEntity(byID:)` + `poi(byKey:)` or `GenericLocation(ref:)`) when destination entity-key lookup is unavailable, removing keyed destination-manager POI fallback reads from automatic beacon callout refresh flow.
- `MarkerParameters.init(markerId:)` now hydrates marker context via `LocationDetailStoreAdapter.referenceEntity(byID:)?.getPOI()` instead of `destinationPOI(forReferenceID:)`, removing keyed destination-POI helper usage from route waypoint marker-serialization hydration.
- `DestinationTutorialInfoPage.playCallout()` now pre-resolves destination POI context through async contract ingress (`DataContractRegistry.spatialRead.poi(byKey:)`) when destination entity-key context is available, with keyed destination-manager lookup and cached tutorial destination fallback retained for compatibility.
- `DestinationTutorialPage` now pre-resolves destination POI/name context through async contract ingress (`DataContractRegistry.spatialRead.poi(byKey:)`) during tutorial page appearance when destination entity-key context is available, with keyed destination-manager lookup retained as compatibility fallback for synchronous reads.
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
- Marker delete-alert route-name hydration now resolves via async contract ingress (`DataContractRegistry.spatialRead.routes(containingMarkerID:)`) in `EditMarkerView` and `MarkersList`, and `Alert.deleteMarkerAlert` now consumes pre-resolved route names instead of direct `SpatialDataCache.routesContaining(...)` reads.
- `ReverseGeocoderContext` nearest-road helpers now use road-local intersection/keyed lookup (`closestRoad.intersection(atCoordinate:)`, in-scope road-key match) instead of direct `SpatialDataCache.intersection(...)` / `SpatialDataCache.searchByKey(...)` reads.
- Intersection arrival/callout flow now carries resolved `Intersection` context in `IntersectionArrivalEvent` and `IntersectionCallout`, removing direct `SpatialDataCache.intersectionByKey(...)` lookups from default/route-guidance/tour intersection callout paths.
- `DynamicLaunchViewController` now uses infrastructure helper `RealmSpatialSearchBootstrap.configureDefaults()` for default search-provider/geocoder bootstrap instead of direct `SpatialDataCache.useDefaultSearchProviders()/useDefaultGeocoder()` UI-layer calls.
- `SearchResultsTableViewController` now resolves recent selections via async contract ingress (`DataContractRegistry.spatialRead.recentlySelectedPOIs()`) instead of direct `SpatialDataCache.recentlySelectedObjects()` reads.
- `EstimatedLocationDetail` now resolves reverse-geocoded address data via async contract ingress (`DataContractRegistry.spatialRead.estimatedAddress(near:)`) instead of direct `SpatialDataCache.fetchEstimatedAddress(...)` reads.
- `ReverseGeocoderResultTypes` keyed road/POI/intersection lookups and estimated-address fetch now route through infrastructure helper `RealmReverseGeocoderLookup` instead of direct non-infrastructure `SpatialDataCache` access in geocoder result models.
- `DynamicLaunchViewController` and `ReverseGeocoderResultTypes` now consume non-infrastructure bootstrap/lookup adapters (`SpatialSearchBootstrap`, `ReverseGeocoderLookup`) from `Data/Spatial Data`, removing direct `Realm*` infrastructure helper references from UI/behavior layers.
- Marker/route SwiftUI preview providers (`WaypointAddList`, `MarkersAndRoutesList`, `MarkersList`, `MarkerCell`, `RouteCell`) now consume non-infrastructure sample adapter `SpatialPreviewSamples` from `Data/Spatial Data` instead of direct `RealmSampleDataBootstrap`/`RealmReferenceEntity.sample*` references.
- `SpatialPreviewSamples` marker-ID helpers now route through infrastructure helper `RealmPreviewSamples` so non-infrastructure adapter code no longer references `RealmReferenceEntity.sample*` directly.
- Marker/route SwiftUI preview and host environment wiring (`WaypointAddList`, `MarkersAndRoutesList`, `MarkersAndRoutesListHostViewController`) now routes `\.realmConfiguration` through non-infrastructure adapter `SpatialPreviewEnvironment` instead of direct `RealmHelper.databaseConfig` usage in Visual UI.
- `AppDelegate` startup migration now routes through non-infrastructure adapter `SpatialDataMigration.migrateIfNeeded()` instead of direct `RealmMigrationTools.migrate(database:cache:)` + `RealmHelper` configuration access in app layer startup wiring.
- `LocationDetail.updateLastSelectedDate()` now routes non-marker POI selection updates through infrastructure helper `LocationDetailStoreAdapter.markPOISelected(_:)` instead of direct Visual UI `RealmHelper` cache writes, and the unused `LocationDetail.init(marker: RealmReferenceEntity, ...)` overload was removed.
- Removed unused app-layer universal-link helper `UniversalLinkManager.shareMarker(_ marker: RealmReferenceEntity)`; marker sharing continues through POI/location entry points (`shareEntity`, `shareLocation`).
- App/runtime marker cloud-sync dispatch now carries canonical `ReferenceEntity` values across `ReferenceEntityRuntimeProviding`, `AppContextDataRuntimeProviders`, and `CloudKeyValueStore+Markers`; Realm object conversion is kept infrastructure-local via `RealmReferenceEntity.domainEntity`.
- Some compatibility paths are still sync today because they sit behind sync callout/rendering helpers or model convenience APIs.
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

## Immediate Next Steps
1. Continue API ingress consolidation by migrating remaining sync-heavy compatibility reads (for example preview destination presentation paths) to async producer pre-resolution or contract-backed async boundaries where call chains can absorb async, while keeping compatibility fallbacks infrastructure-local.
2. Keep strict guardrail enforcement in place (`SpatialDataStoreRegistry.store`, `SpatialDataCache`, `RealmSwift`, and contract infra-type boundaries) while reducing compatibility fallbacks.
3. Refresh dependency-analysis artifacts from deterministic index builds and continue tracking edge deltas (`Data -> App`, `Data -> Visual UI`, `Behaviors -> Visual UI`) in plan updates.
