# Telemetry

Telemetry is optional and defaults to **off** in Debug, AdHoc, and Release. Existing
saved preferences are preserved. Settings → Telemetry → Share Usage Data controls
consent. No collector configuration is included in the repository.

## Collector configuration

Set these build settings for each configuration that should support telemetry:

- `SOUNDSCAPE_OTEL_LOGS_ENDPOINT`: a full HTTPS OTLP logs URL, including the path
  (for example `https://collector.example.org/v1/logs`). HTTP, credentials in the
  URL, fragments, missing hosts, and missing paths are rejected.
- `SOUNDSCAPE_OTEL_LOGS_HEADERS`: optional JSON dictionary whose keys and values
  are strings, for example `{"Authorization":"Bearer token"}`. Empty means no
  extra headers. Invalid JSON or invalid header names/line breaks disable telemetry.

These settings are expanded into Info.plist. Missing or invalid configuration
stops collection as well as export, even if the saved preference is enabled.
Build setting values are visible in the app bundle; do not embed privileged secrets.

In an xcconfig, `//` begins a comment, including inside quotes. Escape the URL
using an empty build-setting expansion between the slashes:

```xcconfig
SOUNDSCAPE_OTEL_LOGS_ENDPOINT = https:/$()/collector.example.org/v1/logs
SOUNDSCAPE_OTEL_LOGS_HEADERS = {"Authorization":"Bearer token"}
```

The Debug, AdHoc, and Release xcconfigs contain empty defaults. Replace these
values in your distribution configuration or override them on the xcodebuild
command line. Verify the expanded values in the built app's Info.plist.

## Records and delivery

OpenTelemetry Swift and Swift Core are pinned to 2.6.0. Existing `GDATelemetry`
calls emit INFO logs with the event name in both `eventName` and the string body,
the occurrence timestamp, and string attributes. `user_id` is the existing client
ID and overrides caller properties. Caller properties override helper snapshot
properties. Screen views use `screen_view` and `screen_name`; value events use
`value`. Existing device, app, accessibility, and experiment snapshots remain.
The resource contains `service.name=soundscape`, `service.version`, and
`service.build`. Pipeline startup does not instantiate `AppContext`.

The pipeline is:

```text
LoggerProviderSdk → BatchLogRecordProcessor → consent disk gate
→ PersistenceLogExporterDecorator → consent network gate → OtlpHttpLogExporter
```

The memory queue holds up to 512 records, exporting batches of 64 every 2 seconds.
The persistence decorator writes synchronously on the batch processor's worker,
then delivers asynchronously on its own export worker. HTTP requeue is disabled;
the decorator alone owns retry and replay. Its low-runtime-impact preset is copied
with 7-day retention, a 20 MiB directory target, 1 MiB files, and synchronous writes.
The preset follows the [SDK 2.6.0 definition](https://github.com/open-telemetry/opentelemetry-swift/blob/2.6.0/Sources/Exporters/Persistence/PersistencePerformancePreset.swift).
The SDK prunes oldest files before creating a new file, so the directory target
can temporarily be exceeded by the newest file. Individual serialized batches
over 256 KiB can be dropped by the SDK.

Records live in Application Support/SoundscapeTelemetry in a directory for each
consent period. The directory is excluded from backups and inherits file
protection allowing access after the first device unlock. An opted-in relaunch
reopens the same directory. On scene backgrounding, an iOS background task drains
the memory batch to disk without waiting for the stored backlog to upload.

Confirming opt-out revokes collection and request starts, cancels outstanding
URLSession requests, suppresses the opt-out event, and serializes shutdown and
memory/disk cleanup. Re-enabling waits for queued cleanup and synchronously purges
old storage before the enabled preference is saved, then creates a fresh consent
period. If purging fails, consent remains disabled. Revoked tokens
prevent SDK shutdown flushes from uploading old records. Opted-out launches purge
leftover storage before any exporter can be created. Automated app tests disable
real export (the existing `-TESTING` launch argument or XCTest detection); unit
tests use injected exporters and URLProtocol stubs.

Delivery is best effort. Records in memory can be lost on abrupt termination,
and ambiguous network failures can cause duplicates. Retention and storage limits
also discard records. Automatic tracing, metrics, and crash reporting are outside
this integration.

## Verification

Run the Soundscape scheme's UnitTests, including `TelemetryTests`, and build Debug,
AdHoc, and Release. Run `apps/ios/Scripts/LocalizationLinter/main.swift` from
`apps/ios`. Tests cover configuration, consent defaults and saved preferences,
event mapping, offline persistence/relaunch replay, failed uploads, expiry,
pruning, corruption, background draining, rapid opt-out/re-enable, disk-write
revocation, HTTP cancellation, and the settings switch's accessibility label.

For device verification with a test collector:

1. Check a fresh installation leaves Share Usage Data off. Enable it and verify
   snapshot and interaction log records arrive with the expected attributes.
2. Use VoiceOver to focus and toggle Share Usage Data. Check the label, confirmation,
   cancellation (switch returns on), and confirmed opt-out (switch stays off).
3. Disable networking, generate events, background and relaunch the app, then restore
   networking. Verify persisted records replay with their original timestamps.
4. While offline, opt out and re-enable. Restore networking and confirm no records
   from the previous consent period arrive. Repeat while an upload is in progress.
