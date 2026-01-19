"""
    σ

Used in emission probability. 

This represents the expected [standard deviation](https://en.wikipedia.org/wiki/Standard_deviation) 
of the distance between the input linestring and the OSM graph, measured in 
metres.  A larger value of σ represents less trust in the input linestring 
point locations.

[Newson and Krumm](https://www.microsoft.com/en-us/research/publication/hidden-markov-map-matching-noise-sparseness/)
recommends a value of 4.07 metres. This was for GPS with good reception. Highly 
offset location data may require a higher value.
"""
σ = 10.0

"""
    β

Used in transition probability. 

This is the expected [scale parameter](https://en.wikipedia.org/wiki/Scale_parameter)
of the ratio between the input linestring length and the OSM graph length. 
A larger value of β represents more tolerance of non-direct routes.

[Newson and Krumm](https://www.microsoft.com/en-us/research/publication/hidden-markov-map-matching-noise-sparseness/)
appears to use a value of around 0.15. Lower frequency location data may 
require a higher value.
"""
β = 1.0

"""
    emission_prob(d::Float64)::Float64
    emission_prob(u::HMMState)
    emission_prob(hmm_g::HMMGraph, i::Integer)

Calculates the emission probability of a HMM state.

The emission probability of a HMM state is the likelihood of this state at a 
particular timestep. In our case, it is the likelihood that this linestring 
point corresponds to this point on the OSM graph. 

Equation 1 in 
[Newson and Krumm](https://www.microsoft.com/en-us/research/publication/hidden-markov-map-matching-noise-sparseness/)
fits the distance between these two points to a normal distribution to 
calculate this likelihood. We are using a modified normal distribution here 
that has a peak value of 1.0, so there is never any probability greater than 1.

# Arguments
- `d::AbstractFloat`: Distance between input linestring point and OSM graph point.
- `u::HMMState`: HMM state to find emission probability of.
- `hmm_g::HMMGraph`: HMM graph.
- `i::Integer`: State index to find emission probability of.

# Returns
- `::Float64`: Emission probability, from 0 to 1.
"""
emission_prob(d::AbstractFloat)::Float64 = exp(-0.5 * (d / σ) ^ 2)  # normal distribution
emission_prob(u::HMMState) = emission_prob(u.dist)
emission_prob(hmm_g::HMMGraph, i::Integer) = emission_prob(hmm_g.states[i])

"""
    transition_prob(g::OSMGraph, u::HMMState, v::HMMState)::Float64
    transition_prob(g::OSMGraph, hmm_g::HMMGraph, u::Integer, v::Integer)

Calculates the transition probability from one HMM state to another, assuming 
they are connected.

The transition probability between two HMM states is the likelihood that 
another state follows the current state. In our case, it is the likelihood 
that the linestring corresponds to the path between these two points on the 
OSM graph.

Equations 2 and 3 in the 
[Newson and Krumm](https://www.microsoft.com/en-us/research/publication/hidden-markov-map-matching-noise-sparseness/)
fits the difference between the linestring distance and OSM graph distance to 
an exponential distribution to calculate this likelihood. We are using a 
modified exponential distribution here that has a peak value of 1.0, so there 
is never any probability greater than 1.

# Arguments
- `g::OSMGraph`: LightOSM graph.
- `u::HMMState`: From state.
- `v::HMMState`: To state.
- `hmm_g::HMMGraph`: HMM graph.
- `u::Integer`: From state index.
- `v::Integer`: To state index.

# Returns
- `::Float64`: Transition probability, from 0 to 1.
"""
function transition_prob(g::OSMGraph, u::HMMState, v::HMMState)::Float64
    x1 = u.osm_point
    z1 = u.source_point
    x2 = v.osm_point
    z2 = v.source_point

    source_dist = distance(z1, z2, :euclidean)
    osm_dist = 0.0
    if x1 != x2
        # Allow for a small max distance if input points are the same
        max_distance = (source_dist ≈ 0) ? 0.1 : 2 * source_dist
        osm_dist = shortest_path_distance(g, x1, x2, max_distance=max_distance)
    end

    # No path found, probability is zero
    isnothing(osm_dist) && return 0.0

    # From eqn 2 and 3 in the 
    d = abs(source_dist - osm_dist) * 1000  # Convert to metres
    p = exp(-d / β)  # Exponential distribution

    return p
end
transition_prob(g::OSMGraph, hmm_g::HMMGraph, u::Integer, v::Integer) = transition_prob(g, hmm_g.states[u], hmm_g.states[v])

"""
    prob_to_cost(prob::AbstractFloat)::Int64

Convert the probability values from `emission_prob` and `transition_prob` to 
cost values, by applying a logarithm. In contrast to a probability, a larger 
cost is worse and a lower cost is better. Using costs prevents numbers from 
getting too small and also lets us use a conventional Dijkstra's algorithm.

Multiplying probabilities is equivalent to adding costs due to the log law
`a × b = log(a) + log(b)`. This is described further in the 
[Valhalla Meili docs](https://valhalla.readthedocs.io/en/stable/meili/algorithms/).

Values are rounded to 3 decimal places to limit precision. If we don't do this, 
the floating-point numbers will very quickly overflow due to lack of available 
significant figures.

# Arguments
- `prob::AbstractFloat`: Probability from 0 to 1.

# Returns
- `::Float64`: Converted to cost.
"""
prob_to_cost(prob::AbstractFloat)::Float64 = round(    # Remove excess precision
    -log(                 # Log turns our tiny probabilities into sane numbers
        min(prob, 1.0)    # Upper limit 1.0
    ),
    digits=3
)

"""
    reconstruct_path(g::OSMGraph{U,T,W}, 
                     hmm_g::HMMGraph{S}, 
                     parents::Vector{S}, 
                     end_state::S; 
                     deduplicate_path=true
                     ) where {U, T, W, S}

Reconstruct the path found through the HMM graph given a list of parents, 
starting from an end state.

# Arguments
- `g::OSMGraph{U,T,W}`: LightOSM graph.
- `hmm_g::HMMGraph`: HMM graph.
- `parents::Vector{S}`: Index is the child and value is the parent.
- `end_state::S`: End state to begin reconstruction from.
- `deduplicate_path=true`: Whether to remove duplicate consecutive nodes (and 
  other edge cases) from the resulting path. 

# Returns
- `::Tuple`:
  - `::Vector{T}`: Matched OSM node path.
  - `::S`: Start state of matched path.
  - `::S`: Goal state of matched path.
"""
function reconstruct_path(g::OSMGraph{U,T,W}, 
                          hmm_g::HMMGraph{S}, 
                          parents::Vector{S}, 
                          end_state::S
                          ) where {U, T, W, S}
    @debug "Reconstructing path"

    path = T[]
    v = end_state
    while true
        u = parents[v]

        # Reached a starting state, break
        if u <= 0
            @debug "Reached start state $v"
            break
        end
        @debug "$u → $v"

        # Get the nodes along this path section
        x1 = hmm_g.states[u].osm_point
        x2 = hmm_g.states[v].osm_point
        s_path = shortest_path(AStarDict, g, x1, x2)
        if isnothing(s_path)
            @warn "Shortest path function returned nothing for $x1 and $x2"
        end
        path_section = x1 == x2 ? [] : isnothing(s_path) ? [] : s_path

        prepend!(path, path_section)
        v = u
    end

    # Remove duplicate consecutive nodes and other edge cases
    path = deduplicate_path(path)

    return path, v, end_state
end

"""
    viterbi(g::OSMGraph, 
            hmm_g::HMMGraph{S}
            ) where {S <: Integer}

Finds the best path through the hidden Markov model graph using the 
[Viterbi algorithm](https://en.wikipedia.org/wiki/Viterbi_algorithm).

This algorithm searches the entire graph and is the most commonly-used 
algorithm for this application, but is slower than Dijkstra's algorithm.

# Arguments
- `g::OSMGraph`: LightOSM graph.
- `hmm_g::HMMGraph{S}`: HMM graph.

# Returns
- `::Tuple`:
  - `::Vector`: Matched OSM node path.
  - `::S`: Start state of matched path.
  - `::S`: Goal state of matched path.
- `::Tuple{Nothing,Nothing,Nothing}`: If no path was found.
"""
function viterbi(g::OSMGraph, 
                 hmm_g::HMMGraph{S}
                 ) where {S <: Integer}
    # Initialise data structures
    dists = fill(typemax(Float64), nv(hmm_g.graph))
    parents = zeros(S, nv(hmm_g.graph))
    frontier = Queue{S}()
    goal = nothing

    # Calculate probabilities for start states
    for i in hmm_g.trellis[1]
        enqueue!(frontier, i)
        dists[i] = prob_to_cost(emission_prob(hmm_g, i))
        parents[i] = -1
    end
    
    # Calculate probabilities for all states
    while !isempty(frontier)
        # Explore current node
        u = dequeue!(frontier)
        @debug "Expanding state $u"

        # Record the best goal state if reached
        if u in hmm_g.trellis[end]
            @debug "    Reached candidate goal state $u with dist=$(dists[u])"
            if isnothing(goal)
                @debug "    Setting new goal state to $u"
                goal = u
            elseif dists[u] > dists[goal]
                @debug "    Setting new goal state to $u"
                goal = u
            end
        end

        # Visit every child of this state
        for v in outneighbors(hmm_g.graph, u)
            # Calculate new cost of this joint
            trans_cost = prob_to_cost(transition_prob(g, hmm_g, u, v))
            emiss_cost = prob_to_cost(emission_prob(hmm_g, v))
            alt = dists[u] + trans_cost + emiss_cost
            @debug "    Visiting child state $v with trans_cost=$trans_cost, emiss_cost=$emiss_cost, dist=$(dists[v]), alt=$alt"

            # Reparent if this probability is better
            if alt > dists[v]
                @debug "    Reparenting $v to $u with new dist=$alt"
                dists[v] = alt
                parents[v] = u
            end

            # Add this to the frontier
            if !(v in frontier)
                enqueue!(frontier, v)
            end
        end
    end

    # No path found
    if isnothing(goal)
        @warn "MapMatching: Failed to find path!"
        return nothing, nothing, nothing
    end

    # Construct the path back to the parent
    return reconstruct_path(g, hmm_g, parents, goal)
end

"""
    dijkstra(g::OSMGraph,
             hmm_g::HMMGraph{S}
             ) where {S}

Finds the best path through the hidden Markov model graph using  
[Dijkstra's algorithm](https://en.wikipedia.org/wiki/Dijkstra%27s_algorithm).

This algorithm searches the lowest-cost path first, which minimises graph 
exploration for increased speed.

# Arguments
- `g::OSMGraph`: LightOSM graph.
- `hmm_g::HMMGraph{S}`: HMM graph.

# Returns
- `::Tuple`:
  - `::Vector`: Matched OSM node path.
  - `::S`: Start state of matched path.
  - `::S`: Goal state of matched path.
- `::Tuple{Nothing,Nothing,Nothing}`: If no path was found.
"""
function dijkstra(g::OSMGraph,
                  hmm_g::HMMGraph{S}
                  ) where {S}
    # Initialise data structures
    heap = BinaryHeap{Tuple{Float64, S}}(FastMin)  # (distance, state)
    dists = fill(typemax(Float64), nv(hmm_g.graph))
    parents = zeros(S, nv(hmm_g.graph))
    visited = zeros(Bool, nv(hmm_g.graph))
    goal = nothing

    # Calculate probabilities for start states
    for i in hmm_g.trellis[1]
        dists[i] = prob_to_cost(emission_prob(hmm_g, i))
        push!(heap, (dists[i], i))
        parents[i] = -1
    end

    while !isempty(heap)
        _, u = pop!(heap) # (f = g + h, current)
        visited[u] && continue
        visited[u] = true
        @debug "Expanding state $u with dist=$(dists[u])"

        # Check for goal
        if u in hmm_g.trellis[end]
            goal = u
            @debug "    Reached goal state $u with dist=$(dists[u])"
            return reconstruct_path(g, hmm_g, parents, goal)
        end

        for v in outneighbors(hmm_g.graph, u)
            visited[v] && continue

            # Calculate new probability
            trans_cost = prob_to_cost(transition_prob(g, hmm_g, u, v))
            emiss_cost = prob_to_cost(emission_prob(hmm_g, v))
            alt = dists[u] + trans_cost + emiss_cost
            @debug "    Visiting child state $v with trans_cost=$trans_cost, emiss_cost=$emiss_cost, dist=$(dists[v]), alt=$alt"
            
            if alt < dists[v]
                @debug "    Reparenting $v to $u with new dist=$alt"
                dists[v] = alt
                parents[v] = u
                push!(heap, (alt, v))
            end
        end
    end

    # If code has reached here, it has failed
    if isnothing(goal)
        @warn "MapMatching: Failed to find path!"
        return nothing, nothing, nothing
    end
end

"""
    construct_states(g::OSMGraph, 
                     ls::Vector{GeoLocation}, 
                     rtree::RTree; 
                     search_radius::AbstractFloat=0.02
                     )

Construct HMM states from the input linestring. Finds the possible states by 
searching for all ways within a rectangle around each linestring point using an 
R-tree, then finds the nearest point on these ways to get the state's position.

# Arguments
- `g::OSMGraph`: LightOSM graph.
- `ls::Vector{GeoLocation}`: Input linestring.
- `rtree::RTree`: R-tree for OSM graph ways.
- `search_radius::AbstractFloat=0.02`: How far to search around the linestring,
  in kilometres.

# Returns
- `::Tuple`:
  - `::Vector{HMMState}`: Constructed HMM states.
  - `::Vector{Vector{Int64}}`: The HMM "trellis", which organises states into 
    their respective time steps.
"""
function construct_states(g::OSMGraph, 
                          ls::Vector{GeoLocation}, 
                          rtree::RTree; 
                          search_radius::AbstractFloat=0.02
                          )
    states = HMMState[]
    trellis = Vector{Int64}[]    # Each element represents a time step

    for p in ls
        # Get nearby ways
        way_ids = nearby_ways(rtree, p, search_radius)

        # Get nearest edge for each way
        results = nearest_point_on_way.(Ref(g), Ref(p), way_ids)

        # Generate states and indices
        new_states = [HMMState(ep, p, d * 1000) for (ep, d) in results if d <= search_radius]  # convert to metres
        new_indices = collect((length(states) + 1):(length(states) + length(new_states)))
        append!(states, new_states)
        push!(trellis, new_indices)
    end

    return states, trellis
end

"""
    construct_hmm_graph(g::OSMGraph, 
                        ls::Vector{GeoLocation}, 
                        rtree::RTree; 
                        search_radius::AbstractFloat=0.02
                        )::HMMGraph

Constructs the HMM graph for the input linestring. This object represents the 
state transition graph of the hidden Markov model by encapsulating a 
`Graphs.jl` graph object.

# Arguments
- `g::OSMGraph`: LightOSM graph.
- `ls::Vector{GeoLocation}`: Input linestring.
- `rtree::RTree`: R-tree for OSM graph ways.
- `search_radius::AbstractFloat=0.02`: How far to search around the linestring,
  in kilometres.

# Returns
- `::HMMGraph`: The constructed HMM graph object.
"""
function construct_hmm_graph(g::OSMGraph, 
                             ls::Vector{GeoLocation}, 
                             rtree::RTree; 
                             search_radius::AbstractFloat=0.02
                             )::HMMGraph
    # Construct states
    states, trellis = construct_states(g, ls, rtree, search_radius=search_radius)

    # Construct graph from indices
    edges = collect(flatten([
        collect(product(i, j)) 
        for (i, j) in zip(trellis[1:end-1], trellis[2:end])
    ]))
    adjmx = spzeros(Bool, length(states), length(states))
    setindex!.(Ref(adjmx), true, getindex.(edges, 1), getindex.(edges, 2))
    graph = SimpleDiGraph{Int64}(adjmx)

    # Construct HMMGraph
    return HMMGraph(
        graph,
        states,
        trellis
    )
end

"""
    match_linestring(g::OSMGraph, 
                     ls::AbstractVector, 
                     rtree::Union{RTree, Nothing}=nothing; 
                     algorithm::Function=dijkstra,
                     search_radius::AbstractFloat=0.02, 
                     source_id::String="",
                     meta::Dict{String,Any}=Dict{String,Any}()
                     )

Matches a linestring to an OpenStreetMap road network. 

# Arguments
- `g::OSMGraph`: LightOSM graph.
- `ls::AbstractVector`: Linestring to match. Must be a `Vector` of either:
  - LightOSM `GeoLocation`s
  - lon-lats, e.g. `[144.9585, -37.8181]` or `(144.9585, -37.8181)`
- `rtree::Union{RTreeNothing}=nothing`: R-tree of all ways in `g`, generated 
  using `construct_rtree(g)`. If `nothing`, this R-tree is generated before 
  the matching commences. Highly recommended to pre-compute the R-tree if 
  performing multiple matches for speed.
- `algorithm::Function=dijkstra`: Which path finding algorithm to use, either
  `viterbi` or `dijkstra`. `dijkstra` is faster and should be used by default, 
  while `viterbi` exhaustively searches all possible paths.
- `search_radius::AbstractFloat=0.02`: How far around each linestring point to 
  search for possible matches to the OSM graph.
- `source_id::String=""`: ID from the source data. This is only used to 
  identify different `MapMatch` objects.
- `meta::Dict{String,Any}=Dict{String,Any}()`: Any metadata associated with 
  the linestring. Will be used in future for matching OSM tags such as street 
  names and road type.

# Returns
- `::MapMatch`: Matched path and associated metadata.
- `::Nothing`: If no match was found.
"""
function match_linestring(g::OSMGraph, 
                          ls::Vector{GeoLocation}, 
                          rtree::Union{RTree, Nothing}=nothing; 
                          algorithm::Function=dijkstra,
                          search_radius::AbstractFloat=0.02, 
                          source_id::String="",
                          meta::Dict{String,Any}=Dict{String,Any}()
                          )
    if g.weight_type != :distance
        throw(SpatialUtilities.SpatialUtilitiesException("OSMGraph must have weight_type=:distance for map matching"))
    end

    if length(ls) < 2
        @warn "MapMatching: Cannot match linestring with length $(length(ls)), it must have at least 2 points!"
        return nothing
    end

    if isnothing(rtree)
        @debug "Constructing R-tree..."
        rtree = construct_rtree(g)
    end

    # Remove consecutive duplicate points
    ls_dedup = deduplicate(ls)

    hmm_g = construct_hmm_graph(g, ls_dedup, rtree, search_radius=search_radius)
    nodes, start_state, goal_state = algorithm(g, hmm_g)

    # Didn't find a valid path
    if isnothing(nodes) || isempty(nodes)
        return nothing
    end
    @debug "Matched nodes: $nodes"

    # Generate MapMatch fields
    matched_ways = nodes_to_ways(g, nodes)
    offset_start = get_offset(hmm_g.states[start_state], nodes[1])
    offset_end = get_offset(hmm_g.states[goal_state], nodes[end])
    matched_path = node_to_geoloc(g, nodes)
    if length(matched_path) > 1
        matched_path[1] = interp(matched_path[1], matched_path[2], offset_start)
        matched_path[end] = interp(matched_path[end], matched_path[end-1], offset_end)
    end

    return MapMatch(
        source_id,
        ls,
        nodes,
        matched_ways,
        matched_path,
        offset_start,
        offset_end,
        meta
    )
end
function match_linestring(g::OSMGraph, 
                          ls::AbstractVector, 
                          rtree::Union{RTree, Nothing}=nothing; 
                          kwargs...
                          )
    return match_linestring(g, coords_to_geoloc(ls), rtree; kwargs...)
end
