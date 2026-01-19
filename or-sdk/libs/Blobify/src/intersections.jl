""" To reduce verbosity in function definitions """
NodeSetType = Set{<:Integer}
IncOutDictType = Dict{<:Integer,<:NodeSetType}

"""
    is_intersection_simple(inc::AbstractSet, out::AbstractSet)::Bool

For any node, determines if it is an intersection centroid node by checking the 
number of incoming vs outgoing nodes. Does not actually need the node itself, 
just the incoming/outgoings for that node. 

This function detects all intersections where three edges intersect regardless 
of direction.

# Arguments
- `inc::AbstractSet`: All OSM node IDs going into this node.
- `out::AbstractSet`: All OSM nodes IDs going out of this node.

# Returns
- `::Bool`: Whether this node satisfies the definition of an intersection.
"""
function is_intersection_simple(inc::AbstractSet, out::AbstractSet)::Bool
    return length(union(inc, out)) >= 3
end

""" 
    is_intersection_simulation(inc::AbstractSet, out::AbstractSet)::Bool

For any node, determines if it is an intersection centroid node by checking the 
number of incoming vs outgoing nodes. Does not actually need the node itself, 
just the incoming/outgoings for that node. 

This function detects all nodes where vehicles might have to give way to another
vehicle. An intersection node must meet the following criteria:
* (A) 1 or more outgoing nodes
* Satisfies one or more of the following:
  * (B) 3 or more incoming nodes
  * (C) Exactly 2 incoming nodes, and at least 1 outgoing node that is not also
    an incoming node

(A) is a minimum requirement for an intersection. A vehicle must be able to exit
the intersection.

(B) checks for intersections with 3 or more incoming branches. This is most 
intersections. Examples:
```
      ▲      
      |      
      ▼      
◀----▶∘◀----▶    ◀----▶∘◀----▶
      ▲                ▲      
      |                |      
      ▼                ▼      
```

(C) specially handles intersections with 2 incoming branches. It accepts 
intersections such as these:
```
      ▲      
      |      
      |      
-----▶∘-----▶    -----▶∘-----▶
      ▲                ▲      
      |                |      
      |                |      
```
but rejects this special case which is not a real intersection:
```
-----▶∘◀----▶
```

This function intentionally does NOT detect the following intersection because 
vehicles do not have to give way here. Use `is_intersection_simple` if you 
want to also detect this case.
```
-----▶∘-----▶
      |
      |
      ▼
```

# Arguments
- `inc::AbstractSet`: All OSM node IDs going into this node.
- `out::AbstractSet`: All OSM nodes IDs going out of this node.

# Returns
- `::Bool`: Whether this node satisfies the definition of an intersection.
"""
function is_intersection_simulation(inc::AbstractSet, out::AbstractSet)::Bool
    A = length(out) >= 1
    B = length(inc) >= 3
    C = length(inc) == 2 && !issubset(out, inc)
    return A && (B || C)
end

"""
    is_roundabout_node(g::OSMGraph, node::Integer)::Bool

Checks if a node lies on a roundabout.
"""
function is_roundabout_node(g::OSMGraph, node::Integer)::Bool
    ways = g.node_to_way[node]
    for way in ways
        if is_roundabout_way(g, way)
            return true
        end
    end
    return false
end

"""
    is_roundabout_way(g::OSMGraph, way::Integer)::Bool

Checks if a way is a roundabout.
"""
function is_roundabout_way(g::OSMGraph, way::Integer)::Bool
    return get(g.ways[way].tags, "junction", "") == "roundabout"
end

"""
    is_roundabout_way(g::OSMGraph, way::Integer)::Bool

Checks if a node has a traffic signal.
"""
function is_traffic_signal(g::OSMGraph, node::Integer)::Bool
    return get(g.nodes[node].tags, "highway", "") == "traffic_signals" || haskey(g.nodes[node].tags, "traffic_signals")
end

"""
    is_carriageway_change(g::OSMGraph, 
                          int_node::Integer, 
                          inc_nodes::AbstractSet{<:Integer}, 
                          out_nodes::AbstractSet{<:Integer}
                          )::Bool

Returns `true` if there is a change in carriageway configuration at an 
intersection.

# Arguments
- `g::OSMGraph`: LightOSM graph.
- `cen_node::Integer`: Centroid node for this intersection.
- `inc_nodes::NodeSetType`: Incoming nodes for this intersection.
- `out_nodes::NodeSetType`: Outgoing nodes for this intersection.

# Returns
- `::Bool`: If intersection contains a change of carriageway configuration.
"""
function is_carriageway_change(g::OSMGraph, 
                               cen_node::Integer, 
                               inc_nodes::NodeSetType, 
                               out_nodes::NodeSetType
                               )::Bool
    way_ids = unique(g.node_to_way[cen_node])
    # Sort by road name to catch CoC's that occur inside intersections
    road_names = Set([get(g.ways[w].tags, "name", "") for w in way_ids])
    road_way_map = Dict(road_names .=> [[w for w in way_ids if (get(g.ways[w].tags, "name", "") == rn)] for rn in road_names])

    cwc_detected = false
    for (road_name, road_ways) in road_way_map
        if length(road_ways) != 3
            continue
        end

        # Must be 3 unique nodes; 1 node occurs twice; 2 nodes occur once
        # This misses changes of carriageway within a dual carriageway system
        all_inout_nodes = [inc_nodes..., out_nodes...]
        inout_nodes = [n for n in all_inout_nodes if !isempty(intersect(g.node_to_way[n], road_ways))]
        counts = [count(==(i), inout_nodes) for i in unique(inout_nodes)]
        if !((length(counts) == 3) && (count(==(2), counts) == 1) && (count(==(1), counts) == 2))
            # Skip if the intersection doesn't have the the right node configuration
            continue
        # Catch CoC intersections along one-way roads
        elseif all([get(g.ways[w].tags, "oneway", "no") == "yes" for w in road_ways])
            if ((length(counts) == 3) && (count(==(1), counts) && 3))
                if length(Set([get(g.ways[w].tags, "highway", "") for w in road_ways])) == 1 # all ways of same type
                    cwc_detected = true
                    break
                end
            end
        end

        # If we get here, we have the correct node configuration and not all ways are one-way
        cwc_detected = true
        break
    end

    return cwc_detected
end

"""
    inc_highway_types(intsc::Intersection)

Gets the values of the OSM "highway" tag for all incoming nodes.
"""
function inc_highway_types(intsc::Intersection)
    return [get(intsc.ways[wid].tags, "highway", "other") for wid in intsc.inc_ways]
end

"""
    out_highway_types(intsc::Intersection)

Gets the values of the OSM "highway" tag for all outgoing nodes.
"""
function out_highway_types(intsc::Intersection)
    return [get(intsc.ways[wid].tags, "highway", "other") for wid in intsc.out_ways]
end

"""
    get_internal_ways(g::OSMGraph, 
                      all_nodes::Set{T}
                      )::NodeSetType where T <: Integer

Gets all ways that are entirely composed of the nodes in `all_nodes`.

# Arguments
- `g::OSMGraph`: LightOSM graph.
- `all_nodes::Set{T}`: Nodes to find internal ways for.

# Returns
- `::NodeSetType`: All ways within the set of nodes.
"""
function get_internal_ways(g::OSMGraph, 
                           all_nodes::Set{T}
                           )::NodeSetType where T <: Integer
    ways = Set{T}()
    for nid in all_nodes
        node_ways = g.node_to_way[nid]
        for wid in node_ways
            way_nodes = g.ways[wid].nodes
            if length(setdiff(way_nodes, all_nodes)) == 0
                push!(ways, wid)
            end
        end
    end
    return ways
end

"""
    path_from_parents(parents::Dict{<:Integer,<:Integer},
                      goal::Integer
                      )::AbstractVector{<:Integer}

Helper function for `adjacent_intersections`. Given the Dijkstra states for a 
node, finds the path from the goal node back to the start node. Adapted from 
LightOSM.

# Arguments
- `parents::Dict{<:Integer,<:Integer}`: Mapping of child nodes to parent nodes.
- `goal::Integer`: Goal node.

# Returns
- `::AbstractVector{<:Integer}`: Node path from start to goal.
"""
function path_from_parents(parents::Dict{<:Integer,<:Integer},
                           goal::Integer
                           )::AbstractVector{<:Integer}
    parents[goal] == 0 && return
    
    pointer = goal
    path = Integer[]
    
    while pointer != 0 # parent of origin is always 0
        push!(path, pointer)
        pointer = parents[pointer]
    end

    return reverse(path)
end

"""
    adjacent_intersections(g::OSMGraph, 
                           start::Integer, 
                           centroids::NodeSetType, 
                           max_distance::AbstractFloat
                           )::Tuple{<:AbstractVector{<:Integer},<:AbstractVector{AbstractVector{<:Integer}}}

Finds connected centroids to a particular intersection node, and returns the 
paths to the node. Uses `search_nearby_nodes` for Dijkstra search up to
`max_distance`.

# Arguments
- `g::OSMGraph`: LightOSM graph.
- `start::Integer`: Starting intersection node.
- `centroids::NodeSetType`: All intersection centroid nodes.
- `max_distance::AbstractFloat`: Maximum distance to explore along the graph.
- `direction::Symbol=:any`: Direction to search relative to direction of traffic
    flow. Options are `:any`, `:forward` (searches along outgoing nodes), and
    `:backward` (searches along incoming nodes). Any other value defaults to
    `:any`.

# Returns
- `::Tuple`:
  - `::Vector{<:Integer}`: Connected centroid nodes.
  - `::Vector{<:Vector{<:Integer}}`: Paths to each centroid node.
"""
function adjacent_intersections(g::OSMGraph, 
                                start::Integer, 
                                centroids::NodeSetType, 
                                max_distance::AbstractFloat,
                                direction::Symbol=:any
                                )::Tuple{<:AbstractVector{<:Integer},<:AbstractVector{AbstractVector{<:Integer}}}

    return search_nearby_nodes(g, start, is_node_in_centroids, max_distance, direction; centroids=centroids)
end

"""
    is_node_in_centroids(n::Integer,
                         g::OSMGraph;
                         centroids::NodeSetType
                         )::Bool

Determine whether a node is a centroid in the set `centroids`.

# Arguments
- `n::Integer, OSM ID of the node to check.
- `g::OSMGraph, LightOSM graph representation of the network.

# Keyword arguments
- `centroids::NodeSetType`, Set of centroid nodes to check membership of `n`.
- `kwargs...`, additional kwargs as passed by e.g. `Blobify.search_nearby_nodes`.

# Returns
- `::Bool`, `true` if `n` is in `centroids`, otherwise `false`.
"""
function is_node_in_centroids(n::Integer,
                              g::OSMGraph;
                              centroids::NodeSetType,
                              kwargs...
                              )::Bool
    return in(n, centroids)
end

"""
    is_node_traffic_light(n::Integer, g::OSMGraph, kwargs...)::Bool

Returns `true` if an OSM Node with ID `n` is tagged as having a traffic light.

# Arguments
- `n::Integer`, OSM ID of the node to check for traffic lights.
- `g::OSMGraph`, LightOSM graph representation of the network.

# Keyword Arguments
- `kwargs...`, additional kwargs as passed by e.g. `Blobify.search_nearby_nodes`.

# Returns
- `true` if the node is tagged with `highway=traffic_signals`, otherwise `false`.
"""
function is_node_traffic_light(n::Integer, g::OSMGraph, kwargs...)::Bool
    return get(g.nodes[n].tags, "highway", "") == "traffic_signals"
end

"""
    search_nearby_nodes(g::OSMGraph,
                        start::Integer,
                        is_target::Function,
                        max_distance::AbstractFloat,
                        direction::Symbol=:any;
                        kwargs...
                        )::Tuple{<:AbstractVector{<:Integer},<:AbstractVector{AbstractVector{<:Integer}}}

Generic node search using Dijkstra's algorithm. Searches up to `max_distance`,
using the function passed as `is_target` to determine if a target node is found.
Any visited nodes for which `is_target` returns `true` are returned, as well as
the shortest path. The nodes along the path are internal nodes to the intersection.

# Arguments
- `g::OSMGraph`, LightOSM graph representation of the network.
- `start::Integer`, OSM ID of the node to start searching from.
- `is_target::Function`, Function to determine if a node is a target node.
    Must be a Function that accepts a node ID (as `Integer`) and the
    `OSMGraph` as arguments, as well as a (potentially empty) set of `kwargs` to
    be expanded. `is_target` must return a Bool.
- `max_distance::AbstractFloat`, Distance to search up to, in kilometres.
- `direction::Symbol=:any`: Direction to search relative to direction of traffic
    flow. Options are `:any`, `:forward` (searches along outgoing nodes), and
    `:backward` (searches along incoming nodes). Any other value defaults to
    `:any`.

# Returns
- `::Tuple`:
  - `::Vector{<:Integer}`: Connected target nodes.
  - `::Vector{<:Vector{<:Integer}}`: Paths to each centroid node.
"""
function search_nearby_nodes(g::OSMGraph,
                             start::Integer,
                             is_target::Function,
                             max_distance::AbstractFloat,
                             direction::Symbol=:any;
                             kwargs...
                            )::Tuple{<:AbstractVector{<:Integer},<:AbstractVector{AbstractVector{<:Integer}}}

    # Preallocate memory
    heap = BinaryHeap{Tuple{AbstractFloat,Integer}}(FastMin)  # (distance, graph index)
    dists = Dict{Integer,AbstractFloat}()  # (graph index, distance)
    parents = Dict{Integer,Integer}()      # (child, parent)
    visited = Set{Integer}()
    found = Set{Integer}()

    # Initialize start node
    dists[start] = 0.0
    parents[start] = 0
    push!(heap, (0.0, start))

    while !isempty(heap)
        # Get current node
        _, u, = pop!(heap)  # (distance, current, path length)
        (u in visited) && continue
        push!(visited, u)
        d = get(dists, u, Inf)
        
        # Check if max_distance reached
        (d > max_distance) && continue

        # Check if centroid reached
        if is_target(u, g; kwargs...) && u != start
            push!(found, u)
        end

        if direction == :any
            neighbours = Graphs.all_neighbors
        elseif direction == :forward
            neighbours = Graphs.outneighbors
        elseif direction == :backward
            neighbours = Graphs.inneighbors
        else
            @warn """
            Argument `direction` not one of `:any`, `:forward`, `:backward`.
            Defaulting to `:any`.
            """
            neighbours = Graphs.all_neighbours
        end
        # Visit each child node
        for v_idx in neighbours(g.graph, g.node_to_index[u])
            # Convert from graph index to node ID
            v = g.index_to_node[v_idx]

            (v in visited) && continue

            # TODO: Use g.weights if g.weight_type == :distance
            alt = d + distance(g.nodes[u], g.nodes[v])
            
            # Reparent if this is a shorter path
            if alt < get(dists, v, Inf)
                dists[v] = alt
                parents[v] = u
                push!(heap, (alt, v))
            end
        end
    end

    found = collect(found)
    paths = [path_from_parents(parents, goal) for goal in found]
    return found, paths
end

"""
    find_traffic_lights!(intsc::Intersection,
                         g::OSMGraph,
                         max_distance::AbstractFloat,
                         direction::Symbol=:any
                         )

Search for traffic lights in/around an intersection and populate that
    intersection's `has_light` parameter in-place.

# Arguments
- `intsc::Intersection`, Intersection to search for nearby lights.
- `g::OSMGraph`, LightOSM graph representation of the network.
- `max_distance::AbstractFloat`, Distance to search up to, in kilometres.
- `direction::Symbol=:any`, Direction to search the graph for lights, choose
    from `:forward`, `:backward`, or `:any` (default).

# Returns
- The modified `Intersection` object `intsc`.
"""
function find_traffic_lights!(intsc::Intersection,
                              g::OSMGraph,
                              max_distance::AbstractFloat,
                              direction::Symbol=:any
                              )::Intersection

    # Search from each centroid
    for c in intsc.centroid_nodes
        found, paths = search_nearby_nodes(g, c, is_node_traffic_light, max_distance, direction)
        if is_node_traffic_light(c, g) || !isempty(found)
            intsc.has_light = true
            return intsc
        end
    end

    intsc.has_light = false
    return intsc
end

"""
    complex_intersections_from_graph(edges::AbstractVector{<:AbstractVector{<:Integer}}, 
                                     num_vertices::Integer, 
                                     vertex_mapping::AbstractDict{<:Integer,<:Integer}, 
                                     centroids::NodeSetType
                                     )::Vector{NodeSetType}

Utility function for roundabout and complex intersection detection. Takes in a 
graph of connected centroids, and outputs the groups of centroids.

# Arguments
- `edges::AbstractVector{<:AbstractVector{<:Integer}`: Edges for the graph of 
  connected centroids.
- `num_vertices::Integer`: Number of centroids in the graph.
- `vertex_mapping::AbstractDict{<:Integer,<:Integer}`: Mapping of centroid 
  graph vertex indices to OSM node IDs.
- `centroids::NodeSetType`: All centroid node IDs.

# Returns 
- `::Vector{NodeSetType}`
"""
function complex_intersections_from_graph(edges::AbstractVector{<:AbstractVector{<:Integer}}, 
                                          num_vertices::Integer, 
                                          vertex_mapping::AbstractDict{<:Integer,<:Integer}, 
                                          centroids::NodeSetType
                                          )::Vector{NodeSetType}
    # Construct a Graphs.jl object representing the connected intersections
    adj_matrix = sparse(
        map(x -> x[1], edges),     # From indices
        map(x -> x[2], edges),     # To indices
        fill(1, length(edges)),    # Edge weights
        num_vertices,              # Number of rows
        num_vertices               # Number of columns
    )
    graph = Graph(adj_matrix)

    # Find all connected sub-graphs. Each is treated as as single intersection.
    conn_components = connected_components(graph)

    # Convert vertex indices to OSM node IDs
    reverse_vertex_mapping = Dict(v => k for (k, v) in vertex_mapping)
    conn_components = [[reverse_vertex_mapping[c] for c in cc if reverse_vertex_mapping[c] in centroids] for cc in conn_components]

    # Filter out intersections with only a single node
    conn_components = [Set(cc) for cc in conn_components if length(cc) > 1]
    
    return conn_components
end

"""
    add_intersection_mappings!(intsc::Intersection, 
                               centroid::Integer, 
                               incoming::IncOutDictType, 
                               outgoing::IncOutDictType; 
                               internal_nodes::Vector{<:Integer}=Int[]
                               )

Populate the `centroid_to_inc` and `centroid_to_out` fields in an `Intersection`
object. 

# Arguments
- `intsc::Intersection`: Intersection to populate.
- `centroid::Integer`: Centroid node to populate.
- `incoming::IncOutDictType`: All incoming nodes.
- `outgoing::IncOutDictType`: All outgoing nodes.
- `internal_nodes::Vector{<:Integer}=Int[]`: Internal nodes, if any.
"""
function add_intersection_mappings!(intsc::Intersection, 
                                    centroid::Integer, 
                                    incoming::IncOutDictType, 
                                    outgoing::IncOutDictType; 
                                    internal_nodes::Vector{<:Integer}=Int[]
                                    )
    # Remove centroid and internal nodes from incoming and outgoing nodes
    inc_nodes = setdiff(incoming[centroid], intsc.centroid_nodes, internal_nodes)
    out_nodes = setdiff(outgoing[centroid], intsc.centroid_nodes, internal_nodes)

    intsc.centroid_to_inc[centroid] = collect(inc_nodes)
    intsc.centroid_to_out[centroid] = collect(out_nodes)

    for inc in inc_nodes
        intsc.inc_to_centroid[inc] = centroid
    end

    for out in out_nodes
        intsc.out_to_centroid[out] = centroid
    end
end

"""
    add_intersection_attributes!(g::OSMGraph, 
                                 intsc::Intersection; 
                                 internal_nodes::Vector{Int}=Int[], 
                                 internal_ways::Vector{Int}=Int[], 
                                 )

Add attributes to an Intersection object.

# Arguments
- `g::OSMGraph`: LightOSM graph.
- `intsc::Intersection`: Intersection to modify.
- `internal_nodes::Vector{Int}=Int[]`: Internal nodes, if any.
- `internal_ways::Vector{Int}=Int[]`: Internal ways, if any.
"""
function add_intersection_attributes!(g::OSMGraph, 
                                      intsc::Intersection; 
                                      internal_nodes::Vector{Int}=Int[], 
                                      internal_ways::Vector{Int}=Int[], 
                                      )
    intsc.inc_nodes = collect(keys(intsc.inc_to_centroid))
    intsc.out_nodes = collect(keys(intsc.out_to_centroid))
    intsc.internal_nodes = internal_nodes

    intsc.inc_ways = [g.edge_to_way[[nid, intsc.inc_to_centroid[nid]]] for nid in intsc.inc_nodes]
    intsc.out_ways = [g.edge_to_way[[intsc.out_to_centroid[nid], nid]] for nid in intsc.out_nodes]
    intsc.internal_ways = internal_ways

    all_nodes = Set([intsc.centroid_nodes..., intsc.inc_nodes..., intsc.out_nodes..., intsc.internal_nodes...])
    all_ways = Set([intsc.inc_ways..., intsc.out_ways..., intsc.internal_ways...])

    intsc.uid = string(hash(all_nodes), base=16)
    intsc.intersecting_roads = Set(setdiff(["$(get(g.ways[w].tags, "name", ""))" for w in all_ways], [""]))

    # Node and way objects
    intsc.nodes = Dict([nid => g.nodes[nid] for nid in all_nodes]...)
    intsc.ways = Dict([wid => g.ways[wid] for wid in all_ways]...)

    # Headings
    inc_node_locations = [intsc.nodes[nid].location for nid in intsc.inc_nodes]
    inc_centroid_locations = [intsc.nodes[intsc.inc_to_centroid[nid]].location for nid in intsc.inc_nodes]
    out_node_locations = [intsc.nodes[nid].location for nid in intsc.out_nodes]
    out_centroid_locations = [intsc.nodes[intsc.out_to_centroid[nid]].location for nid in intsc.out_nodes]
    intsc.inc_nodes_dirs = heading(inc_node_locations, inc_centroid_locations)
    intsc.out_nodes_dirs = heading(out_centroid_locations, out_node_locations)
end

"""
    find_intersection_nodes(g::OSMGraph; 
                            int_detect_func::Function=is_intersection_simple
                            )::Tuple{<:Set{<:Integer},<:Dict{<:Integer,<:Set{<:Integer}},<:Dict{<:Integer,<:Set{<:Integer}}}

Finds all nodes on the OSM graph that could be an intersection.

# Arguments
- `::OSMGraph`: LightOSM graph.
- `int_detect_func::Function=is_intersection_simple`: Function to use for 
  checking if a node is an intersection.

# Returns
- `::Tuple`:
  - `::NodeSetType`: Intersection node IDs.
  - `::IncOutDictType`: Incoming node IDs for each intersection node.
  - `::IncOutDictType`: Outgoing node IDs for each intersection node.
"""
function find_intersection_nodes(g::OSMGraph; 
                                int_detect_func::Function=is_intersection_simple
                                )::Tuple{<:NodeSetType,<:IncOutDictType,<:IncOutDictType}
    nz_nodes = findnz(g.weights)  # OSM graph edges
    nnodes = length(g.nodes)  # Number of nodes

    # Get all incoming and outgoing nodes for every OSM node
    # Preallocate vectors to hold all incomings/outgoings, per node index
    incoming = [Set{Int}() for _ in 1:nnodes]
    outgoing = [Set{Int}() for _ in 1:nnodes]
    for (in, out, _) in zip(nz_nodes...)
        in_node = g.index_to_node[in]; 
        out_node = g.index_to_node[out];     
        push!(incoming[out], in_node)
        push!(outgoing[in], out_node)
    end

    # Filter for intersections only, and convert to OSM node IDs
    intersections = Set([g.index_to_node[n] for n in keys(incoming) if int_detect_func(incoming[n], outgoing[n])])
    incoming_dict = Dict(i => incoming[g.node_to_index[i]] for i in intersections)
    outgoing_dict = Dict(i => outgoing[g.node_to_index[i]] for i in intersections)
    return intersections, incoming_dict, outgoing_dict
end

"""
    find_cwc_intersections(g::OSMGraph, 
                           centroids::NodeSetType, 
                           incoming::IncOutDictType, 
                           outgoing::IncOutDictType
                           )::NodeSetType

Find all carriageway change intersections on the graph.

# Arguments
- `g::OSMGraph`: LightOSM graph.
- `centroids::NodeSetType`: Simple intersection centroid nodes.
- `incoming::IncOutDictType`: Incoming nodes.
- `outgoing::IncOutDictType`: Outgoing nodes.

# Returns
- ``
"""
function find_cwc_intersections(g::OSMGraph, 
                                centroids::NodeSetType, 
                                incoming::IncOutDictType, 
                                outgoing::IncOutDictType
                                )::NodeSetType
    intersections_cwc = filter(centroids) do cen
        inc = incoming[cen]
        out = outgoing[cen]
        return is_carriageway_change(g, cen, inc, out)
    end
    return intersections_cwc
end

"""
    find_roundabout_intersections(g::OSMGraph, centroids::Vector{Int}, neighbours::Vector{Vector{Int}})

Finds all centroids that lie on a roundabout and groups them together. 
Roundabouts are determined by looking at the junction:roundabout OSM tag.

# Arguments
- `g::OSMGraph`: LightOSM graph object to use.
- `centroids::NodeSetType`: Simple intersection centroid nodes.

# Returns
- `Vector{<:NodeSetType}`: Groups of centroids nodes that form roundabouts.
"""
function find_roundabout_intersections(g::OSMGraph, 
                                       centroids::NodeSetType
                                       )::Vector{<:NodeSetType}
    #=
    Build a graph of connected centroids, each vertex is a centroid.
    `vertex_mapping` maps OSM nodes to graph vertex indices.
    `edges` are the edges in this graph represented by vectors of vertex pairs.
    `next` is the number of graph vertices.
    =#
    vertex_mapping = Dict{Int,Int}(node => i for (i, node) in enumerate(centroids))
    edges = Vector{Int}[]
    next = length(vertex_mapping)

    for intsc in centroids
        # Get current intersection
        iv = vertex_mapping[intsc]

        # Roundabouts are treated differently. Connect all centroids on the 
        # same roundabout.
        if is_roundabout_node(g, intsc)
            ways = g.node_to_way[intsc]
            
            for way in ways
                # Only interested in the way(s) with the roundabout
                if !is_roundabout_way(g, way)
                    continue
                end

                # Add new edge connecting these centroids
                if haskey(vertex_mapping, way)
                    wv = vertex_mapping[way]
                else
                    next += 1
                    wv = next
                    vertex_mapping[way] = wv
                end
                push!(edges, [iv, wv])
                push!(edges, [wv, iv])
            end
        end
    end

    return complex_intersections_from_graph(edges, next, vertex_mapping, centroids)
end

"""
    find_complex_intersections(g::OSMGraph, 
                               centroids::NodeSetType, 
                               incoming::IncOutDictType, 
                               outgoing::IncOutDictType; 
                               max_distance::AbstractFloat=0.015
                               )::Vector{<:Tuple{<:NodeSetType,<:NodeSetType}}

Finds all neighbouring intersection nodes to each intersection node.

For each centroid, the graph is explored up to `max_distance` to find any 
adjacent centroids. Any groups of two or more centroids are returned, as well 
as the internal nodes between the centroids.

# Arguments
- `g::OSMGraph`: LightOSM graph object to use.
- `centroids::NodeSetType`: All simple intersection centroid nodes.
- `incoming::IncOutDictType`: Incoming nodes.
- `outgoing::IncOutDictType`: Outgoing nodes.
- `max_distance::AbstractFloat=0.015`: Maximum distance to search along the 
  road network for connected intersections.

# Returns
- `::Vector{Tuple}`: For each complex intersection cluster:
  - `::NodeSetType`: Centroid nodes in each complex intersection.
  - `::NodeSetType`: Internal nodes in each complex intersection.
"""
function find_complex_intersections(g::OSMGraph, 
                                    centroids::NodeSetType, 
                                    incoming::IncOutDictType, 
                                    outgoing::IncOutDictType; 
                                    max_distance::AbstractFloat=0.015
                                    )::Vector{<:Tuple{<:NodeSetType,<:NodeSetType}}
    #=
    Build a graph of connected centroids, each vertex is a centroid.
    `vertex_mapping` maps OSM nodes to graph vertex indices.
    `edges` are the edges in this graph represented by vectors of vertex pairs.
    `next` is the number of graph vertices.
    =#
    neighbours = [collect(Set{Int}([incoming[i]..., outgoing[i]...])) for i in centroids]
    unique_nodes = collect(Set([centroids..., [(neighbours...)...]...]))
    vertex_mapping = Dict{Int,Int}(node => i for (i, node) in enumerate(unique_nodes))
    edges = Vector{Int}[]
    next = length(vertex_mapping)

    # Keep track of internal nodes
    internal_nodes = Dict{Int,Set{Int}}(node => Set() for node in centroids)

    for centroid_id in centroids
        # Get current intersection
        iv = vertex_mapping[centroid_id]

        # Use Dijkstra's algorithm to find neighbouring centroids
        connected, paths = adjacent_intersections(g, centroid_id, centroids, max_distance)
        union!(internal_nodes[centroid_id], Set.(paths)...)

        # Connect all connected centroids
        for nid in connected
            nv = vertex_mapping[nid]
            push!(edges, [iv, nv])
            push!(edges, [nv, iv])
        end
    end

    clusters = complex_intersections_from_graph(edges, next, vertex_mapping, centroids)

    # Explicit typing here to enforce type even when no clusters where found
    return Tuple{<:NodeSetType,<:NodeSetType}[(
        c,          # 1. Centroid cluster
        setdiff(    # 2. Internal nodes
            union([internal_nodes[x] for x in c]...),
            c       # Exclude centroid nodes
        )
    ) for c in clusters]
end

"""
    create_intersections!(type::IntersectionType, 
                          intersections::Vector{Intersection}, 
                          g::OSMGraph, 
                          cent_nodes, 
                          inc_nodes::IncOutDictType, 
                          out_nodes::IncOutDictType
                          )

Creates Intersection objects and appends them to the `intersections` vector.
Different functions for each intersection type.

# Arguments
- `type::IntersectionType`: Intersection type to create.
- `intersections::Vector{Intersection}`: Vector of intersections to add to.
- `g::OSMGraph`: LightOSM graph.
- `cent_nodes`: Centroid nodes. Different format for each intersection type.
- `inc_nodes::IncOutDictType`: Incoming nodes.
- `out_nodes::IncOutDictType`: Outgoing nodes.
"""
function create_intersections!(type::Union{Type{SimpleIntersection},Type{CarriagewayChangeIntersection}}, 
                               intersections::Vector{Intersection}, 
                               g::OSMGraph, 
                               cent_nodes::NodeSetType, 
                               inc_nodes::IncOutDictType, 
                               out_nodes::IncOutDictType
                               )
    for centroid in cent_nodes
        intsc = Intersection{type}()
        intsc.centroid_nodes = [centroid]
        
        add_intersection_mappings!(intsc, centroid, inc_nodes, out_nodes)
        add_intersection_attributes!(g, intsc)
        push!(intersections, intsc)
    end
end

function create_intersections!(type::Type{ComplexIntersection}, 
                               intersections::Vector{Intersection}, 
                               g::OSMGraph, 
                               cent_nodes::Vector{<:Tuple{<:NodeSetType,<:NodeSetType}}, 
                               inc_nodes::IncOutDictType, 
                               out_nodes::IncOutDictType
                               )
    for (cluster, internal_nodes) in cent_nodes
        intsc = Intersection{type}()
        intsc.centroid_nodes = collect(cluster)
        
        internal_ways = collect(get_internal_ways(g, union(internal_nodes, cluster)))
        internal_nodes = collect(internal_nodes)
        
        for centroid in cluster
            add_intersection_mappings!(intsc, centroid, inc_nodes, out_nodes, internal_nodes=internal_nodes)
        end

        add_intersection_attributes!(g, intsc, internal_nodes=internal_nodes, internal_ways=internal_ways)
        push!(intersections, intsc)
    end
end

function create_intersections!(type::Type{RoundaboutIntersection}, 
                               intersections::Vector{Intersection}, 
                               g::OSMGraph, 
                               cent_nodes::Vector{<:NodeSetType}, 
                               inc_nodes::IncOutDictType, 
                               out_nodes::IncOutDictType
                               )
    for cluster in cent_nodes
        intsc = Intersection{type}()
        intsc.centroid_nodes = collect(cluster)

        # Get roundabout ways and nodes
        roundabout_ways = unique(flatten([g.node_to_way[n] for n in cluster]))
        roundabout_ways = [w for w in roundabout_ways if is_roundabout_way(g, w)]
        roundabout_nodes = flatten([g.ways[w].nodes for w in roundabout_ways])
        roundabout_nodes = unique(join_arrays_on_common_trailing_elements(roundabout_nodes))
        any(w -> g.ways[w].tags["reverseway"], roundabout_ways) && reverse!(roundabout_nodes)
        
        for centroid in cluster
            add_intersection_mappings!(intsc, centroid, inc_nodes, out_nodes, internal_nodes=roundabout_nodes)
        end
        
        add_intersection_attributes!(g, intsc, internal_nodes=roundabout_nodes, internal_ways=roundabout_ways)
        push!(intersections, intsc)
    end
end

"""
    get_intersections(g::OSMGraph; max_distance::Float64=0.015)

Main entry point for Blobify intersection detection. Get all intersections for 
a given LightOSM graph.

# Arguments
- `g::OSMGraph`: The LightOSM graph object to use
- `max_distance::Float64=0.015`: Distance threshold for grouping intersections
- `int_detection_func::Function=is_intersection_simulation`: Function to use 
  for detecting intersection centroid nodes. Options are:
  - `is_intersection_simple`
  - `is_intersection_simulation`
- `debug::Bool=true`: Whether to show debug output.
- `light_search_direction::Symbol=:any`: Direction to search the graph for
    nearby traffic light nodes. Choose from `:forward`, `:backward`, or
    `:any` (default).

# Returns
- `::Vector{Intersection}`: All intersections that were found.
"""
function get_intersections(g::OSMGraph; 
                           max_distance::Float64=0.02, 
                           int_detect_func::Function=is_intersection_simple,
                           debug::Bool=true,
                           light_search_direction::Symbol=:any
                           )::Vector{Intersection}
    # Temporary storage structure for intersection nodes
    cent_nodes = Dict{Type,Any}(
        SimpleIntersection => Set{Int}(),
        ComplexIntersection => Tuple{Set{Integer},Set{Integer}}[],
        RoundaboutIntersection => Set{Int}[],
        CarriagewayChangeIntersection => Set{Int}(),
    )
    inc_nodes = Dict{Int,Set{Int}}()
    out_nodes = Dict{Int,Set{Int}}()

    # 1. Find all OSM nodes that are intersections
    debug && @info "1. Detecting intersections in graph with $(length(g.nodes)) nodes..."
    cent_nodes[SimpleIntersection], inc_nodes, out_nodes = find_intersection_nodes(g, int_detect_func=int_detect_func)
    debug && @info "   Found $(length(cent_nodes[SimpleIntersection])) intersections."

    # 2. Detect carraigeway changes
    debug && @info "2. Detecting carriageway change intersections..."
    cent_nodes[CarriagewayChangeIntersection] = find_cwc_intersections(g, cent_nodes[SimpleIntersection], inc_nodes, out_nodes)
    debug && @info "   Found $(length(cent_nodes[CarriagewayChangeIntersection])) carriageway change intersections."
    setdiff!(cent_nodes[SimpleIntersection], cent_nodes[CarriagewayChangeIntersection])

    # 3 Detect roundabouts
    debug && @info "3. Detecting roundabout intersections..."
    cent_nodes[RoundaboutIntersection] = find_roundabout_intersections(g, cent_nodes[SimpleIntersection])
    debug && @info "   Found $(length(cent_nodes[RoundaboutIntersection])) roundabout intersections."
    setdiff!(cent_nodes[SimpleIntersection], cent_nodes[RoundaboutIntersection]...)

    # 4. Detect complex intersections
    debug && @info "4. Detecting complex intersections..."
    cent_nodes[ComplexIntersection] = find_complex_intersections(g, cent_nodes[SimpleIntersection], inc_nodes, out_nodes, max_distance=max_distance)
    debug && @info "   Found $(length(cent_nodes[ComplexIntersection])) complex intersections."
    setdiff!(cent_nodes[SimpleIntersection], [c for (c, _) in cent_nodes[ComplexIntersection]]...)
    
    # 5. Construct `Intersection` objects
    debug && @info "5. Constructing Intersection objects..."
    intersections = Intersection[]
    for type in (SimpleIntersection, ComplexIntersection, RoundaboutIntersection, CarriagewayChangeIntersection)
        create_intersections!(type, intersections, g, cent_nodes[type], inc_nodes, out_nodes)
    end
    debug && @info "   Found $(length(intersections)) total intersections."

    # 6. Allocate traffic lights
    debug && @info "6. Allocating traffic lights"
    for intsc in intersections
        find_traffic_lights!(intsc, g, max_distance, light_search_direction)
    end
    # Ensure lights aren't mapped to multiple intersections
    reallocate_lights!(intersections, g)

    return intersections
end

"""
    get_intersection_centre_location(inter::Intersection)

Utility to get the GeoLocatoin (lat-lon) an intersection, considering multiple 
centroid nodes. Averages out centroid locations.
"""
function get_intersection_centre_location(intsc::Intersection)::GeoLocation
    n = length(intsc.centroid_nodes)
    if n == 1
        return intsc.nodes[intsc.centroid_nodes[1]].location
    end
    lats = [intsc.nodes[nid].location.lat for nid in intsc.centroid_nodes]
    lons = [intsc.nodes[nid].location.lon for nid in intsc.centroid_nodes]
    return GeoLocation(lat=sum(lats)/n, lon=sum(lons)/n)
end
@deprecate get_intersection_centroid_location(intsc::Intersection) get_intersection_centre_location(intsc)


""" 
    match_arm_to_int_nodes(g::OSMGraph, 
                           angle::Real, 
                           intsc::Intersection, 
                           waytype=:inbound
                           )

Gets the node pairs of an interseection closest to an angle

# Arguments
- `g`: LightOSM graph.
- `angle`: Angle as determined from the centroid of the intersection, to the 
  arm, with 0 being north and ±180.
- `intsc`: Intersection struct type.
- `waytype=:inbound`: Direction :inbound or :outbound.
"""
function match_arm_to_int_nodes(g::OSMGraph, 
                                angle::Real, 
                                intsc::Intersection, 
                                waytype=:inbound
                                )
    rel_angles = Dict{Real,Vector}()
    if waytype ==:inbound
        for (n1, n2) in intsc.inc_to_centroid
            dir = LightOSM.heading(g.nodes[n2], g.nodes[n1])
            _angle = abs(get_relative_dir(angle, dir))
            rel_angles[_angle] = [n1, n2]
        end
    elseif waytype == :outbound
        for (n1, n2) in intsc.out_to_centroid  # n2 is centroid
            dir = LightOSM.heading(g.nodes[n2], g.nodes[n1])
            _angle = abs(get_relative_dir(angle, dir))
            rel_angles[_angle] = [n2, n1]
        end
    end
    min_angle = minimum(collect(keys(rel_angles)))
    return rel_angles[min_angle]
end

"""
    to_geojson(int::Intersection;
               int_id::Integer=0
               )::Dict
    to_geojson(int::Intersection,
               filename::String;
               int_id::Integer=0
               )::Nothing
    to_geojson(ints::Vector{Intersection};
               show_progress::Bool=true
               )::Dict
    to_geojson(ints::Vector{Intersection}, 
               filename::String;
               show_progress::Bool=true
               )::Nothing

Converts `Intersection` objects to GeoJSON.

# Arguments
- `int::Intersection`: Convert a single `Intersection`.
- `ints::Vector{Intersection}`: Convert multiple `Intersection`s.
- `filename::String`: Filename to use when writing to file. 
- `int_id::Integer=0`: Value to show in the `"intersection_id"` property.
- `show_progress::Bool=true`: Whether to show a progress bar.

# Returns
- `::Dict`: Generated GeoJSON features in a `FeatureCollection`.
- `::Nothing`: If writing to file.
"""
function to_geojson(int::Intersection;
                    int_id::Integer=0
                    )::Dict
    geojson_dict = Dict{String, Any}("type" => "FeatureCollection")
    geojson_dict["features"] = []
    default_properties = Dict(
        "type" => string(int.type),
        "intersection_id" => int_id,
        "UID" => int.uid,
        "intersecting_roads" => int.intersecting_roads,
        "has_light" => int.has_light
    )
    make_feature_dict(coords::Vector{<:AbstractFloat}; kwargs...) = Dict(
        "type" => "Feature", 
        "properties" => Dict(default_properties..., kwargs...),
        "geometry" => Dict("type" => "Point", "coordinates" => coords)
    )
    make_feature_dict(coords::Vector{<:Vector{<:AbstractFloat}}; kwargs...) = Dict(
        "type" => "Feature", 
        "properties" => Dict(default_properties..., kwargs...),
        "geometry" => Dict("type" => "LineString", "coordinates" => coords)
    )

    # Centroid nodes
    for (n, node) in enumerate(int.centroid_nodes)
        feature_dict = make_feature_dict(
            [int.nodes[node].location.lon, int.nodes[node].location.lat],
            node_type="centroid",
            node_index=n,
            node_osm_id=node
        )
        push!(geojson_dict["features"], feature_dict)
    end

    # Incoming nodes
    for (n, node) in enumerate(int.inc_nodes)
        feature_dict = make_feature_dict(
            [int.nodes[node].location.lon, int.nodes[node].location.lat],
            node_type="incoming",
            node_index=n,
            node_osm_id=node
        )
        push!(geojson_dict["features"], feature_dict)
    end

    # Outgoing nodes
    for (n, node) in enumerate(int.out_nodes)
        feature_dict = make_feature_dict(
            [int.nodes[node].location.lon, int.nodes[node].location.lat],
            node_type="outgoing",
            node_index=n,
            node_osm_id=node
        )
        push!(geojson_dict["features"], feature_dict)
    end

    # Internal nodes
    for (n, node) in enumerate(int.internal_nodes)
        feature_dict = make_feature_dict(
            [int.nodes[node].location.lon, int.nodes[node].location.lat],
            node_type="internal",
            node_index=n,
            node_osm_id=node
        )
        push!(geojson_dict["features"], feature_dict)
    end

    # Incoming arms
    for (inc,cen) in int.inc_to_centroid
        inc_coords = [int.nodes[inc].location.lon, int.nodes[inc].location.lat]
        cen_coords = [int.nodes[cen].location.lon, int.nodes[cen].location.lat]
        feature_dict = make_feature_dict(
            [inc_coords, cen_coords],
            node_type="incoming"
        )
        push!(geojson_dict["features"], feature_dict)
    end

    # Outgoing arms
    for (out,cen) in int.out_to_centroid
        out_coords = [int.nodes[out].location.lon, int.nodes[out].location.lat]
        cen_coords = [int.nodes[cen].location.lon, int.nodes[cen].location.lat]
        feature_dict = make_feature_dict(
            [out_coords, cen_coords],
            node_type="outgoing"
        )
        push!(geojson_dict["features"], feature_dict)
    end

    # Internal ways
    for wid in int.internal_ways
        feature_dict = make_feature_dict(
            [[int.nodes[nid].location.lon, int.nodes[nid].location.lat] for nid in int.ways[wid].nodes],
            node_type="internal"
        )
        push!(geojson_dict["features"], feature_dict)
    end

    # "Centroid" calculated by Blobify
    cl = Blobify.get_intersection_centre_location(int)
    feature_dict = make_feature_dict(
        [cl.lon, cl.lat],
        node_type="centre"
    )
    push!(geojson_dict["features"], feature_dict)

    return geojson_dict
end
function to_geojson(int::Intersection,
                    filename::String;
                    int_id::Integer=0
                    )::Nothing
    geojson_dict = to_geojson(int, int_id=int_id)
    open(filename, "w") do of
        JSON3.write(of, geojson_dict)
    end
    return
end
function to_geojson(ints::Vector{Intersection};
                    show_progress::Bool=false
                    )::Dict

    geojson_dict = Dict{String, Any}("type" => "FeatureCollection")
    geojson_dict["features"] = []

    if show_progress
        @showprogress 0.1 "Creating GeoJSON intersections..." for (j, int) in enumerate(ints)
            append!(geojson_dict["features"], to_geojson(int; int_id=j)["features"])
        end
    else
        for (j, int) in enumerate(ints)
            append!(geojson_dict["features"], to_geojson(int; int_id=j)["features"])
        end
    end

    return geojson_dict
end
function to_geojson(ints::Vector{Intersection}, 
                    filename::String;
                    show_progress::Bool=false
                    )::Nothing
    geojson_dict = to_geojson(ints, show_progress=show_progress)
    open(filename, "w") do of
        JSON3.write(of, geojson_dict)
    end
    return
end

"""
    road_int_mapping(ints::Vector{Intersection})::Dict{String, Vector{String}}

Create a `Dict` mapping road names to UIDs of all `Intersection`s involving
that road name. If a road name appears in an intersection's
`intersecting_roads` parameter, that intersection's UID is included in the list.
If `Intersection.intersecting_roads` is empty, it is added to the "UNNAMED" key.

# Arguments
- `ints`: A `Vector` of `Intersection`s to create a mapping for.

# Returns
A `Dict{String, Vector{String}}` of road names to intersection UIDs
"""
function road_int_mapping(ints::Vector{Intersection})::Dict{String, Vector{String}}

    road_int_dict = Dict{String, Vector{String}}("UNNAMED" => String[])
    for int in ints
        if !isempty(int.intersecting_roads)
            for road_name in int.intersecting_roads
                if haskey(road_int_dict, road_name)
                    push!(road_int_dict[road_name], int.uid)
                else
                    road_int_dict[road_name] = [int.uid]
                end
            end
        else
            push!(road_int_dict["UNNAMED"], int.uid)
        end
    end

    return road_int_dict
end

"""
    uid_int_mapping(ints::Vector{Intersection})::Dict{String, Intersection}

Produce a `Dict` with `Intersecion` UIDs as keys and the corresponding
`Intersection` as the value.

# Arguments
- `ints`: A `Vector` of `Intersections` to create a mapping for.

# Returns
A `Dict{String, Intersection}` mapping intersection UID to the full instance.
"""
function uid_int_mapping(ints::Vector{Intersection})::Dict{String, Intersection}

    uid_int_dict = Dict{String, Intersection}(
        [i.uid for i in ints] .=> ints
    )

    return uid_int_dict
end

"""
    light_to_int_mapping(ints::Vector{Intersection},
                         g::OSMGraph
                         )::Dict{Int64, Vector{String}}

Produce a `Dict` mapping the OSM ID of each traffic light node to the UIDs of
all `Intersection`s containing that node.

# Arguments
- `ints`: A `Vector` of Blobify `Intersection`s to create a mapping for.
- `g`: A LightOSM graph representation of the network.

# Returns
A `Dict{Int64, Vector{String}}` of node IDs to `Intersection` UIDs.
"""
function light_to_int_mapping(ints::Vector{Intersection},
                              g::OSMGraph
                              )::Dict{Int64, Vector{String}}

    light_int_dict = Dict{Int64, Vector{String}}()
    for int in ints
        if int.has_light
            # Get OSM IDs of nodes with lights
            light_nodes = filter(n -> get(g.nodes[n].tags, "highway", "") == "traffic_signals", keys(int.nodes))
            for nid in light_nodes
                # Map light node ID to intersection UID
                haskey(light_int_dict, nid) ? push!(light_int_dict[nid], int.uid) : (light_int_dict[nid] = [int.uid])
            end
        end
    end
    return light_int_dict
end

"""
    reallocate_lights!(ints::Vector{Intersection},
                       g::OSMGraph
                       )::Vector{Intersection}

Ensure traffic light nodes are only allocated to a single intersection. Where
a light is allocated to multiple intersections (e.g. a traffic light node is an
incoming/outgoing node for two sequential intersections), remove the allocation
from all but the intersection with the closest centroid node. Deallocation is
done by manually switching `has_light` to `false`, modifying the original 
`Intersection` in-place. This ensures a single traffic light node isn't 
erroneously shared between two or more intersections.

# Arguments
- `ints`: A `Vector` of Blobify `Intersection`s to modify.
- `g`: A LightOSM graph representation of the network.

# Returns
Returns the modified `ints` Vector.
"""
function reallocate_lights!(ints::Vector{Intersection},
                            g::OSMGraph{U, T, W}
                            )::Vector{Intersection} where {U <: Integer, T <: Integer, W <: Real}

    # Map UIDs to vector indices to simplify editing `ints`
    uid_index_map = Dict{String, Int64}(
        [i.uid for i in ints] .=> collect(1:length(ints))
    )
    light_int_dict = light_to_int_mapping(ints, g)

    # Find light nodes mapped to multiple intersections
    for n_id in filter(n -> length(light_int_dict[n]) > 1, keys(light_int_dict))
        # Get the nearest centroid node
        intersections = [ints[uid_index_map[u]] for u in light_int_dict[n_id]]
        all_centroids = collect(Iterators.flatten([i.centroid_nodes for i in intersections]))

        # Filter out centroids that aren't outneighbours of the lights node
        if !in(n_id, all_centroids) # light on centroid
            filter!(n -> in(g.node_to_index[n], Graphs.outneighbors(g.graph, g.node_to_index[n_id])), all_centroids)
        end
        nearest_centroid, dist = nearest_node_from_list(n_id, all_centroids, g)

        # Get Intersection containing the nearest centroid
        allocated_int = intersections[findfirst(i -> in(nearest_centroid, i.centroid_nodes), intersections)]

        # Edit `has_light` in `ints` where lights have been de-allocated
        for int in setdiff(intersections, [allocated_int])
            ints[uid_index_map[int.uid]].has_light = false
        end
    end

    return ints
end