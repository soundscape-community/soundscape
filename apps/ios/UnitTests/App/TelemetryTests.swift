// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import UIKit
import XCTest
import OpenTelemetryApi
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterHttp
import OpenTelemetryProtocolExporterCommon
import PersistenceExporter
@testable import Soundscape

private final class RecordingLogExporter: LogRecordExporter {
    let records = Locked<[ReadableLogRecord]>(initialValue: [])
    let result = Locked(initialValue: ExportResult.success)
    let attempts = Locked(initialValue: 0)
    let onShutdown: @Sendable () -> Void

    init(onShutdown: @escaping @Sendable () -> Void = {}) {
        self.onShutdown = onShutdown
    }

    func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
        attempts.locking { $0 += 1 }
        let status = result.protectedValue
        if status == .success { records.locking { $0 += logRecords } }
        return status
    }
    func shutdown(explicitTimeout: TimeInterval?) { onShutdown() }
    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult { .success }
}

final class TelemetryTests: XCTestCase {
    private var root: URL!
    private var configuration: TelemetryConfiguration {
        TelemetryConfiguration(info: ["SOUNDSCAPE_OTEL_LOGS_ENDPOINT": "https://example.invalid/v1/logs"])!
    }

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
    }

    private func event(_ name: String = "test") -> TelemetryEvent {
        TelemetryEvent(name: name, clientID: "test-client", sessionID: "test-session")
    }

    private func eventID(_ attributes: [String: AttributeValue]) throws -> String {
        let value: String?
        if case .string(let string) = attributes["event_id"] {
            value = string
        } else {
            value = nil
        }
        return try XCTUnwrap(value, "event_id must be a string attribute")
    }

    private func records() -> [ReadableLogRecord] {
        let exporter = RecordingLogExporter()
        let processor = SimpleLogRecordProcessor(logRecordExporter: exporter)
        let provider = LoggerProviderBuilder().with(processors: [processor]).build()
        event().emit(to: provider.get(instrumentationScopeName: "tests"))
        return exporter.records.protectedValue
    }

    private func drain(_ controller: TelemetryController) {
        let done = expectation(description: "persisted")
        controller.persist { done.fulfill() }
        wait(for: [done], timeout: 10)
    }

    private func close(_ controller: TelemetryController) {
        let done = expectation(description: "closed")
        controller.shutdown { done.fulfill() }
        wait(for: [done], timeout: 10)
    }

    private func files(_ directory: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { UInt64($0.lastPathComponent) != nil }
    }

    func testEventMappingPreservesTimestampAndPropertyPrecedence() throws {
        let exporter = RecordingLogExporter()
        let processor = SimpleLogRecordProcessor(logRecordExporter: exporter)
        let provider = LoggerProviderBuilder().with(processors: [processor]).build()
        let timestamp = Date(timeIntervalSince1970: 123456)
        TelemetryEvent(name: "device_snapshot", timestamp: timestamp,
                       properties: ["locale": "en-GB", "user_id": "caller", "event_id": "caller", "session_id": "caller"],
                       clientID: "client", sessionID: "session",
                       snapshot: ["locale": "en-US", "app.state": "active", "user_id": "snapshot",
                                  "event_id": "snapshot", "session_id": "snapshot"])
            .emit(to: provider.get(instrumentationScopeName: "tests"))
        let record = try XCTUnwrap(exporter.records.protectedValue.first)
        XCTAssertEqual(record.eventName, "device_snapshot")
        XCTAssertNil(record.body)
        XCTAssertEqual(record.severity, .info)
        XCTAssertEqual(record.timestamp, timestamp)
        XCTAssertEqual(record.attributes["locale"], .string("en-GB"))
        XCTAssertEqual(record.attributes["user_id"], .string("client"))
        XCTAssertEqual(record.attributes["session_id"], .string("session"))
        XCTAssertEqual(record.attributes["app.state"], .string("active"))
        let eventID = try eventID(record.attributes)
        XCTAssertEqual(UUID(uuidString: eventID)?.uuidString, eventID)
    }

    func testSeparateEventsReceiveDifferentUUIDs() throws {
        let timestamp = Date(timeIntervalSince1970: 123456)
        let first = try eventID(TelemetryEvent(name: "test", timestamp: timestamp, clientID: "client", sessionID: "session").attributes)
        let second = try eventID(TelemetryEvent(name: "test", timestamp: timestamp, clientID: "client", sessionID: "session").attributes)
        XCTAssertFalse(first.isEmpty)
        XCTAssertFalse(second.isEmpty)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(UUID(uuidString: first)?.uuidString, first)
        XCTAssertEqual(UUID(uuidString: second)?.uuidString, second)
    }

    func testEventAndSessionIDsCannotBeOverriddenAndSurviveRepeatedEmission() throws {
        let exporter = RecordingLogExporter()
        let processor = SimpleLogRecordProcessor(logRecordExporter: exporter)
        let provider = LoggerProviderBuilder().with(processors: [processor]).build()
        let logger = provider.get(instrumentationScopeName: "tests")
        for (properties, snapshot) in [
            (["event_id": "caller", "session_id": "caller"], [:]),
            ([:], ["event_id": "snapshot", "session_id": "snapshot"]),
            (["event_id": "caller", "session_id": "caller"], ["event_id": "snapshot", "session_id": "snapshot"])
        ] {
            let original = TelemetryEvent(name: "test", properties: properties, clientID: "client",
                                          sessionID: "session", snapshot: snapshot)
            let eventID = try eventID(original.attributes)
            XCTAssertNotNil(UUID(uuidString: eventID))
            original.emit(to: logger)
            original.emit(to: logger)
            XCTAssertEqual(exporter.records.protectedValue.suffix(2).map { $0.attributes["event_id"] },
                           [.string(eventID), .string(eventID)])
            XCTAssertEqual(exporter.records.protectedValue.suffix(2).map { $0.attributes["session_id"] },
                           [.string("session"), .string("session")])
        }
        XCTAssertEqual(exporter.records.protectedValue.count, 6)
    }

    func testNewAppProcessesHaveDifferentSessionUUIDs() {
        let first = TelemetrySession()
        let second = TelemetrySession()
        XCTAssertNotNil(UUID(uuidString: first.id))
        XCTAssertNotNil(UUID(uuidString: second.id))
        XCTAssertNotEqual(first.id, second.id)
    }

    func testShortSleepPreservesSessionAndThirtyMinuteSleepRotatesOnlyOnWake() {
        let session = TelemetrySession()
        let originalID = session.id
        let start = Date(timeIntervalSince1970: 123456)
        session.operationStateChanged(to: .sleep, at: start)
        session.operationStateChanged(to: .normal, at: start.addingTimeInterval(30 * 60 - 1))
        XCTAssertEqual(session.id, originalID)

        let nextSleep = start.addingTimeInterval(60 * 60)
        session.operationStateChanged(to: .sleep, at: nextSleep)
        // Events recorded during sleep still belong to the existing session.
        XCTAssertEqual(session.id, originalID)
        session.operationStateChanged(to: .normal, at: nextSleep.addingTimeInterval(30 * 60))
        let newID = session.id
        XCTAssertNotEqual(newID, originalID)
        XCTAssertNotNil(UUID(uuidString: newID))
        session.operationStateChanged(to: .normal, at: nextSleep.addingTimeInterval(2 * 60 * 60))
        XCTAssertEqual(session.id, newID, "Active time must not expire a session")
    }

    func testSleepAndSnoozeShareOneTimeoutAndShortSleepsDoNotAccumulate() {
        let session = TelemetrySession()
        let originalID = session.id
        let start = Date(timeIntervalSince1970: 123456)
        for minutes in [0.0, 30.0] {
            let sleep = start.addingTimeInterval(minutes * 60)
            session.operationStateChanged(to: .sleep, at: sleep)
            session.operationStateChanged(to: .normal, at: sleep.addingTimeInterval(20 * 60))
            XCTAssertEqual(session.id, originalID)
        }

        session.operationStateChanged(to: .sleep, at: start.addingTimeInterval(60 * 60))
        session.operationStateChanged(to: .snooze, at: start.addingTimeInterval(80 * 60))
        session.operationStateChanged(to: .sleep, at: start.addingTimeInterval(85 * 60))
        session.operationStateChanged(to: .normal, at: start.addingTimeInterval(90 * 60))
        XCTAssertNotEqual(session.id, originalID)

        let afterSleep = session.id
        session.operationStateChanged(to: .snooze, at: start.addingTimeInterval(100 * 60))
        session.operationStateChanged(to: .normal, at: start.addingTimeInterval(131 * 60))
        XCTAssertNotEqual(session.id, afterSleep)
    }

    func testEventsKeepTheirCapturedSessionAfterWake() {
        let session = TelemetrySession()
        let originalID = session.id
        let original = TelemetryEvent(name: "before_sleep", clientID: "client", sessionID: session.id)
        let start = Date(timeIntervalSince1970: 123456)
        session.operationStateChanged(to: .sleep, at: start)
        session.operationStateChanged(to: .normal, at: start.addingTimeInterval(31 * 60))
        let wake = TelemetryEvent(name: "wake_state.normal", clientID: "client", sessionID: session.id)
        let exporter = RecordingLogExporter()
        let processor = SimpleLogRecordProcessor(logRecordExporter: exporter)
        let provider = LoggerProviderBuilder().with(processors: [processor]).build()
        let logger = provider.get(instrumentationScopeName: "tests")
        original.emit(to: logger)
        wake.emit(to: logger)
        XCTAssertNotEqual(originalID, session.id)
        XCTAssertEqual(exporter.records.protectedValue.map { $0.attributes["session_id"] },
                       [.string(originalID), .string(session.id)])
    }

    func testConfigurationFailsClosed() {
        for endpoint in ["", "$(SOUNDSCAPE_OTEL_LOGS_ENDPOINT)", "http://host/v1/logs", "https:///v1/logs",
                         "https://user:password@host/v1/logs", "https://host", "https://host/v1/logs#fragment"] {
            XCTAssertNil(TelemetryConfiguration(info: ["SOUNDSCAPE_OTEL_LOGS_ENDPOINT": endpoint]), endpoint)
        }
        for headers in ["[]", "null", "{\"key\":1}", "{\"bad key\":\"value\"}", "{\"key\":\"a\\nb\"}", "$(HEADERS)"] {
            XCTAssertNil(TelemetryConfiguration(info: ["SOUNDSCAPE_OTEL_LOGS_ENDPOINT": "https://host/v1/logs",
                                                       "SOUNDSCAPE_OTEL_LOGS_HEADERS": headers]), headers)
        }
        let config = TelemetryConfiguration(info: ["SOUNDSCAPE_OTEL_LOGS_ENDPOINT": "https://host/custom/logs",
                                                   "SOUNDSCAPE_OTEL_LOGS_HEADERS": "{\"Authorization\":\"Bearer token\"}"])
        XCTAssertEqual(config?.headers.first?.0, "Authorization")
        XCTAssertEqual(config?.headers.first?.1, "Bearer token")
        XCTAssertEqual(configuration.headers.count, 0)
    }

    func testDefaultIsOptedOutAndSavedChoicesSurviveInitialization() throws {
        let suite = "TelemetryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertTrue(SettingsContext(userDefaults: defaults).telemetryOptout)
        defaults.set(false, forKey: "GDASettingsTelemetryOptout")
        XCTAssertFalse(SettingsContext(userDefaults: defaults).telemetryOptout)
        defaults.set(true, forKey: "GDASettingsTelemetryOptout")
        XCTAssertTrue(SettingsContext(userDefaults: defaults).telemetryOptout)
    }

    func testSharingRequiresAnExplicitChoiceAndBothChoicesSurviveRelaunch() throws {
        let suite = "TelemetryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsContext(userDefaults: defaults)
        XCTAssertFalse(settings.telemetryConsentChoiceMade)
        XCTAssertFalse(settings.telemetryEnabled)

        // A legacy preference alone must not authorize collection.
        for optedOut in [false, true] {
            settings.telemetryOptout = optedOut
            let relaunched = SettingsContext(userDefaults: defaults)
            XCTAssertFalse(relaunched.telemetryConsentChoiceMade)
            XCTAssertFalse(relaunched.telemetryEnabled)
            XCTAssertNil(defaults.persistentDomain(forName: suite)?["GDASettingsTelemetryConsentChoiceMade"])
        }

        for optedOut in [false, true] {
            settings.telemetryOptout = optedOut
            settings.telemetryConsentChoiceMade = true
            let relaunched = SettingsContext(userDefaults: defaults)
            XCTAssertTrue(relaunched.telemetryConsentChoiceMade)
            XCTAssertEqual(relaunched.telemetryEnabled, !optedOut)
            XCTAssertEqual(relaunched.telemetryOptout, optedOut)
        }
    }

    func testTelemetryChangesRecordBothExplicitChoices() {
        let defaults = UserDefaults.standard
        let choiceKey = "GDASettingsTelemetryConsentChoiceMade"
        let optoutKey = "GDASettingsTelemetryOptout"
        let previousChoice = defaults.object(forKey: choiceKey)
        let previousOptout = defaults.object(forKey: optoutKey)
        let previousEnabled = GDATelemetry.enabled
        defer {
            GDATelemetry.setConsent(sharingEnabled: previousEnabled)
            defaults.set(previousChoice, forKey: choiceKey)
            defaults.set(previousOptout, forKey: optoutKey)
        }

        for sharingEnabled in [true, false] {
            SettingsContext.shared.telemetryConsentChoiceMade = false
            GDATelemetry.setConsent(sharingEnabled: sharingEnabled)
            XCTAssertTrue(SettingsContext.shared.telemetryConsentChoiceMade)
            XCTAssertEqual(SettingsContext.shared.telemetryOptout, !sharingEnabled)
            XCTAssertEqual(GDATelemetry.enabled, sharingEnabled)
        }
    }

    func testBackgroundDrainPersistsWithoutUploadingAndRelaunchReplays() throws {
        let storage = TelemetryStorage(root: root)
        let exporter = RecordingLogExporter()
        let first = TelemetryController(enabled: true, configuration: configuration, storage: storage) { _, _ in exporter }
        let session = TelemetrySession()
        let originalSessionID = session.id
        let original = TelemetryEvent(name: "offline", clientID: "test-client", sessionID: originalSessionID)
        let originalEventID = try eventID(original.attributes)
        first.record { original }
        drain(first)
        XCTAssertEqual(exporter.attempts.protectedValue, 0)
        let directory = try storage.open(resuming: true)
        XCTAssertFalse(try files(directory).isEmpty)
        close(first)
        XCTAssertEqual(exporter.attempts.protectedValue, 0, "Shutdown must not upload revoked records")
        XCTAssertEqual(try storage.open(resuming: true), directory)
        // Simulate a relaunch after the SDK's minimum readable file age. Keep
        // record timestamps intact while avoiding a timing-sensitive second retry.
        let persisted = try XCTUnwrap(files(directory).first)
        let previousLaunch = String(UInt64(Date().addingTimeInterval(-60).timeIntervalSinceReferenceDate * 1_000))
        try FileManager.default.moveItem(at: persisted, to: directory.appendingPathComponent(previousLaunch))

        let relaunched = TelemetryController(enabled: true, configuration: configuration, storage: storage) { _, _ in exporter }
        XCTAssertNotEqual(TelemetrySession().id, originalSessionID)
        let delivered = expectation(description: "replayed after relaunch")
        DispatchQueue.global().async {
            for _ in 0..<400 {
                if !exporter.records.protectedValue.isEmpty { delivered.fulfill(); return }
                Thread.sleep(forTimeInterval: 0.025)
            }
        }
        wait(for: [delivered], timeout: 12)
        XCTAssertEqual(exporter.records.protectedValue.map(\.eventName), ["offline"])
        XCTAssertEqual(exporter.records.protectedValue.first?.attributes["event_id"], .string(originalEventID))
        XCTAssertEqual(exporter.records.protectedValue.first?.attributes["session_id"], .string(originalSessionID))
        XCTAssertEqual(exporter.records.protectedValue.first?.resource.attributes["service.name"], .string("soundscape"))
        XCTAssertNotNil(exporter.records.protectedValue.first?.resource.attributes["service.version"])
        XCTAssertNotNil(exporter.records.protectedValue.first?.resource.attributes["service.build"])
        close(relaunched)
        XCTAssertTrue(try files(directory).isEmpty)
    }

    func testFailedUploadRetainsRecordsUntilSuccessfulReplay() throws {
        let exporter = RecordingLogExporter()
        exporter.result.protectedValue = .failure
        let decorator = PersistenceLogExporterDecorator(logRecordExporter: exporter, storageURL: root,
            exportCondition: { false }, performancePreset: TelemetryController.persistencePreset)
        let originalRecords = records()
        let originalEventID = try eventID(XCTUnwrap(originalRecords.first).attributes)
        XCTAssertEqual(decorator.export(logRecords: originalRecords), .success)
        _ = decorator.forceFlush()
        XCTAssertFalse(try files(root).isEmpty)
        exporter.result.protectedValue = .success
        _ = decorator.forceFlush()
        XCTAssertEqual(exporter.records.protectedValue.count, 1)
        XCTAssertEqual(exporter.records.protectedValue.first?.attributes["event_id"], .string(originalEventID))
        XCTAssertEqual(exporter.records.protectedValue.first?.attributes["session_id"], originalRecords.first?.attributes["session_id"])
        XCTAssertTrue(try files(root).isEmpty)
        decorator.shutdown()
    }

    func testOTLPFailureRetriesOnlyThePersistedBatch() throws {
        let client = ScriptedTelemetryHTTPClient()
        let otlp = OtlpHttpLogExporter(endpoint: configuration.endpoint,
            config: OtlpConfiguration(compression: .none, exportAsJson: false), httpClient: client,
            envVarHeaders: [("Authorization", "Bearer test")], requeueOnFailure: false)
        let decorator = PersistenceLogExporterDecorator(logRecordExporter: otlp, storageURL: root,
            exportCondition: { false }, performancePreset: TelemetryController.persistencePreset)
        let originalRecords = records()
        let originalEventID = try eventID(XCTUnwrap(originalRecords.first).attributes)
        _ = decorator.export(logRecords: originalRecords)
        _ = decorator.forceFlush()
        XCTAssertFalse(try files(root).isEmpty)
        _ = decorator.forceFlush()
        XCTAssertTrue(try files(root).isEmpty)
        let requests = client.requests.protectedValue
        XCTAssertEqual(requests.count, 2)
        for request in requests {
            XCTAssertEqual(request.url, configuration.endpoint)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test")
            let payload = try Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest(
                serializedBytes: XCTUnwrap(request.httpBody))
            let logs = payload.resourceLogs.flatMap(\.scopeLogs).flatMap(\.logRecords)
            XCTAssertEqual(logs.count, 1, "HTTP must not also requeue failed persisted logs")
            XCTAssertEqual(logs.first?.eventName, "test")
            let eventID = logs.first?.attributes.first(where: { $0.key == "event_id" })?.value.stringValue
            XCTAssertEqual(eventID, originalEventID)
            let sessionID = logs.first?.attributes.first(where: { $0.key == "session_id" })?.value.stringValue
            XCTAssertEqual(sessionID, "test-session")
        }
        decorator.shutdown()
    }

    func testOptoutDeletesMemoryAndDiskAndRapidReenableUsesNewDirectory() throws {
        let storage = TelemetryStorage(root: root)
        let exporter = RecordingLogExporter()
        let controller = TelemetryController(enabled: true, configuration: configuration, storage: storage) { _, _ in exporter }
        controller.record { self.event("old-disk") }
        drain(controller)
        let oldDirectory = try storage.open(resuming: true)
        controller.record { self.event("old-memory") }
        controller.setEnabled(false)
        XCTAssertFalse(controller.collecting)
        controller.record { XCTFail("Opted-out events must not be constructed"); return self.event() }
        controller.setEnabled(true)
        controller.record { self.event("new") }
        drain(controller)
        let newDirectory = try storage.open(resuming: true)
        XCTAssertNotEqual(oldDirectory, newDirectory)
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldDirectory.path))
        close(controller)
        let replay = PersistenceLogExporterDecorator(logRecordExporter: exporter, storageURL: newDirectory,
            exportCondition: { false }, performancePreset: TelemetryController.persistencePreset)
        _ = replay.forceFlush()
        XCTAssertEqual(exporter.records.protectedValue.map(\.eventName), ["new"])
        replay.shutdown()
    }

    func testRenewedOptinWaitsForRevokedStorageBeforeReturning() throws {
        let storage = TelemetryStorage(root: root)
        let shuttingDown = expectation(description: "old pipeline shutdown blocked")
        let release = DispatchSemaphore(value: 0)
        let firstShutdown = Locked(initialValue: true)
        let exporter = RecordingLogExporter {
            let shouldBlock = firstShutdown.locking { first -> Bool in
                defer { first = false }
                return first
            }
            if shouldBlock {
                shuttingDown.fulfill()
                _ = release.wait(timeout: .now() + 5)
            }
        }
        let controller = TelemetryController(enabled: true, configuration: configuration, storage: storage) { _, _ in exporter }
        controller.record { self.event("revoked") }
        drain(controller)
        let oldDirectory = try storage.open(resuming: true)
        XCTAssertFalse(try files(oldDirectory).isEmpty)
        controller.setEnabled(false)
        wait(for: [shuttingDown], timeout: 5)
        let enabling = expectation(description: "renewing consent")
        let enabled = expectation(description: "renewed consent safe to save")
        let returned = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            enabling.fulfill()
            XCTAssertTrue(controller.setEnabled(true))
            // Simulate termination as soon as renewed consent can be saved:
            // the old directory must already be gone, regardless of queued startup.
            XCTAssertFalse(FileManager.default.fileExists(atPath: oldDirectory.path))
            returned.signal()
            enabled.fulfill()
        }
        wait(for: [enabling], timeout: 5)
        XCTAssertEqual(returned.wait(timeout: .now() + 0.1), .timedOut)
        release.signal()
        wait(for: [enabled], timeout: 10)
        drain(controller)
        XCTAssertNotEqual(try storage.open(resuming: true), oldDirectory)
        close(controller)
        XCTAssertEqual(exporter.attempts.protectedValue, 0)
    }

    func testOptoutLaunchAndInvalidConfigurationPurgeLeftovers() throws {
        for enabled in [false, true] {
            try Data("leftover".utf8).write(to: root.appendingPathComponent("old"))
            let controller = TelemetryController(enabled: enabled, configuration: nil, storage: TelemetryStorage(root: root)) { _, _ in
                XCTFail("Must not create an exporter")
                return RecordingLogExporter()
            }
            drain(controller)
            XCTAssertFalse(controller.collecting)
            XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
            close(controller)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }
    }

    func testStorageProtectionAndBackupExclusion() throws {
        let directory = try TelemetryStorage(root: root).open(resuming: false)
        XCTAssertEqual(try root.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        // Simulator filesystems do not expose iOS data-protection attributes.
        #if !targetEnvironment(simulator)
        let attributes = try FileManager.default.attributesOfItem(atPath: directory.path)
        XCTAssertEqual(attributes[.protectionKey] as? FileProtectionType, .completeUntilFirstUserAuthentication)
        #else
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
        #endif
    }

    func testRevokedGatesBlockDiskAndShutdownNetworkExports() throws {
        let consent = TelemetryConsent()
        let exporter = RecordingLogExporter()
        let network = ConsentLogExporter(consent: consent, exporter: exporter)
        let persistence = PersistenceLogExporterDecorator(logRecordExporter: network, storageURL: root,
            exportCondition: { false }, performancePreset: TelemetryController.persistencePreset)
        let disk = ConsentLogExporter(consent: consent, exporter: persistence, protectsDiskWrites: true)
        XCTAssertEqual(disk.export(logRecords: records()), .success)
        consent.revoke()
        XCTAssertEqual(disk.export(logRecords: records()), .failure)
        disk.shutdown()
        XCTAssertEqual(exporter.attempts.protectedValue, 0)
    }

    func testRevocationWaitsForInProgressDiskWrite() {
        let consent = TelemetryConsent()
        let entered = expectation(description: "writing")
        let revoked = expectation(description: "revoked")
        let release = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            consent.active.locking { active in
                XCTAssertTrue(active)
                entered.fulfill()
                _ = release.wait(timeout: .now() + 5)
            }
        }
        wait(for: [entered], timeout: 5)
        DispatchQueue.global().async { consent.revoke(); revoked.fulfill() }
        release.signal()
        wait(for: [revoked], timeout: 5)
        XCTAssertFalse(consent.active.protectedValue)
    }

    func testRevokedHTTPClientRejectsRequests() {
        let consent = TelemetryConsent()
        let client = ConsentHTTPClient(consent: consent)
        consent.revoke()
        let done = expectation(description: "request rejected")
        client.send(request: URLRequest(url: configuration.endpoint)) { result in
            if case .failure(let error) = result {
                XCTAssertEqual((error as? URLError)?.code, .cancelled)
            } else { XCTFail("Revoked request succeeded") }
            done.fulfill()
        }
        wait(for: [done], timeout: 2)
    }

    func testRevocationCancelsAnOutstandingHTTPRequest() {
        let started = expectation(description: "request started")
        let stopped = expectation(description: "request cancelled")
        let completed = expectation(description: "completion cancelled")
        HoldingTelemetryURLProtocol.started.protectedValue = { started.fulfill() }
        HoldingTelemetryURLProtocol.stopped.protectedValue = { stopped.fulfill() }
        defer {
            HoldingTelemetryURLProtocol.started.protectedValue = nil
            HoldingTelemetryURLProtocol.stopped.protectedValue = nil
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HoldingTelemetryURLProtocol.self]
        let consent = TelemetryConsent(session: URLSession(configuration: config))
        let client = ConsentHTTPClient(consent: consent)
        client.send(request: URLRequest(url: configuration.endpoint)) { result in
            if case .failure(let error) = result {
                XCTAssertEqual((error as? URLError)?.code, .cancelled)
            } else { XCTFail("Cancelled upload succeeded") }
            completed.fulfill()
        }
        wait(for: [started], timeout: 5)
        consent.revoke()
        wait(for: [stopped, completed], timeout: 5)
    }

    @MainActor
    func testSettingsRestoresTelemetrySectionAndAccessibleSwitch() throws {
        let settings = try XCTUnwrap(UIStoryboard(name: "Settings", bundle: .main)
            .instantiateInitialViewController() as? SettingsViewController)
        settings.loadViewIfNeeded()
        XCTAssertEqual(settings.numberOfSections(in: settings.tableView), 9)
        let cell = try XCTUnwrap(settings.tableView(settings.tableView, cellForRowAt: IndexPath(row: 0, section: 8))
            as? TelemetrySettingsTableViewCell)
        XCTAssertEqual(cell.telemetrySwitch?.isOn, GDATelemetry.enabled)
        XCTAssertEqual(cell.telemetrySwitch?.accessibilityLabel, GDLocalizedString("settings.section.share_usage_data"))
        XCTAssertEqual(settings.tableView(settings.tableView, titleForHeaderInSection: 8), GDLocalizedString("settings.section.telemetry"))
        XCTAssertEqual(settings.tableView(settings.tableView, titleForFooterInSection: 8), GDLocalizedString("settings.section.telemetry.footer"))
        cell.telemetrySwitch?.isOn = !GDATelemetry.enabled
        cell.configure()
        XCTAssertEqual(cell.telemetrySwitch?.isOn, GDATelemetry.enabled)
    }

    // Accelerate only scheduling and file rotation; retain production size and retention limits.
    private var fastPreset: PersistencePerformancePreset {
        PersistencePerformancePreset(maxFileSize: 1_024 * 1_024, maxDirectorySize: 20 * 1_024 * 1_024,
            maxFileAgeForWrite: 0, minFileAgeForRead: 0, maxFileAgeForRead: 7 * 24 * 60 * 60,
            maxObjectsInFile: 500, maxObjectSize: 256 * 1_024, synchronousWrite: true,
            initialExportDelay: 0.01, defaultExportDelay: 0.01, minExportDelay: 0.01, maxExportDelay: 0.02,
            exportDelayChangeRate: 0.1)
    }

    func testExpiredAndCorruptFilesAreDiscardedWithoutExport() throws {
        let expiredName = String(UInt64(Date().addingTimeInterval(-8 * 24 * 60 * 60).timeIntervalSinceReferenceDate * 1_000))
        let corruptName = String(UInt64(Date().addingTimeInterval(-60).timeIntervalSinceReferenceDate * 1_000))
        try Data("expired".utf8).write(to: root.appendingPathComponent(expiredName))
        try Data("corrupt".utf8).write(to: root.appendingPathComponent(corruptName))
        let exporter = RecordingLogExporter()
        let decorator = PersistenceLogExporterDecorator(logRecordExporter: exporter, storageURL: root,
            performancePreset: fastPreset)
        let deleted = expectation(description: "expired and corrupt files deleted")
        DispatchQueue.global().async {
            for _ in 0..<100 {
                if (try? self.files(self.root).isEmpty) == true { deleted.fulfill(); return }
                Thread.sleep(forTimeInterval: 0.02)
            }
        }
        wait(for: [deleted], timeout: 5)
        XCTAssertEqual(exporter.attempts.protectedValue, 0)
        decorator.shutdown()
    }

    func testStorageTargetPrunesOldestFiles() throws {
        let old = Date().addingTimeInterval(-120).timeIntervalSinceReferenceDate * 1_000
        let names = (0..<22).map { String(UInt64(old) + UInt64($0)) }
        for name in names { try Data(repeating: 32, count: 1_024 * 1_024).write(to: root.appendingPathComponent(name)) }
        let exporter = RecordingLogExporter()
        let decorator = PersistenceLogExporterDecorator(logRecordExporter: exporter, storageURL: root,
            exportCondition: { false }, performancePreset: TelemetryController.persistencePreset)
        _ = decorator.export(logRecords: records())
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(names[0]).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(names[1]).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(names.last!).path))
        // The SDK prunes before file creation: the target can be exceeded by the new file.
        XCTAssertLessThanOrEqual(try files(root).count, 21)
        decorator.shutdown()
    }
}

private final class HoldingTelemetryURLProtocol: URLProtocol {
    static let started = Locked<(() -> Void)?>(initialValue: nil)
    static let stopped = Locked<(() -> Void)?>(initialValue: nil)
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.started.protectedValue?() }
    override func stopLoading() { Self.stopped.protectedValue?() }
}

private final class ScriptedTelemetryHTTPClient: HTTPClient {
    let requests = Locked<[URLRequest]>(initialValue: [])
    func send(request: URLRequest, completion: @escaping (Result<HTTPURLResponse, Error>) -> Void) {
        let count = requests.locking { values -> Int in values.append(request); return values.count }
        if count == 1 {
            completion(.failure(URLError(.cannotConnectToHost)))
        } else {
            completion(.success(HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!))
        }
    }
    func send(request: URLRequest) async throws -> HTTPURLResponse {
        try await withCheckedThrowingContinuation { continuation in
            send(request: request) { continuation.resume(with: $0) }
        }
    }
}
