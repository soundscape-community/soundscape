import pandas as pd
import json
import numpy as np
from scipy.spatial import cKDTree
from geopy.distance import geodesic

# Load the files (Update paths as needed)
csv_file_path = "C:/Users/Matthew Bui/Dropbox/Soundscape/via_sanantonio_NaviLens_Enabled_Bus_Stops.csv"
geojson_file_path = "C:/Users/Matthew Bui/Dropbox/Soundscape/export.geojson"

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
        lon, lat = feature["geometry"]["coordinates"]  # GeoJSON stores as [lon, lat]
        osm_stops.append((lat, lon))  # Convert to (lat, lon) format

# Convert OSM stops to a KDTree for fast lookup
osm_tree = cKDTree(np.array(osm_stops))

# Convert NaviLens stops to an array
navilens_coords = np.array(navilens_df[['lat', 'lon']])

# Define distance threshold in degrees (~1 degree = 111.32 km)
distance_threshold_deg = 5 / 111320  # Convert 5 meters to degrees

# Find the closest OSM stop for each NaviLens stop
distances, indices = osm_tree.query(navilens_coords, distance_upper_bound=distance_threshold_deg)

# Mark NaviLens stops that have a close OSM stop
navilens_df["in_osm"] = distances < distance_threshold_deg

# Print Summary to Console
total_stops = len(navilens_df)
stops_in_osm = navilens_df["in_osm"].sum()
stops_not_in_osm = total_stops - stops_in_osm

print(f"Total NaviLens Stops: {total_stops}")
print(f"Stops Found in OSM: {stops_in_osm}")
print(f"Stops Not in OSM: {stops_not_in_osm}")
