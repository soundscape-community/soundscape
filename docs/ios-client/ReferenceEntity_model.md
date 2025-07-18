# Soundscape Data Model: Markers, Waypoints, and Reference Entities

This document clarifies the internal data model used for saved locations in Soundscape, including the relationship between Markers, Waypoints, and the underlying class, `ReferenceEntity`.

It also addresses terminology discrepancies between the user interface and the underlying codebase, with the goal of guiding future development, feature planning, and documentation.



## 🧭 Terminology Mapping

| Concept (UI)        | Class Name (Code)        | Stored in Realm? | Where Shown in UI | Notes |
|---------------------|--------------------------|------------------|-------------------|-------|
| **Marker**          | `ReferenceEntity`        | ✅ Yes           | Global Marker List | User-created location with name, coordinates, etc. |
| **Waypoint**        | `RouteWaypoint`          | ✅ Yes           | Route Editor only  | Used in a route; references a `ReferenceEntity` |
| **Temporary Point** | `ReferenceEntity` with `isTemp = true` | ✅ Yes | Hidden (used for beacons/navigation only) | Not persisted; used dynamically |
| **ReferenceEntity** | `ReferenceEntity`        | ✅ Yes           | Indirectly (via usage) | Base class for all saved locations |



Marker

- A Marker is a saved location explicitly created by the user.
- Implemented via the `ReferenceEntity` class.
- May include: `nickname` (name), `estimatedAddress`, `annotation`, GPS coordinates
- `isTemp = false` for persistent markers.
- Markers appear in the global UI list for easy access.

Waypoint

- A Waypoint is a location used within a user-defined route.
- Represented by the `RouteWaypoint` class.
- Each `RouteWaypoint` references a `markerId` (i.e., a `ReferenceEntity`) and an `index` indicating order in the route.

Types of Waypoints

Waypoints can be created in two ways:
- From an existing marker (i.e., a `ReferenceEntity` with `isTemp = false`)
- On the fly during route creation (i.e., from a `ReferenceEntity` that may be `isTemp = true` or not yet persisted)

In both cases, a `RouteWaypoint` always contains a `markerId` that maps to a `ReferenceEntity`.  
The only difference is whether that `ReferenceEntity` is a permanent marker or a temporary one (based on `isTemp`).

Behavior Consistency

> "They should behave the same way" means:

- The navigation and ordering logic for waypoints in a route does not depend on whether their `ReferenceEntity` is temporary or permanent.
- The audio experience and routing flow are identical regardless of the origin.

However, the distinction does matter for data lifecycle management:

| Action                        | Result (if `ReferenceEntity.isTemp = true`) | Result (if `isTemp = false`) |
|------------------------------|---------------------------------------------|-------------------------------|
| Deleting the waypoint        | May also delete the temp `ReferenceEntity`  | Does not delete the marker |
| Deleting the marker manually | Does not affect the waypoint’s behavior     | Same                         |

> From a user’s perspective, the behavior appears unified. But from a developer perspective, `isTemp` can determine whether a `ReferenceEntity` should be garbage collected when no longer in use.


Temporary ReferenceEntity

- Created dynamically for temporary use, such as audio beacons or ephemeral navigation targets.
- `isTemp = true`
- These are not shown in the markers list and are not considered persistent.
- They may overlap spatially with real markers but are treated as distinct.



 Terminology Note

The class `ReferenceEntity` is a legacy term from early versions of Soundscape (prior to 2020), when the app referred to saved locations as “reference points.”

- Today, `ReferenceEntity` = Marker (in user-facing language)
- Recommend consistently using "Marker" in the UI, documentation, and code comments
- If necessary, consider aliasing or renaming in the future to avoid confusion



 Marker–Waypoint Relationship Rules

These rules define how markers and waypoints should interact:

- Waypoints created *from markers* retain a link to the marker while it exists.
- Waypoints created *on the fly* are valid route points even if no marker was involved.
- If a marker is deleted, any waypoint at the same location should continue to function normally — exactly like any other waypoint.
- If a waypoint is deleted from a route, it does not affect the corresponding marker, if any.
- The user may optionally choose to “Save Waypoint as Marker” to add it to their global markers list.


