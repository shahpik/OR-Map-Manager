"""
    MapMatch

Stores the results of a successful map match.

# Fields
- `source_id::String`: ID from data source.
- `source_geom::Vector{GeoLocation}`: Source geometry.
- `matched_nodes::Vector{<:Union{Integer, String}}`: Matched OSM nodes.
- `matched_ways::Vector{<:Union{Integer, String}}`: Ways that overlap the matched nodes.
- `matched_path::Vector{GeoLocation}`: Matched coordinates, including offset.
- `offset_start::Float64`: Offset from first node to second node, from 0 to 1.
- `offset_end::Float64`: Offset from last to second-last node, from 0 to 1.
- `meta::Dict{String,Any}`: Any metadata from the source geometry.
"""
@with_kw struct MapMatch
    source_id::String
    source_geom::Vector{GeoLocation}
    matched_nodes::Vector{<:Union{Integer, String}}
    matched_ways::Vector{<:Union{Integer, String}}
    matched_path::Vector{GeoLocation}
    offset_start::Float64
    offset_end::Float64
    meta::Dict{String,Any}
end

"""
    EdgePoint{T<:Union{Integer, String}}

A point along the edge between two OSM nodes.

# Fields
- `n1::T`: First node of edge.
- `n2::T`: Second node of edge.
- `pos::Float64`: Position from `n1` to `n2`, from 0 to 1.
"""
struct EdgePoint{T<:Union{Integer, String}}
    n1::T
    n2::T
    pos::Float64
end

"""
    HMMState

A state within `HMMGraph`. Each state is a possible point in the matched output.

# Fields
- `osm_point::EdgePoint`: Location on OSM graph.
- `source_point::GeoLocation`: Location from source linestring.
- `dist::Float64`: Straight line distance between two points.
"""
struct HMMState
    osm_point::EdgePoint
    source_point::GeoLocation
    dist::Float64
end

"""
    HMMGraph{T<:Union{Integer, String}}

Represents a hidden Markov model graph.

# Fields
- `graph::AbstractGraph`: Edges between states, with vertex id corresponding to 
  elements of `states`.
- `states::Vector{HMMState}`: All states in the graph.
- `trellis::Vector{Vector{T}}`: All states organised into a HMM "trellis". Each 
  element contains the states at every time step, where each time step 
  corresponds to a point on the input linestring.
"""
@with_kw struct HMMGraph{T<:Union{Integer, String}}
    graph::AbstractGraph = SimpleDiGraph{T}()
    states::Vector{HMMState} = []
    trellis::Vector{Vector{T}} = []
end

"""
    ModifiedWeights{U<:Integer,W<:Real,M<:AbstractMatrix{<:W}} <: AbstractMatrix{W}

Adaptor for a graph weights matrix, allowing weights and edges to be 
added to/removed from an existing weights matrix without re-allocating the 
entire matrix.

This is used for finding the shortest path between `EdgePoint`s. Weights are 
added to the `OSMGraph.weights` matrix to connect the `EdgePoint`s to the 
graph using a `ModifiedWeights` matrix.

Note that this does not fully conform to the `AbstractMatrix` interface and 
should not be used as a general matrix.

# Fields
- `weights::M`: Original weights matrix to modify.
- `nv::U`: Number of graph vertices after modifying the graph.
- `weights_add::Dict{Tuple{U,U},W}`: Weights to add. Key is the edge, value is 
  the weight of the new edge.
- `weights_rm::Set{Tuple{U,U}}`: Weights to remove, given by graph edges.
"""
struct ModifiedWeights{U<:Integer,W<:Real,M<:AbstractMatrix{<:W}} <: AbstractMatrix{W}
    weights::M
    nv::U
    weights_add::Dict{Tuple{U,U},W}
    weights_rm::Set{Tuple{U,U}}
end
Base.size(A::ModifiedWeights) = [A.nv, A.nv]
function Base.getindex(A::ModifiedWeights{U,W,M}, i::Integer, j::Integer)::W where {U, W, M}
    # Default
    idx = (i, j)
    add = idx in keys(A.weights_add)
    rm = idx in A.weights_rm
    if !add && !rm
        return getindex(A.weights, idx)
    end

    # Modification needed
    if add
        return A.weights_add[(i,j)]
    end
    return zero(W)
end

"""
    ModifiedGraph{U<:Integer,G<:AbstractGraph{<:U}} <: AbstractGraph{U}

Adaptor for a graph object, allowing vertices and edges to be added to/removed 
from an existing graph object without re-allocating the entire object.

This is used for finding the shortest path between `EdgePoint`s. Edges are 
added to the `OSMGraph.graph` object to connect the `EdgePoint`s to the 
graph using a `ModifiedGraph` object.

Note that this does not fully conform to the `AbstractGraph` interface and 
should not be used as a general graph object.

# Fields
- `graph::G`: Original graph object to modify.
- `nv::U`: Number of graph vertices after modifying the graph.
- `edges_add::Dict{U,Set{U}}`: Edges to add. Key is from node, value is to 
  nodes.
- `edges_rm::Dict{U,Set{U}}`: Edges to remove. Key is from node, value is to 
  nodes.
"""
struct ModifiedGraph{U<:Integer,G<:AbstractGraph{<:U}} <: AbstractGraph{U}
    graph::G
    nv::U
    edges_add::Dict{U,Set{U}}
    edges_rm::Dict{U,Set{U}}
end
Graphs.nv(g::ModifiedGraph) = g.nv
function Graphs.outneighbors(g::ModifiedGraph{U,G}, v::Integer)::Vector{U} where {U, G}
    v = U(v)

    # Default
    add = v in keys(g.edges_add)
    rm = v in keys(g.edges_rm)
    if !add && !rm
        return outneighbors(g.graph, v)
    end

    # Modification needed
    neigh = Set(has_vertex(g.graph, v) ? outneighbors(g.graph, v) : [])
    if add
        neigh = union(neigh, g.edges_add[v])
    end
    if rm 
        neigh = setdiff(neigh, g.edges_rm[v])
    end
    return collect(neigh)
end
