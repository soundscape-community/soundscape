<!-- Copyright (c) Soundscape Community Contributers. -->

# Data Storage API North Star

Last updated: 2026-03-04

## Document Contract
- This document defines the target data API and boundary rules.
- This document should change rarely.
- Progress, checkpoints, metrics, and migration history belong in `docs/plans/modularization_plan.md`.

## Purpose
Define a stable, minimal, app-facing data API so storage and persistence can be modularized without proliferating seams or leaking Realm infrastructure details.

## Final App-Facing API (Stable)
### Entry Point
`DataContractRegistry` is the only app-facing storage ingress, exposing:
- `spatialRead: SpatialReadContract`
- `spatialWrite: SpatialWriteContract`
- `spatialMaintenanceWrite: SpatialMaintenanceWriteContract`

### Contract Responsibilities
- `SpatialReadContract`: async query/read operations for app/runtime consumers.
- `SpatialWriteContract`: async user-driven domain writes (routes, markers, destination-affecting writes).
- `SpatialMaintenanceWriteContract`: async maintenance/import/repair operations (for example cloud import and cleanup flows).

### Canonical Domain Surface
App-facing contracts expose domain/value types only. Canonical examples:
- `Route`
- `RouteWaypoint`
- `ReferenceEntity`
- Existing readable domain/value models used by app features (`POI`, `GenericLocation`, etc.)

No app-facing contract may expose Realm object models or Realm-local type families.

### Async Policy
- Contracts are async-first (`async`/`await`) and explicit about failure (`throws`).
- No parallel sync contract surface is introduced or reintroduced.
- Do not reintroduce removed compatibility surfaces (`spatialReadCompatibility`, `spatialWriteCompatibility`).
- If a temporary compatibility seam is required, mark it deprecated with a clear replacement and intended removal direction.

## Infrastructure-Only APIs (Non App-Facing)
The following are implementation details and must not be used by non-infrastructure code:
- `SpatialDataStoreRegistry.store`
- `SpatialDataCache`
- `DestinationEntityStore`
- Realm object models (`RealmRoute`, `RealmRouteWaypoint`, `RealmReferenceEntity`, etc.)
- Any `RealmSwift`-dependent API

## Boundary Rules
- `Data/Contracts` must remain free of Realm and platform-bound infrastructure types.
- `RealmSwift` imports are confined to `Data/Infrastructure/Realm/**`.
- New storage behavior for `App`, `Behaviors`, `Visual UI`, or `Notifications` must be added through `DataContractRegistry` contracts first.
- Production Realm adapter wiring remains centralized in `DataContractRegistry` default static declarations (`RealmSpatial*Contract()` is not used ad hoc in runtime methods).
- `DataContractRegistry.configure/resetForTesting` seams are test-only (`UnitTests/**`).
- Do not add new global data registries.
- Do not introduce DTO families when canonical domain models are already readable and sufficient.

## Target Extraction Shape
- `apps/common/Sources/SSDataDomain`: platform-neutral canonical domain/value models.
- `apps/common/Sources/SSDataContracts`: platform-neutral async data contract protocols and shared contract-side types.
- `apps/ios/GuideDogs/Code/Data/Infrastructure/Realm`: iOS-only persistence adapter and Realm mapping.

## Static Success Criteria
- Non-infrastructure app code uses only `DataContractRegistry` contracts for storage ingress.
- `Data/Contracts` contain no Realm infrastructure types.
- `RealmSwift` imports remain confined to Realm infrastructure.
- Canonical app-facing models remain stable and domain-shaped (`Route` stays a value type).
- A non-Realm in-memory adapter can satisfy contract behavior tests without special-case shims.

## Related Plan
- Implementation status, metrics, and next execution slices: `docs/plans/modularization_plan.md`
