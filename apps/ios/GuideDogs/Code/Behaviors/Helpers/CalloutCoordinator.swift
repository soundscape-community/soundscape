//
//  CalloutCoordinator.swift
//  Soundscape
//
//  Created to migrate the legacy callout queue/delegate chain toward an async-friendly coordinator.
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

@MainActor
final class CalloutCoordinator: CalloutStateMachineDelegate {

    private final class PendingCalloutCompletion {
        let continuation: CheckedContinuation<Bool, Never>
        let originalCompletion: ((Bool) -> Void)?
        let originalSkip: (() -> Void)?

        init(continuation: CheckedContinuation<Bool, Never>,
             originalCompletion: ((Bool) -> Void)?,
             originalSkip: (() -> Void)?) {
            self.continuation = continuation
            self.originalCompletion = originalCompletion
            self.originalSkip = originalSkip
        }
    }

    private var calloutQueue = Queue<CalloutGroup>()
    private var currentCallouts: CalloutGroup?
    private var pendingContinuations: [UUID: PendingCalloutCompletion] = [:]

    private let stateMachine: CalloutStateMachine

    init(stateMachine: CalloutStateMachine) {
        self.stateMachine = stateMachine
        self.stateMachine.delegate = self
    }

    var hasPendingCallouts: Bool {
        !calloutQueue.isEmpty
    }

    var hasActiveCallouts: Bool {
        currentCallouts != nil
    }

    func enqueue(_ callouts: CalloutGroup, continuation: CheckedContinuation<Bool, Never>? = nil) {
        GDLogEventProcessorInfo("CALL_OUT_TRACE coordinator enqueue group=\(callouts.id) action=\(callouts.action) hushOnInterrupt=\(callouts.playHushOnInterrupt)")

        calloutQueue.enqueue(callouts)

        if let continuation {
            registerContinuation(for: callouts, continuation: continuation)
        }

        tryStartCallouts()
    }

    func playCallouts(_ callouts: CalloutGroup) async -> Bool {
        await withCheckedContinuation { continuation in
            enqueue(callouts, continuation: continuation)
        }
    }

    func clearPending() {
        clearQueue()
    }

    func interruptCurrent(clearQueue shouldClear: Bool, playHush: Bool) {
        GDLogEventProcessorInfo("CALL_OUT_TRACE coordinator interrupt playHush=\(playHush) clearQueue=\(shouldClear)")
        if playHush {
            stateMachine.hush(playSound: true)
        } else {
            stateMachine.stop()
        }

        if shouldClear {
            clearQueue()
        }
    }

    // MARK: - CalloutStateMachineDelegate

    func calloutsDidFinish(id: UUID, finished: Bool) {
        GDLogEventProcessorInfo("CALL_OUT_TRACE coordinator calloutsDidFinish id=\(id) finished=\(finished)")
        if let current = currentCallouts, current.id == id {
            GDLogEventProcessorInfo("CALL_OUT_TRACE coordinator notifying delegate completion group=\(id) finished=\(finished)")
            current.delegate?.calloutsCompleted(for: current, finished: finished)
            currentCallouts = nil
        }

        resumeContinuation(for: id, finished: finished)

        if !calloutQueue.isEmpty {
            tryStartCallouts()
        }
    }

    // MARK: - Private helpers

    private func tryStartCallouts() {
        guard currentCallouts == nil else {
            GDLogEventProcessorInfo("CALL_OUT_TRACE coordinator tryStartCallouts skipped state machine busy current=\(String(describing: currentCallouts?.id))")
            return
        }

        guard let nextGroup = nextValidCalloutGroup() else {
            GDLogEventProcessorInfo("CALL_OUT_TRACE coordinator tryStartCallouts found no valid groups")
            return
        }

        currentCallouts = nextGroup

        GDLogEventProcessorInfo("CALL_OUT_TRACE coordinator starting callouts group=\(nextGroup.id) logContext=\(nextGroup.logContext)")
        stateMachine.start(nextGroup)
    }

    private func nextValidCalloutGroup() -> CalloutGroup? {
        while !calloutQueue.isEmpty {
            guard let calloutGroup = calloutQueue.dequeue() else {
                continue
            }

            guard calloutGroup.isValid() else {
                GDLogEventProcessorInfo("Discarding invalid callout group with id: \(calloutGroup.id), context: \(calloutGroup.logContext)")
                calloutGroup.delegate?.calloutsSkipped(for: calloutGroup)
                calloutGroup.onSkip?()
                continue
            }

            return calloutGroup
        }

        return nil
    }

    private func clearQueue() {
        while !calloutQueue.isEmpty {
            guard let group = calloutQueue.dequeue() else {
                continue
            }

            GDLogEventProcessorInfo("CALL_OUT_TRACE coordinator clearing pending group=\(group.id)")
            group.delegate?.calloutsSkipped(for: group)
            group.onSkip?()
        }
    }

    private func registerContinuation(for group: CalloutGroup, continuation: CheckedContinuation<Bool, Never>) {
        let pending = PendingCalloutCompletion(continuation: continuation,
                                               originalCompletion: group.onComplete,
                                               originalSkip: group.onSkip)
        pendingContinuations[group.id] = pending

        group.onComplete = { [weak self] finished in
            pending.originalCompletion?(finished)
            self?.resumeContinuation(for: group.id, finished: finished)
        }

        group.onSkip = { [weak self] in
            pending.originalSkip?()
            self?.resumeContinuation(for: group.id, finished: false)
        }
    }

    private func resumeContinuation(for groupId: UUID, finished: Bool) {
        guard let pending = pendingContinuations.removeValue(forKey: groupId) else {
            return
        }

        pending.continuation.resume(returning: finished)
    }

}
