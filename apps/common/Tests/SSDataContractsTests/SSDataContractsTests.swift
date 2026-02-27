// Copyright (c) Soundscape Community Contributers.

import Foundation
import Testing

@testable import SSDataContracts

struct SSDataContractsTests {
    @Test
    func addressCacheRecordPreservesValues() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let record = AddressCacheRecord(key: "address-1",
                                        lastSelectedDate: now,
                                        name: "Home",
                                        addressLine: "123 Main St",
                                        streetName: "Main St",
                                        latitude: 47.62,
                                        longitude: -122.34,
                                        centroidLatitude: 47.62,
                                        centroidLongitude: -122.34,
                                        searchString: "home")

        #expect(record.key == "address-1")
        #expect(record.lastSelectedDate == now)
        #expect(record.name == "Home")
        #expect(record.latitude == 47.62)
        #expect(record.longitude == -122.34)
    }

    @Test
    func metadataAndCalloutTypesPreserveFields() {
        let routeMetadata = RouteReadMetadata(id: "route-1", lastUpdatedDate: nil)
        let referenceMetadata = ReferenceReadMetadata(id: "marker-1", lastUpdatedDate: nil)
        let callout = ReferenceCalloutReadData(name: "Marker", superCategory: "places")
        let estimatedAddress = EstimatedAddressReadData(addressLine: "123 Main St",
                                                        streetName: "Main St",
                                                        subThoroughfare: "123")

        #expect(routeMetadata.id == "route-1")
        #expect(referenceMetadata.id == "marker-1")
        #expect(callout.name == "Marker")
        #expect(callout.superCategory == "places")
        #expect(estimatedAddress.addressLine == "123 Main St")
        #expect(estimatedAddress.streetName == "Main St")
        #expect(estimatedAddress.subThoroughfare == "123")
    }

    @Test
    func intersectionRegionStoresCenterAndSpan() {
        let region = SpatialIntersectionRegion(center: .init(latitude: 47.6205, longitude: -122.3493),
                                               latitudeDelta: 0.01,
                                               longitudeDelta: 0.02)

        #expect(region.center.latitude == 47.6205)
        #expect(region.center.longitude == -122.3493)
        #expect(region.latitudeDelta == 0.01)
        #expect(region.longitudeDelta == 0.02)
    }
}
