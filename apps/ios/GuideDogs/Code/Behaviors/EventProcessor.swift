//
//  EventProcessor.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation

extension Notification.Name {
    static let behaviorActivated = Notification.Name("GDABehaviorActivated")
    static let behaviorDeactivated = Notification.Name("GDABehaviorDeactivated")
}

@MainActor
class EventProcessor: BehaviorDelegate {
    
    struct Keys {
        static let behavior = "GDABehaviorKey"
    }
    
    private let calloutCoordinator: CalloutCoordinator
    private unowned let audioEngine: AudioEngineProtocol
    private unowned let data: SpatialDataProtocol
    private let eventQueue = EventQueue()
    private var eventLoopTask: Task<Void, Never>?
    private var behaviorStackTop: BehaviorNode
    
    /// Current top level behavior in the behavior stack
    var activeBehavior: Behavior {
        behaviorStackTop.behavior
    }
    
    /// Indicates if there is currently an active behavior running
    var isCustomBehaviorActive: Bool {
        return !(activeBehavior is SoundscapeBehavior)
    }
    
    private var beaconId: String?

    // MARK: Setup and Initialization
    
    init(activeBehavior: Behavior, calloutCoordinator: CalloutCoordinator, audioEngine: AudioEngineProtocol, data: SpatialDataProtocol) {
        self.calloutCoordinator = calloutCoordinator
        self.audioEngine = audioEngine
        self.data = data
        self.behaviorStackTop = BehaviorNode(behavior: activeBehavior, parent: nil)
        
        // Setup the delegate for the base openscape behavior
        self.behaviorStackTop.behavior.delegate = self

        startEventLoop()
    }

    deinit {
        eventLoopTask?.cancel()
        let queue = eventQueue
        let behaviorNode = behaviorStackTop
        Task { @MainActor in
            queue.finish()
            behaviorNode.finishChain()
        }
    }
    
    /// Starts the event processor by activating the default openscape behavior. This method
    /// should be called after the audio engine is started so that any callouts that are
    /// generated can be played
    func start() {
        guard !activeBehavior.isActive else {
            return
        }
        
        // Activate the default root behavior
        activeBehavior.activate(with: nil)
    }
    
    /// Activates a custom behavior
    ///
    /// - Parameter behavior: The custom behavior to activate
    func activateCustom(behavior: Behavior) {
        // For the time being, only allow one behavior to be layered
        // on top of the default behavior
        if isCustomBehaviorActive {
            deactivateCustom()
        }
        
        GDLogEventProcessorInfo("Activating the \(behavior) behavior")

        let parentNode = behaviorStackTop
        let parentBehavior = parentNode.behavior
        behaviorStackTop = BehaviorNode(behavior: behavior, parent: parentNode)

        behavior.delegate = self
        behavior.activate(with: parentBehavior)
        
        NotificationCenter.default.post(name: Notification.Name.behaviorActivated, object: self, userInfo: [Keys.behavior: behavior])
        
        // Process an event for indicating that the behavior has started
        process(BehaviorActivatedEvent())
        
        // Make sure the new behavior has the current location... (only really matters in GPX simulation)
        if let location = AppContext.shared.geolocationManager.location {
            process(LocationUpdatedEvent(location))
        }
    }
    
    /// If there is currently an active behavior, calling this method will save it's state
    /// and turn off the behavior (setting the active behavior to nil and releasing it's memory).
    func deactivateCustom() {
        guard isCustomBehaviorActive else {
            return
        }
        
        GDLogEventProcessorInfo("Deactivating the \(activeBehavior) behavior")
        
        // Let the active behavior know it is about to be deactivated so it can handle any necessary state clean-up
        activeBehavior.willDeactivate()
        
        // Give the behavior a chance to respond to the fact that it is being deactivated...
        let event = BehaviorDeactivatedEvent { [weak self] _ in
            self?.finishDeactivatingCustom()
        }
        
        if activeBehavior.manualGenerators.contains(where: { $0.respondsTo(event) }) {
            process(event)
        } else {
            finishDeactivatingCustom()
        }
    }
    
    private func finishDeactivatingCustom() {
        guard isCustomBehaviorActive else {
            return
        }

        let currentNode = behaviorStackTop
        guard let parentBehavior = currentNode.behavior.deactivate() else {
            return
        }

        currentNode.finish()
        guard let parentNode = currentNode.parent else {
            GDLogEventProcessorError("Missing parent node during behavior deactivation")
            return
        }

        assert(parentNode.behavior === parentBehavior, "Behavior stack parent mismatch during deactivation")
        behaviorStackTop = parentNode
        
        calloutCoordinator.interruptCurrent(clearQueue: true, playHush: true)
        
        NotificationCenter.default.post(name: Notification.Name.behaviorDeactivated, object: self)
    }
    
    func sleep() {
        var behavior: Behavior? = activeBehavior
        
        while behavior != nil {
            behavior?.sleep()
            behavior = behavior?.parent
        }
        
        hush(playSound: false)
    }
    
    func wake() {
        var behavior: Behavior? = activeBehavior
        
        while behavior != nil {
            behavior?.wake()
            behavior = behavior?.parent
        }
        
        process(GlyphEvent(.appLaunch))
    }
    
    func isActive<T: Behavior>(behavior: T.Type) -> Bool {
        return activeBehavior is T
    }
    
    // MARK: Event Processing
    
    /// Handles an event by passing it to the active behavior (or the default behavior if
    /// no custom behavior is active)
    ///
    /// - Parameter event: The event to process
    func process(_ event: Event) {
        eventQueue.enqueue(event)
    }

    private func startEventLoop() {
        eventLoopTask = Task { [weak self] in
            await self?.runEventLoop()
        }
    }

    @MainActor
    private func runEventLoop() async {
        for await event in eventQueue.stream {
            await handleEventFromQueue(event)
        }
    }

    @MainActor
    private func handleEventFromQueue(_ event: Event) async {
        log(event)

        guard let actions = await performBehaviorHandle(event) else {
            return
        }

        handle(actions, for: event)
    }

    private func log(_ event: Event) {
        switch event {
        case let locEvent as LocationUpdatedEvent:
            GDLogEventProcessorInfo("Processing \(event.name): \(locEvent.location)")
        default:
            GDLogEventProcessorInfo("Processing \(event.name)")
        }
    }

    private func performBehaviorHandle(_ event: Event) async -> [HandledEventAction]? {
        await behaviorStackTop.dispatch(event)
    }

    private func handle(_ actions: [HandledEventAction], for event: Event) {
        if let hushRequest = actions.compactMap({ action -> (playHush: Bool, clearPending: Bool)? in
            if case let .interruptAndClearQueue(playHush, clearPending) = action {
                GDLogEventProcessorInfo("CALL_OUT_TRACE interrupt action received playHush=\(playHush) clearPending=\(clearPending) for event \(event.name)")
                return (playHush, clearPending)
            }
            return nil
        }).first {
            interruptCurrent(clearQueue: hushRequest.clearPending, playHush: hushRequest.playHush)
            return
        }

        for case let .playCallouts(calloutGroup) in actions {
            enqueue(calloutGroup)
        }

        for case let .processEvents(events) in actions {
            for event in events {
                process(event)
            }
        }
    }
    
    
    // MARK: Callout Queueing
    
    /// Helper method for enqueueing multiple `CalloutGroup` objects at once. The value
    /// the enqueue style of the first `CalloutGroup` in the array is maintained as specified,
    /// but all remaining items in the array will be enqueued with the `.enqueue`
    /// style.
    ///
    /// - Parameters:
    ///   - callouts: `CalloutGroup` objects to enqueue
    private func enqueue(_ callouts: [CalloutGroup]) {
        // Enqueue the first group with the specified style
        guard callouts.count > 0 else {
            GDLogWarn(.eventProcessor, "Attempted to enqueue and enmpty group of callouts!")
            return
        }
        
        // Override the enqueue style of all callouts except the first to be .enqueue
        callouts.dropFirst().forEach({ $0.action = .enqueue })
        
        // Enqueue all the callouts
        callouts.forEach({ enqueue($0) })
    }
    
    private func enqueue(_ callouts: CalloutGroup, continuation: CheckedContinuation<Bool, Never>? = nil) {
        GDLogEventProcessorInfo("CALL_OUT_TRACE enqueue group=\(callouts.id) action=\(callouts.action) hushOnInterrupt=\(callouts.playHushOnInterrupt)")
        
        switch callouts.action {
        case .interruptAndClear:
            if calloutCoordinator.hasActiveCallouts {
                interruptCurrent(clearQueue: true, playHush: callouts.playHushOnInterrupt)
            } else if calloutCoordinator.hasPendingCallouts {
                calloutCoordinator.clearPending()
            }
            
        case .clear:
            calloutCoordinator.clearPending()
            
        default:
            break
        }
        
        if let continuation {
            calloutCoordinator.enqueue(callouts, continuation: continuation)
        } else {
            calloutCoordinator.enqueue(callouts)
        }
    }

    func playCallouts(_ group: CalloutGroup) async -> Bool {
        await withCheckedContinuation { continuation in
            enqueue(group, continuation: continuation)
        }
    }

    // MARK: - General Controls
    
    func interruptCurrent(clearQueue clear: Bool = true, playHush: Bool = false) {
        GDLogEventProcessorInfo("CALL_OUT_TRACE interruptCurrent playHush=\(playHush) clearQueue=\(clear)")
        
        calloutCoordinator.interruptCurrent(clearQueue: clear, playHush: playHush)
    }
    
    func hush(playSound: Bool = true, hushBeacon: Bool = true) {
        GDLogInfo(.eventProcessor, "Hushing event processor")
        
        if hushBeacon, data.destinationManager.isAudioEnabled, activeBehavior is SoundscapeBehavior {
            if !data.destinationManager.toggleDestinationAudio(automatic: false) {
                GDLogError(.eventProcessor, "Unable to hush destination audio - hush command")
            }
        }
        
        GDLogEventProcessorInfo("CALL_OUT_TRACE hush invoked playSound=\(playSound) hushBeacon=\(hushBeacon)")
        interruptCurrent(playHush: playSound)
    }
    
    @discardableResult
    func toggleAudio() -> Bool {
        let isDiscreteAudioPlaying = audioEngine.isDiscreteAudioPlaying
        let isBeaconPlaying = data.destinationManager.isAudioEnabled
        let isDestinationSet = data.destinationManager.destinationKey != nil
        
        // Check if there is anything to toggle
        guard isDiscreteAudioPlaying || isDestinationSet || isBeaconPlaying else {
            return false
        }
        
        // Toggle beacon if needed
        // If audio is playing but the beacon is muted, we mute the audio and DO NOT un-mute the beacon
        if isDestinationSet && !(isDiscreteAudioPlaying && !isBeaconPlaying) {
            data.destinationManager.toggleDestinationAudio(automatic: false)
            
            // If audio was playing, the command processor's `hush` method will output the effect sound
            // If not, we force the hush effect sound when unmuting the beacon
            if isBeaconPlaying && !isDiscreteAudioPlaying {
                process(GlyphEvent(.hush))
            }
        }
        
        // Hush callouts if needed
        if isDiscreteAudioPlaying {
            guard !AppContext.shared.eventProcessor.isCustomBehaviorActive else {
                interruptCurrent(clearQueue: true, playHush: true)
                return true
            }
            
            interruptCurrent(playHush: true)
        }
        
        return true
    }
}

// MARK: - EventQueue

@MainActor
private final class EventQueue {
    private var continuation: AsyncStream<Event>.Continuation?
    private var buffer: [Event] = []

    lazy var stream: AsyncStream<Event> = AsyncStream(Event.self, bufferingPolicy: .unbounded) { continuation in
        self.continuation = continuation

        if !self.buffer.isEmpty {
            self.buffer.forEach { continuation.yield($0) }
            self.buffer.removeAll()
        }

        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in
                self?.continuation = nil
            }
        }
    }

    func enqueue(_ event: Event) {
        if let continuation {
            continuation.yield(event)
        } else {
            buffer.append(event)
        }
    }

    func finish() {
        continuation?.finish()
        continuation = nil
        buffer.removeAll()
    }
}

// MARK: - Behavior Dispatchers

@MainActor
private final class BehaviorNode {
    let behavior: Behavior
    fileprivate let dispatcher: BehaviorEventDispatcher
    let parent: BehaviorNode?
    
    init(behavior: Behavior, parent: BehaviorNode?) {
        self.behavior = behavior
        self.parent = parent
        self.dispatcher = BehaviorEventDispatcher(behavior: behavior, parentDispatcher: parent?.dispatcher)
    }
    
    func dispatch(_ event: Event) async -> [HandledEventAction]? {
        await dispatcher.dispatch(event)
    }
    
    func finish() {
        dispatcher.finish()
    }
    
    func finishChain() {
        dispatcher.finish()
        parent?.finishChain()
    }
}

@MainActor
private final class BehaviorEventDispatcher {
    private struct Request {
        let event: Event
        let blockedAuto: [AutomaticGenerator.Type]
        let blockedManual: [ManualGenerator.Type]
        let completion: ([HandledEventAction]?) -> Void
    }
    
    private let behavior: Behavior
    private var continuation: AsyncStream<Request>.Continuation?
    private var buffer: [Request] = []
    private lazy var stream: AsyncStream<Request> = makeStream()
    private var task: Task<Void, Never>?
    
    init(behavior: Behavior, parentDispatcher: BehaviorEventDispatcher?) {
        self.behavior = behavior
        
        if let base = behavior as? BehaviorBase {
            base.setParentEventForwarder(parentDispatcher?.makeForwarder())
        }
        
        task = Task { @MainActor in
            for await request in stream {
                await self.process(request)
            }
        }
    }
    
    func dispatch(_ event: Event) async -> [HandledEventAction]? {
        await withCheckedContinuation { continuation in
            forward(event: event, blockedAuto: [], blockedManual: []) { actions in
                continuation.resume(returning: actions)
            }
        }
    }
    
    func forward(event: Event,
                 blockedAuto: [AutomaticGenerator.Type],
                 blockedManual: [ManualGenerator.Type],
                 completion: @escaping ([HandledEventAction]?) -> Void) {
        let request = Request(event: event, blockedAuto: blockedAuto, blockedManual: blockedManual, completion: completion)
        if let continuation {
            continuation.yield(request)
        } else {
            buffer.append(request)
        }
    }
    
    fileprivate func makeForwarder() -> BehaviorEventForwarder {
        { [weak self] event, blockedAuto, blockedManual, completion in
            guard let self else {
                completion(nil)
                return
            }
            
            self.forward(event: event, blockedAuto: blockedAuto, blockedManual: blockedManual, completion: completion)
        }
    }
    
    func finish() {
        task?.cancel()
        continuation?.finish()
        continuation = nil
        buffer.removeAll()
        
        if let base = behavior as? BehaviorBase {
            base.setParentEventForwarder(nil)
        }
    }
    
    private func process(_ request: Request) async {
        await withCheckedContinuation { continuation in
            behavior.handleEvent(request.event, blockedAuto: request.blockedAuto, blockedManual: request.blockedManual) { actions in
                request.completion(actions)
                continuation.resume()
            }
        }
    }
    
    private func makeStream() -> AsyncStream<Request> {
        AsyncStream(Request.self, bufferingPolicy: .unbounded) { continuation in
            self.continuation = continuation
            
            if !self.buffer.isEmpty {
                self.buffer.forEach { continuation.yield($0) }
                self.buffer.removeAll()
            }
            
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.continuation = nil
                }
            }
        }
    }
}
