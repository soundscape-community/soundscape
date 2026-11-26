# Spatial data caching

Soundscape uses the `SSData` package in `apps/common` for SQLite storage. The iOS app supplies the database paths and coordinates location updates, downloads, and navigation.

The spatial cache is in the app's Caches directory. Each tile owns its metadata and derived POI, road, path, and intersection rows. Nearby queries read the quadkeys covering the requested area. Feature keys and road membership indexes support lookups across tiles. The cache stores map recents separately from downloaded features, so refreshing a tile preserves those selections.

A tile expires after seven days and remains readable offline. The next fetch can use its ETag to renew it or replace its features in one transaction. A category change expires all tiles and clears their ETags to force reprocessing. Multiple tiles can own copies of the same feature, which remain available until their tiles are replaced or evicted.

The cache can be rebuilt after a schema change or database corruption. Resetting it removes downloaded tiles and map recents, and invalidates in-flight writes. Cache reset calls never open or delete the durable user database. Saved markers, routes, and the details needed to reopen saved addresses and imported places are stored separately.
