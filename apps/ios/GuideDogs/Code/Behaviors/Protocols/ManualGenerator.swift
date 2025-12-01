//
//  ManualGenerator.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

@MainActor
protocol ManualGenerator {
    func respondsTo(_ event: UserInitiatedEvent) -> Bool

    func handle(event: UserInitiatedEvent,
                verbosity: Verbosity,
                delegate: BehaviorDelegate) async -> [HandledEventAction]?
}
