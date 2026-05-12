//
//  NaviLensWakeOnForegroundTest.swift
//  UnitTests
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import XCTest
@testable import Soundscape

final class NaviLensWakeOnForegroundTest: XCTestCase {

    func testSleepUntilForegroundSleepsAndWakesWhenAppBecomesActive() {
        let notificationCenter = NotificationCenter()
        let wakeExpectation = expectation(description: "Wake on foreground")
        var state = OperationState.normal
        var sleepCount = 0
        var wakeCount = 0

        let helper = NaviLensWakeOnForeground(notificationCenter: notificationCenter,
                                              appState: { state },
                                              sleep: {
                                                  sleepCount += 1
                                                  state = .sleep
                                              },
                                              wake: {
                                                  wakeCount += 1
                                                  state = .normal
                                                  wakeExpectation.fulfill()
                                              })

        XCTAssertTrue(helper.sleepUntilForeground())
        XCTAssertEqual(sleepCount, 1)
        XCTAssertEqual(wakeCount, 0)
        XCTAssertEqual(state, .sleep)

        notificationCenter.post(name: Notification.Name.appDidBecomeActive, object: nil)

        wait(for: [wakeExpectation], timeout: 1.0)
        XCTAssertEqual(sleepCount, 1)
        XCTAssertEqual(wakeCount, 1)
        XCTAssertEqual(state, .normal)
    }

    func testSleepUntilForegroundDoesNothingWhenAlreadySleeping() {
        let helper = NaviLensWakeOnForeground(notificationCenter: NotificationCenter(),
                                              appState: { .sleep },
                                              sleep: { XCTFail("Should not sleep again") },
                                              wake: { XCTFail("Should not wake without a pending foreground wake") })

        XCTAssertFalse(helper.sleepUntilForeground())
        helper.wakeUp()
    }

    func testWakeUpAfterFailedLaunchWakesOnlyOnce() {
        let notificationCenter = NotificationCenter()
        var state = OperationState.normal
        var wakeCount = 0

        let helper = NaviLensWakeOnForeground(notificationCenter: notificationCenter,
                                              appState: { state },
                                              sleep: { state = .sleep },
                                              wake: {
                                                  wakeCount += 1
                                                  state = .normal
                                              })

        XCTAssertTrue(helper.sleepUntilForeground())
        helper.wakeUp()
        notificationCenter.post(name: Notification.Name.appDidBecomeActive, object: nil)

        XCTAssertEqual(wakeCount, 1)
        XCTAssertEqual(state, .normal)
    }

}
