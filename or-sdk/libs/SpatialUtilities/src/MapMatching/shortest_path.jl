"""
    construct_modified_graph(g::OSMGraph{U,T,W},
                             u::EdgePoint{T}, 
                             v::EdgePoint{T}
                             ) where {U, T, W}

Constructs `ModifedGraph` and `ModifiedWeights` objects suitable for finding 
the shortest path between two `EdgePoint`s.

# Arguments
- `g::OSMGraph{U,T,W}`: LightOSM graph.
- `u::EdgePoint{T}`: Start point.
- `v::EdgePoint{T}`: Goal point.

# Returns
- `::Tuple`:
  - `::ModifiedGraph`: Graph suitable for finding shortest path.
  - `::ModifiedWeights`: Weights matrix suitable for finding shortest path.
  - `::U`: Starting graph index.
  - `::V`: Goal graph index.
"""
function construct_modified_graph(g::OSMGraph{U,T,W},
                                  u::EdgePoint{T}, 
                                  v::EdgePoint{T}
                                  ) where {U, T, W}
    # Pre-allocate memory
    start_idx = nv(g.graph) + U(1)
    goal_idx = nv(g.graph) + U(2)
    edges_add = Dict{U,Set{U}}(
        g.node_to_index[u.n1] => Set{U}(),
        g.node_to_index[u.n2] => Set{U}(),
        g.node_to_index[v.n1] => Set{U}(),
        g.node_to_index[v.n2] => Set{U}(),
        start_idx => Set{U}(),
        goal_idx => Set{U}()
    )
    edges_rm = Dict{U,Set{U}}(
        g.node_to_index[u.n1] => Set{U}(),
        g.node_to_index[u.n2] => Set{U}(),
        g.node_to_index[v.n1] => Set{U}(),
        g.node_to_index[v.n2] => Set{U}()
    )
    weights_add = Dict{Tuple{U,U},W}()
    weights_rm = Set{Tuple{U,U}}()

    # Check for any EdgePoints that are actually directly on a node
    to_add = Tuple{EdgePoint{T},U}[]
    if u.pos <= zero(W)
        start_idx = g.node_to_index[u.n1]
    elseif u.pos >= one(W)
        start_idx = g.node_to_index[u.n2]
    else
        push!(to_add, (u, start_idx))
    end
    if v.pos <= zero(W)
        goal_idx = g.node_to_index[v.n1]
    elseif v.pos >= one(W)
        goal_idx = g.node_to_index[v.n2]
    else
        push!(to_add, (v, goal_idx))
    end

    # Populate the "graph"
    for (ep, ep_idx) in to_add
        # Node IDs to graph indices
        n1_idx = g.node_to_index[ep.n1]
        n2_idx = g.node_to_index[ep.n2]

        # Get edge weights for both directions
        w1 = g.weights[n1_idx, n2_idx]
        w2 = g.weights[n2_idx, n1_idx]

        # Check if the edge n1 -> n2 exists
        if w1 > zero(U)
            # Add n1 -> ep
            push!(edges_add[n1_idx], ep_idx)
            weights_add[(n1_idx, ep_idx)] = ep.pos * w1

            # Add ep -> n2
            push!(edges_add[ep_idx], n2_idx)
            weights_add[(ep_idx, n2_idx)] = (1 - ep.pos) * w1

            # Remove n1 -> n2
            push!(edges_rm[n1_idx], n2_idx)
            push!(weights_rm, (n1_idx, n2_idx))
        end
        # Check if the edge n2 -> n1 exists
        if w2 > zero(U) 
            # Add n2 -> ep
            push!(edges_add[n2_idx], ep_idx)
            weights_add[(n2_idx, ep_idx)] = (1 - ep.pos) * w2

            # Add ep -> n1
            push!(edges_add[ep_idx], n1_idx)
            weights_add[(ep_idx, n1_idx)] = ep.pos * w1

            # Remove n2 -> n1
            push!(edges_rm[n2_idx], n1_idx)
            push!(weights_rm, (n2_idx, n1_idx))
        end
    end

    mg = ModifiedGraph(
        g.graph,
        nv(g.graph) + U(2),
        edges_add,
        edges_rm
    )
    mw = ModifiedWeights(
        g.weights,
        nv(g.graph) + U(2),
        weights_add,
        weights_rm
    )
    return mg, mw, start_idx, goal_idx
end

"""
    LightOSM.shortest_path([::Type{<:PathAlgorithm}]
                           g::OSMGraph{U,T,W},
                           u::EdgePoint{T}, 
                           v::EdgePoint{T}; 
                           max_distance::W=typemax(W)
                           )::Union{Nothing,Vector{T}} where {U, T, W}

Finds the shortest path between two `EdgePoint`s.

# Arguments
- `::Type{<:PathAlgorithm}`: Kept for compatibility, algorithm is always 
  `DijkstraDict`.
- `g::OSMGraph{U,T,W}`: LightOSM graph.
- `u::EdgePoint{T}`: Start point.
- `v::EdgePoint{T}`: Goal point.
- `max_distance::W=typemax(W)`: Maximum distance to search before giving up.

# Returns
- `::Vector{T}`: Node path between `EdgePoint`s.
- `::Nothing`: If no path was found.
"""
function LightOSM.shortest_path(g::OSMGraph{U,T,W},
                                u::EdgePoint{T}, 
                                v::EdgePoint{T}; 
                                max_distance::W=typemax(W)
                                )::Union{Nothing,Vector{T}} where {U, T, W}
    # Check if u and v are on the same edge
    same_edge_forward = u.n1 == v.n1 && u.n2 == v.n2
    same_edge_reverse = u.n1 == v.n2 && u.n2 == v.n1
    if same_edge_forward || same_edge_reverse
        # Check which edge point comes first
        if (same_edge_forward && u.pos < v.pos) ||
           (same_edge_reverse && u.pos < (1-v.pos))
            return [u.n1, u.n2]
        # Make sure an edge exists in the opposite direction
        elseif g.weights[g.node_to_index[u.n2], g.node_to_index[u.n1]] > 0.0
            return [u.n2, u.n1]
        # Can't travel in opposite direction, no convenient path possible
        else
            return nothing
        end
    end

    # Find shortest path using modified graph
    modified_graph, modified_weights, start_idx, goal_idx = construct_modified_graph(g, u, v)
    path = LightOSM.dijkstra(
        DijkstraDict, 
        modified_graph, 
        modified_weights, 
        start_idx, 
        goal_idx, 
        max_distance=max_distance
    )
    isnothing(path) && return nothing

    # Convert to nodes; convert start and goal nodes to their original nodes
    if !has_vertex(g.graph, path[1])
        n1_idx = g.node_to_index[u.n1]
        n2_idx = g.node_to_index[u.n2]
        path[1] = n2_idx == path[2] ? n1_idx : n2_idx
    end
    if !has_vertex(g.graph, path[end])
        n1_idx = g.node_to_index[v.n1]
        n2_idx = g.node_to_index[v.n2]
        path[end] = n2_idx == path[end-1] ? n1_idx : n2_idx
    end
    nodes = [g.index_to_node[x] for x in path]
    return nodes
end
function LightOSM.shortest_path(::Type{<:PathAlgorithm}, 
                                g::OSMGraph{U,T,W}, 
                                u::EdgePoint{T}, 
                                v::EdgePoint{T}; 
                                max_distance::W=typemax(W)
                                )::Union{Nothing,Vector{T}} where {U, T, W}
    return LightOSM.shortest_path(g, u, v, max_distance=max_distance)
end

"""
    shortest_path_distance(g::OSMGraph{U,T,W}, 
                           u::EdgePoint{T}, 
                           v::EdgePoint{T}; 
                           max_distance::W=typemax(W)
                           )::Union{Nothing,W} where {U, T, W}

Finds the length of the shortest path between two `EdgePoint`s.

# Arguments
- `g::OSMGraph{U,T,W}`: LightOSM graph.
- `u::EdgePoint{T}`: Start point.
- `v::EdgePoint{T}`: Goal point.
- `max_distance::W=typemax(W)`: Maximum distance to search before giving up.

# Returns
- `::W`: Distance of shortest path.
- `::Nothing`: If no path was found.
"""
function shortest_path_distance(g::OSMGraph{U,T,W}, 
                                u::EdgePoint{T}, 
                                v::EdgePoint{T}; 
                                max_distance::W=typemax(W)
                                )::Union{Nothing,W} where {U, T, W}
    # Check if u and v are on the same edge
    same_edge = u.n1 == v.n1 && u.n2 == v.n2
    same_edge_flipped = u.n1 == v.n2 && u.n2 == v.n1
    weight_forward = g.weights[g.node_to_index[u.n1], g.node_to_index[u.n2]]
    weight_reverse = g.weights[g.node_to_index[u.n2], g.node_to_index[u.n1]]
    if same_edge || same_edge_flipped
        if same_edge && u.pos <= v.pos && weight_forward > 0.0
            #=
            •----------u-----v----------•
            u.n1                     u.n2
            v.n1                     v.n2
            =#
            return abs(u.pos - v.pos) * weight_forward
        elseif same_edge_flipped && u.pos <= (1-v.pos) && weight_forward > 0.0
            #=
            •----------u-----v----------•
            u.n1                     u.n2
            v.n2                     v.n1
            =#
            return abs(u.pos - (1-v.pos)) * weight_forward
        elseif same_edge && u.pos > v.pos && weight_reverse > 0.0
            #=
            •----------v-----u----------•
            u.n1                     u.n2
            v.n1                     v.n2
            =#
            return abs(u.pos - v.pos) * weight_reverse
        elseif same_edge_flipped && u.pos > (1-v.pos) && weight_reverse > 0.0
            #=
            •----------v-----u----------•
            u.n1                     u.n2
            v.n2                     v.n1
            =#
            return abs(u.pos - (1-v.pos)) * weight_reverse
        else
            # One-way edge and trying to travel in opposite direction
            return nothing
        end
    end

    modified_graph, modified_weights, start_idx, goal_idx = construct_modified_graph(g, u, v)
    path =  LightOSM.dijkstra(
        DijkstraDict, 
        modified_graph, 
        modified_weights, 
        start_idx, 
        goal_idx, 
        max_distance=max_distance
    )
    isnothing(path) && return nothing

    total_weight = zero(W)
    for (curr, next) in zip(path[1:end-1], path[2:end])
        total_weight += modified_weights[curr, next]
    end
    return total_weight
end
