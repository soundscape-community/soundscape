#!/usr/bin/env python3
# Convert CSV into expected format for non-OSM data ingestion.
#
# Example usage:
#    python convert_extra_data_csv.py mobility navilens input.csv output.csv
#
# This will set feature_type to "mobility" and feature_value to "navilens"
# for all rows.

import argparse
import csv

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("feature_type")
    parser.add_argument("feature_value")
    parser.add_argument("input_csv")
    parser.add_argument("output_csv")
    args = parser.parse_args()

    with open(args.input_csv, newline="") as f:
        incsv = csv.DictReader(f)

        with open(args.output_csv, "w", newline="") as f:
            outcsv = csv.DictWriter(f, fieldnames=[
                "feature_type", "feature_value", "latitude", "longitude", 
            ] + incsv.fieldnames)
            outcsv.writeheader()
            for row in incsv:
                outcsv.writerow({
                    "latitude": row["stop_lat"],
                    "longitude": row["stop_lon"],
                    "feature_type": args.feature_type,
                    "feature_value": args.feature_value,
                    **row,
                })