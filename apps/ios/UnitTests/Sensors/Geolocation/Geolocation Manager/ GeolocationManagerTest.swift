//
//  GeolocationManager.swift
//  UnitTests
//
//  Created by Kai on 7/11/23.
//  Copyright © 2023 Microsoft. All rights reserved.
//

import XCTest
import CoreLocation
@testable import Soundscape

// As described in `docs/ios-client/overview.md`, the GeolocationManager manages all location-related sensor providers for both the GPS and headphone location
// by default, this uses CoreLocationManager and derivations of it for all providers

// Gets updated by its providers via its delegate extensions (e.g. `DeviceHeadingProviderDelegate` with event handler `deviceHeadingProvider(_:, didUpdateDeviceHeading:)`)
// When location updates, all `GeolocationManagerUpdateDelegate`s receiving events from it will have `didUpdateLocation(...)` called
// When any heading updates, the event will be sent to `NotificationCenter.default` for distribution to listeners

class TestLocationProvider: LocationProvider {
    var locationDelegate: LocationProviderDelegate?
    func sendLocation(_ loc: CLLocation) {
        locationDelegate?.locationProvider(self, didUpdateLocation: loc)
    }
    
    func startLocationUpdates() { }
    
    func stopLocationUpdates() { }
    
    func startMonitoringSignificantLocationChanges() -> Bool { return false; }
    
    func stopMonitoringSignificantLocationChanges() { }
    
    var id: UUID = UUID()
}

class TestCourseProvider: CourseProvider {
    var courseDelegate: CourseProviderDelegate?
    
    func sendHeading(_ course: HeadingValue) {
        courseDelegate?.courseProvider(self, didUpdateCourse: course)
    }
    
    func startCourseProviderUpdates() { }
    
    func stopCourseProviderUpdates() { }
    
    var id: UUID = UUID()
}

class TestUserHeadingProvider: UserHeadingProvider {
    var headingDelegate: UserHeadingProviderDelegate?
    
    func sendHeading(_ userHeading: HeadingValue) {
        headingDelegate?.userHeadingProvider(self, didUpdateUserHeading: userHeading)
    }
    
    var accuracy: Double = 0
    
    func startUserHeadingUpdates() { }
    
    func stopUserHeadingUpdates() { }
    
    var id: UUID = UUID()
    
    
}

class TestGeolocationUpdateReceiver: GeolocationManagerUpdateDelegate {
    var locations: [CLLocation] = []
    func didUpdateLocation(_ location: CLLocation) {
        locations.append(location)
    }
}
class TestNotificationCenterReceiver {
    var headings: [[String: Any]] = []
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.onNotif(_:)), name: Notification.Name.headingTypeDidUpdate, object: nil)
    }
    @objc
    func onNotif(_ notif: NSNotification) {
        headings.append(notif.userInfo! as! [String: Any])
    }
}

class TestCLLocationManager: CLLocationManager {
    
}

class GeolocationManagerTest: XCTestCase {
    private var manager: GeolocationManager!
    private var locProvider = TestLocationProvider()
    private var courseProvider = TestCourseProvider()
    private var userHeadingProvider = TestUserHeadingProvider()
    private var locReceiver = TestGeolocationUpdateReceiver()

    override func setUp() {
        manager = GeolocationManager(isInMotion: false)
        manager.updateDelegate = locReceiver
        manager.add(locProvider)
        manager.add(courseProvider)
        manager.add(userHeadingProvider)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testDeviceLocationMocked() throws {
        // Using our mock `LocationProvider`
        let loc0_0 = CLLocation(latitude: 0, longitude: 0)
        locProvider.sendLocation(loc0_0)
        XCTAssertEqual(locReceiver.locations.count, 1)
        XCTAssertEqual(locReceiver.locations[0], loc0_0)
    }
    
    func testCourseProviderMocked() throws {
        // Using our mock `CourseProvider`
        let notifReceiver = TestNotificationCenterReceiver()
        courseProvider.sendHeading(HeadingValue(0, 0))
        // Filter to only `HeadingType.course`
        let courseHeadings = notifReceiver.headings.filter({$0[GeolocationManager.Key.type] as! HeadingType == HeadingType.course})
        XCTAssertEqual(courseHeadings.count, 1)
        XCTAssertEqual(courseHeadings[0][GeolocationManager.Key.value] as! Double, 0)
        XCTAssertEqual(courseHeadings[0][GeolocationManager.Key.accuracy] as! Double, 0)
    }
    
    func testCourseProviderMockedNoAccuracy() throws {
        // Using our mock `CourseProvider`
        let notifReceiver = TestNotificationCenterReceiver()
        courseProvider.sendHeading(HeadingValue(0, nil))
        // Filter to only `HeadingType.course`
        let courseHeadings = notifReceiver.headings.filter({$0[GeolocationManager.Key.type] as! HeadingType == HeadingType.course})
        XCTAssertEqual(courseHeadings.count, 1)
        XCTAssertEqual(courseHeadings[0][GeolocationManager.Key.value] as! Double, 0)
        XCTAssertFalse(courseHeadings[0].keys.contains(GeolocationManager.Key.accuracy))
    }
    
    func testUserHeadingProviderMocked() throws {
        // Using our mock `CourseProvider`
        let notifReceiver = TestNotificationCenterReceiver()
        userHeadingProvider.sendHeading(HeadingValue(0, 0))
        // Filter to only `HeadingType.course`
        let userHeadings = notifReceiver.headings.filter({$0[GeolocationManager.Key.type] as! HeadingType == HeadingType.user})
        XCTAssertEqual(userHeadings.count, 1)
        XCTAssertEqual(userHeadings[0][GeolocationManager.Key.value] as! Double, 0)
        XCTAssertEqual(userHeadings[0][GeolocationManager.Key.accuracy] as! Double, 0)
    }
    
    func testUserHeadingProviderMockedNoAccuracy() throws {
        // Using our mock `CourseProvider`
        let notifReceiver = TestNotificationCenterReceiver()
        userHeadingProvider.sendHeading(HeadingValue(0, nil))
        // Filter to only `HeadingType.course`
        let userHeadings = notifReceiver.headings.filter({$0[GeolocationManager.Key.type] as! HeadingType == HeadingType.user})
        XCTAssertEqual(userHeadings.count, 1)
        XCTAssertEqual(userHeadings[0][GeolocationManager.Key.value] as! Double, 0)
        XCTAssertFalse(userHeadings[0].keys.contains(GeolocationManager.Key.accuracy))
    }
    
    // NOTE: device heading provider is locked to be the default
    // but we should probably still add tests
}
