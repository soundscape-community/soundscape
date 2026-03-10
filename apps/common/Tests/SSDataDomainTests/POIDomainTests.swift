// Copyright (c) Soundscape Community Contributers.

import Foundation
import SSGeo
import Testing

@testable import SSDataDomain

struct POIDomainTests {
    @Test
    func genericLocationSupportsPortableDistanceBearingAndContainment() {
        let poi = GenericLocation(lat: 47.6205, lon: -122.3493, name: "Home")
        let sameCoordinate = SSGeoCoordinate(latitude: 47.6205, longitude: -122.3493)
        let nearbyLocation = SSGeoLocation(coordinate: SSGeoCoordinate(latitude: 47.6210, longitude: -122.3493))

        #expect(poi.contains(location: sameCoordinate))
        #expect(poi.distanceToClosestLocation(from: nearbyLocation, useEntranceIfAvailable: false) > 0)
        #expect(poi.bearingToClosestLocation(from: nearbyLocation, useEntranceIfAvailable: false).isFinite)
        #expect(poi.closestLocation(from: nearbyLocation, useEntranceIfAvailable: false).coordinate == poi.geoCoordinate)
    }

    @Test
    func genericLocationCanBeBuiltFromReferenceEntity() {
        let reference = ReferenceEntity(id: "marker-1",
                                        entityKey: nil,
                                        lastUpdatedDate: nil,
                                        lastSelectedDate: nil,
                                        isNew: false,
                                        isTemp: false,
                                        coordinate: .init(latitude: 47.6205, longitude: -122.3493),
                                        nickname: "Coffee",
                                        estimatedAddress: "123 Main",
                                        annotation: nil)

        let poi = GenericLocation(ref: reference)

        #expect(poi.key == "marker-1")
        #expect(poi.name == "Coffee")
        #expect(poi.addressLine == "123 Main")
        #expect(poi.geoCoordinate == reference.coordinate)
    }

    @Test
    func superCategoryParsesKnownCategoryPayloads() {
        let payload = Data("""
        {
          "version": 3,
          "categories": {
            "place": ["cafe"],
            "mobility": ["bus_stop"],
            "unknown": ["ignored"]
          }
        }
        """.utf8)

        let parsed = SuperCategory.parseCategories(from: payload)

        #expect(parsed?.version == 3)
        #expect(parsed?.categories[.places] == Set(["cafe"]))
        #expect(parsed?.categories[.mobility] == Set(["bus_stop"]))
        #expect(parsed?.categories[.undefined] == nil)
    }
}
