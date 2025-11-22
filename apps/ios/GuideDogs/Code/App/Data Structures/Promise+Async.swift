//  Promise+Async.swift
//  Soundscape
//
//  Added as part of Phase 7 (Player Queue Refactor) to enable
//  bridging existing Promise-based buffer generation APIs to
//  Swift concurrency without rewriting all producers at once.
//
//  This extension allows awaiting the value of a Promise using
//  structured concurrency.

import Foundation

extension Promise {
    /// Await the resolved value of the promise.
    /// If already resolved, returns immediately.
    /// Safe because `then` handles immediate callback if resolved.
    func awaitValue() async -> Value {
        // Fast-path: if already resolved, return synchronously
        if case let .resolved(v) = state {
            return v
        }
        return await withCheckedContinuation { continuation in
            self.then { v in
                continuation.resume(returning: v)
            }
        }
    }
}
