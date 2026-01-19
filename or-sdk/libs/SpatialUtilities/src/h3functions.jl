# ==== Convert from H3 Hex index to XY (lon-at) ==== #
"""
    hex_to_xy(hexes::UInt)
    hex_to_xy(hexes::Vector{UInt})

Converts hex index to list of x,y (lon-lat) coordinates of boundary points
"""
function hex_to_xy(hexes::UInt)
    geos = h3ToGeoBoundary(hexes)
    x = [rad2deg(geo.lon) for geo in geos]
    y = [rad2deg(geo.lat) for geo in geos]
    return [x,y]
end
function hex_to_xy(hexes::Vector{UInt})
    filter!(!iszero, hexes)
    x = Vector{Float64}()
    y = Vector{Float64}()
    for hex in (h3ToGeoBoundary(hex) for hex in hexes)
        x_hex, y_hex = hex_to_xy(hex)
        append!(x, x_hex)
        append!(y, y_hex)
    end
    return [x,y]
end


"""
    h3coords_to_xy(geolist::Vector{GeoCoord})

Converts a list of H3 geoCoords to an x (lon) vector and y (lat) vector tuple in degrees.
"""
function h3coords_to_xy(geolist::Vector{GeoCoord})
    x = [rad2deg(pt.lon) for pt in geolist]
    y = [rad2deg(pt.lat) for pt in geolist]
    return x,y
end

"""
    h3coords_to_lat_long(geolist::Vector{GeoCoord})

Converts a list of H3 geoCoords to paired x,y (lon-lat) elements in a linestring vector.
"""
h3coords_to_lat_long(geolist::Vector{GeoCoord}) = [[rad2deg(pt.lat), rad2deg(pt.lon)] for pt in geolist]


"""
    h3_to_geo_location_bounary(hex::UInt64)

Converts hex index into a boundaries points in LightOSM GeoLocation format
"""
h3_to_geo_location_bounary(hex::UInt64) = [LightOSM.GeoLocation(rad2deg(g.lat), rad2deg(g.lon), 0) for g in h3ToGeoBoundary(hex)]


# ==== Convert from XY (Lon-Lat) into H3 hex indexes for points, lines and polygons ==== #

"""
    yx_to_h3coord(y::AbstractFloat, x::AbstractFloat)

Converts y-x (lat-lon) to H3
"""
yx_to_h3coord(y::AbstractFloat, x::AbstractFloat) = GeoCoord(deg2rad(y), deg2rad(x))


"""
    xy_to_h3coord(x::AbstractFloat, y::AbstractFloat)

Converts x-y (lon-lat) to H3
"""
xy_to_h3coord(x::AbstractFloat, y::AbstractFloat) = GeoCoord(deg2rad(y), deg2rad(x))


"""
    xy_to_hex(x::AbstractFloat, y::AbstractFloat, res::Int)

Converts x-y (lon-lat) to Hex id, for given res level
Also defines conventions for handling missing/incomplete data
"""
xy_to_hex(x::AbstractFloat, y::AbstractFloat, res::Int) = geoToH3(xy_to_h3coord(x, y), res)
xy_to_hex(x::Integer, y::Integer, res::Int)=xy_to_hex(Float64(x), Float64(y), res)
xy_to_hex(x::Missing, y::Missing, res) = 0x0000000000000000
xy_to_hex(x::Missing, y, res) = 0x0000000000000000
xy_to_hex(x, y::Missing, res) = 0x0000000000000000

"""
    linestring_to_hex(ls::Vector{Vector{Float64}}, res_level=6)
resolves Linestrings (lat-long) format to a single hex

# Returns
- hex::`UInt64` a single hex id

# TODO
- add proper handler resolving a single hex from multiple hexes
"""
function linestring_to_hex(ls::Vector{Vector{Float64}}, res_level=6)
    npts = length(ls)
    hexes = zeros(UInt, npts)  # blank hexes
    for (i, pt) in enumerate(ls)
        hexes[i] = xy_to_hex(pt[2], pt[1], res_level)
    end
    unique!(hexes)
    if length(hexes) > 1
        sort!(hexes)  # TODO Explore different approaches for this
        @warn "Linestring between $(ls[1]) and $(ls[end]) across $hexes - first hex used, you may want to use linestring_to_all_hex instead"
    end
    return hexes[1]
end
"""
    linestring_to_all_hex(ls::Vector{Vector{Float64}}, res_level=6)
resolves Linestrings (lat-long) to each of the hexes along the way.
Fill in hexes between each hex in result, if points are far apart

# Returns
- hexes::`Vector{UInt64}` a list of hex ids

"""
function linestring_to_all_hex(ls::Vector{Vector{Float64}}, res_level=6)
    if isempty(ls)
        @warn "blank linestring passed to linestring_to_all_hex function!"
        return UInt64[]
    end
    _prevhex = xy_to_hex(ls[1][2], ls[1][1], res_level)
    hexes = [_prevhex]
    for pt in ls
        _currhex = xy_to_hex(pt[2], pt[1], res_level)
        if _currhex != _prevhex
            _mid_hexes = h3Line(_prevhex, _currhex)  # intermediate hexes
            append!(hexes, _mid_hexes[2:end])
            _prevhex = _mid_hexes[end]
        end
    end
    return hexes
end



"""
resolves an OSM Way to a single hex
"""
function way_to_hex(wayid::Union{Integer, String}, g::OSMGraph, res_level=6)
    linestring = osm_way_to_linestring(wayid, g)
    return linestring_to_hex(linestring, res_level)
end


"""
Gets the linestring in lat-lon of an OSM way
"""
function osm_way_to_linestring(wayid::Union{Integer, String}, g::OSMGraph)
    node_list = g.ways[wayid].nodes
    linestring = [[
        g.nodes[n].location.lat,
        g.nodes[n].location.lon
        ] for n in node_list
    ]
    return linestring
end

"""
    Gets hexes inside a polygon (list of lat-lons)

If poly is too small, returns the hex based on the centroid of the poly
by default pads the hex with 1 ring to ensure shape is fully filled

TODO Add handling for 180 /-180 longitude line. Test is currently BROKEN
"""
function get_hexes_inside_polygon(coord_vect::Vector{Vector{T}}, res_level, hex_padding=1) where T <: AbstractFloat
    verts = convert_to_h3_coord(coord_vect)
    return get_hexes_inside_polygon(verts, res_level, hex_padding)
end
function get_hexes_inside_polygon(verts::Vector{GeoCoord}, res_level, hex_padding=1)

    # Danger zone - C-level pointer manipulation
    # =========================================
    # See the tests in H3.jl for the implementation of the polyfill:
    # https://github.com/wookay/H3.jl/blob/77aba2711bddd28897d18544b5071ef3c56d8910/test/h3/lib/regions.jl#L58
    sfGeofence = Geofence(length(verts), pointer(verts))  # struct for C interface
    sfGeoPolygon = GeoPolygon(sfGeofence, 0, C_NULL)  # struct for C interface
    numHexagons = maxPolyfillSize(Ref(sfGeoPolygon), res_level)
    p_hexagons = calloc(numHexagons, sizeof(H3Index))
    polyfill(Ref(sfGeoPolygon), res_level, p_hexagons)
    p = Base.unsafe_convert(Ptr{H3Index}, p_hexagons)  # 'unsafe' methods are low level pointer methods
    v = unsafe_wrap(Vector{H3Index}, p, numHexagons)  # 'unsafe' methods are low level pointer methods
    w = copy(v)  # High level copy is required to ensure the contents of the vector aren't junked when the Prt is freed
    free(p_hexagons)
    # =========================================

    hexagons = filter(!iszero, w)  # or this, shorthand using built in zero filter
    n_hexes = length(hexagons)
    # @info "Created $(n_hexes) Hexes from polygon"
    if iszero(n_hexes)
        # @info "empty poly, shape likely too small, finding hex for centroid instead."
        gc_centroid = get_lat_lon_centroid_geocord(verts)
        return [geoToH3(gc_centroid, res_level)]
    end
    if hex_padding > 0
        padded_hex = kRing.(hexagons, hex_padding)
        hexagons = unique(reduce(vcat, padded_hex))
    end
    return hexagons
end

# ==== Other utils ==== #

"""
    encode_nodes_to_H3_hex(nodes::Dict{Int64, LightOSM.Node{Int64}}, res_level)

Encodes all LightOSM Nodes to hexes
"""
function encode_nodes_to_H3_hex(nodes::Dict{Int64, LightOSM.Node{Int64}}, res_level)
    @info "encoding H3 hexes for $(length(nodes)) nodes"
    node_hex_ids = [geoToH3(GeoCoord(deg2rad(n.location.lat), deg2rad(n.location.lon)), res_level) for (_, n) in nodes]
    return node_hex_ids
end

"""
    get_all_h3_res_levels(gcoord)

For a given GeoCoord, get all 15 of the different zoom level hex tags.
"""
get_all_h3_res_levels(gcoord) = [geoToH3(gcoord, z) for z in 1:15]


"""
    convert_to_h3_coord(geo_list::Vector{LightOSM.GeoLocation})
    convert_to_h3_coord(coord_vect::Vector{Vector{T}}) where T <: String
    convert_to_h3_coord(coord_vect::Vector{Vector{T}}) where T <: AbstractFloat
    convert_to_h3_coord(pt::Vector{String})
    convert_to_h3_coord(pt::Vector{T}) where T <: AbstractFloat

Convert various vector data types to h3 GeoCoords. String/Data array should be in lat-long format, for each coord
"""
function convert_to_h3_coord(geo_list::Vector{LightOSM.GeoLocation})
    output_list = [GeoCoord(deg2rad(pt.lat), deg2rad(pt.lon)) for pt in geo_list]
    return output_list
end
function convert_to_h3_coord(coord_vect::Vector{Vector{T}}) where T <: String
    parsed_vect = [parse.(Float64, coord) for coord in coord_vect]
    return convert_to_h3_coord(parsed_vect)
end
function convert_to_h3_coord(coord_vect::Vector{Vector{T}}) where T <: AbstractFloat
    return [convert_to_h3_coord(pt) for pt in coord_vect]
end
function convert_to_h3_coord(pt::Vector{String})
    return convert_to_h3_coord(parse.(Float64, pt))
end
function convert_to_h3_coord(pt::Vector{T}) where T <: AbstractFloat
    return GeoCoord(deg2rad(pt[1]), deg2rad(pt[2]))
end


"""
    get_lat_lon_centroid(lat_lon_vector::Vector{Vector{T}}) where T <: AbstractFloat

Gets centroid from a list of co-ords, assuimng lat-lon pair vector format.

# TODO
- Improve function to more closely represent a center-of-gravity centroid
"""
function get_lat_lon_centroid(lat_lon_vector::Vector{Vector{T}}) where T <: AbstractFloat
    lons = [l[2] for l in lat_lon_vector]
    lon_c = get_lon_centroid(lons)
    lat_c = sum(l[1] for l in lat_lon_vector) / length(lat_lon_vector)
    return (lat_c, lon_c)
end

"""
    get_lat_lon_centroid_geocord(verts::Vector{GeoCoord})

Gets centroid from a list of co-ords, which are proviced in GeoCoord format.

# TODO
- Improve function to more closely represent a center-of-gravity centroid
"""
function get_lat_lon_centroid_geocord(verts::Vector{GeoCoord})
    lons = [gc.lon for gc in verts]
    lon_c = get_lon_centroid(lons, true)  # use radians
    lat_c = sum(gc.lat for gc in verts)/length(verts)
    return GeoCoord(lat_c, lon_c)
end


"""
    get_lon_centroid(lons, rads=false)

Calculates the lon centroid accouting for crossing dateline

# TODO
- Ensure that this actually finds the correct centroid around dateline
"""
function get_lon_centroid(lons, rads=false)
    if lons_near_dateline(lons, rads)
        @warn "Centroid function may not handle lon wraparound correct, please check result!"
        # Note: This assumes it will go across the date line, even if longer way around
        return (maximum(lons) + abs(minimum(lons))) / 2
    else
        @info "centroid not near dateline"
        return sum(lons)/length(lons)
    end
end


"""
Checks to see if lons are near equator
"""
function lons_near_dateline(lons, rads=false)
    maxl, minl = maximum(lons), minimum(lons)
    if rads
        maxl_cutoff = deg2rad(90)
        minl_cutoff = deg2rad(-90)
    else
        maxl_cutoff, minl_cutoff = 90, -90
    end
    if sign(maxl) != sign(minl)
        if maxl > maxl_cutoff && minl < minl_cutoff
            return true
        end
    end
    return false
end


"""
Returns only the outermost points groups of connected hexes.

Logic is if a point appears 3 times (used by 3 hexes) it is an internal point, ignore. 
only works if all hexes same size
"""
function get_hex_extremities(hex_ids::Vector)
    points = reduce(vcat, h3ToGeoBoundary.(hex_ids))
    pt_counter = Dict(pt => 0 for pt in unique(points))
    for pt in points
        pt_counter[pt] +=1
        if pt_counter[pt] == 3
            delete!(pt_counter, pt)
        end
    end
    return collect(keys(pt_counter))
end



""" 
Generate geojson from hex ids
"""
function get_geojson_from_hexs(hex_ids::Vector)
    hex_data = []
    for hex in hex_ids
        x,y = hex_to_xy(hex)
        coords_poly = vcat([[x[i],y[i]] for i in 1:length(x)], [[x[1],y[1]]])  # close polygon
        push!(hex_data, Dict(
                "type"=> "Feature",
                "properties"=> Dict(
                    "hex_int"=> hex,
                    "hex"=> string(hex, base=16)
                ),
                "geometry"=> Dict(
                    "type"=> "Polygon",
                    "coordinates"=> [coords_poly]  # polygon has extra brackets
                )
            )
        )
    end
        
    gjson = Dict(
        "type" => "FeatureCollection",
        "features"=> hex_data
        )
    return gjson
end