module MapMatching

using ..SpatialUtilities

using Base.Iterators: flatten, product
using Base.Threads
using Logging
using SparseArrays

using DataStructures: Queue, enqueue!, dequeue!
using Graphs
using JSON3
using LightOSM
using LinearAlgebra
using Parameters
using QuickHeaps
using SpatialIndexing
using UnicodePlots: histogram

export MapMatch, HMMState, HMMGraph, EdgePoint
export match_linestring, 
    match_geojson_linestrings, 
    construct_hmm_graph,
    construct_rtree,
    geoloc_to_coords,
    coords_to_geoloc,
    to_geojson

include("types.jl")
include("utilities.jl")
include("rtree.jl")
include("shortest_path.jl")
include("error.jl")
include("algorithm.jl")
include("geojson.jl")
include("manual_matching.jl")

end # module
