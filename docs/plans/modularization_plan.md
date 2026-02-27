<!-- Copyright (c) Soundscape Community Contributers. -->

# Modularization Plan

Last updated: 2026-02-27

## Summary
Modularize the iOS codebase incrementally to maximize platform-agnostic reuse for future multi-platform clients. Extract leaf modules first, enforce strict boundaries, and keep behavior changes out of structural moves.

## Scope
In scope:
- Shared Swift package at `apps/common` with platform-neutral targets.
- Incremental extraction of low-level modules from `apps/ios/GuideDogs/Code`.
- Test coverage for new shared targets using Swift Testing.

Out of scope (for early phases):
- Localization/resource migration.
- Large behavior pipeline refactors beyond boundary prep.

## Plan Execution Rules
- After each plan step is implemented and validation checks/tests pass, stage and commit that scoped slice before proceeding to the next plan step.

## Boundary Rules
- `apps/common/Sources` must stay platform-agnostic.
- No imports of Apple UI/platform frameworks in `apps/common/Sources`.
- iOS app targets may depend on `apps/common`; never the reverse.
- Validate boundaries with `bash apps/common/Scripts/check_forbidden_imports.sh`.

## Model and API Policy
- Prefer readable canonical domain/value models over DTO proliferation.
- Keep app-facing API naming and shapes as stable as possible for client code; only introduce breaking churn when required for modularization boundaries or async correctness.
- Route direction: exposed `Route` remains the canonical app-facing type and should be a `struct`; Realm-backed route object types are infrastructure-only and should use explicit Realm-prefixed names (for example `RealmRoute`).
- Add abstractions/patterns only when they improve readability, organization, and local reasoning; avoid unnecessary patterns from unrelated problem domains.

## Current Status
Phase 1 complete:
- Shared package created: `apps/common/Package.swift`.
- Module extracted: `SSDataStructures`.
- Module extracted: `SSGeo`.
- Extracted types moved from iOS app code:
  - `BoundedStack`, `LinkedList`, `Queue`, `CircularQuantity`, `ThreadSafeValue`, `Token`, `Array+CircularQuantity`.
- New portable geo types introduced in common package:
  - `SSGeoCoordinate`, `SSGeoLocation`, `SSGeoMath`.
- Package test target added:
  - `apps/common/Tests/SSDataStructuresTests`.
  - `apps/common/Tests/SSGeoTests`.
- CI updated to run common boundary check + package tests before iOS build/test.

## Progress Updates
- 2026-02-06 to 2026-02-10: Phase 1 extraction completed (`SSDataStructures`, `SSGeo`) with Swift package tests and common forbidden-import boundary enforcement.
- 2026-02-10: Route modularization baseline established: app-facing `Route` remains a value type, Realm persistence model is `RealmRoute`, and mapping is confined to infrastructure.
- 2026-02-06 to 2026-02-10: Core runtime seam-carving completed for Data/Behaviors by replacing direct `AppContext.shared` reads with provider registries and dispatch tests.
- 2026-02-09 to 2026-02-10: Data layering guardrails were added and wired to CI (`check_spatial_data_cache_seam.sh`, `check_realm_infrastructure_boundary.sh`, `check_data_contract_boundaries.sh`, `check_data_contract_infra_type_allowlist.sh`, `check_route_mutation_seam.sh`).
- 2026-02-09 to 2026-02-11: Async-first data contracts were stabilized (`SpatialReadContract`, `SpatialWriteContract`, `SpatialMaintenanceWriteContract`) with Realm adapters; production compatibility read/write surfaces were removed.
- 2026-02-10: Added non-Realm contract behavior coverage (`InMemorySpatialContractStoreTests`) to keep contract behavior testable independently of Realm.
- 2026-02-18 to 2026-02-19: Destination set/clear and temporary marker flows migrated to async-first seams, including startup and cache-reset cleanup paths.
- 2026-02-19: Destination POI/metadata seams were introduced and adopted by app-facing callers to reduce dependence on full `RealmReferenceEntity` reads.
- 2026-02-19: Destination tile-selection seam now uses coordinate input (`destinationCoordinate`) instead of Realm entities.
- 2026-02-19: Removed `DestinationManagerProtocol.destination` and `DestinationEntityStore.referenceEntity(forReferenceID:)` from app-facing surfaces; `DestinationManager.isDestination(key:)` now uses `destinationEntityKey(forReferenceID:)`.
- 2026-02-19: Destination infrastructure adapter reads/mutations now dispatch through focused `SpatialDataStore` destination seams (POI/metadata/entity-key/select/temp) instead of direct full-entity lookups; destination tutorial pages were migrated from `referenceEntity` reads to destination POI/metadata seams with added dispatch coverage in `RouteStorageProviderDispatchTests`.
- 2026-02-19: Current destination-slice validation baseline is green across common package checks, iOS seam/boundary scripts, localization linting, `xcodebuild build-for-testing`, and targeted suites (`RouteStorageProviderDispatchTests`, `DataContractRegistryDispatchTests`, `CloudSyncContractBridgeTests`, `DestinationManagerTest`, `EventProcessorTest`, `DataRuntimeProviderDispatchTests`).
- 2026-02-19: First-waypoint hydration precedence is now aligned as payload-first with async read fallback across cloud route import and `RouteParametersHandler` through shared `Route` helpers; targeted parity coverage was added in `CloudSyncContractBridgeTests` and `RouteStorageProviderDispatchTests`.
- 2026-02-19: Spatial write defaults are now split by responsibility in `DataContractRegistry` (`RealmSpatialWriteContract` for route/marker mutations, `RealmSpatialMaintenanceWriteContract` for maintenance-only operations), with dispatch tests updated to enforce the default adapter boundary.
- 2026-02-19: Cloud import entry points were moved from `SpatialWriteContract` to `SpatialMaintenanceWriteContract`, and cloud sync callers (`CloudKeyValueStore+Routes`, `CloudKeyValueStore+Markers`) now route imports through maintenance-scoped contracts with updated bridge/dispatch coverage.
- 2026-02-24: Destination beacon UI flows were tightened to use focused destination seams (`DestinationManager.destinationPOI`/`destinationIsTemporary`) instead of full `ReferenceEntity` reads in `BeaconDetailStore` and `BeaconActionHandler`, preserving behavior while reducing app-facing full-entity dependency.
- 2026-02-24: Destination beacon callout playback now resolves destination POI data through `SpatialDataStore.destinationPOI(forReferenceID:)` in `DestinationCallout` instead of app-facing `ReferenceEntity` lookups, preserving existing beacon callout behavior for automatic, preview, and geofence-triggered flows.
- 2026-02-24: Validation baseline for this slice is green across common boundary/package checks, iOS seam guardrail scripts, `xcodebuild build-for-testing`, and targeted suites (`DestinationManagerTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-24: Destination callout seam validation is green across common checks (`check_forbidden_imports.sh`, `swift test --package-path apps/common`), iOS lint/guardrails (`LocalizationLinter`, seam boundary scripts), `xcodebuild build-for-testing`, and targeted suites (`DestinationManagerTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-24: Preview destination beacon update flow now resolves the active destination through `SpatialDataStore.destinationPOI(forReferenceID:)` in `PreviewBehavior` instead of reading full `ReferenceEntity` data, preserving preview beacon distance/arrival callouts while further reducing app-facing full-entity dependencies.
- 2026-02-24: Preview destination-seam validation is green across common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, and targeted suites (`PreviewGeneratorTests`, `UIRuntimeProviderDispatchTests`).
- 2026-02-24: `LocationDetail.beaconId` now prefers destination manager seams (`isDestination(key:)` + `destinationKey`) for entity-backed location details, keeping coordinate/design-data fallback behavior while reducing destination checks that depended on marker entity resolution.
- 2026-02-24: Location-detail destination-seam validation is green across common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, and targeted suites (`LocationActionHandlerTests`, `UIRuntimeProviderDispatchTests`).
- 2026-02-24: Marker callout-history cleanup in `AppContext` now matches marker-backed POI callouts by marker ID/entity-key seams (`destinationEntityKey(forReferenceID:)`) instead of resolving full callout marker entities, reducing app-facing full-entity dependency in history maintenance paths.
- 2026-02-24: History-cleanup seam validation is green across common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, and targeted suites (`DataRuntimeProviderDispatchTests`, `UIRuntimeProviderDispatchTests`).
- 2026-02-24: Search recent-callout hydration now resolves route waypoint arrivals through `WaypointArrivalCallout.waypoint.source.entity` in `SearchResultsTableViewController`, removing app-facing `SpatialReadContract.referenceEntity(byID:)` full-entity reads from this history path.
- 2026-02-24: Recent-callout hydration seam validation is green across common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, and targeted suites (`UIRuntimeProviderDispatchTests`, `LocationActionHandlerTests`, `DataRuntimeProviderDispatchTests`).
- 2026-02-24: Marker-list location actions now hydrate selected marker POIs through `LocationDetail(markerId:)` + `LocationDetail.Source.entity` in `MarkersList`, removing app-facing `SpatialReadContract.referenceEntity(byID:)` full-entity reads from that UI action path.
- 2026-02-24: Marker-list seam validation is green across common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, and targeted suites (`UIRuntimeProviderDispatchTests`, `LocationActionHandlerTests`, `DataRuntimeProviderDispatchTests`).
- 2026-02-24: `LocationActionHandler.save(locationDetail:)` now verifies persisted marker existence via `SpatialReadContract.referenceMetadata(byID:)` instead of `referenceEntity(byID:)`, tightening an app-facing write path away from full-entity reads while preserving save-failure behavior.
- 2026-02-24: Location-action save seam validation is green across common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, and targeted suites (`LocationActionHandlerTests`, `DataRuntimeProviderDispatchTests`, `UIRuntimeProviderDispatchTests`).
- 2026-02-24: `AutoCalloutGenerator` route-waypoint and marker-added paths now resolve marker entity-key/temporary state through focused `SpatialDataStore` seams (`destinationEntityKey(forReferenceID:)`, `destinationIsTemporary(forReferenceID:)`) instead of app-facing full marker entity reads.
- 2026-02-24: Auto-callout seam validation is green across common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, and targeted suites (`EventProcessorTest`, `DataRuntimeProviderDispatchTests`, `UIRuntimeProviderDispatchTests`).
- 2026-02-24: `LocationDetail` marker hydration/selection paths now use focused store seams (`destinationPOI(forReferenceID:)`, `markReferenceEntitySelected(forReferenceID:)`) in place of direct full marker-entity fetches, preserving marker detail initialization and last-selected updates.
- 2026-02-24: Location-detail marker seam validation is green across common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, and targeted suites (`LocationActionHandlerTests`, `DataRuntimeProviderDispatchTests`, `UIRuntimeProviderDispatchTests`).
- 2026-02-24: `MarkerCell` list hydration now resolves marker display/distance fields through `LocationDetail(markerId:)` + POI/location-detail surfaces instead of app-facing `SpatialReadContract.referenceEntity(byID:)`, reducing full-entity dependency in marker-list display updates.
- 2026-02-24: Marker-cell seam validation is green across common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, and targeted suites (`LocationActionHandlerTests`, `DataRuntimeProviderDispatchTests`, `UIRuntimeProviderDispatchTests`).
- 2026-02-24: POI table-cell marker rendering now routes through `LocationDetail(entity:)` surfaces in `POITableViewCellConfigurator` (marker detection/name/address/icon) instead of app-facing `referenceEntityByEntityKey(...).domainEntity` reads, preserving marker-vs-place presentation while reducing full-entity dependency in list-cell hydration.
- 2026-02-24: POI table-cell seam validation is green across common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, and targeted suites (`LocationActionHandlerTests`, `DataRuntimeProviderDispatchTests`, `UIRuntimeProviderDispatchTests`).
- 2026-02-24: Auto-callout marker-existence checks now use focused `SpatialDataStore.hasReferenceEntity(forEntityKey:)` seams in `AutoCalloutGenerator` (`GenericGeocoderResult` marker/landmark gate and category-disabled marker bypass) instead of app-facing full entity fetches used only for existence checks.
- 2026-02-24: Auto-callout marker-existence seam validation is green across common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, and targeted suites (`EventProcessorTest`, `UIRuntimeProviderDispatchTests`, `DataRuntimeProviderDispatchTests`).
- 2026-02-24: Data storage API review snapshot from fresh dependency analysis (`7d741fa`) confirmed persistent split ingress (`DataContractRegistry`, `SpatialDataStoreRegistry`, `DestinationEntityStore`) and Realm-bound domain model leakage; added `docs/plans/data_storage_api_north_star.md` to define a single app-facing contract direction before additional seam slices.
- 2026-02-24: Preview destination beacon context lookup in `PreviewBehavior` now resolves through `DataContractRegistry.spatialRead` (`referenceEntity(byID:)` + `poi(byKey:)`) instead of direct `SpatialDataStoreRegistry.store.destinationPOI(...)`, reducing one non-infrastructure storage-registry ingress point while preserving preview beacon distance/arrival behavior.
- 2026-02-24: Added staged guardrail to `check_spatial_data_cache_seam.sh` so non-infrastructure `SpatialDataStoreRegistry.store` usage must stay within an explicit allowlist while migration to contract ingress proceeds.
- 2026-02-24: `AutoCalloutGenerator` waypoint-arrival and marker-added flows now resolve marker state through `DataContractRegistry.spatialRead.referenceEntity(byID:)` and validate marker POIs through `DataContractRegistry.spatialRead.poi(byKey:)`, replacing direct destination/entity-key store reads in those paths while preserving callout cancellation and temporary-marker behavior.
- 2026-02-24: Auto-callout contract-ingress validation is green across common checks (`check_forbidden_imports.sh`, `swift test --package-path apps/common`), iOS lint/guardrails (all seam boundary scripts including realm/route checks), `xcodebuild build-for-testing`, and targeted suites (`EventProcessorTest`, `BehaviorEventStreamsTest`, `RouteStorageProviderDispatchTests`, `DataContractRegistryDispatchTests`).
- 2026-02-24: Refreshed dependency-analysis artifact from the same validation build index store (`docs/plans/artifacts/dependency-analysis/latest.txt`, report `20260224-210029Z-ssindex-9cb6701.txt`) to keep edge-baseline tracking current for this slice.
- 2026-02-24: `AppContextDataRuntimeProviders.referenceRemoveCalloutHistoryForMarkerID(_:)` now resolves destination marker entity keys through `DestinationManagerProtocol.destinationEntityKey(forReferenceID:)` instead of direct `SpatialDataStoreRegistry.store` access, keeping callout-history cleanup behavior while reducing a non-infrastructure storage-registry ingress point.
- 2026-02-24: Added `DestinationManagerProtocol.destinationEntityKey(forReferenceID:)` and updated the staged seam guardrail allowlist to remove `AppContext.swift`; validation is green across common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, and targeted suites (`DataRuntimeProviderDispatchTests`, `DestinationManagerTest`, `EventProcessorTest`, `RouteStorageProviderDispatchTests`).
- 2026-02-24: `DestinationCallout` now consumes pre-resolved POI context (`storedPOI`) supplied by beacon/destination event producers instead of reading destination POIs via `SpatialDataStoreRegistry.store` inside the callout, reducing non-infrastructure storage-registry ingress in beacon/preview callout rendering.
- 2026-02-24: Beacon event payloads now carry optional destination POI context (`BeaconChangedEvent.destinationPOI`, `BeaconCalloutEvent.destinationPOI`) from `DestinationManager`/beacon generators, and the staged seam guardrail allowlist removes `DestinationCallout.swift`; validation is green across common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, and targeted suites (`DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`, `DataRuntimeProviderDispatchTests`).
- 2026-02-24: `ExplorationGenerator` nearby-marker callout hydration now resolves required marker entities through `DataContractRegistry.spatialRead.referenceEntity(byEntityKey:)` in async flow (`makeCallouts`/`getCalloutsForMarkers`), removing non-infrastructure `SpatialDataStoreRegistry.store` usage while preserving marker-inclusion and duplicate-filtering behavior.
- 2026-02-24: Exploration contract-ingress validation is green across common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, and targeted suites (`EventProcessorTest`, `BehaviorEventStreamsTest`, `BehaviorRuntimeProviderDispatchTests`); staged seam allowlist now removes `ExplorationGenerator.swift`.
- 2026-02-24: Route serialization ingress for `RouteParameters.encode(from: RouteDetail, ...)` now resolves database-backed routes through `DataContractRegistry.spatialRead.route(byKey:)` (async) instead of direct `SpatialDataStoreRegistry.store.routeByKey(...)`, reducing a non-infrastructure storage-registry ingress point in route export helpers.
- 2026-02-24: Route-serialization contract-ingress validation is green across common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, and targeted suites (`RouteStorageProviderDispatchTests`, `DataContractRegistryDispatchTests`); staged seam allowlist now removes `RouteParameters+Codable.swift`.
- 2026-02-24: `LocationParameters` OSM cache lookup now resolves cached entities through `DataContractRegistry.spatialRead.poi(byKey:)` before fallback cache insertion, removing direct `SpatialDataStoreRegistry.store.searchByKey(...)` ingress in universal-link marker/location hydration.
- 2026-02-24: Location-parameters contract-ingress validation is green across iOS seam guardrails, `xcodebuild build-for-testing`, and targeted suites (`RouteStorageProviderDispatchTests`, `DataContractRegistryDispatchTests`); staged seam allowlist now removes `LocationParameters.swift`.
- 2026-02-24: Data API north-star checkpoint updated with explicit policy for remaining sync-heavy callers: keep async-first contracts as the only app-facing ingress and avoid introducing a parallel sync read protocol; migrate via async producer pre-resolution or targeted async boundary conversion.
- 2026-02-25: `MarkerParameters` now routes marker/POI hydration through `LocationDetail` seam surfaces (`LocationDetail(markerId:)`, `LocationDetail(entity:)`, `LocationDetail.Source.entity`, `LocationDetail.lastUpdatedDate`) instead of direct `SpatialDataStoreRegistry.store` calls, removing non-infrastructure storage-registry ingress from marker serialization helpers while preserving sync callsites.
- 2026-02-25: Marker-parameters seam validation is green across common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, and targeted suites (`RouteStorageProviderDispatchTests`, `DataContractRegistryDispatchTests`); staged seam allowlist now removes `MarkerParameters.swift`.
- 2026-02-25: `Roundabout` intersection-region hydration now filters `road.intersections` with an `MKCoordinateRegion` helper instead of direct `SpatialDataStoreRegistry.store.intersections(...)` access, reducing one additional non-infrastructure storage-registry ingress point in road-preview logic.
- 2026-02-25: Roundabout seam validation is green across iOS seam guardrails, `xcodebuild build-for-testing`, and targeted suites (`IntersectionDistanceTests`, `RouteStorageProviderDispatchTests`); staged seam allowlist now removes `Roundabout.swift`.
- 2026-02-25: `POICallout` now consumes pre-resolved POI/marker context (`POICallout(..., poi: marker:)`) from behavior producers instead of reading POIs/markers via `SpatialDataStoreRegistry.store` inside the callout, removing non-infrastructure storage-registry ingress from shared POI callout rendering while preserving marker naming/annotation behavior.
- 2026-02-25: POICallout seam validation is green across iOS seam guardrails, `xcodebuild build-for-testing`, and targeted suites (`EventProcessorTest`, `BehaviorEventStreamsTest`); staged seam allowlist now removes `POICallout.swift`.
- 2026-02-25: `AutoCalloutGenerator` marker-existence gates now consume marker context from the current `SpatialDataView` (`markedPoints`) in both road-sense and category-filtering paths, removing direct `SpatialDataStoreRegistry.store.hasReferenceEntity(...)` lookups while preserving marker bypass behavior for disabled categories.
- 2026-02-25: Auto-callout contract-ingress validation is green across iOS seam guardrails, `xcodebuild build-for-testing`, and targeted suites (`EventProcessorTest`, `BehaviorEventStreamsTest`); staged seam allowlist now removes `AutoCalloutGenerator.swift`.
- 2026-02-25: `SpatialDataView` now receives pre-resolved tile/marker/generic-location payloads from `SpatialDataContext` instead of reading `SpatialDataStoreRegistry.store` directly, moving store-backed lookup mechanics into infrastructure while preserving `SpatialDataViewProtocol` behavior.
- 2026-02-25: Spatial-data-view seam validation is green across iOS seam guardrails, `xcodebuild build-for-testing`, and targeted suites (`PreviewGeneratorTests`, `UIRuntimeProviderDispatchTests`); staged seam allowlist now removes `SpatialDataView.swift`.
- 2026-02-25: `Road` now declares intersection lookup requirements (`intersections`, `intersection(atCoordinate:)`) while default store-backed implementations live in infrastructure (`RealmSpatialReadContract.swift`), removing direct `SpatialDataStoreRegistry.store` usage from `Road.swift` and keeping sync road helpers stable for callers like `Roundabout`/`IntersectionFinder`.
- 2026-02-25: Road seam validation is green across iOS seam guardrails, `xcodebuild build-for-testing`, and targeted suites (`DataContractRegistryDispatchTests`, `PreviewGeneratorTests`); staged seam allowlist now removes `Road.swift`.
- 2026-02-25: `RoadAdjacentDataView` marker hydration/callout lookups now route through infrastructure adapter helpers (`RoadAdjacentDataStoreAdapter` in `RealmSpatialReadContract.swift`) instead of direct `SpatialDataStoreRegistry.store` usage in preview-layer code, preserving sync preview APIs while moving storage ingress to infrastructure.
- 2026-02-25: Road-adjacent seam validation is green across iOS seam guardrails, `xcodebuild build-for-testing`, and targeted suites (`DataContractRegistryDispatchTests`, `PreviewGeneratorTests`); staged seam allowlist now removes `RoadAdjacentDataView.swift`.
- 2026-02-25: `LocationDetail` entity/marker lookup and marker-selection writes now route through infrastructure adapter helpers (`LocationDetailStoreAdapter` in `RealmSpatialWriteContract.swift`) instead of direct `SpatialDataStoreRegistry.store` usage, preserving existing sync `LocationDetail` APIs while removing the final non-infrastructure storage-registry ingress.
- 2026-02-25: Location-detail seam validation is green across iOS seam/boundary guardrails (including realm boundary + route seam checks), `xcodebuild build-for-testing`, and targeted suites (`LocationActionHandlerTests`, `UIRuntimeProviderDispatchTests`, `DataRuntimeProviderDispatchTests`); staged `SpatialDataStoreRegistry.store` allowlist is now empty.
- 2026-02-25: `ReferenceEntity` domain value model moved out of `Data/Infrastructure/Realm` into `Data/Models/Temp Models/ReferenceEntity.swift`; Realm-specific persistence/runtime behavior now lives in `RealmReferenceEntity.swift`, keeping app-facing canonical type naming stable while tightening Realm boundary isolation.
- 2026-02-25: Reference-entity extraction slice validation is green across iOS seam/boundary guardrails (`check_spatial_data_cache_seam.sh`, `check_realm_infrastructure_boundary.sh`, `check_data_contract_boundaries.sh`, `check_data_contract_infra_type_allowlist.sh`, `check_route_mutation_seam.sh`) and `xcodebuild build-for-testing`.
- 2026-02-25: `Route` and `RouteWaypoint` canonical value models moved out of `Data/Infrastructure/Realm` into `Data/Models/Temp Models` (`Route.swift`, `RouteWaypoint.swift`); Realm persistence/runtime types and mappings now live in infrastructure files (`RealmRoute.swift`, `RealmRouteWaypoint.swift`) while preserving existing app-facing names/behavior.
- 2026-02-25: Route model extraction slice validation is green across common checks (`check_forbidden_imports.sh`, `swift test --package-path apps/common`), iOS lint/guardrails (all seam boundary scripts including realm/route checks), and `xcodebuild build-for-testing`.
- 2026-02-25: `LocationDetail` now has a contract-backed async marker loader (`LocationDetail.load(markerId:)`) and carries pre-resolved marker/entity context so async-loaded marker details can avoid immediate sync adapter fallback; async-capable marker flows (`MarkerModel`, `MarkersList` location-action lookup, `EditMarkerView` post-save refresh, `LocationDetailViewController` marker-update refresh) were migrated to this boundary while preserving existing sync APIs for compatibility paths.
- 2026-02-25: Async location-detail seam validation is green across common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, and targeted suites (`LocationActionHandlerTests`, `UIRuntimeProviderDispatchTests`, `DataRuntimeProviderDispatchTests`).
- 2026-02-26: Additional async marker-detail call sites were migrated to contract ingress (`LocationDetail.load(markerId:)`) in marker/waypoint UI flows: `MarkersList` edit/detail selection, `SearchWaypointViewController.addedMarker(id:)`, and `WaypointAddListViewModel` marker-list hydration now load marker detail asynchronously instead of sync `LocationDetail(markerId:)`.
- 2026-02-26: `MarkerParameters` now prefers pre-resolved `LocationDetail.entity` for `.entity` source serialization, and NaviLens action/callout checks (`LocationAction`, `BeaconToolbarView`, `DestinationCallout`) now consume `LocationDetail.hasNaviLens` to align with pre-resolved entity context.
- 2026-02-26: This follow-on location-detail ingress slice is green across iOS seam guardrails, `xcodebuild build-for-testing`, and targeted suites (`EventProcessorTest`, `BehaviorEventStreamsTest`, `LocationActionHandlerTests`, `UIRuntimeProviderDispatchTests`, `DataRuntimeProviderDispatchTests`).
- 2026-02-26: Route persistence first-waypoint hydration now resolves through async contract-backed waypoint detail loading (`RouteWaypoint.locationDetail(using:)` and `RouteWaypoint.locationDetails(using:)`) in `RealmRoute`, `Route+Realm`, and `RealmSpatialWriteContract`, with sync `LocationDetail(markerId:)` fallback retained inside the waypoint helper for compatibility with persisted marker paths.
- 2026-02-26: `MarkerParameters.init(markerId:)` now resolves marker context through destination POI seam lookup (`LocationDetailStoreAdapter.destinationPOI(forReferenceID:)` + `LocationDetail(entity:)`) so marker-parameter hydration keeps destination-focused contract behavior while remaining independent from direct sync marker lookup.
- 2026-02-26: Route async-hydration validation is green across iOS seam guardrails, `xcodebuild build-for-testing`, and targeted suites (`RouteStorageProviderDispatchTests`, `DataContractRegistryDispatchTests`, `CloudSyncContractBridgeTests`).
- 2026-02-26: `RoadAdjacentDataView` now carries marker callout context resolved during path scanning (`adjacentCalloutData`) and generates adjacent marker callouts from that in-memory context, removing the second sync marker re-hydration lookup that previously flowed through `RoadAdjacentDataStoreAdapter.markerCalloutData(...)`.
- 2026-02-26: Road-adjacent preview slice validation is green across iOS seam guardrails (`check_spatial_data_cache_seam.sh`, `check_realm_infrastructure_boundary.sh`, `check_data_contract_boundaries.sh`, `check_data_contract_infra_type_allowlist.sh`, `check_route_mutation_seam.sh`), `xcodebuild build-for-testing`, and targeted suites (`PreviewGeneratorTests`, `DataContractRegistryDispatchTests`).
- 2026-02-26: Route waypoint import validation now uses `RouteWaypoint.validated(index:markerId:using:)` in `RouteParametersHandler` so marker-id waypoints prefer existing local marker validation and only fall back to async `SpatialReadContract.referenceEntity(byID:)` hydration when needed; reversed-route construction now reuses/reindexes in-memory waypoints instead of recreating them through failable sync marker revalidation.
- 2026-02-26: Route-waypoint validation/refinement slice is green across iOS seam guardrails (`check_spatial_data_cache_seam.sh`, `check_realm_infrastructure_boundary.sh`, `check_data_contract_boundaries.sh`, `check_data_contract_infra_type_allowlist.sh`, `check_route_mutation_seam.sh`), `xcodebuild build-for-testing`, and targeted suites (`RouteStorageProviderDispatchTests`, `DataContractRegistryDispatchTests`, `CloudSyncContractBridgeTests`).
- 2026-02-26: `PreviewBehavior` destination beacon-context lookup now prefers `DestinationManager.destinationPOI` when the requested reference ID matches the active destination key, with existing async contract fallback retained for stale or non-active beacon IDs.
- 2026-02-26: Preview destination-context refinement is green across iOS seam guardrails (`check_spatial_data_cache_seam.sh`, `check_realm_infrastructure_boundary.sh`, `check_data_contract_boundaries.sh`, `check_data_contract_infra_type_allowlist.sh`, `check_route_mutation_seam.sh`), `xcodebuild build-for-testing`, and targeted suites (`PreviewGeneratorTests`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: `PreviewBehavior` destination beacon-context lookup now prefers `DestinationManager.destinationEntityKey(forReferenceID:)` + `SpatialReadContract.poi(byKey:)` before falling back to `SpatialReadContract.referenceEntity(byID:)`, reducing full marker-entity reads for non-active destination-key lookups while preserving generic-location fallback behavior.
- 2026-02-26: Preview destination-entity-key refinement is green across iOS seam guardrails (`check_spatial_data_cache_seam.sh`, `check_realm_infrastructure_boundary.sh`, `check_data_contract_boundaries.sh`, `check_data_contract_infra_type_allowlist.sh`, `check_route_mutation_seam.sh`), `xcodebuild build-for-testing`, and targeted suites (`PreviewGeneratorTests`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: `BeaconActionHandler.createMarker(detail:)` now prefers pre-resolved entity context from `BeaconDetail.locationDetail.entity` when constructing marker-edit `LocationDetail`, with existing `DestinationManager.destinationPOI` fallback retained for compatibility.
- 2026-02-26: Beacon action-handler refinement is green across iOS seam guardrails (`check_spatial_data_cache_seam.sh`, `check_realm_infrastructure_boundary.sh`, `check_data_contract_boundaries.sh`, `check_data_contract_infra_type_allowlist.sh`, `check_route_mutation_seam.sh`), `xcodebuild build-for-testing`, and targeted suites (`UIRuntimeProviderDispatchTests`, `PreviewGeneratorTests`).
- 2026-02-26: `.destinationChanged` notification payloads now include optional destination POI context (`DestinationManager.Keys.destinationPOI`) when a destination is set, and `BeaconDetailStore` now prefers that payload before fallback manager lookup when refreshing non-route beacon detail state.
- 2026-02-26: Destination-notification payload refinement is green across iOS seam guardrails (`check_spatial_data_cache_seam.sh`, `check_realm_infrastructure_boundary.sh`, `check_data_contract_boundaries.sh`, `check_data_contract_infra_type_allowlist.sh`, `check_route_mutation_seam.sh`), `xcodebuild build-for-testing`, and targeted suites (`DestinationManagerTest`, `UIRuntimeProviderDispatchTests`, `PreviewGeneratorTests`).
- 2026-02-26: `BeaconActionHandler.callout(detail:)` now forwards destination POI context via `BeaconCalloutEvent.destinationPOI`, preferring pre-resolved `LocationDetail.entity` with destination-manager fallback for active beacon keys.
- 2026-02-26: Beacon callout-context refinement is green across iOS seam guardrails (`check_spatial_data_cache_seam.sh`, `check_realm_infrastructure_boundary.sh`, `check_data_contract_boundaries.sh`, `check_data_contract_infra_type_allowlist.sh`, `check_route_mutation_seam.sh`), `xcodebuild build-for-testing`, and targeted suites (`EventProcessorTest`, `UIRuntimeProviderDispatchTests`, `PreviewGeneratorTests`).
- 2026-02-26: `PreviewBehavior` now caches optional destination POI context from `.destinationChanged` payloads (`DestinationManager.Keys.destinationPOI`) and prefers that cached context for active beacon-key destination resolution before destination-manager and async contract fallbacks.
- 2026-02-26: Preview destination-payload cache refinement is green across iOS seam guardrails (`check_spatial_data_cache_seam.sh`, `check_realm_infrastructure_boundary.sh`, `check_data_contract_boundaries.sh`, `check_data_contract_infra_type_allowlist.sh`, `check_route_mutation_seam.sh`), `xcodebuild build-for-testing`, and targeted suites (`EventProcessorTest`, `UIRuntimeProviderDispatchTests`, `PreviewGeneratorTests`).
- 2026-02-26: `InteractiveBeaconViewModel` now caches optional destination POI context from `.destinationChanged` payloads (`DestinationManager.Keys.destinationPOI`) and uses that cached POI for bearing/orientation updates before destination-manager fallback.
- 2026-02-26: Interactive-beacon payload-cache refinement is green across iOS seam guardrails (`check_spatial_data_cache_seam.sh`, `check_realm_infrastructure_boundary.sh`, `check_data_contract_boundaries.sh`, `check_data_contract_infra_type_allowlist.sh`, `check_route_mutation_seam.sh`), `xcodebuild build-for-testing`, and targeted suites (`EventProcessorTest`, `UIRuntimeProviderDispatchTests`, `PreviewGeneratorTests`).
- 2026-02-26: `BeaconCalloutGenerator` now caches destination POI context (`destinationPOI`) from `BeaconChangedEvent.destinationPOI` and reuses that cache in beacon callout preparation/configuration (`getCalloutsForBeacon`, `configureDestinationUpdates`) before destination-manager fallback.
- 2026-02-26: Beacon-callout generator destination-context cache refinement is green across iOS seam guardrails (`check_spatial_data_cache_seam.sh`, `check_realm_infrastructure_boundary.sh`, `check_data_contract_boundaries.sh`, `check_data_contract_infra_type_allowlist.sh`, `check_route_mutation_seam.sh`), `xcodebuild build-for-testing`, and targeted suites (`EventProcessorTest`, `UIRuntimeProviderDispatchTests`, `PreviewGeneratorTests`).
- 2026-02-26: `BeaconCalloutGenerator.manualCalloutGroup(for:)` now prefers event payload destination context with cache-backed fallback (`destinationPOI` cache + active destination-manager POI) for `BeaconCalloutEvent` when payload context is not present.
- 2026-02-26: Beacon manual-callout destination-context fallback refinement is green across iOS seam guardrails (`check_spatial_data_cache_seam.sh`, `check_realm_infrastructure_boundary.sh`, `check_data_contract_boundaries.sh`, `check_data_contract_infra_type_allowlist.sh`, `check_route_mutation_seam.sh`), `xcodebuild build-for-testing`, and targeted suites (`EventProcessorTest`, `UIRuntimeProviderDispatchTests`, `PreviewGeneratorTests`).
- 2026-02-26: `.destinationChanged` notification payloads now include optional destination entity-key context (`DestinationManager.Keys.destinationEntityKey`), and `PreviewBehavior` caches/uses that payload for active beacon destination POI resolution before destination-manager entity-key lookup fallback.
- 2026-02-26: Destination-entity-key payload refinement is green across iOS seam guardrails (`check_spatial_data_cache_seam.sh`, `check_realm_infrastructure_boundary.sh`, `check_data_contract_boundaries.sh`, `check_data_contract_infra_type_allowlist.sh`, `check_route_mutation_seam.sh`), `xcodebuild build-for-testing`, and targeted suites (`DestinationManagerTest`, `PreviewGeneratorTests`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: `BeaconActionHandler.createMarker(detail:)` now prefers destination entity-key contract ingress (`DestinationManager.destinationEntityKey(forReferenceID:)` + `SpatialReadContract.poi(byKey:)`) before compatibility fallback to `DestinationManager.destinationPOI` when `BeaconDetail.locationDetail.entity` is unavailable, reducing direct manager-POI dependency in marker-edit hydration.
- 2026-02-26: Beacon create-marker destination-entity-key refinement is green across common checks (`check_forbidden_imports.sh`, `swift test --package-path apps/common`), iOS lint/guardrails (`LocalizationLinter`, seam boundary scripts), `xcodebuild build-for-testing`, and targeted suites (`EventProcessorTest`, `PreviewGeneratorTests`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: `BeaconActionHandler.callout(detail:)` now prefers destination entity-key seam lookup (`DestinationManager.destinationEntityKey(forReferenceID:)` + `LocationDetailStoreAdapter.poi(byKey:)`) before compatibility fallback to `DestinationManager.destinationPOI` when `LocationDetail.entity` context is unavailable for active destination beacons.
- 2026-02-26: Beacon callout destination-entity-key fallback refinement is green across common checks (`check_forbidden_imports.sh`, `swift test --package-path apps/common`), iOS lint/guardrails (`LocalizationLinter`, seam boundary scripts), `xcodebuild build-for-testing`, and targeted suites (`EventProcessorTest`, `PreviewGeneratorTests`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: `InteractiveBeaconViewModel` now caches optional destination entity-key context from `.destinationChanged` payloads (`DestinationManager.Keys.destinationEntityKey`) and prefers `LocationDetailStoreAdapter.poi(byKey:)` resolution before direct destination-manager POI fallback when updating beacon bearing/orientation.
- 2026-02-26: Interactive-beacon destination-entity-key refinement is green across common checks (`check_forbidden_imports.sh`, `swift test --package-path apps/common`), iOS lint/guardrails (`LocalizationLinter`, seam boundary scripts), `xcodebuild build-for-testing`, and targeted suites (`EventProcessorTest`, `PreviewGeneratorTests`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: Added focused keyed destination lookup to `DestinationManagerProtocol` (`destinationPOI(forReferenceID:)`) and updated `BeaconCalloutGenerator` destination hydration paths (`init`, manual callout fallback, beacon-changed fallback, automatic callout fallback, and destination-update filter setup) to prefer keyed destination POI resolution instead of direct `destinationPOI` property reads.
- 2026-02-26: Beacon-callout keyed destination-POI seam refinement is green across common checks (`check_forbidden_imports.sh`, `swift test --package-path apps/common`), iOS lint/guardrails (`LocalizationLinter`, seam boundary scripts), `xcodebuild build-for-testing`, and targeted suites (`EventProcessorTest`, `PreviewGeneratorTests`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: Beacon/preview destination hydration now prefers keyed destination lookup (`DestinationManager.destinationPOI(forReferenceID:)`) in `BeaconActionHandler`, `BeaconDetailStore`, `InteractiveBeaconViewModel`, and the active-destination fallback path in `PreviewBehavior`, reducing remaining direct `destinationPOI` property dependency in sync compatibility flows.
- 2026-02-26: Keyed destination-POI fallback refinement is green across common checks (`check_forbidden_imports.sh`, `swift test --package-path apps/common`), iOS lint/guardrails (`LocalizationLinter`, seam boundary scripts), `xcodebuild build-for-testing`, and targeted suites (`EventProcessorTest`, `PreviewGeneratorTests`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: Refreshed dependency-analysis artifact from a deterministic fresh index build (`/tmp/ss-index-derived`) via `export_analysis_report.sh` (`20260226-114625Z-ssindex-4aab0d0.txt`; `latest.txt`), showing continued decoupling trend on tracked edges: `Data -> App` `682 -> 278`, `Data -> Visual UI` `80 -> 66`, `Behaviors -> Visual UI` `211 -> 126`.
- 2026-02-26: `SpatialReadContract` no longer includes unused road-graph/tile-data methods returning infrastructure types (`Intersection`, `TileData`); `RealmSpatialReadContract` dropped those app-facing contract entry points while retaining infrastructure-local road helpers.
- 2026-02-26: `check_data_contract_infra_type_allowlist.sh` now runs with an empty temporary allowlist and reports zero Realm infrastructure model type references under `Data/Contracts`.
- 2026-02-26: Contract leakage removal validation is green across common checks (`check_forbidden_imports.sh`, `swift test --package-path apps/common`), iOS lint/guardrails (`LocalizationLinter`, seam boundary scripts), `xcodebuild build-for-testing`, and targeted suites (`RouteStorageProviderDispatchTests`, `DataContractRegistryDispatchTests`, `CloudSyncContractBridgeTests`).
- 2026-02-26: Onboarding destination callout and destination tutorial-page hydration now use keyed destination lookup (`DestinationManager.destinationPOI(forReferenceID:)`) in `OnboardingCalloutGenerator` and `DestinationTutorialPage`, removing direct `destinationPOI` property reads in these onboarding/tutorial compatibility paths.
- 2026-02-26: Onboarding keyed-destination lookup refinement is green across common checks (`check_forbidden_imports.sh`, `swift test --package-path apps/common`), iOS lint/guardrails (`LocalizationLinter`, seam boundary scripts), `xcodebuild build-for-testing`, and targeted suites (`EventProcessorTest`, `UIRuntimeProviderDispatchTests`, `DestinationManagerTest`).
- 2026-02-26: `BeaconDemoHelper.prepare(disableMelodies:)` now resolves destination snapshot POI context through keyed lookup (`DestinationManager.destinationPOI(forReferenceID:)`) when a destination key is active, reducing one more direct `destinationPOI` property dependency in onboarding/demo compatibility flows.
- 2026-02-26: Beacon-demo keyed-destination lookup refinement is green across common checks (`check_forbidden_imports.sh`, `swift test --package-path apps/common`), iOS lint/guardrails (`LocalizationLinter`, seam boundary scripts), `xcodebuild build-for-testing`, and targeted suites (`EventProcessorTest`, `UIRuntimeProviderDispatchTests`, `DestinationManagerTest`).
- 2026-02-26: `SpatialDataContext` now resolves active destination context (`getDataView`, `updateSpatialDataAsync` destination-tile selection) via keyed destination lookup (`DestinationManager.destinationPOI(forReferenceID:)`) rather than direct `destinationPOI` property reads.
- 2026-02-26: Spatial-data-context keyed-destination lookup refinement is green across common checks (`check_forbidden_imports.sh`, `swift test --package-path apps/common`), iOS lint/guardrails (`LocalizationLinter`, seam boundary scripts), `xcodebuild build-for-testing`, and targeted suites (`RouteStorageProviderDispatchTests`, `DataContractRegistryDispatchTests`, `DestinationManagerTest`).
- 2026-02-26: `DestinationManagerProtocol` no longer exposes `destinationPOI` as a required app-facing property, tightening destination POI access to keyed lookup (`destinationPOI(forReferenceID:)`) for protocol-driven callers.
- 2026-02-26: Destination-manager protocol destination-POI surface tightening is green across common checks (`check_forbidden_imports.sh`, `swift test --package-path apps/common`), iOS lint/guardrails (`LocalizationLinter`, seam boundary scripts), `xcodebuild build-for-testing`, and targeted suites (`EventProcessorTest`, `DestinationManagerTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: `DestinationManager` no longer exposes active-destination POI as a concrete public property; internal current-destination hydration now routes through a private helper (`activeDestinationPOI`) while keyed POI reads stay on `destinationPOI(forReferenceID:)`.
- 2026-02-26: Destination-manager active-POI surface tightening is green across common checks (`check_forbidden_imports.sh`, `swift test --package-path apps/common`), iOS lint/guardrails (`LocalizationLinter`, seam boundary scripts), `xcodebuild build-for-testing`, and targeted suites (`DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: `DestinationManagerProtocol` now exposes keyed destination temporary-state lookup (`destinationIsTemporary(forReferenceID:)`), and destination temporary checks in `BeaconActionHandler`, `BeaconDemoHelper`, and `DestinationManager` startup cleanup now use keyed ID reads instead of active-destination temporary-property access.
- 2026-02-26: Destination temporary-state keyed-lookup refinement is green across common checks (`check_forbidden_imports.sh`, `swift test --package-path apps/common`), iOS lint/guardrails (`LocalizationLinter`, seam boundary scripts), `xcodebuild build-for-testing`, and targeted suites (`DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: `DestinationManagerProtocol` now exposes keyed destination metadata lookup (`destinationNickname(forReferenceID:)`, `destinationEstimatedAddress(forReferenceID:)`), and metadata callers in `AppContext`, `BeaconDemoHelper`, `DestinationTutorialPage`, and `DestinationManager` startup cleanup now use keyed destination ID reads instead of active-destination metadata properties.
- 2026-02-26: Destination metadata keyed-lookup refinement is green across common checks (`check_forbidden_imports.sh`, `swift test --package-path apps/common`), iOS lint/guardrails (`LocalizationLinter`, seam boundary scripts), `xcodebuild build-for-testing`, and targeted suites (`DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: `DestinationManagerProtocol` no longer exposes `isDestinationSet`; protocol-driven callers in `TelemetryHelper`, `RouteGuidance`, `GuidedTour`, `PreviewBehavior`, `AppContext`, and destination tutorial flow now derive destination-set state from `destinationKey != nil`.
- 2026-02-26: Destination-set protocol-surface tightening is green across common checks (`check_forbidden_imports.sh`, `swift test --package-path apps/common`), iOS lint/guardrails (`LocalizationLinter`, seam boundary scripts), `xcodebuild build-for-testing`, and targeted suites (`DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: `DestinationManager` no longer exposes concrete `isDestinationSet`; destination-set assertions and checks now read `destinationKey != nil` directly where concrete manager state is needed.
- 2026-02-26: Destination-manager concrete destination-set surface tightening is green across common checks (`check_forbidden_imports.sh`, `swift test --package-path apps/common`), iOS lint/guardrails (`LocalizationLinter`, seam boundary scripts), `xcodebuild build-for-testing`, and targeted suites (`DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: Expanded `check_realm_infrastructure_boundary.sh` guardrail scope from `GuideDogs/Code/Data/**` to all `GuideDogs/Code/**`, enforcing `RealmSwift` imports to `Data/Infrastructure/Realm/**` with an explicit staged non-infrastructure allowlist for remaining UI files.
- 2026-02-26: Realm boundary-guardrail scope expansion is green (`bash apps/ios/Scripts/ci/check_realm_infrastructure_boundary.sh`) and remains green within the full iOS seam-guardrail validation run.
- 2026-02-26: Marker/route UI preview/bootstrap callers now use infrastructure-local `RealmSampleDataBootstrap.bootstrap()` (in `Samplable.swift`) and no longer import `RealmSwift` directly in non-infrastructure files (`LocationDetailLabelView`, `MarkersAndRoutesList`, `MarkerCell`, `MarkersList`, `RoutesList`, `RouteCell`, `RouteEditView`, `WaypointAddList`).
- 2026-02-26: Realm import boundary guardrail now runs with an empty non-infrastructure allowlist and remains green across full validation (common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, targeted suites `DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: `check_realm_infrastructure_boundary.sh` now enforces strict infrastructure-only `RealmSwift` imports across `GuideDogs/Code/**` and removes staged non-infrastructure allowlist branching from the guardrail script.
- 2026-02-26: Strict Realm import-boundary guardrail enforcement is green across full validation (common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, targeted suites `DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: `check_spatial_data_cache_seam.sh` now enforces strict infrastructure-only `SpatialDataStoreRegistry.store` usage across `GuideDogs/Code/**` and removes staged allowlist branching from the registry guardrail path.
- 2026-02-26: Strict `SpatialDataStoreRegistry.store` guardrail enforcement is green across full validation (common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, targeted suites `DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: `ShareRouteAlertObserver` route-import existence check now uses `DataContractRegistry.spatialRead.route(byKey:)` (async contract ingress) instead of direct `SpatialDataCache.routeByKey(...)` from Notifications-layer alert flow.
- 2026-02-26: Share-route alert ingress refinement is green across full validation (common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, targeted suites `DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: `RouteCell` list-model hydration now uses `DataContractRegistry.spatialRead.route(byKey:)` in `RouteModel.update()` with cancellation-safe task handling instead of direct `SpatialDataCache.routeByKey(...)`.
- 2026-02-26: Route-cell async contract-ingress refinement is green across full validation (common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, targeted suites `DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: `WaypointAddList` preview marker-ID seeding now uses `RealmReferenceEntity.samples` instead of `SpatialDataCache.referenceEntities()`, removing one preview-only non-Data cache ingress.
- 2026-02-26: Waypoint-add preview cache-ingress refinement is green across full validation (common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, targeted suites `DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: `SoundscapeDocumentAlert.shareRoute(_ routeDetail:)` now derives a shareable `Route` from `RouteDetail` values (`displayName`, `description`, `waypoints.asRouteWaypoint`) instead of direct `SpatialDataCache.routeByKey(...)` lookup.
- 2026-02-26: Share-route alert route-derivation refinement is green across full validation (common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, targeted suites `DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: `RouteRecommender` nearby-route hydration now uses `DataContractRegistry.spatialRead.routes()` (async contract ingress) with in-memory nearby-distance filtering (5 km) and existing distance/recency sort behavior, replacing direct `SpatialDataCache.routesNear(...)` usage.
- 2026-02-26: Route-recommender async contract-ingress refinement is green across full validation (common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, targeted suites `DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: Added maintenance contract seam `SpatialMaintenanceWriteContract.clearNewReferenceEntitiesAndRoutes()` and migrated `MarkersAndRoutesListHostViewController` to clear marker/route `isNew` flags via `DataContractRegistry.spatialMaintenanceWrite` instead of direct `SpatialDataCache` calls.
- 2026-02-26: Marker/route new-flag cleanup contract-ingress refinement is green across full validation (common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, targeted suites `DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: Marker delete-alert route-name hydration now resolves through `DataContractRegistry.spatialRead.routes(containingMarkerID:)` in `EditMarkerView` and `MarkersList`, and `Alert.deleteMarkerAlert` now receives pre-resolved route names instead of querying `SpatialDataCache.routesContaining(...)`.
- 2026-02-26: Marker delete-alert contract-ingress refinement is green across full validation (common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, targeted suites `DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: `ReverseGeocoderContext` nearest-road helpers now use road-local lookup (`closestRoad.intersection(atCoordinate:)`, in-scope `roads.first(where: { $0.key == stickyRoadKey })`) instead of direct `SpatialDataCache.intersection(...)` / `searchByKey(...)` calls.
- 2026-02-26: Reverse-geocoder nearest-road helper refinement is green across full validation (common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, targeted suites `DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: Intersection arrival/callout flow now carries resolved `Intersection` context in `IntersectionArrivalEvent` and `IntersectionCallout`, removing direct `SpatialDataCache.intersectionByKey(...)` reads in `IntersectionGenerator`, `RouteGuidanceGenerator`, and `TourGenerator`.
- 2026-02-26: Intersection-arrival context-carrying refinement is green across full validation (common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, targeted suites `DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: Launch-time spatial search/bootstrap setup now routes through infrastructure helper `RealmSpatialSearchBootstrap.configureDefaults()` in `DynamicLaunchViewController`, removing direct UI-layer `SpatialDataCache.useDefaultSearchProviders()/useDefaultGeocoder()` calls.
- 2026-02-26: Launch bootstrap helper refinement is green across full validation (common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, targeted suites `DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: Search recents list hydration now uses async contract ingress (`DataContractRegistry.spatialRead.recentlySelectedPOIs()`) via `SearchResultsTableViewController.loadRecentSelections(...)`, removing direct `SpatialDataCache.recentlySelectedObjects()` reads from POI search UI.
- 2026-02-26: Search recents contract-ingress refinement is green across full validation (common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, targeted suites `DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: `EstimatedLocationDetail.make(for:completion:)` now resolves estimated-address metadata through async contract ingress (`DataContractRegistry.spatialRead.estimatedAddress(near:)`), removing direct `SpatialDataCache.fetchEstimatedAddress(...)` from location-detail UI flow.
- 2026-02-26: Estimated-location-detail contract-ingress refinement is green across full validation (common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, targeted suites `DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: `ReverseGeocoderResultTypes` now resolves keyed road/POI/intersection lookups and estimated-address fetch via infrastructure helper `RealmReverseGeocoderLookup` instead of direct non-infrastructure `SpatialDataCache` calls.
- 2026-02-26: Reverse-geocoder lookup helper refinement is green across full validation (common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, targeted suites `DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: Added non-infrastructure bootstrap/lookup adapters (`SpatialSearchBootstrap`, `ReverseGeocoderLookup`) in `Data/Spatial Data`, and migrated `DynamicLaunchViewController` + `ReverseGeocoderResultTypes` to those adapters to avoid direct `Realm*` infrastructure helper references from UI/behavior layers.
- 2026-02-26: Bootstrap/lookup adapter indirection refinement is green across full validation (common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, targeted suites `DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: Added non-infrastructure preview sample adapter `SpatialPreviewSamples` in `Data/Spatial Data`, and migrated marker/route preview providers (`WaypointAddList`, `MarkersAndRoutesList`, `MarkersList`, `MarkerCell`, `RouteCell`) to remove direct `RealmSampleDataBootstrap` / `RealmReferenceEntity.sample*` references from Visual UI previews.
- 2026-02-26: Preview sample adapter refinement is green across full validation (common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, targeted suites `DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: `SpatialPreviewSamples` marker-ID helpers now delegate to infrastructure helper `RealmPreviewSamples`, removing remaining non-infrastructure adapter references to `RealmReferenceEntity.sample*`.
- 2026-02-26: Preview sample helper boundary refinement is green across full validation (common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, targeted suites `DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: Added non-infrastructure preview environment adapter `SpatialPreviewEnvironment` in `Data/Spatial Data`, and migrated marker/route preview + host wiring (`WaypointAddList`, `MarkersAndRoutesList`, `MarkersAndRoutesListHostViewController`) to remove direct `RealmHelper.databaseConfig` usage from Visual UI.
- 2026-02-26: Preview environment adapter refinement is green across full validation (common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, targeted suites `DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: Added non-infrastructure startup migration adapter `SpatialDataMigration` in `Data/Spatial Data`, and migrated `AppDelegate` launch migration setup to remove direct `RealmMigrationTools` + `RealmHelper` usage from app-layer startup wiring.
- 2026-02-26: Startup migration adapter refinement is green across full validation (common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, targeted suites `DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: `LocationDetail.updateLastSelectedDate()` now routes non-marker POI selection updates through `LocationDetailStoreAdapter.markPOISelected(_:)` (infrastructure seam) instead of direct Visual UI `RealmHelper` cache writes, and the unused Realm-specific `LocationDetail` initializer overload was removed.
- 2026-02-26: Location-detail selection-write seam refinement is green across full validation (common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, targeted suites `DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: Removed unused app-layer universal-link helper `UniversalLinkManager.shareMarker(_ marker: RealmReferenceEntity)` to reduce remaining app-surface `RealmReferenceEntity` exposure; sharing entry points remain `shareEntity` / `shareLocation`.
- 2026-02-26: Universal-link helper cleanup is green across full validation (common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, targeted suites `DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: Marker cloud-sync runtime-provider seams (`ReferenceEntityRuntimeProviding`, `AppContextDataRuntimeProviders`, `ReferenceEntityRuntime`, `CloudKeyValueStore+Markers`) now use canonical `ReferenceEntity` instead of `RealmReferenceEntity`; Realm-to-domain conversion is confined to infrastructure call sites.
- 2026-02-26: Marker cloud-sync domain-surface refinement is green across full validation (common checks, iOS lint/guardrails, `xcodebuild build-for-testing`, targeted suites `DestinationManagerTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: `OnboardingCalloutGenerator` now pre-resolves destination POI context through async contract ingress (`DataContractRegistry.spatialRead.poi(byKey:)`) when a destination entity key is available, with keyed destination-manager lookup retained as compatibility fallback for sync destination presentation flows.
- 2026-02-26: Onboarding beacon-callout contract-ingress refinement is green across validation (`check_forbidden_imports.sh`, `swift test --package-path apps/common`, iOS lint/guardrails, `xcodebuild build-for-testing`, targeted suites `BehaviorEventStreamsTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: `InteractiveBeaconViewModel` now pre-resolves destination POI context through async contract ingress (`DataContractRegistry.spatialRead.poi(byKey:)`) on destination changes, with keyed destination-manager lookup retained as compatibility fallback only when contract reads are unavailable.
- 2026-02-26: Interactive-beacon destination hydration contract-ingress refinement is green across validation (`check_forbidden_imports.sh`, `swift test --package-path apps/common`, iOS lint/guardrails, `LocalizationLinter`, `xcodebuild build-for-testing`, targeted suites `BehaviorEventStreamsTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`).
- 2026-02-26: `BeaconActionHandler.callout(detail:)` now pre-resolves destination POI context through async contract ingress (`DataContractRegistry.spatialRead.poi(byKey:)`) when destination entity key context is available, with keyed destination-manager lookup retained as compatibility fallback.
- 2026-02-26: Beacon-action-handler callout contract-ingress refinement is green across validation (`check_forbidden_imports.sh`, `swift test --package-path apps/common`, iOS lint/guardrails, `LocalizationLinter`, `xcodebuild build-for-testing`, targeted suites `BehaviorEventStreamsTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`, `DestinationManagerTest`).
- 2026-02-26: `BeaconDetailStore` now pre-resolves destination POI context through async contract ingress (`DataContractRegistry.spatialRead.poi(byKey:)`) for initial destination-backed beacon hydration and destination-change updates, with keyed destination-manager lookup retained as compatibility fallback.
- 2026-02-26: Beacon-detail-store destination hydration contract-ingress refinement is green across validation (`check_forbidden_imports.sh`, `swift test --package-path apps/common`, iOS lint/guardrails, `LocalizationLinter`, `xcodebuild build-for-testing`, targeted suites `BehaviorEventStreamsTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`, `DestinationManagerTest`).
- 2026-02-26: `BeaconDemoHelper.prepare(disableMelodies:)` is now async and pre-resolves temporary destination POI context through contract ingress (`DataContractRegistry.spatialRead.poi(byKey:)`) when destination entity-key context is available, with keyed destination-manager lookup retained as compatibility fallback; onboarding/settings/edit-marker call sites now await `prepare` via async task boundaries before demo playback.
- 2026-02-26: Beacon-demo prepare contract-ingress refinement is green across validation (`check_forbidden_imports.sh`, `swift test --package-path apps/common`, iOS lint/guardrails, `LocalizationLinter`, `xcodebuild build-for-testing`, targeted suites `BehaviorEventStreamsTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`, `DestinationManagerTest`).
- 2026-02-26: `DestinationTutorialInfoPage.playCallout()` now pre-resolves destination POI context through async contract ingress (`DataContractRegistry.spatialRead.poi(byKey:)`) when destination entity-key context is available, with keyed destination-manager and cached tutorial destination fallbacks retained for compatibility.
- 2026-02-26: Destination-tutorial callout contract-ingress refinement is green across validation (`check_forbidden_imports.sh`, `swift test --package-path apps/common`, iOS lint/guardrails, `LocalizationLinter`, `xcodebuild build-for-testing`, targeted suites `BehaviorEventStreamsTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`, `DestinationManagerTest`).
- 2026-02-26: `DestinationTutorialPage` now pre-resolves destination POI/name context through async contract ingress (`DataContractRegistry.spatialRead.poi(byKey:)`) in `viewWillAppear` when destination entity-key context is available, with keyed destination-manager lookup retained as compatibility fallback for synchronous getters.
- 2026-02-26: Destination-tutorial page hydration contract-ingress refinement is green across validation (`check_forbidden_imports.sh`, `swift test --package-path apps/common`, iOS lint/guardrails, `LocalizationLinter`, `xcodebuild build-for-testing`, targeted suites `BehaviorEventStreamsTest`, `EventProcessorTest`, `UIRuntimeProviderDispatchTests`, `DestinationManagerTest`).
- 2026-02-27: `BeaconCalloutGenerator` now refreshes active destination POI cache through async contract ingress (`DataContractRegistry.spatialRead.poi(byKey:)`) for startup and destination-change flows, and automatic beacon callout hot paths now consume cached destination context instead of repeated sync keyed destination-manager reads.
- 2026-02-27: Beacon-callout generator destination-cache refinement is green across validation (`check_forbidden_imports.sh`, `swift test --package-path apps/common`, iOS lint/guardrails including seam boundary scripts + `LocalizationLinter`, `xcodebuild build-for-testing`, targeted suites `EventProcessorTest`, `PreviewGeneratorTests`, `UIRuntimeProviderDispatchTests`).
- 2026-02-27: Onboarding beacon interaction events (`SelectedBeaconCalloutEvent`, `SelectedBeaconOrientationCalloutEvent`) now carry pre-resolved destination POI payload context from `InteractiveBeaconViewModel`, and `OnboardingCalloutGenerator` now uses that event payload first before resolving destination POI through contract/keyed-manager lookup.
- 2026-02-27: Onboarding beacon payload-context refinement is green across validation (`check_forbidden_imports.sh`, `swift test --package-path apps/common`, iOS lint/guardrails including seam boundary scripts + `LocalizationLinter`, `xcodebuild build-for-testing`, targeted suites `BehaviorEventStreamsTest`, `EventProcessorTest`, `PreviewGeneratorTests`, `UIRuntimeProviderDispatchTests`).
- 2026-02-27: `OnboardingCalloutGenerator` and destination tutorial callout resolution (`DestinationTutorialPage`, `DestinationTutorialInfoPage`) now use contract-only fallback destination lookup (`SpatialReadContract.referenceEntity(byID:)` + `poi(byKey:)` or `GenericLocation(ref:)`) when destination entity-key context is unavailable, removing app-layer keyed destination-manager POI fallback reads from these paths.
- 2026-02-27: Onboarding/tutorial contract-fallback refinement is green across validation (`check_forbidden_imports.sh`, `swift test --package-path apps/common`, iOS lint/guardrails including seam boundary scripts + `LocalizationLinter`, `xcodebuild build-for-testing`, targeted suites `BehaviorEventStreamsTest`, `EventProcessorTest`, `PreviewGeneratorTests`, `UIRuntimeProviderDispatchTests`, `DestinationManagerTest`).
- 2026-02-27: Beacon UI destination-resolution paths (`BeaconActionHandler.createMarker`, `BeaconActionHandler.callout(detail:)`, `BeaconDetailStore` destination hydration, `InteractiveBeaconViewModel` fallback refresh) now use contract-only fallback lookup (`SpatialReadContract.referenceEntity(byID:)` + `poi(byKey:)` or `GenericLocation(ref:)`) when destination entity-key context is unavailable, removing app-layer keyed destination-manager POI fallback reads from these compatibility flows.
- 2026-02-27: Beacon UI contract-fallback refinement is green across validation (`check_forbidden_imports.sh`, `swift test --package-path apps/common`, iOS lint/guardrails including seam boundary scripts + `LocalizationLinter`, `xcodebuild build-for-testing`, targeted suites `BehaviorEventStreamsTest`, `EventProcessorTest`, `PreviewGeneratorTests`, `UIRuntimeProviderDispatchTests`, `DestinationManagerTest`).
- 2026-02-27: `PreviewBehavior.destinationPOI(forReferenceID:)` and `BeaconDemoHelper` temporary-destination snapshot hydration now use contract-only fallback lookup (`SpatialReadContract.referenceEntity(byID:)` + `poi(byKey:)` or `GenericLocation(ref:)`) when destination entity-key context is unavailable, removing keyed destination-manager POI fallback reads from these compatibility flows.
- 2026-02-27: Preview/beacon-demo contract-fallback refinement is green across validation (`check_forbidden_imports.sh`, `swift test --package-path apps/common`, iOS lint/guardrails including seam boundary scripts + `LocalizationLinter`, `xcodebuild build-for-testing`, targeted suites `BehaviorEventStreamsTest`, `EventProcessorTest`, `PreviewGeneratorTests`, `UIRuntimeProviderDispatchTests`, `DestinationManagerTest`).
- 2026-02-27: `BeaconCalloutGenerator.refreshDestinationPOI(for:)` now uses contract-only fallback lookup (`SpatialReadContract.referenceEntity(byID:)` + `poi(byKey:)` or `GenericLocation(ref:)`) when destination entity-key context is unavailable, removing keyed destination-manager POI fallback reads from automatic beacon callout refresh flow.
- 2026-02-27: Beacon-callout contract-fallback refinement is green across validation (`check_forbidden_imports.sh`, `swift test --package-path apps/common`, iOS lint/guardrails including seam boundary scripts + `LocalizationLinter`, `xcodebuild build-for-testing`, targeted suites `BehaviorEventStreamsTest`, `EventProcessorTest`, `PreviewGeneratorTests`, `UIRuntimeProviderDispatchTests`, `DestinationManagerTest`).
- 2026-02-27: `MarkerParameters.init(markerId:)` now hydrates marker context through `LocationDetailStoreAdapter.referenceEntity(byID:)?.getPOI()` instead of `destinationPOI(forReferenceID:)`, removing keyed destination-POI helper usage from route waypoint marker-serialization flow.
- 2026-02-27: Marker-parameters destination-helper refinement is green across validation (`check_forbidden_imports.sh`, `swift test --package-path apps/common`, iOS lint/guardrails including seam boundary scripts + `LocalizationLinter`, `xcodebuild build-for-testing`, targeted suites `RouteStorageProviderDispatchTests`, `BehaviorEventStreamsTest`, `EventProcessorTest`, `PreviewGeneratorTests`, `UIRuntimeProviderDispatchTests`, `DestinationManagerTest`).
- 2026-02-27: Removed now-unused infrastructure adapter helper `LocationDetailStoreAdapter.destinationPOI(forReferenceID:)` after marker-parameter hydration moved to `referenceEntity(byID:)?.getPOI()`.
- 2026-02-27: Location-detail adapter cleanup is green across validation (`check_forbidden_imports.sh`, `swift test --package-path apps/common`, iOS lint/guardrails including seam boundary scripts + `LocalizationLinter`, `xcodebuild build-for-testing`, targeted suite `RouteStorageProviderDispatchTests`).
- 2026-02-27: Refreshed dependency-analysis artifact via deterministic index workflow (`xcodebuild build-for-testing` with `-derivedDataPath /tmp/ss-index-derived` + `export_analysis_report.sh --store-path /tmp/ss-index-derived/Index.noindex/DataStore --top 40 --min-count 2 --file-top 40 --external-top 25`), producing report `20260227-010245Z-ssindex-1a3f1a8` and updating `latest.txt`.

## Architecture Baseline (from index analysis)
- Most coupled hub: `App/AppContext.swift` (high fan-in from `Data`, `Behaviors`, and `Visual UI`).
- Latest tracked reverse-edge snapshot (report `20260227-010245Z-ssindex-1a3f1a8`):
  - `Data -> App`: 279
  - `Behaviors -> Visual UI`: 126
  - `Data -> Visual UI`: 66
  - `Data -> Behaviors`: below top-40 edge threshold in this snapshot
- `Data` currently mixes domain logic with infrastructure concerns (`RealmSwift`, `CoreLocation`, GPX parsing, file I/O).

## Decoupling Plan (Phase 2: Data-First)
### Milestone 0: Measurement and Guardrails
Owner:
- Modularization owner

Tasks:
- Generate and commit/update `docs/plans/artifacts/dependency-analysis/latest.txt` after a fresh iOS build.
- Track edge metrics in PR descriptions for:
  - `Data -> App`
  - `Data -> Visual UI`
  - `Behaviors -> Visual UI`

Acceptance criteria:
- Baseline report artifact exists and is current for the commit.
- Every modularization PR includes before/after edge counts.

### Milestone 1: Service Locator Removal (AppContext seam carving)
Owner:
- App architecture owner

Tasks:
- Replace `AppContext` reads in `Data`/`Behaviors` with narrow protocols (logging, settings, telemetry, clock, feature flags).
- Inject protocol dependencies through initializers/factories.

Acceptance criteria:
- Candidate files in `Data` and `Behaviors` no longer import or reference `AppContext`.
- `Data -> App` edge count decreases from baseline.

### Milestone 2: Internal Data Layer Split (still in iOS target)
Owner:
- Data architecture owner

Tasks:
- Reorganize `Data` into explicit layers:
  - `Data/Domain` (pure value types, entities, business invariants)
  - `Data/Contracts` (repository/query/service protocols, focused request/response value types only where needed, errors)
  - `Data/Infrastructure` (Realm/CoreLocation/GPX/file adapters)
  - `Data/Composition` (wiring only)
- Ban `Visual UI` imports in `Data/Domain` and `Data/Contracts`.
- Do not introduce parallel DTO families for existing readable models; keep canonical names and shapes (for example `Route`) on the app-facing side.

Acceptance criteria:
- Folder structure maps to layers, not mixed responsibilities.
- Analyzer shows `Data -> Visual UI` trending toward zero (target zero by Milestone 4).

### Milestone 3: Async-First Contracts + Storage Ports
Owner:
- Data architecture owner

Tasks:
- Define async protocol surface in `Data/Contracts` for repositories and loaders.
- Use streaming APIs (`AsyncSequence`) only where the domain is naturally continuous/evented; keep one-shot APIs as async request/response.
- Keep cancellation/error semantics explicit (`throws`, timeout/retry policy in call sites).
- Add in-memory implementations for tests to validate contract behavior independent of Realm.

Acceptance criteria:
- New contracts are async-first by default.
- Contract test suite passes against at least one non-Realm implementation.

### Milestone 4: Extract First Shared Modules to `apps/common`
Owner:
- Common module owner

Tasks:
- Create `SSDomain` and `SSDataContracts` in `apps/common`.
- Move platform-neutral models/contracts from iOS `Data` into those modules.
- Add Swift Testing coverage for domain invariants and contract behavior.

Acceptance criteria:
- `apps/common/Sources` remains platform-agnostic (forbidden import check passes).
- iOS target compiles using new shared modules without behavioral changes.

### Milestone 5: Realm Isolation and Replaceable Persistence Adapter
Owner:
- Persistence owner

Tasks:
- Keep all Realm-specific code inside an iOS infrastructure adapter.
- Keep Realm-backed model types infrastructure-local and explicitly named (for example `RealmRoute`), while exposing canonical domain structs (for example `Route`) across contracts/use cases.
- Map adapter models <-> domain models only at adapter boundaries (no Realm types in contracts/use cases).
- Prepare for backend replacement by keeping adapter conformance tests storage-agnostic.

Acceptance criteria:
- `RealmSwift` appears only in adapter/infrastructure layer.
- Swapping persistence backend does not require changing domain/contracts/use cases.

### Milestone 6: Layer Enforcement in CI
Owner:
- Build/CI owner

Tasks:
- Add dependency checks that fail when forbidden edges reappear.
- Gate initial hard failures on:
  - `Data -> Visual UI` must equal `0`
  - `Behaviors -> Visual UI` must equal `0`
- Keep `Data -> App` on staged threshold reduction until composition-only.

Acceptance criteria:
- CI blocks regressions on hard-gated edges.
- Threshold policy is documented and reviewed quarterly.

## GPX Portability Track
Current state:
- GPX logic is cross-cutting and large (`GPXExtensions.swift` plus GPX parser/simulator usage in App/Data/Sensors).
- GPX parsing currently depends on `CoreGPX` in iOS targets.
- `CoreGPX` is treated as an approved hard dependency for future shared/cross-platform Swift code.

Plan:
1. Keep `CoreGPX` direct (no service/protocol adapter layer for GPX parsing).
2. Move cross-platform GPX parsing/transform logic into common modules where feasible, still using `CoreGPX` types/APIs directly.
3. Keep platform integration code (file import hooks, simulator wiring, motion/location integration) in app/platform layers.
4. Add abstractions only where a concrete replacement boundary exists (for example persistence), not around stable readable library usage.

Acceptance criteria:
- Shared GPX code can compile cross-platform while using `CoreGPX` directly.
- Platform-specific GPX integration code is isolated from shared parsing/transform code.
- No extra protocol/service layer introduced solely to wrap `CoreGPX`.

## Immediate Next Steps
1. Continue API ingress consolidation by migrating remaining sync-heavy compatibility reads (for example preview destination presentation paths) to async producer pre-resolution or contract-backed async boundaries where call chains can absorb async, while keeping compatibility fallbacks infrastructure-local.
2. With `ReferenceEntity`, `Route`, and `RouteWaypoint` value models now outside Realm infrastructure, converge their storage-facing adapters behind contract surfaces so these canonical models can be moved into package-ready domain/contracts targets without introducing parallel DTO/protocol families.
3. Keep `SpatialDataStoreRegistry.store` guardrails strict (`Data/Infrastructure/Realm/**` only, allowlist empty) and keep the `Data/Contracts` infrastructure-type allowlist empty by routing any future storage additions through domain/value contract shapes.
4. Continue refreshing dependency-analysis artifacts from deterministic index builds and recording tracked edge deltas (`Data -> App`, `Data -> Visual UI`, `Behaviors -> Visual UI`) in plan updates and PR descriptions.
