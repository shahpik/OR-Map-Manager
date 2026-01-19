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
using StructTypes
using Suppressor
using YAML
using AWSInterface
using EMInterface
using PSQLInterface
using SpatialUtilities
using Statistics
using ..AppTypes
using ..Workers

# All code included in specific files
include("exceptions.jl")
include("execution.jl")
include("postgres.jl")
include("postprocessing.jl")
include("OSMFetcher.jl")
include("OSMSplit.jl")

using .OSMFetcher
using .OSMSplit
# Define constants to prevent re-downloading for linked sources
const OSM_GRAPH = Ref{OSMGraph}()


function init()
    initialise_db()
end

function map_matching(sourceName::String, trigger_layer::String; original_osm=false, debug=false)
    changeset_count = get_changeset_count()
    graph_types = ["road", "trail"]
    try
        if sourceName == "VICMAP_TRANSPORT"
            for graph_type in graph_types
                map_matching(sourceName, graph_type, trigger_layer; original_osm, debug=false)
            end
        elseif (sourceName == "DECLARED_NETWORK" || sourceName == "CUSTOM_SEED_FILE") && !original_osm
            map_matching(sourceName, "road", trigger_layer; original_osm, debug=false)
        else
            throw(ErrorException("cannot run map matching on layer: $sourceName"))
        end
        if !original_osm && sourceName != "CUSTOM_SEED_FILE" && changeset_count == 0
            generate_match_report(sourceName)
        end
    catch err
        @error "Map Matching encountered an error\n$(typeof(err))" exception=(err, catch_backtrace())
    end
end

function get_osm_graph(graph_type::String, original_osm::Bool)
    OSM_GRAPH[] = OSMFetcher.get_osm_graph_from_db(graph_type, original_osm)
    @info "Finished downloading $graph_type"
    @info "Number of ways in current graph is: $(length(OSM_GRAPH[].ways))" 
    return OSM_GRAPH[]
end

function get_osm_graph(original_osm::Bool)
    OSM_GRAPH[] = OSMFetcher.get_osm_graph_from_db(original_osm)
    @info "Finished downloading full OSM"
    @info "Number of ways in current graph is: $(length(OSM_GRAPH[].ways))" 
    return OSM_GRAPH[]
end

#Upload to database 
function map_matching(sourceName::String, graph_type::String, trigger_layer::String; original_osm::Bool, debug=false)
    source_dict = get_source_data(sourceName, graph_type)
    @info "Retrieved $sourceName data as a dictionary\n"

    g = get_osm_graph(graph_type, original_osm)
    is_vicmap_source = sourceName == "VICMAP_TRANSPORT"

    @info "Retrieved OSM Graph...beginning map_matching\n"
    # This function call with perform the initial map matching + error calculations
    # is_vicmap_source = true will trigger dual carriageway matching + road_names will be recorded
    # for road_name post processing. 
    matched_with_error_metrics, osm_dict = match_geojson_linestrings(g, source_dict; is_vicmap_source = is_vicmap_source)
    # Post processing will either enforce distinct road_name matches if original_osm = true
    # Or will enforce 1:1 / 1:many matching if original_osm = false
    if sourceName == "DECLARED_NETWORK"
        matching_results = matched_with_error_metrics
    else 
        matching_results = post_process_matches(matched_with_error_metrics, osm_dict, original_osm)
    end
    @info "Completed matching, error calculation and postprocessing...beginning upload\n"
    results_upload(sourceName, matching_results, trigger_layer; original_osm, debug=false)
    @info "Completed upload of $sourceName map matching results"
    return nothing
end

#Save to geojson
# Note: missing params here
function map_matching_save(sourceName::String, output_file::String; debug=false)
    #OSM graph ingestion
    g = get_osm_graph()
    source_dict = get_source_data(sourceName)
    @info "Retrieved OSM graph and $sourceName data as a dictionary...beginning matching\n"
    matched_dict = match_geojson_linestrings(g, source_dict, output_progress=true, calculate_error=true)
    @info "Completed matching...beginning error calculation\n"
    # Save GeoJSON
    @info "Writing result to file $output_file..."
    open(output_file, "w") do f
        JSON3.write(f, matched_dict)
    end
end

function step_publish_match_report(trigger_layer::Symbol)
    trigger_layer = string(trigger_layer)
    init()
    # Publish match report for VMT
    publish_match_report("VICMAP_TRANSPORT", trigger_layer)
    # Publish match report for Declared Network 
    publish_match_report("DECLARED_NETWORK", trigger_layer)
end

function step_split_osm_ways(trigger_layer::Symbol)
    init()
    create_dtp_osm_layer()
    trigger_layer = string(trigger_layer)
    OSMSplit.split_osm_ways(trigger_layer)
end

function step_write_unbroken_ways_nodes_attrs(trigger_layer::Symbol)
    init()
    trigger_layer = string(trigger_layer)
    OSMSplit.write_unbroken_ways_nodes_attrs(trigger_layer)
end

function step_invalidate_DTP_OSM_feat_attrs(trigger_layer::Symbol)
    init()
    trigger_layer = string(trigger_layer)
    invalidate_DTP_OSM_features_and_attributes(trigger_layer)
end

function step_invalidate_DTP_OSM_relationships(trigger_layer::Symbol)
    init()
    trigger_layer = string(trigger_layer)
    invalidate_DTP_OSM_relationships(trigger_layer)
end

function step_invalidate_original_OSM_relationships(trigger_layer::Symbol)
    init()
    trigger_layer = string(trigger_layer)
    invalidate_original_OSM_relationships(trigger_layer)
end

end # module
