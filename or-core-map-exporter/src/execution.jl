using PSQLInterface
using LibPQ
using JSON3
using LightOSM
using DataFrames
using Dates


function osm_export_view()
    App.init()
    App.create_export_view()
    println("Importing materialised view data")
    res = execute_psql_string("select * from map_manager.mm_osm_export_mv;")

    df = DataFrames.DataFrame(LibPQ.columntable(res))
    return df
end

function df_to_osm_json(df, trigger_layer)
    uppercaseTL = uppercase(string(trigger_layer))
    osm_elems = Vector()
    for row in eachrow(df)
        id_type = split(row.feature_id, "&&")
        id = row.feature_id
        f_type = row.e_feature_type
        geom = JSON3.read(row.geom_feature)
        feature_id_input = row.feature_id_input

        tags = !ismissing(row.tags) ? JSON3.read(row.tags, Dict) : missing
        custom_attribute_tags = !ismissing(row.custom_attribute_tags) ? JSON3.read(row.custom_attribute_tags, Dict) : missing
        mapping_feature_id = !ismissing(row.mapping_feature_id) ? row.mapping_feature_id : id
        # vmt_tags = JSON3.read(row.vmt_tags)
        vmt_tags = !ismissing(row.vmt_tags) ? JSON3.read(row.vmt_tags) : missing
        if f_type == "LINE"
            
            # nodes = !ismissing(tags["nodes"]) ? JSON3.read(tags["nodes"]) : missing
            nodes = get(tags, "nodes", missing)
            if ismissing(nodes)
                @warn "No \"nodes\" attribute found for feature_id $(row.feature_id), skipping!"
                continue
            end

            try
                nodes = JSON3.read(tags["nodes"])
            catch e
                @warn ("Failed to parse \"nodes\" attribute for feature_id $(row.feature_id): $e")
                continue
            end

            ret_dict = Dict([("id", id), ("way_id", mapping_feature_id), ("type", "way"), ("manual_edit", false), ("nodes", nodes), ("source_matched_id",feature_id_input), ("tags", tags), ("custom_attribute_tags", custom_attribute_tags), ("vmt_tags", vmt_tags)])
            push!(osm_elems, ret_dict)
        end
        if f_type == "POINT"
            lon = geom["coordinates"][1]
            lat = geom["coordinates"][2]
            ret_dict = Dict([("id", id), ("type", "node"), ("manual_edit", false), ("lon", lon), ("lat", lat)])
            push!(osm_elems, ret_dict)
        end
    end

    get_changeset_version = execute_psql_string("with source_changeset_count as (
        select count(*) from map_manager.mm_changeset where e_changeset_edit_type = 'SOURCE'
    ), get_changeset_id as (
        select case when (select count from source_changeset_count) = 0 then 'INITIAL_CHANGESET'
        else (select changeset_id from map_manager.mm_changeset where e_changeset_edit_type = 'SOURCE' and e_changeset_status = 'APPROVED' and layer_id = '$uppercaseTL' order by s_layer_version desc limit 1)
        end as changeset_id
    ), get_version_no as (
        select case when (select s_layer_version from map_manager.mm_changeset where changeset_id = (select changeset_id from get_changeset_id)) is null then '1.0'
        else (select s_layer_version from map_manager.mm_changeset where changeset_id = (select changeset_id from get_changeset_id)) end as ver_no
    )
    select changeset_id, ver_no from get_changeset_id, get_version_no;")
    
    changeset_id = DataFrame(get_changeset_version)[1,1]
    ver_no = DataFrame(get_changeset_version)[1,2]

    date_of_ingestion = unix2datetime(DataFrame(execute_psql_string("""select dt_last_opened from map_manager.mm_changeset where changeset_id = '$changeset_id'"""))[1, 1])

    return Dict([("version", "dtp_osm_network-road_transport-network:" * string(ver_no)), ("changeset_id", changeset_id), ("date_of_ingestion", date_of_ingestion), ("elements", osm_elems)])
end

"""
This function exists only in the case where we would need to provide a geojson file instead of an osm json
"""
function convert_df_to_geojson(df)
    geoj = Dict("type" => "FeatureCollection", "features" => [])
    total_rows = nrow(df)
    @info "Total Layer Features: $total_rows"
    prev_progress = 0.0
    for i in 1:total_rows
        # Define the new feature properties and geometry
        tags = !ismissing(df.tags[i]) ? JSON3.read(df.tags[i], Dict) : missing
        source_matched_id = !ismissing(df.feature_id_input[i]) ? df.feature_id_input[i] : missing
        new_feature = Dict(
            "type" => "Feature",
            "geometry" => JSON3.read(df.geom_feature[i], Dict),
            "properties" => Dict{String,Any}("id" => df.s_source_id[i], "e_feature_type" => df.e_feature_type[i], 
                                                "tags" => tags, "source_matched_id" => source_matched_id, 
                                                "layer_id" => df.layer_id[i]),
            "id" => df.s_source_id[i]
        )
        # Add the new feature to the 'features' array
        push!(geoj["features"], new_feature)
        # Log Progress after every 5% change
        current_progress = i / total_rows * 100
        if abs(current_progress - prev_progress) >= 5.0
            @info "Progress: $current_progress%, Iteration Number: $i"
            prev_progress = current_progress
        end
    end
    #Returns geoj as a dictionary
    return geoj
end

function export_osm_to_s3(df::IOBuffer, file_name::String, metadata::Dict=Dict())
    App.write_osm_export_to_s3(df::IOBuffer, file_name, metadata)
    return nothing
end  

function copy_osm(file_name::String)
    App.copy_export_file(file_name)
    return nothing
end 