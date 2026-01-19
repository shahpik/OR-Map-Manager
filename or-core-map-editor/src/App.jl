"`App` contains all application code."
module App

using CSV
using DataFrames
using Dates
using HTTP
using URIs
using UUIDs
using JSON3
using LibPQ
using MbedTLS
using ProgressMeter
using StructTypes
using Suppressor
using YAML
using LightOSM

using AWSInterface
using EMInterface
using PSQLInterface
using SpatialUtilities

using ..AppTypes
using ..Workers

using UUIDs


# All code included in specific files
include("exceptions.jl")
include("execution.jl")
include("postgres.jl")
#include("download.jl")
#include("convert.jl")

# Imports the post-processing files
# To be filled --------------------

const SCRIPT_DIRECTORY = Ref{String}()

function init()
    initialise_db()
end

# Step Function Definitions
function step_create_changeset(layerId::Symbol)
    layerId = string(layerId)
    init()
    try 
        blocking_changeset = App.validate_changeset(layerId)
        if blocking_changeset != "EMPTY" 
            throw(MapEditorException("MapEditor - changeset creation blocked by $blocking_changeset"))
        else 
            create_changeset(layerId, userName = "Source data", e_changeset_edit_type = "SOURCE")
            @info "MapEditor - changeset successfully created"
        end
    catch err
        @error "MapEditor - creation of new changeset for $layerId failed due to " exception=(err, catch_backtrace())
    end
end

function step_check_changeset_status(layerId::Symbol)
    layerId = string(layerId)
    init()
    while get_latest_source_changeset_id_by_status(layerId, "APPROVING") === nothing
        @warn "Sleeping for 10s"
        sleep(10)
    end
end

function step_refresh_mv_feature(layerId::Symbol)
    layerId = string(layerId)
    init()
    refresh_materialized_view_feature(layerId)
end

function step_refresh_mv_feature(mv_list::Vector{Symbol})
    for mv in mv_list
        @info "Refreshing Materialized View for $mv"
        step_refresh_mv_feature(mv)
    end
end

function step_refresh_mv_relationship()
    init()
    refresh_materialized_view_relationship()
end

function step_update_source_update_changeset_status(layerId::Symbol)
    layerId = string(layerId)
    init()
    update_source_update_changeset_status(layerId, "PROCESSING", "PENDING")
end

function step_source_layer_update_publish_changeset()
    init()
    source_layer_update_publish_changeset()
end

function step_update_source_update_changeset_status_post_approval(layerId::Symbol)
    layerId = string(layerId)
    init()
    update_source_update_changeset_status(layerId, "APPROVING" ,"APPROVED")
end

end # module