# Callout Pipeline Modernization Plan

## Goal
Evolve the current callout pipeline (behaviors → EventProcessor → CalloutCoordinator → AudioEngine) into a simpler, Swift-concurrency-first architecture that is easier to reason about, test, and extend.

## Current Stack Summary
- **Behaviors & Generators**: Each behavior owns mutable queues of callout generators plus ad-hoc DispatchQueues/timers to decide when to speak. They coordinate hush, validation, and priority themselves.
- **EventProcessor**: Central router that interprets app events, manages the behavior stack, and executes the resulting actions (enqueue callouts, interrupt/hush, and enqueue follow-up events).
- **CalloutCoordinator**: Main-actor queue + state machine replacement that sequences hush → play → completion via async/await, encapsulating what the legacy state machine handled.
- **AudioEngine**: `@MainActor` class with its own queue and delegate callbacks. Callouts poll this layer to know when discrete audio stopped before continuing.
- **Communication Style**: Delegates and completion closures hop between these layers, creating long-lived references and shared mutable state.

## Pain Points
1. **Distributed state**: Hush, queueing, and validation flags live in multiple classes, making it hard to see which component truly “owns” a callout.
2. **Callback pyramids**: Completion + hush + “still valid?” decisions can happen in any layer, producing complex control flow and race potential.
3. **Difficult testing**: Mocking delegate chains and DispatchQueues makes regression tests brittle under Swift 6 actor rules.
4. **Audio coupling**: EventProcessor and behaviors reach deep into AudioEngine concerns (e.g., waiting for hush completion), violating separation of concerns.

## Proposed Direction
Introduce a small set of concurrency-friendly components with clear responsibilities and async APIs:

### 1. `CalloutCoordinator`
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
- Event handling becomes structured and serial: events are processed in-order, and each behavior can have its own event loop task.
- This reduces callback pyramids and makes cancellation / teardown explicit when behaviors deactivate.

### 4. `AudioPlaybackActor`
- Wrap AVAudioEngine interactions in an actor that exposes suspending functions such as `play(segments:) async` and `stopDiscreteAudio() async`.
- CalloutCoordinator simply awaits these calls; no polling or completion delegates necessary.

### 5. Shared Data Actors
- Secondary actors (e.g., `SpatialDataActor`, `CalloutHistoryActor`) provide safe read/write access without the EventProcessor reaching into main-actor singletons.

## Migration Steps
1. **Coordinator Scaffold (done)**: Introduce `CalloutCoordinator` as the callout queue owner with async APIs so behaviors can await playback.
2. **Audio Actor Facade (done)**: Add `AudioPlaybackActor` / `AudioPlaybackControlling` so coordinator awaits playback instead of polling engine delegates.
3. **Manual Generator Refactor (done)**: `ManualGenerator` is async; `AsyncManualGenerator` is now just a deprecated typealias.
4. **Retire CalloutStateMachine (done)**: Remove the legacy state machine and route all queueing/interrupt logic through the coordinator.
5. **Async Event Streams (in progress)**: EventProcessor queues incoming events via `AsyncStream`, and each behavior now has a dedicated event dispatcher loop.
6. **Typed Generator Streams (next)**: Provide typed `AsyncSequence`s for user/state events so generators can subscribe declaratively, and shrink/remove the large `BehaviorBase.handleEvent` switch.

## Validation & Testing
- Unit tests create a mock `AudioPlaybackActor` that completes after controlled delays, allowing deterministic testing of hush and validation.
- Integration tests spin up coordinator + mock behaviors, verifying order of callout execution via async expectations.
- Because every component is an actor or structured Task, Swift 6 concurrency checks enforce thread safety, reducing reliance on custom DispatchQueues.

Must-have regression tests for the migration:
- **Coordinator exactly-once completion**: play/skip/hush/interrupt paths each resolve a callout group once (no double completion, no hangs).
- **Cancellation on deactivation**: when a behavior deactivates mid-playback, any awaiting generator unblocks and no further callouts are enqueued/played from that behavior.
- **Event ordering under delay**: long-running manual generator playback must not reorder subsequent events for the same behavior.
- **Queue/backpressure behavior**: sustained bursts of state events with delayed playback do not cause unbounded growth (or, if growth is allowed, it is observable and covered by a policy).
- **Parent bubbling contract**: key events that must bubble are asserted (child “no-op handle” must not suppress parent behavior).

## Expected Benefits
- **Readability**: Clear ownership—`CalloutCoordinator` is the single place where hush, queueing, and validation occur.
- **Maintainability**: Behaviors focus on deciding *what* to play, not *how* to schedule audio. EventProcessor just routes events.
- **Reliability**: Structured concurrency removes race-prone delegate chains; hush/interrupt logic becomes cancellation instead of manual callbacks.
- **Testability**: Actors expose async APIs that can be mocked without touching DispatchQueues or run loops.

## Maintainability Notes (Remaining “Global Reasoning” Hotspots)
- **Backpressure & latency**: Serialized per-behavior event loops prevent interleaving, but they can hide unbounded queues if handlers await long-running playback. Define/measure queue depth and consider coalescing or dropping policies for high-frequency events.
- **Cancellation & lifecycle**: Ensure behavior deactivation cancels in-flight work (especially tasks awaiting audio) so we never emit callouts after a behavior is deactivated.
- **Exactly-once completion**: The async/legacy bridging (continuations and completion closures) must uphold a strict invariant: each enqueued callout group resolves exactly once (no double-resume traps, no “never resumed” hangs).
- **Main-actor contention**: Keeping behaviors and the coordinator on `@MainActor` improves safety, but increases responsiveness risk if any heavy work slips into handlers. Prefer moving expensive work behind dedicated actors/services.
- **Parent bubbling contract**: Closure-based forwarding reduces coupling, but correctness still depends on which events must bubble. Keep this contract explicit and covered by tests.

Practical acceptance checks:
- No callouts play after behavior deactivation.
- Each callout group completes exactly once across play/skip/hush/interrupt paths.
- Event queue growth remains bounded/observable under delayed playback.

- `CalloutCoordinator` now owns hush + queue orchestration end-to-end. EventProcessor and AppContext wire a single coordinator instance, and the legacy `CalloutStateMachine` implementation has been deleted.
- **State machine files removed:** `CalloutStateMachine.swift` plus its Xcode project references are gone, and the remaining tests (`EventProcessorTest`) now construct the coordinator directly. This locks the pipeline to a single playback surface before we proceed with async event streams.
- **Event stream queue:** `EventProcessor` now publishes every event into an `AsyncStream` that a main-actor task consumes. Behaviors still feed actions through the delegate for now, but recursive `process(_:)` calls are replaced with structured queuing so we can hand dedicated streams to each behavior next.
- `BehaviorDelegate` gained an async `playCallouts` API and `OnboardingBehavior` became the pilot client: it now wires a dedicated `OnboardingCalloutGenerator` built on the async `ManualGenerator` protocol, allowing onboarding UI flows to block on completion without sprinkling manual `Task` management through the behavior.
- **Manual generator protocol unified:** the legacy `AsyncManualGenerator` shim has been folded into `ManualGenerator`, so every manual generator now awaits playback through `delegate.playCallouts` and the callback-based manual path is gone.
- **Audio facade extracted:** `CalloutCoordinator` depends on the `AudioPlaybackControlling` protocol that is fulfilled by `AudioPlaybackActor`, an actor wrapping the main-actor `AudioEngine`. All discrete audio stop/wait logic lives behind this facade so callout sequencing no longer touches `AudioEngine` directly, and hush completion is handled by awaiting the actor instead of polling delegates. The Soundscape XCTest bundle passes on the iPhone 17 simulator (iOS 26.1), exercising the updated hush + playback flow.
- **Preview behavior now awaits callouts:** the road-finder flow constructs callouts through the shared `PreviewGenerator` but uses `delegate.playCallouts` under the hood, so onboarding-style instructional sequences (`PreviewStartedEvent`, instructions, node transitions, resume, beacon updates, and focus confirmations) block until audio finishes before restarting wand haptics. This removes the temporary completion closures and lets us reason about preview state changes with async/await.
- **Tutorial pages await callouts:** `BaseTutorialViewController` (and the destination tutorial pages layered on top of it) now route announcements through `TutorialCalloutPlayer`, so the UI waits for discrete audio to finish without `GenericAnnouncementEvent` completion pyramids.
- **Accessibility observers main-threaded:** `TelemetryHelper` now registers every `UIAccessibility` status observer on `OperationQueue.main`, eliminating the AXCommon `unsafeForcedSync` warnings we saw once the coordinator began running under Swift concurrency checks.
- **Preview generator tests:** New unit tests under `UnitTests/Behaviors/Preview` exercise the async generator/delegate bridge so regressions in `PreviewGenerator.handle` surface without spinning up the full preview behavior.
- **System generator awaits callouts:** `SystemGenerator` now rides on the async `ManualGenerator` protocol, letting headset checks, voice previews, generic announcements, and repeat requests await `delegate.playCallouts` so their completion handlers and hush semantics align with the rest of the async pipeline.
- **Headset test generator awaits instructions:** the AR headset validation flow now runs through `HeadsetTestGenerator`'s async implementation, so the instructional callout awaits playback before spinning up the test beacon, and the teardown step clears the beacon without the legacy `.noAction` plumbing.
- **Exploration generator awaits toggles:** `ExplorationGenerator` now adopts the async `ManualGenerator`, so locate/around-me/ahead-of-me/nearby-marker toggles await delegate playback, yet it still services automatic POI updates without duplicating hush state across the behavior stack.
- **Per-behavior event loops:** `EventProcessor` wraps each behavior in a `BehaviorEventDispatcher` that owns an `AsyncStream`/Task pair, serializing `handleEvent` calls per behavior. Parent forwarding now flows via an injected closure (not `parent?.handleEvent(...)`).
- **Event ordering test:** `EventProcessorTest` includes coverage that events are processed sequentially for a behavior even when completions are delayed.
- **Next up:** expose typed `AsyncSequence`s (e.g., user-initiated vs state-changed) so generators can subscribe directly and we can shrink the central `BehaviorBase.handleEvent` switch.

- **Typed event streams (started):** `BehaviorBase` now exposes typed `AsyncStream`s (`userInitiatedEvents`, `stateChangedEvents`, plus `allEvents`) and finishes them on deactivation so future generator subscriptions can be cancellation-safe.
- **Pilot subscription:** `AutoCalloutGenerator` and `ExplorationGenerator` now subscribe to `stateChangedEvents` for non-blockable prioritized-POI registration events, exercising generator-owned event loops without changing `HandledEventAction` routing.
- **Additional subscription:** `AutoCalloutGenerator` also consumes `GPXSimulationStartedEvent` via its subscription to reset internal state without emitting actions.
- **Intersection/Beacon reset via subscription:** `IntersectionGenerator` and `BeaconCalloutGenerator` now reset local state when `GPXSimulationStartedEvent` broadcasts arrive on the state stream, shrinking the legacy `handle(event:)` switches.
- **Subscription correctness:** subscriptions are deduped when a generator appears in both `manualGenerators` and `autoGenerators`, and per-subscriber streams are explicitly finished on deactivation to ensure subscriber tasks terminate cleanly.
- **Non-goal (for now):** callout-producing events like `GlyphEvent` remain routed via `HandledEventAction` so the `EventProcessor` continues to own queue/interrupt semantics.

_Last updated: 2026-01-13_
