// Copyright (c) Soundscape Community Contributers.

import Foundation
import Testing

@testable import SSDataContracts

struct SharedParameterModelsTests {
    @Test
    func coordinateParametersRoundTripThroughQueryItems() {
        let original = CoordinateParameters(latitude: 47.6205, longitude: -122.3493)
        let decoded = CoordinateParameters(queryItems: original.queryItems)

        #expect(decoded?.latitude == original.latitude)
        #expect(decoded?.longitude == original.longitude)
    }

    @Test
    func markerParametersRoundTripThroughQueryItems() {
        let original = MarkerParameters(id: nil,
                                        nickname: "Home",
                                        annotation: "Front door",
                                        estimatedAddress: nil,
                                        lastUpdatedDate: nil,
                                        location: LocationParameters(name: "Home",
                                                                     address: nil,
                                                                     coordinate: CoordinateParameters(latitude: 47.6205,
                                                                                                      longitude: -122.3493),
                                                                     entity: EntityParameters(source: .osm,
                                                                                              lookupInformation: "poi-1")))

        let decoded = MarkerParameters(queryItems: original.queryItems)

        #expect(decoded?.nickname == "Home")
        #expect(decoded?.annotation == "Front door")
        #expect(decoded?.location.name == "Home")
        #expect(decoded?.location.coordinate.latitude == 47.6205)
        #expect(decoded?.location.coordinate.longitude == -122.3493)
        #expect(decoded?.location.entity?.lookupInformation == "poi-1")
    }

    @Test
    func routeParametersStoreWaypointPayloads() {
        let waypoint = RouteWaypointParameters(index: 0,
                                               markerId: "marker-1",
                                               marker: MarkerParameters(name: "Marker",
                                                                        latitude: 47.6205,
                                                                        longitude: -122.3493))
        let createdDate = Date(timeIntervalSince1970: 100)
        let updatedDate = Date(timeIntervalSince1970: 200)
        let selectedDate = Date(timeIntervalSince1970: 300)

        let route = RouteParameters(id: "route-1",
                                    name: "Commute",
                                    routeDescription: "Test route",
                                    waypoints: [waypoint],
                                    createdDate: createdDate,
                                    lastUpdatedDate: updatedDate,
                                    lastSelectedDate: selectedDate)

        #expect(route.id == "route-1")
        #expect(route.name == "Commute")
        #expect(route.waypoints.count == 1)
        #expect(route.waypoints.first?.markerId == "marker-1")
        #expect(route.createdDate == createdDate)
        #expect(route.lastUpdatedDate == updatedDate)
        #expect(route.lastSelectedDate == selectedDate)
    }
}
