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

    private var suiteName: String!
    private var userDefaults: UserDefaults!
    private var settings: SettingsContext!

    override func setUp() {
        super.setUp()
        suiteName = "NaviLensWakeOnForegroundTest-\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)!
        settings = SettingsContext(userDefaults: userDefaults)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        settings = nil
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testAutoSnoozeDefaultsToEnabled() {
        XCTAssertTrue(settings.naviLensAutoSnoozeEnabled)
    }

    func testAutoSnoozePersistsAcrossSettingsInstances() {
        for enabled in [false, true] {
            settings.naviLensAutoSnoozeEnabled = enabled

            let reloadedDefaults = UserDefaults(suiteName: suiteName)!
            let reloadedSettings = SettingsContext(userDefaults: reloadedDefaults)
            XCTAssertEqual(reloadedSettings.naviLensAutoSnoozeEnabled, enabled)
            XCTAssertEqual(reloadedDefaults.persistentDomain(forName: suiteName)?["GDANaviLensAutoSnoozeEnabled"] as? Bool, enabled)
        }
    }

    func testDisabledAutoSnoozeDoesNotSleepOrScheduleWake() {
        settings.naviLensAutoSnoozeEnabled = false
        let notificationCenter = NotificationCenter()
        let helper = NaviLensWakeOnForeground(notificationCenter: notificationCenter,
                                              appState: { .normal },
                                              sleep: { XCTFail("Should not sleep when auto-snooze is disabled") },
                                              wake: { XCTFail("Should not wake when auto-snooze is disabled") })

        XCTAssertFalse(helper.sleepUntilForeground(autoSnoozeEnabled: settings.naviLensAutoSnoozeEnabled))
        notificationCenter.post(name: Notification.Name.appDidBecomeActive, object: nil)
        helper.wakeUp()
    }

    func testSettingsSwitchLoadsAndSavesAutoSnooze() throws {
        let originalValue = SettingsContext.shared.naviLensAutoSnoozeEnabled
        defer { SettingsContext.shared.naviLensAutoSnoozeEnabled = originalValue }

        let storyboard = UIStoryboard(name: "Settings", bundle: Bundle(for: SettingsViewController.self))
        let controller = try XCTUnwrap(storyboard.instantiateInitialViewController() as? SettingsViewController)
        controller.loadViewIfNeeded()
        let tableView = try XCTUnwrap(controller.tableView)
        let section = try XCTUnwrap((0..<controller.numberOfSections(in: tableView)).first {
            controller.tableView(tableView, titleForHeaderInSection: $0) == GDLocalizedString("settings.section.navilens")
        })
        let indexPath = IndexPath(row: 0, section: section)

        for enabled in [true, false] {
            SettingsContext.shared.naviLensAutoSnoozeEnabled = enabled
            let cell = controller.tableView(tableView, cellForRowAt: indexPath)
            let settingSwitch = try XCTUnwrap(cell.accessoryView as? UISwitch)
            XCTAssertEqual(settingSwitch.isOn, enabled)
            XCTAssertEqual(settingSwitch.accessibilityLabel, GDLocalizedString("settings.navilens.auto_snooze.title"))

            settingSwitch.isOn = !enabled
            settingSwitch.sendActions(for: .valueChanged)
            XCTAssertEqual(SettingsContext.shared.naviLensAutoSnoozeEnabled, !enabled)
        }
    }

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

        XCTAssertTrue(helper.sleepUntilForeground(autoSnoozeEnabled: settings.naviLensAutoSnoozeEnabled))
        XCTAssertEqual(sleepCount, 1)
        XCTAssertEqual(wakeCount, 0)
        XCTAssertEqual(state, .sleep)

        notificationCenter.post(name: Notification.Name.appDidBecomeActive, object: nil)

        wait(for: [wakeExpectation], timeout: 1.0)
        notificationCenter.post(name: Notification.Name.appDidBecomeActive, object: nil)
        XCTAssertEqual(sleepCount, 1)
        XCTAssertEqual(wakeCount, 1)
        XCTAssertEqual(state, .normal)
    }

    func testSleepUntilForegroundDoesNothingWhenAlreadySleeping() {
        let helper = NaviLensWakeOnForeground(notificationCenter: NotificationCenter(),
                                              appState: { .sleep },
                                              sleep: { XCTFail("Should not sleep again") },
                                              wake: { XCTFail("Should not wake without a pending foreground wake") })

        XCTAssertFalse(helper.sleepUntilForeground(autoSnoozeEnabled: settings.naviLensAutoSnoozeEnabled))
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

        XCTAssertTrue(helper.sleepUntilForeground(autoSnoozeEnabled: settings.naviLensAutoSnoozeEnabled))
        helper.wakeUp()
        notificationCenter.post(name: Notification.Name.appDidBecomeActive, object: nil)

        XCTAssertEqual(wakeCount, 1)
        XCTAssertEqual(state, .normal)
    }

}
