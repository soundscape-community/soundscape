# Modularization Plan

Last updated: 2026-02-06

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
1. Complete remaining direct `CLLocation.distance(from:)` migrations in `Sensors`, `Data`, and selected `App` helpers where portable coordinate math can be used without API churn.
2. Run a fresh `xcodebuild build-for-testing` and regenerate dependency analysis artifact for the branch head.
3. Start Milestone 1 seam-carving by removing `AppContext` reads from `Data/Authored Activities` behind narrow injected protocols.
4. Keep this document and `AGENTS.md` updated in every modularization PR with status and next action.
