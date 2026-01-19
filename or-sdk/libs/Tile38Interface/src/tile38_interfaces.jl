"""
    set_object(key, id, object, conn)
    set_object(key, id, object)

Sets a geojson object (string) to a key (collection).
"""
set_object(key, id, object, conn) = JedisCluster.execute(["SET", key, id, "OBJECT", object], conn)
set_object(key, id, object) = set_object(key, id, object, get_global_connection())
set_object_with_field(key::String, id::String, field_name::String, field_value::String, object::String, conn::Union{JedisCluster.Client,JedisCluster.Pipeline}) = JedisCluster.execute(["SET", key, id, "FIELD", field_name, field_value, "OBJECT", object], conn)
set_object_with_field(key::String, id::String, field_name::String, field_value::String, object::String) = set_object_with_field(key, id, field_name, field_value, object, get_global_connection())

"""
    set_object_field(key, id, object, conn)
    set_object_field(key, id, object)

Sets a geojson object's field for a given key and id.
"""
set_object_field(key::String, id::String, field_name::String, field_value::String, conn::Union{JedisCluster.Client,JedisCluster.Pipeline}) = JedisCluster.execute(["FSET", key, id, field_name, field_value], conn)
set_object_field(key::String, id::String, field_name::String, field_value::String) = set_object_field(key, id, field_name, field_value, get_global_connection())

"""
    get_object(key, id, conn)
    get_object(key, id, conn; timeout)
    get_object(key, id)
    get_object(key, id; timeout)

Gets a value from key and id combination.
"""
get_object(key, id, conn) = JedisCluster.execute(["GET", key, id], conn)
get_object(key, id, conn; timeout::Float64=25.0) = JedisCluster.execute(["TIMEOUT", timeout, "GET", key, id], conn)
get_object(key, id) = get_object(key, id, get_global_connection())
get_object(key::String, id::String; timeout::Float64=25.0) = get_object(key, id, get_global_connection(), timeout=timeout)

"""
    del_object(key, id, conn)
    del_object(key, id)

Deletes a value from key and id combination.
"""
del_object(key, id, conn) = JedisCluster.execute(["DEL", key, id], conn)
del_object(key, id) = del_object(key, id, get_global_connection())

"""
    pdel_object(key, id, conn)
    pdel_object(key, id)

Delete all objects within a key (collection) that match the provided ID pattern.
"""
pdel_object(key, pattern, conn) = JedisCluster.execute(["PDEL", key, pattern], conn)
pdel_object(key, pattern) = pdel_object(key, pattern, get_global_connection())

"""
    get_intersecting_objects(key, object[; limit=100, buffer=100, timeout=25.0])
    get_intersecting_objects(key, object, wherein, conn[; limit=100, buffer=100, timeout=25.0])

Find all intersecting objects within a key (collection) that intersect with the query GeoJSON object (string) for a given buffer and/or a wherein condition.
"""
get_intersecting_objects(key::String, object::String, conn::Union{JedisCluster.Client,JedisCluster.Pipeline}; limit::Int64=100, buffer::Float64=100.0, timeout::Float64=25.0) = JedisCluster.execute(["TIMEOUT", timeout, "INTERSECTS", key, "LIMIT", limit, "BUFFER", buffer, "OBJECT", object], conn)
get_intersecting_objects(key::String, object::String, where_in::String, conn::Union{JedisCluster.Client,JedisCluster.Pipeline}; limit::Int64=100, buffer::Float64=100.0, timeout::Float64=25.0) = JedisCluster.execute("TIMEOUT $timeout INTERSECTS $key LIMIT $limit BUFFER $buffer WHEREIN $where_in OBJECT $object", conn)
get_intersecting_objects(key::String, object::String; limit::Int64=100, buffer::Float64=100.0, timeout::Float64=25.0) = get_intersecting_objects(key, object, get_global_connection(); limit=limit, buffer=buffer, timeout=timeout)
get_intersecting_objects(key::String, object:: String, where_in::String; limit::Int64=100, buffer::Float64=100.0, timeout::Float64=25.0) = get_intersecting_objects(key, object, where_in, get_global_connection(); limit=limit, buffer=buffer, timeout=timeout)

"""
    intersect_object(key, object, conn[; limit=100])
    intersect_object(key, object, conn[; limit=100, timeout=25.0])
    intersect_object(key, object[; limit=100])
    intersect_object(key, object[; limit=100, timeout=25.0])

Finds all object ids within a key (collection) that intersect with the query geojson object (string).
"""
intersect_object(key, object, conn; limit=100) = JedisCluster.execute(["INTERSECTS", key, "LIMIT", limit, "IDS", "OBJECT", object], conn)
intersect_object(key, object, conn; limit=100, timeout::Float64=25.0) = JedisCluster.execute(["TIMEOUT", timeout, "INTERSECTS", key, "LIMIT", limit, "IDS", "OBJECT", object], conn)
intersect_object(key, object; limit=100) = intersect_object(key, object, get_global_connection(); limit=limit)
intersect_object(key, object; limit=100, timeout::Float64=25.0) = intersect_object(key, object, get_global_connection(); limit=limit, timeout=timeout)

"""
    intersect_point(key, point, conn[; limit=100])
    intersect_point(key, point[; limit=100])

Finds all object ids within a key (collection) that intersect with the query point [lon, lat].
"""
intersect_point(key, point, conn; limit=100) = intersect_object(key, """{"type": "Point", "coordinates": $(replace(string(point), "JSON3.Array" => ""))}""", conn; limit=limit)
intersect_point(key, point; limit=100) = intersect_point(key, point, get_global_connection(); limit=limit)

"""
    intersect_linestring(key, line, conn[; limit=100])
    intersect_linestring(key, line[; limit=100])

Finds all object ids within a key (collection) that intersect with a line (vector of [lon, lat] coordinates).
"""
intersect_linestring(key, line, conn; limit=100) = intersect_object(key, """{"type": "LineString", "coordinates": $(replace(string(line), "JSON3.Array" => ""))}""", conn; limit=limit)
intersect_linestring(key, line; limit=100) = intersect_linestring(key, line, get_global_connection(); limit=limit)

"""
    intersect_circle_objects(key, lat, lon, radius, conn[; limit=100])
    intersect_circle_objects(key, lat, lon, radius, match, conn[; limit=100])
    intersect_circle_objects(key, lat, lon, radius, match, where_in, conn[; limit=100])

Finds all objects within a key (collection) that intersect with a circle with the specified center (lat, lon) and radius (m).
"""
intersect_circle_objects(key::String, lat::Float64, lon::Float64, radius::Float64, conn::Union{JedisCluster.Client,JedisCluster.Pipeline}; limit::Int64=100) = JedisCluster.execute(["INTERSECTS", key, "LIMIT", limit, "CIRCLE", lat, lon, radius], conn)
intersect_circle_objects(key::String, lat::Float64, lon::Float64, radius::Float64, match::String, conn::Union{JedisCluster.Client,JedisCluster.Pipeline}; limit::Int64=100, timeout::Float64=25.0) = JedisCluster.execute(["TIMEOUT", timeout, "INTERSECTS", key, "LIMIT", limit, "MATCH", match, "CIRCLE", lat, lon, radius], conn)
intersect_circle_objects(key::String, lat::Float64, lon::Float64, radius::Float64, match::String, where_in::String, conn::Union{JedisCluster.Client,JedisCluster.Pipeline}; limit::Int64=100, timeout::Float64=25.0) = JedisCluster.execute("TIMEOUT $timeout INTERSECTS $key LIMIT $limit MATCH $match WHEREIN $where_in CIRCLE $lat $lon $radius", conn)
intersect_circle_objects(key::String, lat::Float64, lon::Float64, radius::Float64; limit::Int64=100) = intersect_circle_objects(key, lat, lon, radius, get_global_connection(); limit=limit)
intersect_circle_objects(key::String, lat::Float64, lon::Float64, radius::Float64, match::String; limit::Int64=100, timeout::Float64=25.0) = intersect_circle_objects(key, lat, lon, radius, match, get_global_connection(); limit=limit, timeout=timeout)
intersect_circle_objects(key::String, lat::Float64, lon::Float64, radius::Float64, match::String, where_in::String; limit::Int64=100, timeout::Float64=25.0) = intersect_circle_objects(key, lat, lon, radius, match, where_in, get_global_connection(); limit=limit, timeout=timeout)

"""
    intersect_circle_objects_with_where(key, lat, lon, radius, where_in, conn[; limit=100])

Finds all objects within a key (collection) that intersect with a circle with the specified center (lat, lon) and radius (m) based on the where in caluse.
"""
intersect_circle_objects_with_where(key::String, lat::Float64, lon::Float64, radius::Float64, where_in::String, conn::Union{JedisCluster.Client,JedisCluster.Pipeline}; limit::Int64=100, timeout::Float64=25.0) = JedisCluster.execute("TIMEOUT $timeout INTERSECTS $key LIMIT $limit WHEREIN $where_in CIRCLE $lat $lon $radius", conn)
intersect_circle_objects_with_where(key::String, lat::Float64, lon::Float64, radius::Float64, where_in::String; limit::Int64=100, timeout::Float64=25.0) = intersect_circle_objects(key, lat, lon, radius, where_in, get_global_connection(); limit=limit, timeout=timeout)

"""
    intersect_circle(key, lat, lon, meters, conn[; limit=100])
    intersect_circle(key, lat, lon, meters[; limit=100])

Finds all object ids within a key (collection) that intersect with a circle with the specified center (lat, lon) and radius (m).
"""
intersect_circle(key, lat, lon, meters, conn; limit=100) = JedisCluster.execute(["INTERSECTS", key, "LIMIT", limit, "IDS", "CIRCLE", lat, lon, meters], conn)
intersect_circle(key, lat, lon, meters; limit=100) = intersect_circle(key, lat, lon, meters, get_global_connection(); limit=limit)

"""
    intersect_bounds(key, bottom_left_lat, bottom_left_lon, top_right_lat, top_right_lon, conn[; limit=100])
    intersect_bounds(key, bottom_left_lat, bottom_left_lon, top_right_lat, top_right_lon[; limit=100])

Finds all object ids within a key (collection) that intersect with a bounding box specified by the coordinates of the bottom left and top right corner (bottom_left_lat, bottom_left_lon, top_right_lat, top_right_lon).
"""
intersect_bounds(key, bottom_left_lat, bottom_left_lon, top_right_lat, top_right_lon, conn; limit=100) = JedisCluster.execute(["INTERSECTS", key, "LIMIT", limit, "IDS", "BOUNDS", bottom_left_lat, bottom_left_lon, top_right_lat, top_right_lon], conn)
intersect_bounds(key, bottom_left_lat, bottom_left_lon, top_right_lat, top_right_lon; limit=100) = intersect_bounds(key, bottom_left_lat, bottom_left_lon, top_right_lat, top_right_lon, get_global_connection(); limit=limit)

"""
    scan_key(key, conn[; limit=1000000])
    scan_key(key[; limit=1000000])

Scans and returns all the ids within a key.
"""
scan_key(key, conn::Union{JedisCluster.Client,JedisCluster.Pipeline}; limit=1000000) = JedisCluster.execute(["SCAN", key, "LIMIT", limit, "IDS"], conn)
scan_key(key; limit=1000000) = scan_key(key, get_global_connection(); limit=limit)
"""
    scan_key(key, match::String, conn::Union{JedisCluster.Client,JedisCluster.Pipeline}; limit=1000000)
    scan_key(key, match::String; limit=1000000)

Scans and returns all the ids within a key that match a string.
"""
scan_key(key, match::String, conn::Union{JedisCluster.Client,JedisCluster.Pipeline}; limit=1000000) = JedisCluster.execute(["SCAN", key, "MATCH", match, "LIMIT", limit, "IDS"], conn)
scan_key(key, match::String; limit=1000000) = scan_key(key, match, get_global_connection(); limit=limit)

"""
    scan_key_with_where_in(key, where_in::String, conn::Union{JedisCluster.Client,JedisCluster.Pipeline}; limit=1000000)
    scan_key_with_where_in(key, where_in::String; limit=1000000)

Scans a collection by meta and returns all the objects within a key that match a string.
"""
scan_key_with_where_in(key::String, where_in::String, conn::Union{JedisCluster.Client,JedisCluster.Pipeline}; limit::Int64=1000000) = JedisCluster.execute("SCAN $key WHEREIN $where_in LIMIT $limit", conn)
scan_key_with_where_in(key::String, where_in::String; limit::Int64=1000000) = scan_key_with_where_in(key, where_in, get_global_connection(); limit=limit)

"""
    scan_key_ids_with_where_in(key, where_in::String, conn::Union{JedisCluster.Client,JedisCluster.Pipeline}; limit=1000000)
    scan_key_ids_with_where_in(key, where_in::String; limit=1000000)

Scans a collection by meta and returns all the ids within a key that match a string.
"""
scan_key_ids_with_where_in(key::String, where_in::String, conn::Union{JedisCluster.Client,JedisCluster.Pipeline}; limit::Int64=1000000) = JedisCluster.execute("SCAN $key WHEREIN $where_in LIMIT $limit IDS", conn)
scan_key_ids_with_where_in(key::String, where_in::String; limit::Int64=1000000) = scan_key_with_where_in(key, where_in, get_global_connection(); limit=limit)

"""
    nearby_point(key, limit, lat, lon[, match::String, conn::Union{JedisCluster.Client,JedisCluster.Pipeline}])

Finds all objects within a key (collection) that are near to a certain coordinate.
"""
nearby_point(key, limit, lat, lon, conn::Union{JedisCluster.Client,JedisCluster.Pipeline}) = JedisCluster.execute(["NEARBY", key, "LIMIT", limit, "POINT", lat, lon,], conn)
nearby_point(key, limit, lat, lon, match::String, conn::Union{JedisCluster.Client,JedisCluster.Pipeline}) = JedisCluster.execute(["NEARBY", key, "LIMIT", limit, "MATCH", match, "POINT", lat, lon,], conn)
nearby_point(key, limit, lat, lon, match::String, radius::Float64, conn::Union{JedisCluster.Client,JedisCluster.Pipeline}) = JedisCluster.execute(["NEARBY", key, "LIMIT", limit, "MATCH", match, "POINT", lat, lon, radius], conn)
nearby_point(key, limit, lat, lon, match::String, where_in::String, radius::Float64, conn::Union{JedisCluster.Client,JedisCluster.Pipeline}) = JedisCluster.execute("NEARBY $key LIMIT $limit MATCH $match WHEREIN $where_in POINT $lat $lon $radius", conn)
nearby_point(key, limit, lat, lon) = nearby_point(key, limit, lat, lon, get_global_connection())
nearby_point(key, limit, lat, lon, match::String) = nearby_point(key, limit, lat, lon, match, get_global_connection())
nearby_point(key, limit, lat, lon, match::String, radius::Float64) = nearby_point(key, limit, lat, lon, match, radius, get_global_connection())
nearby_point(key, limit, lat, lon, match::String, where_in::String, radius::Float64) = nearby_point(key, limit, lat, lon, match, where_in, radius, get_global_connection())

"""
    nearby_point_ids(key, limit, lat, lon[, match::String, conn::Union{JedisCluster.Client,JedisCluster.Pipeline}])

Finds all objects within a key (collection) that are near to a certain coordinate.
"""
nearby_point_ids(key, limit, lat, lon, conn::Union{JedisCluster.Client,JedisCluster.Pipeline}) = JedisCluster.execute(["NEARBY", key, "LIMIT", limit, "IDS", "POINT", lat, lon], conn)
nearby_point_ids(key, limit, lat, lon, match::String, conn::Union{JedisCluster.Client,JedisCluster.Pipeline}) = JedisCluster.execute(["NEARBY", key, "LIMIT", limit, "MATCH", match, "IDS", "POINT", lat, lon], conn)
nearby_point_ids(key, limit, lat, lon) = nearby_point_ids(key, limit, lat, lon, get_global_connection())
nearby_point_ids(key, limit, lat, lon, match::String) = nearby_point_ids(key, limit, lat, lon, match, get_global_connection())

"""
    rename_collection(from::String, to::String, conn::Union{JedisCluster.Client,JedisCluster.Pipeline})
    rename_collection(from::String, to::String)

Renames collection "from" key to new "to" key. If new "to" already exists, it will be deleted prior to renaming.
"""
rename_collection(from::String, to::String, conn::Union{JedisCluster.Client,JedisCluster.Pipeline}) = JedisCluster.execute(["RENAME", from, to], conn)
rename_collection(from::String, to::String) = rename_collection(from, to, get_global_connection())
