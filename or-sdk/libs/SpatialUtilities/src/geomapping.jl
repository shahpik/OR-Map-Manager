# Utility functions
"""Swaps an lat-long lon-lat, or vice versa. Does no checking of I/O validty"""
swapxy(line::Vector{Any}) = [Vector{Float64}(reverse(pt)) for pt in line]  # Be careful with typing here
swapxy(line::Vector{Vector{T}}) where T<:AbstractFloat = [Vector{T}(reverse(pt)) for pt in line]  # Be careful with typing here

""" converts linestring arrays of Any{Any} Float64 """
convert_to_float_linestring(ls)::Vector{Vector{Float64}} = Vector{Float64}.(ls)

""" Gets relative angle compared to a reference angle, returns result in the range +/- 180"""
function get_relative_dir(ref_dir::Number, target_dir::Number)
    rel_dir = target_dir - ref_dir
    if (abs(rel_dir) >= 180) 
        rel_dir += (sign(rel_dir) * -360)
    end
    return rel_dir
end


## = Related to matchin linestrings to ways

""" Gets the bounding boxes of a linestring, as a sequence of lat-lon points of the extrema """
function get_linestring_bboxes(linestring, buffer=0)
    bboxes = []
    for i in 1:(length(linestring)-1)
        coords = linestring[i:i+1]
        push!(bboxes, SpatialUtilities.get_linestring_extrema(coords, buffer=buffer))
    end
    return bboxes
end

""" Gets the Way IDs that intersect the a list of bounding boxes"""
function get_isect_wids_from_bboxes(tree, bboxes)
    possible_wids = []
    for bbox in bboxes
        push!(possible_wids, get_isect_ids(tree, bbox))
    end
    return possible_wids
end


""" Returns the direction of the start and end of a way. Ignores way curvature"""
function get_way_heading(g::OSMGraph, wayid; reverse=false, return_units=:degrees)
    o_id = g.ways[wayid].nodes[1]
    d_id = g.ways[wayid].nodes[end]
    if reverse
        return LightOSM.heading(g.nodes[d_id], g.nodes[o_id], return_units)
    else
        return LightOSM.heading(g.nodes[o_id], g.nodes[d_id], return_units)
    end
end

""" 
    get_point_dir(pt_o::Vector, pt_d::Vector; xy=true)

Calcs the heading between two points, input as vectors 
    
`xy=true`: input as long-lat, false for lat-long input
"""
function get_point_dir(pt_o::Vector, pt_d::Vector; xy=true)
    if xy
        geoloc_o = GeoLocation(lat=pt_o[2], lon=pt_o[1])
        geoloc_d = GeoLocation(lat=pt_d[2], lon=pt_d[1])
    else
        geoloc_o = GeoLocation(lat=pt_o[1], lon=pt_o[2])
        geoloc_d = GeoLocation(lat=pt_d[1], lon=pt_d[2])
    end
    return LightOSM.heading(geoloc_o, geoloc_d)
end

""" Returns the a vector of dirs, for each line edge along a linestring"""
function get_dirs_along_linestring(linestring::Vector; xy=true)
    n_edges = length(linestring)-1
    if n_edges<0
        @warn("No edges in linestring, input may be malformed")
        return Float64[]
    end
    edge_dirs = Float64[]
    for edge_index in 1:n_edges
        push!(edge_dirs, get_point_dir(linestring[edge_index], linestring[edge_index+1], xy=xy))
    end
    return edge_dirs
end

""" filters out all ways that don't match angle, except roundabouts if desired """
function remove_all_ways_by_angle!(g::OSMGraph, widlist::Vector{Any}, ls_edge_dirs, angle=30; except_roundabout=true)
    for (i, wids) in enumerate(widlist)
        matches_angle = map(x->filter_ways_by_angle(g, x, ls_edge_dirs[i]; deg_buffer=angle), wids)
        #exception: check for roundabouts.
        if except_roundabout
            exceptions = map(x->LightOSM.is_roundabout(g.ways[x].tags), wids)
            matches_angle = matches_angle .| exceptions
        end
        deleteat!(wids, .!matches_angle)  # delete all not in angle, . is broadcasting the ! operator
    end
end

""" 
    filter_ways_by_angle(g, wayid, ref_angle; deg_buffer=30)::Bool

Returns true or false, if a way's direction matches the reference angle
For two way roads, true if either direction matches 
"""
function filter_ways_by_angle(g, wayid, ref_angle; deg_buffer=30)::Bool
    waydata = g.ways[wayid]
    w_node_o = waydata.nodes[1]
    w_node_d = waydata.nodes[end]
    is_in_angle = filter_node_pair_by_angle(g, w_node_o, w_node_d, ref_angle; deg_buffer=deg_buffer)
    if is_in_angle 
        return true
    elseif !waydata.tags["oneway"]
        return filter_node_pair_by_angle(g, w_node_d, w_node_o, ref_angle; deg_buffer=deg_buffer)
    else
        return false
    end
end

""" Checks if the angle line from one node to another is within the certain degrees"""
function filter_node_pair_by_angle(g, node_o, node_d, ref_angle; deg_buffer=30)::Bool
    n_angle = LightOSM.heading(g.nodes[node_o], g.nodes[node_d])
    return is_within_angle(n_angle, ref_angle, deg_buffer)
end

""" Compares the direction from an origin to a destination, returns if it's within a certain angle in degrees """
function filter_coordinate_pair_by_angle(g, coord_o, coord_d, ref_angle; deg_buffer=30, xy=true)::Bool
    if xy
        o_geo = GeoCoord(lat=coord_o[1], lon=coord_o[2])
        d_geo = GeoCoord(lat=coord_d[1], lon=coord_d[2])
    else
        o_geo = GeoCoord(lat=coord_o[2], lon=coord_o[1])
        d_geo = GeoCoord(lat=coord_d[2], lon=coord_d[1]) 
    end
    angle = LightOSM.heading(o_geo, d_geo)
    @debug angle
    return is_within_angle(angle, ref_angle, deg_buffer)
end


""" Checks if 2 angles (both +/- 180) are within deg_buffer (degrees) of each other"""
function is_within_angle(angle, ref_angle, deg_buffer)
    if deg_buffer > 180  # doesn't make sense to have more than 180 either side
        @warn "Angle degree checking for $deg_buffer > 180, will return true"
        return true
    end
    rel_angle = abs(get_relative_dir(angle, ref_angle))
    return rel_angle <= abs(deg_buffer)
end

""" 
    find_paths_in_frw(g::OSMGraph, path_stem::Vector{T}, 
                      frw::Dict)::Vector{Vector{T}} where T<:Union{Integer, String}

Given a way and a way forward/reverse lookup, finds conencting paths until no more
Multiple paths (i.e. forks in road) will be returned as separate paths (Array of arrays)
Prevents loops by detecting if a way is already in the path, and ends the search

# TODO
Handle logic here for when ways don't link in frw, search for intermediate links on graph.
"""
function find_paths_in_frw(g::OSMGraph, path_stem::Vector{T}, 
                           frw::Dict)::Vector{Vector{T}} where T<:Union{Integer, String}
    next_ways = intersect(frw[path_stem[end]]['f'], keys(frw))
    # stopping condition: no more 'f' connected paths
    if isempty(next_ways)
        return [path_stem]  # must fit return type of function
    else
        path_segments = Vector{T}[]  # holds all results
        for wid in next_ways
            if wid in path_stem  # prevent endlessly going around a roundabout.
                append!(path_segments, [path_stem])
            else
                append!(path_segments, find_paths_in_frw(g, vcat(path_stem, wid), frw))
            end
         end
    end
    return path_segments
end



""" builds a forward/reverse way lookup for all ways in a bag """
function get_frw_lookup(g::OSMGraph, way_bag::Vector{T}; weights_t=nothing) where T<:Union{Integer, String}
    frw = Dict{T, Dict{Char,Vector{T}}}()  
    for wayid in way_bag
        rways= get_connected_ways(g, wayid, dir=:reverse, weights_t=weights_t)
        fways= get_connected_ways(g, wayid, weights_t=weights_t)
        frw[wayid] = Dict(
            'f'=> fways,
            'r'=> rways
        )
    end
    return frw
end

""" 
    get_starting_ways(frw::Dict)

using a forward/reverse way lookup, identifies potential path starts 
either forward/reverse not in list. Has logic that handles two-way roads.
"""
function get_starting_ways(frw::Dict)
    start_ways = Integer[]
    frw_ways = keys(frw)
    for (k,linked_ways) in frw
        # check if it has any a forward or reverse, NOT part of current frw keys set, i.e. external
        if all(map(x->x ∉ frw_ways,  linked_ways['r'])) || all(map(x->x ∉ frw_ways,  linked_ways['f'])) 
            push!(start_ways, k)
        else # possible that keys are in both 'f' and 'r', due to two-way roads
            # check for f/r values that appear in both, that are not part of the frw
            twoways = [f for f in linked_ways['f'] if f in linked_ways['r']]
            if !isempty(setdiff(twoways, frw_ways))  
                push!(start_ways, k)
            end
        end
    end
    return start_ways
end

""" Utility that performs both setdiffs, faster if both inputs are already unique """
get_all_setdiff(set1,set2) = vcat([w for w in set1 if w ∉ set2],[w for w in set2 if w ∉ set1])


""" Gets the permutations of forward, middle and reverse paths, i.e. list of ways"""
function connect_fr_ways(reverse::Vector, middle::Vector, forward::Vector) 
    results = Vector{Integer}[]
    if isempty(forward) && isempty(reverse)
        return [middle]
    end
    if isempty(reverse)
        for f in forward
            push!(results, vcat(middle, f))
        end
    elseif isempty(forward)
        for r in reverse
            push!(results, vcat(r, middle))
        end
    else
        for f in forward
            for r in reverse
                push!(results, vcat(r, middle, f))        
            end
        end
    end
    return results
end

""" 
    get_connected_ways(g::OSMGraph, wayid::Union{Integer, String}; dir=:forward)

Gets a list of all ways connected to the given one, on the graph. It is one-way road aware, 
using the metdata on the graph.

# Arguments
- `g::OSMGraph`: OSM Graph to do the search on 
- `wayid::Union{Integer, String}`: Way Id
- `dir=:forward`: :forward is ways that can exit from the the given, :reverse returns ways 
                  that can lead into the given way.
- `weights_t=nothing`: Optional transposed weights matrix, see docs for get_adjacent_nodes_on_graph

# TODO
Currently doesn't check any Turn restrictions, should add as option

# Note
- Direction :both not supported as logic too complex, each possible edge result needs to be 
direction aware. To get both directions call this function twice with :forward and :reverse
- the 'forward' logic for one way roads only looks for connected ways that is NOT 
linked to the first starting node. So ways that can be reached from the origin node but 
won't result in travelling along the way, will be exluded from results
"""
function get_connected_ways(g::OSMGraph, wayid::Union{Integer, String}; dir=:forward, weights_t=nothing)
    if g.ways[wayid].tags["oneway"] 
        if dir==:forward  # disallow paths going from 1st node
            way_nodes = g.ways[wayid].nodes[2:end]
        elseif dir==:reverse  # disallow paths going to the last node
            way_nodes = g.ways[wayid].nodes[1:end-1]
        else
            throw(DomainError("Direction $dir not implemented, use :forward or :reverse"))
        end
    else
        way_nodes = g.ways[wayid].nodes
    end
    connected_ways = Int[]
    for node_id in way_nodes
        connected_nodes = get_adjacent_nodes_on_graph(g, node_id, dir=dir, weights_t=weights_t)
        filter!(x->x ∉ way_nodes, connected_nodes)
        @debug "node_id:$node_id dir $dir connected nodes $connected_nodes" # debug use
        isempty(connected_nodes) && continue
        for c_n in connected_nodes
            if dir==:forward 
                connected_edge = [node_id, c_n]
            elseif dir==:reverse
                connected_edge = [c_n, node_id]
            end
            push!(connected_ways, g.edge_to_way[connected_edge])
        end
    end    
    return unique!(connected_ways)
end

"""Given node_id and graph, recursively return all adjacent nodes within x 'hops' of node, defined bythe maxhop
# Arguments
- `maxhop::Int64=1`: max number of 'hop's from the starting node to get all nodes
- `dir::Symbol=:forward`:`:forward` finds outgoing nodes from given node, `:reverse` is incoming nodes
- `hop::Int64=1`: should always be 1 when directly called, use for tracking recursion steps to maxhop
- `weights_t::Union{Nothing,AbstractSparseMatrix}=nothing`: Optional: Pass in a copy(transposed(weights)) LightOSM 
weights matrix for use in the 'forward' mode, so column lookup can be used instead of row lookup. For a sparse matrix
col lookup is significantly faster than row lookup. If no weights_t is passed, will default to slower row lookup.
"""
function get_adjacent_nodes_on_graph(g, 
                                     node_id; maxhops::Int64=1, 
                                     dir::Symbol=:forward, 
                                     hop::Int64=1,
                                     weights_t::Union{Nothing,AbstractSparseMatrix}=nothing)::Array{Integer,1}
    if hop > maxhops throw(DomainError("Hop $hop must be less than maxhops $maxhops")) end
    node_index = g.node_to_index[node_id]
    adj_nodes = Int32[]
    if dir==:forward || dir==:both
        if !isnothing(weights_t)  # transposed weights provided, use col lookup
            _res =  rowvals(weights_t[:, node_index])
        else  # row lookup, will be much slower
            _res =  rowvals(g.weights[node_index, :])
        end
        append!(adj_nodes, _res)  # find the nonzeroes -> node index
    end
    if dir==:reverse || dir==:both
        _res = rowvals(g.weights[:, node_index])
        append!(adj_nodes, _res)  # find the nonzeroes -> node index
    end
    dir==:both && unique!(adj_nodes)  # remove possible dupes if going both dirs
    found_nodes_ids = graph_index_to_node(g.index_to_node, adj_nodes)
    hop == maxhops &&  return found_nodes_ids
    # otherwise, not yet reached end hop
    next_found_nodes = Integer[]
    for i in found_nodes_ids
        next_nodes = get_adjacent_nodes_on_graph(g, i, ;maxhops=maxhops, dir=dir, hop=hop+1, weights_t=weights_t)
        append!(next_found_nodes, next_nodes)
    end
    append!(found_nodes_ids, next_found_nodes)
    return unique(found_nodes_ids)
end

"""
    inverse_haversine(lat1,lon1,bearing,distance)

Using Haversines, from a starting lat/lon position determine the lon/lat of a 
second point at some distance along some bearing.

# Arguments
- `lat1::Float`: latitude of starting point, in WGS84 format.
- `lon1::Float`: longitude of starting point, in WGS84 format.
- `bearing::Float`: bearing from starting point to end point, in radians.
- `distance::Float`: distance from starting point to end point, in km.
"""
function inverse_haversine(lat1, lon1, bearing, distance)
    # Convert to radians
    lat1rad = lat1 * (π/180.0)
    lon1rad = lon1 * (π/180.0)
    ang_dist = distance/6378.137 # 6378.137 = earth equatorial radius in km

    # Calculate lat2/lon2 
    lat2_rad = asin(sin(lat1rad) * cos(ang_dist) + cos(lat1rad) * sin(ang_dist) * cos(bearing))

    lon2_rad = lon1rad + atan(sin(bearing) * sin(ang_dist) * cos(lat1rad),
                              cos(ang_dist) - sin(lat1rad) * sin(lat2_rad))

    # convert result to degrees for WGS84
    return(lon2_rad * (180.0/π), lat2_rad * (180.0/π))
end