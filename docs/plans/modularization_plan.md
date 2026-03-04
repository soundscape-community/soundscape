<!-- Copyright (c) Soundscape Community Contributers. -->

# Modularization Plan

Last updated: 2026-03-04

## Summary
Modularize iOS code incrementally while keeping behavior stable, tightening architectural boundaries, and extracting platform-neutral data/domain contracts into `apps/common`.

## Scope
In scope:
- Shared Swift package work under `apps/common`.
- Data-first modularization for domain models and storage contracts.
- Realm isolation and adapter-bound persistence details.
- Guardrail and dispatch-test enforcement.

Out of scope (current phase):
- Broad UI architecture rewrites.
- Localization/resource migration.
- Non-essential behavior redesign.

## Plan Execution Rules
- After each scoped step: run validation, stage only that slice, and commit before the next step.
- Keep each slice small enough to reason about regressions quickly.

## Boundary Rules
- `apps/common/Sources` remains platform-agnostic.
- No Apple UI/platform imports in `apps/common/Sources`.
- `Data/Contracts` stays free of Realm infrastructure types.
- `RealmSwift` imports stay in `Data/Infrastructure/Realm/**`.
- `SpatialDataStoreRegistry.store` stays infrastructure-only.

## Model and API Policy
- Keep canonical domain/value models readable and stable (`Route` remains app-facing value type).
- Keep app ingress unified at `DataContractRegistry` async contracts.
- Avoid parallel sync contract surfaces.
- Add abstractions only when they materially improve boundaries/readability.

## Current Status
Completed foundations:
- `SSDataStructures`, `SSGeo`, and initial `SSDataDomain` extraction are in `apps/common` with package tests.
- Data seam guardrails active in CI:
  - `check_spatial_data_cache_seam.sh`
  - `check_realm_infrastructure_boundary.sh`
  - `check_data_contract_boundaries.sh`
  - `check_data_contract_infra_type_allowlist.sh`
  - `check_route_mutation_seam.sh`
- Async-first storage contracts in production use:
  - `SpatialReadContract`
  - `SpatialWriteContract`
  - `SpatialMaintenanceWriteContract`
- Strict infra-only enforcement in place for `SpatialDataStoreRegistry.store` and `RealmSwift` imports.
- Realm adapter constructor wiring is guardrailed: `RealmSpatial*Contract()` construction is restricted to `DataContractRegistry` and `UnitTests/**`.
- `DataContractRegistry` adapter wiring is guardrailed: `RealmSpatial*Contract()` usage in the registry must stay in private static default-adapter declarations.

Current architecture baseline (normalized comparison baseline `20260304-155712Z-ssindex-eba4cdf`):
- `Data -> App`: 678
- `Data -> Visual UI`: 94
- `Behaviors -> Visual UI`: 215
- `Sensors -> App`: 145
- Comparability note: this report was exported with explicit historical analyzer args (`--top 40 --min-count 2 --file-top 40 --external-top 25`) from deterministic `/tmp/ss-index-derived` build output, so trend comparisons can use this as the normalized baseline.

## Trajectory Review (2026-03-04)
- Direction remains correct: app ingress is unified at async `DataContractRegistry` contracts and Realm boundaries are guarded in CI.
- Milestone 4 is approaching diminishing-return parity slices; close-out should now be criteria-driven rather than open-ended edge chasing.
- Milestone 3 hardening still has meaningful payoff in constructor/wiring seam control and should become the primary track once Milestone 4 close-out criteria are met.
- Dependency metrics now have a fresh normalized rerun (`20260304-155712Z-ssindex-eba4cdf`); follow-up deltas should be compared against that artifact with fixed args.

## Progress Updates
Historical micro-slice log was intentionally condensed to keep this plan context-clear-ready.

Milestone ledger:
- 2026-02-06 to 2026-02-10: `SSDataStructures` and `SSGeo` extraction completed with package-test and boundary-check integration.
- 2026-02-09 to 2026-02-11: Data contract/guardrail baseline established and wired to CI.
- 2026-02-18 to 2026-02-26: Destination and storage-ingress migration moved app callers onto async contracts; strict infra-only guardrails landed.
- 2026-02-27: `Data -> Visual UI` reduced to 34 via marker-parameter serializer boundary cleanup; `Data -> App` reduced to 245 via GPX/data helper decouplings.
- 2026-02-27: Remaining small `Sensors -> App` `AppContext` seams were reduced via runtime-integration hooks in geolocation/headphone paths.
- 2026-02-27: Milestone 1 first extraction slice landed: `Route`, `RouteWaypoint`, and `ReferenceEntity` now live in `apps/common/Sources/SSDataDomain` with iOS bridge extensions preserved in `Temp Models`.
- 2026-02-27: Milestone 2 first extraction slice landed: shared contract-side value types moved to `apps/common/Sources/SSDataContracts` and bridged in iOS via compile-safe typealiases.
- 2026-02-27: Milestone 2 second extraction slice landed: shared route/reference/write/maintenance storage protocol surfaces moved into `apps/common/Sources/SSDataContracts` and iOS storage contracts now inherit shared protocols while retaining iOS-only members.
- 2026-02-27: Milestone 2 third extraction slice landed: shared tile-read surface introduced as `SpatialTileReadContract` in `SSDataContracts` with iOS constrained specialization (`Tile == VectorTile`, `NearbyLocation == POI`).
- 2026-02-27: Milestone 2 fourth extraction slice landed: shared marker-parameter read surface introduced as `SpatialReferenceMarkerReadContract` in `SSDataContracts` with iOS specialization (`MarkerParametersValue == MarkerParameters`).
- 2026-02-27: Milestone 2 fifth extraction slice landed: shared POI/generic-location read surface introduced as `SpatialPointOfInterestReadContract` in `SSDataContracts` with iOS specialization (`PointOfInterestValue == POI`, `GenericLocationValue == GenericLocation`).
- 2026-02-27: Milestone 2 sixth extraction slice landed: shared reference write/maintenance surfaces introduced as `SpatialReferenceWriteContract` and `SpatialReferenceMaintenanceWriteContract` in `SSDataContracts` with iOS constrained specializations.
- 2026-02-27: Milestone 2 seventh extraction slice landed: shared route-parameter read surface introduced as `SpatialRouteParametersReadContract` in `SSDataContracts` with iOS specialization (`RouteParametersValue == RouteParameters`, `RouteParametersContextValue == RouteParameters.Context`).
- 2026-02-27: Milestone 2 eighth extraction slice landed: shared aggregate contract surfaces (`SpatialReadContract`, `SpatialWriteContract`, `SpatialMaintenanceWriteContract`) introduced in `SSDataContracts` and iOS registry-facing protocols now inherit these shared aggregates via constrained specializations.
- 2026-02-27: Milestone 2 closure decision taken: constrained iOS-specialized shared protocols are the target end-state for current scope (no additional model-family extraction required for milestone completion).
- 2026-02-27: Milestone 3 first hardening slice landed: `check_data_contract_boundaries.sh` now enforces `RealmSpatial*Contract` adapter symbols stay in `Data/Infrastructure/Realm/**` except `DataContractRegistry` seam wiring.
- 2026-02-27: Milestone 3 second hardening slice landed: `check_data_contract_boundaries.sh` now enforces `DataContractRegistry.configure/resetForTesting` override seams are test-only (`UnitTests/**`).
- 2026-03-04: Milestone 3 third hardening slice landed: `check_data_contract_boundaries.sh` now enforces `RealmSpatial*Contract()` constructor usage stays in `DataContractRegistry` (plus `UnitTests/**` seam coverage), tightening adapter wiring boundaries.
- 2026-03-04: Milestone 3 fourth hardening slice landed: `check_data_contract_boundaries.sh` now enforces `DataContractRegistry` Realm adapter constructors stay limited to private static default-adapter declarations (`defaultSpatial*`), preventing ad-hoc runtime wiring drift.
- 2026-03-04: Milestone 3 fifth hardening slice landed: `check_data_contract_boundaries.sh` now enforces `DataContractRegistry` spatial adapter reassignments stay limited to declaration/configure/reset seams, preventing ad-hoc runtime rewiring beyond approved seams.
- 2026-03-04: Milestone 3 sixth hardening slice landed: `check_data_contract_boundaries.sh` now enforces `DataContractRegistry` spatial adapter reassignments to occur only inside `configure`/`resetForTesting` method scopes (in addition to declaration seams), preventing assignment-shape bypasses in ad-hoc runtime methods.
- 2026-03-04: Milestone 3 seventh hardening slice landed: `check_data_contract_boundaries.sh` now enforces qualified `DataContractRegistry.`/`Self.` spatial-adapter reassignment forms in addition to `self.`/unqualified forms, closing qualified-assignment bypasses for registry seam checks.
- 2026-03-04: Milestone 3 eighth hardening slice landed: `check_data_contract_boundaries.sh` now detects punctuation-prefixed `spatialRead`/`spatialWrite`/`spatialMaintenanceWrite` assignment forms, closing non-whitespace assignment-prefix bypasses in registry seam checks.
- 2026-03-04: Milestone 3 ninth hardening slice landed: `check_data_contract_boundaries.sh` now detects parenthesized/tuple `DataContractRegistry` `spatialRead`/`spatialWrite`/`spatialMaintenanceWrite` assignment forms, closing tuple-assignment bypasses in registry seam checks.
- 2026-03-04: Milestone 3 tenth hardening slice landed: `check_data_contract_boundaries.sh` now detects multiline `DataContractRegistry` `spatialRead`/`spatialWrite`/`spatialMaintenanceWrite` assignment forms (target and `=` on separate lines), closing newline-split assignment bypasses in registry seam checks.
- 2026-03-04: Milestone 3 eleventh hardening slice landed: `check_data_contract_boundaries.sh` now detects split member-access `DataContractRegistry` `spatialRead`/`spatialWrite`/`spatialMaintenanceWrite` assignment forms (owner and `.spatial* =` split across lines), closing split-member assignment bypasses in registry seam checks.
- 2026-03-04: Milestone 3 twelfth hardening slice landed: `check_data_contract_boundaries.sh` now detects three-line split member-access `DataContractRegistry` `spatialRead`/`spatialWrite`/`spatialMaintenanceWrite` assignment forms (owner, `.spatial*`, and `=` split across lines), closing split-member multiline-assignment bypasses in registry seam checks.
- 2026-03-04: Milestone 3 thirteenth hardening slice landed: `check_data_contract_boundaries.sh` parenthesized-assignment detection now includes split member-access forms (`self`/`Self`/`DataContractRegistry` plus `.spatial*` with optional whitespace), closing split-member tuple-assignment bypasses in registry seam checks.
- 2026-03-04: Milestone 3 fourteenth hardening slice landed: `check_data_contract_boundaries.sh` now detects whitespace-before-dot member-access assignment forms (`self .spatial* =` and `DataContractRegistry .spatial* =`) across single-line and multiline wiring checks, closing spaced-member assignment bypasses in registry seam checks.
- 2026-03-04: Milestone 3 fifteenth hardening slice landed: `check_data_contract_boundaries.sh` now detects block-comment-interleaved assignment forms (`self/*...*/.spatial* =`, `self.spatial*/*...*/=`, and multiline equivalents), closing comment-interleaved assignment bypasses in registry seam checks.
- 2026-03-04: Milestone 3 sixteenth hardening slice landed: `check_data_contract_boundaries.sh` now detects block-comment-separated assignment fragments (for example `self`, then `/*...*/`, then `.spatial* =` or `spatial*`, `/*...*/`, `=`), closing block-comment-separated assignment bypasses in registry seam checks.
- 2026-03-04: Milestone 3 seventeenth hardening slice landed: `check_data_contract_boundaries.sh` now detects inout-based spatial adapter mutation forms (`&spatial*`, `&self.spatial*`, and multiline/comment-separated variants), closing non-`=` inout wiring bypasses in registry seam checks.
- 2026-03-04: Milestone 3 eighteenth hardening slice landed: `check_data_contract_boundaries.sh` now detects spatial adapter key-path forms (`\\.spatial*`, `\\Self.spatial*`, `\\DataContractRegistry.spatial*`, including multiline split-key-path variants), closing key-path wiring bypasses in registry seam checks.
- 2026-03-04: Milestone 3 nineteenth hardening slice landed: `check_data_contract_boundaries.sh` now detects metatype-alias assignment forms (for example `let registry = Self.self` then `registry.spatial* = ...`, including split-member multiline variants), closing local-alias wiring bypasses in registry seam checks.
- 2026-03-04: Milestone 3 twentieth hardening slice landed: `check_data_contract_boundaries.sh` now detects typealias-owner assignment forms (for example `typealias Registry = DataContractRegistry` then `Registry.spatial* = ...`, including split-member multiline variants), closing typealias-owner wiring bypasses in registry seam checks.
- 2026-03-04: Dependency tracking normalization slice landed: exported SSIndex artifact `20260304-145500Z-ssindex-a7a05e5` from deterministic `/tmp/ss-index-derived/Index.noindex/DataStore` with explicit comparison args (`--top 40 --min-count 2 --file-top 40 --external-top 25`).
- 2026-03-04: Dependency follow-up rerun after Milestone 3 fourth hardening slice exported SSIndex artifact `20260304-150933Z-ssindex-741ce45` from deterministic `/tmp/ss-index-derived/Index.noindex/DataStore` with the same fixed comparison args.
- 2026-03-04: Dependency follow-up rerun after Milestone 3 fifth hardening slice exported SSIndex artifact `20260304-151805Z-ssindex-48da232` from deterministic `/tmp/ss-index-derived/Index.noindex/DataStore` with the same fixed comparison args.
- 2026-03-04: Dependency follow-up rerun after Milestone 3 sixth hardening slice exported SSIndex artifact `20260304-154602Z-ssindex-94b1388` from deterministic `/tmp/ss-index-derived/Index.noindex/DataStore` with the same fixed comparison args.
- 2026-03-04: Dependency follow-up rerun after Milestone 3 seventh hardening slice exported SSIndex artifact `20260304-155712Z-ssindex-eba4cdf` from deterministic `/tmp/ss-index-derived/Index.noindex/DataStore` with the same fixed comparison args.
- 2026-03-04: Dependency follow-up rerun after Milestone 3 eighth hardening slice exported SSIndex artifact `20260304-162400Z-ssindex-9531c11` from deterministic `/tmp/ss-index-derived/Index.noindex/DataStore` with the same fixed comparison args.
- 2026-03-04: Dependency follow-up rerun after Milestone 3 ninth hardening slice exported SSIndex artifact `20260304-163225Z-ssindex-5458557` from deterministic `/tmp/ss-index-derived/Index.noindex/DataStore` with the same fixed comparison args.
- 2026-03-04: Dependency follow-up rerun after Milestone 3 tenth hardening slice exported SSIndex artifact `20260304-163645Z-ssindex-0b3d6e2` from deterministic `/tmp/ss-index-derived/Index.noindex/DataStore` with the same fixed comparison args.
- 2026-03-04: Dependency follow-up rerun after Milestone 3 eleventh hardening slice exported SSIndex artifact `20260304-163935Z-ssindex-1591fdb` from deterministic `/tmp/ss-index-derived/Index.noindex/DataStore` with the same fixed comparison args.
- 2026-03-04: Dependency follow-up rerun after Milestone 3 twelfth hardening slice exported SSIndex artifact `20260304-164235Z-ssindex-ce89e25` from deterministic `/tmp/ss-index-derived/Index.noindex/DataStore` with the same fixed comparison args.
- 2026-03-04: Dependency follow-up rerun after Milestone 3 thirteenth hardening slice exported SSIndex artifact `20260304-175034Z-ssindex-9958bc3` from deterministic `/tmp/ss-index-derived/Index.noindex/DataStore` with the same fixed comparison args.
- 2026-03-04: Dependency follow-up rerun after Milestone 3 fourteenth hardening slice exported SSIndex artifact `20260304-190247Z-ssindex-29435e0` from deterministic `/tmp/ss-index-derived/Index.noindex/DataStore` with the same fixed comparison args.
- 2026-03-04: Dependency follow-up rerun after Milestone 3 fifteenth hardening slice exported SSIndex artifact `20260304-190720Z-ssindex-218b4f7` from deterministic `/tmp/ss-index-derived/Index.noindex/DataStore` with the same fixed comparison args.
- 2026-03-04: Dependency follow-up rerun after Milestone 3 sixteenth hardening slice exported SSIndex artifact `20260304-191219Z-ssindex-a070323` from deterministic `/tmp/ss-index-derived/Index.noindex/DataStore` with the same fixed comparison args.
- 2026-03-04: Dependency follow-up rerun after Milestone 3 seventeenth hardening slice exported SSIndex artifact `20260304-191600Z-ssindex-4d423ef` from deterministic `/tmp/ss-index-derived/Index.noindex/DataStore` with the same fixed comparison args.
- 2026-03-04: Dependency follow-up rerun after Milestone 3 eighteenth hardening slice exported SSIndex artifact `20260304-193136Z-ssindex-dc3a079` from deterministic `/tmp/ss-index-derived/Index.noindex/DataStore` with the same fixed comparison args.
- 2026-03-04: Dependency follow-up rerun after Milestone 3 nineteenth hardening slice exported SSIndex artifact `20260304-193557Z-ssindex-92f265e` from deterministic `/tmp/ss-index-derived/Index.noindex/DataStore` with the same fixed comparison args.
- 2026-03-04: Dependency follow-up rerun after Milestone 3 twentieth hardening slice exported SSIndex artifact `20260304-193907Z-ssindex-4b03bd8` from deterministic `/tmp/ss-index-derived/Index.noindex/DataStore` with the same fixed comparison args.
- 2026-03-04: Fixed `run_local_validation.sh` empty forwarded-arg handling under `set -u` so step 5 no longer errors before invoking `run_local_ios_build_test.sh`.
- 2026-02-27: Milestone 4 first parity slice landed: in-memory contract tests now verify `RouteParameters` backup/share context behavior plus reference lookup parity across ID/entity-key/coordinate/generic-location read paths.
- 2026-03-04: Milestone 4 second parity slice landed: in-memory maintenance tests now cover `clearNewReferenceEntitiesAndRoutes` behavior and `cleanCorruptReferenceEntities` entity-key lookup cleanup semantics.
- 2026-03-04: Milestone 4 third parity slice landed: in-memory maintenance tests now cover `removeAllReferenceEntities` and `removeAllRoutes` flow semantics (reference cleanup first, route cleanup second).
- 2026-03-04: Milestone 4 fourth parity slice landed: in-memory reference-removal parity now mirrors Realm route-maintenance side effects by removing affected route waypoints, reindexing remaining waypoints, and refreshing first-waypoint coordinates for `removeReferenceEntity` and `cleanCorruptReferenceEntities`.
- 2026-03-04: Milestone 4 fifth parity slice landed: in-memory reference-location updates now mirror Realm first-waypoint maintenance by refreshing first-waypoint coordinates only for routes whose first waypoint matches the updated marker.
- 2026-03-04: Milestone 4 sixth parity slice landed: in-memory destination-marker removal now mirrors Realm destination semantics by marking an active destination reference as temporary instead of deleting it, while retaining route waypoint linkage and reference/POI lookups.
- 2026-03-04: Milestone 4 seventh parity slice landed: in-memory temporary-marker cleanup now mirrors destination follow-up semantics by removing `isTemp` references while preserving route waypoint snapshots and backup/share route-parameter behavior for unresolved temporary marker IDs.
- 2026-03-04: Milestone 4 eighth parity (close-out) slice landed: in-memory parity now covers `importReferenceEntityFromCloud` read-surface round-trip, metadata/callout nickname-fallback semantics, and entity-key upsert behavior after temporary-marker cleanup.
- 2026-03-04: Milestone 4 declared complete; primary execution focus moved to Milestone 3 Realm adapter isolation hardening.
- 2026-02-27: Local `xcodebuild test-without-building` currently fails in `AudioEngineTest` (`testDiscreteAudio2DSeveral`, `testDiscreteAudio2DSimple`) while modularization-targeted data suites pass.
- 2026-03-04: Local validation workflow streamlined with scripted simulator-aware build/test (`apps/ios/Scripts/ci/run_local_ios_build_test.sh`) and scripted full baseline runner (`apps/ios/Scripts/ci/run_local_validation.sh`) to reduce xcodebuild noise and command drift.

Most recent completed slices (latest first):
- 2026-03-04: Re-exported normalized SSIndex artifact `20260304-193907Z-ssindex-4b03bd8` (fixed args preserved) after the Milestone 3 twentieth hardening slice; `latest.txt` now points to this report.
- 2026-03-04: Hardened `DataContractRegistry` wiring seam checks so typealias-owner assignment forms (`typealias Registry = DataContractRegistry` then `Registry.spatialRead = ...`, plus split-member multiline variants) are detected by `check_data_contract_boundaries.sh`.
- 2026-03-04: Re-exported normalized SSIndex artifact `20260304-193557Z-ssindex-92f265e` (fixed args preserved) after the Milestone 3 nineteenth hardening slice; `latest.txt` now points to this report.
- 2026-03-04: Hardened `DataContractRegistry` wiring seam checks so metatype-alias assignment forms (`let registry = Self.self` then `registry.spatialRead = ...`, plus split-member multiline variants) are detected by `check_data_contract_boundaries.sh`.
- 2026-03-04: Re-exported normalized SSIndex artifact `20260304-193136Z-ssindex-dc3a079` (fixed args preserved) after the Milestone 3 eighteenth hardening slice; `latest.txt` now points to this report.
- 2026-03-04: Hardened `DataContractRegistry` wiring seam checks so key-path forms (`\\.spatialRead`, `\\Self.spatialWrite`, `\\DataContractRegistry.spatialMaintenanceWrite`, and multiline split-key-path variants) are detected by `check_data_contract_boundaries.sh`.
- 2026-03-04: Re-exported normalized SSIndex artifact `20260304-191600Z-ssindex-4d423ef` (fixed args preserved) after the Milestone 3 seventeenth hardening slice; `latest.txt` now points to this report.
- 2026-03-04: Hardened `DataContractRegistry` wiring seam checks so inout mutation forms (`&spatialRead`, `&self.spatialWrite`, and multiline/comment-separated variants) are detected by `check_data_contract_boundaries.sh`.
- 2026-03-04: Re-exported normalized SSIndex artifact `20260304-191219Z-ssindex-a070323` (fixed args preserved) after the Milestone 3 sixteenth hardening slice; `latest.txt` now points to this report.
- 2026-03-04: Hardened `DataContractRegistry` assignment seam checks so block-comment-separated fragments (`self`, `/*...*/`, `.spatialRead =`; `spatialWrite`, `/*...*/`, `=`) are detected by `check_data_contract_boundaries.sh`.
- 2026-03-04: Re-exported normalized SSIndex artifact `20260304-190720Z-ssindex-218b4f7` (fixed args preserved) after the Milestone 3 fifteenth hardening slice; `latest.txt` now points to this report.
- 2026-03-04: Hardened `DataContractRegistry` assignment seam checks so block-comment-interleaved forms (`self/*...*/.spatialRead =`, `self.spatialWrite/*...*/=`, and multiline variants) are detected by `check_data_contract_boundaries.sh`.
- 2026-03-04: Re-exported normalized SSIndex artifact `20260304-190247Z-ssindex-29435e0` (fixed args preserved) after the Milestone 3 fourteenth hardening slice; `latest.txt` now points to this report.
- 2026-03-04: Hardened `DataContractRegistry` assignment seam checks so whitespace-before-dot member access forms (`self .spatialRead =`, `Self .spatialWrite =`, `DataContractRegistry .spatialMaintenanceWrite =`) are detected by `check_data_contract_boundaries.sh`.
- 2026-03-04: Re-exported normalized SSIndex artifact `20260304-175034Z-ssindex-9958bc3` (fixed args preserved) after the Milestone 3 thirteenth hardening slice; `latest.txt` now points to this report.
- 2026-03-04: Hardened `DataContractRegistry` parenthesized-assignment seam checks so split member-access `spatialRead`/`spatialWrite`/`spatialMaintenanceWrite` forms are detected by `check_data_contract_boundaries.sh`.
- 2026-03-04: Re-exported normalized SSIndex artifact `20260304-164235Z-ssindex-ce89e25` (fixed args preserved) after the Milestone 3 twelfth hardening slice; `latest.txt` now points to this report.
- 2026-03-04: Hardened `DataContractRegistry` assignment seam checks so three-line split member-access `spatialRead`/`spatialWrite`/`spatialMaintenanceWrite` assignment forms are detected by `check_data_contract_boundaries.sh`.
- 2026-03-04: Re-exported normalized SSIndex artifact `20260304-163935Z-ssindex-1591fdb` (fixed args preserved) after the Milestone 3 eleventh hardening slice; `latest.txt` now points to this report.
- 2026-03-04: Hardened `DataContractRegistry` assignment seam checks so split member-access `spatialRead`/`spatialWrite`/`spatialMaintenanceWrite` assignment forms are detected by `check_data_contract_boundaries.sh`.
- 2026-03-04: Re-exported normalized SSIndex artifact `20260304-163645Z-ssindex-0b3d6e2` (fixed args preserved) after the Milestone 3 tenth hardening slice; `latest.txt` now points to this report.
- 2026-03-04: Hardened `DataContractRegistry` assignment seam checks so multiline `spatialRead`/`spatialWrite`/`spatialMaintenanceWrite` assignment forms are detected by `check_data_contract_boundaries.sh`.
- 2026-03-04: Re-exported normalized SSIndex artifact `20260304-163225Z-ssindex-5458557` (fixed args preserved) after the Milestone 3 ninth hardening slice; `latest.txt` now points to this report.
- 2026-03-04: Hardened `DataContractRegistry` assignment seam checks so parenthesized/tuple `spatialRead`/`spatialWrite`/`spatialMaintenanceWrite` assignment forms are detected by `check_data_contract_boundaries.sh`.
- 2026-03-04: Re-exported normalized SSIndex artifact `20260304-162400Z-ssindex-9531c11` (fixed args preserved) after the Milestone 3 eighth hardening slice; `latest.txt` now points to this report.
- 2026-03-04: Hardened `DataContractRegistry` assignment seam checks so punctuation-prefixed `spatialRead`/`spatialWrite`/`spatialMaintenanceWrite` assignment forms are detected by `check_data_contract_boundaries.sh`.
- 2026-03-04: Re-exported normalized SSIndex artifact `20260304-155712Z-ssindex-eba4cdf` (fixed args preserved) after the Milestone 3 seventh hardening slice; `latest.txt` now points to this report.
- 2026-03-04: Hardened `DataContractRegistry` assignment seam checks so qualified `Self.`/`DataContractRegistry.` `spatialRead`/`spatialWrite`/`spatialMaintenanceWrite` reassignment forms are also enforced by `check_data_contract_boundaries.sh`.
- 2026-03-04: Re-exported normalized SSIndex artifact `20260304-154602Z-ssindex-94b1388` (fixed args preserved) after the Milestone 3 sixth hardening slice; `latest.txt` now points to this report.
- 2026-03-04: Hardened `DataContractRegistry` assignment seams so `spatialRead`/`spatialWrite`/`spatialMaintenanceWrite` reassignments are constrained to `configure`/`resetForTesting` method scopes (plus declarations) via `check_data_contract_boundaries.sh`.
- 2026-03-04: Fixed `run_local_validation.sh` empty forwarded-arg handling under `set -u`, restoring no-arg baseline execution.
- 2026-03-04: Re-exported normalized SSIndex artifact `20260304-151805Z-ssindex-48da232` (fixed args preserved) after the Milestone 3 fifth hardening slice; `latest.txt` now points to this report.
- 2026-03-04: Hardened `DataContractRegistry` assignment seams so `spatialRead`/`spatialWrite`/`spatialMaintenanceWrite` reassignments are limited to declaration/configure/reset paths via `check_data_contract_boundaries.sh`.
- 2026-03-04: Re-exported normalized SSIndex artifact `20260304-150933Z-ssindex-741ce45` (fixed args preserved) after the Milestone 3 fourth hardening slice; `latest.txt` now points to this report.
- 2026-03-04: Hardened `DataContractRegistry` adapter wiring boundaries so `RealmSpatial*Contract()` usage in the registry is restricted to private static default-adapter declarations via `check_data_contract_boundaries.sh`.
- 2026-03-04: Normalized dependency tracking by running deterministic build-only index generation and exporting SSIndex report `20260304-145500Z-ssindex-a7a05e5` with fixed comparison args; `latest.txt` now points to this baseline.
- 2026-03-04: Hardened Realm adapter wiring boundaries so direct `RealmSpatialReadContract`/`RealmSpatialWriteContract`/`RealmSpatialMaintenanceWriteContract` construction is limited to `DataContractRegistry` and `UnitTests/**` via `check_data_contract_boundaries.sh`.
- 2026-03-04: Closed Milestone 4 by adding in-memory parity coverage for cloud marker import read round-trip, metadata/callout nickname fallback, and entity-key upsert after temporary-marker cleanup (`InMemorySpatialContractStoreTests`).
- 2026-03-04: Added reusable local validation scripts for simulator selection plus build/test output control (`errors`, `xcpretty`, `raw`) and documented them in agent/onboarding docs to make common execution paths one-command and context-light.
- 2026-03-04: Expanded in-memory parity with `removeAllTemporaryReferenceEntities` cleanup semantics, verifying temporary destination markers are purged from reference/POI lookups while routes remain and share-context route parameters fail when marker payloads can no longer hydrate.
- 2026-03-04: Expanded in-memory parity so removing an active destination reference marks it temporary (`isTemp == true`) without deleting the marker or removing route waypoints, matching Realm destination-maintenance behavior.
- 2026-03-04: Expanded in-memory parity so `updateReferenceEntity` location changes refresh first-waypoint coordinates (and route update timestamps) only for routes whose first waypoint references the updated marker.
- 2026-03-04: Expanded in-memory parity so `removeReferenceEntity` and `cleanCorruptReferenceEntities` remove impacted route waypoints, reindex waypoint order, and keep route first-waypoint coordinates aligned with remaining references.
- 2026-03-04: Expanded maintenance parity with `removeAllReferenceEntities` and `removeAllRoutes` in-memory flow coverage, asserting reference/POI cleanup and route retention/removal order semantics.
- 2026-03-04: Expanded `InMemorySpatialContractStore` maintenance parity by adding tests for clear-new route cleanup and corrupt-reference entity-key/POI lookup cleanup; rebuilt in-memory `poiByEntityKey` during corrupt-clean maintenance to avoid stale lookups.
- 2026-02-27: Expanded `InMemorySpatialContractStore` parity coverage with route-parameter context assertions and cross-surface reference lookup assertions in `DataContractRegistryDispatchTests`.
- 2026-02-27: Hardened boundary guardrails so `DataContractRegistry.configure` and `DataContractRegistry.resetForTesting` usage outside `UnitTests/**` fails CI.
- 2026-02-27: Hardened boundary guardrails so direct `RealmSpatialReadContract`/`RealmSpatialWriteContract`/`RealmSpatialMaintenanceWriteContract` usage outside Realm infrastructure and `DataContractRegistry` fails CI.
- 2026-02-27: Milestone 2 closed with constrained-specialization end-state accepted for storage-contract signatures.
- 2026-02-27: Added shared aggregate storage protocols in `SSDataContracts` (`SpatialReadContract`, `SpatialWriteContract`, `SpatialMaintenanceWriteContract`) and rewired iOS aggregate contracts to inherit them while preserving compatibility with existing local subprotocol expectations.
- 2026-02-27: Added shared `SpatialRouteParametersReadContract` in `SSDataContracts` and rewired iOS `RouteReadContract` to inherit it via constrained specialization.
- 2026-02-27: Added shared `SpatialReferenceWriteContract` and `SpatialReferenceMaintenanceWriteContract` in `SSDataContracts` and rewired iOS `SpatialWriteContract`/`SpatialMaintenanceWriteContract` to inherit them via constrained specializations.
- 2026-02-27: Added shared `SpatialPointOfInterestReadContract` in `SSDataContracts` and rewired iOS `ReferenceReadContract` to inherit it via constrained specialization.
- 2026-02-27: Added shared `SpatialReferenceMarkerReadContract` in `SSDataContracts` and rewired iOS `ReferenceReadContract` to inherit it while keeping `POI`/`GenericLocation` reads iOS-local.
- 2026-02-27: Added shared `SpatialTileReadContract` in `SSDataContracts` and rewired iOS `TileReadContract` to a constrained specialization while keeping `POI`/`VectorTile` iOS-local.
- 2026-02-27: Added shared storage protocol surfaces in `SSDataContracts` (`SpatialRouteReadContract`, `SpatialReferenceReadContract`, `SpatialRouteWriteContract`, `SpatialRouteMaintenanceWriteContract`, `SpatialAddressMaintenanceWriteContract`) and rewired iOS `Spatial*Contract` protocols to inherit from them.
- 2026-02-27: Added `SSDataContracts` module and migrated `SpatialIntersectionRegion`/`RouteReadMetadata`/`ReferenceReadMetadata`/`ReferenceCalloutReadData`/`EstimatedAddressReadData`/`AddressCacheRecord`.
- 2026-02-27: Added shared `SSDataDomain` module and migrated canonical route/reference models (`Route`, `RouteWaypoint`, `ReferenceEntity`) behind compile-safe iOS aliases/extensions.
- 2026-02-27: `BoseFramesMotionManager` event dispatch decoupled from direct `AppContext.process(...)` via runtime integration hook.
- 2026-02-27: `HeadphoneCalibrator` heading source decoupled from direct `AppContext.shared.geolocationManager`.
- 2026-02-27: `HeadphoneMotionManager` event dispatch decoupled from direct `AppContext.process(...)`.
- 2026-02-27: `SignificantChangeMonitoringOrigin` POI lookup decoupled from direct `AppContext.shared.spatialDataContext`.
- 2026-02-27: `GeolocationManager`/`GPXSimulator` simulation integration decoupled from direct `AppContext` motion wiring.

Validation baseline for each slice:
- primary runner: `bash apps/ios/Scripts/ci/run_local_validation.sh`
- deterministic index build: `bash apps/ios/Scripts/ci/run_local_ios_build_test.sh --build-only --derived-data-path /tmp/ss-index-derived --output errors`
- analyzer export (comparison-stable): `bash tools/SSIndexAnalyzer/Scripts/export_analysis_report.sh --store-path /tmp/ss-index-derived/Index.noindex/DataStore --top 40 --min-count 2 --file-top 40 --external-top 25`
- equivalent manual checks remain available (`check_forbidden_imports.sh`, `swift test --package-path apps/common`, localization linter, seam/boundary scripts)
- targeted suites: `RouteStorageProviderDispatchTests`, `DataContractRegistryDispatchTests`, `CloudSyncContractBridgeTests`

## Decoupling Plan (Data-First)
### Milestone 1: Extract Domain Models to `SSDataDomain`
Tasks:
- Move canonical data domain/value models from `apps/ios/.../Data/Models/Temp Models` into `apps/common/Sources/SSDataDomain`.
- Keep public names/shapes stable (`Route`, `RouteWaypoint`, `ReferenceEntity`).
- Add Swift Testing coverage for moved model invariants.

Acceptance:
- iOS compiles against `SSDataDomain` with no behavior regressions.
- No new DTO family introduced for moved models.

### Milestone 2: Extract Contracts to `SSDataContracts`
Status:
- Complete (2026-02-27)

Tasks:
- Move contract protocols and contract-side shared types into `apps/common/Sources/SSDataContracts`.
- Keep contracts async-first and Realm-free.
- Update iOS call sites/imports to consume shared contracts.

Acceptance:
- Contract targets compile in `apps/common` with platform-agnostic boundaries.
- Existing dispatch/behavior tests continue passing.

### Milestone 3: Realm Adapter Isolation Hardening
Tasks:
- Keep Realm mapping and persistence implementation strictly in `Data/Infrastructure/Realm`.
- Ensure app/runtime layers consume only contracts/domain models.
- Maintain strict seam guardrail compliance.

Acceptance:
- No non-infrastructure `RealmSwift` imports.
- No non-infrastructure `SpatialDataStoreRegistry.store` usage.
- No non-registry/non-test Realm adapter construction (`RealmSpatial*Contract()` wiring remains centralized).
- No ad-hoc Realm adapter constructor usage inside `DataContractRegistry` methods (default static declarations remain the only constructor wiring).

### Milestone 4: In-Memory Contract Parity
Status:
- Complete (2026-03-04)

Tasks:
- Expand non-Realm in-memory contract behavior coverage.
- Verify contract semantics independent of Realm adapter specifics.

Acceptance:
- In-memory adapter passes contract behavior suite without adapter-specific shims.

## Immediate Next Steps
1. Use normalized SSIndex baseline `20260304-155712Z-ssindex-eba4cdf` for Milestone 3 delta tracking; keep analyzer args fixed (`--top 40 --min-count 2 --file-top 40 --external-top 25`) on each follow-up export.
2. Execute the next Milestone 3 hardening slice for adapter wiring beyond constructor/registry-default/assignment-scope/qualified-assignment/punctuation-assignment/parenthesized-assignment/multiline-assignment/split-member-assignment/split-member-multiline-assignment/parenthesized-split-member-assignment/spaced-member-assignment/comment-interleaved-assignment/block-comment-separated-assignment/inout-wiring/key-path-wiring/metatype-alias-assignment/typealias-assignment seams, keeping coverage comparable to existing symbol-boundary checks.
3. Keep running the validation baseline plus dependency-report export for each slice, with dependency comparisons locked to the explicit analyzer arg set above.
4. Keep known full-suite `AudioEngineTest` failures tracked as non-blocking for data-modularization slices until explicitly reprioritized.

## Decision Log (2026-03-04)
1. Milestone 4 closure policy: complete Milestone 4 after one close-out parity slice for remaining high-value uncovered read/write behaviors, then move primary execution to Milestone 3.
2. Dependency tracking policy: lock progress comparisons to explicit SSIndex args (`--top 40 --min-count 2 --file-top 40 --external-top 25`) to preserve comparability.
3. Test-gating policy: known `AudioEngineTest` failures remain non-blocking for data-modularization slices in current scope.

## Context-Clear Handoff
Current branch state:
- Milestone 2 is complete; Milestone 4 is complete; Milestone 3 hardening is now the primary active track.
- Milestone 3 now includes constructor, registry-default, assignment-shape, assignment-method-scope, qualified-assignment-form, punctuation-prefixed-assignment-form, parenthesized-assignment-form, multiline-assignment-form, split-member-assignment-form, split-member-multiline-assignment-form, parenthesized-split-member-assignment-form, spaced-member-assignment-form, comment-interleaved-assignment-form, block-comment-separated-assignment-form, inout-wiring-form, key-path-wiring-form, metatype-alias-assignment-form, and typealias-assignment-form guardrails for `DataContractRegistry` Realm adapter wiring seams.
- In-memory parity now includes maintenance semantics for clear-new, corrupt-reference cleanup, remove-all flows, route-waypoint cleanup on reference removals, first-waypoint refresh on marker location updates, destination-marker temporary preservation on remove, temporary-marker cleanup parity, cloud marker import read round-trip, metadata/callout nickname fallback, and entity-key upsert after temporary-marker cleanup.
- Local execution is now script-first via `run_local_validation.sh` (full baseline) and `run_local_ios_build_test.sh` (simulator-aware build/test with filtered output).

Latest dependency artifact:
- `docs/plans/artifacts/dependency-analysis/20260304-193907Z-ssindex-4b03bd8.txt`
- `docs/plans/artifacts/dependency-analysis/latest.txt` points to that report.

Resume checklist:
1. Re-open this file and `docs/plans/data_storage_api_north_star.md`.
2. Continue Milestone 3 adapter-isolation hardening slices (constructor, registry-default wiring, registry assignment-shape, registry assignment-method-scope, registry qualified-assignment-form, registry punctuation-assignment-form, registry parenthesized-assignment-form, registry multiline-assignment-form, registry split-member-assignment-form, registry split-member-multiline-assignment-form, registry parenthesized-split-member-assignment-form, registry spaced-member-assignment-form, registry comment-interleaved-assignment-form, registry block-comment-separated-assignment-form, registry inout-wiring-form, registry key-path-wiring-form, registry metatype-alias-assignment-form, and registry typealias-assignment-form guardrails landed; proceed with next wiring-boundary hardening slice).
3. Run scripted validation baseline and export dependency report from `/tmp/ss-index-derived/Index.noindex/DataStore` with fixed analyzer args (`--top 40 --min-count 2 --file-top 40 --external-top 25`).
4. Update this plan's `Progress Updates` and commit.
