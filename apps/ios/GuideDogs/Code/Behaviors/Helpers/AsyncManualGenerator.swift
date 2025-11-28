//
//  AsyncManualGenerator.swift
//  Soundscape
//
//  Introduces an async variant of ManualGenerator so behaviors can
//  await callout playback without inlining event handling logic.
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

@MainActor
protocol AsyncManualGenerator: ManualGenerator {
    func handleAsync(event: UserInitiatedEvent,
                     verbosity: Verbosity,
                     delegate: BehaviorDelegate) async -> [HandledEventAction]?
}

extension AsyncManualGenerator {
    func handle(event: UserInitiatedEvent, verbosity: Verbosity) -> HandledEventAction? {
        // Async generators are invoked through handleAsync; synchronous handling
        // is intentionally unsupported.
        return nil
    }
}
