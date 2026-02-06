# iOS Client Overview

Soundscape is a medium-sized iOS application with a layered architecture around sensors, spatial data, behavior-driven event processing, and audio rendering.

Use this document as a high-level map. For deeper subsystem detail, use `docs/ios-client/components/`.

## Client Pipeline Architecture

This diagram shows the core runtime flow from sensor updates through callout generation and playback.

![Flow chart](./attachments/ios-pipeline-soundscape-diagram.png)

::: mermaid
flowchart LR
    subgraph GeolocationManager["Geolocation & Heading"]
        direction LR
        subgraph Sensors["Sensor Providers"]
            direction LR
            loc(Location)
            dev(Device Heading)
            course(Course)
            user(User Heading)
            style loc stroke-dasharray: 5 5
            style dev stroke-dasharray: 5 5
            style course stroke-dasharray: 5 5
            style user stroke-dasharray: 5 5
        end
        Sensors --> geo(Geolocation Manager)
    end
    subgraph DataManagement["Data Management"]
        direction TB
        data(Spatial Data Context) --Tiles to Fetch--> osm(OSM Service Model) --> data
    end
    subgraph EventProcessor["Event Processor"]
        direction TB
        active(Active Behavior) --User Interaction Event--> manual(Manual Generators)
        active --State Change Event--> auto(Auto Generators)
        manual --> queue{{Was a callout group generated?}}
        auto --> queue
        queue --> enqueue(Enqueue Callout Group)
    end
    GeolocationManager --Loc Update--> DataManagement
    DataManagement --Loc Changed Event--> EventProcessor
    GeolocationManager --Heading Updates--> EventProcessor
    EventProcessor --> audio(Audio Engine)
    dest(Destination Manager) --Beacon Changed--> audio
    GeolocationManager --Heading Updates--> audio
    audio --> out(Rendered Output)
:::

## Geolocation and Heading

`GeolocationManager` orchestrates location and heading providers and propagates updates into the app.

- Default providers come from `CoreLocationManager`.
- Optional providers (for example simulation and user heading inputs) can be added through provider protocols.
- Location updates are sent through `SpatialDataContext` before reaching the behavior pipeline, so callout generation has current nearby map data.

## Spatial Data Pipeline

`SpatialDataContext` is responsible for making sure map tiles near the user are available and cached.

- Tile data is fetched from Soundscape data services.
- The app works on GeoJSON tile payloads at zoom level 16.
- Consumers request nearby data through `SpatialDataContext`/`SpatialDataView` APIs rather than directly parsing network responses.

## Event Processing and Behaviors

The core callout logic is managed by the behavior stack and `EventProcessor`.

- `EventProcessor` receives app events through `process(_:)`.
- Events are enqueued and consumed by an async event loop (`EventQueue` + `AsyncStream`) on `@MainActor` for deterministic ordered handling.
- Behaviors are layered (default behavior plus optional custom behavior). If the active behavior does not handle an event, bubbling can continue to the parent behavior depending on blocking rules.
- `BehaviorBase` provides manual and automatic generator registration and typed event streams (`allEvents`, `userInitiatedEvents`, `stateChangedEvents`) used by stream-subscribing generators.
- Generators emit `HandledEventAction` values (for example play callouts, enqueue follow-up events, interrupt current playback).

## Callout Orchestration

`CalloutCoordinator` is the queue owner for callout playback semantics.

- Owns callout queueing, interrupt/hush behavior, and validity checks.
- Exposes async playback APIs used by `EventProcessor` and async-capable generators via `BehaviorDelegate.playCallouts(_:)`.
- Keeps callout lifecycle and completion behavior centralized instead of spreading queue logic across generators.

`CalloutGroup` is the unit of callout playback intent and carries:

- callouts,
- queueing action (`interrupt`, `enqueue`, etc.),
- logging context,
- optional completion and validity hooks.

## Audio Playback Stack

`AudioEngine` renders discrete and continuous sounds.

- Discrete audio includes callouts and earcons.
- Dynamic audio includes beacon playback that adapts to heading/location context.

`AudioPlaybackActor` provides an async control boundary around playback operations used by the coordinator, reducing direct callback-style coupling in the callout pipeline.

## Destination Manager and Audio Beacon

`DestinationManager` controls the active beacon destination and integrates with audio playback.

- Soundscape currently uses a single active beacon target.
- Beacon state and user heading/location updates determine dynamic beacon rendering.
