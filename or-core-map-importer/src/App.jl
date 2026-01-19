"`App` contains all application code."
module App

using CSV
using DataFrames
using Dates
using HTTP
using URIs
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

# All code included in specific files
include("exceptions.jl")
include("execution.jl")
include("config.jl")
include("postgres.jl")
include("aws.jl")
include("utilities.jl")
include("download.jl")
include("convert.jl")

# Imports the post-processing files
# To be filled --------------------

const CONFIG = Ref{Dict{Symbol, SourceConfig}}()
const SCRIPT_DIRECTORY = Ref{String}()


# Define ingestion list for full load
const INGESTION_LIST = Ref{Dict{Symbol,Bool}}()

function init()
    SCRIPT_DIRECTORY[] = joinpath(@__DIR__, "..", "scripts")
    CONFIG[] = load_source_config(;path=get(ENV, "CONFIG_FILE", "../config/config.yaml"))
    INGESTION_LIST[] = Dict(source => false for source in keys(CONFIG[]))

    initialise_aws()
    initialise_db()
end

# Step Function Definitions
function step_delta_function(layerId::Symbol)
    layerId = string(layerId)
    init()
    changeset_id = get_latest_source_changeset_id_by_status(layerId, "PROCESSING")
    if changeset_id !== nothing
        write_delta_to_db("source_delta", changeset_id)
    else
        throw(MapImporterException("Changeset not found. Delta Function cannot proceed."))
    end
end

function step_truncate_all_temp_tables()
    init()
    truncate_all_temp_tables()
end

function step_create_initial_changeset()
    init()
    create_initial_changeset()
end

function step_check_db_before_load()
    init()
    check_db_before_load()
end

function step_truncate_tables_before_initial_load()
    init()
    truncate_tables_before_initial_load()
end

function step_delete_custom_seed_file_relationships()
    init()
    delete_custom_seed_file_relationships()
end

end # module