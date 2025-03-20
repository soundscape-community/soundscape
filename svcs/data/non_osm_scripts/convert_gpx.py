# Copyright (c) Soundscape Community.
# Licensed under the MIT License.
"""
Convert GPX into expected format for non-OSM data ingestion.
Suitable for routes exported from Authoring Tool.

Example usage:
    python convert_gpx.py input.gpx output.csv
"""

import argparse
import csv

import gpxpy


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("input_gpx")
    parser.add_argument("output_csv")
    args = parser.parse_args()

    with open(args.input_gpx, newline="") as gpx_file:
        gpx = gpxpy.parse(gpx_file)

        with open(args.output_csv, "w", newline="") as f:
            outcsv = csv.DictWriter(f, fieldnames=[
                "feature_type",
                "feature_value",
                "latitude",
                "longitude",
                "name",
                "bus",
                "highway",
                "public_transport",
                "qr_code:navilens",
                "blind",
                "blind:description",
            ])
            outcsv.writeheader()
            for route in gpx.routes:
                for point in route.points:
                    outcsv.writerow({
                        "latitude": point.latitude,
                        "longitude": point.longitude,

                        #TODO Generalize beyond bus stops
                        "name": "NaviLens available: " + point.name,

                        # Soundscape app expects these as top-level GeoJSON properties
                        "feature_type": "highway",
                        "feature_value": "bus_stop",

                        # properites observed on bus stops in OSM
                        "bus": "yes",
                        "highway": "bus_stop",
                        "public_transport": "platform",

                        # proposed additional tags for OSM compatibility
                        # discussion: https://www.openstreetmap.org/user/John%20Joseph%20A%20Gatchalian/diary/406296
                        "qr_code:navilens": "yes",
                        "blind": "yes",
                        "blind:description": "Has NaviLens code",

                        # optionally include all other columns from input CSV
                        #**row,
                    })