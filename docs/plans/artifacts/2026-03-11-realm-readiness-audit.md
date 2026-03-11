<!-- Copyright (c) Soundscape Community Contributers. -->

# Realm Replaceability Readiness Audit

Date: 2026-03-11

## Conclusion
Realm is not fully replaceable yet.

The app-facing caller surface is largely contract-first, but the Realm backend is still coupled to iOS runtime behavior in several files. The current inventory of `apps/ios/GuideDogs/Code/Data/Infrastructure/Realm/**` is:

- `10` backend-ready files
- `7` mixed files that still combine persistence logic with runtime side effects
- `3` runtime-owned files that should stay in `apps/ios` when a backend target/package is introduced

## Coupling Clusters
- `DataRuntimeProviderRegistry`: `RealmRoute.swift`, `RealmReferenceEntity.swift`, `GDASpatialDataResultEntity.swift`, `SpatialDataContext.swift`
- `NotificationCenter`: `RealmReferenceEntity.swift`, `SpatialDataContext.swift`
- `GDATelemetry`: `SpatialDataCache.swift`, `Intersection.swift`, `RealmReferenceEntity.swift`, `SpatialDataContext.swift`
- App lifecycle/resource globals: `SpatialDataContext.swift` uses `Bundle.main`, `UserDefaults`, and `UIApplication`
- Preview/UI glue: `Samplable.swift` imports `SwiftUI` and bootstraps preview data

## File Classification
### Backend-ready
These can remain in the backend target once the mixed/runtime-owned files stop pulling app-runtime concerns back across the boundary.

- `TileData.swift`: Realm cache model only
- `RouteRealmError.swift`: backend error surface only
- `RealmString.swift`: Realm string wrapper only
- `RealmHelper.swift`: Realm configuration/database access only
- `Address.swift`: Realm-backed POI/cache model
- `OsmTag.swift`: Realm-backed value/model helper
- `IntersectionRoadId.swift`: Realm-backed relation model
- `RealmRouteWaypoint.swift`: Realm-backed route waypoint model/mapping
- `RealmSpatialReadContract.swift`: async contract reads over backend-local cache/models
- `RealmMigrationTools.swift`: migration helper now routes failure reporting through `RealmMigrationRuntime`

### Mixed
These still combine backend persistence with runtime side effects and must be split or redirected before backend extraction.

- `SpatialDataCache.swift`: backend search/cache logic plus bootstrap and telemetry hooks
- `RealmSpatialWriteContract.swift`: backend writes plus destination-clearing runtime calls and cloud-removal dispatch during cache reset
- `GDASpatialDataResultEntity.swift`: backend entity model plus current-user-location runtime access
- `RealmReferenceEntity.swift`: backend marker model/mapping plus cloud sync, destination mutation, callout-history, event dispatch, telemetry, and notifications
- `Intersection.swift`: backend intersection model plus telemetry warning path
- `Route+Realm.swift`: backend route persistence plus cloud sync and active-route behavior hooks
- `RealmRoute.swift`: backend route model/mapping plus route runtime provider access

### Runtime-owned
These should remain in `apps/ios` runtime/composition code and be excluded from the first backend target candidate.

- `SpatialDataContext.swift`: app lifecycle, notifications, initial cloud sync, audio-engine updates, bundle resources, defaults, and UI presentation
- `DataContractRegistry+RealmDefaults.swift`: concrete backend installation into the iOS composition root
- `Samplable.swift`: preview/test sample data and `SwiftUI` preview environment glue

## First Refactor Slice
Completed on 2026-03-11:

1. Split `RealmRoute.swift` and `RealmReferenceEntity.swift` so their `DataRuntimeProviderRegistry` usage moves behind iOS-owned runtime adapters or explicit backend callback dependencies.
2. Keep the persistence/model logic in those files backend-local while routing the first notification/telemetry slice in `Route+Realm.swift`, `RealmSpatialWriteContract.swift`, and `RealmMigrationTools.swift` through explicit runtime integrations.
3. Do not attempt a backend target/package split in the same change.

## Follow-on Refactor Order
After the route/reference runtime chokepoints and the first telemetry/notification slice are removed:

1. Re-audit the remaining runtime-global usage in `GDASpatialDataResultEntity.swift` and `SpatialDataContext.swift`.
2. Continue peeling cloud-sync, destination-mutation, and marker add/edit/remove side effects out of `Route+Realm.swift`, `RealmSpatialWriteContract.swift`, `RealmReferenceEntity.swift`, and `SpatialDataCache.swift`.
3. Re-run the audit; only then choose the first concrete backend target/package boundary.
