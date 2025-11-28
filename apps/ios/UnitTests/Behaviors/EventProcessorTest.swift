//
//  EventProcessorTest.swift
//  UnitTests
//
//  Created for Soundscape concurrency migration.
//

import XCTest
@testable import Soundscape
import CoreLocation
import AVFAudio
import Combine

@MainActor
final class EventProcessorTest: XCTestCase {
    
    var eventProcessor: EventProcessor?
    var mockAudioEngine: MockAudioEngine?
    var mockData: MockSpatialData?
    var mockBehavior: MockBehavior?
    var calloutCoordinator: CalloutCoordinator?
    
    override func setUp() {
        super.setUp()
        
        // Create mock dependencies
        mockAudioEngine = MockAudioEngine()
        mockData = MockSpatialData()
        let mockGeo = MockGeolocationManager()
        let mockMotion = MockMotionActivity()
        calloutCoordinator = CalloutCoordinator(
            audioEngine: mockAudioEngine!,
            geo: mockGeo,
            motionActivityContext: mockMotion,
            history: CalloutHistory()
        )
        mockBehavior = MockBehavior()
        
        // Create event processor
        eventProcessor = EventProcessor(
            activeBehavior: mockBehavior!,
            calloutCoordinator: calloutCoordinator!,
            audioEngine: mockAudioEngine!,
            data: mockData!
        )
    }
    
    override func tearDown() {
        eventProcessor = nil
        mockAudioEngine = nil
        mockData = nil
        mockBehavior = nil
        calloutCoordinator = nil
        super.tearDown()
    }
    
    /// Test that EventProcessor initializes with correct state
    func testInit() throws {
        let processor = eventProcessor!
        
        XCTAssertNotNil(processor.activeBehavior)
        // MockBehavior is not a SoundscapeBehavior, so it's considered custom
        XCTAssertTrue(processor.isCustomBehaviorActive)
    }
    
    /// Test starting the default behavior
    func testStart() throws {
        let processor = eventProcessor!
        let behavior = mockBehavior!
        
        XCTAssertFalse(behavior.isActive)
        
        processor.start()
        
        XCTAssertTrue(behavior.isActive)
    }
    
    /// Test activating a custom behavior
    func testActivateCustomBehavior() throws {
        let processor = eventProcessor!
        
        // Start with default behavior (which is MockBehavior, so already custom)
        processor.start()
        XCTAssertTrue(processor.isCustomBehaviorActive)
        
        // Activate another custom behavior
        let customBehavior = MockBehavior()
        processor.activateCustom(behavior: customBehavior)
        
        XCTAssertTrue(processor.isCustomBehaviorActive)
        XCTAssertTrue(customBehavior.isActive)
        XCTAssertTrue(customBehavior.parent === mockBehavior)
    }
    
    /// Test deactivating a custom behavior
    func testDeactivateCustomBehavior() throws {
        let processor = eventProcessor!
        
        // Start and activate custom
        processor.start()
        let customBehavior = MockBehavior()
        processor.activateCustom(behavior: customBehavior)
        
        XCTAssertTrue(processor.isCustomBehaviorActive)
        XCTAssertTrue(customBehavior.isActive)
        XCTAssertTrue(customBehavior.parent === mockBehavior)
        
        // Deactivate - should return to parent (mockBehavior)
        processor.deactivateCustom()
        
        // After deactivation, active behavior is mockBehavior
        XCTAssertTrue(processor.activeBehavior === mockBehavior)
        XCTAssertFalse(customBehavior.isActive)
        // Note: mockBehavior is deactivated during activation of customBehavior
        // and not reactivated during deactivation, so isActive remains false
        XCTAssertFalse(mockBehavior!.isActive)
    }
    
    /// Test that sleep/wake work correctly
    func testSleepWake() throws {
        let processor = eventProcessor!
        let behavior = mockBehavior!
        
        processor.start()
        XCTAssertTrue(behavior.isActive)
        
        processor.sleep()
        XCTAssertFalse(behavior.isActive)
        
        processor.wake()
        XCTAssertTrue(behavior.isActive)
    }
    
    func testProcessDispatchesEventsViaQueue() {
        let processExpectation = expectation(description: "Event delivered to behavior")
        mockBehavior?.handleEventHandler = { event, completion in
            if event is BehaviorActivatedEvent {
                processExpectation.fulfill()
            }
            completion(nil)
        }
        
        eventProcessor?.process(BehaviorActivatedEvent())
        wait(for: [processExpectation], timeout: 1.0)
    }

    func testEventsProcessSequentiallyPerBehavior() {
        let firstEventHandled = expectation(description: "First event handled")
        let secondEventHandled = expectation(description: "Second event handled after first completes")
        var firstCompletion: (([HandledEventAction]?) -> Void)?
        var secondEventTriggered = false
        
        mockBehavior?.handleEventHandler = { event, completion in
            if firstCompletion == nil {
                firstCompletion = completion
                firstEventHandled.fulfill()
            } else {
                secondEventTriggered = true
                completion(nil)
                secondEventHandled.fulfill()
            }
        }
        
        eventProcessor?.process(BehaviorActivatedEvent())
        eventProcessor?.process(BehaviorActivatedEvent())
        
        wait(for: [firstEventHandled], timeout: 1.0)
        XCTAssertFalse(secondEventTriggered, "Second event should wait until the first completion runs")
        XCTAssertNotNil(firstCompletion)
        
        firstCompletion?(nil)
        wait(for: [secondEventHandled], timeout: 1.0)
    }
}

// MARK: - Mock Classes

@MainActor
class MockBehavior: Behavior {
    var id: UUID = UUID()
    var isActive: Bool = false
    var verbosity: Verbosity = .normal
    var userLocation: CLLocation?
    var delegate: BehaviorDelegate?
    var parent: Behavior?
    var manualGenerators: [ManualGenerator] = []
    var autoGenerators: [AutomaticGenerator] = []
    var blockedAutoGenerators: [AutomaticGenerator.Type] = []
    var blockedManualGenerators: [ManualGenerator.Type] = []
    var description: String = "MockBehavior"
    
    func activate(with parent: Behavior?) {
        self.parent = parent
        isActive = true
    }
    
    func deactivate() -> Behavior? {
        isActive = false
        return parent
    }
    
    func sleep() {
        isActive = false
    }
    
    func wake() {
        isActive = true
    }
    
    func willDeactivate() {
        // Mock implementation
    }
    
    func addBlocked(auto gen: AutomaticGenerator.Type) {}
    func removeBlocked(auto gen: AutomaticGenerator.Type) {}
    func addBlocked(manual gen: ManualGenerator.Type) {}
    func removeBlocked(manual gen: ManualGenerator.Type) {}
    
    var handleEventHandler: ((Event, @escaping ([HandledEventAction]?) -> Void) -> Void)?
    
    func handleEvent(_ event: Event, blockedAuto: [AutomaticGenerator.Type], blockedManual: [ManualGenerator.Type], completion: @escaping ([HandledEventAction]?) -> Void) {
        if let handleEventHandler {
            handleEventHandler(event, completion)
        } else {
            completion(nil)
        }
    }
}

@MainActor
class MockAudioEngine: AudioEngineProtocol {
    var session: AVAudioSession = AVAudioSession.sharedInstance()
    var outputType: String = "Mock"
    var delegate: AudioEngineDelegate?
    var isRecording: Bool = false
    var isDiscreteAudioPlaying: Bool = false
    var isInMonoMode: Bool = false
    var mixWithOthers: Bool = false
    
    static var recordingDirectory: URL? { nil }
    
    func start(isRestarting: Bool, activateAudioSession: Bool) {}
    func stop() {}
    func play<T: DynamicSound>(_ sound: T, heading: Heading?) -> AudioPlayerIdentifier? { nil }
    func play(_ sound: SynchronouslyGeneratedSound) -> AudioPlayerIdentifier? { nil }
    func play(looped: SynchronouslyGeneratedSound) -> AudioPlayerIdentifier? { nil }
    func play(_ sound: Sound, completion callback: CompletionCallback?) { callback?(true) }
    func play(_ sounds: Sounds, completion callback: CompletionCallback?) { callback?(true) }
    func finish(dynamicPlayerId: AudioPlayerIdentifier) {}
    func stop(_ id: AudioPlayerIdentifier) {}
    func stopDiscrete(with: Sound?) {}
    func updateUserLocation(_ location: CLLocation) {}
    func startRecording() {}
    func stopRecording() {}
    func enableSpeakerMode(_ handler: ((AVAudioSession.PortOverride) -> Void)?) {}
    func disableSpeakerMode(_ handler: ((AVAudioSession.PortOverride) -> Void)?) {}
}

@MainActor
class MockSpatialData: SpatialDataProtocol {
    static var zoomLevel: UInt = 16
    static var cacheDistance: CLLocationDistance = 1000
    static var initialPOISearchDistance: CLLocationDistance = 200
    static var expansionPOISearchDistance: CLLocationDistance = 200
    static var refreshTimeInterval: TimeInterval = 5.0
    static var refreshDistanceInterval: CLLocationDistance = 5.0
    
    var motionActivityContext: MotionActivityProtocol = MockMotionActivity()
    var destinationManager: DestinationManagerProtocol = MockDestinationManager()
    var state: SpatialDataState = .ready
    var loadedSpatialData: Bool = false
    var currentTiles: [VectorTile] = []
    
    func start() {}
    func stop() {}
    func clearCache() -> Bool { false }
    func getDataView(for location: CLLocation, searchDistance: CLLocationDistance) -> SpatialDataViewProtocol? { nil }
    func getCurrentDataView(searchDistance: CLLocationDistance) -> SpatialDataViewProtocol? { nil }
    func getCurrentDataView(initialSearchDistance: CLLocationDistance, shouldExpandDataView: @escaping (SpatialDataViewProtocol) -> Bool) -> SpatialDataViewProtocol? { nil }
    func updateSpatialData(at location: CLLocation, completion: @escaping () -> Void) -> Progress? { nil }
    func clear(updateCache: Bool) {}
    func fetch(location: CLLocation, clearUpdatedEntities: Bool) {}
    func fetch(location: CLLocation, completion: @escaping (_ tiles: Int, _ pois: Int) -> Void) {}
    func pois(for location: CLLocation, searchDistance: CLLocationDistance) -> [POI] { [] }
    func roads(for location: CLLocation, useClosestRoad: Bool) -> [Road] { [] }
    func spatialDataView(for location: CLLocation, searchDistance: CLLocationDistance) -> SpatialDataViewProtocol? { nil }
}

@MainActor
class MockDestinationManager: DestinationManagerProtocol {
    var destinationKey: String?
    var isDestinationSet: Bool = false
    var destination: ReferenceEntity?
    var isAudioEnabled: Bool = false
    var isBeaconInBounds: Bool = false
    var isCurrentBeaconAsyncFinishable: Bool = false
    var beaconPlayerId: AudioPlayerIdentifier?
    var proximityBeaconPlayerId: AudioPlayerIdentifier?
    
    func isUserWithinGeofence(_ userLocation: CLLocation) -> Bool { false }
    func isDestination(key: String) -> Bool { false }
    func setDestination(referenceID: String, enableAudio: Bool, userLocation: CLLocation?, logContext: String?) throws {}
    func setDestination(location: CLLocation, address: String?, enableAudio: Bool, userLocation: CLLocation?, logContext: String?) throws -> String { "" }
    func setDestination(location: GenericLocation, address: String?, enableAudio: Bool, userLocation: CLLocation?, logContext: String?) throws -> String { "" }
    func setDestination(entityKey: String, enableAudio: Bool, userLocation: CLLocation?, estimatedAddress: String?, logContext: String?) throws -> String { "" }
    func setDestination(location: CLLocation, behavior: String, enableAudio: Bool, userLocation: CLLocation?, logContext: String?) throws -> String { "" }
    func clearDestination(logContext: String?) throws {}
    func toggleDestinationAudio(_ sendNotfication: Bool, automatic: Bool, forceMelody: Bool) -> Bool { false }
    func updateDestinationLocation(_ newLocation: CLLocation, userLocation: CLLocation) -> Bool { false }
}

@MainActor
class MockGeolocationManager: GeolocationManagerProtocol {
    var isActive: Bool = false
    var coreLocationServicesEnabled: Bool = true
    var coreLocationAuthorizationStatus: CoreLocationAuthorizationStatus = .fullAccuracyLocationAuthorized
    var updateDelegate: GeolocationManagerUpdateDelegate?
    var location: CLLocation?
    var collectionHeading: Heading = Heading(orderedBy: [.user], course: nil, deviceHeading: nil, userHeading: nil)
    var presentationHeading: Heading = Heading(orderedBy: [.user], course: nil, deviceHeading: nil, userHeading: nil)
    
    func heading(orderedBy types: [HeadingType]) -> Heading { Heading(orderedBy: types, course: nil, deviceHeading: nil, userHeading: nil) }
    func start() {}
    func stop() {}
    func snooze() {}
    func add(_ provider: LocationProvider) {}
    func remove(_ provider: LocationProvider) {}
    func add(_ provider: CourseProvider) {}
    func remove(_ provider: CourseProvider) {}
    func add(_ provider: UserHeadingProvider) {}
    func remove(_ provider: UserHeadingProvider) {}
}

@MainActor
class MockMotionActivity: MotionActivityProtocol {
    var isWalking: Bool { false }
    var isInVehicle: Bool { false }
    var currentActivity: ActivityType { .stationary }
    
    func startActivityUpdates() {}
    func stopActivityUpdates() {}
}
