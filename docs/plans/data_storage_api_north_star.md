<!-- Copyright (c) Soundscape Community Contributers. -->

# Data Storage API North Star

Last updated: 2026-03-10

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

### Composition Root Rule
`DataContractRegistry` is a composition root, not a portability target.

That means:
- app/runtime code should keep reading and writing through `DataContractRegistry`
- storage backends should conform to the contracts, not own parallel ingress points
- do not move Realm-backed default construction into `apps/common`
- do not add a second generic registry layer just to make package boundaries look cleaner

### Canonical Domain Surface
Use domain/value types directly at contract boundaries (for example `Route`, `RouteWaypoint`, `ReferenceEntity`, `POI`, `GenericLocation`), not Realm object models.

## Async Policy
- Contracts are async-first (`async`/`await`) and explicit about failure (`throws`).
- Do not reintroduce removed compatibility surfaces (`spatialReadCompatibility`, `spatialWriteCompatibility`).
- Temporary compatibility seams must be explicitly deprecated and short-lived.
- Do not reintroduce retired sync-store registry/shim patterns.

## Infrastructure-Only APIs (Non App-Facing)
Must not be used by non-infrastructure code:
- `SpatialDataCache`
- `DestinationEntityStore`
- Realm object models (`RealmRoute`, `RealmRouteWaypoint`, `RealmReferenceEntity`, etc.)
- Any `RealmSwift`-dependent API

## Boundary Rules
- `Data/Contracts` must remain free of Realm infrastructure types.
- `RealmSwift` imports are confined to `Data/Infrastructure/Realm/**`.
- `SpatialDataCache` usage is confined to `Data/Infrastructure/Realm/**`.
- New app/runtime data behavior must be exposed through `DataContractRegistry` contracts.
- `DataContractRegistry` stores installed defaults but must not construct Realm adapters directly; backend default installation belongs to infrastructure-owned installer code.
- Avoid adding global registries or parallel ingress points.

## Target Extraction Shape
- `apps/common/Sources/SSDataDomain`: canonical platform-neutral domain/value models.
- `apps/common/Sources/SSDataContracts`: async contract protocols and shared contract-side types.
- iOS-only storage-support target/package: concrete contract-boundary types that are still app/platform-shaped (for example `POI`, `GenericLocation`, `VectorTile`, route/marker parameter types, and the registry composition root).
- Realm storage target/package: Realm-backed contract implementations plus Realm object mappings/migrations/cache/search infrastructure.

Recommended split:
1. Keep `SSDataDomain`, `SSGeo`, and `SSDataContracts` as the shared portable core.
2. Extract the current `Data/Contracts` surface plus the iOS-specific associated-value types into a small iOS package target.
3. Extract `Data/Infrastructure/Realm/**` into a separate Realm storage target that depends on that iOS storage-support target.
4. Keep `DataContractRegistry` in the iOS storage-support target or app target as the single composition root that chooses the concrete backend.

Do not put `DataContractRegistry` in `apps/common`.
Reason: the registry is where concrete backend selection happens, and moving that into the portable package would either leak backend knowledge upward or require unnecessary type-erasure/glue layers.

Portable-first guidance:
- move pure value types to `apps/common` only when they do not depend on app runtime behavior or Apple frameworks
- keep associated-type-bound contracts in `SSDataContracts` when they need to abstract over iOS-only values such as `POI` or `VectorTile`
- prefer one iOS support target plus one backend target over several micro-targets

## Static Success Criteria
- Non-infrastructure app code uses only `DataContractRegistry` contracts for storage ingress.
- `Data/Contracts` contain no Realm infrastructure types.
- `RealmSwift` imports remain confined to Realm infrastructure.
- App-facing model shapes remain stable and domain-first.
- In-memory adapter can satisfy contract behavior tests without adapter-specific shims.
- Realm can be removed from the app target by swapping a single storage backend dependency rather than rewriting app/runtime callers.

## Related Plan
- Active execution and status: `docs/plans/modularization_plan.md`
