<!-- Copyright (c) Soundscape Community Contributers. -->

# Data Modularization North Star

Last updated: 2026-03-11

## Document Contract
- This document defines the stable modularization target for shared data/domain code and storage boundaries.
- This document should change rarely.
- Progress and migration history belong in `docs/plans/modularization_plan.md`.
- Day-to-day validation and execution defaults belong in `AGENTS.md`.

## Purpose
Define a stable target that supports three outcomes at once:
- keep the current iOS app readable and shippable during migration
- make Realm replaceable behind a stable contract boundary
- keep most non-UI app logic portable enough to move into shared code for future Android support

## Simplicity Principles
1. Prefer canonical domain/value models over new abstraction layers.
2. Keep API shapes readable and similar to existing behavior unless change is strictly required.
3. Do not introduce DTO families, extra registries, or package shells without clear local payoff.
4. If a seam feels complex, simplify the API first before adding tooling complexity.

## Stable Direction
### Shared Portable Core
`apps/common` is the portability target.

It should hold:
- `SSGeo`: portable coordinates, locations, and geodesic math
- `SSDataDomain`: shared app/domain concepts and portable domain helpers
- `SSDataContracts`: storage contracts plus portable contract-side value types

### iOS Runtime Layer
`apps/ios` should hold:
- app composition and runtime bootstrapping
- `DataContractRegistry` as the single storage composition root
- platform services such as `CoreLocation`, audio, haptics, backgrounding, notifications, and UI integration
- platform-specific conveniences and presentation mapping that wrap shared models

### Backend Layer
Realm remains an infrastructure backend under `apps/ios/GuideDogs/Code/Data/Infrastructure/Realm/**` until it is ready to be split behind the stabilized app-side surface.
Replaceability comes before physical extraction: Realm may stay in the iOS app target for now, but non-infrastructure callers should depend on contracts and shared value types rather than Realm object models or cache/search helpers.

## Stable App-Facing Storage API
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
- do not move backend default construction into `apps/common`
- do not add a second generic registry layer just to make package boundaries look cleaner

## Shared Domain Direction
Use shared domain/value types directly at boundaries and in cross-platform logic.

Current examples include:
- `Route`, `RouteWaypoint`, `ReferenceEntity`
- `POI`, `GenericLocation`, `SuperCategory`
- shared POI typing, matching, filter construction, filtering, sorting, queueing, and generic array-query helpers that do not depend on Apple frameworks
- shared route/marker/location/universal-link parameter models and universal-link parsing/building value types
- `VectorTile` and other portable geometry/value helpers

Platform-specific wrappers should stay in `apps/ios` only when they genuinely depend on Apple frameworks or presentation/runtime services.

## Async and Compatibility Policy
- Contracts are async-first (`async`/`await`) and explicit about failure (`throws`).
- Do not reintroduce removed compatibility surfaces (`spatialReadCompatibility`, `spatialWriteCompatibility`).
- Temporary compatibility seams must be explicitly deprecated and short-lived.
- Do not reintroduce retired sync-store registry/shim patterns.

## Infrastructure-Only APIs
Must not be used by non-infrastructure code:
- `SpatialDataCache`
- `DestinationEntityStore`
- Realm object models (`RealmRoute`, `RealmRouteWaypoint`, `RealmReferenceEntity`, etc.)
- any `RealmSwift`-dependent API

## Boundary Rules
- `apps/common/Sources` must remain free of Apple UI/platform framework imports.
- `Data/Contracts` must remain free of Realm infrastructure types.
- `RealmSwift` imports are confined to `Data/Infrastructure/Realm/**`.
- `SpatialDataCache` usage is confined to `Data/Infrastructure/Realm/**`.
- New shared-domain logic should move to `apps/common` when it no longer depends on Apple frameworks or UI/runtime behavior.
- New app/runtime data behavior must be exposed through `DataContractRegistry` contracts.
- `DataContractRegistry` stores installed defaults but must not construct Realm adapters directly; backend default installation belongs to infrastructure-owned installer code.
- Avoid adding global registries or parallel ingress points.

## Target Extraction Shape
- `apps/common/Sources/SSGeo`: portable geometry, location payloads, bearings, and distance math.
- `apps/common/Sources/SSDataDomain`: canonical platform-neutral domain/value models and portable domain helpers.
- `apps/common/Sources/SSDataContracts`: async contract protocols and portable contract-side value types.
- `apps/ios/GuideDogs/Code/Data/Contracts` and adjacent runtime extensions: iOS-specific composition plus platform/presentation shims.
- `apps/ios/GuideDogs/Code/Data/Infrastructure/Realm/**`: Realm-backed contract implementations, object mappings, migrations, cache/search infrastructure, and backend installers.

Recommended split:
1. Keep `SSGeo`, `SSDataDomain`, and `SSDataContracts` as the shared portable core.
2. Move pure domain/value/helper logic into `apps/common` instead of creating an intermediate iOS package layer.
3. Keep `DataContractRegistry` in `apps/ios` as the single composition root that chooses the concrete backend.
4. Keep platform-only wrappers in `apps/ios` until they are genuinely portable.
5. Extract `Data/Infrastructure/Realm/**` into a backend target/package only after it depends on a stable shared/app-side surface rather than the full app runtime.

Do not put `DataContractRegistry` in `apps/common`.
Reason: the registry is where concrete backend selection happens, and moving that into the portable package would either leak backend knowledge upward or require unnecessary glue.

Do not use `apps/ios/Package.swift` as a modularization boundary.
Reason: it is editor/tooling scaffolding, not part of the architectural split.

## Static Success Criteria
- Non-infrastructure app code uses `DataContractRegistry` contracts for storage ingress.
- Non-infrastructure app code does not depend directly on Realm object models, `SpatialDataCache`, or other infrastructure-local helpers.
- `apps/common` contains the portable domain/value/helper surface for shared app logic.
- `Data/Contracts` contain no Realm infrastructure types.
- `RealmSwift` imports remain confined to Realm infrastructure.
- App-facing model shapes remain stable and domain-first.
- Shared logic is isolated from platform code by thin iOS wrappers rather than backend-specific types.
- Realm can be replaced by swapping a backend dependency rather than rewriting app/runtime callers.
- Future Android work can reuse shared domain/contracts/helpers rather than reimplementing them from scratch.

## Related Plan
- Active execution and status: `docs/plans/modularization_plan.md`
