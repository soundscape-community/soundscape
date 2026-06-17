//
//  NearbyTableFilterTest.swift
//  UnitTests
//
//  Created by Jonathan Ha on 7/11/24.
//  Copyright © 2024 Soundscape community. All rights reserved.
//

import XCTest
@testable import Soundscape

final class NearbyTableFilterTest: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    func testDefaultFilter() throws {
        let filter = NearbyTableFilter.defaultFilter
        XCTAssertNil(filter.type)
        XCTAssertEqual(filter.localizedString, GDLocalizedString("filter.all"))
        XCTAssertEqual(filter.image, UIImage(named: "AllPlaces"))
    }
    
    func testPrimaryTypeFilters() throws {
        let filters = NearbyTableFilter.primaryTypeFilters
        XCTAssertEqual(filters.count, PrimaryType.allCases.count + 1) // +1 for the default filter
        
        for (index, type) in PrimaryType.allCases.enumerated() {
            let filter = filters[index + 1] // First filter is the default filter
            XCTAssertEqual(filter.type, type)
            switch type {
            case .transit:
                XCTAssertEqual(filter.localizedString, GDLocalizedString("filter.transit"))
                XCTAssertEqual(filter.image, UIImage(named: "Transit"))
            case .food:
                XCTAssertEqual(filter.localizedString, GDLocalizedString("filter.food_drink"))
                XCTAssertEqual(filter.image, UIImage(named: "Food & Drink"))
            case .park:
                XCTAssertEqual(filter.localizedString, GDLocalizedString("filter.parks"))
                XCTAssertEqual(filter.image, UIImage(named: "Parks"))
            case .bank:
                XCTAssertEqual(filter.localizedString, GDLocalizedString("filter.banks"))
                XCTAssertEqual(filter.image, UIImage(named: "Banks & ATMs"))
            case .grocery:
                XCTAssertEqual(filter.localizedString, GDLocalizedString("filter.groceries"))
                XCTAssertEqual(filter.image, UIImage(named: "Groceries & Convenience Stores "))
            case .navilens:
                XCTAssertEqual(filter.localizedString, GDLocalizedString("filter.navilens"))
                XCTAssertEqual(filter.image, UIImage(named: "navilens"))
            }
        }
    }

    func testEquality() throws {
        let filter1 = NearbyTableFilter(type: .transit)
        let filter2 = NearbyTableFilter(type: .transit)
        let filter3 = NearbyTableFilter(type: .food)
        
        XCTAssertEqual(filter1, filter2)
        XCTAssertNotEqual(filter1, filter3)
    }

    func testLocationActionsExcludeNaviLensForStandardLocation() throws {
        let location = GenericLocation(lat: 47.6205, lon: -122.3493, name: "Space Needle")
        let detail = LocationDetail(screenshot: location)

        let actions = LocationAction.actions(for: detail)

        XCTAssertTrue(matches(actions[0], .beacon))
        XCTAssertFalse(actions.contains(where: { matches($0, .navilens) }))
    }

    func testLocationActionsPlaceNaviLensAfterBeacon() throws {
        let location = GenericLocation(lat: 47.6205, lon: -122.3493, name: "NaviLens Code")
        location.superCategory = SuperCategory.navilens.rawValue
        let detail = LocationDetail(screenshot: location)

        let actions = LocationAction.actions(for: detail)

        XCTAssertEqual(actions.count, 5)
        XCTAssertTrue(matches(actions[0], .beacon))
        XCTAssertTrue(matches(actions[1], .navilens))
        XCTAssertTrue(matches(actions[2], .save(isEnabled: true)))
        XCTAssertTrue(matches(actions[3], .preview))
        XCTAssertTrue(matches(actions[4], .share(isEnabled: true)))
        XCTAssertEqual(LocationAction.navilens.text, GDLocalizedString("location_detail.action.navilens"))
        XCTAssertEqual(LocationAction.navilens.accessibilityHint, GDLocalizedString("location_detail.action.navilens.hint"))
    }

    private func matches(_ lhs: LocationAction, _ rhs: LocationAction) -> Bool {
        switch (lhs, rhs) {
        case (.save(let lhsEnabled), .save(let rhsEnabled)):
            return lhsEnabled == rhsEnabled
        case (.edit, .edit),
             (.beacon, .beacon),
             (.preview, .preview),
             (.navilens, .navilens):
            return true
        case (.share(let lhsEnabled), .share(let rhsEnabled)):
            return lhsEnabled == rhsEnabled
        default:
            return false
        }
    }
}
