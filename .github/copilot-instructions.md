# Soundscape Copilot Instructions

## Key Components
- **apps/ios/GuideDogs/** contains the Swift iOS client; most code lives under `Code/Behaviors`, `Code/Audio`, and `Code/Services`. Treat this as the default target for feature work.
- **docs/** holds design notes (e.g., `docs/ios-client/overview.md`, `docs/callout_architecture_plan.md`) that explain the behavior/callout pipeline and the ongoing Swift-concurrency migration—consult them before reshaping architecture.
- **svcs/data/** provides ingestion + tile-serving scripts (Python, Docker, Rust); keep iOS and services changes isolated because they build and deploy independently.

## Behavior & Callout Architecture
- Behaviors subclass `BehaviorBase` (`apps/ios/GuideDogs/Code/Behaviors/Helpers`) and own `manualGenerators` (user-initiated) plus `autoGenerators` (state-driven). Events bubble to parents if the active behavior doesn90t handle them.
- Manual generators now prefer `AsyncManualGenerator` when they must await playback; see `SystemGenerator`, `ExplorationGenerator`, `PreviewGenerator`, and `AutoCalloutGenerator` for patterns.
- Automatic generators still return `HandledEventAction` values synchronously; don90t convert unless the generator truly needs to await audio completion.
- `CalloutGroup` encapsulates playback batches. Always set `action`, `logContext`, and `delegate`/`onComplete` when completion semantics matter (examples throughout `apps/ios/GuideDogs/Code/Behaviors/Default`).
- Follow the modernization plan in `docs/callout_architecture_plan.md`: new async work should route through `BehaviorDelegate.playCallouts` and keep hush/validation inside the coordinator instead of sprinkling timers.
- When a multi-step plan exists, keep executing subsequent steps without pausing for approval; surface blockers only when truly necessary.

## Concurrency & Actors
- New async code should be `@MainActor` unless it deliberately hops to another actor (audio, data services). Generators that touch UIKit/AppContext must stay on the main actor.
- Avoid introducing ad-hoc `DispatchQueue` usage; prefer `Task { @MainActor in ... }` or existing helper actors (`CalloutCoordinator`, `AudioPlaybackActor`).
- When awaiting `delegate.playCallouts`, capture any `completionHandler` from the event and call it via `CalloutGroup.onComplete` so legacy behavior observers still fire.

## Build, Test, and Tooling
- Run iOS tests with `cd apps/ios && xcodebuild test -workspace GuideDogs.xcworkspace -scheme 'Soundscape' -destination 'platform=iOS Simulator,name=iPhone 17'`; CI expects this exact scheme/destination.
- The workspace depends on SwiftPM plus local assets under `apps/ios/GuideDogs`—use `xed .` or open `GuideDogs.xcworkspace` directly.
- Fastlane lanes (in `apps/ios/fastlane`) assume Bundler; run `bundle install` inside `apps/ios` before invoking any lane.
- When touching localization or audio assets, update the matching files under `apps/ios/GuideDogs/Assets` and keep filenames ASCII to satisfy build phases.

## Services Side Notes
- Data ingestion utilities under `svcs/data` rely on Python scripts + Dockerfiles; run them via the provided `docker-compose.yml`. They feed tile data consumed by the iOS client90s `SpatialDataContext`.
- Rust helpers live in `svcs/data/misc` (`Cargo.toml`); keep their build separate from the iOS toolchain.

## Working Agreements
- Keep documentation current: whenever you add or migrate a generator, append a short bullet to `docs/callout_architecture_plan.md` summarizing the change and its rationale.
- Tests: new callout behaviors should add coverage under `apps/ios/UnitTests/**` (see `PreviewGeneratorTests.swift` for async generator testing patterns).
- Logging: prefer `GDLog*` macros over `print` for anything that surfaces in telemetry; choose the category matching the subsystem (e.g., `.autoCallout`, `.routeGuidance`).
- Before large refactors, scan `docs/ios-client/components/` for write-ups on each subsystem to stay aligned with historical decisions.
- Stage and commit cohesive chunks of work at natural breakpoints (e.g., after each generator migration + docs/tests) so reviewers can follow the plan’s progress.

*Questions or missing guidance? Let the maintainers know so we can extend this document.*
