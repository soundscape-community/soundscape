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

    @Test
    func poiEqualityUsesStableKey() {
        let lhs = TestPOI(key: "shared-key", name: "Coffee Shop", coordinate: .init(latitude: 47.6205, longitude: -122.3493))
        let rhs = TestPOI(key: "shared-key", name: "Coffee Shop Annex", coordinate: .init(latitude: 47.6210, longitude: -122.3490))

        #expect(lhs.isEqual(rhs))
    }

    @Test
    func primaryAndSecondaryTypesMatchTypeablePOIs() {
        let poi = TestPOI(key: "poi-1",
                          name: "City Bus Stop",
                          coordinate: .init(latitude: 47.6205, longitude: -122.3493),
                          primaryTypes: [.transit],
                          secondaryTypes: [.transitStop])

        #expect(PrimaryType.transit.matches(poi: poi))
        #expect(SecondaryType.transitStop.matches(poi: poi))
        #expect(PrimaryType.food.matches(poi: poi) == false)
    }

    @Test
    func poiMatchPrefersClosestStringAndSpatialMatch() {
        let source = TestPOI(key: "source",
                             name: "Coffee Shop",
                             coordinate: .init(latitude: 47.6205, longitude: -122.3493),
                             primaryTypes: [.food],
                             secondaryTypes: [.food])
        let closeMatch = TestPOI(key: "close",
                                 name: "Coffee Shop",
                                 coordinate: .init(latitude: 47.6206, longitude: -122.3492),
                                 primaryTypes: [.food],
                                 secondaryTypes: [.food])
        let farMismatch = TestPOI(key: "far",
                                  name: "Other Place",
                                  coordinate: .init(latitude: 47.6300, longitude: -122.3400),
                                  primaryTypes: [.food],
                                  secondaryTypes: [.food])

        let matched = source.match(others: [farMismatch, closeMatch])

        #expect(matched?.key == closeMatch.key)
    }

    @Test
    func poiMatchRejectsTransitAndNonTransitMix() {
        let transit = TestPOI(key: "transit",
                              name: "Main Street Stop",
                              coordinate: .init(latitude: 47.6205, longitude: -122.3493),
                              primaryTypes: [.transit],
                              secondaryTypes: [.transitStop])
        let nonTransit = TestPOI(key: "non-transit",
                                 name: "Main Street Stop",
                                 coordinate: .init(latitude: 47.6205, longitude: -122.3493),
                                 primaryTypes: [.food],
                                 secondaryTypes: [.food])

        #expect(transit.match(others: [nonTransit]) == nil)
    }


    @Test
    func superCategoryPredicateIncludesMatchingCategory() {
        let poi = TestPOI(key: "poi-1",
                          name: "Transit Hub",
                          coordinate: .init(latitude: 47.6205, longitude: -122.3493),
                          superCategory: SuperCategory.mobility.rawValue)

        #expect(SuperCategoryPredicate(expected: .mobility).isIncluded(poi))
        #expect(SuperCategoryPredicate(expected: .places).isIncluded(poi) == false)
    }

    @Test
    func typePredicateIncludesMatchingType() {
        let poi = TestPOI(key: "poi-1",
                          name: "Transit Hub",
                          coordinate: .init(latitude: 47.6205, longitude: -122.3493),
                          primaryTypes: [.transit],
                          secondaryTypes: [.transitStop])

        #expect(TypePredicate(expected: PrimaryType.transit).isIncluded(poi))
        #expect(TypePredicate(expected: SecondaryType.food).isIncluded(poi) == false)
    }

    @Test
    func compoundPredicateSupportsAndOrAndInvert() {
        let poi = TestPOI(key: "poi-1",
                          name: "Park Cafe",
                          coordinate: .init(latitude: 47.6205, longitude: -122.3493),
                          primaryTypes: [.food],
                          secondaryTypes: [.food],
                          superCategory: SuperCategory.places.rawValue)

        let category = SuperCategoryPredicate(expected: .places)
        let food = TypePredicate(expected: PrimaryType.food)
        let transit = TypePredicate(expected: PrimaryType.transit)

        #expect(CompoundPredicate(andPredicatesWithSubpredicates: [category, food]).isIncluded(poi))
        #expect(CompoundPredicate(orPredicateWithSubpredicates: [transit, food]).isIncluded(poi))
        #expect(food.invert().isIncluded(poi) == false)
    }


    @Test
    func lastSelectedPredicateOrdersMostRecentSelectablePOIsFirst() {
        let older = TestPOI(key: "older",
                            name: "Older",
                            coordinate: .init(latitude: 47.6205, longitude: -122.3493),
                            lastSelectedDate: Date(timeIntervalSince1970: 100))
        let newer = TestPOI(key: "newer",
                            name: "Newer",
                            coordinate: .init(latitude: 47.6205, longitude: -122.3493),
                            lastSelectedDate: Date(timeIntervalSince1970: 200))

        #expect(LastSelectedPredicate().areInIncreasingOrder(newer, older))
        #expect(LastSelectedPredicate().areInIncreasingOrder(older, newer) == false)
    }

    @Test
    func poiQueueKeepsSortedFilteredTopNResults() {
        let queue = POIQueue(maxItems: 2,
                             sort: LastSelectedPredicate(),
                             filter: SuperCategoryPredicate(expected: .places))
        let oldest = TestPOI(key: "oldest",
                             name: "Oldest",
                             coordinate: .init(latitude: 47.6205, longitude: -122.3493),
                             lastSelectedDate: Date(timeIntervalSince1970: 100))
        let newest = TestPOI(key: "newest",
                             name: "Newest",
                             coordinate: .init(latitude: 47.6206, longitude: -122.3494),
                             lastSelectedDate: Date(timeIntervalSince1970: 300))
        let middle = TestPOI(key: "middle",
                             name: "Middle",
                             coordinate: .init(latitude: 47.6207, longitude: -122.3495),
                             lastSelectedDate: Date(timeIntervalSince1970: 200))
        let filteredOut = TestPOI(key: "filtered",
                                  name: "Filtered",
                                  coordinate: .init(latitude: 47.6208, longitude: -122.3496),
                                  superCategory: SuperCategory.mobility.rawValue,
                                  lastSelectedDate: Date(timeIntervalSince1970: 400))

        queue.insert([oldest, newest, middle, filteredOut])

        #expect(queue.pois.map(\.key) == ["newest", "middle"])
    }
}

private struct TestPOI: SelectablePOI, Typeable {
    let key: String
    let name: String
    let localizedName: String
    let superCategory: String
    let addressLine: String?
    let streetName: String?
    let centroidLatitude: Double
    let centroidLongitude: Double
    var lastSelectedDate: Date?
    let primaryTypes: Set<PrimaryType>
    let secondaryTypes: Set<SecondaryType>

    init(
        key: String,
        name: String,
        coordinate: SSGeoCoordinate,
        primaryTypes: Set<PrimaryType> = [],
        secondaryTypes: Set<SecondaryType> = [],
        superCategory: String = SuperCategory.places.rawValue,
        addressLine: String? = nil,
        streetName: String? = nil,
        lastSelectedDate: Date? = nil
    ) {
        self.key = key
        self.name = name
        localizedName = name
        self.superCategory = superCategory
        self.addressLine = addressLine
        self.streetName = streetName
        self.lastSelectedDate = lastSelectedDate
        centroidLatitude = coordinate.latitude
        centroidLongitude = coordinate.longitude
        self.primaryTypes = primaryTypes
        self.secondaryTypes = secondaryTypes
    }

    func contains(location: SSGeoCoordinate) -> Bool {
        location == centroidSSGeoCoordinate
    }

    func closestLocation(from location: SSGeoLocation, useEntranceIfAvailable: Bool) -> SSGeoLocation {
        centroidSSGeoLocation
    }

    func distanceToClosestLocation(from location: SSGeoLocation, useEntranceIfAvailable: Bool) -> Double {
        SSGeoMath.distanceMeters(from: centroidSSGeoCoordinate, to: location.coordinate)
    }

    func bearingToClosestLocation(from location: SSGeoLocation, useEntranceIfAvailable: Bool) -> Double {
        SSGeoMath.initialBearingDegrees(from: location.coordinate, to: centroidSSGeoCoordinate)
    }

    func isOfType(_ type: PrimaryType) -> Bool {
        primaryTypes.contains(type)
    }

    func isOfType(_ type: SecondaryType) -> Bool {
        secondaryTypes.contains(type)
    }
}
