module MapMatcher

using CSV
using EMInterface
using Suppressor
using PSQLInterface
using DataFrames
using JSON3
using Base.Iterators: flatten, product
using Base.Threads
using Logging
using SparseArrays

using DataStructures: Queue, enqueue!, dequeue!
using Graphs
using JSON3
using LightOSM
using Parameters
using QuickHeaps
using SpatialIndexing

export MapMatch, HMMState, HMMGraph, EdgePoint
export match_linestring, 
    match_geojson_linestrings, 
    construct_hmm_graph,
    construct_rtree,
    geoloc_to_coords,
    coords_to_geoloc,
    to_geojson


### Utilities
include("Logger.jl")
using .Logger

include("OSMFetcher.jl")
using .OSMFetcher

include("Workers.jl")
using .Workers

### App
include("AppTypes.jl")
using .AppTypes

include("App.jl")
using .App

include("Resource.jl")
using .Resource

include("postgres.jl")

include("execution.jl")

"""
    initialise_experiment_manager()

Once the application is ready, this function connects to the Experiment Manager
by performing a full instrospection of its GraphQL Schema.

# Keyword Arguments
- `job_mode::Bool=false`: If set to `true`, the function will skip connecting to the
  Experiment Manager and return immediately. Useful for job mode where initialization
  is not be necessary.

See also: [`Resource.ready`](@ref)
"""
function initialise_experiment_manager(; job_mode::Bool=false)
    # If in job_mode, end the function without executing remaining commands
    if job_mode
        @info "Skipping initialization in job mode."
        return
    end
    
    while !Resource.experiment_manager_ready()
        @debug "Waiting for Experiment Manager to be ready, retrying..."
        sleep(0.5)
    end
    @info "Initialising Experiment Manager interface with $(EXPERIMENT_MANAGER_ENDPOINT[])"
    try
        token = get(ENV, "OR_MASTER_JWT", "")
        headers = Dict()
        if haskey(ENV, "OR_SECURITY_TOKEN")
            @info "Using a security token"
            headers = Dict("x-security-check" => get(ENV, "OR_SECURITY_TOKEN", ""))
        end
        @suppress EMInterface.connect(EXPERIMENT_MANAGER_ENDPOINT[], EXPERIMENT_MANAGER_WS_ENDPOINT[], headers=headers, token=token)
        @info "Initialised Experiment Manager interface."
    catch err
        @warn "Full introspection failed, check Experiment Manager is live. \n Error:" exception = (err, catch_backtrace())
    end
end

"""
    run()

This is the entrypoint of the microservice.
"""
function run()
    Workers.init()
    App.init()
    Workers.@async initialise_experiment_manager()
    Resource.run()
end

function run_matching(sourceName::String, trigger_layer::String; original_osm=true, debug=false, job_mode=false)
    Workers.init()
    App.init()
    initialise_experiment_manager(job_mode=job_mode)
    App.map_matching(sourceName::String, trigger_layer::String; original_osm, debug)
end
# run_matching() = run_matching(Symbol(source); kwargs...)

"""
    julia_main()::Cint

This function serves as an entry point to an app created by PackageCompiler,
and should not be modified.
"""
function julia_main()::Cint
    run()
    return 0
end

# Step Function Definitions
step_run_map_matching(sourceName::Symbol, trigger_layer::Symbol; kwargs...) = run_matching(string(sourceName), string(trigger_layer); kwargs...)

function step_run_map_matching_from_source_list(source_list::Vector{Symbol}, trigger_layer::Symbol; kwargs...)
    for source in source_list
        @info "Starting Map Matching for $source"
        step_run_map_matching(source, trigger_layer; kwargs...)
    end
end

end # module

