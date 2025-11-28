# Callout Pipeline Modernization Plan

## Goal
Evolve the current callout pipeline (behaviors → EventProcessor → CalloutStateMachine → AudioEngine) into a simpler, Swift-concurrency-first architecture that is easier to reason about, test, and extend.

## Current Stack Summary
- **Behaviors & Generators**: Each behavior owns mutable queues of callout generators plus ad-hoc DispatchQueues/timers to decide when to speak. They coordinate hush, validation, and priority themselves.
- **EventProcessor**: Central router that interprets app events, delegates to behaviors, and manually wires hush/completion callbacks between behaviors and the state machine. Needs deep knowledge of every behavior.
- **CalloutStateMachine**: Imperative, callback-driven component that sequences hush → play → completion via closures/delegates while also waiting for audio silence.
- **AudioEngine**: `@MainActor` class with its own queue and delegate callbacks. Callouts poll this layer to know when discrete audio stopped before continuing.
- **Communication Style**: Delegates and completion closures hop between these layers, creating long-lived references and shared mutable state.

## Pain Points
1. **Distributed state**: Hush, queueing, and validation flags live in multiple classes, making it hard to see which component truly “owns” a callout.
2. **Callback pyramids**: Completion + hush + “still valid?” decisions can happen in any layer, producing complex control flow and race potential.
3. **Difficult testing**: Mocking delegate chains and DispatchQueues makes regression tests brittle under Swift 6 actor rules.
4. **Audio coupling**: EventProcessor and behaviors reach deep into AudioEngine concerns (e.g., waiting for hush completion), violating separation of concerns.

## Proposed Direction
Introduce a small set of actors with clear responsibilities and async APIs:

### 1. `CalloutCoordinator` Actor
- Owns the callout queue, hush state, and interaction with AudioEngine.
- API example: `func enqueue(_ request: CalloutRequest) async -> CalloutResult`.
- Serializes access; hush stays a **dual action**: the coordinator immediately issues `stopDiscrete()`/`stopAll()` to the audio layer *and* cancels any awaiting tasks so behaviors unblock as soon as audio is silenced.
- Each `CalloutRequest` carries an `isStillValid` closure so the coordinator can re-check right before audio starts, replacing delegate-based validation without extra tokens.

### 2. Behavior Intents
- Behaviors stay `@MainActor` but no longer manage their own queues/timers for playback.
- They create `CalloutRequest` instances describing what to play (segments, priority, hush policy) and await the coordinator’s result.
- Behaviors react to results (finished, skipped, hushed) via structured concurrency instead of delegate callbacks.

### 3. Event Routing via Async Streams
- EventProcessor becomes a lightweight dispatcher emitting events into an `AsyncStream<Event>`.
- Behaviors run as Tasks that consume this stream, filtering only what they need.
- This eliminates ad-hoc delegate hookups and allows easier cancellation when behaviors deactivate.

### 4. `AudioPlaybackActor`
- Wrap AVAudioEngine interactions in an actor that exposes suspending functions such as `play(segments:) async` and `stopDiscreteAudio() async`.
- CalloutCoordinator simply awaits these calls; no polling or completion delegates necessary.

### 5. Shared Data Actors
- Secondary actors (e.g., `SpatialDataActor`, `CalloutHistoryActor`) provide safe read/write access without the EventProcessor reaching into main-actor singletons.

## Migration Steps
1. **Coordinator Scaffold**: Introduce `CalloutCoordinator` actor that wraps today’s `CalloutStateMachine` logic but provides async APIs. Behaviors dispatch through it while legacy internals remain.
2. **Audio Actor Facade**: Add an async wrapper around AudioEngine operations to remove delegate callbacks. Coordinator now `await`s playback completion.
3. **Behavior Refactor**: Gradually replace behavior-specific queues with async Tasks and use structured cancellation for hush/interrupt logic. *Pilot:* `OnboardingBehavior` drops `OnboardingGenerator` in favor of direct `await coordinator.playCallouts(...)`, validating queue semantics and hush responsiveness in a contained scenario. This inlining is temporary—once the async API proves out we will reintroduce a generator-level protocol (e.g., `AsyncManualGenerator`) so other behaviors stay modular. Only the handful of behaviors that truly block the UI on completion (onboarding, preview, tutorials) will use the async helper; the rest keep the existing callback-based `CalloutGroup` flow so we avoid a wholesale redesign.
4. **Retire CalloutStateMachine**: Once the coordinator fully owns sequencing, delete the legacy state machine and convert EventProcessor to a simple dispatcher.
5. **Async Event Streams**: Move event routing from delegate callbacks to `AsyncStream`, letting behaviors subscribe declaratively.

## Validation & Testing
- Unit tests create a mock `AudioPlaybackActor` that completes after controlled delays, allowing deterministic testing of hush and validation.
- Integration tests spin up coordinator + mock behaviors, verifying order of callout execution via async expectations.
- Because every component is an actor or structured Task, Swift 6 concurrency checks enforce thread safety, reducing reliance on custom DispatchQueues.

## Expected Benefits
- **Readability**: Clear ownership—`CalloutCoordinator` is the single place where hush, queueing, and validation occur.
- **Maintainability**: Behaviors focus on deciding *what* to play, not *how* to schedule audio. EventProcessor just routes events.
- **Reliability**: Structured concurrency removes race-prone delegate chains; hush/interrupt logic becomes cancellation instead of manual callbacks.
- **Testability**: Actors expose async APIs that can be mocked without touching DispatchQueues or run loops.

- `CalloutCoordinator` now wraps the legacy state machine and exposes async helpers. EventProcessor owns a single coordinator instance instead of duplicating queue/continuation logic.
- `BehaviorDelegate` gained an async `playCallouts` API and `OnboardingBehavior` became the pilot client: it now wires a dedicated `OnboardingCalloutGenerator` that conforms to the new `AsyncManualGenerator` protocol, allowing onboarding UI flows to block on completion without sprinkling manual `Task` management through the behavior.
- **Audio facade extracted:** `CalloutStateMachine` now depends on a new `AudioPlaybackControlling` protocol that is fulfilled by `AudioPlaybackActor`, an actor wrapping the main-actor `AudioEngine`. All discrete audio stop/wait logic moved behind this facade so callout sequencing no longer touches `AudioEngine` directly, and hush completion is handled by awaiting the actor instead of polling delegates. The Soundscape XCTest bundle passes on the iPhone 17 simulator (iOS 26.1), exercising the updated hush + playback flow.
- **Preview behavior now awaits callouts:** the road-finder flow constructs callouts through the shared `PreviewGenerator` but uses `delegate.playCallouts` under the hood, so onboarding-style instructional sequences (`PreviewStartedEvent`, instructions, node transitions, resume, beacon updates, and focus confirmations) block until audio finishes before restarting wand haptics. This removes the temporary completion closures and lets us reason about preview state changes with async/await.
- **Tutorial pages await callouts:** `BaseTutorialViewController` (and the destination tutorial pages layered on top of it) now route announcements through `TutorialCalloutPlayer`, so the UI waits for discrete audio to finish without `GenericAnnouncementEvent` completion pyramids.
- **Accessibility observers main-threaded:** `TelemetryHelper` now registers every `UIAccessibility` status observer on `OperationQueue.main`, eliminating the AXCommon `unsafeForcedSync` warnings we saw once the coordinator began running under Swift concurrency checks.
- **Preview generator tests:** New unit tests under `UnitTests/Behaviors/Preview` exercise the async generator/delegate bridge so regressions in `PreviewGenerator.handleAsync` surface without spinning up the full preview behavior.
- **System generator awaits callouts:** `SystemGenerator` now conforms to `AsyncManualGenerator`, letting headset checks, voice previews, generic announcements, and repeat requests await `delegate.playCallouts` so their completion handlers and hush semantics align with the rest of the async pipeline.
- **Headset test generator awaits instructions:** the AR headset validation flow now runs through `HeadsetTestGenerator`'s async implementation, so the instructional callout awaits playback before spinning up the test beacon, and the teardown step clears the beacon without the legacy `.noAction` plumbing.
- **Exploration generator awaits toggles:** `ExplorationGenerator` now adopts `AsyncManualGenerator`, so locate/around-me/ahead-of-me/nearby-marker toggles await delegate playback, yet it still services automatic POI updates without duplicating hush state across the behavior stack.
- **Auto callout toggles await glyphs:** `AutoCalloutGenerator` conforms to `AsyncManualGenerator`, so manual interactions like enabling/disabling automatic callouts or announcing saved markers route through `delegate.playCallouts` instead of returning actions, ensuring those user-facing glyphs complete before subsequent UI state changes run.
- **Route guidance activation async:** `RouteGuidanceGenerator` now conforms to `AsyncManualGenerator`, so behavior activation events execute through the async path and keep auto-callout blocking aligned with the rest of the modernization work.
- **Guided tour activation async:** `TourGenerator` also adopts `AsyncManualGenerator`, moving its activation block logic into `handleAsync` so onboarding-style tour flows follow the same awaitable pattern.
- **Beacon generator aligns with async manual path:** `BeaconCalloutGenerator` now conforms to `AsyncManualGenerator`, so manual beacon requests and destination toggles reuse the same delegate-backed playback pipeline as other behaviors.
- Next up: extend `AsyncManualGenerator` beyond onboarding so other manual behaviors (preview, beacon training, tutorials) can adopt the same awaitable flow while we continue peeling away legacy callback-based generators.

_Last updated: 2025-11-28_
