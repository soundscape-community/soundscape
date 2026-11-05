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

## Apple privacy declarations

The app's `Assets/PropertyLists/PrivacyInfo.xcprivacy` declares the current telemetry
payload as follows. Use the same classifications in App Store Connect for a
distribution build with a configured collector; editing the manifest does not
update the App Store privacy answers automatically.

| Apple data type | Exported information | Purpose |
| --- | --- | --- |
| Device ID | The random, persistent installation identifier exported as `user_id` | Analytics |
| Product Interaction | Usage events, sessions, tutorial progress, beacon and route actions | Analytics |
| Other Diagnostic Data | Audio/migration errors, offline state, device model/OS and audio/headset context | Analytics, App Functionality |
| Fitness | `routes.added.activity`, derived from Motion & Fitness activity detection | Analytics |
| Other Data Types | App preferences and accessibility settings | Analytics |

These categories are declared **not linked to the user's identity**
(`NSPrivacyCollectedDataTypeLinked = false`). Soundscape has no user accounts and
collects no identity information. The random installation identifier correlates
reports from the same installation; it is not connected to a real-world identity,
an account, or an advertising identifier. Neither Soundscape nor its analytics
providers link these reports to identity information or identity-enabling datasets.
The wire key `user_id` does not determine Apple's data category. The consent screen
describes sharing as anonymous, and the English settings footer describes the
installation identifier. Reassess this declaration if identity collection or
identity linking is introduced. Accessibility settings describe enabled system
features, not a stated
diagnosis or disability; reassess Sensitive Info if the payload or its use changes.

Tracking is declared false based on analytics/diagnostics-only use: no advertising,
cross-company advertising measurement, or data-broker sharing. This assumes the
collector and analytics provider follow the same restriction. Persistent first-party
analytics alone is not Apple's definition of tracking. Do not enable automatic IP
geolocation or add fields or integrations without revisiting these declarations.
The current telemetry payload has no location coordinates, search text, user audio,
crash reports, or performance measurements; on-device use alone does not make those
types collected by telemetry. Review other app services separately for the complete
App Store privacy answers.

Before submitting a distribution build:

1. Match the manifest, App Store Connect answers, translated consent/settings text,
   and published privacy policy to the actual production payload and processing.
   The policy must explain collection, purposes, third-party processing, retention,
   deletion, and how users withdraw consent. Opting out purges local telemetry; it
   does not delete reports previously received by the collector.
   The current in-app link is `https://vially.io/privacy-policy`, which redirects
   to Vially's general website policy. At review time it does not describe
   Soundscape telemetry or Mixpanel; update that policy or the link before release.
2. Review whether the Motion & Fitness activity field is necessary. Declaring
   Fitness describes collection; it does not grant permission for every use.
   Apple imposes additional restrictions on health/fitness data in that context.
   Remove this telemetry field if it is unnecessary, then remove its declaration
   only once no other exported field requires it.
3. Archive the actual distribution configuration, generate Xcode's privacy report,
   inspect the app and dependency manifests in the archive, and run Organizer's
   Validate App. Manifest syntax validation alone is not App Review approval.
4. Exercise both consent choices and opt-out against the production-configured
   build, and describe the optional telemetry and settings path in review notes.

Apple references: [manifest structure](https://developer.apple.com/documentation/technotes/tn3184-adding-data-collection-details-to-your-privacy-manifest),
[data types, linkage, tracking and App Store answers](https://developer.apple.com/app-store/app-privacy-details/),
and [App Review privacy rules](https://developer.apple.com/app-store/review/guidelines/#privacy).

## Collected events

The app emits 24 event names. Screen views, `app.open`, dynamically named events,
settings-change events, accessibility-change events and experiment snapshots are
not collected. The remaining events cover onboarding start/completion, beacon
add/arrival/removal, route creation, GPX saving, app-rating prompts/actions,
selected deep-link actions, offline state, and selected audio/migration errors.

`session.snapshot` replaces the separate `app_snapshot`, `device_snapshot` and
`ios_accessibility` events. It carries the following context as string attributes:

- `app.*`: version/build, language/voice/rate, units, callout
  and audio-mixing settings, beacon style/melodies, volumes and tutorial status.
- `device.*`: locale, model identifier, OS version and audio output type.
- `accessibility.*`: VoiceOver, mono audio, Speak Screen/Selection, bold text,
  content size, grayscale, inverted/darker colours, AssistiveTouch and Switch Control.

The prefixes are prepended to the former keys, for example `app.settings.voice`,
`device.os.version` and `accessibility.voice_over`. Shared event attributes and
identifiers are still attached. Beacon/headset state uses the shared `beacon.state`
and `ar_headset.state` attributes, without duplicate `app.*` fields. First-use date
and accumulated marker/beacon counters are not exported. The beacon-set counter
is retained locally for reminder scheduling. All accessibility fields are retained.
Initial context is captured after launch setup and
saved-voice validation, then once per new session ID. Early startup errors may
precede the initial snapshot. Enabling sharing after initialization emits current
context; renewed consent emits fresh context even within the same session. No
pre-consent activity is replayed. Mixpanel can derive sessions from `session_id`;
this snapshot is context, not an explicit session-start event.

`navilens.suggested` records the first visible recommendation card while the app
is active in each session. Refreshes and navigation do not add impressions. A
visible card is reconsidered on foregrounding, session rotation and consent changes.
An impression already collected in a session is not repeated after renewed consent.

`navilens.launch` records each user launch attempt when the system open request
completes, with `destination` (`navilens` or `app_store`) and `success` (`true` or
`false`). Recommendation, location, accessibility and beacon-toolbar launch paths
share this instrumentation. Timestamp, session ID and shared context are captured
at the initiating action. Revocation invalidates pending attempts, including if
sharing is subsequently re-enabled. Neither NaviLens event includes POI names,
identifiers, addresses or coordinates.

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
Shared/computed providers such as `helper.sessionSnapshot` and `currentStateInfo`,
and transformations such as `logContext.map { ... }`, remain unresolved. It does
not trace dictionary mutation through helper calls or infer runtime values.
Recognized dictionary mutation methods and inout uses are flagged as unresolved;
previously known keys are retained conservatively.
When `#if`/`#else` branches redeclare the same local dictionary name, only the
last scanned declaration supplies properties to calls after the branches.
Those property keys are not unioned across declarations. This currently affects
no telemetry call sites in the app; conditional-compilation property analysis
remains a scanner limitation.
Automatically attached event snapshots, `user_id`, `event_id`, `session_id`, and
OpenTelemetry resource attributes are outside this inventory. All conditional-compilation branches are
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
  extra headers. Invalid JSON, invalid header names, or control characters in
  header values (except horizontal tab) disable telemetry.

These settings are expanded into Info.plist. Missing or invalid configuration
stops collection as well as export, even if the saved preference is enabled.
Build setting values are visible in the app bundle; do not embed privileged secrets.

In an xcconfig, `//` begins a comment, including inside quotes. Escape the URL
using an empty build-setting expansion between the slashes:

```xcconfig
SOUNDSCAPE_OTEL_LOGS_ENDPOINT = https:/$()/collector.example.org/v1/logs
SOUNDSCAPE_OTEL_LOGS_HEADERS = {"Authorization":"Bearer token"}
```

The Debug, AdHoc, and Release xcconfigs contain empty defaults and optionally
include `GuideDogs/Assets/Configurations/Local.xcconfig` after those defaults.
To configure builds on your machine, create that file with the settings above.
It is ignored by Git and applies to builds from both Xcode and xcodebuild.
Leave it absent to keep telemetry disabled by default, including in forks, so
fork builds do not send data to the upstream project's collector.

For distribution builds, provision the local file on the build machine or override
these settings on the xcodebuild command line. Verify the expanded values in the
built app's Info.plist.

## Records and delivery

OpenTelemetry Swift and Swift Core are pinned to 2.6.0. Existing `GDATelemetry`
calls emit INFO logs with the event name in `eventName`, no body, the occurrence
timestamp, and string attributes. `user_id` is the existing client
ID and overrides caller properties. Caller properties override helper snapshot
properties. Screen views use `screen_view` and `screen_name`; value events use
`value`. Existing device, app, accessibility, and experiment snapshots remain.
The resource contains `service.name=soundscape`, `service.version`, and
`service.build`. Pipeline startup does not instantiate `AppContext`.

Each `TelemetryEvent` generates a UUID once at creation and exports it as the
string attribute `event_id`. It is assigned after merging caller properties and
snapshots, so neither can override it. The same ID travels through batching, disk
persistence, retries, and relaunch replay; export never regenerates it. Distinct
occurrences receive distinct IDs even when their names, attributes, and timestamps
otherwise match. This per-occurrence UUID is separate from the event names listed
as `eventIds` by the source inventory above.

Vector maps `event_id` to Mixpanel's `$insert_id` for deduplication. An upload can
succeed while its response is lost, causing the app or Vector to retry. Reusing
the original ID lets Mixpanel recognize the repeated event without relying on
the collector's fallback hash of event fields, which can merge distinct occurrences
with identical attributes and timestamps.

The string attribute `session_id` is a random UUID for the current usage session.
Every new app process starts a fresh session. Backgrounding, foregrounding, phone
lock, and ordinary inactivity keep the same ID because background use is normal.
Entering Soundscape sleep mode (the home screen Sleep button) keeps the ID until
wake: returning to normal operation after **at least 30 continuous minutes** in
sleep or snooze generates a new UUID and, when collection is enabled and launch
initialization is complete, emits `session.snapshot` before subsequent events.
Switching between sleep and "wake when I leave" snooze does not restart
the timeout. Short sleeps keep the session and do not accumulate toward 30 minutes.
Other paths into Soundscape sleep mode, such as the NaviLens integration, follow
the same rule. Device sleep alone never starts this timeout.
The timeout uses elapsed seconds from `CLOCK_MONOTONIC_RAW`, which advances during
device sleep and is unaffected by wall-clock adjustments. Device sleep counts
toward the timeout only while Soundscape is already in sleep or snooze mode.
Event occurrence timestamps continue to use wall-clock dates.

Session tracking is in memory and independent of consent; it does not collect or
export events while sharing is disabled. Each event captures its session ID at
creation, after merging properties and snapshots so neither can override it.
Batching, persistence, retries, and replay retain that original session ID, even
after wake or a relaunch has started a new session. Neither `session_id` nor
`event_id` changes the existing client `user_id`.

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
URLSession requests, invalidates pending launch telemetry, and serializes shutdown and
memory/disk cleanup. Re-enabling waits for queued cleanup and synchronously purges
old storage before the enabled preference is saved, then creates a fresh consent
period. If purging fails, consent remains disabled. Revoked tokens
prevent SDK shutdown flushes from uploading old records. Opted-out launches purge
leftover storage before any exporter can be created. Automated app tests disable
real export (the existing `-TESTING` launch argument or XCTest detection); unit
tests use injected exporters and URLProtocol stubs.

Delivery is best effort. Records in memory can be lost on abrupt termination,
and ambiguous network failures can cause repeated delivery; the stable `event_id`
supports downstream deduplication. Retention and storage limits
also discard records. Automatic tracing, metrics, and crash reporting are outside
this integration.

## Verification

Run the Soundscape scheme's UnitTests, including `TelemetryTests`, and build Debug,
AdHoc, and Release. Run `apps/ios/Scripts/LocalizationLinter/main.swift` from
`apps/ios`. Tests cover configuration, consent defaults and saved preferences,
event mapping, distinct UUIDs for identical occurrences, protected `event_id`
precedence, stable IDs through repeated emission, OTLP serialization,
session UUIDs, background continuity, short sleeps, the 30-minute wake boundary,
sleep/snooze transitions, captured session IDs after wake,
offline persistence/relaunch replay, failed uploads, expiry,
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
   networking. Verify persisted records replay with their original timestamps and
   `event_id` values. Retry an upload and confirm both OTLP requests carry the same
   ID, which Vector maps to Mixpanel's `$insert_id`.
   Confirm replay also retains the original `session_id`, while newly created
   events after relaunch have a new session ID.
4. While offline, opt out and re-enable. Restore networking and confirm no records
   from the previous consent period arrive. Repeat while an upload is in progress.
5. Background and foreground the app, including locking and unlocking the phone,
   and verify `session_id` stays the same. Use the home screen Sleep button and
   wake before 30 minutes: the ID stays the same. Sleep for at least 30 minutes
   (including time in snooze), then wake manually or by moving: the wake event and
   subsequent events use a new ID. Events recorded before wake keep their old ID.
