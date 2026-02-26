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
- Contract boundary checks now temporarily allow only remaining infrastructure types in `Data/Contracts` (`Intersection`, `TileData`); currently detected usage is `Intersection`, `TileData`.

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
- `Data/Contracts` infrastructure-type guardrails now treat `Road` and `Route` as canonical app-facing protocol/value types, narrowing temporary infra allowlist coverage to `Intersection` and `TileData`.
- `RoadAdjacentDataView` now resolves marker callout data and nearby marker scans through infrastructure adapter helpers (`RoadAdjacentDataStoreAdapter`) instead of direct store access in preview-layer code.
- `LocationDetail` now resolves POI/marker lookup and marker-selection writes through infrastructure adapter helpers (`LocationDetailStoreAdapter`) instead of direct store access in UI-layer code.
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
   - Keep CI guardrail blocking `SpatialDataStoreRegistry.store` usage outside `Data/Infrastructure/Realm/**` (allowlist empty).
2. Unify storage-facing domain models (completed for first set):
   - Move `Route`, `RouteWaypoint`, `ReferenceEntity` value models out of Realm infrastructure files.
   - Keep Realm object models (`RealmRoute`, `RealmRouteWaypoint`, `RealmReferenceEntity`) infrastructure-local.
3. Shrink contract leakage (in progress):
   - Remove temporary infrastructure type allowlist entries from `Data/Contracts` as each type is replaced with domain/value equivalents.
4. Realm isolation hardening (in progress):
   - Expand Realm import boundary checks to whole `GuideDogs/Code` (with explicit temporary allowlist only if needed).
5. Extractable adapter boundary (in progress):
   - Ensure swapping persistence backend only requires a new adapter conforming to the three app-facing contracts.

## Done Criteria for “Realm Split Ready”
- `App`, `Behaviors`, `Visual UI`, and `Notifications` do not reference `Data/Infrastructure/Realm/**` directly.
- `DataContractRegistry` contracts contain no Realm infrastructure types.
- `RealmSwift` imports are confined to adapter/infrastructure files.
- A non-Realm in-memory adapter passes contract behavior tests without special-case shims.
