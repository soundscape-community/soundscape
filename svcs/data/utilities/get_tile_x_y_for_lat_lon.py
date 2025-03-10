# Copyright (c) Soundscape Community.
# Licensed under the MIT License.
"""
Prints the tile server URL path for the tile containing the given
latitude and longitude.
"""
import argparse
import math


# standard tile to coordinates and reverse versions from
# https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames
def osm_deg2num(lat_deg, lon_deg, zoom):
    lat_rad = math.radians(lat_deg)
    n = 2.0 ** zoom
    xtile = int((lon_deg + 180.0) / 360.0 * n)
    ytile = int((1.0 - math.log(math.tan(lat_rad) + (1 / math.cos(lat_rad))) / math.pi) / 2.0 * n)
    return (xtile, ytile)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("latitude", type=float)
    parser.add_argument("longitude", type=float)
    parser.add_argument("--zoom", type=int, default=16)
    args = parser.parse_args()

    x, y = osm_deg2num(args.latitude, args.longitude, args.zoom)
    print(f"/{args.zoom}/{x}/{y}.json")