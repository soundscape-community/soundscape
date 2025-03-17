# Copyright (c) Soundscape Community.
# Licensed under the MIT License.
"""
This is a fake tile server. It serves collections of synthetic randomized
features as map tiles. Each feature is guaranteed to have coordinates that
place it within its tile.

As written, each tile served will contain 1,000 random bus stops, half of
which are marked as NaviLens-enabled. This is useful for testing the app
for support of this new feature type when such features don't exist yet in
the database.

To use as a backend for the app:
1. Run this file:
    python3 random_tile_server.py
2. Update Code/Data/Services/Helpers/ServiceModel.swift:
    private static let productionServicesHostName = "http://localhost:8080"
3. Rebuild and run the app in the simulator.
   a. You may need to clear cached map tiles under Settings > Troubleshooting.
"""
import json
import math
import random

from aiohttp import web

# Upper bound for fake OpenStreetMap node IDs
MAX_OSM_ID = 1 << 40
# Number of random features per tile (1/4 sq. mi.)
FEATURE_DENSITY = 1000


# This returns the NW-corner of the square. Use the function with xtile+1 and/or ytile+1 to get the other corners. With xtile+0.5 & ytile+0.5 it will return the center of the tile.
def num2deg(xtile, ytile, zoom):
    n = 2.0 ** zoom
    lon_deg = xtile / n * 360.0 - 180.0
    lat_rad = math.atan(math.sinh(math.pi * (1 - 2 * ytile / n)))
    lat_deg = math.degrees(lat_rad)
    return (lat_deg, lon_deg)


def random_feature(lat, lon, osm_id):
    # Create a mixture of normal and Navilens-enabled bus stops
    properties = {"name": "Normal",}
    if random.choice([True, False]):
        properties["name"] = "Navilens-enabled"
        properties["qr_code:navilens"] = "yes"

    # Return a bus stop at the given latitude + longitude
    return {
        "feature_type": "highway",
        "feature_value": "bus_stop",
        "geometry": {
            "type": "Point",
            "coordinates": [lon, lat],
        },
        "osm_ids": [osm_id],
        "properties": {
            "bus": "yes",
            "highway": "bus_stop",
            "public_transport": "platform",
            **properties,
        },
        "type": "Feature",
    }


def get_tile_data(zoom, x, y):
    # Get lat/lon range of bounding box
    min_x, min_y = num2deg(x, y, zoom)
    max_x, max_y = num2deg(x + 1, y + 1, zoom)

    # Generate randomized GeoJSON
    return {
        "type": "FeatureCollection",
        "features": [
            # Generate a fixed number of random features within the box
            random_feature(
                lat=random.uniform(min_x, max_x),
                lon=random.uniform(min_y, max_y),
                osm_id=random.randrange(1, MAX_OSM_ID),
            ) for _ in range(FEATURE_DENSITY)
        ],
    }


def tile_handler(request):
    zoom = int(request.match_info['zoom'])
    if int(zoom) != 16:
        raise web.HTTPNotFound()
    x = int(request.match_info['x'])
    y = int(request.match_info['y'])
    tile_data = json.dumps(get_tile_data(zoom, x, y))
    if tile_data == None:
        raise web.HTTPServiceUnavailable()
    else:
        return web.Response(text=tile_data, content_type='application/json')


if __name__ == "__main__":
    app = web.Application()
    app.add_routes([
        web.get(r'/{zoom:\d+}/{x:\d+}/{y:\d+}.json', tile_handler),
        web.get(r'/tiles/{zoom:\d+}/{x:\d+}/{y:\d+}.json', tile_handler), # also respond to requests for /tiles/...
    ])
    web.run_app(app)
