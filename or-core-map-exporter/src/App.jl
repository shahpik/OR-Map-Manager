"`App` contains all application code."
module App

using CSV
using DataFrames
using Dates
using HTTP
using JSON3
using LibPQ
using LightOSM
using MbedTLS
using TimeZones
using YAML
using AWSInterface
using PSQLInterface
using EMInterface
using ..AppTypes
using ..Workers


# All code included in specific files
include("exceptions.jl")
include("execution.jl")
include("aws.jl")
include("postgres.jl")
include("utilities.jl")

function init()
    initialise_db()
    initialise_aws()
end

#Upload to export
function map_export(trigger_layer::Symbol)
    try
        df = osm_export_view()
        @info "Retrieved OSM data with matched id's...beginning conversion\n"
        export_data = df_to_osm_json(df, trigger_layer)
        file_version = export_data["version"]
        json_string = JSON3.write(export_data)
        io_st = IOBuffer(json_string)
        @info "Completed data conversion. Writing to s3 with version $(file_version)...\n"

        # Get common file name for both save and copy
        file_name = get_exporter_file_name()
        export_osm_to_s3(io_st, file_name, Dict( "version" => file_version))
        @info "Data successfully exported to s3\n"
        copy_osm(file_name)
        @info "Data successfully copied to s3\n"
    catch ex
        throw(MapExporterException("MapExporter - error writing OSM to s3 $ex"))
    end
end

end # module