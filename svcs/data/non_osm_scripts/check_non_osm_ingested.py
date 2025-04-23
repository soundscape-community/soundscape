# Copyright (c) Soundscape Community.
# Licensed under the MIT License.
"""
Checks that a non-OSM data CSV was properly loaded by choosing a random row
and confirming that the row is served as a feature in the expected tile.
"""
import argparse
import csv
import math
from pathlib import Path
import random
import sys

import requests


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
    parser.add_argument("non_osm_csv", type=Path)
    parser.add_argument(
        "--tile-server", type=str, default="https://tiles.soundscape.services/")
    parser.add_argument("--zoom", type=int, default=16)
    args = parser.parse_args()

    with open(args.non_osm_csv) as f:
        # Choose a random row from the CSV
        data = csv.DictReader(f)
        some_row = random.choice([row for row in data])
        print(f"Chose feature: {some_row['name']}")

        # Determine tile that would contain feature
        x, y = osm_deg2num(
            float(some_row['latitude']), float(some_row["longitude"]), args.zoom)
        url = f"{args.tile_server}/{args.zoom}/{x}/{y}.json"
        print(f"Fetching {url}...")
        response = requests.get(url)
        features = response.json()["features"]
        print(f"Tile contains {len(features)} features.")

        # Check that some feature in the tile matches our row
        from pprint import pprint
        for feature in features:
            #pprint(feature)
            if (
                feature["feature_type"] == some_row["feature_type"]
                and feature["feature_value"] == some_row["feature_value"]
                and feature["geometry"]["type"] == "Point"
                #and feature["geometry"]["coordinates"] == [
                #    str(some_row["latitude"]), str(some_row["longitude"])]
                # All feature properties should have come from CSV fields
                and all(
                    some_row[key] == val
                    for (key, val) in feature["properties"].items()
                )
            ):
                print("PASS")
                break
        else:
            # No feature in tile matched our row
            print("FAIL")
            sys.exit(-1)