<!-- Copyright (c) Soundscape Community Contributers. -->

# Soundscape Agent Instructions

This file is the canonical instruction source for coding agents in this repository.

## Repository Map
- `apps/ios/`: iOS app (`GuideDogs.xcworkspace`, app code, unit tests, CI scripts).
- `apps/common/`: shared Swift package for platform-agnostic modules (currently `SSDataStructures`, `SSGeo`, `SSDataDomain`, `SSDataContracts`).
- `svcs/data/`: open-source data-plane ingestion/tile tooling (Python, Docker, SQL, Helm chart assets).
- `docs/`: project documentation.
- `.github/workflows/`: CI definitions (use these as command truth for automation-aligned docs).

## iOS Architecture Snapshot
- Behavior framework lives under `apps/ios/GuideDogs/Code/Behaviors`.
- `BehaviorBase` manages manual/automatic generators plus typed event streams (`allEvents`, `userInitiatedEvents`, `stateChangedEvents`).
- `EventProcessor` is the central router and processes events through an async event queue/loop (ordered handling on `@MainActor`).
- `CalloutCoordinator` owns callout queueing, interruption, hush behavior, and playback sequencing.
- `AudioPlaybackActor` provides async audio playback control for the coordinator and wraps `AudioEngine` interactions.
- `HandledEventAction` is the behavior-to-processor contract for callout playback, event fan-out, and interrupt requests.
- `SSDataStructures` now lives in `apps/common` and is imported by iOS targets that need queue/stack/token/thread-safe primitives.
- `SSGeo` now lives in `apps/common` and provides portable location payloads plus basic geodesic math without `CoreLocation`.
- `SSDataDomain` now lives in `apps/common` and hosts canonical route/reference domain value models shared with iOS.
- `SSDataContracts` now lives in `apps/common` and hosts shared contract-side value types for storage/read-write boundaries.

## Modularization Status (Phase 1)
- First extraction is complete: core data-structure types moved from `apps/ios` into `apps/common/Sources/SSDataStructures`.
- Shared geo primitives extraction is complete: portable coordinate/location/math types now live in `apps/common/Sources/SSGeo`.
- Initial data-domain extraction is complete: canonical `Route`, `RouteWaypoint`, and `ReferenceEntity` models now live in `apps/common/Sources/SSDataDomain`.
- Initial data-contract extraction is complete: shared contract-side value types now live in `apps/common/Sources/SSDataContracts` and are bridged in iOS contract files.
- Boundary rule: keep `apps/common` platform-agnostic. Do not import Apple UI/platform frameworks in `apps/common/Sources`.
- Boundary enforcement script: `bash apps/common/Scripts/check_forbidden_imports.sh`.
- Package tests for extracted module: `swift test --package-path apps/common`.

## Common Module Naming
- Use `SS` + concise domain noun for modules in `apps/common` (for example: `SSDataStructures`, `SSUniversalLinks`).
- Avoid `Soundscape*` prefixes and avoid generic names like `Core` or `Common` alone.
- Keep names short, domain-specific, and consistent with import usage in iOS targets.

## Plan Documents
- Active plans live in `docs/plans/`.
- Modularization progress is tracked in `docs/plans/modularization_plan.md`.
- Each active plan must include: summary, scope, current status, progress updates, and next steps.
- After each implementation in plan scope, update the plan document in the same change with current progress and immediate next steps.
- After each plan step is complete and validation tests/scripts are successful, stage and commit the scoped changes before starting the next plan step.
- When modularization lands a new module, update both `docs/plans/modularization_plan.md` and this file's modularization status section (concisely).

## Build, Test, and Lint Commands
Use commands aligned with `.github/workflows/ios-tests.yml`, but for local runs always use a simulator that is already installed on the current machine.

Local session rule:
- At the start of each session, check available simulators with `bash apps/ios/Scripts/ci/run_local_ios_build_test.sh --list-simulators` (or `xcrun simctl list devices available`).
- Do not download simulator runtimes just to run local build/tests.
- CI remains pinned in workflow config; do not edit workflow destinations for this.

From repo root:

```bash
# Full common local baseline (default xcodebuild output mode: errors-only):
bash apps/ios/Scripts/ci/run_local_validation.sh

# Optional output modes for build/test stage:
bash apps/ios/Scripts/ci/run_local_validation.sh -- --output xcpretty
bash apps/ios/Scripts/ci/run_local_validation.sh -- --output raw

# Build/test only (without running other baseline checks):
bash apps/ios/Scripts/ci/run_local_ios_build_test.sh
```

## Tool Output and Context Hygiene
- Watch for high-volume tools (especially `xcodebuild`) polluting agent/user context with low-signal logs.
- Prefer concise output modes and wrappers for repeated actions:
  - `--output errors` for routine local build/test loops.
  - `--output xcpretty` when human-readable summaries are needed (`xcpretty` is available locally).
- When a command is repeated often, prefer a small script in `apps/ios/Scripts/ci/` rather than re-issuing long raw commands.
- Default to reporting key outcomes + log file locations instead of streaming full command output into the conversation.
- Use raw output only when diagnosing a failure that requires full trace context.

## Dependency Analysis Tooling
- Source-level dependency analysis is available via `tools/SSIndexAnalyzer` (SwiftPM executable using `swiftlang/indexstore-db`).
- Build `SSIndexAnalyzer` locally:

```bash
swift build --package-path tools/SSIndexAnalyzer
```

- Export a timestamped report for later chats/review (writes to `docs/plans/artifacts/dependency-analysis/` and refreshes `latest.txt`):

```bash
bash tools/SSIndexAnalyzer/Scripts/export_analysis_report.sh
```

- Run against latest `GuideDogs` DerivedData index store (auto-discovery defaults):

```bash
swift run --package-path tools/SSIndexAnalyzer SSIndexAnalyzer --top 40 --min-count 2 --file-top 40 --external-top 25
```

- Deterministic index freshness workflow (recommended before exporting a report):

```bash
bash apps/ios/Scripts/ci/run_local_ios_build_test.sh \
  --build-only \
  --derived-data-path /tmp/ss-index-derived \
  --output errors

bash tools/SSIndexAnalyzer/Scripts/export_analysis_report.sh \
  --store-path /tmp/ss-index-derived/Index.noindex/DataStore \
  --top 40 --min-count 2 --file-top 40 --external-top 25
```

- Override analyzer output scope by passing args through the export script:

```bash
bash tools/SSIndexAnalyzer/Scripts/export_analysis_report.sh --top 50 --min-count 3 --file-top 50 --external-top 30
```

- Typical explicit usage (if auto-discovery is not desired):

```bash
swift run --package-path tools/SSIndexAnalyzer SSIndexAnalyzer \
  --store-path /Users/<user>/Library/Developer/Xcode/DerivedData/GuideDogs-<id>/Index.noindex/DataStore \
  --db-path /tmp/ss-index-analyzer-db \
  --source-root apps/ios/GuideDogs/Code \
  --lib-indexstore /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib \
  --file-top 30 \
  --external-top 30
```

## Documentation Navigation
Operational/current docs:
- `docs/README.md` (index)
- `docs/Client.md`
- `docs/Services.md`
- `docs/ios-client/onboarding.md`
- `docs/ios-client/overview.md`

Historical planning logs:
- `docs/callout_architecture_plan.md`
- `docs/concurrency_migration_plan.md`

Historical planning docs are valuable context, but commands and tooling details may drift over time. For current execution defaults, use this file and CI workflows.

## Agent Hygiene
- Keep changes scoped and cohesive.
- Prefer updating docs when architecture or workflows change.
- Keep iOS app changes and services changes isolated unless intentionally cross-cutting.
- Use `GDLog*` logging conventions instead of ad-hoc prints when touching runtime logging paths.
- Do not alter Microsoft copyright notices in existing files.
- **NEVER** add Microsoft copyright notices to any files.
- **do** add copyright notice for "Soundscape Community Contributers" to modified or new files

## Domain Model and Abstraction Policy
- Prefer canonical domain models over DTO proliferation. Do not introduce DTO families when existing readable domain/value types can be used directly.
- Keep app-facing names stable and readable. Preserve existing API names/shapes for client code unless a change is strictly necessary for modularization or async correctness.
- For route modularization, the exposed model should remain `Route` and be a value type (`struct`). Realm object types must stay infrastructure-local under `Data/Infrastructure/Realm` and use explicit Realm-prefixed names (for example `RealmRoute`).
- Use async APIs where appropriate, but migrate incrementally with minimal client churn and explicit deprecation only for temporary compatibility seams.
- Add abstractions/patterns only when they clearly improve code organization, readability, and local reasoning boundaries. Do not add patterns from irrelevant contexts (for example distributed-systems patterns) when they are not required for this modularization work.

## Modularization Checkpoint (2026-02-11)
- Data read/write contract compatibility surfaces are removed from production (`spatialReadCompatibility`/`spatialWriteCompatibility` usage in `apps/ios/GuideDogs/Code` is zero); use async `DataContractRegistry.spatialRead` and `DataContractRegistry.spatialWrite`.
- Canonical route write APIs are now domain-shaped: `SpatialWriteContract.addRoute(_ route: Route)` and `SpatialWriteContract.updateRoute(_ route: Route)`.
- Route add telemetry remains infrastructure-local in `Data/Infrastructure/Realm/Route+Realm.swift`; do not re-introduce telemetry-context parameters into app-facing contracts.
- First-waypoint coordinate hydration for route initialization is centralized behind route-focused helpers in `Data/Infrastructure/Realm/Route.swift` (`firstWaypointCoordinate(for:)`, `markerCoordinate(forMarkerID:)`).
- When validating route modularization slices locally, prefer clean derived data (for example `/tmp/soundscape-modularization-dd2`) before `xcodebuild build-for-testing` and targeted suites (`RouteStorageProviderDispatchTests`, `DataContractRegistryDispatchTests`, `CloudSyncContractBridgeTests`) to avoid stale test artifacts.

## Modularization Checkpoint (2026-03-04)
- Milestone 4 in-memory contract parity is complete; coverage now includes cloud marker import read round-trip, metadata/callout nickname-fallback semantics, and entity-key upsert behavior after temporary-marker cleanup.
- Milestone 3 Realm adapter isolation hardening is now the primary active execution track.
- For data-modularization slices, known full-suite `AudioEngineTest` failures (`testDiscreteAudio2DSimple`, `testDiscreteAudio2DSeveral`) are currently tracked as non-blocking.

## Compatibility Seam Policy
- Temporary compatibility APIs (for example sync wrappers around async-first contracts) must be explicitly marked deprecated with `@available(*, deprecated, message: "...")`.
- Deprecation messages should point to the preferred replacement API (for example async contract surface) so callsites are easy to migrate.
- When adding or removing a temporary compatibility seam, update `docs/plans/modularization_plan.md` with current status and intended removal direction.
