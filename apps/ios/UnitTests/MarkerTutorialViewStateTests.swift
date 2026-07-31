//
//  MarkerTutorialViewStateTests.swift
//  UnitTests
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import XCTest
import UIKit
import SwiftUI
@testable import Soundscape

final class MarkerTutorialViewStateTests: XCTestCase {
    func testIntroStateAndAddMarkerAction() {
        let state = MarkerTutorialViewState(exitTitle: "Skip")

        state.show(title: "Getting started",
                   image: UIImage(),
                   text: "Intro",
                   actionTitle: "Add marker",
                   action: .addMarker,
                   hidesContentFromAccessibility: false)

        XCTAssertEqual(state.title, "Getting started")
        XCTAssertEqual(state.text, "Intro")
        XCTAssertEqual(state.actionTitle, "Add marker")
        XCTAssertEqual(state.action, .addMarker)
        XCTAssertFalse(state.isActionVisible)
        XCTAssertFalse(state.hidesContentFromAccessibility)
        XCTAssertEqual(state.exitTitle, "Skip")
    }

    func testActionRemainsHiddenWhenPageHasNoAction() {
        let state = MarkerTutorialViewState(exitTitle: "Skip")

        state.show(title: "Mark your world",
                   image: UIImage(),
                   text: nil,
                   actionTitle: nil,
                   action: nil,
                   hidesContentFromAccessibility: true)
        state.revealAction()

        XCTAssertFalse(state.isActionVisible)
        XCTAssertEqual(state.actionFocusRequest, 0)
        XCTAssertTrue(state.hidesContentFromAccessibility)
    }

    func testNearbyMarkersActionBecomesVisibleAndRequestsFocus() {
        let state = MarkerTutorialViewState(exitTitle: "Skip")

        state.show(title: "Experience your world",
                   image: UIImage(),
                   text: nil,
                   actionTitle: "Nearby markers",
                   action: .nearbyMarkers,
                   hidesContentFromAccessibility: true)
        state.revealAction()

        XCTAssertEqual(state.action, .nearbyMarkers)
        XCTAssertTrue(state.isActionVisible)
        XCTAssertEqual(state.actionFocusRequest, 1)
    }

    func testSpokenTextUpdateAndClearResetPresentation() {
        let state = MarkerTutorialViewState(exitTitle: "Skip")
        state.show(title: "Title",
                   image: UIImage(),
                   text: nil,
                   actionTitle: "Continue",
                   action: .addMarker,
                   hidesContentFromAccessibility: true)

        state.updateText("Spoken tutorial text")

        XCTAssertEqual(state.text, "Spoken tutorial text")

        state.clear()

        XCTAssertNil(state.title)
        XCTAssertNil(state.image)
        XCTAssertNil(state.text)
        XCTAssertNil(state.actionTitle)
        XCTAssertNil(state.action)
        XCTAssertFalse(state.isActionVisible)
        XCTAssertFalse(state.hidesContentFromAccessibility)
    }

    func testControllerRendersSwiftUISurfaceAndRestoresNavigationBar() {
        let previousTutorialMode = AppContext.shared.isInTutorialMode
        let controller = MarkerTutorialViewController(logContext: "simulator_smoke_test")
        let navigationController = UINavigationController(rootViewController: controller)

        defer {
            controller.stop()
            AppContext.shared.isInTutorialMode = previousTutorialMode
        }

        controller.loadViewIfNeeded()
        navigationController.view.frame = UIScreen.main.bounds
        controller.view.frame = navigationController.view.bounds
        navigationController.beginAppearanceTransition(true, animated: false)
        navigationController.endAppearanceTransition()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
        navigationController.view.layoutIfNeeded()
        controller.view.layoutIfNeeded()

        XCTAssertEqual(controller.children.count, 1)
        XCTAssertTrue(String(describing: type(of: controller.children[0])).contains("UIHostingController"))
        XCTAssertTrue(navigationController.isNavigationBarHidden)
        XCTAssertEqual(controller.view.backgroundColor, Colors.Background.markerTutorial)

        navigationController.beginAppearanceTransition(false, animated: false)
        navigationController.endAppearanceTransition()

        XCTAssertFalse(navigationController.isNavigationBarHidden)
    }

    func testSwiftUISurfaceRendersIntroOnSimulator() throws {
        let tutorialImage = try XCTUnwrap(UIImage(named: "Markers tutorial - 01"))
        let state = MarkerTutorialViewState(exitTitle: GDLocalizedString("tutorial.skip"))
        state.show(title: GDLocalizedString("tutorial.markers.getting_started"),
                   image: tutorialImage,
                   text: GDLocalizedString("tutorial.markers.text.Intro"),
                   actionTitle: GDLocalizedString("tutorial.markers.add_marker"),
                   action: .addMarker,
                   hidesContentFromAccessibility: false)
        state.revealAction(requestAccessibilityFocus: false)

        let hostingController = UIHostingController(
            rootView: MarkerTutorialView(state: state, onAction: { _ in }, onExit: {})
        )
        let windowScene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let previousKeyWindow = windowScene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: windowScene)
        window.frame = UIScreen.main.bounds
        window.windowLevel = .alert + 1
        window.rootViewController = hostingController

        defer {
            window.isHidden = true
            previousKeyWindow?.makeKey()
        }

        window.makeKeyAndVisible()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
        hostingController.view.frame = window.bounds
        hostingController.view.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(bounds: hostingController.view.bounds)
        let image = renderer.image { _ in
            hostingController.view.drawHierarchy(in: hostingController.view.bounds, afterScreenUpdates: true)
        }
        XCTAssertEqual(image.size, hostingController.view.bounds.size)

        let attachment = XCTAttachment(image: image)
        attachment.name = "Marker tutorial intro - simulator"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
