//
//  TutorialMigrationTests.swift
//  UnitTests
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI
import UIKit
import XCTest
@testable import Soundscape

final class TutorialMigrationTests: XCTestCase {
    func testDestinationStateUpdatesTextAndActionVisibility() {
        let state = DestinationTutorialViewState(title: "Title",
                                                 image: UIImage(),
                                                 text: "Initial",
                                                 actionTitle: "Continue",
                                                 action: .setBeacon,
                                                 exitTitle: "Exit")

        XCTAssertTrue(state.isActionVisible)
        XCTAssertEqual(state.action, .setBeacon)

        state.updateText("Updated")
        state.setActionVisible(false)

        XCTAssertEqual(state.text, "Updated")
        XCTAssertFalse(state.isActionVisible)
    }

    func testDestinationStateWithoutActionCannotRevealOne() {
        let state = DestinationTutorialViewState(title: "Title", image: UIImage(), text: "Text")
        state.setActionVisible(true)
        XCTAssertFalse(state.isActionVisible)
    }

    func testDestinationCoordinatorAdvancesInOrderAndHostsSwiftUI() {
        let controller = DestinationTutorialViewController(source: nil, entityKey: nil)
        controller.loadViewIfNeeded()

        XCTAssertEqual(controller.steps.count, 3)
        XCTAssertEqual(controller.currentPageIndex, 0)
        XCTAssertTrue(controller.steps[0].children.first is UIHostingController<DestinationTutorialPageView>)

        XCTAssertTrue(controller.goToNextPage())
        XCTAssertEqual(controller.currentPageIndex, 1)
        XCTAssertTrue(controller.goToNextPage())
        XCTAssertEqual(controller.currentPageIndex, 2)
        XCTAssertFalse(controller.goToNextPage())
    }

    func testDestinationNameSubstitution() {
        let page = DestinationTutorialBeaconPage()
        XCTAssertEqual(page.resolvedText("Walk toward @!destination!!.", destinationName: "The Library"),
                       "Walk toward The Library.")
        XCTAssertFalse(page.resolvedText("Walk toward @!destination!!.", destinationName: nil)
            .contains("@!destination!!"))
    }

    func testPreviewDonePersistsCompletionAndRestoresCalloutsIdempotently() {
        final class Delegate: PreviewTutorialDelegate {
            var completionCount = 0
            func previewTutorialDidComplete() { completionCount += 1 }
        }

        let previousCallouts = SettingsContext.shared.automaticCalloutsEnabled
        let previousCompletion = FirstUseExperience.didComplete(.previewTutorial)
        defer {
            SettingsContext.shared.automaticCalloutsEnabled = previousCallouts
            FirstUseExperience.setDidComplete(previousCompletion, for: .previewTutorial)
        }

        SettingsContext.shared.automaticCalloutsEnabled = true
        FirstUseExperience.setDidComplete(false, for: .previewTutorial)
        let delegate = Delegate()
        let controller = PreviewTutorialViewController(delegate: delegate)
        controller.loadViewIfNeeded()

        XCTAssertFalse(SettingsContext.shared.automaticCalloutsEnabled)
        XCTAssertTrue(controller.children.first is UIHostingController<PreviewTutorialView>)

        controller.completeTutorial()
        controller.restoreCalloutsIfNeeded()

        XCTAssertTrue(SettingsContext.shared.automaticCalloutsEnabled)
        XCTAssertTrue(FirstUseExperience.didComplete(.previewTutorial))
        XCTAssertEqual(delegate.completionCount, 1)
    }
}
