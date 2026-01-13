//
//  BehaviorEventStreamsTest.swift
//  UnitTests
//

import XCTest
@testable import Soundscape
import CoreLocation

@MainActor
final class BehaviorEventStreamsTest: XCTestCase {

    private final class TestBehavior: BehaviorBase { }

    @MainActor
    private final class SubscribingGenerator: BehaviorEventStreamSubscribing {
        var onUserEvent: (() -> Void)?

        func startEventStreamSubscriptions(userInitiatedEvents: AsyncStream<UserInitiatedEvent>,
                                           stateChangedEvents: AsyncStream<StateChangedEvent>,
                                           delegateProvider: @escaping @MainActor () -> BehaviorDelegate?) -> [Task<Void, Never>] {
            let task = Task { @MainActor in
                for await _ in userInitiatedEvents {
                    onUserEvent?()
                    break
                }
            }

            return [task]
        }
    }

    func testPublishesTypedStreams() async {
        let behavior = TestBehavior()
        behavior.activate(with: nil)

        let userEventReceived = expectation(description: "UserInitiatedEvent received")
        let stateEventReceived = expectation(description: "StateChangedEvent received")

        let userTask = Task { @MainActor in
            for await _ in behavior.userInitiatedEvents {
                userEventReceived.fulfill()
                break
            }
        }

        let stateTask = Task { @MainActor in
            for await event in behavior.stateChangedEvents {
                if event is LocationUpdatedEvent {
                    stateEventReceived.fulfill()
                    break
                }
            }
        }

        await withCheckedContinuation { continuation in
            behavior.handleEvent(BehaviorActivatedEvent()) { _ in
                continuation.resume()
            }
        }

        let location = CLLocation(latitude: 47.6205, longitude: -122.3493)
        await withCheckedContinuation { continuation in
            behavior.handleEvent(LocationUpdatedEvent(location)) { _ in
                continuation.resume()
            }
        }

        await fulfillment(of: [userEventReceived, stateEventReceived], timeout: 1.0)

        userTask.cancel()
        stateTask.cancel()
        _ = behavior.deactivate()
    }

    func testStreamsFinishOnDeactivate() async {
        let behavior = TestBehavior()
        behavior.activate(with: nil)

        let userStream = behavior.userInitiatedEvents
        let stateStream = behavior.stateChangedEvents

        let userStreamFinished = expectation(description: "User stream finished")
        let stateStreamFinished = expectation(description: "State stream finished")

        let userTask = Task { @MainActor in
            for await _ in userStream { }
            userStreamFinished.fulfill()
        }

        let stateTask = Task { @MainActor in
            for await _ in stateStream { }
            stateStreamFinished.fulfill()
        }

        await Task.yield()
        _ = behavior.deactivate()

        await fulfillment(of: [userStreamFinished, stateStreamFinished], timeout: 1.0)
        userTask.cancel()
        stateTask.cancel()
    }

    func testGeneratorSubscriptionReceivesEvents() async {
        let subscribing = SubscribingGenerator()

        // Minimal shim so we can store the subscribing generator in a typed array.
        @MainActor
        final class ManualShim: ManualGenerator, BehaviorEventStreamSubscribing {
            let subscribing: SubscribingGenerator

            init(_ subscribing: SubscribingGenerator) {
                self.subscribing = subscribing
            }

            func respondsTo(_ event: UserInitiatedEvent) -> Bool {
                event is BehaviorActivatedEvent
            }

            func handle(event: UserInitiatedEvent,
                        verbosity: Verbosity,
                        delegate: BehaviorDelegate) async -> [HandledEventAction]? {
                nil
            }

            func startEventStreamSubscriptions(userInitiatedEvents: AsyncStream<UserInitiatedEvent>,
                                               stateChangedEvents: AsyncStream<StateChangedEvent>,
                                               delegateProvider: @escaping @MainActor () -> BehaviorDelegate?) -> [Task<Void, Never>] {
                subscribing.startEventStreamSubscriptions(userInitiatedEvents: userInitiatedEvents,
                                                         stateChangedEvents: stateChangedEvents,
                                                         delegateProvider: delegateProvider)
            }
        }

        final class Hooked: BehaviorBase {
            let shim: ManualShim

            init(shim: ManualShim) {
                self.shim = shim
                super.init()
                manualGenerators = [shim]
            }
        }

        let didReceive = expectation(description: "Subscribing generator received user event")
        subscribing.onUserEvent = { didReceive.fulfill() }

        let hooked = Hooked(shim: ManualShim(subscribing))
        hooked.activate(with: nil)

        await withCheckedContinuation { continuation in
            hooked.handleEvent(BehaviorActivatedEvent()) { _ in
                continuation.resume()
            }
        }

        await fulfillment(of: [didReceive], timeout: 1.0)
        _ = hooked.deactivate()
    }
}
