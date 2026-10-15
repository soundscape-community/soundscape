# Telemetry

Telemetry is optional and defaults to **off** in Debug, AdHoc, and Release. A shared
SwiftUI consent screen appears at the end of onboarding, or on launch for existing
users who have not answered it. Users must choose Share Usage Data or Don't Share;
the screen cannot be dismissed without a choice. Both answers are remembered using
`GDASettingsTelemetryConsentChoiceMade`, separately from the existing opt-out
preference. An old enabled preference alone does not authorize collection: sharing
is paused until a choice is recorded, and old queued records are purged by the
existing disabled-launch cleanup. Settings → Telemetry → Share Usage Data lets
users change their choice later. A confirmed settings change also records a choice;
canceling the opt-out confirmation does not. If enabling fails during storage
cleanup, sharing remains disabled and the choice is still remembered. No collector
configuration is included in the repository.

## Source inventory

Run the standalone Swift inventory script from the repository root:

```sh
apps/ios/Scripts/TelemetryInventory/main.swift > telemetry-inventory.json
```

From `apps/ios`, use `./Scripts/TelemetryInventory/main.swift`. The script discovers
the repository from the current directory; `--root <repository>` selects it
explicitly, and `--help` describes usage. It requires the macOS Swift toolchain
available through `xcrun`, with no additional dependencies or app build.

Stdout contains pretty-printed JSON with stable ordering and a trailing newline:

- `eventIds`: sorted, unique literal event IDs. Screen views contribute
  `screen_view`, rather than their screen names.
- `screenNames`: sorted, unique literal names passed to `trackScreenView`.
- `calls`: every recognized `GDATelemetry.track` or `trackScreenView` call in
  `GuideDogs/**/*.swift`, ordered by file and source position. Each record includes
  `api`, repository-relative `file`, one-based `line` and `column`, and the original
  `nameExpression`. `eventId` is omitted when computed; `screenName` is present
  only for literal screen names. Repeated calls remain separate records.
- Each call's `properties` lists keys and sorted `valueExpressions` containing
  Swift source text. `unresolvedPropertyExpressions` retains dictionary sources or
  computed keys that could not be analyzed, even when other keys were extracted.

For example, `trackScreenView("home")` contributes `screen_view`, screen name
`home`, and property `screen_name` with source expression `"home"`. The `value:`
overload contributes a `value` property. Interpolated or concatenated event names
remain expressions; the script does not expand enums or evaluate app code.

Property analysis extracts inline dictionaries, explicit dictionary/nil ternary
alternatives, and local dictionary initializers, replacements, and subscript
assignments preceding each call. It respects nested local declarations and keeps
possible keys across conditional branches. These are possible call-site keys,
not a guarantee of presence, reachability, or the final value at runtime. Value
expressions are retained rather than evaluated, and assignments after a call do
not change its record.

This is a bounded source scanner, not a Swift compiler or whole-program analysis.
Shared/computed providers such as `helper.deviceSnapshot` and `currentStateInfo`,
and transformations such as `logContext.map { ... }`, remain unresolved. It does
not trace dictionary mutation through helper calls or infer runtime values.
Recognized dictionary mutation methods and inout uses are flagged as unresolved;
previously known keys are retained conservatively.
Automatically attached event snapshots, `user_id`, and OpenTelemetry resource
attributes are outside this inventory. All conditional-compilation branches are
scanned; tests, scripts, and dependencies outside `GuideDogs` are excluded. Comments
and string contents do not count as calls, and internal unqualified forwarding
calls in `GDATelemetry` are not counted again.

Invalid arguments, unreadable files, and unbalanced source delimiters produce an
error on stderr and a nonzero exit without partial JSON. Unresolved expressions
are normal inventory results and do not fail the command.

Run the standalone fixture checks with:

```sh
apps/ios/Scripts/TelemetryInventory/tests.swift
```

These compile the script once and scan temporary repositories, without building
or changing the app.

### HTML report

Select `--html` to generate a self-contained report that opens locally in
a browser, without external scripts, styles, fonts, or a server:

```sh
apps/ios/Scripts/TelemetryInventory/main.swift --html > telemetry-inventory.html
```

JSON is the default when `--html` is omitted. Both formats write to stdout and
support `--root <repository>`.

The report shows inventory totals and expandable event groups, sorted by literal
event ID followed by computed name expression. Repeated event IDs share a group;
each group retains every call site's source location, name/screen information,
possible property keys, value expressions, and unresolved property sources.

Search matches event IDs, screen names, properties, source expressions, and files
case-insensitively. **Needs review only** limits the report to groups containing
computed event/screen names or unresolved property sources. Filters apply to whole
groups: all call sites within a matching group remain available. Summary totals
describe the full inventory; the status shows how many groups match the filters.
Groups start collapsed, and all details remain usable without JavaScript;
JavaScript enables search and filtering. The property-analysis limits above apply
equally to the report.

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
calls emit INFO logs with the event name in `eventName`, no body, the occurrence
timestamp, and string attributes. `user_id` is the existing client
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
   On a fresh installation, finish onboarding and check both consent choices,
   VoiceOver, large text, and blocked swipe/accessibility-escape dismissal. Relaunch
   and replay onboarding to confirm the prompt is skipped after either answer.
   Upgrade an installation with telemetry previously enabled but no choice key:
   verify collection stays off until the launch consent screen is answered. Terminate
   before answering and confirm the screen appears again on the next launch.
3. Disable networking, generate events, background and relaunch the app, then restore
   networking. Verify persisted records replay with their original timestamps.
4. While offline, opt out and re-enable. Restore networking and confirm no records
   from the previous consent period arrive. Repeat while an upload is in progress.
