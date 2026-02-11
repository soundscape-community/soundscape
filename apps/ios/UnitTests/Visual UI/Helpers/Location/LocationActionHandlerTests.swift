//
//  LocationActionHandlerTests.swift
//  UnitTests
//
//  Copyright (c) Soundscape Community Contributers.
//

import XCTest
import CoreLocation
import SSGeo
@testable import Soundscape

@MainActor
final class LocationActionHandlerTests: XCTestCase {
    override func setUpWithError() throws {
        DataContractRegistry.resetForTesting()
    }

    override func tearDownWithError() throws {
        DataContractRegistry.resetForTesting()
    }

    func testSaveCoordinatePersistsMarkerThroughAsyncWriteContract() async throws {
        try await DataContractRegistry.spatialWrite.removeAllReferenceEntities()

        let coordinate = CLLocation(latitude: 47.6205, longitude: -122.3493)
        let detail = LocationDetail(location: coordinate, telemetryContext: "unit-test")

        try await LocationActionHandler.save(locationDetail: detail)

        let marker = await DataContractRegistry.spatialRead.markerParameters(byCoordinate: coordinate.coordinate.ssGeoCoordinate)
        XCTAssertNotNil(marker)

        try await DataContractRegistry.spatialWrite.removeAllReferenceEntities()
    }

    func testSaveDesignDataThrowsFailedToSaveMarker() async throws {
        let source: LocationDetail.Source = .designData(at: CLLocation(latitude: 47.6205, longitude: -122.3493),
                                                        address: "Design Address")
        guard let detail = LocationDetail(designTimeSource: source, telemetryContext: "unit-test") else {
            return XCTFail("Expected design-time detail")
        }

        do {
            try await LocationActionHandler.save(locationDetail: detail)
            XCTFail("Expected save to fail for design-data source")
        } catch let error as LocationActionError {
            switch error {
            case .failedToSaveMarker:
                break
            default:
                XCTFail("Expected failedToSaveMarker, got \(error)")
            }
        }
    }
}
