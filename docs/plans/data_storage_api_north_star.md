<!-- Copyright (c) Soundscape Community Contributers. -->

# Data Storage API North Star

Last updated: 2026-03-09

## Document Contract
- This document defines the target data API and boundary rules.
- This document should change rarely.
- Progress/migration history belongs in `docs/plans/modularization_plan.md`.
- Day-to-day execution/logging defaults belong in `AGENTS.md` to keep this document stable.

## Purpose
Define a stable, minimal app-facing data API that stays close to existing data behavior while isolating Realm infrastructure.

## Simplicity Principles
1. Prefer canonical domain/value models over new abstraction layers.
2. Keep API shapes readable and similar to prior Realm-backed behavior unless change is strictly required.
3. Do not introduce DTO families or protocol stacks without clear, local payoff.
4. If a seam feels complex, simplify the API first before adding tooling complexity.

## Final App-Facing API (Stable)
### Entry Point
`DataContractRegistry` is the only app-facing storage ingress.

It exposes:
- `spatialRead: SpatialReadContract`
- `spatialWrite: SpatialWriteContract`
- `spatialMaintenanceWrite: SpatialMaintenanceWriteContract`

### Contract Responsibilities
- `SpatialReadContract`: async query/read operations.
- `SpatialWriteContract`: async user-driven domain writes.
- `SpatialMaintenanceWriteContract`: async maintenance/import/repair flows.

### Canonical Domain Surface
Use domain/value types directly at contract boundaries (for example `Route`, `RouteWaypoint`, `ReferenceEntity`, `POI`, `GenericLocation`), not Realm object models.

## Async Policy
- Contracts are async-first (`async`/`await`) and explicit about failure (`throws`).
- Do not reintroduce removed compatibility surfaces (`spatialReadCompatibility`, `spatialWriteCompatibility`).
- Temporary compatibility seams must be explicitly deprecated and short-lived.

## Infrastructure-Only APIs (Non App-Facing)
Must not be used by non-infrastructure code:
- `SpatialDataCache`
- `DestinationEntityStore`
- Realm object models (`RealmRoute`, `RealmRouteWaypoint`, `RealmReferenceEntity`, etc.)
- Any `RealmSwift`-dependent API

## Boundary Rules
- `Data/Contracts` must remain free of Realm infrastructure types.
- `RealmSwift` imports are confined to `Data/Infrastructure/Realm/**`.
- New app/runtime data behavior must be exposed through `DataContractRegistry` contracts.
- Production Realm adapter wiring stays centralized in `DataContractRegistry` default static declarations.
- Avoid adding global registries or parallel ingress points.

## Target Extraction Shape
- `apps/common/Sources/SSDataDomain`: canonical platform-neutral domain/value models.
- `apps/common/Sources/SSDataContracts`: async contract protocols and shared contract-side types.
- `apps/ios/GuideDogs/Code/Data/Infrastructure/Realm`: iOS-only persistence adapter and Realm mapping.

## Static Success Criteria
- Non-infrastructure app code uses only `DataContractRegistry` contracts for storage ingress.
- `Data/Contracts` contain no Realm infrastructure types.
- `RealmSwift` imports remain confined to Realm infrastructure.
- App-facing model shapes remain stable and domain-first.
- In-memory adapter can satisfy contract behavior tests without adapter-specific shims.

## Related Plan
- Active execution and status: `docs/plans/modularization_plan.md`
