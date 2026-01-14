# CalloutCoordinator Queue Runner Simplification Plan

_Last updated: 2026-01-14_

## Scope / Non-goals
- This plan is **only** about simplifying the internal callout playback loop (readability + correctness invariants) within `CalloutCoordinator` and its boundary with `AudioEngine`.
- We are **not** changing the broader event pipeline direction in this plan:
  - Ordering-sensitive and callout-producing event handling stays on the existing synchronous generator path.
  - Typed generator streams remain limited to non-order-sensitive, state-only updates.

## Problem Statement
`CalloutCoordinator` currently works and is async-friendly, but it’s harder than it needs to be to reason about because it mixes:
- queue policy (which groups are pending, validity checks, interrupt rules)
- playback sequencing (prelude → callouts → completion)
- concurrency control (per-group tasks, cancellation, idle waiting)
- completion plumbing (delegate callbacks + `CalloutGroup.onComplete` + `playCallouts` continuations)

The goal is to make the coordinator read like a single “command-driven loop”, so the mental model becomes:

> “Commands mutate a high-level queue; one runner processes it; hush/interrupt is an explicit command that stops audio and causes the current group to finish exactly once.”

## Current Ownership Model (for reference)
- `CalloutCoordinator`
  - owns the **callout-group queue** (`Queue<CalloutGroup>`)
  - chooses next valid group (`CalloutGroup.isValid()`)
  - drives group lifecycle and completion semantics
- `AudioEngine`
  - owns the **discrete sound queue** (`soundsQueue` + `currentSounds`)
  - owns player lifecycle and “when the next segment can start”
- Bridge
  - `AudioPlaybackActor` wraps `AudioEngineProtocol.playAsync(...)` and `stopDiscrete(with:)` into a minimal async interface

## Key Insight: Cancellation != Hush
Swift task cancellation unblocks `await` points, but does not stop AVAudio playback by itself.

We must treat hush/interrupt as two separate but coordinated effects:
1. **Stop audio now** via `AudioEngine.stopDiscrete(with:)` (possibly enqueueing a hush earcon).
2. **Unblock/abort the coordinator’s runner logic** (so `playCallouts` calls return promptly and state is consistent).

The existing `AudioEngineProtocol.playAsync(...)` implementation already supports “unblock without double-resume” via the `PlaybackContinuationToken`, so the coordinator can safely do both:
- cancel its awaiting work
- issue a stop command

## Proposed Design: A Single Runner Task + Command Stream
Instead of starting a new `Task` per group and maintaining an explicit playback state machine, run a single long-lived task that:
- receives commands (enqueue/clear/interrupt)
- processes the next pending valid group when idle

### Public API stays the same
We keep existing surface area (or as close as possible):
- `enqueue(_ group: CalloutGroup)`
- `func playCallouts(_ group: CalloutGroup) async -> Bool`
- `interruptCurrent(clearQueue:playHush:)`
- `clearPending()`

### Internal data types
Introduce a queued wrapper so we do not need an external UUID → continuation map:

```swift
private struct QueuedGroup {
    let group: CalloutGroup
    let continuation: CheckedContinuation<Bool, Never>?
}
```

### Command stream
Create an internal command enum:

```swift
private enum Command {
    case enqueue(QueuedGroup)
    case clearPending
    case interruptCurrent(clearQueue: Bool, hushSound: Sound?)
}
```

And a single `AsyncStream<Command>` plus continuation created during init.

### Runner state
Keep only what the runner must know:
- `pending: Queue<QueuedGroup>`
- `current: QueuedGroup?`
- `abortCurrent: Bool` (set by interrupt/hush)
- `hushedCurrent: Bool`

Avoid a complex multi-value playback state machine if we can express everything as:
- “we have a current group or not”
- “abort requested or not”

### Runner loop outline
Pseudo-structure (high level):

```swift
runnerTask = Task { @MainActor in
    for await command in commands {
        apply(command)
        while current == nil, let next = dequeueNextValid() {
            current = next
            let result = await runGroup(next)
            finishCurrentGroupOnce(result)
            current = nil
        }
    }
}
```

Notes:
- The loop processes as many pending groups as possible after each command, without re-entrant calls.
- `runGroup` is linear and contains the existing playback sequencing logic.

## Hush/Interrupt Semantics in the Runner Model
### Requirements
- Hush must stop discrete audio immediately.
- If a hush earcon is requested, it should play after stopping current audio.
- The currently awaiting `playCallouts` should return quickly.
- Pending queued groups may be cleared and must receive consistent “skipped/false” completion.

### Proposed behavior
On `.interruptCurrent(clearQueue:playHush:)`:
1. Set `abortCurrent = true` and `hushedCurrent = (hushSound != nil)`.
2. Call `audioPlayback.stopDiscreteAudio(hushSound: hushSound)`.
   - If `hushSound != nil`, `AudioPlaybackActor` returns quickly.
   - The next group run should still call `waitForDiscreteAudioSilence()` before starting, which naturally waits for the hush earcon to finish.
3. If `clearQueue == true`, drain pending groups:
   - call `delegate.calloutsSkipped` + `onSkip` where applicable
   - resume their continuations with `false`
4. Cause the active `runGroup` to exit on its next cancellation/abort check and finish the active group exactly once.

Implementation detail:
- `runGroup` should check `abortCurrent`:
  - before starting
  - after every awaited `play(...)`
  - before sleeping on any `calloutDelay`

## Completion Model: Exactly Once
Today completion flows through:
- `CalloutGroup.delegate` callbacks
- `CalloutGroup.onComplete` / `onSkip`
- `playCallouts` continuation

The runner design centralizes completion into a single helper:

```swift
private func finishGroupOnce(_ queued: QueuedGroup, finished: Bool, reason: FinishReason)
```

Rules:
- `calloutsCompleted(for:finished:)` fires once.
- `onComplete` OR `onSkip` fires once (depending on outcome).
- `playCallouts` continuation resumes once.

## AudioEngine Boundary: What stays in AudioEngine
This plan assumes AudioEngine continues to own:
- the discrete segment queue (`soundsQueue` / `currentSounds`)
- the “play next segment” mechanics (`playNextSound`)
- “stop discrete now” (`stopDiscrete(with:)`) including draining queued completions

This is compatible with the runner loop: the coordinator doesn’t need to know player IDs or segment timing; it only awaits “finished” and issues stop commands.

## Step-by-step Refactor Plan (Low Risk)
### Step 0 — Write a small invariants doc (this file)
Done. (Committed)

### Step 1 — Centralize completion without changing concurrency
- Add `QueuedGroup` wrapper and store the `CheckedContinuation` alongside each enqueued group.
- Add `finishGroupOnce(...)` and route *all* current completion outcomes through it.
- Keep current `Task` approach initially.

Status: Done (2026-01-14)

Notes:
- Implemented `QueuedGroup` + a `GroupCompletionToken` so `playCallouts` continuations are stored with the queued group and resumed exactly once.
- Removed the `pendingContinuations` dictionary and the closure-rewriting approach.

Acceptance check: no behavior changes; existing tests pass.

### Step 2 — Make hush/interrupt a single path
- Ensure interrupt/hush performs:
  - stop audio
  - finish current group once (false)
  - optionally clear pending
- Delete duplicated “notify completion” sites by funneling them to `finishGroupOnce`.

Status: Done (2026-01-14)

Notes:
- Fixed interrupt/hush when a group is staged (`playbackState == .off` but a `currentQueuedGroup` exists): we now cancel the pending playback task, stop discrete audio, complete the group (false), and advance the queue.

Acceptance check: existing tests pass; add a focused unit test that hush completes exactly once.

### Step 3 — Replace per-group playback tasks with a single runner task
- Introduce command stream and runner task.
- Make `enqueue`, `clearPending`, `interruptCurrent` emit commands.
- Move “tryStartCallouts / startCallouts / beginPlayback” logic into the linear runner.

Status: Done (2026-01-14)

Notes:
- Added an internal command loop so queue mutations (`enqueue`, `clearPending`, `interruptCurrent`) are expressed as commands and `tryStartCallouts()` is driven from the command loop.
- Playback completion now schedules queue advancement via a `.startNext` command.

Acceptance check:
- no deadlocks
- no re-entrancy
- no double completion

### Step 4 — Delete now-unnecessary machinery
Once the runner is stable, remove:
- `PlaybackState` enum (or reduce to minimal)
- `IdleSignal` (runner is the idle mechanism)
- `pendingContinuations` dictionary and mutation of group closures (if Step 1 moved continuations into `QueuedGroup`)

Status: Done (2026-01-14)

Notes:
- Reduced playback state to a minimal `PlaybackPhase` (idle/running/stopping) and removed the idle-wait signaling.
- Removed the redundant `completionResult` plumbing; the finished result is now passed directly to the final completion path.

## Testing Strategy
We should keep tests focused and behavior-oriented:
- **Callout completion exactly once** under:
  - normal success
  - `stopSoundsBeforePlaying` cases
  - hush/interrupt while playing
- **Queue drain semantics**:
  - `clearPending` causes pending groups to be skipped and their `playCallouts` to return `false`
- **No overlap**:
  - after hush with earcon, next group waits for silence before starting

We can implement these using existing mocks in `EventProcessorTest` (MockAudioEngine + CalloutCoordinator), or add a dedicated coordinator test harness if needed.

## Acceptance Criteria
- `CalloutCoordinator` can be understood as:
  - “commands + queue + one runner”
- Each `CalloutGroup` completes exactly once across all paths.
- Hush stops audio promptly and unblocks awaiting callers promptly.
- Existing unit tests pass; add minimal new tests for hush/interrupt completion semantics.

## Open Questions (to resolve before coding)
- When `clearPending` runs, do we want to invoke `onSkip` or `onComplete(false)` for pending groups (today: `onSkip` + delegate skipped)? Pick one and keep it consistent.
- Do we need a distinct outcome for “interrupted with hush earcon” vs “failed playback” for telemetry? If so, model `FinishReason` explicitly.
