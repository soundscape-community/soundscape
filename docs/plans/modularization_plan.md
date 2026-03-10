<!-- Copyright (c) Soundscape Community Contributers. -->

# Modularization Plan

Last updated: 2026-03-10

## Summary
Continue extracting the data layer toward a small, stable contract surface.
Keep Realm implementation details isolated under `Data/Infrastructure/Realm`, keep app-facing APIs centered on `DataContractRegistry`, and prefer deleting compatibility seams over adding new ones.

## Scope
In scope:
- App-facing data API shape and naming stability.
- Realm isolation boundaries.
- Contract behavior confidence through focused validation.
- Low-noise local validation and handoff hygiene.

Out of scope:
- New abstraction families such as DTO stacks or extra shim hierarchies.
- Parser-style seam hardening beyond clear structural boundary checks.
- Broad UI or behavior architecture work unrelated to the data-layer boundary.

## Current Assessment
Progress is materially good:
- `SSDataStructures`, `SSGeo`, `SSDataDomain`, and `SSDataContracts` are extracted into `apps/common`.
- `DataContractRegistry` is the app-facing data ingress.
- Realm adapter wiring is centralized and guarded.
- The retired sync-store seam has been removed from `apps/ios/GuideDogs/Code` and `apps/ios/UnitTests`.

Local evidence as of 2026-03-10:
- `RealmSwift` imports outside `Data/Infrastructure/Realm/**`: `0`
- `SpatialDataCache` usage outside `Data/Infrastructure/Realm/**`: `0`
- `RealmHelper` usage outside `Data/Infrastructure/Realm/**`: `0`
- `RealmSpatial*Contract()` construction outside registry/tests: `0`
- Residual sync-store seam symbols in app/test Swift sources: `0`
- `spatialReadCompatibility` / `spatialWriteCompatibility` references: `0`

Plan sanity assessment:
- The north star is still correct: contract-first ingress, domain/value models at the boundary, Realm kept infrastructure-local.
- The previous plan had become too historical and noisy. It is now trimmed to current status, current rules, and current next steps.
- Remaining work is now mostly cleanup and closure work, not large architectural uncertainty.

## Current Status
Completed:
- Common data modules are extracted and tested in `apps/common`.
- In-memory contract parity is complete.
- Structural boundary checks are active and currently green.
- Sync-store compatibility registry/shim reintroduction is structurally blocked and absent from app/test code.

In progress:
- Continue shrinking residual Realm-owned helper/runtime surface where the contract/value shape is already sufficient.
- Keep app-level storage usage readable and contract-first.
- Close remaining migration steps in small validated slices.

Known non-blocking local full-suite failures:
- `AudioEngineTest.testDiscreteAudio2DSimple`
- `AudioEngineTest.testDiscreteAudio2DSeveral`

## Boundary Rules
1. No `RealmSwift` imports outside `Data/Infrastructure/Realm/**`.
2. No global sync-store compatibility registry or equivalent seam reintroduction.
3. No non-registry/non-test `RealmSpatial*Contract()` construction.
4. No app-facing Realm model types in `Data/Contracts`.
5. Keep cloud marker dispatch value-shaped (`MarkerParameters` updates, marker-ID deletes) unless a concrete production caller requires something else.

## Validation Snapshot
Preferred local workflow:
1. `bash apps/ios/Scripts/ci/run_local_validation.sh -- --output quiet`
2. `bash apps/ios/Scripts/ci/run_data_modularization_targeted_tests.sh --output quiet`
3. Refresh dependency analysis only when dependency shape meaningfully changes.

Latest local results on 2026-03-10:
- `bash apps/ios/Scripts/ci/run_data_modularization_targeted_tests.sh --output quiet`: passed, `61` tests, `0` failures.
- `bash apps/ios/Scripts/ci/run_local_validation.sh -- --output quiet`: boundary scripts green, iOS build-for-testing passed, full-suite test phase reached only the two known non-blocking `AudioEngineTest` failures.

## Milestone Status
### Milestone A: Reset and Guardrail Simplification
Status: Completed

Outcome:
- The plan is reset around high-signal structural rules instead of speculative seam permutations.
- Validation defaults are low-noise.

### Milestone B: API Surface Consolidation
Status: In progress

Remaining focus:
- Keep removing compatibility helpers where contract/value-shaped paths already exist.
- Keep app-facing call sites stable and readable.

### Milestone C: Behavior Confidence and Closure
Status: In progress

Remaining focus:
- Keep targeted data suites reliable.
- Keep the boundary scripts green while closing the remaining cleanup slices.

## Recent Completed Work
- Removed the retired sync-store seam from app and unit-test code and aligned the boundary script to enforce that state.
- Narrowed marker cloud dispatch to `MarkerParameters` updates and marker-ID deletes.
- Removed the last non-infrastructure `RouteRuntime` usage by routing route-guidance deactivation through `BehaviorDelegate` instead of a Realm-owned runtime wrapper.
- Removed dead Realm-typed overloads and stale `RealmReferenceEntity` references from non-infrastructure model/serialization/UI code; the remaining concrete Realm-model references outside infrastructure were then isolated and removed.
- Moved `GenericLocationSearchProvider`, `OSMPOISearchProvider`, and `AddressSearchProvider` Realm-backed implementations into `Data/Infrastructure/Realm`, then moved the remaining app-layer `RealmHelper` calls behind infrastructure-owned extensions and neutral façades.
- Renamed the route persistence error surface from `RouteRealmError` to `RouteDataError`, removing the last UI-facing Realm-branded error reference from runtime code.
- Revalidated targeted modularization coverage with simulator-backed local runs.

## Next Steps
1. Keep the remaining explicit Realm-owned type names outside `Data/Infrastructure/Realm/**` limited to the registry's allowed default adapter construction unless a concrete migration step requires otherwise.
2. Keep app-level storage ingress contract-first through `DataContractRegistry`; avoid introducing new side-entry points or registry-style helpers.
3. Refresh dependency analysis artifacts only when a meaningful dependency-shape delta is expected.
4. Keep plan/docs concise; detailed slice history should live in git history rather than this document.

## Handoff
- Use `docs/plans/data_storage_api_north_star.md` for the stable target.
- Use this file for current status only.
- Start the next slice with one focused cleanup, validate with `--output quiet`, then update this file only if the current status or next steps materially changed.
