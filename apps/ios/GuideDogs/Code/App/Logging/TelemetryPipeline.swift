// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterHttp
import PersistenceExporter

struct TelemetryConfiguration {
    let endpoint: URL
    let headers: [(String, String)]

    init?(info: [String: Any]) {
        guard let endpoint = info["SOUNDSCAPE_OTEL_LOGS_ENDPOINT"] as? String,
              !endpoint.contains("$("),
              let components = URLComponents(string: endpoint),
              components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.fragment == nil, !components.path.isEmpty,
              let url = components.url else { return nil }
        self.endpoint = url
        let rawHeaders = info["SOUNDSCAPE_OTEL_LOGS_HEADERS"] as? String ?? ""
        if rawHeaders.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            headers = []
        } else {
            guard let data = rawHeaders.data(using: .utf8),
                  let dictionary = (try? JSONSerialization.jsonObject(with: data)) as? [String: String],
                  dictionary.allSatisfy({ key, value in
                      !key.isEmpty && key.utf8.allSatisfy { byte in
                          (65...90).contains(byte) || (97...122).contains(byte) || (48...57).contains(byte) ||
                          "!#$%&'*+-.^_`|~".utf8.contains(byte)
                      } && !value.contains("\r") && !value.contains("\n")
                  }) else { return nil }
            headers = dictionary.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
        }
    }
}

/// A process-local usage session. Backgrounding and device lock do not end it.
final class TelemetrySession {
    static let sleepTimeout: TimeInterval = 30 * 60

    private struct State {
        var id = UUID().uuidString
        var sleepingSince: Date?
    }

    private let state = Locked(initialValue: State())

    var id: String { state.protectedValue.id }

    func operationStateChanged(to operationState: OperationState, at now: Date = Date()) {
        state.locking { state in
            switch operationState {
            case .sleep, .snooze:
                // Switching between sleep and snooze must not restart the timeout.
                if state.sleepingSince == nil { state.sleepingSince = now }
            case .normal:
                if let since = state.sleepingSince, now.timeIntervalSince(since) >= Self.sleepTimeout {
                    state.id = UUID().uuidString
                }
                state.sleepingSince = nil
            }
        }
    }
}

struct TelemetryEvent {
    let name: String
    let timestamp: Date
    let attributes: [String: AttributeValue]

    init(name: String, timestamp: Date = Date(), properties: [String: String] = [:],
         clientID: String, sessionID: String, snapshot: [String: String] = [:]) {
        self.name = name
        self.timestamp = timestamp
        var values = properties.merging(snapshot) { current, _ in current }
        values["user_id"] = clientID
        values["session_id"] = sessionID
        // Identify this occurrence once; exports and persisted retries reuse these attributes.
        values["event_id"] = UUID().uuidString
        attributes = values.mapValues { .string($0) }
    }

    func emit(to logger: OpenTelemetryApi.Logger) {
        logger.logRecordBuilder()
            .setEventName(name)
            .setTimestamp(timestamp)
            .setSeverity(.info)
            .setAttributes(attributes)
            .emit()
    }
}

/// One revocable consent period. The same lock protects request starts and disk writes
/// against revocation. Network completion never holds this lock.
final class TelemetryConsent: Sendable {
    let active = Locked(initialValue: true)
    let session: URLSession

    init(session: URLSession? = nil) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        self.session = session ?? URLSession(configuration: configuration)
    }

    func revoke() {
        active.locking { $0 = false }
        session.invalidateAndCancel()
    }
}

final class ConsentHTTPClient: HTTPClient {
    private let consent: TelemetryConsent
    private let base: BaseHTTPClient

    init(consent: TelemetryConsent) {
        self.consent = consent
        base = BaseHTTPClient(session: consent.session)
    }

    func send(request: URLRequest, completion: @escaping (Result<HTTPURLResponse, Error>) -> Void) {
        let started = consent.active.locking { active in
            guard active else { return false }
            base.send(request: request, completion: completion)
            return true
        }
        if !started { completion(.failure(URLError(.cancelled))) }
    }

    func send(request: URLRequest) async throws -> HTTPURLResponse {
        try await withCheckedThrowingContinuation { continuation in
            send(request: request) { continuation.resume(with: $0) }
        }
    }
}

/// The outer gate serializes synchronous disk writes with revocation. The inner
/// network gate checks consent even during the decorator's unconditional shutdown flush.
final class ConsentLogExporter: LogRecordExporter {
    let consent: TelemetryConsent
    let exporter: any LogRecordExporter
    let protectsDiskWrites: Bool

    init(consent: TelemetryConsent, exporter: any LogRecordExporter, protectsDiskWrites: Bool = false) {
        self.consent = consent
        self.exporter = exporter
        self.protectsDiskWrites = protectsDiskWrites
    }

    func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
        if protectsDiskWrites {
            return consent.active.locking { active in
                guard active else { return .failure }
                return exporter.export(logRecords: logRecords, explicitTimeout: explicitTimeout)
            }
        }
        guard consent.active.protectedValue else { return .failure }
        return exporter.export(logRecords: logRecords, explicitTimeout: explicitTimeout)
    }

    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
        guard consent.active.protectedValue else { return .failure }
        return exporter.forceFlush(explicitTimeout: explicitTimeout)
    }

    func shutdown(explicitTimeout: TimeInterval?) {
        exporter.shutdown(explicitTimeout: explicitTimeout)
    }
}

struct TelemetryStorage {
    let root: URL

    func purge() throws {
        if FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
    }

    func open(resuming: Bool) throws -> URL {
        let marker = root.appendingPathComponent("current")
        let savedID = resuming ? try? String(contentsOf: marker, encoding: .utf8) : nil
        let identifier = savedID.flatMap(UUID.init(uuidString:))?.uuidString ?? UUID().uuidString
        if savedID == nil { try purge() }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
                                                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        var excludedRoot = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try excludedRoot.setResourceValues(values)
        let directory = root.appendingPathComponent(identifier, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        // Directory enumeration can resolve /var to /private/var on devices.
        // These are direct children, so compare names rather than aliased URLs.
        for child in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            where child.lastPathComponent != marker.lastPathComponent && child.lastPathComponent != identifier {
            try FileManager.default.removeItem(at: child)
        }
        try identifier.write(to: marker, atomically: true, encoding: .utf8)
        return directory
    }
}

/// Pipeline lifecycle and cleanup run on one utility queue. Consent revocation is
/// synchronous, so queued events and requests cannot cross a disable/re-enable boundary.
final class TelemetryController {
    static let persistencePreset = PersistencePerformancePreset(
        maxFileSize: 1 * 1_024 * 1_024, maxDirectorySize: 20 * 1_024 * 1_024,
        maxFileAgeForWrite: 4.75, minFileAgeForRead: 5.25, maxFileAgeForRead: 7 * 24 * 60 * 60,
        maxObjectsInFile: 500, maxObjectSize: 256 * 1_024, synchronousWrite: true,
        initialExportDelay: 5, defaultExportDelay: 5, minExportDelay: 1, maxExportDelay: 20,
        exportDelayChangeRate: 0.1)

    private let queue = DispatchQueue(label: "org.soundscape.telemetry", qos: .utility)
    private let current = Locked<TelemetryConsent?>(initialValue: nil)
    private let configuration: TelemetryConfiguration?
    private let storage: TelemetryStorage
    private let exporterFactory: (TelemetryConsent, TelemetryConfiguration) -> any LogRecordExporter
    private var processor: BatchLogRecordProcessor?
    private var provider: LoggerProviderSdk?
    private var pipelineConsent: TelemetryConsent?

    init(enabled: Bool, configuration: TelemetryConfiguration?, storage: TelemetryStorage,
         exporterFactory: @escaping (TelemetryConsent, TelemetryConfiguration) -> any LogRecordExporter = { consent, config in
             OtlpHttpLogExporter(endpoint: config.endpoint, httpClient: ConsentHTTPClient(consent: consent),
                                 envVarHeaders: config.headers, requeueOnFailure: false)
         }) {
        self.configuration = configuration
        self.storage = storage
        self.exporterFactory = exporterFactory
        transition(enabled: enabled, resuming: true)
    }

    var collecting: Bool { current.protectedValue?.active.protectedValue == true }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool { transition(enabled: enabled, resuming: false) }

    @discardableResult
    private func transition(enabled: Bool, resuming: Bool) -> Bool {
        current.locking { previous in
            if !resuming && enabled && previous?.active.protectedValue == true { return true }
            previous?.revoke()
            previous = nil
            if !resuming && enabled {
                do {
                    // Drain lifecycle work before purging so queued startup cannot
                    // recreate the old marker. The caller can now save renewed
                    // consent without making revoked records resumable on relaunch.
                    try queue.sync { try storage.purge() }
                } catch {
                    GDLogAppError("Unable to clear revoked telemetry storage: \(error.localizedDescription)")
                    return false
                }
            }
            let consent = enabled && configuration != nil ? TelemetryConsent() : nil
            previous = consent
            queue.async { [self] in
                _ = processor?.shutdown(explicitTimeout: 5)
                processor = nil
                provider = nil
                pipelineConsent = nil
                do {
                    // No exporter exists before opted-out launch cleanup has completed.
                    guard let consent = consent, consent.active.protectedValue, let configuration = configuration else {
                        try storage.purge()
                        return
                    }
                    let directory = try storage.open(resuming: resuming)
                    let network = ConsentLogExporter(consent: consent, exporter: exporterFactory(consent, configuration))
                    let persistence = PersistenceLogExporterDecorator(logRecordExporter: network, storageURL: directory,
                        exportCondition: { consent.active.protectedValue }, performancePreset: Self.persistencePreset)
                    let disk = ConsentLogExporter(consent: consent, exporter: persistence, protectsDiskWrites: true)
                    let batch = BatchLogRecordProcessor(logRecordExporter: disk, scheduleDelay: 2,
                                                        maxQueueSize: 512, maxExportBatchSize: 64)
                    processor = batch
                    provider = LoggerProviderBuilder().with(resource: Resource(attributes: [
                        "service.name": .string("soundscape"),
                        "service.version": .string(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"),
                        "service.build": .string(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown")
                    ])).with(processors: [batch]).build()
                    pipelineConsent = consent
                } catch {
                    consent?.revoke()
                    GDLogAppError("Unable to prepare telemetry storage: \(error.localizedDescription)")
                }
            }
            return true
        }
    }

    func record(_ makeEvent: () -> TelemetryEvent) {
        guard let consent = current.protectedValue, consent.active.protectedValue else { return }
        let event = makeEvent()
        queue.async { [self] in
            guard consent === pipelineConsent, consent.active.protectedValue, let provider = provider else { return }
            event.emit(to: provider.get(instrumentationScopeName: "GDATelemetry"))
        }
    }

    /// Close a consent period without deleting its already persisted records, as
    /// on normal process exit. Reopening storage is safe only while still opted in.
    func shutdown(completion: @escaping () -> Void) {
        current.locking { consent in
            consent?.revoke()
            consent = nil
            queue.async { [self] in
                _ = processor?.shutdown(explicitTimeout: 5)
                processor = nil
                provider = nil
                pipelineConsent = nil
                completion()
            }
        }
    }

    /// Batch processor flush exports only to our synchronous disk writer; calling
    /// the persistence exporter's forceFlush here would upload the entire backlog.
    func persist(completion: @escaping () -> Void) {
        queue.async { [self] in
            processor?.forceFlush(timeout: 5)
            completion()
        }
    }
}
