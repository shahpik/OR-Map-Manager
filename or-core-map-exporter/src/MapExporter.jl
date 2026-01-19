module MapExporter

using EMInterface

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

include("postgres.jl")

include("execution.jl")

"""
    initialise_experiment_manager()

Once the application is ready, this function connects to the Experiment Manager
by performing a full instrospection of its GraphQL Schema.

# Keyword Arguments
- `job_mode::Bool=false`: If set to `true`, the function will skip connecting to the
  Experiment Manager and return immediately. Useful for job mode where initialization
  is not necessary.

See also: [`Resource.ready`](@ref)
"""
function initialise_experiment_manager(; job_mode::Bool=false)
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
        EMInterface.connect(EXPERIMENT_MANAGER_ENDPOINT[], EXPERIMENT_MANAGER_WS_ENDPOINT[], token=token)
        @info "Initialised Experiment Manager interface."
    catch err
        @warn "Full introspection failed, check Experiment Manager is live. \n Error:" exception=(err, catch_backtrace())
    end
end

"""
    run()

This is the entrypoint of the microservice.
"""
function run(;job_mode::Bool=false)
    Workers.init()
    Workers.@async initialise_experiment_manager(job_mode=job_mode)
    Resource.run()
end

function run_exporting(trigger_layer;job_mode::Bool=false)
    Workers.init()
    App.init()
    initialise_experiment_manager(job_mode=job_mode)
    App.map_export(trigger_layer)
end

# Step Function Definitions
step_export(trigger_layer;kwargs...) = run_exporting(trigger_layer;kwargs...)


"""
    julia_main()::Cint

This function serves as an entry point to an app created by PackageCompiler,
and should not be modified.
"""
function julia_main()::Cint
    run()
    return 0
end



end # module
