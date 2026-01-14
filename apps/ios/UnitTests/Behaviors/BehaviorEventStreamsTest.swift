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

    func testBroadcastStateEventsDeliveredToAllAutoSubscribers() async {
        @MainActor
        final class AutoSubscribingGenerator: AutomaticGenerator, BehaviorEventStreamSubscribing {
            var onGPXSimulationStarted: (() -> Void)?

            let canInterrupt: Bool = false

            func respondsTo(_ event: StateChangedEvent) -> Bool {
                event is GPXSimulationStartedEvent
            }

            func handle(event: StateChangedEvent, verbosity: Verbosity) -> HandledEventAction? {
                // No callout action; state is handled by the subscription.
                .noAction
            }

            func cancelCalloutsForEntity(id: String) {
                // No-op for this test.
            }

            func startEventStreamSubscriptions(userInitiatedEvents: AsyncStream<UserInitiatedEvent>,
                                               stateChangedEvents: AsyncStream<StateChangedEvent>,
                                               delegateProvider: @escaping @MainActor () -> BehaviorDelegate?) -> [Task<Void, Never>] {
                let task = Task { @MainActor in
                    for await event in stateChangedEvents {
                        if event is GPXSimulationStartedEvent {
                            onGPXSimulationStarted?()
                            break
                        }
                    }
                }

                return [task]
            }
        }

        final class Hooked: BehaviorBase {
            init(generators: [AutomaticGenerator]) {
                super.init()
                autoGenerators = generators
            }
        }

        let gen1 = AutoSubscribingGenerator()
        let gen2 = AutoSubscribingGenerator()

        let received1 = expectation(description: "Subscriber 1 received GPXSimulationStartedEvent")
        let received2 = expectation(description: "Subscriber 2 received GPXSimulationStartedEvent")

        gen1.onGPXSimulationStarted = { received1.fulfill() }
        gen2.onGPXSimulationStarted = { received2.fulfill() }

        let hooked = Hooked(generators: [gen1, gen2])
        hooked.activate(with: nil)

        await withCheckedContinuation { continuation in
            hooked.handleEvent(GPXSimulationStartedEvent()) { _ in
                continuation.resume()
            }
        }

        await fulfillment(of: [received1, received2], timeout: 1.0)
        _ = hooked.deactivate()
    }

    func testConsumedStateEventsDeliveredToFirstAutoSubscriber() async {
        @MainActor
        final class ConsumedTestEvent: StateChangedEvent { }

        @MainActor
        final class AutoConsumingGenerator: AutomaticGenerator, BehaviorEventStreamSubscribing {
            var onEvent: (() -> Void)?

            let canInterrupt: Bool = false

            func respondsTo(_ event: StateChangedEvent) -> Bool {
                event is ConsumedTestEvent
            }

            func handle(event: StateChangedEvent, verbosity: Verbosity) -> HandledEventAction? {
                nil
            }

            func cancelCalloutsForEntity(id: String) {
                // No-op for this test.
            }

            func startEventStreamSubscriptions(userInitiatedEvents: AsyncStream<UserInitiatedEvent>,
                                               stateChangedEvents: AsyncStream<StateChangedEvent>,
                                               delegateProvider: @escaping @MainActor () -> BehaviorDelegate?) -> [Task<Void, Never>] {
                let task = Task { @MainActor in
                    for await event in stateChangedEvents {
                        if event is ConsumedTestEvent {
                            onEvent?()
                        }
                    }
                }

                return [task]
            }
        }

        final class Hooked: BehaviorBase {
            init(generators: [AutomaticGenerator]) {
                super.init()
                autoGenerators = generators
            }
        }

        let gen1 = AutoConsumingGenerator()
        let gen2 = AutoConsumingGenerator()

        let received1 = expectation(description: "Subscriber 1 received consumed event")
        let notReceived2 = expectation(description: "Subscriber 2 should not receive consumed event")
        notReceived2.isInverted = true

        gen1.onEvent = { received1.fulfill() }
        gen2.onEvent = { notReceived2.fulfill() }

        let hooked = Hooked(generators: [gen1, gen2])
        hooked.activate(with: nil)

        await withCheckedContinuation { continuation in
            hooked.handleEvent(ConsumedTestEvent()) { _ in
                continuation.resume()
            }
        }

        await fulfillment(of: [received1, notReceived2], timeout: 0.5)
        _ = hooked.deactivate()
    }
}
