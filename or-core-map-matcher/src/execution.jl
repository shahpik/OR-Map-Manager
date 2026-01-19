#Execution script
"""
get_source_data(sourceName)

This function takes in a sourceName such as "LOCALITY", "POSTCODE", "VICMAP_TRANSPORT" 
and retrieves the id and geom_feature for the source from the map_manager.mm_feature table in the database. 
It then passes the dataframe to the 'convert_df_to_geojson' function to be converted to geojson. 
"""
function get_source_data(sourceName::String, graph_type::String)

    # This select statement selects all VicMap features which should match against the OSM Road Graph
    vicmap_road = """
    SELECT
    ST_AsGeoJSON(fe.geom_feature) AS geometry,
    fe.feature_id AS feature_id,
    atz.s_value AS road_name,
    att.s_value AS direction_code
        FROM
        map_manager.mm_feature fe
    LEFT JOIN
        map_manager.mm_attribute att ON fe.feature_id = att.feature_id
                                    AND att.s_name = 'direction_code'
                                    AND att.b_is_latest = TRUE
    LEFT JOIN
        map_manager.mm_attribute atz ON fe.feature_id = atz.feature_id
                                    AND atz.s_name = 'local_road'
                                    AND atz.b_is_latest = TRUE
    WHERE
        fe.layer_id = '$sourceName'
        AND fe.b_is_latest = TRUE
        
        AND EXISTS (
            SELECT 1
            FROM map_manager.mm_attribute AS sub
            WHERE sub.feature_id = fe.feature_id
                AND sub.s_name = 'class_code'
                AND (
                    (sub.s_value IN ('0', '1', '2', '3', '4') AND NOT EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub2
                        WHERE sub2.feature_id = sub.feature_id
                            AND sub2.s_name = 'feature_type_code'
                            AND sub2.s_value IN ('connector', 'ford')
                    ))
                    OR (sub.s_value = '5' AND NOT EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub2
                        WHERE sub2.feature_id = sub.feature_id
                            AND sub2.s_name = 'feature_type_code'
                            AND sub2.s_value IN ('connector', 'ford')
                        ) AND NOT EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub3
                        WHERE sub3.feature_id = sub.feature_id
                            AND sub3.s_value = 'track'
                    ))
                    OR (sub.s_value = '6' AND NOT EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub2
                        WHERE sub2.feature_id = sub.feature_id
                            AND sub2.s_name = 'feature_type_code'
                            AND sub2.s_value IN ('connector', 'ford', 'tunnel')
                        ) AND NOT EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub3
                        WHERE sub3.feature_id = sub.feature_id
                            AND sub3.s_value = 'track'
                    ))
                    OR (sub.s_value = '7' AND NOT EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub2
                        WHERE sub2.feature_id = sub.feature_id
                            AND sub2.s_name = 'feature_type_code'
                            AND sub2.s_value IN ('connector', 'ford', 'bridge')
                        ) AND NOT EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub3
                        WHERE sub3.feature_id = sub.feature_id
                            AND sub3.s_value = 'track'
                        ) AND NOT EXISTS (
                        SELECT 1
                        FROM map_manager.mm_feature AS sub4
                        WHERE sub4.feature_id = sub.feature_id
                            AND sub4.s_name = 'UNNAMED'
                    ))
                    OR (sub.s_value = '13' AND EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub2
                        WHERE sub2.feature_id = sub.feature_id
                            AND sub2.s_name = 'feature_type_code'
                            AND sub2.s_value = 'road'
                    ))
                )
        );
    """
    # This select statement selects all VicMap features which should match against the OSM Trail Graph
    vicmap_trails = """
    SELECT
    ST_AsGeoJSON(fe.geom_feature) AS geometry,
    fe.feature_id AS feature_id,
    atz.s_value AS road_name,
    att.s_value AS direction_code
    FROM
        map_manager.mm_feature fe
    LEFT JOIN
        map_manager.mm_attribute att ON fe.feature_id = att.feature_id
                                    AND att.s_name = 'direction_code'
                                    AND att.b_is_latest = TRUE
    LEFT JOIN
        map_manager.mm_attribute atz ON fe.feature_id = atz.feature_id
                                    AND atz.s_name = 'local_road'
                                    AND atz.b_is_latest = TRUE
    WHERE
        fe.layer_id = '$sourceName'
        AND fe.b_is_latest = TRUE
        AND EXISTS (
            SELECT 1
            FROM map_manager.mm_attribute AS sub
            WHERE sub.feature_id = fe.feature_id
                AND sub.s_name = 'class_code'
                AND (
                    (sub.s_value = '9' AND EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub2
                        WHERE sub2.feature_id = sub.feature_id
                            AND sub2.s_name = 'feature_type_code'
                            AND sub2.s_value IN ('trail', 'tunnel')
                    ))
                    OR (sub.s_value = '8' AND EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub2
                        WHERE sub2.feature_id = sub.feature_id
                            AND sub2.s_name = 'feature_type_code'
                            AND sub2.s_value IN ('bridge', 'road')
                    ))
                    OR (sub.s_value = '7' AND EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub2
                        WHERE sub2.feature_id = sub.feature_id
                            AND sub2.s_name = 'feature_type_code'
                            AND sub2.s_value = 'bridge'
                    ))
                    OR (sub.s_value IN ('6', '7') AND EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub2
                        WHERE sub2.feature_id = sub.feature_id
                            AND sub2.s_name = 'feature_type_code'
                            AND sub2.s_value = 'road'
                        AND EXISTS (
                            SELECT 1
                            FROM map_manager.mm_attribute AS sub3
                            WHERE sub3.feature_id = sub.feature_id
                                AND sub3.s_name = 'road_type'
                                AND sub3.s_value = 'track'
                        )
                    ))
                    OR (sub.s_value IN ('5', '6') AND EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub2
                        WHERE sub2.feature_id = sub.feature_id
                            AND sub2.s_name = 'feature_type_code'
                            AND sub2.s_value = 'bridge'
                        AND EXISTS (
                            SELECT 1
                            FROM map_manager.mm_attribute AS sub3
                            WHERE sub3.feature_id = sub.feature_id
                                AND sub3.s_name = 'road_type'
                                AND sub3.s_value = 'track'
                        )
                    ))
                    OR (sub.s_value = '6' AND EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub2
                        WHERE sub2.feature_id = sub.feature_id
                            AND sub2.s_name = 'feature_type_code'
                            AND sub2.s_value = 'tunnel'
                    ))
                )
        );
    """

    non_vicmap = """
    select
    ST_AsGeoJSON(fe.geom_feature) as geometry,
    fe.feature_id as feature_id
    from map_manager.mm_feature fe
    where fe.layer_id = '$sourceName' 
    and fe.b_is_latest = true;
    """

    vicmap_roads_delta = """
    SELECT
    ST_AsGeoJSON(fe.geom_feature) AS geometry,
    fe.feature_id AS feature_id,
    atz.s_value AS road_name,
    att.s_value AS direction_code
        FROM
        map_manager.mm_feature fe
    LEFT JOIN
        map_manager.mm_attribute att ON fe.feature_id = att.feature_id
                                    AND att.s_name = 'direction_code'
                                    AND att.b_is_latest = TRUE
    LEFT JOIN
        map_manager.mm_attribute atz ON fe.feature_id = atz.feature_id
                                    AND atz.s_name = 'local_road'
                                    AND atz.b_is_latest = TRUE
    WHERE
        fe.layer_id = '$sourceName'
        AND fe.b_is_latest = TRUE
        AND fe.global_version_start is null 
        AND fe.global_version_id_end is null 
        AND fe.e_feature_status != 'REMOVED'
        AND EXISTS (
            SELECT 1
            FROM map_manager.mm_attribute AS sub
            WHERE sub.feature_id = fe.feature_id
                AND sub.s_name = 'class_code'
                AND (
                    (sub.s_value IN ('0','1', '2', '3', '4') AND NOT EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub2
                        WHERE sub2.feature_id = sub.feature_id
                            AND sub2.s_name = 'feature_type_code'
                            AND sub2.s_value IN ('connector', 'ford')
                    ))
                    OR (sub.s_value = '5' AND NOT EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub2
                        WHERE sub2.feature_id = sub.feature_id
                            AND sub2.s_name = 'feature_type_code'
                            AND sub2.s_value IN ('connector', 'ford')
                        ) AND NOT EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub3
                        WHERE sub3.feature_id = sub.feature_id
                            AND sub3.s_value = 'track'
                    ))
                    OR (sub.s_value = '6' AND NOT EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub2
                        WHERE sub2.feature_id = sub.feature_id
                            AND sub2.s_name = 'feature_type_code'
                            AND sub2.s_value IN ('connector', 'ford', 'tunnel')
                        ) AND NOT EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub3
                        WHERE sub3.feature_id = sub.feature_id
                            AND sub3.s_value = 'track'
                    ))
                    OR (sub.s_value = '7' AND NOT EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub2
                        WHERE sub2.feature_id = sub.feature_id
                            AND sub2.s_name = 'feature_type_code'
                            AND sub2.s_value IN ('connector', 'ford', 'bridge')
                        ) AND NOT EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub3
                        WHERE sub3.feature_id = sub.feature_id
                            AND sub3.s_value = 'track'
                        ) AND NOT EXISTS (
                        SELECT 1
                        FROM map_manager.mm_feature AS sub4
                        WHERE sub4.feature_id = sub.feature_id
                            AND sub4.s_name = 'UNNAMED'
                    ))
                    OR (sub.s_value = '13' AND EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub2
                        WHERE sub2.feature_id = sub.feature_id
                            AND sub2.s_name = 'feature_type_code'
                            AND sub2.s_value = 'road'
                    ))
                )
        );
    """

    # This select statement selects all VicMap features which should match against the OSM Trail Graph
    vicmap_trails_delta = """
    SELECT
    ST_AsGeoJSON(fe.geom_feature) AS geometry,
    fe.feature_id AS feature_id,
    atz.s_value AS road_name,
    att.s_value AS direction_code
    FROM
        map_manager.mm_feature fe
    LEFT JOIN
        map_manager.mm_attribute att ON fe.feature_id = att.feature_id
                                    AND att.s_name = 'direction_code'
                                    AND att.b_is_latest = TRUE
    LEFT JOIN
        map_manager.mm_attribute atz ON fe.feature_id = atz.feature_id
                                    AND atz.s_name = 'local_road'
                                    AND atz.b_is_latest = TRUE
    WHERE
        fe.layer_id = '$sourceName'
        AND fe.global_version_start is null 
        AND fe.global_version_id_end is null 
        AND fe.e_feature_status != 'REMOVED'
        AND EXISTS (
            SELECT 1
            FROM map_manager.mm_attribute AS sub
            WHERE sub.feature_id = fe.feature_id
                AND sub.s_name = 'class_code'
                AND (
                    (sub.s_value = '9' AND EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub2
                        WHERE sub2.feature_id = sub.feature_id
                            AND sub2.s_name = 'feature_type_code'
                            AND sub2.s_value IN ('trail', 'tunnel')
                    ))
                    OR (sub.s_value = '8' AND EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub2
                        WHERE sub2.feature_id = sub.feature_id
                            AND sub2.s_name = 'feature_type_code'
                            AND sub2.s_value IN ('bridge', 'road')
                    ))
                    OR (sub.s_value = '7' AND EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub2
                        WHERE sub2.feature_id = sub.feature_id
                            AND sub2.s_name = 'feature_type_code'
                            AND sub2.s_value = 'bridge'
                    ))
                    OR (sub.s_value IN ('6', '7') AND EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub2
                        WHERE sub2.feature_id = sub.feature_id
                            AND sub2.s_name = 'feature_type_code'
                            AND sub2.s_value = 'road'
                        AND EXISTS (
                            SELECT 1
                            FROM map_manager.mm_attribute AS sub3
                            WHERE sub3.feature_id = sub.feature_id
                                AND sub3.s_name = 'road_type'
                                AND sub3.s_value = 'track'
                        )
                    ))
                    OR (sub.s_value IN ('5', '6') AND EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub2
                        WHERE sub2.feature_id = sub.feature_id
                            AND sub2.s_name = 'feature_type_code'
                            AND sub2.s_value = 'bridge'
                        AND EXISTS (
                            SELECT 1
                            FROM map_manager.mm_attribute AS sub3
                            WHERE sub3.feature_id = sub.feature_id
                                AND sub3.s_name = 'road_type'
                                AND sub3.s_value = 'track'
                        )
                    ))
                    OR (sub.s_value = '6' AND EXISTS (
                        SELECT 1
                        FROM map_manager.mm_attribute AS sub2
                        WHERE sub2.feature_id = sub.feature_id
                            AND sub2.s_name = 'feature_type_code'
                            AND sub2.s_value = 'tunnel'
                    ))
                )
        );

    """

    non_vicmap_layer = false

    # Perform the select statement and convert result to a dataframe
    if sourceName == "VICMAP_TRANSPORT"
        if graph_type == "road"
            source_data_dataframe = DataFrame(execute_psql_string(vicmap_road))
        elseif graph_type == "trail"
            source_data_dataframe = DataFrame(execute_psql_string(vicmap_trails))
        end 
    else  
        source_data_dataframe = DataFrame(execute_psql_string(non_vicmap))
        non_vicmap_layer = true
    end

    @info "Downloaded $sourceName Data from Database for mapping"
    # Call the convert_df_to_geojson() function to convert the dataframe to a featurecollection
    converted_source_data = convert_df_to_geojson(source_data_dataframe, non_vicmap_layer)
    reduced_source_data = reduce_linestring(converted_source_data; threshold_length = 500, reduction_length = 50, reduction_percentage = 10)
    return reduced_source_data
end


function results_upload(source_name, matched_dict, trigger_layer; original_osm, debug=false)
    @info "============== STARTING UPLOAD PROCESS FOR MAP MATCHING RESULTS: $(source_name) =============="
    # Enforce uppercase to improve error handling
    source_name = Symbol(uppercase(string(source_name)))
    df = convert_geojson_to_df(matched_dict)
    # Updates to lowercase for DB usage
    source_name_lower = lowercase(string(source_name))
    df_to_db(df, source_name_lower, trigger_layer; original_osm, debug=debug)
    return nothing
end


"""
convert_df_to_geojson(layer_feature)

This function takes in a source data as a dataframe and converts it to a featureCollection of features with geometry
and properties. This can be returned as a Dict or geojson string. 
"""
function convert_df_to_geojson(layer_feature, non_vicmap_layer::Bool)
    geoj = Dict("type" => "FeatureCollection", "features" => [])
    total_rows = nrow(layer_feature)
    @info "Total Layer Features: $total_rows"
    prev_progress = 0.0
    for i in 1:total_rows
        # Define the new feature properties and geometry
        if non_vicmap_layer == true
            new_feature = Dict(
                "geometry" => JSON3.read(layer_feature.geometry[i], Dict),
                "properties" => Dict{String,Any}("id" => layer_feature.feature_id[i]),
                "id" => layer_feature.feature_id[i]
            )
        else
            new_feature = Dict(
                "geometry" => JSON3.read(layer_feature.geometry[i], Dict),
                "properties" => Dict{String,Any}("id" => layer_feature.feature_id[i], "direction_code" => layer_feature.direction_code[i]),
                "id" => layer_feature.feature_id[i],
                "direction_code" => layer_feature.direction_code[i],
                "road_name" => layer_feature.road_name[i]
            )
        end
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


function df_to_db(df, source_name, trigger_layer; tz="Australia/Melbourne", original_osm, debug=false)
    try
        execute_psql_string("SET timezone TO '$(tz)';")
        @info "Set PostgreSQL timezone to $(tz)"

        source_elt(df, source_name, trigger_layer; schema="map_manager", original_osm, debug=debug)
        @info "Finished $(source_name) data load process"
    finally
        execute_psql_string("SET timezone TO 'GMT';")
        @info "Reset PostgreSQL timezone to GMT"
    end
end


function convert_geojson_to_df(matched_dict::Dict)::DataFrame
    #Take in a dict instead of a string
    features = matched_dict["features"]
    df = DataFrame(geometry=String[])

    for f in features
        # New row contains all properties
        row = Dict{Any,Any}(f["properties"])

        for (k,v) in row
            if v isa Array
                row[k]=JSON3.write(v)
            end
        end
        # Transform geometry into JSON string
        row["geometry"] = JSON3.write(f["geometry"])

        if haskey(f, "id")
            row["id"]=f["id"]
        end
        # Append to DataFrame
        append!(df, DataFrame(row); cols=:union)
    end

    return df
end

function check_delta(sourceName::String)
    check_delta_query = execute_psql_string("""
    SELECT count(*) FROM map_manager.mm_feature
    WHERE layer_id = '$sourceName' and
    global_version_id_start IS NULL;
    """
    )
    get_count = DataFrame(check_delta_query)[1,1]
    if get_count == 0
        return false
    else
        return true
    end
end

function get_changeset_count()
    get_changeset_count_statement = """
    select count(*) from map_manager.mm_changeset where e_changeset_edit_type = 'SOURCE'
    """

    changeset_count = DataFrame(execute_psql_string(get_changeset_count_statement))[1,1]
    return changeset_count
end

"""
reduce_linestring_length(converted_source_data::Dict; reduction_percentage::Int64)

This function takes in a dictionary of VicMap data, extracts vectors of coordinates and reduces them in length. 
If the lstring_distance of line is > 500m, we remove 50m from each end. If the lstring_distance is < 500m, we remove 10%. 
These are parameters that can be set when we call the function. 
When we remove 50m or 10%, we will be interpolating a point. 
This may be between the 1st and 2nd node, or might need to be between the 2nd and 3rd...and so on. 
"""
function reduce_linestring(converted_source_data::Dict; threshold_length::Int64 = 500, reduction_length::Int64 = 50, reduction_percentage::Int64 = 10)
    # First we extract the coordinates from each feature in the Dict
    @info "Linestring Length Reduction Step in Progress..."
    reduced_source_data = converted_source_data
    for f in reduced_source_data["features"]
        coords = f["geometry"]["coordinates"]
        if f["geometry"]["type"] == "LineString"
            coords = Vector{Vector{Float64}}(coords)
        elseif f["geometry"]["type"] == "MultiLineString" && length(coords) == 1
            coords = Vector{Vector{Float64}}(coords[1])
            f["geometry"]["type"] = "LineString"
        else
            @debug "Skipping unsupported geometry type $(feature["geometry"]["type"])"
            continue
        end
        total_length = lstring_distance(coords) * 1000

        # Interpolate by 10% if the length is smaller than threshold length (500m)
        (total_length < threshold_length) ? 
        (interpolation_length = (reduction_percentage/100) * total_length) : 
        (interpolation_length = reduction_length)
        #println("Interpolate $interpolation_length in")
        # Call general function to remove this length from the start
        coords_start = remove_length(coords, interpolation_length)
        # Call general function to remove this length from the end by reversing coords
        coords_end = remove_length(reverse(coords_start), interpolation_length)
        # Reverse coords to correct their orientation to original 
        coords_final = reverse(coords_end)
        f["geometry"]["coordinates"] = coords_final
    end
    @info "Linestring Length Reduction Step Completed..."
    return reduced_source_data
end

"""remove_length(coords, interpolation_length)

A general function to remove a prescribed length from a linestring.
It does this by interpolating new points and removing nodes where needed. 
To remove from both sides of a linestring, this function should be called twice: 
Once for the start coordinates, and then with reversed coordinates for the other side. 
"""
function remove_length(coords, interpolation_length)
    len_so_far = 0
    shortened_coords = copy(coords)

    for i in 1:length(coords)-1
        # Calculate length between nodes iteratively 
        new_len = lstring_distance([coords[i], coords[i+1]]) * 1000
        #println("between point $i and point $(i+1) the distance is $new_len")
        # If the total length so far and the new length takes us over the interplation length, interpolate a point
        # Coordinates i is removed, coordinates i+1 is kept 
        if len_so_far + new_len > interpolation_length
            #println("Len so far is $len_so_far and the next coordinate pushes us over that limit")
            # Calculate the 'amount' left to interpolate inwards
            remainder = interpolation_length - len_so_far
            #println("Remainder we need to interpolate for is $remainder m")
            # Calculation is based on proportion and is between coordinate set i and i+1 
            proportion = remainder/new_len
            #Interpolate a point here
            x1, y1 = coords[i]
            x2, y2 = coords[i+1]
            # Interpolate a point here
            x1, y1 = coords[i]
            x2, y2 = coords[i+1]
            x_c = x1 + proportion * (x2 - x1)
            y_c = y1 + proportion * (y2 - y1)
            interpolated_point = [x_c, y_c]
            
            # Update shortened_coords starting from the interpolated point
            shortened_coords = [[interpolated_point]; vcat(coords[i+1:end])]
            break
        # The interpolation length has not been reached, so record how much was consumed 
        # Continue to next coordinate set 
        else 
            len_so_far += new_len
        end
    end
    return shortened_coords
end