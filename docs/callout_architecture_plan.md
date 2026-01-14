# Callout Pipeline Modernization Plan

> **Note (2026-01-14):** We are pausing further callout-pipeline modernization work. In particular, we explicitly decided to keep the remaining synchronous event handling for ordering-sensitive and/or callout-producing logic. Typed generator streams should remain limited to non-order-sensitive, state-only updates ("Bucket A"), and the later phases that propose new synchronous typed hooks or a fully-async pipeline are intentionally **out of scope for now**.

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
- **Manual generator protocol unified:** the legacy `AsyncManualGenerator` shim has been folded into `ManualGenerator`, so manual generators can use the async `delegate.playCallouts` API when needed. As a rule, *normal-use* generators should **not await** playback (fire-and-forget instead) so user actions can interrupt/hush immediately; onboarding/tutorial UI flows may still intentionally await.
- **Audio facade extracted:** `CalloutCoordinator` depends on the `AudioPlaybackControlling` protocol that is fulfilled by `AudioPlaybackActor`, an actor wrapping the main-actor `AudioEngine`. All discrete audio stop/wait logic lives behind this facade so callout sequencing no longer touches `AudioEngine` directly, and hush completion is handled by awaiting the actor instead of polling delegates. The Soundscape XCTest bundle passes on the iPhone 17 simulator (iOS 26.1), exercising the updated hush + playback flow.
- **Preview behavior callouts are fire-and-forget:** the road-finder flow constructs callouts through the shared `PreviewGenerator` and schedules playback via `delegate.playCallouts` without blocking event handling, so follow-up UI actions can interrupt immediately.
- **Tutorial pages await callouts:** `BaseTutorialViewController` (and the destination tutorial pages layered on top of it) now route announcements through `TutorialCalloutPlayer`, so the UI waits for discrete audio to finish without `GenericAnnouncementEvent` completion pyramids.
- **Accessibility observers main-threaded:** `TelemetryHelper` now registers every `UIAccessibility` status observer on `OperationQueue.main`, eliminating the AXCommon `unsafeForcedSync` warnings we saw once the coordinator began running under Swift concurrency checks.
- **Preview generator tests:** New unit tests under `UnitTests/Behaviors/Preview` exercise the async generator/delegate bridge so regressions in `PreviewGenerator.handle` surface without spinning up the full preview behavior.
- **System generator callouts are fire-and-forget:** `SystemGenerator` schedules headset checks, voice previews, generic announcements, and repeat requests without awaiting playback so user interactions can interrupt immediately.
- **Headset test generator is non-blocking:** the AR headset validation flow schedules its instructional callout without awaiting playback so it doesn't stall the event-processing queue.
- **Exploration generator is non-blocking:** `ExplorationGenerator` schedules locate/around-me/ahead-of-me/nearby-marker toggle callouts without awaiting playback so a second press can hush immediately.
- **Per-behavior event loops:** `EventProcessor` wraps each behavior in a `BehaviorEventDispatcher` that owns an `AsyncStream`/Task pair, serializing `handleEvent` calls per behavior. Parent forwarding now flows via an injected closure (not `parent?.handleEvent(...)`).
- **Event ordering test:** `EventProcessorTest` includes coverage that events are processed sequentially for a behavior even when completions are delayed.
- **Next up:** expose typed `AsyncSequence`s (e.g., user-initiated vs state-changed) so generators can subscribe directly and we can shrink the central `BehaviorBase.handleEvent` switch.

- **Typed event streams (started):** `BehaviorBase` now exposes typed `AsyncStream`s (`userInitiatedEvents`, `stateChangedEvents`, plus `allEvents`) and finishes them on deactivation so future generator subscriptions can be cancellation-safe.
- **Pilot subscription:** `AutoCalloutGenerator` and `ExplorationGenerator` now subscribe to `stateChangedEvents` for non-blockable prioritized-POI registration events, exercising generator-owned event loops without changing `HandledEventAction` routing.
- **Additional subscription:** `AutoCalloutGenerator` also consumes `GPXSimulationStartedEvent` via its subscription to reset internal state without emitting actions.
- **Intersection/Beacon reset via subscription:** `IntersectionGenerator` and `BeaconCalloutGenerator` now reset local state when `GPXSimulationStartedEvent` broadcasts arrive on the state stream, shrinking the legacy `handle(event:)` switches.
- **Subscription boundary clarified:** keep `LocationUpdatedEvent` handling in legacy `handle(event:)` when it may synchronously enqueue follow-on events (e.g., intersection arrival/departure events). Typed `AsyncStream` subscriptions are currently reserved for state updates that do not rely on same-turn ordering.
- **AR headset override via subscription:** `ARHeadsetGenerator` now consumes `CalibrationOverrideEvent` via its state stream subscription so the legacy `handle(event:)` switch stays focused on callout-producing events.
- **Route guidance distance callouts via subscription:** `RouteGuidanceGenerator` now consumes `BeginWaypointDistanceCalloutsEvent` via its state stream subscription to start its `BeaconUpdateFilter` and clear `awaitingNextWaypoint` without emitting actions.
- **Tour distance callouts via subscription:** `TourGenerator` now consumes `BeginTourWaypointDistanceCalloutsEvent` via its state stream subscription to start its `BeaconUpdateFilter` and clear `awaitingNextWaypoint` without emitting actions.
- **Subscription correctness:** subscriptions are deduped when a generator appears in both `manualGenerators` and `autoGenerators`, and per-subscriber streams are explicitly finished on deactivation to ensure subscriber tasks terminate cleanly.
- **Non-goal (for now):** callout-producing events like `GlyphEvent` remain routed via `HandledEventAction` so the `EventProcessor` continues to own queue/interrupt semantics.

## Deep-Dive: Are Typed Generator Streams the Right Direction?
Yes — but with an important boundary: an `AsyncStream` subscription is *not* the same thing as synchronous event handling.

### Key Insight: Ordering and “Same-Turn” Side Effects
`BehaviorBase.handleEvent` currently does three things (in order):
1. Publishes/yields the event into typed streams.
2. Routes the event through the legacy generator path (`handleUserInteraction` / `handleStateChange`).
3. Completes, then moves on to the next event.

Typed stream subscriptions run in separate `Task`s. Even though they are `@MainActor`, they are *scheduled work*, not inline work. This means:
- Any generator logic moved into a subscription may run **after** the legacy handling returns.
- If that moved logic enqueues follow-on events (e.g., `IntersectionArrivalEvent`, `IntersectionDepartureEvent`) or updates state that the very next event depends on, we can unintentionally change behavior.

Concrete example:
- `IntersectionGenerator.locationUpdated` can synchronously call `owner.delegate?.process(...)` to enqueue intersection arrival/departure events.
- If this moves to a subscription, those derived events can be delayed and interleave differently relative to other events.

So the direction is right, but we must be explicit about which event categories can safely move.

### What We Should Move vs Keep (Decision Framework)
Classify candidate migrations into three buckets:

**Bucket A — Safe to move into subscriptions (current approach)**
- Local state resets/flags that do not need to be applied “same turn”.
- No derived events (`delegate.process(...)`) and no dependency on immediate subsequent routing.
- Examples: GPX simulation resets, simple filters/flags, cached registration lists.

**Bucket B — Keep in legacy synchronous handling (for now)**
- Any handling that enqueues follow-on events or must preserve same-turn ordering.
- Any handling whose result affects the decision to generate callouts for the *same* incoming event.
- Examples: `LocationUpdatedEvent` flows that may emit derived events or whose state updates are used immediately.

**Bucket C — Requires a refactor of the pipeline**
- We still want the conceptual clarity of “typed subscriptions”, but we need ordering guarantees.
- This is where we should invest in a small framework change (below).

## Next Steps Plan (Detailed)
### Phase 1 — Lock the Boundary (Docs + Guardrails)
1. **Codify the bucket framework** (A/B/C) and apply it consistently when choosing migrations.
2. **Stop treating `return .noAction` as the migration signal.** The true signal is *ordering sensitivity*:
	- Does it enqueue follow-on events?
	- Does it mutate state that must be visible immediately?
3. **Annotate each migrated event in the plan** with its bucket and rationale.

### Phase 2 — Expand Bucket A Migrations Safely
1. Continue migrating Bucket A cases generator-by-generator.
2. Prefer subscription code paths that:
	- only mutate local state,
	- do not reference `delegateProvider()`,
	- do not call `delegate.process(...)` or `AppContext.process(...)`.
3. Add targeted tests only when semantics are subtle:
	- broadcast vs consumed delivery (already covered),
	- stream teardown on deactivation (already covered).

### Phase 3 — Refactor Proposal: “Synchronous Typed Side-Effects”
To migrate Bucket B/C logic without changing ordering, we need a synchronous hook that is still *typed* and generator-owned.

Proposed small refactor:
1. Introduce a new protocol for synchronous, ordering-sensitive state effects, e.g.
	- `BehaviorStateSideEffectHandling`
	- `func handleSideEffects(event: StateChangedEvent, delegate: BehaviorDelegate?)`
2. `BehaviorBase.handleEvent` should invoke this hook **inline** (on the main actor) for matching generators *before* it runs the legacy `handleStateChange` callout routing.
3. Keep the existing `AsyncStream` subscriptions for Bucket A (and for any work that benefits from being async/cancellable).

Benefits:
- Preserves current ordering semantics.
- Still lets us “delete switch cases” and move logic into generator-owned typed handlers.
- Gives us a clear stepping stone toward a future fully-async `handleEvent` pipeline.

Costs / risks:
- Slightly larger surface area in `BehaviorBase`.
- Needs careful thought around consumed vs broadcast semantics (the synchronous hook should mirror the same distribution rules).

Acceptance criteria for the refactor:
- No change in the ordering of derived events vs the originating event.
- No callouts play after deactivation.
- Existing stream-delivery tests continue to pass.

### Phase 4 — Bucket B/C Migrations Using the New Hook
1. Migrate ordering-sensitive `LocationUpdatedEvent` state-handling (like intersection detection) into the synchronous typed hook.
2. Keep callout production in `handle(event:)` until/unless we make the event processor pipeline fully async.
3. Add 1–2 focused unit tests that assert ordering for a derived-event case (e.g., a location update producing an arrival event) so we don’t regress.

_Last updated: 2026-01-14_
