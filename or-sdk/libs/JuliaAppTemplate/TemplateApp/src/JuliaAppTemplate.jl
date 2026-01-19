module JuliaAppTemplate

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

"""
    initialise_experiment_manager()

Once the application is ready, this function connects to the Experiment Manager
by performing a full instrospection of its GraphQL Schema.

See also: [`Resource.ready`](@ref)
"""
function initialise_experiment_manager()
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
function run()
    Workers.init()
    Workers.@async initialise_experiment_manager()
    Resource.run()
end

end # module
