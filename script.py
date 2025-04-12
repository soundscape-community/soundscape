import argparse
import pandas as pd
import json
import numpy as np
from scipy.spatial import cKDTree
from geopy.distance import geodesic

# Argument parser for CLI inputs
parser = argparse.ArgumentParser(description="Check NaviLens stops against OSM GeoJSON data.")
parser.add_argument("--csv", required=True, help="Path to NaviLens-enabled bus stops CSV file")
parser.add_argument("--geojson", required=True, help="Path to OSM bus stops GeoJSON file")
parser.add_argument("--output", help="Optional path to save result CSV file")
args = parser.parse_args()

# Load the files
csv_file_path = args.csv
geojson_file_path = args.geojson

# Load NaviLens-enabled bus stops CSV
navilens_df = pd.read_csv(csv_file_path)

# Ensure correct latitude and longitude column names
navilens_df = navilens_df.rename(columns={"stop_lat": "lat", "stop_lon": "lon"})

# Load OSM bus stops from GeoJSON
with open(geojson_file_path, "r") as f:
    geojson_data = json.load(f)

# Extract OSM bus stop coordinates
osm_stops = []
for feature in geojson_data["features"]:
    if "geometry" in feature and "coordinates" in feature["geometry"]:
        lon, lat = feature["geometry"]["coordinates"]  # GeoJSON uses [lon, lat]
        osm_stops.append((lat, lon))  # Convert to (lat, lon)

# Convert OSM stops to a KDTree for fast lookup
osm_tree = cKDTree(np.array(osm_stops))

# Convert NaviLens stops to an array
navilens_coords = np.array(navilens_df[['lat', 'lon']])

# Define distance threshold in degrees (~1 degree ≈ 111.32 km)
distance_threshold_deg = 5 / 111320  # Convert 5 meters to degrees

# Find the closest OSM stop for each NaviLens stop
distances, indices = osm_tree.query(navilens_coords, distance_upper_bound=distance_threshold_deg)

# Mark NaviLens stops that have a close OSM stop
navilens_df["in_osm"] = distances < distance_threshold_deg

# Print Summary
total_stops = len(navilens_df)
stops_in_osm = navilens_df["in_osm"].sum()
stops_not_in_osm = total_stops - stops_in_osm

print(f"Total NaviLens Stops: {total_stops}")
print(f"Stops Found in OSM: {stops_in_osm}")
print(f"Stops Not in OSM: {stops_not_in_osm}")

# Show sample of matched stops for manual spot-check
print("\nSample matched NaviLens stops (lat, lon):")
print(navilens_df[navilens_df["in_osm"]][["lat", "lon"]].head())

# Optional: save to output CSV if requested
if args.output:
    navilens_df.to_csv(args.output, index=False)
    print(f"\nFull results saved to: {args.output}")
