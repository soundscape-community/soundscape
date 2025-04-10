import json
import math
import pandas as pd
import folium

# Tile coordinate conversion
def num2deg(xtile, ytile, zoom):
    n = 2.0 ** zoom
    lon_deg = xtile / n * 360.0 - 180.0
    lat_rad = math.atan(math.sinh(math.pi * (1 - 2 * ytile / n)))
    lat_deg = math.degrees(lat_rad)
    return lat_deg, lon_deg

# Read JSON file
json_file = "tiles.log.json"  
rows = []

with open(json_file, "r") as f:
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


df = pd.DataFrame(rows)

center_lat = df["lat"].mean()
center_lon = df["lon"].mean()

# Count frequency of each tile
df["coord_key"] = df["lat"].round(6).astype(str) + "," + df["lon"].round(6).astype(str)
df["count"] = df["coord_key"].map(df["coord_key"].value_counts())

# Build folium map
m = folium.Map(location=[40.7128, -74.0060], zoom_start=4)

for _, row in df.iterrows():
    count = row["count"]
    radius = 3 + count
    color = "red" if count > 3 else "blue"

    folium.CircleMarker(
        location=[row["lat"], row["lon"]],
        radius=radius,
        color=color,
        fill=True,
        fill_opacity=0.6,
        popup=f"ts: {row['ts']}<br>count: {count}"
    ).add_to(m)

m.save("tiles_map.html")
print("✅ Map saved as tiles_map.html")
