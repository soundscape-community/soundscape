# Soundscape telemetry collector

This is the collector-facing contract for the iOS app. See [Telemetry.md](Telemetry.md)
for consent, app configuration, event inventory, and delivery details.

## Ingestion

- Accept HTTPS **OTLP/HTTP logs**, using an explicitly configured full endpoint such
  as `/v1/logs`. Requests are POSTs containing a binary protobuf
  `ExportLogsServiceRequest` (`Content-Type: application/x-protobuf`). The app
  normally sends gzip-compressed bodies (`Content-Encoding: gzip`); also accept
  uncompressed bodies. Optional configured HTTP headers are sent with every request.
- Each log record is an event: use `eventName` as its name and `timeUnixNano` as
  its occurrence time. Severity is INFO and the body is empty. Expand every record
  in the resource and scope groups; do not treat a batch as a single event.
- Resource attributes are `service.name` (`soundscape`), `service.version`, and
  `app.build_id` (the bundle build number). Preserve event attribute names and
  their OTLP string, boolean, integer, and floating-point types. Event names and available properties can
  be inspected with the telemetry inventory described in [Telemetry.md](Telemetry.md).

## Mixpanel mapping

Map each OTLP record to one Mixpanel event:

| Source | Mixpanel destination | Handling |
| --- | --- | --- |
| `eventName` | `event` | Preserve the event name. |
| `timeUnixNano` | `properties.time` | Convert the original occurrence time to the units accepted by the selected Mixpanel API. |
| `app.installation.id` | `properties.distinct_id` | Preserve the random monthly telemetry UUID as a string. |
| `event_id` | `properties.$insert_id` | Preserve the UUID for deduplication on every retry. |
| `session.id` | `properties.session_id` | Preserve the session UUID as a string. |
| `geo.location.lat`, `geo.location.lon` | `properties.$latitude`, `properties.$longitude` | Map both as floating-point numbers when present; do not stringify, round again, or substitute collector coordinates. |
| Other event attributes | Event properties | Preserve names and values; exclude or rename only where a deliberate mapping requires it. |

The app uses OpenTelemetry `device.model.identifier` and `os.version` on
`session.snapshot`; they are not automatically attached to other events. Its
`app.build_id` resource attribute is the bundle build number. `event_id` remains a
Soundscape-specific per-occurrence UUID; `eventName` identifies the event type.

Boolean attributes are `first_launch`, `success`, `is_flat`,
`is_other_audio_playing`, `is_mixing_with_others`, `app.settings.allow_callouts`,
`app.settings.mix_audio`, `app.beacon.melodies_enabled`, and the accessibility flags
(except `accessibility.content_size`). Numeric doubles are `app.settings.voice.rate`,
`app.volume.beacon`, `app.volume.tts`, `app.volume.other`, `ar_headset.accuracy`,
and the two geographic coordinates; `error.code` is an integer. All other current
event attributes are strings. A missing or invalid value is omitted for a typed
field; do not infer types from the contents of strings.

Configure the Mixpanel project token and destination endpoint in the collector.
These credentials are not included in app records. Mixpanel uses event coordinates
for geographic inference; they are the centre of an H3 resolution 7 cell, captured
once after consent for a session. Some events, including early events and events
without a usable location, have no coordinates. Disable IP-derived geolocation for
those events (for the import API, set event `ip` to `0`), so the collector's address
is not reported as the user's location. Do not create a user profile or infer precise
location from these coordinates. See [Mixpanel geolocation](https://docs.mixpanel.com/docs/tracking-best-practices/geolocation)
and [event import](https://developer.mixpanel.com/reference/import-events).

`app.installation.id` is randomly generated for telemetry and rotates on the first
session in each UTC calendar month. A session crossing the month boundary retains
its original identifier, as do delayed events and replays. Do not join old and new
identifiers as one user.

`session.snapshot` is a context event, not a session-start event. Its location may be
absent even if later events in the same session have one. Session IDs change on app
process launch and after a qualifying Soundscape sleep; correlate events by the
provided `session.id`, not by upload time.

## Delivery and checks

Delivery is best effort and can be delayed, reordered, or repeated after an ambiguous
failure. Preserve original event timestamps, IDs, and properties across collector
retries; use durable collector buffering as appropriate. App opt-out stops future
collection and purges its local queue, but cannot retract records already received
by the collector.

Verify with a test build and destination: receive compressed and uncompressed OTLP
requests; check multiple events per batch; confirm numeric coordinates and absent
coordinates; retry an event and confirm Mixpanel deduplicates it using `$insert_id`;
and verify a delayed replay keeps its original time and session ID. Inspect the
actual Mixpanel event to confirm geography is inferred from the cell centre and that
an event without coordinates does not inherit the collector's location.
