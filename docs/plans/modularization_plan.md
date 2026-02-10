# Modularization Plan

Last updated: 2026-02-10

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

## Boundary Rules
- `apps/common/Sources` must stay platform-agnostic.
- No imports of Apple UI/platform frameworks in `apps/common/Sources`.
- iOS app targets may depend on `apps/common`; never the reverse.
- Validate boundaries with `bash apps/common/Scripts/check_forbidden_imports.sh`.

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
- 2026-02-06: Completed first extraction (`SSDataStructures`) and integrated it into iOS target dependencies.
- 2026-02-06: Added boundary enforcement script for forbidden platform imports in `apps/common/Sources`.
- 2026-02-06: Added Swift Testing coverage for extracted data-structure module.
- 2026-02-06: Renamed common module naming to `SS*` convention and updated first module name from `SoundscapeCoreDataStructures` to `SSDataStructures`.
- 2026-02-06: Added `tools/SSIndexAnalyzer/Scripts/export_analysis_report.sh` to generate timestamped dependency reports under `docs/plans/artifacts/dependency-analysis/` for repeatable architecture reviews across chat sessions.
- 2026-02-06: Baseline index analysis showed high coupling into `App/AppContext.swift` and reverse edges (`Behaviors -> Visual UI`), indicating current folders do not enforce clean subsystem boundaries.
- 2026-02-06: Added common module `SSGeo` with portable location payloads and geodesic helpers, plus tests that compare distance accuracy/performance against `CoreLocation` where available.
- 2026-02-06: Migrated `Data/Authored Activities` GPX parsing boundary to store portable `SSGeoLocation` in waypoints/POIs while preserving existing `CLLocationCoordinate2D`-based iOS APIs.
- 2026-02-06: Migrated additional `Data` geospatial paths (`POI`, `ReferenceEntity`, `GenericLocation`, `Address`) to use `SSGeo` coordinate payloads and `SSGeoMath` internally while preserving existing CoreLocation-facing APIs.
- 2026-02-06: Updated `SSGeoMath` to default to WGS84 geodesic calculations (Vincenty with spherical fallback), added explicit spherical-approx APIs, and refactored iOS coordinate extensions to call SSGeo geodesy instead of choosing radius in app code.
- 2026-02-06: Migrated `GDASpatialDataResultEntity` distance/bearing internals from direct `CLLocation` math to `SSGeoMath`/portable coordinates while preserving CoreLocation method signatures, and added focused iOS unit tests for fallback/line-string/bearing behavior.
- 2026-02-06: Migrated `Data` intersection/roundabout/preview distance hot paths away from direct `CLLocation.distance(from:)` toward `SSGeoMath` or coordinate-based SSGeo-backed helpers, with new unit coverage for nearest-intersection selection.
- 2026-02-06: Migrated `Behaviors` + `Generators` waypoint/intersection/filter/reverse-geocoder distance calls from direct `CLLocation.distance(from:)` to SSGeo-backed coordinate distance helpers, preserving existing callout thresholds and public APIs.
- 2026-02-06: Migrated additional non-UI runtime distance paths in `Sensors` (`GPXSimulator`, geolocation filters), `Audio` (localized/proximity beacon distance), and core app extensions (`Array+POI`, `CoreLocation+Extensions`) to SSGeo-backed coordinate distance helpers.
- 2026-02-06: Migrated concrete UI/runtime callers that still used direct `CLLocation.distance(from:)` (`LocationDetailLocalizedLabel`, NaviLens integrations, Route/NaviLens recommenders) to SSGeo-backed coordinate distance helpers while preserving existing label/output behavior.
- 2026-02-06: Migrated remaining hot-path coordinate distance calculations in `GeometryUtils`, `RoadAdjacentDataView`, and `AutoCalloutGenerator` to explicit `SSGeoCoordinate.distance(to:)` usage, reducing dependence on CoreLocation extension distance wrappers.
- 2026-02-06: Added SSGeo-first label helpers in `LocationDetailLocalizedLabel` and `BeaconDetailLocalizedLabel` (`SSGeoLocation` inputs with `CLLocation` compatibility overloads) to keep UI geospatial formatting logic migration-friendly while preserving current caller APIs.
- 2026-02-06: Migrated Route Guidance and Guided Tour waypoint/intersection distance checks to explicit `SSGeoCoordinate.distance(to:)` calls across callouts and generators, reducing direct CoreLocation distance coupling in high-frequency behavior paths.
- 2026-02-06: Migrated default/preview behavior filters and callout distance logic (`BeaconUpdateFilter`, `GeneratorUpdateFilter`, `IntersectionGenerator`, `IntersectionCallout`, `POICallout`, preview and location callout helpers) to explicit `SSGeoCoordinate.distance(to:)` usage.
- 2026-02-06: Migrated geolocation sensor runtime distance checks (`GPXSimulator`, `LocationUpdateFilter`, `SignificantChangeMonitoringOrigin`) to explicit `SSGeoCoordinate.distance(to:)` usage to reduce remaining CoreLocation distance coupling in location update paths.
- 2026-02-06: Migrated reverse-geocoder runtime distance checks/callout component distances (`ReverseGeocoderContext`, `ReverseGeocoderResultTypes`) to explicit `SSGeoCoordinate.distance(to:)` usage while preserving geocoder thresholds and callout outputs.
- 2026-02-06: Migrated additional non-UI runtime distance paths (`Array+POI`, `CoreLocation+Extensions` transform helper, `RoadAdjacentDataView`, `AuthoredActivityContent`, `BaseAudioPlayer`, `DynamicAudioEngineAssets`, NaviLens integration helper) to explicit `SSGeoCoordinate.distance(to:)` calls.
- 2026-02-06: Migrated recommender distance sorting/filtering in `RouteRecommender` and `NavilensRecommender` to explicit `SSGeoCoordinate.distance(to:)` usage to remove remaining direct coordinate distance math in recommender publishers.
- 2026-02-06: Migrated UI label callers (`BeaconTitle*`, `TourToolbar`, `LocationItemView`, `LocationDetailLabelView`, `WaypointCell`, `LocationDetailTableViewController`, `EditMarkerView`) to `SSGeoLocation` overloads for distance labels, reducing `CLLocation`-typed call-site coupling in view/presenter layers.
- 2026-02-06: Migrated beacon “more information” action flow (`BeaconActionHandler`, `BeaconTitleViewController`, `BeaconTitleView`) to `SSGeoLocation` inputs and removed unused `CLLocation` overloads from `BeaconDetailLocalizedLabel`.
- 2026-02-06: Removed remaining `CLLocation` distance overload from `LocationDetailLocalizedLabel` and made `nameAndDistance` SSGeo-first (`SSGeoLocation` input) to continue collapsing legacy compatibility surfaces.
- 2026-02-06: Removed unused `CLLocationCoordinate2D.distance(from:)` extension from app code and updated iOS unit tests (`GeometryUtilsTest`, `GDASpatialDataResultEntityDistanceTests`) to assert distances via explicit `SSGeoCoordinate.distance(to:)` calls.
- 2026-02-06: Made `UserLocationStore` SSGeo-first (`@Published ssGeoLocation`) with a read-only `CLLocation` compatibility accessor, and updated route/tour UI distance callers to consume `ssGeoLocation` directly.
- 2026-02-06: Updated `BeaconTitleViewController` state/subscriptions to store user position as `SSGeoLocation` directly, removing local `CLLocation` storage and additional conversion churn in beacon UI updates.
- 2026-02-06: Made additional UI location state SSGeo-first (`BeaconTitleView`, `LocationItemView`, `LocationDetailLabelView`, `LocationDetailTableViewController`) while keeping targeted `CLLocation` initializer overloads where call-site compatibility is still needed.
- 2026-02-06: Migrated waypoint/tour detail UI call paths (`WaypointDetailView`, `GuidedTourDetailsView`, `LocationDetailConfiguration`, waypoint add/edit lists) to pass `SSGeoLocation` directly, reducing remaining call-site `.ssGeoLocation` conversion churn.
- 2026-02-06: Removed now-unused `CLLocation` compatibility initializers from SSGeo-first views (`BeaconTitleView`, `LocationItemView`, `LocationDetailLabelView`, `WaypointDetailView`) after migrating production call sites, keeping UI distance APIs consistently `SSGeoLocation`-typed.
- 2026-02-06: Removed direct `AppContext` location reads from waypoint add/edit list rendering (`WaypointAddList`, `WaypointEditList`) by threading `SSGeoLocation` through their call sites, and removed obsolete `UserLocationStore.location` (`CLLocation`) compatibility accessor.
- 2026-02-06: Made map/waypoint card detail configuration explicitly location-injected (`LocationDetailConfiguration` now takes `SSGeoLocation?`), and updated `BeaconMapView`, `BeaconMapCard`, and `WaypointCard` to source user location from `UserLocationStore` instead of `AppContext`.
- 2026-02-06: Removed direct geolocation-manager reads from UIKit waypoint/location detail controllers (`SearchWaypointViewController`, `LocationDetailTableViewController`) by sourcing SSGeo user location through `UserLocationStore`.
- 2026-02-06: Updated GPX waypoint parsing in `AuthoredActivityContent` to construct `SSGeoCoordinate`/`SSGeoLocation` directly from lat/lon values, removing an intermediate CoreLocation coordinate conversion step in the data ingestion path.
- 2026-02-06: Migrated remaining `UserLocationStore(designValue: ...)` preview/test setup call sites to `SSGeoLocation` payloads and removed the obsolete `UserLocationStore` `CLLocation` design initializer.
- 2026-02-06: Removed inline `UserLocationStore(...)` construction from SwiftUI view-builder call sites (production and previews), replacing them with `@StateObject` in view state or stored preview instances to avoid repeated body-time allocation.
- 2026-02-06: Started Milestone 1 seam-carving in Data models by introducing injectable runtime bridges for route/reference-entity location/runtime dependencies (`RouteRuntime`, `ReferenceEntityRuntime`, `SpatialDataEntityRuntime`) and migrating route persistence/sort and spatial debug quick-look call sites away from direct inline `AppContext` reads.
- 2026-02-06: Extended `ReferenceEntityRuntime` to cover cloud sync + destination/callout-history mutations, migrating marker add/update/remove flows to runtime bridge calls so `ReferenceEntity` operations no longer perform direct `AppContext.shared` service lookups inline.
- 2026-02-06: Added `DestinationManagerRuntime` and migrated destination manager geolocation/active-behavior reads behind runtime hooks (`route/tour active`, `beacon-callout-blocked`, `current user location`) to continue removing direct in-method `AppContext.shared` lookups from data-layer runtime logic.
- 2026-02-06: Added `SpatialDataContextRuntime` and `SpatialDataCacheRuntime` hooks to move initial location/cloud sync/callout-history/app-state/audio-engine destination lookups behind injectable seams, and removed internal self-references through `AppContext.shared.spatialDataContext` during data-view expansion.
- 2026-02-06: Removed `SpatialDataCache` destination lookup via `AppContext` by threading destination state through `SpatialDataContext.checkForTiles(...)` and `SpatialDataCache.tiles(...)`, making tile selection inputs explicit and reducing hidden global coupling in spatial cache decisions.
- 2026-02-06: Added an `SSGeoLocation` geofence helper on `DestinationManagerProtocol` and replaced beacon label geofence checks with `BeaconDetailRuntime` so beacon UI labels no longer read destination geofence state directly from `AppContext`.
- 2026-02-06: Added `UserLocationStoreRuntime` to source initial user location via an injectable hook, removing direct `AppContext` reads from `UserLocationStore` construction while preserving location-update notifications.
- 2026-02-06: Replaced `Data` runtime-seam default closures with protocol-based registry providers (`RouteRuntimeProviding`, `ReferenceEntityRuntimeProviding`, `SpatialDataEntityRuntimeProviding`, `DestinationManagerRuntimeProviding`, `SpatialDataContextRuntimeProviding`) and wired `AppContextDataRuntimeProviders` during `AppContext` composition.
- 2026-02-06: Added `DataRuntimeProviderDispatchTests` to verify runtime dispatch, throw/nil behavior propagation, and provider reset isolation; `rg \"AppContext.shared\" apps/ios/GuideDogs/Code/Data` now returns zero matches.
- 2026-02-06: Added UI runtime provider DI (`UserLocationStoreRuntimeProviding`, `BeaconDetailRuntimeProviding`, `UIRuntimeProviders`) with `AppContextUIRuntimeProviders`, and migrated `UserLocationStoreRuntime` + `BeaconDetailRuntime` to provider registry lookups.
- 2026-02-06: Added `UIRuntimeProviderDispatchTests` to verify provider dispatch and reset isolation for UI runtime seams.
- 2026-02-06: Extended UI runtime provider DI into remaining observable stores (`BeaconDetailStore`, `RouteGuidanceStateStore`, `GuidedTourStateStore`, `GuidedTourWaypointAudioStore`, `AudioFileStore`) so those stores no longer default to `AppContext.shared`; direct `AppContext.shared` matches in `Visual UI/Observable Data Stores` are now zero.
- 2026-02-06: Updated `AppContext.shared` coupling snapshot (current matches by top-level subsystem): `Visual UI: 250`, `Behaviors: 70`, `App: 25`, `Sensors: 11`, `Haptics: 11`, `Audio: 8`, `Notifications: 5`, `Generators: 5`, `Language: 2`, `Devices: 1`, `Data: 0`.
- 2026-02-06: Added behavior runtime provider DI (`RouteGuidanceRuntimeProviding`, `GuidedTourRuntimeProviding`, `BehaviorRuntimeProviders`) with `AppContextBehaviorRuntimeProviders`, and migrated `RouteGuidance` + `GuidedTour` to runtime hooks/injected dependencies so they no longer read `AppContext.shared` directly.
- 2026-02-06: Added `BehaviorRuntimeProviderDispatchTests` to verify route/tour runtime dispatch and provider reset isolation for behavior seams.
- 2026-02-06: Updated `AppContext.shared` coupling snapshot (current matches by top-level subsystem): `Visual UI: 254`, `Behaviors: 41`, `App: 25`, `Haptics: 13`, `Sensors: 11`, `Audio: 8`, `Notifications: 5`, `Generators: 5`, `Language: 2`, `Devices: 1`, `Data: 0`.
- 2026-02-06: Extended behavior runtime DI into onboarding (`OnboardingBehavior`, `OnboardingCalloutGenerator`) so onboarding beacon/audio/authorization hooks no longer read `AppContext.shared` or call `AppContext.process` directly.
- 2026-02-06: Extended `BehaviorRuntimeProviderDispatchTests` to validate onboarding runtime dispatch (`location`, `heading`, `authorization`) and preserve reset semantics.
- 2026-02-06: Updated `AppContext.shared` coupling snapshot (current matches by top-level subsystem): `Visual UI: 254`, `Behaviors: 34`, `App: 25`, `Haptics: 13`, `Sensors: 11`, `Audio: 8`, `Notifications: 5`, `Generators: 5`, `Language: 2`, `Devices: 1`, `Data: 0`.
- 2026-02-06: Migrated `ARHeadsetGenerator`, `HeadsetTestGenerator`, and `PreviewBehavior` from direct `AppContext.shared` access to constructor-injected protocol dependencies (`AudioEngineProtocol`, `GeolocationManagerProtocol`, `DestinationManagerProtocol`, `DeviceManagerProtocol`) and updated composition call sites (`SoundscapeBehavior`, `LocationActionHandler`).
- 2026-02-06: Updated `AppContext.shared` coupling snapshot (current matches by top-level subsystem): `Visual UI: 255`, `App: 25`, `Behaviors: 15`, `Haptics: 13`, `Sensors: 11`, `Audio: 8`, `Notifications: 5`, `Generators: 5`, `Language: 2`, `Devices: 1`, `Data: 0`.
- 2026-02-06: Extended behavior runtime DI for route/tour generators by adding `behaviorAudioOutputType()` to `BehaviorRuntimeProviders`, routing telemetry output-type lookups through `BehaviorRuntimeProviderRegistry`, and replacing route deactivation/motion-activity singleton reads with runtime/injected protocol access in `RouteGuidanceGenerator` and `TourGenerator`.
- 2026-02-06: Extended `BehaviorRuntimeProviderDispatchTests` to verify route/tour generator runtime dispatch of audio output type.
- 2026-02-06: Updated `AppContext.shared` coupling snapshot (current matches by top-level subsystem): `Visual UI: 255`, `App: 25`, `Haptics: 13`, `Sensors: 11`, `Behaviors: 10`, `Audio: 8`, `Notifications: 5`, `Generators: 5`, `Language: 2`, `Devices: 1`, `Data: 0`.
- 2026-02-06: Removed remaining direct behavior-layer singleton reads in `IntersectionGenerator`, `CalloutCoordinator`, and `EventProcessor` by routing callout telemetry output through behavior runtime provider hooks and using injected `GeolocationManagerProtocol`/`MotionActivityProtocol` dependencies for location, heading, and activity checks.
- 2026-02-06: Extended guided-tour behavior runtime hooks with `guidedTourActiveBehavior()` and migrated `TourDetail` to runtime-based active-tour lookup (`GuidedTourRuntime.activeGuidedTour()`), eliminating direct `AppContext.shared` access in `Behaviors/Guided Tour`.
- 2026-02-06: Updated `AppContext.shared` coupling snapshot (current matches by top-level subsystem): `Visual UI: 255`, `App: 25`, `Haptics: 13`, `Sensors: 11`, `Audio: 8`, `Notifications: 5`, `Generators: 5`, `Language: 2`, `Devices: 1`, `Behaviors: 0`, `Data: 0`.
- 2026-02-06: Extended `UIRuntimeProviders` with behavior/event dispatch hooks (`uiIsCustomBehaviorActive`, `uiDeactivateCustomBehavior`, `uiProcessEvent`) and migrated route/tour/beacon helper actions (`RouteDetail`, `RouteAction`, `GuidedTourAction`, `TourWaypointDetail`, `BeaconActionHandler`) to provider-based behavior and destination-manager access.
- 2026-02-06: Updated `BeaconToolbarView` route-guidance lookups to `UIRuntimeProviderRegistry` for route progress button state initialization and refresh.
- 2026-02-06: Extended `UIRuntimeProviderDispatchTests` to verify the new UI behavior/event runtime hooks dispatch to configured providers.
- 2026-02-06: Updated `AppContext.shared` coupling snapshot (current matches by top-level subsystem): `Visual UI: 244`, `App: 25`, `Haptics: 13`, `Sensors: 11`, `Audio: 8`, `Notifications: 5`, `Generators: 5`, `Language: 2`, `Devices: 1`, `Behaviors: 0`, `Data: 0`.
- 2026-02-06: Extended UI runtime hooks with guidance construction/activation access (`uiActivateCustomBehavior`, `uiSpatialDataContext`, `uiMotionActivityContext`) and migrated `RouteDetailsView`, `RouteTutorialView`, and `GuidedTourDetailsView` start/stop guidance flows away from direct `AppContext.shared` usage.
- 2026-02-06: Extended `UIRuntimeProviderDispatchTests` to verify UI custom-behavior activation + shared context lookup dispatch for the new UI runtime hooks.
- 2026-02-06: Updated `AppContext.shared` coupling snapshot (current matches by top-level subsystem): `Visual UI: 223`, `App: 25`, `Haptics: 13`, `Sensors: 11`, `Audio: 8`, `Notifications: 5`, `Generators: 5`, `Language: 2`, `Devices: 1`, `Behaviors: 0`, `Data: 0`.
- 2026-02-06: Migrated remaining singleton-coupled route/tour UI entry points (`RoutesList`, `RouteCompleteView`, `TourToolbar`, `RouteDetailsViewHostingController`, `TourCardContainerHostingController`) to `UIRuntimeProviderRegistry` hooks for active behavior, custom behavior activation/deactivation, and shared context lookup.
- 2026-02-06: Extended Data runtime provider DI with event-dispatch hooks (`referenceProcessEvent`, `destinationManagerProcessEvent`, `spatialDataContextProcessEvent`) and replaced the last `Data`-layer `AppContext.process(...)` call sites in `ReferenceEntity`, `DestinationManager`, and `SpatialDataContext`; `rg "AppContext.shared|AppContext.process" apps/ios/GuideDogs/Code/Data` now returns zero matches.
- 2026-02-06: Extended `DataRuntimeProviderDispatchTests` to verify dispatch of Data runtime event hooks and preserve provider-reset isolation.
- 2026-02-06: Regenerated dependency analysis artifact after a fresh iOS test build: `docs/plans/artifacts/dependency-analysis/latest.txt`.
- 2026-02-06: Updated `AppContext.shared` coupling snapshot (current matches by top-level subsystem): `Visual UI: 204`, `App: 25`, `Sensors: 11`, `Haptics: 11`, `Audio: 8`, `Notifications: 5`, `Generators: 5`, `Language: 2`, `Devices: 1`, `Behaviors: 0`, `Data: 0`.
- 2026-02-06: Extended `UIRuntimeProviders` with troubleshooting/status hooks (`uiCurrentUserLocation`, `uiIsOffline`, `uiHushEventProcessor`, `uiCheckSpatialServiceConnection`) and migrated `StatusTableViewController` away from direct `AppContext.shared` / `AppContext.process` usage.
- 2026-02-06: Extended `UIRuntimeProviderDispatchTests` to verify the new troubleshooting/status runtime hook dispatch and completion-callback behavior.
- 2026-02-06: Updated `AppContext.shared` coupling snapshot (current matches by top-level subsystem): `Visual UI: 194`, `App: 25`, `Sensors: 11`, `Haptics: 11`, `Audio: 8`, `Notifications: 5`, `Generators: 5`, `Language: 2`, `Devices: 1`, `Behaviors: 0`, `Data: 0`.
- 2026-02-06: Migrated `MarkersList` route-active behavior check to `UIRuntimeProviderRegistry` and removed preview-only `AppContext` location mock setup from `MarkersList_Previews`.
- 2026-02-06: Renamed UI runtime provider seam symbols from `Visual*` to `UI*` for semantic clarity (`UIRuntimeProviderRegistry`, `UIRuntimeProviders`, `UIRuntimeProviderDispatchTests`, `ui*` behavior/context hooks) with no behavior changes.
- 2026-02-06: Extended `UIRuntimeProviders` with Home-screen hooks (`uiSetRemoteCommandDelegate`, `uiIsFirstLaunch`, `uiShouldShowNewFeatures`, `uiNewFeatures`, guided-tour/route checks, location-permission status, street-preview, destination-audio toggles) and migrated `HomeViewController` away from direct `AppContext.shared` / `AppContext.process` usage.
- 2026-02-06: Extended `UIRuntimeProviderDispatchTests` to cover the new Home-screen UI runtime hook dispatch.
- 2026-02-06: Extended `UIRuntimeProviders` with tutorial-mode toggling (`uiSetTutorialMode`) and migrated `MarkerTutorialViewController` away from direct `AppContext.shared` / `AppContext.process` usage for tutorial state, destination control, and event dispatch.
- 2026-02-06: Extended `UIRuntimeProviderDispatchTests` to cover tutorial-mode runtime dispatch.
- 2026-02-06: Updated `AppContext.shared` coupling snapshot (current matches by top-level subsystem): `Visual UI: 173`, `App: 25`, `Sensors: 11`, `Haptics: 11`, `Audio: 8`, `Notifications: 5`, `Generators: 5`, `Language: 2`, `Devices: 1`, `Behaviors: 0`, `Data: 0`.
- 2026-02-06: Extended `UIRuntimeProviders` with device-management hooks (`uiSetDeviceManagerDelegate`, `uiDevices`, `uiAddDevice`, `uiRemoveDevice`, `uiUserHeading`, `uiBLEAuthorizationStatus`) and migrated `DevicesViewController` away from direct `AppContext.shared` / `AppContext.process` usage.
- 2026-02-06: Extended `UIRuntimeProviderDispatchTests` to verify device-management/heading/BLE runtime hook dispatch and reset isolation.
- 2026-02-06: Updated `AppContext` coupling snapshot using `AppContext.shared|AppContext.process` matches by top-level subsystem: `Visual UI: 180` (down from `202` pre-slice), `App: 25`, `Sensors: 18`, `Haptics: 11`, `Audio: 9`, `Notifications: 5`, `Generators: 5`, `Offline: 2`, `Language: 2`, `Devices: 2`, `Behaviors: 0`, `Data: 0`.
- 2026-02-06: Extended `UIRuntimeProviders` with `uiAudioSession` and migrated `DestinationTutorialViewController` away from direct `AppContext.shared` / `AppContext.process` usage for audio-session observer binding, tutorial-mode reset, event dispatch, and destination cleanup.
- 2026-02-06: Extended `UIRuntimeProviderDispatchTests` to verify UI audio-session runtime hook dispatch.
- 2026-02-06: Updated `AppContext` coupling snapshot using `AppContext.shared|AppContext.process` matches by top-level subsystem: `Visual UI: 171` (down from `180` pre-slice), `App: 25`, `Sensors: 18`, `Haptics: 11`, `Audio: 9`, `Notifications: 5`, `Generators: 5`, `Offline: 2`, `Language: 2`, `Devices: 2`, `Behaviors: 0`, `Data: 0`.
- 2026-02-06: Migrated `DestinationTutorialIntroViewController` to `UIRuntimeProviders` for tutorial-mode toggling, audio-session interruption observer wiring, destination cleanup, and destination selection setup.
- 2026-02-06: Updated `AppContext` coupling snapshot using `AppContext.shared|AppContext.process` matches by top-level subsystem: `Visual UI: 166` (down from `171` pre-slice), `App: 25`, `Sensors: 18`, `Haptics: 11`, `Audio: 9`, `Notifications: 5`, `Generators: 5`, `Offline: 2`, `Language: 2`, `Devices: 2`, `Behaviors: 0`, `Data: 0`.
- 2026-02-06: Migrated `DestinationTutorialBeaconPage` device/destination runtime reads to `UIRuntimeProviders` (`uiDevices`, `uiToggleDestinationAudio`, `uiSpatialDataContext`) and removed direct singleton usage in beacon in-bounds/out-of-bounds tutorial flow logic.
- 2026-02-06: Updated `AppContext` coupling snapshot using `AppContext.shared|AppContext.process` matches by top-level subsystem: `Visual UI: 160` (down from `166` pre-slice), `App: 25`, `Sensors: 18`, `Haptics: 11`, `Audio: 9`, `Notifications: 5`, `Generators: 5`, `Offline: 2`, `Language: 2`, `Devices: 2`, `Behaviors: 0`, `Data: 0`.
- 2026-02-06: Migrated remaining destination tutorial and beacon-map/title UI call sites (`DestinationTutorialMutePage`, `DestinationTutorialInfoPage`, `BeaconTitleViewController`, `BeaconMapCard` previews) to runtime providers or direct non-singleton preview data; kept one preview-only compatibility constructor in `BeaconMapView_Previews.behavior`.
- 2026-02-06: Updated `AppContext` coupling snapshot using `AppContext.shared|AppContext.process` matches by top-level subsystem: `Visual UI: 154` (down from `160` pre-slice), `App: 25`, `Sensors: 18`, `Haptics: 11`, `Audio: 9`, `Notifications: 5`, `Generators: 5`, `Offline: 2`, `Language: 2`, `Devices: 2`, `Behaviors: 0`, `Data: 0`.
- 2026-02-07: Extended `UIRuntimeProviders` with location-helper hooks (`uiGeolocationManager`, `uiAudioEngine`, `uiReverseGeocode`) and migrated `LocationActionHandler`, `LocationDetail`, and `EstimatedLocationDetail` away from direct `AppContext.shared` lookups in location save/beacon/preview/name/address resolution paths.
- 2026-02-07: Extended `UIRuntimeProviderDispatchTests` to validate dispatch/reset behavior for the new location-helper UI runtime hooks.
- 2026-02-07: Updated `AppContext` coupling snapshot using `AppContext.shared|AppContext.process` matches by top-level subsystem: `Visual UI: 141` (down from `154` pre-slice), `App: 25`, `Sensors: 18`, `Haptics: 11`, `Audio: 9`, `Notifications: 5`, `Generators: 5`, `Offline: 2`, `Language: 2`, `Devices: 2`, `Behaviors: 0`, `Data: 0`.
- 2026-02-07: Extended `UIRuntimeProviders` with `uiCalloutHistoryCallouts()` and migrated nearby/search UI seams (`NearbyDataContext`, `SearchResultsUpdater`, `SearchTableViewController`, `SearchResultsTableViewController`) away from direct `AppContext.shared` usage for current-location, offline-state, callout-history, street-preview, and spatial-data lookups.
- 2026-02-07: Extended `UIRuntimeProviderDispatchTests` to validate dispatch/reset behavior for the new callout-history runtime hook.
- 2026-02-07: Updated `AppContext` coupling snapshot using `AppContext.shared|AppContext.process` matches by top-level subsystem: `Visual UI: 129` (down from `141` pre-slice), `App: 25`, `Sensors: 18`, `Haptics: 11`, `Audio: 9`, `Notifications: 5`, `Generators: 5`, `Offline: 2`, `Language: 2`, `Devices: 2`, `Behaviors: 0`, `Data: 0`.
- 2026-02-07: Extended `UIRuntimeProviders` with `uiPresentationHeading()` and migrated onboarding callout/beacon interactive UI seams (`OnboardingCalloutButton`, `InteractiveBeaconView`, `InteractiveBeaconViewModel`) away from direct `AppContext.shared` / `AppContext.process` usage for hush/event dispatch, heading stream access, current-location, and destination beacon state.
- 2026-02-07: Extended `UIRuntimeProviderDispatchTests` to validate dispatch/reset behavior for the new presentation-heading runtime hook.
- 2026-02-07: Updated `AppContext` coupling snapshot using `AppContext.shared|AppContext.process` matches by top-level subsystem: `Visual UI: 118` (down from `129` pre-slice), `App: 25`, `Sensors: 18`, `Haptics: 11`, `Audio: 9`, `Notifications: 5`, `Generators: 5`, `Offline: 2`, `Language: 2`, `Devices: 2`, `Behaviors: 0`, `Data: 0`.
- 2026-02-07: Extended `UIRuntimeProviders` with launch/remote-control hooks (`uiIsApplicationInNormalState`, `uiActiveRouteGuidance`, `uiToggleAudio`, `uiToggleDestinationAudio(automatic:)`, `uiHushEventProcessor(playSound:hushBeacon:)`, `uiIsSimulatingGPX`, `uiToggleGPXSimulationState`) and migrated `HomeViewController+RemoteControl` and `LaunchHelper` away from direct `AppContext.shared` / `AppContext.process` usage.
- 2026-02-07: Extended `UIRuntimeProviderDispatchTests` to validate dispatch/reset behavior for the new launch/remote-control runtime hooks.
- 2026-02-07: Updated `AppContext` coupling snapshot using `AppContext.shared|AppContext.process` matches by top-level subsystem: `Visual UI: 103` (down from `118` pre-slice), `App: 25`, `Sensors: 18`, `Haptics: 11`, `Audio: 9`, `Notifications: 5`, `Generators: 5`, `Offline: 2`, `Language: 2`, `Devices: 2`, `Behaviors: 0`, `Data: 0`.
- 2026-02-07: Extended `UIRuntimeProviders` with launch-bootstrap hooks (`uiSetExperimentManagerDelegate`, `uiInitializeExperimentManager`, `uiTelemetryHelper`, `uiStartApp(fromFirstLaunch:)`) and added `UIRuntimeProviderRegistry.ensureConfiguredForLaunchIfNeeded()` to bootstrap providers during cold start.
- 2026-02-07: Migrated `DynamicLaunchViewController` and `OnboardingBeaconView` away from direct `AppContext.shared` usage for startup wiring, experiment-manager lifecycle, telemetry helper initialization, and first-launch app start.
- 2026-02-07: Extended `UIRuntimeProviderDispatchTests` to validate dispatch/reset behavior for the new launch-bootstrap runtime hooks.
- 2026-02-07: Updated `AppContext` coupling snapshot using `AppContext.shared|AppContext.process` matches by top-level subsystem: `Visual UI: 95` (down from `103` pre-slice), `App: 26`, `Sensors: 18`, `Haptics: 11`, `Audio: 9`, `Notifications: 5`, `Generators: 5`, `Offline: 2`, `Language: 2`, `Devices: 2`, `Behaviors: 0`, `Data: 0`.
- 2026-02-07: Migrated voice/volume demo UI seams (`SpeakingRateTableViewCell`, `VolumeControls`) to existing `UIRuntimeProviders` hooks for hush/discrete-audio stop/event dispatch, removing direct `AppContext.shared` / `AppContext.process` usage without adding new runtime APIs.
- 2026-02-07: Updated `AppContext` coupling snapshot using `AppContext.shared|AppContext.process` matches by top-level subsystem: `Visual UI: 80` (down from `95` pre-slice), `App: 26`, `Sensors: 18`, `Haptics: 11`, `Audio: 9`, `Notifications: 5`, `Generators: 5`, `Offline: 2`, `Language: 2`, `Devices: 2`, `Behaviors: 0`, `Data: 0`.
- 2026-02-07: Migrated additional route-guidance UI checks (`HelpViewController`, `WaypointDetail`, `LocationAction`, `MixAudioSettingCell`, `ShareMarkerAlert`) to existing runtime-provider hooks (`uiIsActiveBehaviorRouteGuidance`, `routeGuidanceStateStoreActiveRouteGuidance`) without introducing new provider API surface.
- 2026-02-07: Updated `AppContext` coupling snapshot using `AppContext.shared|AppContext.process` matches by top-level subsystem: `Visual UI: 74` (down from `80` pre-slice), `App: 26`, `Sensors: 18`, `Haptics: 11`, `Audio: 9`, `Notifications: 5`, `Generators: 5`, `Offline: 2`, `Language: 2`, `Devices: 2`, `Behaviors: 0`, `Data: 0`.
- 2026-02-07: Extended `UIRuntimeProviders` with additional UI behavior/status hooks (`uiIsActiveBehaviorSoundscape`, `uiIsDestinationSet`) and migrated `CardStateViewController`, `VoiceSettingsTableViewController`, and `SettingsViewController` away from direct `AppContext.shared` / `AppContext.process` usage.
- 2026-02-07: Migrated additional no-new-API UI seams (`BaseTutorialViewController`, `OnboardingWelcomeView`, `RouteRecommenderView`, `RouteRecommender`, `NavilensRecommender`, `RecommenderViewModel`, `WaypointAudioButton`) to existing `UIRuntimeProviderRegistry` hooks.
- 2026-02-07: Extended `UIRuntimeProviders` with preview/sleep/auth hooks (`uiGoToSleep`, `uiSnooze`, `uiWakeUp`, `uiActiveBehaviorID`, `uiCurrentPreviewDecisionPoint`, `uiLocationAuthorizationProvider`, `uiMotionAuthorizationProvider`) and migrated `StandbyViewController`, `PreviewViewController`, `CalloutButtonPanelViewController`, and `AuthorizationViewModel` away from direct singleton calls.
- 2026-02-07: Extended `UIRuntimeProviderDispatchTests` to validate dispatch/reset behavior for the new UI hooks (sleep/wake, active behavior ID, preview decision point, location/motion authorization providers).
- 2026-02-07: Updated `AppContext` coupling snapshot using `AppContext.shared|AppContext.process` matches by top-level subsystem: `Visual UI: 27` (down from `74` pre-slice), `App: 26`, `Sensors: 18`, `Haptics: 11`, `Audio: 9`, `Notifications: 5`, `Generators: 5`, `Offline: 2`, `Language: 2`, `Devices: 2`, `Behaviors: 0`, `Data: 0`.
- 2026-02-07: Migrated additional remaining UI/controller seams (`Integrations`, `NearbyTableViewController`, `LocationDetailViewController`, `MarkersAndRoutesListNavigationHelper`, `PreviewTutorialViewController`, `EnableLocationServicesViewController`, `MenuViewController`, `MarkerModel`, `TourViewModel`, `AccessibilityEditableMapView`, `AuthoredActivityStorage`) to `UIRuntimeProviderRegistry` hooks without expanding provider API surface.
- 2026-02-07: Updated `AppContext` coupling snapshot using `AppContext.shared|AppContext.process` matches by top-level subsystem: `Visual UI: 16` (down from `27` pre-slice), `App: 26`, `Sensors: 18`, `Haptics: 11`, `Audio: 9`, `Notifications: 5`, `Generators: 5`, `Offline: 2`, `Language: 2`, `Devices: 2`, `Behaviors: 0`, `Data: 0`.
- 2026-02-07: Extended `UIRuntimeProviders` with remaining production-control hooks (`uiDeviceHeading`, `uiRequestCoreLocationAuthorization`, `uiPlayCallouts`) and migrated `PreviewControlViewController`, `AccessibilityEditableMapViewModel`, `AuthorizeLocationsViewController`, `LocationPermissionViewController`, and `TutorialCalloutPlayer` off direct singleton usage.
- 2026-02-07: Extended `UIRuntimeProviderDispatchTests` to validate dispatch/reset behavior for the new heading/location-authorization/play-callouts hooks.
- 2026-02-07: Updated `AppContext` coupling snapshot using `AppContext.shared|AppContext.process` matches by top-level subsystem: `Visual UI: 11` (down from `16` pre-slice), `App: 26`, `Sensors: 18`, `Haptics: 11`, `Audio: 9`, `Notifications: 5`, `Generators: 5`, `Offline: 2`, `Language: 2`, `Devices: 2`, `Behaviors: 0`, `Data: 0`.
- 2026-02-07: Migrated remaining preview-only UI call sites (`BeaconTitleView`, `BeaconToolbarView`, `BeaconView`, `BeaconMapView`, `WaypointAddList`, `WaypointEditList`, `MarkersAndRoutesList`) off direct `AppContext.shared` reads by using existing `UIRuntimeProviderRegistry` hooks and explicit preview data setup.
- 2026-02-07: Updated `AppContext` coupling snapshot using `AppContext.shared|AppContext.process` matches by top-level subsystem: `App: 26`, `Sensors: 18`, `Haptics: 11`, `Audio: 9`, `Notifications: 5`, `Generators: 5`, `Offline: 2`, `Language: 2`, `Devices: 2`, `Behaviors: 0`, `Data: 0`.
- 2026-02-07: Added a first storage-port seam in `Data` by introducing `DestinationEntityStore` with a default `SpatialDataDestinationEntityStore` adapter and injecting it into `DestinationManager` construction; destination lookup/temp-create/temp-clear flows now dispatch through the protocol seam instead of direct static `SpatialDataCache`/`ReferenceEntity` calls.
- 2026-02-07: Extended `DestinationManagerTest` with injected-store coverage (`testSetDestinationUsesInjectedEntityStoreLookup`, `testClearDestinationUsesInjectedEntityStoreCleanup`) to verify dispatch behavior while preserving existing geofence and destination behavior tests.
- 2026-02-07: `AppContext` coupling snapshot unchanged for this slice (still no `Visual UI`/`Data` singleton usage): `App: 26`, `Sensors: 18`, `Haptics: 11`, `Audio: 9`, `Notifications: 5`, `Generators: 5`, `Offline: 2`, `Language: 2`, `Devices: 2`, `Behaviors: 0`, `Data: 0`.
- 2026-02-07: Regenerated dependency-analysis artifact after the destination-storage seam slice: `docs/plans/artifacts/dependency-analysis/latest.txt` (timestamped artifact: `20260207-084920Z-ssindex-4ff83b8.txt`).
- 2026-02-07: Added route storage seam types in `Route+Realm` (`RouteSpatialDataStore`, `DefaultRouteSpatialDataStore`, `RouteSpatialDataStoreRegistry`) and migrated route storage call sites (`objectKeys(sortedBy: .distance)`, `deleteAll()`, first-waypoint update lookup, and route waypoint bulk update/remove paths) away from direct static `SpatialDataCache` calls.
- 2026-02-07: Added `RouteStorageProviderDispatchTests` to verify route storage seam dispatch (`referenceEntityByKey`, `routesContaining`) and provider reset isolation.
- 2026-02-07: Validation for this slice: `xcodebuild build-for-testing` passed; `xcodebuild test-without-building` still fails only in known simulator audio tests (`AudioEngineTest.testDiscreteAudio2DSimple`, `AudioEngineTest.testDiscreteAudio2DSeveral`), with all new/affected data runtime tests passing.
- 2026-02-07: Updated `AppContext` coupling snapshot after route-storage seam (unchanged singleton usage profile): `App: 26`, `Sensors: 18`, `Haptics: 11`, `Audio: 9`, `Notifications: 5`, `Generators: 5`, `Offline: 2`, `Language: 2`, `Devices: 2`, `Behaviors: 0`, `Data: 0`.
- 2026-02-07: Extended `RouteSpatialDataStore` with route lookup (`routeByKey`) and migrated additional route call sites away from static cache usage: `Route.init(from:)` first-waypoint marker lookup in `Route.swift` and route serialization lookup in `RouteParameters+Codable.encode(from:detail,context:)`.
- 2026-02-07: Extended `RouteStorageProviderDispatchTests` with route serialization/init dispatch coverage (`testEncodeFromDetailUsesInjectedSpatialStoreRouteLookup`, `testRouteInitFromParametersUsesInjectedSpatialStoreMarkerLookup`) and route-list dispatch coverage (`testDeleteAllUsesInjectedSpatialStoreRoutesList`).
- 2026-02-07: Validation for this slice: `xcodebuild build-for-testing` passed; targeted `RouteStorageProviderDispatchTests` passed (`5` tests); full `xcodebuild test-without-building` remains blocked only by known simulator audio failures (`AudioEngineTest.testDiscreteAudio2DSimple`, `AudioEngineTest.testDiscreteAudio2DSeveral`, `10` assertions).
- 2026-02-07: Migrated cloud route backup/import route+marker lookups in `CloudKeyValueStore+Routes` (`store()`, `isValid(routeParameters:)`, `shouldUpdateLocalRoute`) from direct `SpatialDataCache` static access to `RouteSpatialDataStoreRegistry` provider lookups.
- 2026-02-07: Validation for this slice: `xcodebuild build-for-testing` passed; targeted `RouteStorageProviderDispatchTests` passed (`5` tests); full `xcodebuild test-without-building` remains blocked only by known simulator audio failures (`AudioEngineTest.testDiscreteAudio2DSimple`, `AudioEngineTest.testDiscreteAudio2DSeveral`, `10` assertions).
- 2026-02-07: Renamed route-focused seam types to broader spatial naming (`RouteSpatialDataStore` -> `SpatialDataStore`, `DefaultRouteSpatialDataStore` -> `DefaultSpatialDataStore`, `RouteSpatialDataStoreRegistry` -> `SpatialDataStoreRegistry`) to reflect shared use across Route and Marker cloud sync paths.
- 2026-02-07: Extended `SpatialDataStore` with `referenceEntities()` and migrated marker cloud-store sync lookups in `CloudKeyValueStore+Markers` (`store()`, `shouldUpdateLocalReferenceEntity`) from direct `SpatialDataCache` reads to provider lookups.
- 2026-02-07: Validation for this slice: `xcodebuild build-for-testing` passed; targeted `RouteStorageProviderDispatchTests` passed (`5` tests); full `xcodebuild test-without-building` remains blocked only by known simulator audio failures (`AudioEngineTest.testDiscreteAudio2DSimple`, `AudioEngineTest.testDiscreteAudio2DSeveral`, `10` assertions).
- 2026-02-07: Extended `SpatialDataStore` with marker/serialization lookup APIs (`referenceEntityByEntityKey`, `referenceEntityByLocation`, `searchByKey`) and migrated `MarkerParameters` + `LocationParameters` cache lookups off direct `SpatialDataCache` usage.
- 2026-02-07: Extended `RouteStorageProviderDispatchTests` with marker/location serialization seam coverage (`testMarkerParametersInitMarkerIDUsesInjectedSpatialStoreLookup`, `testMarkerParametersInitGenericLocationUsesInjectedSpatialStoreLocationLookup`, `testLocationParametersFetchEntityUsesInjectedSpatialStoreSearchLookup`).
- 2026-02-07: Validation for this slice: `xcodebuild build-for-testing` passed; targeted `RouteStorageProviderDispatchTests` passed (`8` tests); full `xcodebuild test-without-building` remains blocked only by known simulator audio failures (`AudioEngineTest.testDiscreteAudio2DSimple`, `AudioEngineTest.testDiscreteAudio2DSeveral`, `10` assertions).
- 2026-02-07: Extended `SpatialDataStore` with `referenceEntitiesNear(_:range:)` and migrated `RoadAdjacentDataView` marker reads (`makeCalloutsForAdjacents`, `markersAlongPath`) from direct static `SpatialDataCache` calls to provider-based lookups.
- 2026-02-07: Added direct dispatch coverage for newly added spatial-store methods in `RouteStorageProviderDispatchTests` (`testSpatialDataStoreReferenceEntityByEntityKeyDispatchesToInjectedStore`, `testSpatialDataStoreReferenceEntitiesNearDispatchesToInjectedStore`).
- 2026-02-07: Validation for this slice: `xcodebuild build-for-testing` passed; targeted `RouteStorageProviderDispatchTests` passed (class suite + focused method filters); full `xcodebuild test-without-building` remains blocked only by known simulator audio failures (`AudioEngineTest.testDiscreteAudio2DSimple`, `AudioEngineTest.testDiscreteAudio2DSeveral`, `10` assertions).
- 2026-02-07: Extended `SpatialDataStore` with marker mutation API (`addReferenceEntity(detail:telemetryContext:notify:)`) and migrated `Route.add(...)` waypoint marker creation from direct `ReferenceEntity.add` to provider-based mutation dispatch.
- 2026-02-07: Extended `RouteStorageProviderDispatchTests` with route mutation seam coverage (`testRouteAddUsesInjectedSpatialStoreReferenceEntityAdd`) and refreshed class dispatch validation coverage (10 targeted tests passing).
- 2026-02-07: Validation for this slice: `xcodebuild build-for-testing` passed; focused route-mutation + storage-dispatch tests passed; full `xcodebuild test-without-building` remains blocked only by known simulator audio failures (`AudioEngineTest.testDiscreteAudio2DSimple`, `AudioEngineTest.testDiscreteAudio2DSeveral`, `10` assertions).
- 2026-02-07: Regenerated dependency-analysis artifact after the latest data seam slices: `docs/plans/artifacts/dependency-analysis/latest.txt` (timestamped artifact: `20260207-092318Z-ssindex-0a2fa30.txt`).
- 2026-02-07: Extended `SpatialDataStore` with generic-location + temporary-marker operations (`referenceEntityByGenericLocation`, `addTemporaryReferenceEntity` overloads, `removeAllTemporaryReferenceEntities`) and updated `SpatialDataDestinationEntityStore` to delegate through `SpatialDataStoreRegistry` for both destination reads and temporary marker mutations.
- 2026-02-07: Extended `RouteStorageProviderDispatchTests` with additional storage dispatch coverage (`testSpatialDataStoreReferenceEntityByGenericLocationDispatchesToInjectedStore`, `testSpatialDataStoreTemporaryReferenceEntityOperationsDispatchToInjectedStore`) and validated route add/mutation dispatch (`testRouteAddUsesInjectedSpatialStoreReferenceEntityAdd`).
- 2026-02-07: Validation for this slice: `xcodebuild build-for-testing` passed; targeted `RouteStorageProviderDispatchTests` passed (`11` tests); full `xcodebuild test-without-building` remains blocked only by known simulator audio failures (`AudioEngineTest.testDiscreteAudio2DSimple`, `AudioEngineTest.testDiscreteAudio2DSeveral`, `10` assertions).
- 2026-02-07: Migrated remaining `ReferenceEntity` internal read seams (`getPOI()`, `add(detail:)`, `add(entityKey:...)`, `add(location:...)`) from direct `SpatialDataCache` static lookups to `SpatialDataStoreRegistry.store` dispatch.
- 2026-02-07: Extended `RouteStorageProviderDispatchTests` with `ReferenceEntity` lookup dispatch coverage (`testReferenceEntityGetPOIUsesInjectedSpatialStoreSearchLookup`, `testReferenceEntityAddEntityKeyUsesInjectedSpatialStoreLookups`, `testReferenceEntityAddLocationUsesInjectedSpatialStoreGenericLocationLookup`).
- 2026-02-07: Validation for this slice: `xcodebuild build-for-testing` passed; targeted `RouteStorageProviderDispatchTests` passed (`16` tests); full `xcodebuild test-without-building` not rerun in this sub-slice (known baseline full-suite blocker remains simulator audio tests).
- 2026-02-07: Extended `SpatialDataStore` with road/intersection graph lookups (`roadByKey`, `intersections(forRoadKey:)`, `intersection(forRoadKey:atCoordinate:)`, `intersections(forRoadKey:inRegion:)`) and migrated `Intersection`, `Road`, and `Roundabout` model helpers to use `SpatialDataStoreRegistry.store` rather than direct static `SpatialDataCache` calls.
- 2026-02-07: Migrated `GDASpatialDataResultEntity.entrances` lookup path from direct `SpatialDataCache.searchByKey` to injected `SpatialDataStoreRegistry.store.searchByKey`.
- 2026-02-07: Extended `RouteStorageProviderDispatchTests` with graph-lookup dispatch coverage (`testSpatialDataStoreRoadByKeyDispatchesToInjectedStore`, `testSpatialDataStoreIntersectionsForRoadKeyDispatchesToInjectedStore`, `testSpatialDataStoreIntersectionForRoadKeyAtCoordinateDispatchesToInjectedStore`, `testSpatialDataStoreIntersectionsForRoadKeyInRegionDispatchesToInjectedStore`, `testIntersectionRoadsUseInjectedSpatialStoreLookup`, `testRoadIntersectionsUseInjectedSpatialStoreLookup`, `testRoadIntersectionAtCoordinateUsesInjectedSpatialStoreLookup`); targeted suite now passes `23` tests.
- 2026-02-07: Validation for this slice: `xcodebuild build-for-testing` passed; targeted `RouteStorageProviderDispatchTests` passed (`23` tests); full `xcodebuild test-without-building` still fails only in known simulator audio tests (`AudioEngineTest.testDiscreteAudio2DSimple`, `AudioEngineTest.testDiscreteAudio2DSeveral`, `10` assertions).
- 2026-02-07: Data-layer `SpatialDataCache` coupling snapshot after graph seam: direct static cache usage outside infrastructure/adapters is now `0`; remaining references are confined to `SpatialDataCache.swift`, `SpatialDataView.swift`, `SpatialDataContext.swift`, and the `DefaultSpatialDataStore` adapter in `Route+Realm.swift`.
- 2026-02-07: Extended `SpatialDataStore` with tile/generic-location infrastructure operations (`tiles(forDestinations:forReferences:at:destination:)`, `tileData(for:)`, `genericLocationsNear(_:range:)`) and migrated `SpatialDataView`/`SpatialDataContext` infrastructure callsites to use `SpatialDataStoreRegistry.store`.
- 2026-02-07: Extended `RouteStorageProviderDispatchTests` with infrastructure dispatch coverage (`testSpatialDataStoreTilesDispatchesToInjectedStore`, `testSpatialDataStoreTileDataDispatchesToInjectedStore`, `testSpatialDataStoreGenericLocationsNearDispatchesToInjectedStore`); targeted suite now passes `26` tests.
- 2026-02-07: Validation for this slice: `xcodebuild build-for-testing` passed; targeted `RouteStorageProviderDispatchTests` passed (`26` tests); full `xcodebuild test-without-building` still fails only in known simulator audio tests (`AudioEngineTest.testDiscreteAudio2DSimple`, `AudioEngineTest.testDiscreteAudio2DSeveral`, `10` assertions).
- 2026-02-07: Data-layer `SpatialDataCache` coupling snapshot after infrastructure seam: all direct static cache references outside `SpatialDataCache.swift` are now isolated to the `DefaultSpatialDataStore` adapter in `Route+Realm.swift`.
- 2026-02-07: Added guard script `apps/ios/Scripts/ci/check_spatial_data_cache_seam.sh` to fail when direct `SpatialDataCache` references appear outside allowed seam files (`SpatialDataCache.swift`, `Route+Realm.swift`).
- 2026-02-07: Validation for guard slice: `bash apps/ios/Scripts/ci/check_spatial_data_cache_seam.sh` passes with current seam boundaries.
- 2026-02-09: Moved `SpatialDataStore` seam definitions (`SpatialDataStore`, `DefaultSpatialDataStore`, `SpatialDataStoreRegistry`) from `Route+Realm.swift` into `SpatialDataCache.swift` to co-locate the storage seam with data infrastructure instead of model extensions.
- 2026-02-09: Tightened guard script `apps/ios/Scripts/ci/check_spatial_data_cache_seam.sh` so direct `SpatialDataCache.*` usage is only allowed in `SpatialDataCache.swift`; no secondary allowlist files remain.
- 2026-02-09: Validation for seam-centralization slice: seam guard passes, `xcodebuild build-for-testing` passes, targeted `RouteStorageProviderDispatchTests` pass (`26` tests), full `xcodebuild test-without-building` still fails only in known simulator audio tests (`AudioEngineTest.testDiscreteAudio2DSimple`, `AudioEngineTest.testDiscreteAudio2DSeveral`, `10` assertions).
- 2026-02-09: Wired `apps/ios/Scripts/ci/check_spatial_data_cache_seam.sh` into CI (`.github/workflows/ios-tests.yml`) so seam regressions fail before iOS build/test.
- 2026-02-09: Started folder-layer split batch by moving `Route+Realm.swift` from `Code/Data/Models/Extensions/Route` to `Code/Data/Infrastructure/Realm` and updating the Xcode file reference path, making a first concrete Realm/persistence placement under `Data/Infrastructure`.
- 2026-02-09: Validation for folder-move slice: seam guard passes, `xcodebuild build-for-testing` passes, targeted `RouteStorageProviderDispatchTests` pass (`26` tests), full `xcodebuild test-without-building` still fails only in known simulator audio tests (`AudioEngineTest.testDiscreteAudio2DSimple`, `AudioEngineTest.testDiscreteAudio2DSeveral`, `10` assertions).
- 2026-02-09: Continued the folder-layer split by moving additional Realm-only support files into `Code/Data/Infrastructure/Realm` (`RealmHelper.swift`, `RealmMigrationTools.swift`, `RealmString.swift`) and updating Xcode file reference paths.
- 2026-02-09: Validation for the second Infrastructure batch: seam guard passes, `xcodebuild build-for-testing` passes, targeted `RouteStorageProviderDispatchTests` pass (`26` tests), full `xcodebuild test-without-building` still fails only in known simulator audio tests (`AudioEngineTest.testDiscreteAudio2DSimple`, `AudioEngineTest.testDiscreteAudio2DSeveral`, `10` assertions).
- 2026-02-09: Moved `RouteRealmError.swift` into `Code/Data/Infrastructure/Realm` and updated Xcode file reference paths so Realm-specific route persistence errors reside with other infrastructure persistence files.
- 2026-02-09: Validation for the third Infrastructure batch: seam guard passes, `xcodebuild build-for-testing` passes, targeted `RouteStorageProviderDispatchTests` pass (`26` tests), full `xcodebuild test-without-building` still fails only in known simulator audio tests (`AudioEngineTest.testDiscreteAudio2DSimple`, `AudioEngineTest.testDiscreteAudio2DSeveral`, `10` assertions).
- 2026-02-09: Continued the folder-layer split by moving Realm-only helper/value files `OsmTag.swift` and `IntersectionRoadId.swift` from `Code/Data/Models/...` into `Code/Data/Infrastructure/Realm`, with corresponding Xcode file reference path updates.
- 2026-02-09: Validation for the fourth Infrastructure batch: seam guard passes, `xcodebuild build-for-testing` passes, targeted `RouteStorageProviderDispatchTests` pass (`26` tests), full `xcodebuild test-without-building` not rerun in this sub-slice (known baseline blocker remains simulator audio tests).
- 2026-02-09: Continued the folder-layer split by moving Realm-backed route model files `Route.swift` and `RouteWaypoint.swift` from `Code/Data/Models/Database Models/Routes` into `Code/Data/Infrastructure/Realm` and updating Xcode file reference paths.
- 2026-02-09: Validation for the fifth Infrastructure batch: seam guard passes, `xcodebuild build-for-testing` passes, targeted `RouteStorageProviderDispatchTests` pass (`26` tests), full `xcodebuild test-without-building` not rerun in this sub-slice (known baseline blocker remains simulator audio tests).
- 2026-02-09: Continued the folder-layer split by moving additional Realm-backed data model files `ReferenceEntity.swift`, `Address.swift`, `Intersection.swift`, `GDASpatialDataResultEntity.swift`, and `TileData.swift` from `Code/Data/Models/...` into `Code/Data/Infrastructure/Realm` and updating Xcode file reference paths.
- 2026-02-09: Validation for the sixth Infrastructure batch: seam guard passes, `xcodebuild build-for-testing` passes, targeted `RouteStorageProviderDispatchTests` pass (`26` tests), full `xcodebuild test-without-building` not rerun in this sub-slice (known baseline blocker remains simulator audio tests).
- 2026-02-09: `RealmSwift` import footprint in `Code/Data` is now concentrated in `Code/Data/Infrastructure/Realm` plus only three known holdouts pending follow-up (`SpatialDataCache.swift`, `SpatialDataContext.swift`, and preview helper `Samplable.swift`).
- 2026-02-09: Moved preview Realm helper `Samplable.swift` from `Code/Data/Models/Preview Content` into `Code/Data/Infrastructure/Realm` and updated the Xcode file reference path.
- 2026-02-09: Validation for the seventh Infrastructure batch: seam guard passes, `xcodebuild build-for-testing` passes, targeted `RouteStorageProviderDispatchTests` pass (`26` tests), full `xcodebuild test-without-building` not rerun in this sub-slice (known baseline blocker remains simulator audio tests).
- 2026-02-09: `RealmSwift` imports in `Code/Data` are now fully concentrated in `Code/Data/Infrastructure/Realm` except `SpatialDataCache.swift` and `SpatialDataContext.swift`.
- 2026-02-09: Moved `SpatialDataCache.swift` and `SpatialDataContext.swift` from `Code/Data/Spatial Data` into `Code/Data/Infrastructure/Realm`, updated Xcode file reference paths, and refreshed seam-guard messaging to the new cache file location.
- 2026-02-09: Validation for the eighth Infrastructure batch: seam guard passes, `xcodebuild build-for-testing` passes, targeted `RouteStorageProviderDispatchTests` pass (`26` tests), full `xcodebuild test-without-building` not rerun in this sub-slice (known baseline blocker remains simulator audio tests).
- 2026-02-09: `RealmSwift` imports in `Code/Data` are now fully confined to `Code/Data/Infrastructure/Realm`.
- 2026-02-09: Added `apps/ios/Scripts/ci/check_realm_infrastructure_boundary.sh` and wired it into `.github/workflows/ios-tests.yml` so CI fails if `import RealmSwift` appears outside `GuideDogs/Code/Data/Infrastructure/Realm`.
- 2026-02-09: Added first `Data/Contracts` read surface (`SpatialReadContract` family + `DataContractRegistry`) and a Realm-backed adapter (`RealmSpatialReadContract`) that delegates to the existing `SpatialDataStoreRegistry` seam so runtime behavior stays unchanged.
- 2026-02-09: Migrated cloud sync read paths in `CloudKeyValueStore+Routes` and `CloudKeyValueStore+Markers` to contract-backed async internals (`syncRoutesAsync`, `syncReferenceEntitiesAsync`) while keeping sync wrappers for compatibility with current callers in `AppContext` and `SpatialDataContext`.
- 2026-02-09: Added `apps/ios/Scripts/ci/check_data_contract_boundaries.sh` and wired it into `.github/workflows/ios-tests.yml` to block `RealmSwift`, `CoreLocation`, and `MapKit` imports in `GuideDogs/Code/Data/Contracts` (and `Data/Domain` when introduced).
- 2026-02-09: Added unit coverage for the new seam (`DataContractRegistryDispatchTests`, `CloudSyncContractBridgeTests`) to validate contract dispatch, async-wrapper compatibility behavior, and fallback handling for invalid cloud payloads.
- 2026-02-09: Updated cloud-sync orchestration callsites to use async internals directly (`SpatialDataContext.handleCloudKeyValueStoreDidChange`, `AppContextDataRuntimeProviders.spatialDataContextPerformInitialCloudSync`) while preserving completion-based compatibility surfaces for existing callers.
- 2026-02-09: Added sync compatibility contracts (`SpatialReadCompatibilityContract` family) alongside async-first `SpatialReadContract`, wired `DataContractRegistry.spatialReadCompatibility`, and migrated additional synchronous read callers off direct `SpatialDataStoreRegistry` usage (`Route.swift`, `Route+Realm.swift` reads, `ReferenceEntity.swift` reads, `DestinationManager` read store methods, `MarkerParameters`, `LocationParameters`, `RouteParameters+Codable`, `RoadAdjacentDataView`, `Intersection`, `Road` protocol helpers, `Roundabout`, `GDASpatialDataResultEntity`).
- 2026-02-09: Remaining direct `SpatialDataStoreRegistry.store` callsites are now concentrated to expected seams: adapter implementation (`RealmSpatialReadContract`, 17), write/mutation seams pending write-contract extraction (`DestinationManager` temporary marker mutations + `Route.add` marker import, 5), and infrastructure tile/view orchestration (`SpatialDataContext` + `SpatialDataView`, 6).
- 2026-02-09: Migrated the remaining infrastructure tile/view read callsites (`SpatialDataContext`, `SpatialDataView`) to `DataContractRegistry.spatialReadCompatibility`, removing all direct `SpatialDataStoreRegistry` reads outside the adapter and write-mutation seams.
- 2026-02-09: Direct `SpatialDataStoreRegistry.store` usage is now limited to two intentional areas: `RealmSpatialReadContract` adapter implementation (17) and write mutation seams (`DestinationManager` temporary marker mutations + `Route.add` marker import, 5).
- 2026-02-09: Added first write-side contracts (`SpatialWriteContract`, `SpatialWriteCompatibilityContract`) and `DataContractRegistry` wiring (`spatialWrite`, `spatialWriteCompatibility`) with Realm-backed adapter implementation (`RealmSpatialWriteContract`).
- 2026-02-09: Migrated remaining write mutation callsites (`DestinationManager` temporary marker add/remove and `Route.add` marker import) to `DataContractRegistry.spatialWriteCompatibility`; direct `SpatialDataStoreRegistry` usage is now fully isolated to the Realm adapter file.
- 2026-02-09: Extended data contract seam tests with write dispatch coverage (`DataContractRegistryDispatchTests.testSpatialWriteCompatibilityDispatchesToConfiguredContract`) while preserving existing route/cloud dispatch suites.
- 2026-02-10: Marked temporary compatibility seams as explicitly deprecated (`@available(*, deprecated, message: ...)`) across compatibility contracts and registry compatibility accessors so migration targets are visible and searchable.
- 2026-02-10: Split Realm-backed data contract adapters into dedicated infrastructure files (`RealmSpatialReadContract.swift`, `RealmSpatialWriteContract.swift`) while keeping `DataContractRegistry` as the single seam entry point.
- 2026-02-10: Extended `check_data_contract_boundaries.sh` to also fail on direct app/runtime singleton symbols (`AppContext`, `AppContext.shared`, `UIRuntimeProviderRegistry`, `BehaviorRuntimeProviderRegistry`) in `Data/Contracts` and `Data/Domain`.
- 2026-02-10: Added lightweight metadata DTO surfaces on read contracts (`RouteReadMetadata`, `ReferenceReadMetadata`) and migrated cloud-sync local-update checks to these metadata methods instead of loading full `Route`/`ReferenceEntity` models for comparison logic.

## Architecture Baseline (from index analysis)
- Most coupled hub: `App/AppContext.swift` (high fan-in from `Data`, `Behaviors`, and `Visual UI`).
- Reverse edges indicating layering violations:
  - `Behaviors -> Visual UI`
  - `Data -> Visual UI`
  - `Data -> Behaviors`
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
  - `Data/Contracts` (repository/query/service protocols, DTOs, errors)
  - `Data/Infrastructure` (Realm/CoreLocation/GPX/file adapters)
  - `Data/Composition` (wiring only)
- Ban `Visual UI` imports in `Data/Domain` and `Data/Contracts`.

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
- Map adapter models <-> domain models at the boundary (no Realm types in contracts/use cases).
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
1. Continue replacing contract methods that expose `Data/Infrastructure/Realm` model types with DTO/value surfaces (starting with cloud-sync export/store paths that still pass `Route`/`ReferenceEntity`).
2. Add a follow-up guard that flags `Data/Contracts` references to model files under `Data/Infrastructure/Realm` so contract APIs can converge on domain DTO/value types.
3. Begin introducing `Data/Domain` folder structure with portable types as contracts gain DTO boundaries, then extend boundary scripts to include the new layer.
