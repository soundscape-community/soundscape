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

Current packaging decision:
- `apps/common` remains the portable core for domain models, geo types, and storage contracts.
- `DataContractRegistry` remains the single composition root, but should not be forced into the portable core.
- Realm replacement readiness now depends more on package extraction shape than on additional runtime seam cleanup.

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
- The main open design choice is now settled: prefer a portable contracts core plus iOS storage-support target plus Realm backend target, rather than adding another registry abstraction layer.

## Current Status
Completed:
- Common data modules are extracted and tested in `apps/common`.
- In-memory contract parity is complete.
- Structural boundary checks are active and currently green.
- Sync-store compatibility registry/shim reintroduction is structurally blocked and absent from app/test code.
- App-layer `RealmHelper` usage is now zero.

In progress:
- Prepare the storage code for package extraction instead of continuing incidental seam cleanup.
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
6. Keep `DataContractRegistry` as the single composition root; do not add a second registry layer for modularization.
7. Prefer one iOS storage-support target and one Realm backend target over multiple thin glue targets.

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
- Keep app-facing call sites stable and readable.

### Milestone C: Package Extraction Readiness
Status: In progress

Remaining focus:
- Create a package boundary for the iOS-specific storage-support surface (`DataContractRegistry`, `Data/Contracts`, and non-portable contract-associated value types).
- Extract Realm infrastructure behind that boundary without introducing additional ingress layers.

### Milestone D: Behavior Confidence and Closure
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
- Chose the extraction direction: keep `apps/common` portable, keep `DataContractRegistry` as the composition root, and split future package work into iOS storage-support plus Realm backend targets.
- Revalidated targeted modularization coverage with simulator-backed local runs.

## Next Steps
1. Create an explicit iOS storage-support target/package boundary around `DataContractRegistry`, `Data/Contracts`, and the iOS-specific contract-associated value types that are not yet portable.
2. Extract `Data/Infrastructure/Realm/**` into a Realm backend target/package that depends on that storage-support target instead of the full app target.
3. Keep app-level storage ingress contract-first through `DataContractRegistry`; avoid introducing new side-entry points or secondary registries.
4. Move additional types into `apps/common` only when they are genuinely platform-neutral and runtime-neutral.
5. Refresh dependency analysis artifacts only when a meaningful dependency-shape delta is expected.

## Handoff
- Use `docs/plans/data_storage_api_north_star.md` for the stable target.
- Use this file for current status only.
- Start the next slice with one focused cleanup, validate with `--output quiet`, then update this file only if the current status or next steps materially changed.
