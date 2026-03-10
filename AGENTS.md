<!-- Copyright (c) Soundscape Community Contributers. -->

# Soundscape Agent Instructions

This file is the canonical instruction source for coding agents in this repository.

## Repository Map
- `apps/ios/`: iOS app (`GuideDogs.xcworkspace`, app code, unit tests, CI scripts).
- `apps/common/`: shared Swift package for platform-agnostic modules (currently `SSDataStructures`, `SSGeo`, `SSLanguage`, `SSDataDomain`, `SSDataContracts`).
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
- `SSLanguage` now lives in `apps/common` and provides portable localization helpers, distance/direction/intersection/street-address/cardinal-movement formatters, locale helpers, and package-owned shared language resources.
- Localization validation now checks both `apps/ios/GuideDogs/Assets/Localization` and `apps/common/Sources/SSLanguage/Resources`, and it blocks reintroducing `SSLanguage`-owned helper keys into the iOS app bundle.
- `SSDataDomain` now lives in `apps/common` and hosts canonical route/reference domain value models plus shared POI/category/type/filter/sort/queue/query abstractions and portable POI matching logic shared with iOS.
- `SSDataContracts` now lives in `apps/common` and hosts shared contract-side value types for storage/read-write boundaries, including universal-link parameter/parsing types, `VectorTile`, and the Swift `GDAJSONObject` helper after decoupling them from iOS runtime behavior.

## Data Modularization Status
- `SSDataStructures`, `SSGeo`, `SSLanguage`, `SSDataDomain`, and `SSDataContracts` are extracted into `apps/common`.
- `DataContractRegistry` is the app-facing data ingress.
- Realm implementation remains infrastructure-local under `apps/ios/GuideDogs/Code/Data/Infrastructure/Realm`.
- `SpatialDataCache` usage is confined to Realm infrastructure and the retired sync-store seam (`SpatialDataStoreRegistry`, `DefaultSpatialDataStore`, `SpatialDataStore`) must not be reintroduced.
- Marker cloud write/update paths are value-shaped (`MarkerParameters` updates, marker-ID deletes) rather than entity-shaped compatibility helpers.
- Boundary rule: keep `apps/common` platform-agnostic. Do not import Apple UI/platform frameworks in `apps/common/Sources`.
- Boundary enforcement script: `bash apps/common/Scripts/check_forbidden_imports.sh`.
- Package tests for extracted modules: `swift test --package-path apps/common`.

## Common Module Naming
- Use `SS` + concise domain noun for modules in `apps/common` (for example: `SSDataStructures`, `SSUniversalLinks`).
- Avoid `Soundscape*` prefixes and avoid generic names like `Core` or `Common` alone.
- Keep names short, domain-specific, and consistent with import usage in iOS targets.

## Plan Documents
- Active plans live in `docs/plans/`.
- Modularization progress is tracked in `docs/plans/modularization_plan.md`.
- Language extraction progress is tracked in `docs/plans/language_modularization_plan.md`.
- Stable target/boundary rules live in `docs/plans/data_modularization_north_star.md`.
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

# Localization-only validation (checks iOS assets + SSLanguage resources/boundary):
(cd apps/ios && swift Scripts/LocalizationLinter/main.swift)

# Optional output modes for build/test stage:
bash apps/ios/Scripts/ci/run_local_validation.sh -- --output quiet
bash apps/ios/Scripts/ci/run_local_validation.sh -- --output summary
bash apps/ios/Scripts/ci/run_local_validation.sh -- --output xcpretty
bash apps/ios/Scripts/ci/run_local_validation.sh -- --output raw

# Build/test only (without running other baseline checks):
bash apps/ios/Scripts/ci/run_local_ios_build_test.sh

# Targeted data-modularization suites (low-noise wrapper):
bash apps/ios/Scripts/ci/run_data_modularization_targeted_tests.sh
bash apps/ios/Scripts/ci/run_data_modularization_targeted_tests.sh --output quiet

# Focused seam/boundary spot check:
bash apps/ios/Scripts/ci/check_spatial_data_cache_seam.sh
```

## Tool Output and Context Hygiene
- Watch for high-volume tools (especially `xcodebuild`) polluting agent/user context with low-signal logs.
- Treat context tokens as a limited budget: default to low-noise output and avoid full log streaming unless actively diagnosing a failure.
- Prefer concise output modes and wrappers for repeated actions:
  - `--output quiet` (alias for `summary`) for routine local runs where context minimization is the priority.
  - `--output summary` for the lowest-noise local loop (step pass/fail + counts + log paths).
  - `--output errors` for routine local build/test loops.
  - `--output xcpretty` only when human-readable per-test output is specifically needed (`xcpretty` is available locally).
- When a command is repeated often, prefer a small script in `apps/ios/Scripts/ci/` rather than re-issuing long raw commands.
- When creating or changing a script in `apps/ios/Scripts/ci/`, update this `AGENTS.md` in the same change with command examples, defaults, and supported output/options so future sessions can discover and use it correctly.
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

## Data Modularization Checkpoints
- Data read/write contract compatibility surfaces are removed from production; use async `DataContractRegistry.spatialRead` and `DataContractRegistry.spatialWrite`.
- Canonical route write APIs are domain-shaped: `SpatialWriteContract.addRoute(_ route: Route)` and `SpatialWriteContract.updateRoute(_ route: Route)`.
- First-waypoint coordinate hydration stays infrastructure-local behind route-focused Realm helpers.
- Destination temporary-marker mutation is persistence-local (`RealmReferenceEntity.setTemporary(id:temporary:)`).
- Data-infrastructure runtime facades (for example `RouteRuntime`) should stay within data infrastructure; behavior-layer callers should use behavior/UI runtime or delegate seams instead.
- Neutral app-layer wrappers such as spatial search/bootstrap/migration entry points should remain declaration-only outside infrastructure, with Realm-backed implementations owned from `Data/Infrastructure/Realm/**`.
- Route persistence errors exposed outside infrastructure should stay boundary-neutral (`RouteDataError`), not Realm-branded.
- Packaging direction: keep `apps/common` portable (`SSGeo`, `SSLanguage`, `SSDataDomain`, `SSDataContracts`), keep `DataContractRegistry` as the single composition root in `apps/ios`, and move runtime-neutral types into `apps/common` instead of using `apps/ios/Package.swift` as a modularization boundary.
- `DataContractRegistry` should store installed defaults, but concrete Realm adapter construction belongs in infrastructure-owned installer code (`configureWithRealmDefaults()`), not in the registry file itself.
- Shared route/marker/location parameter models, `UniversalLinkParameters`, and universal-link path/version/component parsing types now live in `apps/common/Sources/SSDataContracts`; keep only runtime managers/handlers and other app-specific behavior in `apps/ios`.
- `VectorTile` and `GDAJSONObject` now live in `apps/common/Sources/SSDataContracts`; keep the iOS helper file as a CoreLocation shim only, and do not reintroduce the old Objective-C bridge.
- `POI`, `GenericLocation`, `SuperCategory`, portable POI equality/matching, type/filter/sort/queue/query helpers, and generic `[POI]` array helper logic now live in `apps/common/Sources/SSDataDomain`; keep only Realm keys, CoreLocation conveniences/bridges, quadrant-specific wrappers, and glyph/audio presentation mapping in `apps/ios`.
- Shared distance/direction/intersection/street-address/cardinal-movement localization helper keys are owned by `SSLanguage`; do not duplicate those key families back into `apps/ios/GuideDogs/Assets/Localization/**`.
- `SSLanguage` call sites in `apps/ios` now import the module directly for portable types; keep iOS wrappers only where app-locale defaults, `AppContext`, or Apple-framework bridging are still required.
- `apps/ios/Package.swift` is placeholder/editor scaffolding and should not be used as the architectural extraction boundary.
- Current validation default for modularization slices is low-noise output (`--output quiet`).
- Known local full-suite non-blocking failures remain `AudioEngineTest.testDiscreteAudio2DSimple` and `AudioEngineTest.testDiscreteAudio2DSeveral`.

## Compatibility Seam Policy
- Temporary compatibility APIs (for example sync wrappers around async-first contracts) must be explicitly marked deprecated with `@available(*, deprecated, message: "...")`.
- Deprecation messages should point to the preferred replacement API (for example async contract surface) so callsites are easy to migrate.
- When adding or removing a temporary compatibility seam, update `docs/plans/modularization_plan.md` with current status and intended removal direction.
