# Tile38Interface

## Setting Up

```
# Initialises global client connection on set using environment variable 'TILE38_ENDPOINT':
using Tile38Interface
Tile38Interface.set_global_connection()

# Check if Tile38Interface is ready
Tile38Interface.tile38_isready()
```

## Establish a Tile38 Connection Context and Running Tile38 Interfaces

```
# With a connection
Tile38Interface.with_tile38() do conn
    Tile38Interface.intersect_point("a", [-111.8851089477539, 33.366090537121586], conn)
end

# With the global connection
Tile38Interface.intersect_point("a", [-111.8851089477539, 33.366090537121586])
```

## Tile38 Interfaces

```
# Sets a geojson object (string) to a key (collection).
set_object(key, id, object, conn)
set_object(key, id, object)
set_object("segment", "sample_DEM", """{"type":"Polygon","coordinates":[[[-111.9787,33.4411],[-111.8902,33.4377],[-111.8950,33.2892],[-111.9739,33.2932],[-111.9787,33.4411]]]}""", conn)

# Gets a value from key and id combination.
get_object(key, id, conn)
get_object(key, id)
get_object("segment", "sample_DEM", conn)

# Deletes a value from key and id combination.
del_object(key, id, conn)
del_object(key, id)
del_object("segment", "sample_DEM", conn)

# Finds all object ids within a key (collection) that intersect with the query geojson object (string).
intersect_object(key, object, conn)
intersect_object(key, object)
intersect_object("a", """{"type":"Polygon","coordinates":[[[-111.9787,33.4411],[-111.8902,33.4377],[-111.8950,33.2892],[-111.9739,33.2932],[-111.9787,33.4411]]]}""", conn)

# Finds all object ids within a key (collection) that intersect with the query point [lon, lat].
intersect_point(key, point, conn)
intersect_point(key, point)
intersect_point("a", [-111.8851089477539, 33.366090537121586], conn)

# inds all object ids within a key (collection) that intersect with a line (vector of [lon, lat] coordinates).
intersect_linestring(key, line, conn)
intersect_linestring(key, line)
intersect_linestring("a", [[-111.8851089477539, 33.366090537121586], [-112.1251089477539, 32.986090537121586]], conn)

# Finds all object ids within a key (collection) that intersect with a circle with the specified center (lat, lon) and radius (m).
intersect_circle(key, lat, lon, meters, conn)
intersect_circle(key, lat, lon, meters)
intersect_circle("a",  33.366090537121586, -111.8851089477539, 100, conn)

# Scans and returns all the ids within a key.
scan_key(key, conn)
scan_key(key)
scan_key("segment", conn)
```
