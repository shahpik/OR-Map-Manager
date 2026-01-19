# TODO: Support for polygons with holes

"""
    libgeos_create_polygon(::Type{<:Ptr},
                           coords_outer::Vector{Vector{Float64}};
                           xy=true, 
                           context::LibGEOS.GEOSContext=LibGEOS.GEOSContext()
                           )::Ptr{GEOSGeometry}

INTERNAL ONLY. Create a LibGEOS polygon object from coordinates.

# Arguments
- `::Type`: Desired return type (optional, defaults to `Ptr`):
    - `::Type{<:Ptr}` (default): Return a LibGEOS.jl `Polygon` object.
    - `::Type{<:Ptr}`: Return a pointer to the underlying libgeos C object.
- `coords_outer::Vector{Vector{Float64}}`: Coordinates for the outer ring (perimeter) of 
    the polygon.
- `tolerance::AbstractFloat=0.00005`: Distance from the original geometry from which the 
    simplified geometry can deviate.

# Keyword arguments
- `xy::Bool=true`: If true, then polygon is in xy (lon-lat) format, else yx (lat-lon).
- `context::LibGEOS.GEOSContext` (optional): GEOSContext object for LibGEOS to use as a 
    memory space. Important for multi-threading and must be passed between functions that
    operate on the same LibGEOS objects. Pass a pre-built GEOSContext to speed this up when 
    running the function many times. See docstring for GEOSContext here:
    https://github.com/JuliaGeo/LibGEOS.jl/blob/master/src/LibGEOS.jl
"""
function libgeos_create_polygon(::Type{<:Ptr},
                                coords_outer::Vector{Vector{Float64}};
                                xy=true, 
                                context::LibGEOS.GEOSContext=LibGEOS.GEOSContext()
                                )::Ptr{LibGEOS.GEOSGeometry}
    if !xy
        polygon = swapxy(polygon)
    end

    # Create polygon in LibGEOS
    outer_ring = LibGEOS.createLinearRing(coords_outer, context)
    polygon = LibGEOS.createPolygon(outer_ring, context)

    return polygon
end
function libgeos_create_polygon(::Type{<:LibGEOS.AbstractGeometry}, 
                                args...; 
                                context::LibGEOS.GEOSContext=LibGEOS.GEOSContext,
                                kwargs...
                                )::LibGEOS.Polygon
    polygon = libgeos_create_polygon(Ptr, args...; context=context, kwargs...)
    return LibGEOS.geomFromGEOS(polygon, context)
end
function libgeos_create_polygon(coords_outer::Vector{Vector{Float64}}, args...; kwargs...)
    return libgeos_create_polygon(LibGEOS.Polygon, coords_outer, args...; kwargs...)
end

"""
    simplify_2d_polygon(coords_outer::Vector,
                        tolerance=0.00005;
                        xy=true, 
                        context=LibGEOS.GEOSContext()
                        )::Vector{Vector{Float64}}

Simplify points from a single polygon to represent it with fewer points.

# Arguments
- `coords_outer::Vector`: Coordinates for the outer ring (perimeter) of 
    the polygon.
- `tolerance::AbstractFloat=0.00005`: Distance from the original geometry from which the 
    simplified geometry can deviate.

# Keyword arguments
- `xy::Bool=true`: If true, then polygon is in xy (lon-lat) format, else yx (lat-lon).
- `context::LibGEOS.GEOSContext` (optional): GEOSContext object for LibGEOS to use as a 
    memory space. Important for multi-threading and must be passed between functions that
    operate on the same LibGEOS objects. Pass a pre-built GEOSContext to speed this up when 
    running the function many times. See docstring for GEOSContext here:
    https://github.com/JuliaGeo/LibGEOS.jl/blob/master/src/LibGEOS.jl
"""
function simplify_2d_polygon(coords_outer::Vector{Vector{Float64}},
                             tolerance::AbstractFloat=0.00005;
                             xy=true, 
                             context::LibGEOS.GEOSContext=LibGEOS.GEOSContext()
                             )::Vector{Vector{Float64}}
    polygon = libgeos_create_polygon(coords_outer; xy=xy, context=context)
    polygon = LibGEOS.simplify(polygon, tolerance, context)
    
    # Return index 1, the outer ring only
    return GeoInterface.coordinates(polygon)[1]
end
function simplify_2d_polygon(coords_outer::Vector, args...; kwargs...)
    simplify_2d_polygon(ls_to_vector(coords_outer), args...; kwargs...)
end

"""
    validate_polygon([::Type],
                     coords_outer::Vector{Vector{Float64}};
                     xy::Bool=true, 
                     context::LibGEOS.GEOSContext=LibGEOS.GEOSContext()
                     )
    
Validate a polygon geometry, including self-intersecting and overlapping geometry. Uses 
the same implementation as described in the PostGIS docs here:
https://postgis.net/docs/ST_MakeValid.html

The validation may split the polygon into multiple parts, so the return value can consist 
of a polygon or a multi-polygon.

# Arguments
- `::Type`: Desired return type (optional, defaults to Vector):
    - `::Type{<:AbstractVector}` (default): Return a Vector of coordinates, may be 
        additionally nested if it is a multi-polygon.
    - `::Type{<:AbstractString}`: Return the geometry in Well-Known Text (WKT) format,
        see here: https://libgeos.org/specifications/wkt/
    - `::Type{<:LibGEOS.AbstractGeometry}`: Return either a LibGEOS.jl Polygon or 
        MultiPolygon object.
- `coords_outer::Vector{Vector{Float64}}`: Coordinates for the outer ring (perimeter) of 
    the polygon.

# Keyword arguments
- `xy::Bool=true`: If true, then polygon is in xy (lon-lat) format, else yx (lat-lon).
- `context::LibGEOS.GEOSContext` (optional): GEOSContext object for LibGEOS to use as a 
    memory space. Important for multi-threading and must be passed between functions that
    operate on the same LibGEOS objects. Pass a pre-built GEOSContext to speed this up when 
    running the function many times. See docstring for GEOSContext here:
    https://github.com/JuliaGeo/LibGEOS.jl/blob/master/src/LibGEOS.jl
"""
function validate_polygon(::Type{<:LibGEOS.AbstractGeometry},
                          coords_outer::Vector{Vector{Float64}};
                          xy::Bool=true, 
                          context::LibGEOS.GEOSContext=LibGEOS.GEOSContext()
                          )
    # Create LibGEOS Polygon object
    polygon = libgeos_create_polygon(Ptr, coords_outer; xy=xy, context=context)

    # Fix up self-intersecting and invalid polygons
    if !LibGEOS.isValid(polygon, context)
        # Use the raw C function because there is no nice wrapper in LibGEOS.jl
        # The _r functions accept the LibGEOS context, making it thread-safe
        polygon = LibGEOS.GEOSMakeValid_r(context.ptr, polygon)
    end
    
    # Convert from libgeos C pointer to LibGEOS.jl object
    return LibGEOS.geomFromGEOS(polygon, context)
end
function validate_polygon(::Type{<:AbstractVector}, 
                          args...;
                          kwargs...
                          )
    p = validate_polygon(LibGEOS.AbstractGeometry, args...; kwargs...)
    return GeoInterface.coordinates(p)  # Convert to coordinates vector
end
function validate_polygon(::Type{<:AbstractString}, 
                          args...;
                          context::LibGEOS.GEOSContext=LibGEOS.GEOSContext(),
                          kwargs...
                          )::String
    p = validate_polygon(LibGEOS.AbstractGeometry, args...; context=context, kwargs...)
    return LibGEOS.writegeom(p, context)  # Convert to well-known text
end
function validate_polygon(coords_outer::Vector{Vector{Float64}}, args...; kwargs...)
    return validate_polygon(Vector, coords_outer, args...; kwargs...)
end

"""
    get_utm_crs(lon, lat)::CoordinateReferenceSystemFormat

Get the Universal Transverse Mercator (UTM) projection at a specified coordinate.

UTM is a series of map projections that splits up the Earth into 60 vertical slices. Each 
slice is called a "UTM zone", and is its own map projection. With UTM, the distance covered 
by a line no matter where it is on the map, unlinke degrees-based systems where geometry is 
stretched out at the poles. It also uses metres for its coordinates. This makes it ideal 
for calculating polygon area using regular geometric methods.

To use UTM, we need to find the local UTM zone for the geometry we are working with using a 
simple caulcation. This is returned as a GeoFormatTypes.jl object.

# Arguments
- `lon::AbstractFloat`: Longitude to find the UTM projection of.
- `lat::AbstractFloat`: Latitude to find the UTM projection of.

# Returns
- `::CoordinateReferenceSystemFormat`: The local UTM projection.
"""
function get_utm_crs(lon, lat)
    # Create a string representing the UTM projection in PROJ format
    # https://proj.org/operations/projections/utm.html
    utm_zone = Int(ceil((lon + 180) / 6))
    south = (lat > 0) ? "" : "+south"
    proj4_str = "+proj=utm +zone=$utm_zone $south"
    return proj4_str
end

""" 
    calculate_area_2d_polygon(coords_outer::Vector, 
                              xy=true; 
                              context=LibGEOS.GEOSContext()
                              )::Float64

Calculate area of a polygon. It CANNOT have holes. It CAN be self-intersecting.

# Arguments
- `coords_outer::Vector`: Coordinates of the polygon's outer ring.

# Keyword arguments
- `xy::Bool=true`: If true, then polygon is in xy (lon-lat) format, else yx (lat-lon).
- `context::LibGEOS.GEOSContext` (optional): GEOSContext object for LibGEOS to use as a 
    memory space. Important for multi-threading and must be passed between functions that
    operate on the same LibGEOS objects. Pass a pre-built GEOSContext to speed this up when 
    running the function many times. See docstring for GEOSContext here:
    https://github.com/JuliaGeo/LibGEOS.jl/blob/master/src/LibGEOS.jl

# Returns
- `::Float64`: Polygon area.
"""
function calculate_area_2d_polygon(coords_outer::Vector{Vector{Float64}}; 
                                   xy::Bool=true, 
                                   context::LibGEOS.GEOSContext=LibGEOS.GEOSContext()
                                   )::Float64
    p = validate_polygon(LibGEOS.AbstractGeometry, coords_outer; xy=xy, context=context)
    return LibGEOS.area(p, context)
end
function calculate_area_2d_polygon(coords_outer::Vector, args...; kwargs...)
    calculate_area_2d_polygon(ls_to_vector(coords_outer), args...; kwargs...)
end

"""
    calculate_area_2d_polygon_geo(coords_outer::Vector;
                                  xy=true, 
                                  context=LibGEOS.GEOSContext()
                                  )::Float64

Calculate area of a geospatial polygon. It CANNOT have holes. It CAN be self-intersecting.

# Arguments
- `coords_outer::Vector`: Coordinates of the polygon's outer ring.

# Keyword arguments
- `xy::Bool=true`: If true, then polygon is in xy (lon-lat) format, else yx (lat-lon).
- `context::LibGEOS.GEOSContext` (optional): GEOSContext object for LibGEOS to use as a 
    memory space. Important for multi-threading and must be passed between functions that
    operate on the same LibGEOS objects. Pass a pre-built GEOSContext to speed this up when 
    running the function many times. See docstring for GEOSContext here:
    https://github.com/JuliaGeo/LibGEOS.jl/blob/master/src/LibGEOS.jl

# Returns
- `::Float64`: Polygon area in square metres.
"""
function calculate_area_2d_polygon_geo(coords_outer::Vector{Vector{Float64}};
                                       context::LibGEOS.GEOSContext=LibGEOS.GEOSContext()
                                       )::Float64
    # Target_crs is assigned the zone of the first coordinate pair   
    target_crs = get_utm_crs(coords_outer[1][1], coords_outer[1][2]) 
    # Reproject coordinates to UTM zone from WGS84
    reprojected_coordinates = copy(coords_outer)
    reproject_coordinates!(reprojected_coordinates, target_crs)
    # Calculate area of polygon using the reprojected coordinates
    area = calculate_area_2d_polygon(reprojected_coordinates, context=context)
    return area
end
function calculate_area_2d_polygon_geo(coords_outer::Vector, args...; kwargs...)::Float64
    calculate_area_2d_polygon_geo(ls_to_vector(coords_outer), args...; kwargs...)
end


""" 
    centroid_2d_polygon(coords_outer::Vector;
                        xyl=true, 
                        context=LibGEOS.GEOSContext()
                        )::Vector{Float64}

Get the centroid of a single polygon.

# Arguments
- `coords_outer::Vector`: Coordinates of the polygon's outer ring.

# Keyword arguments
- `xy::Bool=true`: If true, then polygon is in xy (lon-lat) format, else yx (lat-lon).
- `context::LibGEOS.GEOSContext` (optional): GEOSContext object for LibGEOS to use as a 
    memory space. Important for multi-threading and must be passed between functions that
    operate on the same LibGEOS objects. Pass a pre-built GEOSContext to speed this up when 
    running the function many times. See docstring for GEOSContext here:
    https://github.com/JuliaGeo/LibGEOS.jl/blob/master/src/LibGEOS.jl
"""
function centroid_2d_polygon(coords_outer::Vector{Vector{Float64}};
                             xy::Bool=true, 
                             context::LibGEOS.GEOSContext=LibGEOS.GEOSContext()
                             )::Vector{Float64}
    polygon = libgeos_create_polygon(coords_outer; xy=xy, context=context)
    centroid = LibGEOS.centroid(polygon, context)
    return GeoInterface.coordinates(centroid)
end
function centroid_2d_polygon(coords_outer::Vector, args...; kwargs...)
    centroid_2d_polygon(ls_to_vector(coords_outer), args...; kwargs...)
end

""" 
    get_polygon_wkt(coords_outer::Vector; xy=true)

Transform a polygon as array of points to Well-Known Text (WKT), see here:
https://libgeos.org/specifications/wkt/

# Arguments
- `coords_outer::Vector`: Coordinates of the polygon's outer ring.

# Keyword arguments
- `xy::Bool=true`: If true, then polygon is in xy (lon-lat) format, else yx (lat-lon).

# Return
- `::String`: Well-Known Text representation of the polygon
"""
function get_polygon_wkt(coords_outer::Vector; xy=true)::String
    if !xy
        coords_outer = swapxy(coords_outer)
    end

    poly_str = "POLYGON(("
    for point in coords_outer
        poly_str = poly_str * string(point[1]) * " " * string(point[2]) * ","
    end
    poly_str = poly_str[1:end-1] * "))"
    
    return poly_str
end

""" 
    get_intersection(coordinates_1::Vector, 
                     coordinates_2::Vector;
                     xy=true, 
                     context=LibGEOS.GEOSContext()
                     )::Vector{Vector}

Calculate intersection of two polygons.

# Arguments
- `coordinates_1::Vector`: Coordinates for first polygon.
- `coordinates_2::Vector`: Coordinates for second polygon.

# Keyword arguments
- `xy::Bool=true`: If true, then polygon is in xy (lon-lat) format, else yx (lat-lon).
- `context::LibGEOS.GEOSContext` (optional): GEOSContext object for LibGEOS to use as a 
    memory space. Important for multi-threading and must be passed between functions that
    operate on the same LibGEOS objects. Pass a pre-built GEOSContext to speed this up when 
    running the function many times. See docstring for GEOSContext here:
    https://github.com/JuliaGeo/LibGEOS.jl/blob/master/src/LibGEOS.jl

# Returns
- `::Vector`: Coordinates of resulting polygon(s). Can be a LineString, Polygon or 
    MultiPolygon depending on intersection result, which will affect output dimensions.
"""
function get_intersection(coordinates_1::Vector{Vector{Float64}}, 
                          coordinates_2::Vector{Vector{Float64}};
                          xy::Bool=true, 
                          context::LibGEOS.GEOSContext=LibGEOS.GEOSContext()
                          )::Vector{Vector}
    polygon1 = libgeos_create_polygon(coordinates_1; xy=xy, context=context)
    polygon2 = libgeos_create_polygon(coordinates_2; xy=xy, context=context)
    intersecting_polygon = LibGEOS.intersection(polygon1, polygon2, context)
    return GeoInterface.coordinates(intersecting_polygon)
end
function get_intersection(coordinates_1::Vector, coordinates_2::Vector, args...; kwargs...)
    get_intersection(
        ls_to_vector(coordinates_1), 
        ls_to_vector(coordinates_2), 
        args...; 
        kwargs...
    )
end

""" 
    check_intersect(coordinates_1::Vector, 
                    coordinates_2::Vector;
                    xy=true, 
                    context=LibGEOS.GEOSContext()
                    )::Bool

Check if two polygons intersect.

# Arguments
- `coordinates_1::Vector`: Coordinates for first polygon.
- `coordinates_2::Vector`: Coordinates for second polygon.

# Keyword arguments
- `xy::Bool=true`: If true, then polygon is in xy (lon-lat) format, else yx (lat-lon).
- `context::LibGEOS.GEOSContext` (optional): GEOSContext object for LibGEOS to use as a 
    memory space. Important for multi-threading and must be passed between functions that
    operate on the same LibGEOS objects. Pass a pre-built GEOSContext to speed this up when 
    running the function many times. See docstring for GEOSContext here:
    https://github.com/JuliaGeo/LibGEOS.jl/blob/master/src/LibGEOS.jl

# Returns
- `::Bool`: True if polygons intersect.
"""
function check_intersect(coordinates_1::Vector{Vector{Float64}}, 
                         coordinates_2::Vector{Vector{Float64}};
                         xy::Bool=true, 
                         context::LibGEOS.GEOSContext=LibGEOS.GEOSContext()
                         )::Bool
    polygon1 = libgeos_create_polygon(coordinates_1; xy=xy, context=context)
    polygon2 = libgeos_create_polygon(coordinates_2; xy=xy, context=context)
    return LibGEOS.intersects(polygon1, polygon2)
end
function check_intersect(coordinates_1::Vector, coordinates_2::Vector, args...; kwargs...)
    check_intersect(
        ls_to_vector(coordinates_1), 
        ls_to_vector(coordinates_2), 
        args...; 
        kwargs...
    )
end

""" 
    union_polygons(coordinates_1::Vector, 
                   coordinates_2::Vector;
                   xy=true, 
                   context=LibGEOS.GEOSContext()
                   )::Vector{Vector}

Calculate union of two 2D polygons.

# Arguments
- `coordinates_1::Vector`: Coordinates for first polygon.
- `coordinates_2::Vector`: Coordinates for second polygon.

# Keyword arguments
- `xy::Bool=true`: If true, then polygon is in xy (lon-lat) format, else yx (lat-lon).
- `context::LibGEOS.GEOSContext` (optional): GEOSContext object for LibGEOS to use as a 
    memory space. Important for multi-threading and must be passed between functions that
    operate on the same LibGEOS objects. Pass a pre-built GEOSContext to speed this up when 
    running the function many times. See docstring for GEOSContext here:
    https://github.com/JuliaGeo/LibGEOS.jl/blob/master/src/LibGEOS.jl

# Returns
- `::Vector`: Coordinates of resulting polygon(s). Can be a LineString, Polygon or 
    MultiPolygon depending on union result, which will affect output dimensions.
"""
function union_polygons(coordinates_1::Vector{Vector{Float64}}, 
                        coordinates_2::Vector{Vector{Float64}};
                        xy::Bool=true, 
                        context::LibGEOS.GEOSContext=LibGEOS.GEOSContext()
                        )::Vector{Vector}
    polygon1 = libgeos_create_polygon(coordinates_1; xy=xy, context=context)
    polygon2 = libgeos_create_polygon(coordinates_2; xy=xy, context=context)
    union_polygon = LibGEOS.union(polygon1, polygon2)
    return GeoInterface.coordinates(union_polygon)
end
function union_polygons(coordinates_1::Vector, coordinates_2::Vector, args...; kwargs...)
    union_polygons(
        ls_to_vector(coordinates_1), 
        ls_to_vector(coordinates_2), 
        args...; 
        kwargs...
    )
end

""" 
    reproject_coordinates!(polygon, target_crs)

Reproject coordinates by calling the proj CLI. If there are more than 2000 coordinates, 
then the coordinates are batched into groups of 2000 to not exceed the proj CLI's limit.

# Arguments
- `coordinates::Vector{Vector{Float64}}`: Coordinates to reproject. Modified in-place.
- `target_crs::String`: Target CRS for reprojection in proj format.
"""
function reproject_coordinates!(coordinates::Vector{Vector{Float64}}, target_crs::String)
    BATCH_SIZE = 2000
    if length(coordinates) > BATCH_SIZE
        # Proj is limited to 2000 coordinate pairs per call
        n_batches = Int64(ceil(length(coordinates) / BATCH_SIZE))
        for i in 1:n_batches
            batch_start = (i - 1) * BATCH_SIZE + 1
            batch_end = (i == n_batches) ? length(coordinates) : i * BATCH_SIZE
            batch_view = @view coordinates[batch_start:batch_end]
            _reproject_coordinates!(batch_view, target_crs)
        end
        return coordinates
    else
        _reproject_coordinates!(coordinates, target_crs)
        return coordinates
    end
end

""" 
    _reproject_coordinates!(coordinates, target_crs)

Reproject coordinates by calling the proj CLI. This is a helper function for 
`reproject_coordinates!` and should not be called directly.

# Arguments
- `coordinates::Vector{Vector{Float64}}`: Coordinates to reproject. Modified in-place.
- `target_crs::String`: Target CRS for reprojection in proj format.
"""
# The following function is a recursive function that will transform a polygon into a new polygon with the same structure, but with the coordinates transformed.
function _reproject_coordinates!(coordinates::AbstractVector{<:AbstractVector{<:Float64}}, target_crs::String)
    # Convert coordinates to string
    coordinate_list = join([
        "$(coordinates[i][1]) $(coordinates[i][2])\n" 
        for i in eachindex(coordinates)
    ])
    #coordinate_list = rstrip(coordinate_list, '\n')  # Remove trailing newline
    
    # Generate shell command string. Example:
    # `echo 144.0 -37.0\n144.0 -37.0 | proj +proj=utm +zone=54 +south`
    cmd_string = String("echo $coordinate_list | proj $target_crs")

    # Run proj command
    local stdout
    try
        stdout, _ = run_shell(cmd_string)
    catch
        @error """Error running shell command. The command was:
        $cmd_string

        Check that proj is installed. Try: 
        brew install proj         # Mac
        apt-get install proj-bin  # Ubuntu
        apk add proj-util         # Alpine\n"""
        rethrow()
    end

    # Parse output
    coords = split(stdout, '\n')
    for a in eachindex(coordinates)
        x, y = [parse(Float64, substr) for substr in split(coords[a], '\t')]
        coordinates[a] = [x, y]
    end
end
