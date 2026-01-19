module OSMFetcher
using PSQLInterface
using LibPQ
using JSON3
using LightOSM
using DataFrames

include("postgres.jl")


function init()
    initialise_db()
end

"""get_osm_road_from_db()

This function selects from the database to retrieve only 'roads' data to create an OSM Graph. 
This OSM graph will be used for map matching against VicMap road features. 
It returns a dataframe containing the data that can be used to create the OSMGraph. 
"""
function get_osm_road_from_db()
    println("Starting OSM Road import")
    osm_road = execute_psql_string("""
    with osm_trail_feature_id as (
        select distinct(feature_id) from map_manager.mm_attribute where s_name = 'highway' and s_value in ('cycleway', 'footway', 'pedestrian', 'track', 'circular','roundabout') and feature_id like 'OSM&&WAY%' and b_is_latest = true
    ), osm_road_feature_id as (
        select distinct(feature_id) from map_manager.mm_attribute where feature_id not in (select feature_id from osm_trail_feature_id) and feature_id like 'OSM&&WAY%' and b_is_latest = true
    ), osm_road_tag as (
        select mm_attribute.feature_id as osm_road_tag_feature_id, jsonb_object_agg(s_name, s_value) as tags from map_manager.mm_attribute
        inner join osm_road_feature_id on mm_attribute.feature_id = osm_road_feature_id.feature_id
        where b_is_latest = true group by mm_attribute.feature_id
    ), osm_road_way as (
        select feature_id, tags, e_feature_type, layer_id, s_name, s_source_id, ST_asGeoJSON(geom_feature) as geom_feature from map_manager.mm_feature
        inner join osm_road_tag on mm_feature.feature_id = osm_road_tag.osm_road_tag_feature_id where b_is_latest = true
    ), osm_road_node_from_attr_raw as (
        select distinct(trim(unnest(string_to_array(regexp_replace(s_value::text, '\\[|\\]', '', 'g'), ',')))) as node_id
        from map_manager.mm_attribute inner join osm_road_tag on mm_attribute.feature_id = osm_road_tag.osm_road_tag_feature_id where s_name = 'nodes' and b_is_latest = true
    ), osm_road_node_from_attr as (
        SELECT trim(both '"' from node_id) AS node_id FROM osm_road_node_from_attr_raw
    ), osm_road_point as (
        select feature_id, null::jsonb as tags, e_feature_type, layer_id, s_name, s_source_id, ST_asGeoJSON(geom_feature) as geom_feature from map_manager.mm_feature
        inner join osm_road_node_from_attr on mm_feature.feature_id = osm_road_node_from_attr.node_id where b_is_latest = true 
    )
    (select * from osm_road_way) union (select * from osm_road_point);
    """
    )

    df = DataFrames.DataFrame(LibPQ.columntable(osm_road))
    return df
end

"""get_osm_trail_from_db()

This function selects from the database to retrieve only 'trails' data to create an OSM Graph. 
This OSM graph will be used for map matching against VicMap trail features. 
It returns a dataframe containing the data that can be used to create the OSMGraph. 
"""
function get_osm_trail_from_db()
    println("Starting OSM Trail import")
    osm_trail = execute_psql_string("""
    with osm_trail_feature_id as (
        select feature_id from map_manager.mm_attribute where s_name = 'highway' and s_value in ('cycleway', 'footway', 'pedestrian', 'track') and feature_id like 'OSM&&WAY%' and b_is_latest = true
    ), osm_trail_tag as (
        select mm_attribute.feature_id as osm_trail_tag_feature_id, jsonb_object_agg(s_name, s_value) as tags from map_manager.mm_attribute
        inner join osm_trail_feature_id on mm_attribute.feature_id = osm_trail_feature_id.feature_id
        where b_is_latest = true group by mm_attribute.feature_id
    ), osm_trail_way as (
        select feature_id, tags, e_feature_type, layer_id, s_name, s_source_id, ST_asGeoJSON(geom_feature) as geom_feature from map_manager.mm_feature
        inner join osm_trail_tag on mm_feature.feature_id = osm_trail_tag.osm_trail_tag_feature_id where b_is_latest = true
    ), osm_trail_node_from_attr_raw as (
        select distinct(trim(unnest(string_to_array(regexp_replace(s_value::text, '\\[|\\]', '', 'g'), ',')))) as node_id
        from map_manager.mm_attribute inner join osm_trail_tag on mm_attribute.feature_id = osm_trail_tag.osm_trail_tag_feature_id where s_name = 'nodes' and b_is_latest = true
    ), osm_trail_node_from_attr as (
        SELECT trim(both '"' from node_id) AS node_id FROM osm_trail_node_from_attr_raw
    ), osm_trail_point as (
        select feature_id, null::jsonb as tags, e_feature_type, layer_id, s_name, s_source_id, ST_asGeoJSON(geom_feature) as geom_feature from map_manager.mm_feature
        inner join osm_trail_node_from_attr on mm_feature.feature_id = osm_trail_node_from_attr.node_id where b_is_latest = true 
    )
    (select * from osm_trail_way) union (select * from osm_trail_point);
    """
    )

    df = DataFrames.DataFrame(LibPQ.columntable(osm_trail))
    return df
end

"""get_osm_from_db_full()

This function selects from the database to retrieve all data to create an OSM Graph. 
This is currently unused - the roads/trails graphs will be used to match against VicMap Transport - and the DTP OSM Road Network graph will be used for other matching. 
It returns a dataframe containing the data that can be used to create the OSMGraph. 
"""
function get_osm_from_db_full()
    println("Starting OSM import")
    res = execute_psql_string(
    """select feat.feature_id, tags, e_feature_type, layer_id,s_name,s_source_id, ST_asGeoJSON(geom_feature) as geom_feature
    from
    (select
    feature_id,
    jsonb_object_agg(s_name, s_value) as tags
    from map_manager.mm_attribute 
    where b_is_latest = true 
    group by feature_id) as res
    right join
    map_manager.mm_feature as feat
    on feat.feature_id=res.feature_id
    where feat.feature_id like 'OSM&&%' and feat.b_is_latest = true
    ;"""
    )
    df = DataFrames.DataFrame(LibPQ.columntable(res))
    return df
end

"""get_dtp_road_from_db()

This function selects from the database to retrieve only 'roads' data to create an DTP Graph. 
This DTP graph will be used for map matching against VicMap road features. 
It returns a dataframe containing the data that can be used to create the DTP Graph. 
"""
function get_dtp_road_from_db()
    println("Starting DTP Road import")
    dtp_road = execute_psql_string("""
    with dtp_trail_feature_id as (
        select distinct(feature_id) from map_manager.mm_derived_attribute where s_name = 'highway' and s_value in ('cycleway', 'footway', 'pedestrian', 'track', 'circular','roundabout') 
        and (feature_id like 'OSM&&WAY%' OR feature_id like 'DTP&&WAY%') and b_is_latest = true
    ), dtp_road_feature_id as (
        select distinct(feature_id) from map_manager.mm_derived_attribute where feature_id not in (select feature_id from dtp_trail_feature_id) 
        and (feature_id like 'OSM&&WAY%' OR feature_id like 'DTP&&WAY%') and b_is_latest = true
    ), dtp_road_tag as (
        select mm_derived_attribute.feature_id as dtp_road_tag_feature_id, jsonb_object_agg(s_name, s_value) as tags from map_manager.mm_derived_attribute
        inner join dtp_road_feature_id on mm_derived_attribute.feature_id = dtp_road_feature_id.feature_id
        where b_is_latest = true group by mm_derived_attribute.feature_id
    ), dtp_road_way as (
        select feature_id, tags, e_feature_type, layer_id, s_name, s_source_id, ST_asGeoJSON(geom_feature) as geom_feature from map_manager.mm_derived_feature
        inner join dtp_road_tag on mm_derived_feature.feature_id = dtp_road_tag.dtp_road_tag_feature_id where b_is_latest = true
    ), dtp_road_node_from_attr_raw as (
        select distinct(trim(unnest(string_to_array(regexp_replace(s_value::text, '\\[|\\]', '', 'g'), ',')))) as node_id
        from map_manager.mm_derived_attribute inner join dtp_road_tag on mm_derived_attribute.feature_id = dtp_road_tag.dtp_road_tag_feature_id where s_name = 'nodes' and b_is_latest = true
    ), dtp_road_node_from_attr as (
        SELECT trim(both '"' from node_id) AS node_id FROM dtp_road_node_from_attr_raw
    ), dtp_road_point as (
        select feature_id, null::jsonb as tags, e_feature_type, layer_id, s_name, s_source_id, ST_asGeoJSON(geom_feature) as geom_feature from map_manager.mm_derived_feature
        inner join dtp_road_node_from_attr on mm_derived_feature.feature_id = dtp_road_node_from_attr.node_id where b_is_latest = true 
    )
    (select * from dtp_road_way) union (select * from dtp_road_point);
    """
    )

    df = DataFrames.DataFrame(LibPQ.columntable(dtp_road))
    return df
end


"""get_dtp_trail_from_db()

This function selects from the database to retrieve only 'trails' data to create an DTP Graph. 
This DTP graph will be used for map matching against VicMap trail features. 
It returns a dataframe containing the data that can be used to create the DTP Graph. 
"""
function get_dtp_trail_from_db()
    println("Starting DTP Trail import")
    dtp_trail = execute_psql_string("""
    with dtp_trail_feature_id as (
        select feature_id from map_manager.mm_derived_attribute where s_name = 'highway' and s_value in ('cycleway', 'footway', 'pedestrian', 'track')
        and (feature_id like 'OSM&&WAY%' OR feature_id like 'DTP&&WAY%') and b_is_latest = true
    ), dtp_trail_tag as (
        select mm_derived_attribute.feature_id as dtp_trail_tag_feature_id, jsonb_object_agg(s_name, s_value) as tags from map_manager.mm_derived_attribute
        inner join dtp_trail_feature_id on mm_derived_attribute.feature_id = dtp_trail_feature_id.feature_id
        where b_is_latest = true group by mm_derived_attribute.feature_id
    ), dtp_trail_way as (
        select feature_id, tags, e_feature_type, layer_id, s_name, s_source_id, ST_asGeoJSON(geom_feature) as geom_feature from map_manager.mm_derived_feature
        inner join dtp_trail_tag on mm_derived_feature.feature_id = dtp_trail_tag.dtp_trail_tag_feature_id where b_is_latest = true
    ), dtp_trail_node_from_attr_raw as (
        select distinct(trim(unnest(string_to_array(regexp_replace(s_value::text, '\\[|\\]', '', 'g'), ',')))) as node_id
        from map_manager.mm_derived_attribute inner join dtp_trail_tag on mm_derived_attribute.feature_id = dtp_trail_tag.dtp_trail_tag_feature_id where s_name = 'nodes' and b_is_latest = true
    ), dtp_trail_node_from_attr as (
        SELECT trim(both '"' from node_id) AS node_id FROM dtp_trail_node_from_attr_raw
    ), dtp_trail_point as (
        select feature_id, null::jsonb as tags, e_feature_type, layer_id, s_name, s_source_id, ST_asGeoJSON(geom_feature) as geom_feature from map_manager.mm_derived_feature
        inner join dtp_trail_node_from_attr on mm_derived_feature.feature_id = dtp_trail_node_from_attr.node_id where b_is_latest = true 
    )
    (select * from dtp_trail_way) union (select * from dtp_trail_point);
    """
    )

    df = DataFrames.DataFrame(LibPQ.columntable(dtp_trail))
    return df
end


"""get_dtp_from_db_full()

This function selects from the database to retrieve all data to create an DTP Graph. 
This DTP graph will be used for map matching against the Custom Seed File & Declared Network.
It returns a dataframe containing the data that can be used to create the DTP Graph. 
"""
function get_dtp_from_db_full()
    println("Starting DTP import")
    res = execute_psql_string(
    """select feat.feature_id, tags, e_feature_type, layer_id,s_name,s_source_id, ST_asGeoJSON(geom_feature) as geom_feature
    from
    (select
    feature_id,
    jsonb_object_agg(s_name, s_value) as tags
    from map_manager.mm_derived_attribute 
    where b_is_latest = true 
    group by feature_id) as res
    right join
    map_manager.mm_derived_feature as feat
    on feat.feature_id=res.feature_id
    where (feat.feature_id like 'OSM&&%' or feat.feature_id like 'DTP&&%') and feat.b_is_latest = true
    ;"""
    )
    df = DataFrames.DataFrame(LibPQ.columntable(res))
    return df
end



function get_osm_graph_from_db(graph_type::String, original_osm::Bool)
    if graph_type == "road" && original_osm
        df = get_osm_road_from_db()
        @info "Fetched original OSM road data from DB"
    elseif graph_type == "trail" && original_osm
        df = get_osm_trail_from_db()
        @info "Fetched original OSM trail data from DB"
    elseif graph_type == "road" && !original_osm
        df = get_dtp_road_from_db()
        @info "Fetched DTP OSM road data from DB"
    elseif graph_type == "trail" && !original_osm
        df = get_dtp_trail_from_db()
        @info "Fetched DTP OSM trail data from DB"
    end

    osm_elems = df_to_osm_elems(df)
    @info "Starting graph from $graph_type"
    osm_graph = graph_from_object(osm_elems, weight_type=:distance, filter_network_type=false,largest_connected_component = false)
    return osm_graph
end

function get_osm_graph_from_db(original_osm::Bool)
    if original_osm
        df = get_osm_from_db_full()
    elseif !original_osm
        df = get_dtp_from_db_full()
    end        
    @info "Fetched graph data from db"
    osm_elems = df_to_osm_elems(df)
    @info "Starting graph from object"
    osm_graph = graph_from_object(osm_elems, weight_type=:distance, filter_network_type=false,largest_connected_component = false)
    return osm_graph
end


function df_to_osm_elems(df)
    osm_elems = Vector()
    for row in eachrow(df)
        id = row.feature_id 
        f_type = row.e_feature_type
        geom = JSON3.read(row.geom_feature)

        tags = !ismissing(row.tags) ? JSON3.read(row.tags, Dict) : missing
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

            ret_dict = Dict([("id", id), ("type", "way"), ("tags", tags), ("nodes", nodes)])
            push!(osm_elems, ret_dict)
        end
        if f_type == "POINT"
            lon = geom["coordinates"][1]
            lat = geom["coordinates"][2]
            ret_dict = Dict([("id", id), ("type", "node"), ("lon", lon), ("lat", lat)])
            push!(osm_elems, ret_dict)
        end


    end
    return Dict([("elements", osm_elems)])
    # return osm_elems
end

end #end module