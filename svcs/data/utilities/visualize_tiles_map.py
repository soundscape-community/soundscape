# Usage:
#   python visualize_tiles_map_v2.py tiles.log.json
#
# Options:
#   output        (optional) Output HTML filename, default: tiles_map_v2.html
#   min_radius    (optional) Minimum circle radius, default: 3
#   max_radius    (optional) Maximum circle radius, default: 15
#
# Example:
#   python visualize_tiles_map_v2.py tiles.log.json output mymap.html min_radius 4 max_radius 10


import json
import math
import pandas as pd
import folium
import argparse

# Tile coordinate conversion
def num2deg(xtile, ytile, zoom):
    n = 2.0 ** zoom
    lon_deg = xtile / n * 360.0 - 180.0
    lat_rad = math.atan(math.sinh(math.pi * (1 - 2 * ytile / n)))
    lat_deg = math.degrees(lat_rad)
    return lat_deg, lon_deg

# Parse command-line arguments
parser = argparse.ArgumentParser(description="Visualize tile request log as interactive map.")
parser.add_argument("json_file", help="Path to tile log JSON file")
parser.add_argument("output", default="tiles_map_v2.html", help="Output HTML map file name")
parser.add_argument("min_radius", type=int, default=3, help="Minimum marker radius")
parser.add_argument("max_radius", type=int, default=15, help="Maximum marker radius")
args = parser.parse_args()

# Read and parse JSON file
rows = []
with open(args.json_file, "r") as f:
    buffer = ""
    for line in f:
        line = line.strip()
        if not line:
            continue
        buffer += line
        if line.endswith("}"):
            try:
                log = json.loads(buffer)
                uri = log["uri"]
                ts = log["ts"]
                parts = uri.strip("/").split("/")
                if len(parts) >= 4 and parts[0] == "tiles":
                    z = int(parts[1])
                    x = int(parts[2])
                    y = int(parts[3].replace(".json", ""))
                    lat, lon = num2deg(x, y, z)
                    rows.append({"ts": ts, "lat": lat, "lon": lon})
            except Exception:
                pass
            buffer = ""

# Create DataFrame and preprocess
df = pd.DataFrame(rows)
df["coord_key"] = df["lat"].round(6).astype(str) + "," + df["lon"].round(6).astype(str)
df["count"] = df["coord_key"].map(df["coord_key"].value_counts())

center_lat = df["lat"].mean()
center_lon = df["lon"].mean()

min_count = df["count"].min()
max_count = df["count"].max()

def scale_radius(count):
    if max_count == min_count:
        return args.min_radius
    return args.min_radius + (count - min_count) / (max_count - min_count) * (args.max_radius - args.min_radius)

def heatmap_color(count):
    if max_count == min_count:
        hue = 240
    else:
        hue = 240 - int((count - min_count) / (max_count - min_count) * 240)
    return f"hsl({hue}, 100%, 50%)"

# Create map
m = folium.Map(location=[40.7128, -74.0060], zoom_start=4)

for _, row in df.iterrows():
    count = row["count"]
    radius = scale_radius(count)
    color = heatmap_color(count)

    folium.CircleMarker(
        location=[row["lat"], row["lon"]],
        radius=radius,
        color=color,
        fill=True,
        fill_opacity=0.7,
        popup=f"ts: {row['ts']}<br>count: {count}"
    ).add_to(m)

m.save(args.output)
print(f"✅ Optimized map saved as {args.output}")
