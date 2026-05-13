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

    func testTransparentNavigationStyleTintsExistingImageButtons() {
        let root = UIViewController()
        let menuItem = UIBarButtonItem(image: UIImage(), style: .plain, target: nil, action: nil)
        let sleepItem = UIBarButtonItem(image: UIImage(), style: .plain, target: nil, action: nil)
        let navigationController = NavigationController(rootViewController: root)

        root.navigationItem.leftBarButtonItem = menuItem
        root.navigationItem.rightBarButtonItem = sleepItem

        navigationController.navigationBar.configureAppearance(for: .transparentLightTitle)

        XCTAssertEqual(navigationController.navigationBar.tintColor, UINavigationBar.Style.transparentLightTitle.foregroundColor)
        XCTAssertEqual(menuItem.tintColor, UINavigationBar.Style.transparentLightTitle.foregroundColor)
        XCTAssertEqual(sleepItem.tintColor, UINavigationBar.Style.transparentLightTitle.foregroundColor)
        XCTAssertEqual(menuItem.image?.renderingMode, .alwaysTemplate)
        XCTAssertEqual(sleepItem.image?.renderingMode, .alwaysTemplate)
    }

    func testDefaultNavigationStyleTintsExistingImageButtons() {
        let root = UIViewController()
        let menuItem = UIBarButtonItem(image: UIImage(), style: .plain, target: nil, action: nil)
        let sleepItem = UIBarButtonItem(image: UIImage(), style: .plain, target: nil, action: nil)
        let navigationController = NavigationController(rootViewController: root)

        root.navigationItem.leftBarButtonItem = menuItem
        root.navigationItem.rightBarButtonItem = sleepItem

        navigationController.navigationBar.configureAppearance(for: .default)

        XCTAssertEqual(navigationController.navigationBar.tintColor, UINavigationBar.Style.default.foregroundColor)
        XCTAssertEqual(menuItem.tintColor, UINavigationBar.Style.default.foregroundColor)
        XCTAssertEqual(sleepItem.tintColor, UINavigationBar.Style.default.foregroundColor)
        XCTAssertEqual(menuItem.image?.renderingMode, .alwaysTemplate)
        XCTAssertEqual(sleepItem.image?.renderingMode, .alwaysTemplate)
    }

    func testDefaultBackButtonDoesNotUseIOS26SharedBackground() throws {
        let item = UIBarButtonItem.defaultBackBarButtonItem

        if #available(iOS 26.0, *) {
            XCTAssertTrue(item.hidesSharedBackground)
            XCTAssertFalse(item.sharesBackground)
        }
    }

    func testDefaultNavigationStyleKeepsLightBackButtonColor() {
        let appearance = UINavigationBarAppearance.soundscapeAppearance(for: .default)
        let foregroundColor = appearance.backButtonAppearance.normal.titleTextAttributes[.foregroundColor] as? UIColor

        XCTAssertEqual(foregroundColor, UINavigationBar.Style.default.foregroundColor)
    }

    func testTransparentNavigationStyleKeepsLightBackButtonColor() {
        let appearance = UINavigationBarAppearance.soundscapeAppearance(for: .transparentLightTitle)
        let foregroundColor = appearance.backButtonAppearance.normal.titleTextAttributes[.foregroundColor] as? UIColor

        XCTAssertEqual(foregroundColor, UINavigationBar.Style.transparentLightTitle.foregroundColor)
    }

    func testNavigationStyleForcesDarkInterfaceStyle() {
        let navigationController = NavigationController(rootViewController: UIViewController())

        navigationController.navigationBar.configureAppearance(for: .default)

        XCTAssertEqual(navigationController.navigationBar.overrideUserInterfaceStyle, .dark)
    }

}
