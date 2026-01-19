module OSMSplit

using PSQLInterface
using LibPQ
using JSON3
using DataFrames
using SpatialUtilities
using LinearAlgebra
using CSV
using ThreadPools
using Suppressor
using ..Workers

include("postgres.jl")

"""
get_osm_with_multiple_matches()

SQL statement to retrieve OSM ways have more than one Vicmap matches.

# Returns
- `osm_features::String`: OSM feature id
- `aggregated_vmt_ids::Vector{String}`: A list of matched Vicmap ids 
- `vmt_length::Int64`: The number of matched Vicmap linstrings
"""
function get_osm_with_multiple_matches()
    get_osm_with_multiple_matches_statement = """
    with agg_vmt_matches as (
        select unnest(feature_id_matched) as osm_features, array_agg(feature_id_input) as aggregated_vmt_ids, array_length(array_agg(feature_id_input), 1) as vmt_length from map_manager.mm_relationship where
        feature_id_input like 'VICMAP%' and b_is_latest = true group by osm_features
    )
    select * from agg_vmt_matches where vmt_length >= 2;
    """
    return get_osm_with_multiple_matches_statement
end

"""
get_osm_metadata()

SQL statement to retrieve OSM name and geometry when OSM id is passed.

# Returns
- `s_name::String`: OSM name
- `geom::GeoJSON`: Geometry in JSON format
"""
function get_osm_metadata()
    get_osm_metadata_statement = """select s_name, ST_AsGeoJSON(geom_feature) as geom from map_manager.mm_feature where feature_id = \$1 and b_is_latest = true;"""
    return get_osm_metadata_statement
end

"""
get_osm_nodes()

SQL statement to retrieve OSM node ids.

# Returns
- `s_value::Vector{Int64}`: OSM node ids.
"""
function get_osm_nodes()
    get_osm_nodes_statement = """select s_value as nodes from map_manager.mm_attribute where feature_id = \$1 and s_name = \$2 and b_is_latest = true"""
    return get_osm_nodes_statement
end

"""
get_osm_attributes()

SQL statement to retrieve OSM attributes names and values except "nodes".

# Returns
- `s_name::String`: OSM attribute name.
- `s_value::String`: OSM attribute value.
"""
function get_osm_attributes()
    get_osm_attributes_statement = """
    select s_name, s_value from map_manager.mm_attribute where feature_id = \$1 and s_name != \$2 and b_is_latest = true
    """
    return get_osm_attributes_statement
end

"""
points_to_interpolate_list(points_to_interpolate_df::DataFrame)

Push start and end point of each matched linestring to a list.

# Arguments
- `points_to_interpolate_df::DataFrame`: All start and end points of matched Vimcap linestring

# Returns
- `Vector{Vector{Float64}}`: List of Vicmap matches start and end points.
"""
function points_to_interpolate_list(points_to_interpolate_df::DataFrame)
    points_to_interpolate = []

    for row in eachrow(points_to_interpolate_df)
        if JSON3.read(row["geom"])["type"] == "LineString"
            push!(points_to_interpolate, JSON3.read(row["geom"])["coordinates"][1])
            push!(points_to_interpolate, JSON3.read(row["geom"])["coordinates"][end])
        elseif JSON3.read(row["geom"])["type"] == "MultiLineString"
            for coor in JSON3.read(row["geom"])["coordinates"]
                push!(points_to_interpolate, coor[1])
                push!(points_to_interpolate, coor[end])
            end
        end
    end

    return points_to_interpolate
end

"""
get_current_changeset()

SQL statement to retrieve latest approved source update changeset id and version.

# Returns
- `current_version_start::Int64`: changeset start version
- `current_changeset_id::String`: changeset id
"""
function get_current_changeset(trigger_layer::String)
    uppercaseTL = uppercase(string(trigger_layer))
    get_current_changeset_statement = """
    with changeset_count as (
    select count(*) as changeset_count from map_manager.mm_changeset where e_changeset_edit_type = 'SOURCE'
    ), get_changeset_id as (
    select case when (select changeset_count from changeset_count) = 0 then 'INITIAL_CHANGESET'
    else (select changeset_id from map_manager.mm_changeset where e_changeset_edit_type = 'SOURCE' 
        and e_changeset_status = 'APPROVED' and layer_id = '$uppercaseTL' order by dt_last_opened desc limit 1)
    end as changeset_id
    )
    select global_version_id, changeset_id from map_manager.mm_global_version where changeset_id = (select changeset_id from get_changeset_id);
    """

    current_changeset_df = DataFrame(execute_psql_string(get_current_changeset_statement))[1, :]
    if !isempty(current_changeset_df)
        current_version_start = Int64(current_changeset_df.global_version_id)
        current_changeset_id = current_changeset_df.changeset_id
    end

    return current_version_start, current_changeset_id
end 

"""
coors_to_linestring(coors::Vector{Vector{Float64}})

Format coordinates as a Well-Known Text string to write data to DB.

# Arguments
- `coors::Vector{Vector{Float64}}`: a list of coordinates

# Returns
- `linestring::String`: Coordinates in WKT string format.
"""
function coors_to_linestring(coors::Vector{Vector{Float64}})
    linestring = "LINESTRING ("
    for (idx, coor) in enumerate(coors)
        linestring *= string(coor[1]) * " " * string(coor[2])
        if idx != length(coors)
            linestring *= ", "
        end
    end
    linestring *= ")"

    return linestring
end

"""
get_feature_id()

SQL statement to retrieve latest feature_id given parent OSM feature id and feature type, e.g. POINT, LINE
"""
function get_feature_id()
    get_feature_id_statement = """
    select feature_id from map_manager.mm_derived_feature where mapping_feature_id = \$1 and b_is_latest = true
    and e_feature_type = \$2 order by cast(s_source_id as bigint) desc limit 1
    """
    return get_feature_id_statement
end

"""
write_node_to_db()

Insert new node to DB if the distance between nearest node and interpolated node is < 10 M

Parameters will be passed when executing this query.

# Returns
SQL statement.
"""
function write_node_to_db()
    write_node_to_db_statement = """
    with get_latest_dtp_node_id as (
        select cast(s_source_id as bigint) from map_manager.mm_derived_feature where feature_id like 'DTP&&NODE%' order by cast(s_source_id as bigint) desc limit 1
    ), latest_dtp_node_id as (
        select case when (select s_source_id from get_latest_dtp_node_id) is null then 0
        else (select s_source_id from get_latest_dtp_node_id) end as node_id
    )
    insert into map_manager.mm_derived_feature (
        feature_id,
        mapping_feature_id, 
        layer_id, 
        s_name, 
        e_feature_type, 
        s_source_id, 
        geom_feature,
        global_version_id_start, 
        changeset_id
    ) 
    values (
        'DTP&&NODE' || (select node_id from latest_dtp_node_id) + 1,
        \$1,
        'DTP_OSM',
        NULL,
        'POINT',
        (select node_id from latest_dtp_node_id) + 1,
        st_geomfromtext(\$2),
        \$3,
        \$4
    )"""
    return write_node_to_db_statement
end

"""
add_node_to_db(mapping_feature_id::String,
                geom_feature::Vector{Float64}, 
                current_version_start::Int64, 
                current_changeset_id::String)

Add new node to DB. We want to inherit parent OSM feature_id, name, version, and changeset_id for new point.

# Arguments
- `mapping_feature_id::String`: Parent OSM feature id
- `geom_feature::Vector{Float64}`: The geometry of the interpolated point
- `current_version_start::Int64`: Parent OSM way version current_version_start
- `current_changeset_id::String`: Parent OSM way changeset id

# Returns
- `node_id::String`: The latest node id that was added to DB.
"""
function add_node_to_db(mapping_feature_id::String, 
                        geom_feature::Vector{Float64}, 
                        current_version_start::Int64, 
                        current_changeset_id::String)
    write_node_to_db_statement = write_node_to_db()
    geom_feature = "POINT($(geom_feature[1]) $(geom_feature[2]))"
    execute_psql_string(write_node_to_db_statement, parameters=[mapping_feature_id, geom_feature, current_version_start, current_changeset_id])

    get_node_id_statement = get_feature_id()
    node_id = DataFrame(execute_psql_string(get_node_id_statement, parameters=[mapping_feature_id, "POINT"]))[1, :].feature_id
    return node_id
end

"""
write_way_to_db()

Insert new ways to DB.

Parameters will be passed when executing this query.

# Returns
SQL statement.
"""
function write_way_to_db()
    write_way_to_db_statement = """
    with get_latest_dtp_way_id as (
        select cast(s_source_id as bigint) from map_manager.mm_derived_feature where feature_id like 'DTP&&WAY%' order by cast(s_source_id as bigint) desc limit 1
    ), latest_dtp_way_id as (
        select case when (select s_source_id from get_latest_dtp_way_id) is null then 0
        else (select s_source_id from get_latest_dtp_way_id) end as way_id
    )
    insert into map_manager.mm_derived_feature (
        feature_id,
        mapping_feature_id,
        layer_id,
        s_name, 
        e_feature_type,
        s_source_id,
        geom_feature,
        global_version_id_start,
        changeset_id
    )
    values (
        'DTP&&WAY' || (select way_id from latest_dtp_way_id) + 1,
        \$1,
        'DTP_OSM',
        \$2,
        'LINE',
        (select way_id from latest_dtp_way_id) + 1,
        st_geomfromtext(\$3),
        \$4,
        \$5
    )"""

    return write_way_to_db_statement
end 

"""
add_way_to_db(mapping_feature_id::String, 
            osm_name::String, 
            geom_feature::Vector{Vector{Float64}}, 
            current_version_start::Int64, 
            current_changeset_id::String)

Add new node to DB. We want to inherit parent OSM feature_id, name, version, and changeset_id for new point.

# Arguments
- `mapping_feature_id::String`: Parent OSM feature id
- `osm_name::Union{String, Missing}`: Parent OSM feature name
- `geom_feature::Vector{Float64}`: The geometry of the interpolated point
- `current_version_start::Int64`: Parent OSM way version current_version_start
- `current_changeset_id::String`: Parent OSM way changeset id

# Returns
- `way_id::String`: The latest node id that was added to DB.
"""
function add_way_to_db(mapping_feature_id::String, 
                        osm_name::Union{String, Missing},
                        geom_feature::Vector{Vector{Float64}}, 
                        current_version_start::Int64, 
                        current_changeset_id::String)
    write_way_to_db_statement = write_way_to_db()
    geom_feature = coors_to_linestring(geom_feature)
    execute_psql_string(write_way_to_db_statement, parameters=[mapping_feature_id, osm_name, geom_feature, current_version_start, current_changeset_id])

    get_way_id_statement = get_feature_id()
    way_id = DataFrame(execute_psql_string(get_way_id_statement, parameters=[mapping_feature_id, "LINE"]))[1, :].feature_id
    return way_id
end

"""
get_projection_direction_right(osm_geom::Vector{Vector{Float64}}, 
                                nearest_node_index::Int64, 
                                nearest_node::Vector{Float64},
                                origin_vector::Vector{Float64},
                                to_right::Bool)
Determine the direction of the projection of the origin vector onto the target vector.

# Arguments
- `osm_geom::Vector{Vector{Float64}}`: osm geometry that a list of Vicmap features matched to 
- `nearest_node_index::Int64`: the nearest node index of current point to interpolate
- `nearest_node::Vector{Float64}`: the coordinates of nearest node of current point to interpolate
- `origin_vector::Vector{Float64}`: the vector that we want to project to osm, which is the vector
    of point to interpolate to nearest node
- `to_right`: if next nearest node is to the right of nearest node

# Returns 
- `Int`
The dot product of origin vector and target vector.
"""
function get_projection_direction(
                                osm_geom::Vector{Vector{Float64}}, 
                                nearest_node_index::Int64, 
                                nearest_node::Vector{Float64},
                                origin_vector::Vector{Float64},
                                to_right::Bool)
    if to_right 
        next_nearest_node = osm_geom[nearest_node_index + 1]
    elseif !to_right
        next_nearest_node = osm_geom[nearest_node_index - 1]
    end

    target_vector = next_nearest_node - nearest_node
    projection_direction = LinearAlgebra.dot(origin_vector, target_vector)

    return projection_direction, target_vector
end

"""
calculate_interpolated_point(nearest_node::Vector{Float64},
                                    project_direction::Any,
                                    target_vector::Vector{Float64})
Calculates a list interpolated point given origin vector and target vector
# Arguments
- `nearest_node_index::Int64`: the nearest node index of current point to interpolate
- `project_direction::Any`: the scalar value, representing the result of the dot product
- `target_vector:Vector{Float64}`: the vector that origin vector project to

# Returns
- Vector{Float64}
The coordinates of interpolated point
"""
function calculate_interpolated_point(
                                nearest_node::Vector{Float64},
                                projection_direction::Any,
                                target_vector::Vector{Float64})
    interpolated_point = nearest_node + (projection_direction / LinearAlgebra.dot(target_vector, target_vector)) * target_vector
    return interpolated_point
end

function find_nearest_point(source_point::Vector{Float64}, osm_ls::Vector{Vector{Float64}})
    dist = []

    for (i, node) in enumerate(osm_ls)
        push!(dist, sqrt((source_point[1]-node[1])^2 + (source_point[2]-node[2])^2))
    end

    min_dist = findmin(dist)
    min_dist_index = min_dist[2]

    nearest_node = osm_ls[min_dist_index]
    return nearest_node, min_dist_index
end

"""
create_node(nearest_node::Vector{Float64}, 
            interpolated_point::Union{Vector{Float64}, Nothing},
            mapping_feature_id::String,
            current_version_start::Int64,
            current_changeset_id::String
            node_count::Int64,
            node_way_df::DataFrame)

Create new node if the distance between nearest node and interpolated point is > 2.5 M.

# Arguments
- `nearest_node::Vector{Float64}`: The coordinates of the nearest node
- `interpolated_point::Union{Vector{Float64}, Nothing}`: The coordinates of the interpolated point, it can be nothing
- `mapping_feature_id::String`: The parent OSM way id
- `current_version_start`: Parent OSM version start
- `current_changeset_id::String`: Parent OSM changeset id
- `node_count`: Current node count
- `node_way_df::String`: Node & Way dataframe

# Returns
Create new node in DB.
"""
function create_node(nearest_node::Vector{Float64}, 
                    interpolated_point::Union{Vector{Float64}, Nothing},
                    mapping_feature_id::String,
                    current_version_start::Int64,
                    current_changeset_id::String,
                    node_count,
                    node_way_df::DataFrame,
                    node_way_attribute_lock)
    if !isnothing(interpolated_point)
        node_distance = SpatialUtilities.lstring_distance([nearest_node, interpolated_point]) * 1000
        if node_distance >= 2.5
            updated_data = Threads.atomic_add!(node_count, 1)
            node_id = "DTP&&NODE" * string(updated_data[])
            interpolated_point = "POINT($(interpolated_point[1]) $(interpolated_point[2]))"
            lock(node_way_attribute_lock) do
                push!(node_way_df, (node_id, mapping_feature_id, "DTP_OSM", missing, "POINT", string(updated_data[]), interpolated_point, current_version_start, current_changeset_id))
            end
            return true, node_id
        else
            return false, nearest_node
        end
    else 
        return false, nothing
    end
end

"""
find_index(interpolated_point::Vector{Float64}, 
            modified_osm_geom::Vector{Vector{Float64}})

Find the index of given value in a list.

# Arguments
- `interpolated_point::Vector{Float64}`: Interpolated point coordinates
- `modified_osm_geom::Vector{Vector{Float64}}`: OSM geometry after adding interpolated points

# Returns
- `i::Int`: The index of given coordinates in updated osm geometry list.
"""
function find_index(interpolated_point::Vector{Float64}, 
                    modified_osm_geom::Vector{Vector{Float64}})
    for i in 1:length(modified_osm_geom)
        if modified_osm_geom[i] == interpolated_point
            return i
        end
    end
end

"""
write_osm_attrs_to_db()

SQL statement to write parent OSM attributes, exclude 'nodes' to mm_derived_attribute for new OSM ways.
"""
function write_osm_attrs_to_db()
    write_osm_attrs_to_db_statement = """
    with attribute_name_value as (
        select s_name, s_value from map_manager.mm_attribute where feature_id = \$1 and 
        b_is_latest = true and s_name != \$2
    )
    insert into map_manager.mm_derived_attribute (
        attribute_id,
        feature_id,
        s_name,
        s_value,
        global_version_id_start,
        changeset_id
    )
    select \$3 || '&&' || s_name,
    \$3,
    s_name,
    s_value,
    \$4,
    \$5
    from attribute_name_value
    """

    return write_osm_attrs_to_db_statement
end

"""
add_osm_attrs_to_db(osm_way_id::String, 
                    new_way_id::String, 
                    current_version_start::Int64, 
                    current_changeset_id::String)

New OSM ways inherit parent OSM attributes except 'nodes'.

# Arguments
- `osm_way_id::String`: Parent OSM way id
- `new_way_id::String`: Newly created OSM way id
- `current_version_start::Int64`: Parent OSM way version current_version_start
- `current_changeset_id::String`: Parent OSM way changeset id
"""
function add_osm_attrs_to_db(osm_way_id::String, 
                            new_way_id::String, 
                            current_version_start::Int64, 
                            current_changeset_id::String)
    write_osm_attrs_statement = write_osm_attrs_to_db()
    execute_psql_string(write_osm_attrs_statement, parameters=[osm_way_id, "nodes", new_way_id, current_version_start, current_changeset_id])
end

"""
write_attribute_node_to_db()

SQL statement to write new 'nodes' field for new OSM way.
"""
function write_attribute_node_to_db()
    write_node_to_db_statement = """
    insert into map_manager.mm_derived_attribute (
        attribute_id,
        feature_id,
        s_name, 
        s_value,
        global_version_id_start,
        changeset_id
    ) 
    values (
        \$1 || '&&' || \$2,
        \$1,
        \$2,
        \$3,
        \$4, 
        \$5
    )
    """

    return write_node_to_db_statement
end

"""
add_attribute_node_to_db(osm_way_id::String, 
                        node_value::Vector{String}, 
                        current_version_start::Int64, 
                        current_changeset_id::String)

Add 'node' attribute to derived attribute table for new OSM ways.

# Arguments
- `osm_way_id::String`: Parent OSM feature id
- `node_value::Vector{String}`: The list of nodes for new OSM way
- `current_version_start::Int64`: Parent OSM way version current_version_start
- `current_changeset_id::String`: Parent OSM way changeset id
"""
function add_attribute_node_to_db(osm_way_id::String, 
                                node_value::Vector{String}, 
                                current_version_start::Int64, 
                                current_changeset_id::String)
    write_attribute_node_statement = write_attribute_node_to_db()
    execute_psql_string(write_attribute_node_statement, parameters=[osm_way_id, "nodes", "$(node_value)", current_version_start, current_changeset_id])
end

"""
copy_unbroken_ways_and_nodes()

SQL statement to retrive unbroken OSM ways and nodes. And insert to mm_derived_feature table.

# Returns
- `copy_unbroken_ways_and_nodes_statement::String`: SQL statement.
"""
function copy_unbroken_ways_and_nodes()
    copy_unbroken_ways_and_nodes_statement = """
    with split_osm_ids as (
        select distinct mapping_feature_id from map_manager.mm_derived_feature where b_is_latest = true and changeset_id = \$1
    ), unbroken_osm_ways as (
        select feature_id, s_name, e_feature_type, s_source_id, geom_feature from map_manager.mm_feature f left join split_osm_ids s on 
        f.feature_id = s.mapping_feature_id where f.e_feature_type = 'LINE' and f.feature_id like 'OSM&&WAY%' and f.b_is_latest = true and s.mapping_feature_id is null
    ), osm_nodes as (
        select feature_id, s_name, e_feature_type, s_source_id, geom_feature from map_manager.mm_feature where e_feature_type = 'POINT' and b_is_latest = true
    ), combine_nodes_and_ways as (
        (select * from unbroken_osm_ways) union (select * from osm_nodes)
    )
    insert into map_manager.mm_derived_feature (
        feature_id,
        layer_id,
        s_name, 
        e_feature_type, 
        s_source_id,
        geom_feature,
        global_version_id_start,
        changeset_id
    )
    select 
        feature_id,
        'DTP_OSM',
        s_name, 
        e_feature_type,
        s_source_id,
        geom_feature,
        \$2,
        \$1
    from combine_nodes_and_ways;
    """
    return copy_unbroken_ways_and_nodes_statement
end

"""
write_unbroken_ways_and_nodes_to_db(current_version_start::Int64, 
                                    current_changeset_id::String)

Write unbroken OSM ways and their nodes to mm_derived_feature table give start version and changeset id.

# Arguments
- `current_version_start::Int64`: Start version for each unbroken OSM way and node
- `current_changeset_id::String`: Changeset id for each unbroken OSM way and node

# Returns
- `linestring::String`: Coordinates in WKT string format.
"""
function write_unbroken_ways_and_nodes_to_db(current_version_start::Int64, 
                                            current_changeset_id::String)

    copy_unbroken_ways_and_nodes_statement = copy_unbroken_ways_and_nodes()
    execute_psql_string(copy_unbroken_ways_and_nodes_statement, parameters=[current_changeset_id, current_version_start])
end

"""
copy_unbroken_ways_attrs()

SQL statement to retrive unbroken OSM way attributes and insert into mm_derived_attribute table.

# Returns
- `copy_unbroken_ways_attrs_statement::String`: SQL statement.
"""
function copy_unbroken_ways_attrs()
    copy_unbroken_ways_attrs_statement = """
    with split_osm_ids as (
        select distinct mapping_feature_id from map_manager.mm_derived_feature where b_is_latest = true and changeset_id = \$1
    ), unbroken_osm_ways as (
        select feature_id from map_manager.mm_feature f left join split_osm_ids s on 
        f.feature_id = s.mapping_feature_id where f.b_is_latest = true and s.mapping_feature_id is null 
        and f.feature_id like 'OSM&&WAY%'
    ), attributes_to_copy as (
        select attribute_id, mm_attribute.feature_id, s_name, s_value from map_manager.mm_attribute join unbroken_osm_ways 
        on mm_attribute.feature_id = unbroken_osm_ways.feature_id and b_is_latest = true
    )
    insert into map_manager.mm_derived_attribute (
        attribute_id,
        feature_id,
        s_name,
        s_value,
        global_version_id_start,
        changeset_id
    )
    select 
        attribute_id,
        feature_id,
        s_name,
        s_value,
        \$2,
        \$1
    from attributes_to_copy;
    """
    return copy_unbroken_ways_attrs_statement
end

"""
write_unbroken_ways_attrs(current_version_start::Int64, 
                        current_changeset_id::String)

Write unbroken OSM ways attributes to mm_derived_attribute table.

# Arguments
- `current_version_start::Int64`: Start version for each unbroken OSM way and node
- `current_changeset_id::String`: Changeset id for each unbroken OSM way and node
"""
function write_unbroken_ways_attrs(current_version_start::Int64, current_changeset_id::String)
    copy_unbroken_ways_attrs_statement = copy_unbroken_ways_attrs()
    execute_psql_string(copy_unbroken_ways_attrs_statement, parameters=[current_changeset_id, current_version_start])
end

"""
write_unbroken_ways_nodes_attrs(trigger_layer::String)

Writing unbroken ways and their node, attributes to derived feature and attribute table.
"""
function write_unbroken_ways_nodes_attrs(trigger_layer::String)
    current_version_start, current_changeset_id = get_current_changeset(trigger_layer)
    write_unbroken_ways_and_nodes_to_db(current_version_start, current_changeset_id)
    write_unbroken_ways_attrs(current_version_start, current_changeset_id)
end

"""
create_first_way(combined_nodes::Vector{Vector{Float64}}, 
            osm_nodes::Vector{String}, 
            osm_geom::Vector{Vector{Float64}}, 
            mapping_feature_id::String, 
            osm_name::Union{String, Missing},
            current_version_start::Int64, 
            current_changeset_id::String,
            way_count::Int64,
            osm_attrs_df::DataFrame,
            node_way_df::DataFrame,
            attribute_df::DataFrame)

Create first OSM way using indices of osm geometry.
Find indices of combined nodes in OSM geometry and sort these indices so we get sorted_indices. The coordinate 
of the first OSM way is osm_geom[1:sorted_indices[1]]

# Arguments
- `combined_nodes::Vector{Vector{Float64}}`: A list of created interpolated points and original OSM nodes,
    we will use original OSM nodes to split OSM way if the distance between nearest node and interpolated 
    point is less than a threshold.
- `osm_nodes::Vector{String}`: Origial OSM nodes
- `osm_geom::Vector{Vector{Float64}}`: Origial OSM geometry
- `mapping_feature_id::String`: Parent OSM way id
- `osm_name::Union{String, Missing}`: Parent OSM name, can be NULL in some cases
- `current_version_start::Int64`: Parent OSM way version current_version_start
- `current_changeset_id::String`: Parent OSM way changeset id
- `way_count`: Current way count
- `osm_attrs_df::DataFrame`: OSM atribute dataframe 
- `node_way_df::DataFrame`: Node & Way dataframe
- `attribute_df::DataFrame`: Attribute dataframe

"""
function create_first_way(sorted_indices::Vector{Int64},
    osm_nodes::Vector{String},
    osm_geom::Vector{Vector{Float64}},
    mapping_feature_id::String,
    osm_name::Union{String, Missing},
    current_version_start::Int64, 
    current_changeset_id::String,
    way_count,
    osm_attrs_df::DataFrame,
    node_way_df::DataFrame,
    attribute_df::DataFrame,
    node_way_attribute_lock
    )
    # Find the geometry of first child OSM way
    first_way_geom = coors_to_linestring(osm_geom[1:sorted_indices[1]])

    way_count_id = Threads.atomic_add!(way_count, 1)
    first_way_id = "DTP&&WAY" * string(way_count_id[])
    lock(node_way_attribute_lock) do
        push!(node_way_df, (first_way_id, mapping_feature_id, "DTP_OSM", osm_name, "LINE", string(way_count_id[]), first_way_geom, current_version_start, current_changeset_id))
    end

    for attr in eachrow(osm_attrs_df)
        lock(node_way_attribute_lock) do
            push!(attribute_df, (first_way_id * "&&" * attr.s_name, first_way_id, attr.s_name, attr.s_value, current_version_start, current_changeset_id))
        end
    end

    first_way_node_ids = osm_nodes[1:sorted_indices[1]]
    lock(node_way_attribute_lock) do
        push!(attribute_df, (first_way_id * "&&" * "nodes", first_way_id, "nodes", string(first_way_node_ids), current_version_start, current_changeset_id))
    end
end

"""
create_middle_ways(combined_nodes::Vector{Vector{Float64}}, 
            osm_nodes::Vector{String}, 
            osm_geom::Vector{Vector{Float64}}, 
            mapping_feature_id::String, 
            osm_name::Union{String, Missing},
            current_version_start::Int64, 
            current_changeset_id::String,
            way_count,
            osm_attrs_df::DataFrame,
            node_way_df::DataFrame,
            attribute_df::DataFrame)

Create middle OSM ways using indices of OSM geometry.
We will get Middle OSM way geometry: osm_geom[1:sorted_indices[1]], osm_geom[sorted_indices[1], sorted_indices[2]]...

# Arguments
- `combined_nodes::Vector{Vector{Float64}}`: A list of created interpolated points and original OSM nodes,
    we will use original OSM nodes to split OSM way if the distance between nearest node and interpolated 
    point is less than a threshold.
- `osm_nodes::Vector{String}`: Origial OSM nodes
- `osm_geom::Vector{Vector{Float64}}`: Origial OSM geometry
- `mapping_feature_id::String`: Parent OSM way id
- `osm_name::Union{String, Missing}`: Parent OSM name, can be NULL in some cases
- `current_version_start::Int64`: Parent OSM way version current_version_start
- `current_changeset_id::String`: Parent OSM way changeset id
- `way_count`: Current way count
- `osm_attrs_df::DataFrame`: OSM atribute dataframe 
- `node_way_df::DataFrame`: Node & Way dataframe
- `attribute_df::DataFrame`: Attribute dataframe
"""
function create_middle_ways(sorted_indices::Vector{Int64},
    osm_nodes::Vector{String},
    osm_geom::Vector{Vector{Float64}},
    mapping_feature_id::String,
    osm_name::Union{String, Missing},
    current_version_start::Int64, 
    current_changeset_id::String,
    way_count,
    osm_attrs_df::DataFrame,
    node_way_df::DataFrame,
    attribute_df::DataFrame,
    node_way_attribute_lock)
    # Find the geometry of middle children OSM ways by using the index of all interploated points in OSM geometry
    for i in 1:(length(sorted_indices) - 1)
        middle_way_geom = coors_to_linestring(osm_geom[sorted_indices[i]:sorted_indices[i+1]])

        way_count_id = Threads.atomic_add!(way_count, 1)
        middle_way_id = "DTP&&WAY" * string(way_count_id[])
        lock(node_way_attribute_lock) do
            push!(node_way_df, (middle_way_id, mapping_feature_id, "DTP_OSM", osm_name, "LINE", string(way_count_id[]), middle_way_geom, current_version_start, current_changeset_id))
        end

        for attr in eachrow(osm_attrs_df)
            lock(node_way_attribute_lock) do
                push!(attribute_df, (middle_way_id * "&&" * attr.s_name, middle_way_id, attr.s_name, attr.s_value, current_version_start, current_changeset_id))
            end
        end

        middle_way_node_ids = osm_nodes[sorted_indices[i]:sorted_indices[i+1]]
        lock(node_way_attribute_lock) do
            push!(attribute_df, (middle_way_id * "&&" * "nodes", middle_way_id, "nodes", string(middle_way_node_ids), current_version_start, current_changeset_id))
        end
    end 
end

"""
create_last_way(combined_nodes::Vector{Vector{Float64}}, 
            osm_nodes::Vector{String}, 
            osm_geom::Vector{Vector{Float64}}, 
            mapping_feature_id::String, 
            osm_name::Union{String, Missing},
            current_version_start::Int64, 
            current_changeset_id::String,
            way_count,
            osm_attrs_df::DataFrame,
            node_way_df::DataFrame,
            attribute_df::DataFrame)

Create last OSM ways using indices of OSM geometry.
We will get last OSM way geometry: osm_geom[sorted_indices[end], length(osm_geom)]

# Arguments
- `combined_nodes::Vector{Vector{Float64}}`: A list of created interpolated points and original OSM nodes,
    we will use original OSM nodes to split OSM way if the distance between nearest node and interpolated 
    point is less than a threshold.
- `osm_nodes::Vector{String}`: Origial OSM nodes
- `osm_geom::Vector{Vector{Float64}}`: Origial OSM geometry
- `mapping_feature_id::String`: Parent OSM way id
- `osm_name::Union{String, Missing}`: Parent OSM name, can be NULL in some cases
- `current_version_start::Int64`: Parent OSM way version current_version_start
- `current_changeset_id::String`: Parent OSM way changeset id
- `current_changeset_id::String`: Parent OSM way changeset id
- `way_count`: Current way count
- `osm_attrs_df::DataFrame`: OSM atribute dataframe 
- `node_way_df::DataFrame`: Node & Way dataframe
- `attribute_df::DataFrame`: Attribute dataframe
"""
function create_last_way(sorted_indices::Vector{Int64},
    osm_nodes::Vector{String},
    osm_geom::Vector{Vector{Float64}},
    mapping_feature_id::String,
    osm_name::Union{String, Missing},
    current_version_start::Int64, 
    current_changeset_id::String,
    way_count,
    osm_attrs_df::DataFrame,
    node_way_df::DataFrame,
    attribute_df::DataFrame,
    node_way_attribute_lock
    )
    # Find the geometry of last child OSM way
    last_way_geom = coors_to_linestring(osm_geom[sorted_indices[end]:length(osm_geom)])

    way_count_id = Threads.atomic_add!(way_count, 1)
    last_way_id = "DTP&&WAY" * string(way_count_id[])
    lock(node_way_attribute_lock) do
        push!(node_way_df, (last_way_id, mapping_feature_id, "DTP_OSM", osm_name, "LINE", string(way_count_id[]), last_way_geom, current_version_start, current_changeset_id))
    end

    for attr in eachrow(osm_attrs_df)
        lock(node_way_attribute_lock) do
            push!(attribute_df, (last_way_id * "&&" * attr.s_name, last_way_id, attr.s_name, attr.s_value, current_version_start, current_changeset_id))
        end
    end

    last_way_node_ids = osm_nodes[sorted_indices[end]:length(osm_geom)]
    lock(node_way_attribute_lock) do
        push!(attribute_df, (last_way_id * "&&" * "nodes", last_way_id, "nodes", string(last_way_node_ids), current_version_start, current_changeset_id))
    end
end 

"""
create_ways(interpolated_points::Vector{Vector{Float64}}, 
            osm_nodes::Vector{String}, 
            osm_geom::Vector{Vector{Float64}}, 
            mapping_feature_id::String, 
            osm_name::String, 
            current_version_start::Int64, 
            current_changeset_id::String,
            way_count,
            osm_attrs_df::DataFrame,
            node_way_df::DataFrame,
            attribute_df::DataFrame)

Split long OSM ways into multiple smaller ways using created interpolated points.

# Arguments
- `interpolated_points::Vector{Vector{Float64}}`: A list of interpolated points
- `osm_nodes::Vector{String}`: Origial OSM nodes
- `osm_geom::Vector{Vector{Float64}}`: Origial OSM geometry
- `mapping_feature_id::String`: Parent OSM way id
- `osm_name::Union{String, Missing}`: Parent OSM name, can be NULL in some cases
- `current_version_start::Int64`: Parent OSM way version current_version_start
- `current_changeset_id::String`: Parent OSM way changeset id
- `current_changeset_id::String`: Parent OSM way changeset id
- `way_count`: Current way count
- `osm_attrs_df::DataFrame`: OSM atribute dataframe 
- `node_way_df::DataFrame`: Node & Way dataframe
- `attribute_df::DataFrame`: Attribute dataframe

# Returns
- `node_id::String`: The latest node id that was added to DB.
"""
function create_ways(combined_nodes::Vector{Vector{Float64}}, 
                    osm_nodes::Vector{String}, 
                    osm_geom::Vector{Vector{Float64}}, 
                    mapping_feature_id::String, 
                    osm_name::Union{String, Missing},
                    current_version_start::Int64, 
                    current_changeset_id::String,
                    way_count,
                    osm_attrs_df::DataFrame,
                    node_way_df::DataFrame,
                    attribute_df::DataFrame,
                    node_way_attribute_lock)

    sorted_indices = sort([find_index(combined_node, osm_geom) for combined_node in combined_nodes])

    if !isempty(sorted_indices) && length(sorted_indices) == 1 && (1 < sorted_indices[1] < length(osm_geom))
        create_first_way(sorted_indices, osm_nodes, osm_geom, mapping_feature_id, osm_name, current_version_start, current_changeset_id, way_count, osm_attrs_df, node_way_df, attribute_df, node_way_attribute_lock)
        create_last_way(sorted_indices, osm_nodes, osm_geom, mapping_feature_id, osm_name, current_version_start, current_changeset_id, way_count, osm_attrs_df, node_way_df, attribute_df, node_way_attribute_lock)
    elseif !isempty(sorted_indices) && length(sorted_indices) >= 2
        if sorted_indices[1] != 1 && sorted_indices[end] != length(osm_geom)
            create_first_way(sorted_indices, osm_nodes, osm_geom, mapping_feature_id, osm_name, current_version_start, current_changeset_id, way_count, osm_attrs_df, node_way_df, attribute_df, node_way_attribute_lock)
            create_middle_ways(sorted_indices, osm_nodes, osm_geom, mapping_feature_id, osm_name, current_version_start, current_changeset_id, way_count, osm_attrs_df, node_way_df, attribute_df, node_way_attribute_lock)
            create_last_way(sorted_indices, osm_nodes, osm_geom, mapping_feature_id, osm_name, current_version_start, current_changeset_id, way_count, osm_attrs_df, node_way_df, attribute_df, node_way_attribute_lock)
        elseif sorted_indices[1] == 1 && sorted_indices[end] != length(osm_geom)
            create_middle_ways(sorted_indices, osm_nodes, osm_geom, mapping_feature_id, osm_name, current_version_start, current_changeset_id, way_count, osm_attrs_df, node_way_df, attribute_df, node_way_attribute_lock)
            create_last_way(sorted_indices, osm_nodes, osm_geom, mapping_feature_id, osm_name, current_version_start, current_changeset_id, way_count, osm_attrs_df, node_way_df, attribute_df, node_way_attribute_lock)
        elseif sorted_indices[1] != 1 && sorted_indices[end] == length(osm_geom)
            create_first_way(sorted_indices, osm_nodes, osm_geom, mapping_feature_id, osm_name, current_version_start, current_changeset_id, way_count, osm_attrs_df, node_way_df, attribute_df, node_way_attribute_lock)
            create_middle_ways(sorted_indices, osm_nodes, osm_geom, mapping_feature_id, osm_name, current_version_start, current_changeset_id, way_count, osm_attrs_df, node_way_df, attribute_df, node_way_attribute_lock)
        elseif sorted_indices[1] == 1 && sorted_indices[end] == length(osm_geom)
            create_middle_ways(sorted_indices, osm_nodes, osm_geom, mapping_feature_id, osm_name, current_version_start, current_changeset_id, way_count, osm_attrs_df, node_way_df, attribute_df, node_way_attribute_lock)
        end
    end
end

"""
copy_node_way_df_in_batch(node_way_df::DataFrame, 
                            batch_size::Int64)

Copy new nodes ways from dataframe to DB in batch.

# Arguments
- `node_way_df::DataFrame`: Node-Way dataframe
- `batch_size::Int64`: Batch size, set to 10,000
"""
function copy_node_way_df_in_batch(node_way_df::DataFrame, batch_size::Int64)
    node_way_batch_rounds = Int(floor(size(node_way_df)[1] / batch_size) + 1)
    ThreadPools.@qbthreads for x in 1:node_way_batch_rounds
        try
            if x != node_way_batch_rounds
                from_index = x == 1 ? 1 : (x-1) * batch_size
                to_index = from_index == 1 ? (from_index + batch_size - 2) : (from_index + batch_size - 1)
                try
                    copy_node_way_df_to_db(node_way_df[from_index:to_index, :])
                catch way_err
                    @error "Threading encounterd an error at non last round,\n$(typeof(way_err))" exception=(way_err, catch_backtrace())
                end
            elseif x == node_way_batch_rounds
                from_index = (x-1) * batch_size 
                to_index = size(node_way_df)[1]
                try 
                    copy_node_way_df_to_db(node_way_df[from_index:to_index, :])
                catch way_last_err
                    @error "Threading encounterd an error at last round,\n$(typeof(way_last_err))" exception=(way_last_err, catch_backtrace())
                end
            end
        catch way_error
            @error "Threading encounterd an node way insertion error,\n$(typeof(way_error))" exception=(way_error, catch_backtrace())
        end
    end
end

"""
copy_attribute_df_in_batch(attribute_df::DataFrame, 
                            batch_size::Int64)

Copy new OSM ways attributes from dataframe to DB in batch.

# Arguments
- `attribute_df::DataFrame`: Attribute dataframe
- `batch_size::Int64`: Batch size, set to 10,000
"""
function copy_attribute_df_in_batch(attribute_df::DataFrame, batch_size::Int64)
    attribute_batch_rounds = Int(floor(size(attribute_df)[1] / batch_size) + 1)
    ThreadPools.@qbthreads for x in 1:attribute_batch_rounds
        try
            if x != attribute_batch_rounds
                from_index = x == 1 ? 1 : (x-1) * batch_size
                to_index = from_index == 1 ? (from_index + batch_size - 2) : (from_index + batch_size - 1)
                try
                    copy_attribute_df_to_db(attribute_df[from_index:to_index,:])
                catch attr_err
                    @error "Threading encounterd an error at attribute non last round,\n$(typeof(attr_err))" exception=(attr_err, catch_backtrace())
                end
            elseif x == attribute_batch_rounds
                from_index = (x-1) * batch_size 
                to_index = size(attribute_df)[1]
                try 
                    copy_attribute_df_to_db(attribute_df[from_index:to_index,:])
                catch attr_last_err
                    @error "Threading encounterd an error at attribute last round,\n$(typeof(attr_last_err))" exception=(attr_last_err, catch_backtrace())
                end
            end
        catch attr_error
            @error "Threading encounterd an attribute insertion error,\n$(typeof(attr_error))" exception=(attr_error, catch_backtrace())
        end
    end
end

"""
copy_node_way_df_to_db(node_way_df::DataFrame)

# arguments
- `node_way_df::DataFrame`: Node way dataframe

Write new nodes and ways from dataframe to DB.
"""
function copy_node_way_df_to_db(node_way_df::DataFrame)
    node_way_column_names = names(node_way_df)
    node_way_data = CSV.RowWriter(node_way_df, bufsize = 2^30, transform=(col, val) -> something(val, missing))
    copy_node_way_string = "COPY map_manager.mm_derived_feature ($("\"" * join(node_way_column_names, "\", \"") * "\"")) FROM STDIN (FORMAT CSV, HEADER);"
    PSQLInterface.execute_psql_string_copyin(copy_node_way_string, node_way_data)
end

"""
copy_attribute_df_to_db(attribute_df::DataFrame)

# arguments
- `attribtue_df::DataFrame`: Attribute dataframe

New ways inherit parent OSM attributes and write to DB.
"""
function copy_attribute_df_to_db(attribute_df::DataFrame)
    attribute_column_names = names(attribute_df)
    attribute_data = CSV.RowWriter(attribute_df, bufsize = 2^30, transform=(col, val) -> something(val, missing))
    copy_attribute_string = "COPY map_manager.mm_derived_attribute ($("\"" * join(attribute_column_names, "\", \"") * "\"")) FROM STDIN (FORMAT CSV, HEADER);"
    PSQLInterface.execute_psql_string_copyin(copy_attribute_string, attribute_data)
end

function split_osm_in_batch(aggregated_osm_matches_batch::DataFrame, node_count, way_count, 
                            node_way_df::DataFrame, attribute_df::DataFrame, node_way_attribute_lock, trigger_layer::String)
    for row in eachrow(aggregated_osm_matches_batch)
        osm_feature_id = row["osm_features"]
        @info "current OSM way id is $osm_feature_id"
        osm_geom_df = DataFrame(execute_psql_string(get_osm_metadata(), parameters=[osm_feature_id]))[1, :]
        if !isempty(osm_geom_df)
            osm_name = osm_geom_df.s_name
            osm_geom = convert(Vector{Vector{Float64}}, JSON3.read(osm_geom_df.geom)["coordinates"])
        end

        osm_nodes_df = DataFrame(execute_psql_string(get_osm_nodes(), parameters=[osm_feature_id, "nodes"]))[1, :]
        if !isempty(osm_nodes_df)
            osm_nodes = map(s -> string(s), eval(Meta.parse(osm_nodes_df.nodes)))
        end

        osm_attrs_df = DataFrame(execute_psql_string(get_osm_attributes(), parameters=[osm_feature_id, "nodes"]))

        current_version_start, current_changeset_id = get_current_changeset(trigger_layer)

        matched_vmt_ids = row["aggregated_vmt_ids"]
        split_matched_vmt_ids = split(matched_vmt_ids[2:end-1], ",")
        formatted_vmt_ids = "(" * join(map(s -> "'$(strip(s))'", split_matched_vmt_ids), ", ") * ")"

        get_matched_geom = execute_psql_string("""
            select ST_asGeoJSON(geom_feature) as geom from map_manager.mm_feature where feature_id in $formatted_vmt_ids and b_is_latest = true
        """
        )
        matched_geom_df = DataFrames.DataFrame(LibPQ.columntable(get_matched_geom))
        
        if !isempty(matched_geom_df)
            points_to_interpolate = convert(Vector{Vector{Float64}}, unique(points_to_interpolate_list(matched_geom_df)))
            create_nodes_and_ways(points_to_interpolate, osm_name, osm_geom, osm_feature_id, current_version_start, current_changeset_id, osm_nodes, node_count, way_count, osm_attrs_df, node_way_df, attribute_df, node_way_attribute_lock)
        end
    end
end

"""
function split_osm_all(aggregated_osm_matches::DataFrame, 
                        batch_size::Int64, 
                        node_count, 
                        way_count, 
                        node_way_df::DataFrame, 
                        attribute_df::DataFrame, 
                        node_way_attribute_lock
                        trigger_layer::String)
Split OSM ways that have multiple Vicmap matches in batch and run OSM split in each one of them.

# arguments
- `aggregated_osm_matches::DataFrame`: OSM ways that have multiple Vicmap matches dataframe.
- `batch_size::Int64`: 10000
- `node_count`: The current node count.
- `way_count`: The current way count.
- `node_way_df::DataFrame`: Node way dataframe that stores split results.
- `attribute_df::DataFrame`: Attribute dataframe that store attribute related info.
- `node_way_attribute_lock`: Lock dataframe from being written
- `trigger_layer`: Layer causing new derived layer to be created
"""
function split_osm_all(aggregated_osm_matches::DataFrame, 
                        batch_size::Int64, 
                        node_count, 
                        way_count, 
                        node_way_df::DataFrame, 
                        attribute_df::DataFrame, 
                        node_way_attribute_lock,
                        trigger_layer::String)
    aggregated_osm_batch_rounds = Int(floor(size(aggregated_osm_matches)[1] / batch_size) + 1)

    ThreadPools.@qbthreads for round in 1:aggregated_osm_batch_rounds
        if round != aggregated_osm_batch_rounds
            @info "Starting OSM Split in round $round out of $aggregated_osm_batch_rounds rounds"
            osm_from_index = round == 1 ? 1 : (round-1) * batch_size
            osm_to_index = osm_from_index == 1 ? (osm_from_index + batch_size - 2) : (osm_from_index + batch_size - 1)
            try 
                split_osm_in_batch(aggregated_osm_matches[osm_from_index:osm_to_index, :], node_count, 
                way_count, node_way_df, attribute_df, node_way_attribute_lock, trigger_layer)
            catch osm_split_err
                @error "Threading encounterd an error at splitting OSM dataframe,\n$(typeof(osm_split_err))" exception=(osm_split_err, catch_backtrace())
            end
        elseif round == aggregated_osm_batch_rounds
            @info "Starting OSM Split in round $round out of $aggregated_osm_batch_rounds rounds"
            osm_from_index = (round - 1) * batch_size
            osm_to_index = size(aggregated_osm_matches)[1]
            try 
                split_osm_in_batch(aggregated_osm_matches[osm_from_index:osm_to_index, :], node_count, 
                way_count, node_way_df, attribute_df, node_way_attribute_lock, trigger_layer)
            catch osm_split_last_err
                @error "Threading encounterd an error at OSM split last round,\n$(typeof(osm_split_last_err))" exception=(osm_split_last_err, catch_backtrace())
            end
        end
    end
end

"""
function create_nodes_and_ways(
                            points_to_interpolate::Vector{Vector{Float64}},
                            osm_name::Union{String, Missing},
                            osm_geom::Vector{Vector{Float64}},
                            mapping_feature_id::String,
                            current_version_start::Int64,
                            current_changeset_id::String,
                            way_count,
                            osm_attrs_df::DataFrame,
                            node_way_df::DataFrame,
                            attribute_df::DataFrame)
Calculate interpolated point and create new nodes and ways if condition met.

# arguments
- `points_to_interpolate::Vector{Vector{Float64}}`: a list of start and end point on Vicmap 
- `osm_name::Union{String, Missing}`: Parent OSM name
- `osm_geom::Vector{Vector{Float64}}`: osm geometry that a list of vicmap matched to
- `mapping_feature_id::String`: The parent OSM way id
- `current_version_start`: Parent OSM version start
- `current_changeset_id::String`: Parent OSM changeset id
- `way_count`: Current way count
- `osm_attrs_df::DataFrame`: OSM atribute dataframe 
- `node_way_df::DataFrame`: Node & Way dataframe
- `attribute_df::DataFrame`: Attribute dataframe
"""
function create_nodes_and_ways(
                            points_to_interpolate::Vector{Vector{Float64}},
                            osm_name::Union{String, Missing},
                            osm_geom::Vector{Vector{Float64}},
                            mapping_feature_id::String,
                            current_version_start::Int64,
                            current_changeset_id::String,
                            osm_nodes::Vector{String},
                            node_count,
                            way_count,
                            osm_attrs_df::DataFrame,
                            node_way_df::DataFrame,
                            attribute_df::DataFrame,
                            node_way_attribute_lock
                            )

    interpolated_points = []
    nearest_nodes = []

    for point_to_interpolate in points_to_interpolate
        nearest_node, nearest_node_index = find_nearest_point(point_to_interpolate, osm_geom)
        origin_vector = point_to_interpolate - nearest_node

        if nearest_node_index == 1
            projection_direction_right, target_vector_right = get_projection_direction(osm_geom, nearest_node_index, nearest_node, origin_vector, true)

            if projection_direction_right > 0
                interpolated_point = calculate_interpolated_point(nearest_node, projection_direction_right, target_vector_right)
                interpolated_point_index = nearest_node_index + 1
            else
                interpolated_point = nothing
            end
        elseif 1 < nearest_node_index < length(osm_geom)
            projection_direction_right, target_vector_right = get_projection_direction(osm_geom, nearest_node_index, nearest_node, origin_vector, true)
            projection_direction_left, target_vector_left = get_projection_direction(osm_geom, nearest_node_index, nearest_node, origin_vector, false)

            if projection_direction_right > 0 && projection_direction_left < 0
                interpolated_point = calculate_interpolated_point(nearest_node, projection_direction_right, target_vector_right)
                interpolated_point_index = nearest_node_index + 1
            elseif projection_direction_right < 0 && projection_direction_left > 0
                interpolated_point = calculate_interpolated_point(nearest_node, projection_direction_left, target_vector_left)
                interpolated_point_index = nearest_node_index
            elseif projection_direction_right > 0 && projection_direction_left > 0
                # get the length of projection
                projection_length_right = projection_direction_right / LinearAlgebra.norm(target_vector_right)
                projection_length_left = projection_direction_left / LinearAlgebra.norm(target_vector_left)

                if projection_length_right > projection_length_left
                    interpolated_point = calculate_interpolated_point(nearest_node, projection_direction_right, target_vector_right)
                    interpolated_point_index = nearest_node_index + 1
                elseif projection_length_right < projection_length_left
                    interpolated_point = calculate_interpolated_point(nearest_node, projection_direction_left, target_vector_left)
                    interpolated_point_index = nearest_node_index
                end
            else
                interpolated_point = nothing
            # no need to consider orthogonal or both value < 0. If nothing is returned from this function, no need to create interpolated node
            end
        # when nearest node is the last element on OSM geometry, interpolated point has to be to the left of nearest point
        elseif nearest_node_index == length(osm_geom)
            projection_direction_left, target_vector_left = get_projection_direction(osm_geom, nearest_node_index, nearest_node, origin_vector, false)

            if projection_direction_left > 0
                interpolated_point = calculate_interpolated_point(nearest_node, projection_direction_left, target_vector_left)
                interpolated_point_index = nearest_node_index
            else
                interpolated_point = nothing
            end
        end
        node_created, node = create_node(nearest_node, interpolated_point, mapping_feature_id, current_version_start, current_changeset_id, node_count, node_way_df, node_way_attribute_lock)

        if node_created
            insert!(osm_geom, interpolated_point_index, interpolated_point)
            push!(interpolated_points, interpolated_point)

            insert!(osm_nodes, interpolated_point_index, node)
        elseif !(node_created) && !isnothing(node)
            push!(nearest_nodes, node)
        end
    end 

    combined_nodes = convert(Vector{Vector{Float64}}, unique(vcat(interpolated_points, nearest_nodes)))

    create_ways(combined_nodes, osm_nodes, osm_geom, mapping_feature_id, osm_name, current_version_start, current_changeset_id, way_count, osm_attrs_df, node_way_df, attribute_df, node_way_attribute_lock)

end

"""
split_osm_ways(trigger_layer::String)

Find all OSM ways with multiple matches, iterating through all OSM ways and split them.
Create new nodes and ways if needed.
"""
function split_osm_ways(trigger_layer::String)
    
    initialise_db()
    
    node_count = Threads.Atomic{Int}(1)
    way_count = Threads.Atomic{Int}(1)
    batch_size = 10000

    node_way_attribute_lock = Threads.ReentrantLock()

    node_way_df = DataFrame(
        feature_id=String[],
        mapping_feature_id=String[],
        layer_id=String[],
        s_name=Union{String, Missing}[],
        e_feature_type=String[],
        s_source_id=String[],
        geom_feature=String[],
        global_version_id_start=Int64[],
        changeset_id=String[]
    )

    attribute_df = DataFrame(
        attribute_id=String[],
        feature_id=String[],
        s_name=String[],
        s_value=String[],
        global_version_id_start=Int64[],
        changeset_id=String[]
    )

    osm_matches = execute_psql_string(get_osm_with_multiple_matches())
    aggregated_osm_matches = DataFrames.DataFrame(LibPQ.columntable(osm_matches))

    split_osm_all(aggregated_osm_matches, batch_size, node_count, way_count, node_way_df, 
                    attribute_df, node_way_attribute_lock, trigger_layer)

    @info "Finished OSM split, writing DF to DB"
    copy_node_way_df_in_batch(node_way_df, batch_size)
    copy_attribute_df_in_batch(attribute_df, batch_size)
    
end

end