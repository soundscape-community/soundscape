# Saved markers and routes

The iOS app presents markers and destinations as reference entities. A marker has a stable ID, a coordinate, optional nickname, estimated address and annotation, and an optional key for a corresponding map feature. When the map feature is unavailable, the app can use the stored coordinate and saved details. Address and imported place details that cannot reliably be downloaded are stored with their marker.

Temporary reference entities support destinations. The active destination can keep using its marker if the user removes it from the saved marker list. Clearing the destination removes temporary references. Deletion repairs any routes that refer to the removed marker.

Each route has an ordered list of waypoints referring to marker IDs. The user store keeps those relationships valid and writes changes to a route and its markers in one transaction where they belong together. Route start coordinates follow the first waypoint's marker.

The user database lives in Application Support and uses forward-only schema migrations. If it cannot open, Soundscape reports the failure and offers retry while preserving the database files. The Settings action to delete markers and routes works offline. The separate map reset action only clears the spatial cache.
