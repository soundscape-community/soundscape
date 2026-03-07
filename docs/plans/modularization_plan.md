<!-- Copyright (c) Soundscape Community Contributers. -->

# Modularization Plan

Last updated: 2026-03-06

## Summary
Simplify the data modularization plan around a small, stable model/API surface.
Keep Realm infrastructure isolated, keep app-facing APIs close to existing model behavior, and stop expanding guardrails into an unbounded parser project.

## Scope
In scope:
- App-facing data API shape and naming stability.
- Realm isolation boundaries.
- Contract behavior confidence via focused tests.
- Low-noise validation workflows.

Out of scope:
- New abstraction families (DTO layers, extra shim/protocol hierarchies).
- Endless edge-case regex/state-machine hardening beyond practical risk.
- Broad UI or behavior architecture rewrites.

## Reset Decision (2026-03-06)
1. Freeze new seam-edge-case hardening work in `check_data_contract_boundaries.sh` unless a concrete production-risk bypass is discovered.
2. Prioritize API/model clarity and migration completion over guardrail permutation coverage.
3. Keep only high-signal enforcement and test confidence gates.

## Architecture North Star (Condensed)
- App ingress remains `DataContractRegistry`.
- App-facing models remain canonical domain/value types (`Route`, `RouteWaypoint`, `ReferenceEntity`, existing readable models).
- Realm object models remain infrastructure-local under `Data/Infrastructure/Realm`.
- Contracts remain async-first and explicit (`async`/`throws`).

## Current Status
Completed:
- `SSDataStructures`, `SSGeo`, `SSDataDomain`, and `SSDataContracts` are extracted into `apps/common`.
- In-memory contract parity milestone is complete.
- Core boundary checks are in place and active.

Active:
- Milestone 3 simplification and closure: consolidate to minimal boundaries and finish migration with stable behavior.

Known non-blocking local full-suite failures:
- `AudioEngineTest.testDiscreteAudio2DSimple`
- `AudioEngineTest.testDiscreteAudio2DSeveral`

## Minimal Boundary Rules (Keep)
1. No `RealmSwift` imports outside `Data/Infrastructure/Realm/**`.
2. No `SpatialDataStoreRegistry.store` usage outside infrastructure.
3. No non-registry/non-test `RealmSpatial*Contract()` construction.
4. No app-facing Realm model types in `Data/Contracts`.

## Guardrail Simplification Policy
- Keep existing guardrail script coverage as-is.
- Do not add new seam-shape detectors unless:
  - the bypass is reproducible,
  - the bypass is practically likely, and
  - it cannot be covered more simply by test + structural boundary rules.
- Prefer deleting/merging brittle checks when equivalent protection exists through stronger structural rules.

## Validation Strategy (Low-Noise)
Default local workflow:
1. `bash apps/ios/Scripts/ci/run_local_validation.sh -- --output xcpretty`
2. `bash apps/ios/Scripts/ci/run_local_ios_build_test.sh --build-only --derived-data-path /tmp/ss-index-derived --output errors`
3. `bash tools/SSIndexAnalyzer/Scripts/export_analysis_report.sh --store-path /tmp/ss-index-derived/Index.noindex/DataStore --top 40 --min-count 2 --file-top 40 --external-top 25`
4. `bash apps/ios/Scripts/ci/run_data_modularization_targeted_tests.sh --output xcpretty`

Execution notes:
- Prefer concise output modes (`errors`, `xcpretty`).
- Treat one-off targeted-suite flakes as intermittent only if immediate rerun passes.

## Milestones
### Milestone A: Plan and Guardrail Reset
Status: In progress

Tasks:
- Freeze further seam-permutation expansion.
- Define minimal high-signal boundary set.
- Keep existing checks but stop speculative hardening.

Acceptance:
- Plan/docs reflect reset policy.
- No new speculative seam slices are opened.

### Milestone B: API Surface Consolidation
Status: In progress

Tasks:
- Keep app-facing data APIs close to prior Realm-backed model behavior.
- Remove/avoid redundant abstractions and temporary shims where not required.
- Ensure naming and behavior stay readable/stable for callers.

Acceptance:
- No new DTO family or extra protocol layering introduced for this work.
- Call sites remain straightforward and behaviorally equivalent.

### Milestone C: Behavior Confidence and Closure
Status: Pending

Tasks:
- Focus on dispatch/integration behavior tests rather than seam-shape regex growth.
- Close remaining migration items with small, test-backed slices.

Acceptance:
- Targeted data suites pass reliably.
- Boundary checks stay green without additional parser-like complexity.

## Progress Updates
- 2026-03-06: Plan reset initiated to reduce complexity and token churn.
- 2026-03-06: Guardrail policy changed from seam-permutation expansion to minimal high-signal boundary enforcement.
- 2026-03-06: Added low-noise targeted-suite wrapper `apps/ios/Scripts/ci/run_data_modularization_targeted_tests.sh` to reduce repeated manual `xcodebuild` context pollution and standardize reruns.
- 2026-03-06: Simplified async route waypoint validation by removing the pre-check dependency on sync `RouteWaypoint(index:markerId:)` in `RouteWaypoint.validated(...)`, keeping persisted-waypoint shape domain-first (`importedReferenceEntity: nil`).
- 2026-03-06: Removed sync store-probe validation from `RouteWaypoint.init?(index:markerId:)`; existence checks now stay in async call paths that already receive `SpatialReadContract`.
- 2026-03-05: Latest dependency artifact: `docs/plans/artifacts/dependency-analysis/20260305-120430Z-ssindex-d98603a.txt`.

## Immediate Next Steps
1. Apply the same simplification principles to implementation slices (model-first, minimal seams, no new abstraction families).
2. Continue removing sync compatibility lookups from async model/serialization paths where contract-based async reads already exist.
3. Use `run_data_modularization_targeted_tests.sh` for targeted data-suite runs; add wrappers only where repetition/noise still hurts execution.
4. Keep dependency tracking cadence but report only meaningful deltas.

## Context-Clear Handoff
- This plan is intentionally reset and shortened.
- Historical detailed seam-by-seam logs remain available in git history and prior revisions of this file.
- Use `docs/plans/data_storage_api_north_star.md` as the stable contract; use this file for active execution status only.
