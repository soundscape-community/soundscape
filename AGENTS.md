# Soundscape Agent Instructions

This file is the canonical instruction source for coding agents in this repository.

## Repository Map
- `apps/ios/`: iOS app (`GuideDogs.xcworkspace`, app code, unit tests, CI scripts).
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

## Build, Test, and Lint Commands
Use commands aligned with `.github/workflows/ios-tests.yml`, but for local runs always use a simulator that is already installed on the current machine.

Local session rule:
- At the start of each session, check available simulators with `xcrun simctl list devices available`.
- Do not download simulator runtimes just to run local build/tests.
- CI remains pinned in workflow config; do not edit workflow destinations for this.

From repo root:

```bash
cd apps/ios
swift Scripts/LocalizationLinter/main.swift

# Per session: pick an installed iPhone simulator (first available).
SIMULATOR_ID=$(xcrun simctl list devices available \
  | rg "iPhone" \
  | head -n 1 \
  | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')

if [ -z "$SIMULATOR_ID" ]; then
  echo "No available iPhone simulator found. Create one locally in Xcode."
  exit 1
fi

DESTINATION="platform=iOS Simulator,id=${SIMULATOR_ID}"

xcodebuild build-for-testing -workspace GuideDogs.xcworkspace \
  -scheme Soundscape \
  -destination "$DESTINATION" \
  CODE_SIGN_IDENTITY= CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
xcodebuild test-without-building -workspace GuideDogs.xcworkspace \
  -scheme Soundscape \
  -destination "$DESTINATION"
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
