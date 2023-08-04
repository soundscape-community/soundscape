//
//  RouteGuidanceTest.swift
//  UnitTests
//
//  Created by Kai on 7/21/23.
//  Copyright © 2023 Microsoft. All rights reserved.
//

import XCTest
import CoreLocation
@testable import Soundscape

// Note that while these mocked systems allow for some testing, they still cover a limited number of cases, since some would require that more complex systems be mocked.


class RouteGuidanceTest: XCTestCase {
    class TestMotionActivity: MotionActivityProtocol {
        var isWalking: Bool = true
        var isInVehicle: Bool = false
        var currentActivity: ActivityType = .walking
        func startActivityUpdates() { }
        func stopActivityUpdates() { }
    }
    class TestSpatialData: SpatialDataProtocol {
        static var zoomLevel: UInt = SpatialDataContext.zoomLevel
        static var cacheDistance: CLLocationDistance = SpatialDataContext.cacheDistance
        static var initialPOISearchDistance: CLLocationDistance = SpatialDataContext.initialPOISearchDistance
        static var expansionPOISearchDistance: CLLocationDistance = SpatialDataContext.expansionPOISearchDistance
        static var refreshTimeInterval: TimeInterval = SpatialDataContext.refreshTimeInterval
        static var refreshDistanceInterval: CLLocationDistance = SpatialDataContext.refreshDistanceInterval
        
        var motionActivityContext: MotionActivityProtocol
        var destinationManager: DestinationManagerProtocol
        var state: SpatialDataState = SpatialDataState.waitingForLocation
        var loadedSpatialData: Bool = false
        var currentTiles: [VectorTile] = []
        
        init(_ motionActivity: MotionActivityProtocol, _ destination: DestinationManagerProtocol) {
            motionActivityContext = motionActivity
            destinationManager = destination
        }
        
        func start() { }
        func stop() { }
        func clearCache() -> Bool {
            false
        }
        
        func getDataView(for location: CLLocation, searchDistance: CLLocationDistance) -> SpatialDataViewProtocol? {
            nil
        }
        func getCurrentDataView(searchDistance: CLLocationDistance) -> SpatialDataViewProtocol? {
            nil
        }
        func getCurrentDataView(initialSearchDistance: CLLocationDistance, shouldExpandDataView: @escaping (SpatialDataViewProtocol) -> Bool) -> SpatialDataViewProtocol? {
            nil
        }
        
        func updateSpatialData(at location: CLLocation, completion: @escaping () -> Void) -> Progress? {
            nil
        }
    }
    
    // ----
    
    let motion = TestMotionActivity()
    let destinationM = DestinationManager(userLocation: nil, audioEngine: AudioEngine(envSettings: TestAudioEnvironmentSettings(), mixWithOthers: true), collectionHeading: Heading(orderedBy: [], course: nil, deviceHeading: nil, userHeading: nil, geolocationManager: nil))
    var spatial: TestSpatialData!
    static let loc0_0 = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    static let availableInterval = DateInterval(start: Date(timeIntervalSinceNow: TimeInterval(0)), end: Date(timeIntervalSinceNow: TimeInterval(99999999)))
    static func activity_single_waypoint() -> AuthoredActivityContent {
        AuthoredActivityContent(id: "test1234", type: .guidedTour, name: "test1234", creator: "soundscape_unit_tests", locale: .enUS, availability: availableInterval, expires: false, image: nil, desc: "test description", waypoints: [ActivityWaypoint(coordinate: loc0_0)], pois: [])
    }
    static func activity_random_waypoints(count: Int) -> AuthoredActivityContent {
        var points: [ActivityWaypoint] = []
        for _ in 0..<count {
            points.append(ActivityWaypoint(coordinate: CLLocationCoordinate2D(latitude: Double.random(in: -90...90), longitude: Double.random(in: -90...90))))
        }
        return AuthoredActivityContent(id: "test5678", type: .guidedTour, name: "test5678", creator: "soundscape_unit_tests", locale: .enUS, availability: availableInterval, expires: false, image: nil, desc: "test description", waypoints: points, pois: [])
    }

    override func setUpWithError() throws {
        spatial = TestSpatialData(motion, destinationM)
        // let a = AuthoredActivityContent(id: "test1234", type: .guidedTour, name: "test1234", creator: "soundscape_unit_tests", locale: .enUS, availability: RouteGuidanceTest.availableInterval, expires: false, image: nil, desc: "test description", waypoints: [ActivityWaypoint(coordinate: RouteGuidanceTest.loc0_0)], pois: [ActivityPOI(coordinate: RouteGuidanceTest.loc0_0, name: "point1", description: "point1description")])
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSinglePointInitialState() throws {
        let route = RouteGuidance(RouteGuidanceTest.activity_single_waypoint(), spatialData: spatial, motion: motion)
        route.activate(with: nil)
        XCTAssertNotNil(route.currentWaypoint)
        let currentWaypoint = route.currentWaypoint!
        XCTAssertEqual(currentWaypoint.index, 0)
        let loc_cw = currentWaypoint.waypoint.location.coordinate
        XCTAssertEqual(loc_cw.latitude, 0)
        XCTAssertEqual(loc_cw.longitude, 0)
        
        let routeProgress = route.progress
        XCTAssertNotNil(routeProgress.currentWaypoint)
        XCTAssertEqual(routeProgress.currentWaypoint!.index, currentWaypoint.index)
        let loc_rp = currentWaypoint.waypoint.location.coordinate
        XCTAssertEqual(loc_cw.latitude, loc_rp.latitude)
        XCTAssertEqual(loc_cw.longitude, loc_rp.longitude)
        XCTAssertEqual(routeProgress.completed, 0)
        XCTAssertEqual(routeProgress.remaining, 1) // calculated
        XCTAssertFalse(routeProgress.isDone)
        XCTAssertEqual(routeProgress.total, 1)
        XCTAssertEqual(routeProgress.percentComplete, 0) // calculated
        
        // Because we created using the AuthoredActivityContent constructor for RouteGuidance, it always has the trailActivity type, which should result in the following:
        XCTAssertTrue(route.isAdaptiveSportsEvent)
        XCTAssertEqual(route.telemetryContext, "asevent")
        
        XCTAssertNil(route.deactivate())
    }
    
    func testSinglePointFinish() throws {
        let route = RouteGuidance(RouteGuidanceTest.activity_single_waypoint(), spatialData: spatial, motion: motion)
        route.activate(with: nil)
        XCTAssertNotNil(route.currentWaypoint)
        XCTAssertEqual(route.currentWaypoint!.index, 0)
        
        // ----
        
        XCTAssert(route.completeCurrentWaypoint())
        XCTAssertNotNil(route.currentWaypoint, "we should be on the last waypoint even though we are done")
        let progress = route.progress
        XCTAssertNotNil(progress.currentWaypoint, "we should be on the last waypoint even though we are done")
        XCTAssertTrue(progress.isDone)
        XCTAssertEqual(progress.percentComplete, 100)
        XCTAssertEqual(progress.total, 1)
        XCTAssertEqual(progress.completed, 1)
        XCTAssertEqual(progress.remaining, 0)
        
        XCTAssertTrue(route.state.isFinal)
        XCTAssertEqual(route.state.visited.count, 1)
        
        XCTAssertNil(route.deactivate())
    }
    
    /// For `RouteGuidance.shouldResume`
    func testSinglePointResume() throws {
        let route = RouteGuidance(RouteGuidanceTest.activity_single_waypoint(), spatialData: spatial, motion: motion)
        route.activate(with: nil)
        XCTAssert(route.completeCurrentWaypoint())
        
        // Assert 'before' state
        XCTAssertTrue(route.progress.isDone)
        XCTAssertEqual(route.progress.completed, 1)
        XCTAssertTrue(route.state.isFinal)
        XCTAssertEqual(route.state.visited.count, 1)
        
        // ---
        route.shouldResume = true
        XCTAssertNil(route.deactivate())
        route.activate(with: nil)
        // ---
        
        // Assert 'after' state (should be the same as 'before')
        XCTAssertTrue(route.progress.isDone)
        XCTAssertEqual(route.progress.completed, 1)
        XCTAssertTrue(route.state.isFinal)
        XCTAssertEqual(route.state.visited.count, 1)
        
        XCTAssertNil(route.deactivate())
    }
    
    /// Tests `RouteGuidance.setBeacon(waypointIndex:, enableAudio:)`
    func testSetBeacon() throws {
        let activity = RouteGuidanceTest.activity_random_waypoints(count: 5)
        let route = RouteGuidance(activity, spatialData: spatial, motion: motion)
        route.activate(with: nil)
        XCTAssertNotNil(route.currentWaypoint)
        XCTAssertEqual(route.currentWaypoint!.index, 0)
        XCTAssertEqual(route.currentWaypoint!.waypoint.location.coordinate, activity.waypoints[0].coordinate)
        
        // Go to 2
        route.setBeacon(waypointIndex: 2, enableAudio: false)
        XCTAssertNotNil(route.currentWaypoint)
        XCTAssertEqual(route.currentWaypoint!.index, 2)
        XCTAssertEqual(route.currentWaypoint!.waypoint.location.coordinate, activity.waypoints[2].coordinate)
        XCTAssertEqual(route.progress.completed, 0)
        
        // Go to 3
        route.setBeacon(waypointIndex: 3, enableAudio: false)
        XCTAssertNotNil(route.currentWaypoint)
        XCTAssertEqual(route.currentWaypoint!.index, 3)
        XCTAssertEqual(route.currentWaypoint!.waypoint.location.coordinate, activity.waypoints[3].coordinate)
        XCTAssertEqual(route.progress.completed, 0)
        
        // Go to 10 (out of bound, so fails and stays at 3)
        route.setBeacon(waypointIndex: 10, enableAudio: false)
        XCTAssertNotNil(route.currentWaypoint)
        XCTAssertEqual(route.currentWaypoint!.index, 3)
        XCTAssertEqual(route.currentWaypoint!.waypoint.location.coordinate, activity.waypoints[3].coordinate)
        XCTAssertEqual(route.progress.completed, 0)
        
        // Go back to 0
        route.setBeacon(waypointIndex: 0, enableAudio: false)
        XCTAssertNotNil(route.currentWaypoint)
        XCTAssertEqual(route.currentWaypoint!.index, 0)
        XCTAssertEqual(route.currentWaypoint!.waypoint.location.coordinate, activity.waypoints[0].coordinate)
        XCTAssertEqual(route.progress.completed, 0)
        
        XCTAssertNil(route.deactivate())
    }
    
    // TODO: There are definitely more tests we should add here
}
