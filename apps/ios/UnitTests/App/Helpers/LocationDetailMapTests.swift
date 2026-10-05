//
//  LocationDetailMapTests.swift
//  UnitTests
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import XCTest
import CoreLocation
import SwiftUI
@testable import Soundscape

final class LocationDetailMapTests: XCTestCase {

    func testUnsavedLocationDetailsDisableMapEditing() {
        let detail = LocationDetail(location: CLLocation(latitude: 51.5074, longitude: -0.1278))
        let controller = LocationDetailViewController()
        controller.locationDetail = detail
        let map = ExpandableMapViewController()
        let segue = UIStoryboardSegue(identifier: nil, source: controller, destination: map)

        controller.prepare(for: segue, sender: nil)

        XCTAssertFalse(detail.isMarker)
        XCTAssertFalse(map.isEditable)
    }

    func testSavedMarkerDetailsEnableMapEditing() throws {
        let detail = LocationDetail(location: CLLocation(latitude: 51.5084, longitude: -0.1288))
        let markerId = try ReferenceEntity.add(detail: detail, telemetryContext: nil, notify: false)
        defer { try? ReferenceEntity.remove(id: markerId) }
        let controller = LocationDetailViewController()
        controller.locationDetail = try XCTUnwrap(LocationDetail(markerId: markerId))
        let map = ExpandableMapViewController()
        let segue = UIStoryboardSegue(identifier: nil, source: controller, destination: map)

        controller.prepare(for: segue, sender: nil)

        XCTAssertTrue(map.isEditable)
    }

    func testReadOnlyMapDoesNotCreateNudgeControl() throws {
        let map = try makeMap(isEditable: false)

        map.viewWillAppear(false)

        XCTAssertFalse(map.children.contains { $0 is UIHostingController<AnyView> })
        map.viewWillDisappear(false)
    }

    func testMarkerEditorCreatesNudgeControlForUnsavedLocation() throws {
        let map = try makeMap(isEditable: true)

        map.viewWillAppear(false)

        XCTAssertTrue(map.children.contains { $0 is UIHostingController<AnyView> })
        map.viewWillDisappear(false)
    }

    private func makeMap(isEditable: Bool) throws -> ExpandableMapViewController {
        let storyboard = UIStoryboard(name: "Map", bundle: Bundle(for: ExpandableMapViewController.self))
        let map = try XCTUnwrap(storyboard.instantiateInitialViewController() as? ExpandableMapViewController)
        map.style = .location(detail: LocationDetail(location: CLLocation(latitude: 51.5094, longitude: -0.1298)))
        map.isEditable = isEditable
        map.accessibilityEditableMapViewModel = AccessibilityEditableMapViewModel()
        map.loadViewIfNeeded()
        return map
    }
}
