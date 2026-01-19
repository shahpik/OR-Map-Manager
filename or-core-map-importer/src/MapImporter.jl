module MapImporter

using EMInterface
using Suppressor
using PSQLInterface

### Utilities
include("Logger.jl")
using .Logger

include("Workers.jl")
using .Workers

### App
include("AppTypes.jl")
using .AppTypes

include("App.jl")
using .App

include("Resource.jl")
using .Resource

include("execution.jl")

include("postgres.jl")

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
        @info "Skipping Experiment Manager initialization in job mode."
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

function run_ingestion(source::Symbol; debug::Bool=false, job_mode::Bool=false)
    Workers.init()
    App.init()
    initialise_experiment_manager(job_mode=job_mode)
    @time App.source_ingestion(source; refresh_data=true, debug=debug)
end
run_ingestion(source::String; kwargs...) = run_ingestion(Symbol(source); kwargs...)

"""
    julia_main()::Cint

This function serves as an entry point to an app created by PackageCompiler,
and should not be modified.
"""
function julia_main()::Cint
    run()
    return 0
end

#Step Function Definitions 

function step_load_new_data(source::Symbol; debug::Bool=false, job_mode::Bool=false)
    App.init()
    create_temp_tables()
    run_ingestion(source; debug=debug, job_mode=job_mode)
end

function step_load_new_data_from_source_list(source_list::Vector{Symbol}; kwargs...)
    for source in source_list
        @info "Starting Data Load for $source"
        step_load_new_data(source; kwargs...)
    end
end

function step_create_custom_osm_attributes()
    App.init()
    inherit_csf_attributes_as_dtp_attributes()
end

end # module

