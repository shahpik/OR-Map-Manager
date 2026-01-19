"""
    deduplicate(v::T)::T where {T <: AbstractVector}

Removes consecutive repeating elements from a vector.

Example: `[1,2,2,3,3,3,4,2,5]`  ->  `[1,2,3,4,2,5]`

# Arguments
- `v::T`: Vector to process.

# Returns
- `::T`: Converted vector.
"""
function deduplicate(v::T)::T where {T <: AbstractVector}
    if length(v) < 2
        return v
    end

    last_e = v[1]
    v1 = T([last_e])
    for e in v
        if e != last_e
            last_e = e
            push!(v1, last_e)
        end
    end

    return v1
end

"""
    deduplicate2(v::T)::T where {T <: AbstractVector}

Removes consecutive repeating patterns of 2 elements from a vector.

Example: `[1,2,1,2,3,4,5,4,5,4,5]`  ->  `[1,2,3,4,5]`

# Arguments
- `v::T`: Vector to process.

# Returns
- `::T`: Converted vector.
"""
function deduplicate2(v::T)::T where {T <: AbstractVector}
    if length(v) < 4
        return v
    end

    v1 = T(v[1:2])
    i = 3
    while i <= length(v)
        if i < length(v)
            if v[i-2:i-1] == v[i:i+1]
                i += 2
                continue
            end
        end
        push!(v1, v[i])
        i += 1
    end
    
    return v1
end

"""
    deduplicate3(v::T)::T where {T <: AbstractVector}

Changes patterns of `ABA` to `A` in a vector.

Example: `[1,2,5,2,3,4,5]`  ->  `[1,2,3,4,5]`

# Arguments
- `v::T`: Vector to process.

# Returns
- `::T`: Converted vector.
"""
function deduplicate3(v::T)::T where {T <: AbstractVector}
    if length(v) < 4
        return v
    end

    v1 = T(v[1:1])
    i = 2
    while i <= length(v)
        if i < length(v)
            # Check if neighbouring elements are the same
            if v[i-1] == v[i+1]
                i += 2
                continue
            end
        end
        push!(v1, v[i])
        i += 1
    end
    
    return v1
end

"""
    deduplicate_path(v::T)::T where {T <: AbstractVector}

Removes the following edge cases in a node path:
- Duplicate consecutive nodes: `ABBC` -> `ABC`.
- Duplicate consecutive patterns of 2: `ABABABC` -> `ABC`.
  This is for when two `EdgePoint`s are joined end-to-end.
- Detour to a side node: `ABABC` -> `ABC`.
  This is for when a matched path briefly matches to a side road in error.

# Arguments
- `v::T`: Vector to process.

# Returns
- `::T`: Converted vector.
"""
function deduplicate_path(v::T)::T where {T <: AbstractVector}
    v1 = copy(v)
    prev_len = length(v)

    while true
        # This order seems to work the best
        v1 = deduplicate(deduplicate3(deduplicate2(v1)))
        len = length(v1)
        (len == prev_len) && break
        prev_len = len
    end

    return v1
end

"""
    interp(a::GeoLocation, b::GeoLocation, alpha::AbstractFloat)

Interpolates a point along a line between two points.

# Arguments
- `a::GeoLocation`: First point.
- `b::GeoLocation`: Second point.
- `alpha::AbstractFloat`: Proportion of distance along the line from `a` to `b`,
  in the range from 0 to 1.

# Returns
- `::GeoLocation`: Interpolated point.
"""
function interp(a::GeoLocation, b::GeoLocation, alpha::AbstractFloat)
    dlon = b.lon - a.lon
    dlat = b.lat - a.lat
    return GeoLocation(
        lon=a.lon + dlon * alpha,
        lat=a.lat + dlat * alpha
    )
end

"""
    node_to_coords(g::OSMGraph, n::AbstractVector{<:Union{Integer, String}})

Converts OSM node IDs to lon-lat coordinates.

# Arguments
- `g::OSMGraph`: LightOSM graph.
- `n::AbstractVector{<:Union{Integer, String}}`: Node IDs to convert.

# Returns
- `::Vector{Vector{<:AbstractFloat}}`: List of coordinates in lon-lat format.
"""
function node_to_coords(g::OSMGraph, n::AbstractVector{<:Union{Integer, String}})
    return [[g.nodes[x].location.lon, g.nodes[x].location.lat] for x in n]
end

"""
    node_to_geoloc(g::OSMGraph, 
                   n::AbstractVector{<:Union{Integer, String}}, 
                   [offset_start::AbstractFloat, 
                   offset_end::AbstractFloat]
                   )

Converts OSM node IDs to `GeoLocation`s.

# Arguments
- `g::OSMGraph`: LightOSM graph.
- `n::AbstractVector{<:Union{Integer, String}}`: Node IDs to convert.
- `offset_start::AbstractFloat` (optional): Offset from first node to second 
  node, from 0 to 1.
- `offset_end::AbstractFloat` (optional): Offset from last node to second-last 
  node, from 0 to 1.

# Returns
- `::Vector{GeoLocation}`: Converted `GeoLocation`s.
"""
node_to_geoloc(g::OSMGraph, n::AbstractVector{<:Union{Integer,String}}) = [g.nodes[x].location for x in n]
function node_to_geoloc(g::OSMGraph, 
                          n::AbstractVector{<:Union{Integer,String}}, 
                          offset_start::AbstractFloat, 
                          offset_end::AbstractFloat
                          )
    path = node_to_geoloc(g, n)
    new_start = interp(path[1], path[2], offset_start)
    new_end = interp(path[end-1], path[end], offset_end)
    path[1] = new_start
    path[end] = new_end
    return path
end

"""
    nodes_to_ways(g::OSMGraph, n::AbstractVector{<:Union{Integer, String}})

Converts a path of node IDs to the way IDs that this path overlaps.

# Arguments
- `g::OSMGraph`: LightOSM graph.
- `n::AbstractVector{<:Union{Integer, String}}`: Node ID path.

# Returns
- `::Vector{<:Union{Integer, String}}`: Path of way IDs.
"""
function nodes_to_ways(g::OSMGraph, n::AbstractVector{<:Union{Integer, String}})
    edges = [[n[i], n[i+1]] for i in 1:length(n)-1]
    ways = [g.edge_to_way[edge] for edge in edges if haskey(g.edge_to_way, edge)]
    return deduplicate(ways)
end

"""
    geoloc_to_coords(v::AbstractVector{<:GeoLocation})

Converts `GeoLocation`s to lon-lat coordinates.

# Arguments
- `v::AbstractVector{<:GeoLocation}`: `GeoLocation`s to convert.

# Returns
- `::Vector{Vector{<:AbstractFloat}}`: Lon-lat coordinate path.
"""
function geoloc_to_coords(v::AbstractVector{<:GeoLocation})
    return [[x.lon, x.lat] for x in v]
end

"""
    geoloc_to_coords(v::AbstractVector{<:GeoLocation})

Converts a `GeoLocation` to lon-lat coordinates.

# Arguments
- `x::GeoLocation`: `GeoLocation` to convert.

# Returns
- `::Vector{Vector{<:AbstractFloat}}`: Lon-lat coordinate path.
"""
function geoloc_to_coords(x::GeoLocation)
    return [x.lon, x.lat]
end

"""
    coords_to_geoloc(v::AbstractVector)

Converts lon-lat coordinates to `GeoLocation`s.

# Arguments
- `v::AbstractVector`: Coordinates in lon-lat format.

# Returns
- `::Vector{GeoLocation}`: Converted `GeoLocation`s.
"""
function coords_to_geoloc(v::AbstractVector)
    return [GeoLocation(x[2], x[1]) for x in v]
end

"""
    get_offset(s::HMMState, node::Union{Integer, String})

Gets the offset of a HMM state's position from one of its nodes.

# Arguments
- `s::HMMState`: HMM state.
- `node::Union{Integer, String}`: Node to check. Must be one of the two nodes that this state 
  sits between.

# Returns
- `::Float64`: Offset from `node` to the next node, from 0 to 1.
"""
function get_offset(s::HMMState, node::Union{Integer, String})
    ep = s.osm_point
    if ep.n2 == node
        return 1 - ep.pos
    end
    return ep.pos
end

"""
    location(g::OSMGraph, ep::EdgePoint)

Gets the coordinates of an `EdgePoint`.

# Arguments
- `g::OSMGraph`: LightOSM graph.
- `ep::EdgePoint`: `EdgePoint` to find location of.

# Returns
- `::GeoLocation`: Coordinates of `EdgePoint`.
"""
function location(g::OSMGraph, ep::EdgePoint)
    return interp(g.nodes[ep.n1].location, g.nodes[ep.n2].location, ep.pos)
end

"""
    nearest_point_on_line(x1::T, 
                          y1::T, 
                          x2::T, 
                          y2::T, 
                          x::T, 
                          y::T
                          )::Tuple{T,T,T} where {T <: AbstractFloat}

Finds the nearest position along a straight line to a given point.

# Arguments
- `x1::T`, `y1::T`: Starting point of the line.
- `x2::T`, `y2::T`: Ending point of the line.
- `x::T`, `y::T`: Point to nearest position to.

# Returns
- `::Tuple`:
  - `::T`: x-coordinate of nearest position.
  - `::T`: y-coordinate of nearest position.
  - `::T`: Position along the line, from 0 to 1.
"""
function nearest_point_on_line(x1::T, 
                               y1::T, 
                               x2::T, 
                               y2::T, 
                               x::T, 
                               y::T
                               )::Tuple{T,T,T} where {T <: AbstractFloat}
    A = x - x1
    B = y - y1
    C = x2 - x1
    D = y2 - y1
    dot = A * C + B * D
    len_sq = C * C + D * D
    param::T = -1.0
    if len_sq != 0 # in case of 0 length line
        param = dot / len_sq
    end
    if param < 0.0
        return (x1, y1, 0.0)
    elseif param > 1.0
        return (x2, y2, 1.0)
    else
        return (x1 + param * C, y1 + param * D, param)
    end
end

"""
    nearest_point_on_way(g::OSMGraph, p::GeoLocation, wid::Union{Integer, String})

Finds the nearest position on a way to a given point. Matches to an `EdgePoint`.

# Arguments
- `g::OSMGraph`: LightOSM graph.
- `p::GeoLocation`: Point to find nearest position to.
- `wid::Union{Integer, String}`: Way ID to search.

# Returns
- `::Tuple`:
  - `::EdgePoint`: Nearest position along the way between two nodes.
  - `::Float`: Distance from `p` to the nearest position on the way.
"""
function nearest_point_on_way(g::OSMGraph, p::GeoLocation, wid::Union{Integer, String})
    nodes = g.ways[wid].nodes
    min_edge = nothing
    min_dist = floatmax()
    min_pos = 0.0
    for edge in zip(nodes[1:end-1], nodes[2:end])
        x1 = g.nodes[edge[1]].location.lon
        y1 = g.nodes[edge[1]].location.lat
        x2 = g.nodes[edge[2]].location.lon
        y2 = g.nodes[edge[2]].location.lat
        x, y, pos = nearest_point_on_line(x1, y1, x2, y2, p.lon, p.lat)
        d = distance(GeoLocation(y, x), p)
        if d < min_dist
            min_edge = edge
            min_dist = d
            min_pos = pos
        end
    end
    return EdgePoint(min_edge[1], min_edge[2], min_pos), min_dist
end
