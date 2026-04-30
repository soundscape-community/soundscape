//
//  NavigationControllerTest.swift
//  UnitTests
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import XCTest
@testable import Soundscape

class NavigationControllerTest: XCTestCase {

    func testPushViewControllerKeepsNativeBackButton() {
        let root = UIViewController()
        let pushed = UIViewController()
        let navigationController = NavigationController(rootViewController: root)

        navigationController.pushViewController(pushed, animated: false)

        XCTAssertFalse(pushed.navigationItem.hidesBackButton)
        XCTAssertNil(pushed.navigationItem.leftBarButtonItem)
    }

    func testSetViewControllersKeepsNativeBackButton() {
        let root = UIViewController()
        let pushed = UIViewController()
        let navigationController = NavigationController()

        navigationController.setViewControllers([root, pushed], animated: false)

        XCTAssertFalse(pushed.navigationItem.hidesBackButton)
        XCTAssertNil(pushed.navigationItem.leftBarButtonItem)
    }

    func testPushedControllerWithoutLeadingItemDoesNotReceiveCustomBackButton() {
        let root = UIViewController()
        let markerTutorialEditController = UIViewController()
        let navigationController = NavigationController(rootViewController: root)

        XCTAssertNil(markerTutorialEditController.navigationItem.leftBarButtonItem)

        navigationController.pushViewController(markerTutorialEditController, animated: false)

        XCTAssertFalse(markerTutorialEditController.navigationItem.hidesBackButton)
        XCTAssertNil(markerTutorialEditController.navigationItem.leftBarButtonItem)
    }

}
