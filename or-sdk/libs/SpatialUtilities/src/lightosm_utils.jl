## Light OSM Utilities

""" Calculates the total distance, given an array of [lons,lats] in sequential order. xy = false for lat-long"""
function lstring_distance(lstring::Vector, xy=true) 
    (length(lstring) < 2) && return 0.0
    floatls = convert_to_float_linestring(lstring)
    return lstring_distance(floatls, xy)
end
function lstring_distance(lstring::Vector{Vector{T}} where T<:AbstractFloat, xy=true) 
    (length(lstring) < 2) && return 0.0
    if xy lstring = swapxy(lstring) end # LightOSM is y-x by default
    distances = [LightOSM.distance(lstring[i], lstring[i+1]) for i in 1:length(lstring)-1]
    local total_distance
    try
        total_distance = sum(distances)
    catch
        @error "Couldn't sum $distances with lstring=$lstring"
    end
    return total_distance
end

""" Calculates the total distance, given an array of nodes in sequential order"""
lnode_distance(g::OSMGraph, lnode) = sum([LightOSM.distance(g.nodes[lnode[i]], g.nodes[lnode[i+1]]) for i in 1:length(lnode)-1])

""" 
for a list of ways, gets the linestring lat-long (yx or xy) coordinates 

For a sequence of ways, function will consider the direction of two-way ways, and try to
infer the correct sequence of node positions to match the way order specified.

If the ways list is not in sequence or a single way id, no correct order can be inferred.

# Assumptions
- ways are connected and in correct order. No garuantees what happens if not.
"""
function get_way_ls_coords(g::OSMGraph, way_path::Vector; xy=true)
    if length(way_path) < 2 
        @debug "Way path too short, default to single way nodes"
        return get_way_ls_coords(g, way_path[1]; xy=xy)
    end
    ls_result = Vector{Float64}[]
    # reversibility check for first way is slightly different
    rev_first_node = reverse_nodes_to_connect_ways(g, way_path[1], way_path[2])
    append!(ls_result, get_way_ls_coords(g, way_path[1]; xy=xy, rev_nodes=rev_first_node[1]))
    for i in 2:length(way_path)
        wayid = way_path[i]
        rev_nodes = reverse_nodes_to_connect_ways(g, way_path[i-1], wayid)
        next_way_coords = get_way_ls_coords(g, wayid; xy=xy, rev_nodes=rev_nodes[2])
        append!(ls_result, next_way_coords[2:end])  # ensure endpoints are deduped
    end
    return ls_result
end
function get_way_ls_coords(g::OSMGraph, wayid::Union{Integer, String}; xy=true, rev_nodes=false)
    !haskey(g.ways, wayid) && @error "Way ID $wayid not found in graph!"
    way_nodes = g.ways[wayid].nodes
    if rev_nodes 
        return [get_node_pos(g, nid, xy) for nid in reverse(way_nodes)]
    else
        return [get_node_pos(g, nid, xy) for nid in way_nodes]
    end
end

""" 
Gets the nodes along listed ways of a coord, accounting for reversed nodes

# Assumptions
- ways are connected and in correct order. No garuantees what happens.
"""
function get_way_ls_nodes(g::OSMGraph, way_path::Vector)
    if length(way_path) < 2 
        @debug "Way path too short, default to single way nodes"
        return get_way_ls_nodes(g, way_path[1])
    end
    ls_result = Integer[]
    # reversibility check for first way is slightly different
    rev_first_node = reverse_nodes_to_connect_ways(g, way_path[1], way_path[2])
    append!(ls_result, get_way_ls_nodes(g, way_path[1]; rev_nodes=rev_first_node[1]))
    for i in 2:length(way_path)
        wayid = way_path[i]
        rev_nodes = reverse_nodes_to_connect_ways(g, way_path[i-1], wayid)
        next_way_nodes = get_way_ls_nodes(g, wayid; rev_nodes=rev_nodes[2])
        append!(ls_result, next_way_nodes[2:end])  # ensure endpoints are deduped
    end
    return ls_result
end
function get_way_ls_nodes(g::OSMGraph, wayid::Union{Integer,String}; rev_nodes=false)
    !haskey(g.ways, wayid) && @error "Way ID $wayid not found in graph!"
    if rev_nodes
        return reverse(g.ways[wayid].nodes)
    else
        return g.ways[wayid].nodes
    end
end

""" 
    reverse_nodes_to_connect_ways(g::OSMGraph, way1::Union{Integer, String}, way2::Union{Integer, String}, first_way=false)

Compares 2 consecutive ways and determines if the node order need to be reversed, so the 
nodes connected in the right sequence. This is because for two way roads, it's possible for 
the nodes to not be in default order when the ways are connected.

The logic works out that you can pass any pair along a way sequence (assuming they are 
properly connected) and the result of which ways need to be reversed in the list is stable, 
not dependent on the order in which you pass the pairs of ways in.

# Arguments
- `g::OSMGraph`: OSM Graph where ways are on
- `way1::Union{Integer, String}`: Way ID of first way
- `way2::Union{Integer, String}`: Way ID of 2nd way
- `ignore_oneway=false`: By default, will not attempt reverse if way is one way. Set to true to disable this check.

# Returns
- `ways_reversible::Vector{Bool}`: a bool for each of the input ways, true if it should be 
reversed (-B), false if it should not (-A).

# Assumptions
- Way data has been checked as being connected, accounting for oneway roads.
- Ways list is connected at the end nodes only. See TODO.

# TODO
A method of detecting reversibility for ways connecting in middle nodes rather than end to end?
"""
function reverse_nodes_to_connect_ways(g::OSMGraph, way1::Union{Integer, String}, way2::Union{Integer, String}; ignore_oneway=false)
    if way1 == way2
        throw(ErrorException("way 1 $way1 cannot be same as way 2, path invalid!"))
    end
    # This logic is relying on the start/end nodes being connected.
    w1_o = g.ways[way1].nodes[1]
    w1_d = g.ways[way1].nodes[end]
    w2_o = g.ways[way2].nodes[1]
    w2_d = g.ways[way2].nodes[end]
    if w1_d == w2_o  # don't reverse either
        ways_reversible = [false, false]  # A A
    elseif w1_d == w2_d  # reverse 2nd way
        ways_reversible = [false, true]  # A B
    elseif w1_o == w2_o  # reverse 1st way
        ways_reversible = [true, false]  # B A
    elseif w1_o == w2_d  # need to reverse both, to connect.
        ways_reversible = [true, true]  # B B
    else
        # Needs logic for checking if two ways aren't connected at the ends
        @debug "endpoint nodes don't match, ways may not be connected. Defaulting to not reversing either ways."
        return [false, false]
    end
    if !ignore_oneway  # must be both NOT be oneway, and wants to reverse, to be true.
        w1_oneway = g.ways[way1].tags["oneway"]
        w2_oneway = g.ways[way2].tags["oneway"]
        ways_reversible[1] = !w1_oneway &&  ways_reversible[1]
        ways_reversible[2] = !w2_oneway &&  ways_reversible[2]
    end
    return ways_reversible    
end

""" 
get way directions of a path, with choice of return formats:
-`:ab`: append -A/-B/-O onto the end, to denote forward/reverse/oneway 
-`:tf`: a Bool vector of True/False to reverse or not

# Note
Way path has to be at least 2 ways long for this to work
"""
function get_way_path_dir_oab(g::OSMGraph, way_path::Vector, format=:ab)
    path_len = length(way_path)
    if path_len < 2
        @warn "Path $way_path length too short, not possible to determine direction"
        return nothing
    end
    rev_list = Bool[]
    push!(rev_list, reverse_nodes_to_connect_ways(g, way_path[1], way_path[2])[1])
    for i in 2:path_len
        wayid = way_path[i]
        rev_nodes = reverse_nodes_to_connect_ways(g, way_path[i-1], wayid)
        append!(rev_list, rev_nodes[2])  # ensure endpoints are deduped
    end
    if format == :tf
        return rev_list
    elseif format == :ab
        wp_with_dir = Vector{String}(undef, path_len)
        for i in 1:path_len
            wp_with_dir[i]=append_way_oab(way_path[i], rev_list[i]; g=g)
        end
        return wp_with_dir
    else
        throw(DomainError("$Format not implemented, choose either :ab or :tf as formats"))
    end
end

"""
get way directions of a path for a single path where length is 1 :

# Arguments
- `g::OSMGraph`: OSM Graph where ways are on
- `waypath::Union{Integer, String}`: array containing the string of way IDs to make the path, for this function there will only be one way ID
- `raw_ls::Vector`: raw linestring of coordinates which is required to determine the direction of the way

# Returns
- `wp_with_dir::Vector{String}`: an array which contains the way ID with the direction attached to it
# Note
This method is used to handle a single way path as additional checks are required for single paths
"""

function get_way_path_dir_oab_single(g::OSMGraph, way_path::Vector, raw_ls::Vector)
    path = way_path[1]

    a_angle = get_way_heading(g, path)
    b_angle = get_way_heading(g, path, reverse=true)

    raw_angle = get_point_dir(raw_ls[1], raw_ls[end])

    a_diff = abs(raw_angle - a_angle)
    b_diff = abs(raw_angle - b_angle)

    if a_diff < b_diff
        reverse_flag = false
    else
        reverse_flag = true
    end

    wp_with_dir = [append_way_oab(path, reverse_flag; g=g)]
    return wp_with_dir
        
end

""" Tags ways by the direction using the -O/-A/-B system used in the core schema"""
function append_way_oab(wayid::Integer, rev::Bool; g=nothing, oneway=nothing)
    if isnothing(oneway)
        if isnothing(g)
            throw(ArgumentError("must supply one of g or oneway!"))
        end
        oneway = g.ways[wayid].tags["oneway"] == true
    end 
    if oneway
        return string(wayid) * "-O"
    else
        if rev  # reverse = tue, means -B
            return string(wayid) * "-B"
        else 
            return string(wayid) * "-A"
        end
    end
end


""" 
get the directional way id using the -O/-A/-B system in the core Schema, from a pair of nodes

# Note
- If the nodes provided are not on the same way, will return a guess at the default
- If the way is a oneway road, it will always return 'false' i.e. the -O option
TODO: A better fallback method for nodes on different ways, that looks at the direction 
between nodes, and tries to guess the direction
"""
function get_way_oab_from_node_pair(g, node_o, node_d)
    waylist = intersect(g.node_to_way[node_o], g.node_to_way[node_d])
    if length(waylist)==1
        _way_id = waylist[1]
    elseif isempty(waylist)
        # a bad guess. There could be multiple ways
        @debug "Nodes not on the same way, returning default of node $node_o"
        _way_id = g.node_to_way[node_o][1]
    else
        @debug "Multiple ways detected! Returning default of node $node_o"
        _way_id = g.node_to_way[node_o][1]
    end
    if g.ways[_way_id].tags["oneway"]
        return append_way_oab(_way_id, false, oneway=true)
    else
        rev = get_way_dir_from_node_pair(node_o, node_d, g.ways[_way_id].nodes)
        return append_way_oab(_way_id, rev, oneway=false)
    end
end

""" 
get way directions by checking the order of the nodes on the way

# Returns
- `false` if the node pair is in the 'natural' direction
- `true` if the road should be reversed

# Note
Does NOT check for oneway! Assumes node list is in order
"""
function get_way_dir_from_node_pair(node_o::Int, node_d::Int, way_nodes::Vector{Int})
    if node_o == node_d
        @warn "Input Nodes are the same during way dir lookup! $node_o Default returned"
        return false
    end
    node_o_ind = findfirst(x->x==node_o, way_nodes)
    node_d_ind = findfirst(x->x==node_d, way_nodes)
    if isnothing(node_o_ind) || isnothing(node_d_ind)
        @warn "Warning nodes $node_o $node_d not on same way for dir lookup! Default returned."
        return false
    elseif node_o_ind < node_d_ind
        return false
    elseif node_o_ind > node_d_ind
        return true
    else  # somehow the indicies are equal?? Something went wrong, should not be possible
        throw(DomainError("Data error: Indicies for nodes $node_o $node_d is equal along way nodes $way_nodes"))
    end
end

""" 
    get_way_path_start_end_node(g, way_path)

returns the start and end nodes from a path, considering reversible ways 
# Note:
- Won't work if the way_path is just a single way, will return the default start/end
node
"""
function get_way_path_start_end_node(g, way_path)
    if length(way_path) < 2
        @debug "single way only! Default start/end nodes returned"
        way_nodes = g.ways[way_path[1]].nodes
        return [way_nodes[1], way_nodes[end]]
    end
    rev_ways = reverse_nodes_to_connect_ways(g, way_path[1], way_path[2])
    if rev_ways[1]
        start_node = g.ways[way_path[1]].nodes[end]
    else
        start_node = g.ways[way_path[1]].nodes[1]
    end
    if rev_ways[2]
        end_node = g.ways[way_path[end]].nodes[1]
    else
        end_node = g.ways[way_path[end]].nodes[end]
    end
    return [start_node, end_node]
end

""" Gets the coordinate pair of a node, as xy or yx  """
function get_node_pos(g::OSMGraph, nodeid::Union{Integer, String}, xy=true)
    if xy
        return [Float64(g.nodes[nodeid].location.lon), Float64(g.nodes[nodeid].location.lat)]
    else
        return [Float64(g.nodes[nodeid].location.lat), Float64(g.nodes[nodeid].location.lon)]
    end 
end

""" convert from a LightOSM graph indicies to node ids, types are per OSMGraph fields"""
graph_index_to_node(i_n_dict::OrderedDict{Int32,Int64}, out_index::Array{Int32,1}) = Integer[i_n_dict[x]::Int64 for x in out_index]



"""
    function interpolate_path(
        path::Vector{<:GeoLocation}; 
        interval=nothing, 
        num_intervals=nothing,
        min_interval=nothing,
        append_endpoint=true
    )

Interpolate uniformly spaced points along a linestring.

# Arguments:
- `path::Vector{<:GeoLocation}`: The path to interpolate along.
- `interval`: Space between the interpolated points in kilometres.
Overriden if `num_intervals` is set.
- `num_intervals`: Calculate the `interval` from the number of segments to
  split the line into.
- `min_interval`: If using `num_intervals`, make sure the interval length is not
  shorter than this value (in kilometres).
- `append_endpoint`: Whether to append the original endpoint of the linestring
  onto the output points.

# Returns:
`Vector{GeoLocation}`: The linearly interpolated points.
"""
function interpolate_path(
        path::Vector{<:GeoLocation}; 
        interval=nothing, 
        num_intervals=nothing,
        min_interval=nothing,
        append_endpoint=true
    )
    # Calculate interval distance from num_intervals
    if !isnothing(num_intervals)
        total_length = 0
        prev_point = path[1]
        for point in path[2:end]
            total_length += LightOSM.distance(prev_point, point)
            prev_point = point
        end
        interval = total_length / num_intervals

        # Reduce number of intervals if exceeds min_interval
        if !isnothing(min_interval)
            interval = max(min_interval, interval)
        
        # Don't append endpoint if we are perfectly splitting the line, because
        # this will cause a duplicate point
        else
            append_endpoint = false
        end
    end

    interp_points = GeoLocation[path[1]]
    prev_offset = 0
    prev_point = path[1]
    for point in path[2:end]

        dist = LightOSM.distance(prev_point, point)
        
        # No room for any points; skip
        if (prev_offset + dist) < interval
            prev_point = point
            prev_offset += dist
            continue
        end

        offset_start = interval - prev_offset
        offset_start_point = lerp(prev_point, point, offset_start / dist)

        num_additional_points, offset_end = abs.(divrem(dist - offset_start, interval))

        # Only room for one point; just add this point
        if num_additional_points == 0
            push!(interp_points, offset_start_point)
            prev_point = point
            prev_offset = offset_end
            continue
        end

        offset_end_point = lerp(point, prev_point, offset_end / dist)

        # Only room for two points; just add start and end point
        if num_additional_points == 1
            push!(interp_points, offset_start_point)
            push!(interp_points, offset_end_point)
            prev_point = point
            prev_offset = offset_end
            continue
        end

        # Interpolate
        interval_lon = (offset_end_point.lon - offset_start_point.lon) / num_additional_points
        interval_lat = (offset_end_point.lat - offset_start_point.lat) / num_additional_points

        push!(interp_points, offset_start_point)
        for i = 1:num_additional_points-1
            new_lon = offset_start_point.lon + interval_lon * i
            new_lat = offset_start_point.lat + interval_lat * i
            interp_point = GeoLocation(lon=new_lon, lat=new_lat)
            push!(interp_points, interp_point)
        end
        push!(interp_points, offset_end_point)

        prev_point = point
        prev_offset = offset_end
    end

    # Append endpoint
    if append_endpoint
        push!(interp_points, path[end])
    end

    return interp_points
end

"""
    lerp(a::GeoLocation, b::GeoLocation, alpha::AbstractFloat)

Linearly interpolate a point along a line defined by two `GeoLocation`s. 
Interpolates along the Euclidean line between these points.

# Arguments
- `a::GeoLocation`: Start point of line
- `b::GeoLocation`: End point of line
- `alpha::AbstractFloat`: Value between 0 and 1 indicating how far along the
line the output point should be. 0 is point `a`, 1 is point `b`.

# Returns
`GeoLocation`: Linearly interpolated point.
"""
function lerp(a::GeoLocation, b::GeoLocation, alpha::AbstractFloat)
    dlon = b.lon - a.lon
    dlat = b.lat - a.lat
    return GeoLocation(
        lon=a.lon + dlon * alpha,
        lat=a.lat + dlat * alpha
    )
end

"""
    linestring_to_geolocations(ls, xy=true)

Convert a linestring in Vector{Vector{<:AbstractFloat}} format to
Vector{GeoLocation}.
"""
function linestring_to_geolocations(ls, xy=true)
    if xy
        return [GeoLocation(lon=p[1], lat=p[2]) for p in ls]
    else
        return [GeoLocation(lat=p[1], lon=p[2]) for p in ls]
    end
end

""" 
    get_nodepath_extrema(g::OSMGraph, nodepath)

Finds the extrema (i.e. bounding box) of a nodepath, which is a vector of OSM nodes.
Nodes does not have to be ordered.

Returns the bounding box in the format of [(min_x, min_y), (max_x, max_y)]
"""
function get_nodepath_extrema(g::OSMGraph, nodepath)
    lats = map(x->g.nodes[x].location.lat, nodepath)
    lons = map(x->g.nodes[x].location.lon, nodepath)
    min_pt = (minimum(lons), minimum(lats))
    max_pt = (maximum(lons), maximum(lats))
    return (min_pt, max_pt)
end

""" returns the bbox for a way from a graph """
function get_way_extrema(g::OSMGraph, way::Union{Integer, String})
    return get_nodepath_extrema(g, g.ways[way].nodes)
end

""" returns the bbox for a list of x-y coordinates """
function get_linestring_extrema(ls::Vector; buffer=0)
    xs = map(x->x[1], ls)
    ys = map(x->x[2], ls)
    min_pt = (minimum(xs) - buffer, minimum(ys) - buffer)
    max_pt = (maximum(xs) + buffer, maximum(ys) + buffer)
    return (min_pt, max_pt)
end

""" 
    get_way_boxes(g::OSMGraph)

creates bounding boxes for all ways in a LightOSM graph, returns them along with the way ids
"""
function get_way_boxes(g::OSMGraph)
    way_ids = Int[]
    n_ways = length(g.ways)
    # Tuples makes things fast
    box_coords = Vector{Tuple{Tuple{Float64, Float64}, Tuple{Float64, Float64}}}(undef, n_ways)
    for (i, way_data) in enumerate(g.ways)
        push!(way_ids, way_data.first)  # way_data is now a pair, due to enumerate
        bbox = get_nodepath_extrema(g, way_data.second.nodes)
        box_coords[i] = bbox
    end
    return way_ids, box_coords
end

"""
    total_network_distance(g::OSMGraph)

Calculates the total length of all ways in the OSM graph in km.
"""
function total_graph_distance(g::OSMGraph)
    total_distance = 0.0
    for (wid, _) in g.ways
        total_distance += lstring_distance(get_way_ls_coords(g, wid))
    end
    return total_distance
end

"""
    total_geojson_distance(geoj::AbstractDict)

Calculates the total length of all `LineString`s and `MultiLineString`s in a GeoJSON 
`FeatureCollection`.
"""
function total_geojson_distance(geoj::AbstractDict)
    total_distance = 0.0
    for f in geoj["features"]
        if f["geometry"]["type"] == "LineString"
            total_distance += lstring_distance(f["geometry"]["coordinates"])
        elseif f["geometry"]["type"] == "MultiLineString"
            total_distance += sum(lstring_distance.(f["geometry"]["coordinates"]))
        end
    end
    return total_distance
end
function total_geojson_distance(filename::AbstractString)
    geoj = open(filename) do f
        JSON3.read(f, Dict)
    end
    @info "Loaded file"
    return total_geojson_distance(geoj)
end

"""
    compass_direction(ls)::String
    compass_direction(way)::String
    compass_direction(g, way_id)::String

Gets the compass direction for a linestring or way.

# Arguments
- `ls`: Linestring as `Vector{Vector{Float64}}` or `Vector{GeoLocation}`.
- `g`: LightOSM graph.
- `way_id`: OSM way ID.

# Returns
- `::String`: "NORTHBOUND", "SOUTHBOUND", "EASTBOUND" or "WESTBOUND".
"""
function compass_direction(ls::AbstractVector{GeoLocation})
    if length(ls) < 2
        @warn "Linestring has less than 2 points, unable to determine direction"
        return ""
    end
    ang = heading(ls[1], ls[end], :degrees)
    if ang < -135 || ang > 135
        return "SOUTHBOUND"
    elseif ang < -45
        return "WESTBOUND"
    elseif ang > 45
        return "EASTBOUND"
    else
        return "NORTHBOUND"
    end
end
function compass_direction(ls::AbstractVector, xy=true)
    if xy
        return compass_direction([GeoLocation(lon=x[1], lat=x[2]) for x in ls])
    else
        return compass_direction([GeoLocation(lat=x[1], lon=x[2]) for x in ls])
    end
end
function compass_direction(g::OSMGraph, way_id::Integer)
    return compass_direction([g.nodes[nid].location for nid in g.ways[way_id].nodes])
end

"""
    ls_to_vector(ls::Vector)::Vector{Vector{Float64}}

Convert a `Vector` of any numeric type to a `Vector{Vector{Float64}}` linestring.
"""
ls_to_vector(ls::Vector)::Vector{Vector{Float64}} = Vector{Float64}.(ls)
