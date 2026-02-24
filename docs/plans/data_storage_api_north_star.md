<!-- Copyright (c) Soundscape Community Contributers. -->

# Data Storage API North Star

Last updated: 2026-02-24

## Purpose
Define a stable, minimal, app-facing data API before deeper Realm extraction work so incremental seams do not produce a fragmented contract surface.

## Current State (Observed)
- Storage access is split across multiple entry points:
  - `DataContractRegistry` async contracts for app/runtime callers.
  - `SpatialDataStoreRegistry.store` sync storage seam used in many non-adapter paths.
  - `DestinationEntityStore` as a parallel destination-specific abstraction.
- Domain-looking models are still defined in Realm infrastructure files (`Route`, `RouteWaypoint`, `ReferenceEntity`) that import `RealmSwift`.
- Dependency analysis still shows reverse layering pressure:
  - `Data -> App`: 712
  - `Data -> Visual UI`: 90
  - `Data -> Behaviors`: 62
  - `Behaviors -> Visual UI`: 217
- Contract boundary checks still temporarily allow infrastructure types in `Data/Contracts` (`Route`, `Road`, `Intersection`, `TileData`, `RealmReferenceEntity`).

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

## 2026-02-24 Checkpoint: Remaining Sync Callers
- Remaining staged `SpatialDataStoreRegistry.store` callers are concentrated in sync-heavy paths:
  - `POICallout`, `AutoCalloutGenerator`
  - `LocationDetail`, `MarkerParameters`
  - `Road`, `Roundabout`, `RoadAdjacentDataView`, `SpatialDataView`
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
1. Lock ingress:
   - Migrate non-infrastructure `SpatialDataStoreRegistry.store` usages to `DataContractRegistry` contracts.
   - Add a CI guardrail that blocks `SpatialDataStoreRegistry.store` usage outside `Data/Infrastructure/Realm/**`.
2. Unify storage-facing domain models:
   - Move `Route`, `RouteWaypoint`, `ReferenceEntity` value models out of Realm infrastructure files.
   - Keep Realm object models (`RealmRoute`, `RealmRouteWaypoint`, `RealmReferenceEntity`) infrastructure-local.
3. Shrink contract leakage:
   - Remove temporary infrastructure type allowlist entries from `Data/Contracts` as each type is replaced with domain/value equivalents.
4. Realm isolation hardening:
   - Expand Realm import boundary checks to whole `GuideDogs/Code` (with explicit temporary allowlist only if needed).
5. Extractable adapter boundary:
   - Ensure swapping persistence backend only requires a new adapter conforming to the three app-facing contracts.

## Done Criteria for “Realm Split Ready”
- `App`, `Behaviors`, `Visual UI`, and `Notifications` do not reference `Data/Infrastructure/Realm/**` directly.
- `DataContractRegistry` contracts contain no Realm infrastructure types.
- `RealmSwift` imports are confined to adapter/infrastructure files.
- A non-Realm in-memory adapter passes contract behavior tests without special-case shims.
