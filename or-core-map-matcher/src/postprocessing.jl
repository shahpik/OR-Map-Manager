
## The following code contains functions to post process map matching results.
"""
post_process_matches(matched_with_error_metrics::Dict, osm_dict::Dict)::Dict

This function takes in a match dictionary, and an osm_dict recording all matches to an OSM way. 
It then postprocesses the match dictionary by looking for cases where there were multiple VicMap matches to an OSM way
that had different road names. It then calculates average error, angle and length metrics for each road name 
and based on these values makes a determination of the best road name(s) to keep. The code alters the match_dict by 
removing incorrect way matches, and therefore recreates the geometry and error metrics of the newly altered relationships. 
The output is an altered version of the matched_with_error_metrics dictionary. 
"""
function post_process_matches(matched_with_error_metrics::Dict, osm_dict::Dict, original_osm::Bool)::Dict
    @info "Post-processing Step beginning now...\n"
    # First remove all 'good' matches from osm_dict - they don't need to be preprocessed.
    # For 'road_name' post-processing, this is done by removing cases where only one road name was matched to 
    # For general 1:1 / 1:many post-processing, this is done by removing cases where only 1 input linestring matched to a way 
    if original_osm == true
        for (way_key, entry) in osm_dict
            # Check if all road names are the same - indicating a fine match
            if length(unique(entry["road_names"])) <= 1
                delete!(osm_dict, way_key)
                println("Deleted $way_key")
            end
        end
    else
        for (way_key, entry) in osm_dict
            # Check if there is only 1 input linestring that matched to this way - indicating a fine match
            if length(entry["input_source_linestrings"]) <= 1
                delete!(osm_dict, way_key)
                println("Deleted $way_key")
            end
        end
    end
    # Retrieve all geometries we will need for postprocessing
    geom_dict = select_geom_for_post_processing(osm_dict, original_osm)

    # The Custom Seed File contains geometries which are incorrectly stored as MultiLineStrings - this step ensures only linestrings
    for (key, value) in geom_dict
        # Check if the type of the value isn't a linestring
        if typeof(value) != Vector{Vector{Float64}}
            # Store the flattened result
            try
                flattened_value = convert(Vector{Vector{Float64}}, vcat(value...))
                # Replace the original value in geom_dict with the flattened one
                geom_dict[key] = flattened_value
            catch
                @error "Coodinates convert failed at coords: $value and id is: $key"
            end
        end
    end
    @info "Finished retrieving all linestring geometries"
    # Monitor progress
    i = 0
    len = length(osm_dict)
    # For each unique OSM way in the dictionary
    for (way_key, entry) in osm_dict
        i = i+1
        @info "Progress = $i of $len"
        # Select the VicMap feature ids we will need to test
        matched_feature_ids = entry["input_source_linestrings"]
        # Initialise an empty array for the metrics we're about to calculate
        osm_dict[way_key]["angles"] = []
        osm_dict[way_key]["errors"] = []
        # Iterate over each VicMap feature
        for id in matched_feature_ids
            # Select the vectors for vmt and osm features
            vmt_vector = geom_dict[id]
            osm_vector = geom_dict[way_key]
            # Return the individual relationship formed with that OSM&&WAY and also the error
            trimmed_relationship, formatted_relationship_geom, error = recreate_individual_relationship(vmt_vector, osm_vector);
            # Calculate the length of the matched geometry 
            length_of_match = lstring_distance(trimmed_relationship)
            angle_of_match = calculate_local_angle_delta(vmt_vector, osm_vector)
            push!(osm_dict[way_key]["individual_lengths"], length_of_match)
            push!(osm_dict[way_key]["angles"], angle_of_match)
            push!(osm_dict[way_key]["errors"], error)
        end
        
        # Initialize a dictionary to store lists of angle differences and errors
        angle_diffs_dict = Dict()
        errors_dict = Dict()
        metrics_dict = Dict()
        individual_lengths = osm_dict[way_key]["individual_lengths"]
        individual_angles = osm_dict[way_key]["angles"]
        individual_errors = osm_dict[way_key]["errors"]

        # For 'road_name' post-processing in the original OSM we need to group by road name
        # For general 1:1 / 1:many post-processing, we actually don't want to group, but we can reuse existing code by knowing that all 'input_source_linestrings' will be unique
        if original_osm == true
            # Get road names and individual metrics from the entry
            grouping_name = osm_dict[way_key]["road_names"]
        else
            # Get input_source_linestrings - these will all be unique values
            grouping_name = matched_feature_ids
        end

        # Iterate together for each name
        for (name, length, angle, error) in zip(grouping_name, individual_lengths, individual_angles, individual_errors)
            # Create an entry in angle_diffs_dict for each road name if one doesn't exist
            if !(haskey(angle_diffs_dict, name))
                angle_diffs_dict[name] = [angle]
                errors_dict[name] = [error]
            # If one already exists, we append the angle difference and error
            else
                push!(angle_diffs_dict[name], angle)
                push!(errors_dict[name], error)
            end
        end

        # Calculate total length, median angle difference, and median error
        for (name, angle_diffs) in angle_diffs_dict
            total_length = sum(individual_lengths[grouping_name .== name])
            median_angle_diff = median(angle_diffs)
            median_error = median(errors_dict[name])
            
            metrics_dict[name] = Dict("total_length" => total_length, "median_angle_diff" => median_angle_diff, "median_error" => median_error)
        end

        accepted_matches = choose_best_match(metrics_dict, original_osm)

        if isnothing(accepted_matches)
            undesired_indices = [i for (i, val) in enumerate(grouping_name)]
        else
            matching_keys = Set(keys(accepted_matches))
            undesired_indices = [i for (i, val) in enumerate(grouping_name) if !(val in matching_keys)]
        end

        # Initialize arrays to store grouping_name and indices to be removed
        undesired_grouping_name = grouping_name[undesired_indices]

        # Display the undesired_grouping_name and undesired_indices
        matches_to_be_removed = matched_feature_ids[undesired_indices]
        # Since way key is a string with "OSM&&WAYxxxx", split into just the way id since we store 'matched_ways' as a list of integers
        # split_way_key = split(way_key, "WAY")
        # way_key_int = parse(Int64, split_way_key[2])
        

        # For each VMT match that needs to be revisited 
        for vmt_linestring in matches_to_be_removed
            # Locating within our map matching dictionary
            for match in matched_with_error_metrics["features"]
                # If we can locate the vmt_linestring to be fixed
                if match["properties"]["id"] == vmt_linestring
                    println("way_key = $way_key")
                    # Remove the osm way that should not have been matched to
                    if haskey(match["properties"], "matched_ways") == false
                        continue
                    end
                    # new_matched_ways = [x for x in match["properties"]["matched_ways"] if x!= way_key_int]
                    new_matched_ways = [x for x in match["properties"]["matched_ways"] if x!= way_key]
                    # If the vmt linestring still matches to something, recalculate the match
                    if length(new_matched_ways) > 0 
                        #println("ORIGINAL geometry = $(match["geometry"]["coordinates"]), ORIGINAL matched ways = $(match["properties"]["matched_ways"])")
                        # To select from the database we need the full feature ids for OSM ways
                        # new_match_array = ["OSM&&WAY$x" for x in new_matched_ways]
                        new_match_array = new_matched_ways
                        # Select saved vmt_vector from geom_dict
                        vmt_vector = geom_dict[vmt_linestring]
                        # Calculate new geometry and error with precribed matches
                        trimmed_relationship, formatted_relationship_geom, error = recreate_individual_relationship(vmt_vector, new_match_array, original_osm)
                        # Update entries in the map matching dictionary
                        match["properties"]["matched_ways"] = new_matched_ways
                        match["properties"]["mapmatching_error"] = error
                        match["properties"]["offset_start"] = 0.0
                        match["properties"]["offset_end"] = 0.0
                        # NOTE we are setting these values to zero because we don't calculate them, and we are also ignoring matched_nodes.
                        # Matched nodes is not added to our database  
                        match["geometry"] = formatted_relationship_geom
                    # Otherwise if the vmt linestring now matches to nothing, remove all match information
                    else
                        # Remove matched geometry and keys associated with a successful match
                        match["geometry"]["coordinates"] = []
                        delete!(match["properties"], "offset_start")
                        delete!(match["properties"], "matched_ways")
                        delete!(match["properties"], "matched_nodes")
                        delete!(match["properties"], "offset_end")
                        # Redefine the map matching error to be a failed match
                        match["properties"]["mapmatching_error"] = "Failed to find path"   
                        #println("new properties = $(match["properties"])")
                    end
                end
            end
        end
    end
    # Return altered dictionary
    return matched_with_error_metrics
end

"""select_geom_for_post_processing(osm_dict::Dict)::Dict

This function retrieves all vector geometries for post processing in batched queries to speed up processing time. 
PostgreSQL has limits to the number of items you can include in a where condition. 
Upon testing, batches of 2000 was the most time efficient batch size to retrieve all information. 
The function takes in an input 'osm_dict' with keys being OSM ways like so -> "OSM&&WAY123456": ["VICMAP123456", "VICMAP987654"]
It combines all feature_ids referenced here (both keys and values in the array) and retrieves all geometries from the database. 
The output is a dictionary, where each key is a feature_id, and each value is a vector geometry. 
"""
function select_geom_for_post_processing(osm_dict::Dict, original_osm::Bool)::Dict   
    # For all features, record all feature_ids into a big array to be retrieved
    if original_osm == true
        # Then we can retrieve everything from mm_feature
        # Initialise empty array for feature_ids to be retrieved
        full_array = Vector{String}()
        for (way_key, entry) in osm_dict
            append!(full_array, [way_key, entry["input_source_linestrings"]...])
        end
        geom_dict = retrieve_geometries(full_array, "mm_feature")
    else
        # Then we can retrieve dtp/osm ways from mm_derived_feature, other layer from mm_feature
        # Initialise empty array for feature_ids to be retrieved
        way_array = String[]
        layer_array = String[]
        for (way_key, entry) in osm_dict
            append!(layer_array, [entry["input_source_linestrings"]...])
            push!(way_array, way_key)
        end
        way_dict = retrieve_geometries(way_array, "mm_derived_feature")
        layer_dict = retrieve_geometries(layer_array, "mm_feature")
        geom_dict = merge(way_dict, layer_dict)
    end
    return geom_dict
end

"""retrieve_geometries(feature_id_array, table::String)

This function accepts an array of feature_ids to retrieve from the database and a table
to retrieve them from. This was written due to the issue of needing to retrieve from multiple
tables. 
"""
function retrieve_geometries(feature_id_array::Vector{String}, table::String)
    # Initialise an empty Dict 
    geom_dict = Dict()
    # Define the size of each sub-array
    split_size = 2000 
    # Make sure we only retrieve this geometry once
    feature_id_array = unique(feature_id_array)
    # Split the long array into smaller arrays
    array_of_arrays = [feature_id_array[i:min(i+split_size-1, end)] for i in 1:split_size:length(feature_id_array)]
    # Retrieve into DF
    for batch_array in array_of_arrays
        println("Length of this array is $(length(batch_array))")
        # Select the geometries in a single query
        # Creates a variable sized 'items' which means feature_ids can be any length
        items = join(["\$$n" for n in 1:length(batch_array)], ", ")

        select_post_geom = execute_psql_string(
        """select
            feature_id, 
            ST_AsGeoJSON(geom_feature)
            from map_manager.$table
            where feature_id in ($(items))
            and b_is_latest;  
        """, parameters=batch_array) 

        input_feature_geom = DataFrame(select_post_geom)
        println("Length of DataFrame is $(size(input_feature_geom)[1])")
        println(input_feature_geom)

        for i in 1:size(input_feature_geom, 1)
            feature_id = input_feature_geom[i, :feature_id]
            geom_feature = input_feature_geom[i, :st_asgeojson]
            if !isempty(geom_feature)
                input_feat_json_array = JSON3.read(IOBuffer(geom_feature))["coordinates"]
                input_feat_vector = copy(input_feat_json_array)
                geom_dict[feature_id] = input_feat_vector
            end
        end
    end
    return geom_dict
end

"""calculate_local_angle_delta(vmt_ls, osm_ls)

This function calculates the difference between two linestrings. Since we are applying it
in cases where vmt is matching to longer osm ways, we will take the vmt start and end points
and find the nearest nodes in the OSM way, so that we can calculate the 'local' angle for OSM. 
Angles between [-15,15] or [-165, 165] seem to indicate 'fine' matches. 
An angle approaching -180 or 180 degrees occurs when osm and vmt linestrings are defined in opposite directions.
We could potentially normalise this by saying for any angle >90 degrees, -180, and vice versa.  
"""
function calculate_local_angle_delta(vmt_ls, osm_ls)
    closest_node_to_start, start_index, closest_node_to_end, end_index = SpatialUtilities.MapMatching.find_nearest_points(vmt_ls, osm_ls)
    angle_delta = angle_difference([closest_node_to_start, closest_node_to_end], vmt_ls)
    return angle_delta
end

"""angle_difference(osm::Vector{Vector{Float64}}, vmt::Vector{Vector{Float64}})

This function actually calculates the difference based on the linestrings provided. 
Output is in degrees for readability. 
"""
function angle_difference(osm::Vector{Vector{Float64}}, vmt::Vector{Vector{Float64}})
    # Compute angles for osm
    osm_angle = angle(complex(osm[end][1] - osm[1][1], osm[end][2] - osm[1][2]))
    # Compute angles for vmt
    vmt_angle = angle(complex(vmt[end][1] - vmt[1][1], vmt[end][2] - vmt[1][2]))
    # Calculate the absolute difference in angles
    angle_diff = abs(rad2deg(angle_normalize(osm_angle - vmt_angle)))
    return angle_diff
end

"""angle_normalize(angle)

This function is to normalize angle to range [-π/2, π/2]
"""
function angle_normalize(angle)
    # Normalize angle to be between [-π/2, π/2] radians
    while angle > π/2
        angle -= π
    end
    while angle < -π/2
        angle += π
    end
    return angle
end


"""
calculate_new_relationship(input_feat_vector::Vector{Vector{Float64}}, new_relation_vector::Vector{Vector{Float64}})

This function enables the creation of custom relationships. An 'input' vector is taken as
an input, as well as the vector of OSM way/s that this has been manually matched to. 
The function 'calculate_return_geom' is called to perform this calculation, and the error of
this new relationship is calculated also. 
"""
function calculate_new_relationship(input_feat_vector::Vector{Vector{Float64}}, new_relation_vector)
    # Using SpatialUtilities, calculate the relationship geometry 
    trimmed_relationship_geom = SpatialUtilities.MapMatching.calculate_return_geom(input_feat_vector, new_relation_vector)
    # Trimmed_relationship_geom will be a vector{vector{vector{Float64}}} by default
    # Define as either a linestring or multilinestring depending on length
    # Unnest if trimmed_relationship_geom is a linestring
    if length(trimmed_relationship_geom)>1
        type = "MultiLineString"
        trimmed_relationship_geom = Vector{Vector{Float64}}.(trimmed_relationship_geom)
    else
        type = "LineString"
        trimmed_relationship_geom = trimmed_relationship_geom[1]
    end
    formatted_rel_geom = Dict("coordinates" => trimmed_relationship_geom, "type" => type) 
    # Calculate error for the new relationship geometry against the input feature geometry
    error = SpatialUtilities.MapMatching.e_polygon_area(trimmed_relationship_geom, input_feat_vector)[1]
    return trimmed_relationship_geom, formatted_rel_geom, error
end

"""recreate_individual_relationship(input_feat_vector::Vector{Vector{Float64}}, new_relation_vector::Vector{Vector{Float64}})

This function is the simplest method for calling the calculate_new_relationship function. 
An input feat vector and new_relationship vector are both provided and don't need to be
extracted from the database. 
"""
function recreate_individual_relationship(input_feat_vector::Vector{Vector{Float64}}, new_relation_vector::Vector{Vector{Float64}})
    trimmed_relationship_geom, formatted_rel_geom, error = calculate_new_relationship(input_feat_vector, new_relation_vector)
    return trimmed_relationship_geom, formatted_rel_geom, error
end

"""recreate_individual_relationship(input_feature_id::String, matched_feature_ids::Vector{String}, original_osm::Bool)

This function is the the most expensive method for calling the calculate_new_relationship function. 
An input feature_id and vector of matched_feature_ids are provided. The vectors required
are extracted from the database. 
"""
function recreate_individual_relationship(input_feature_id::String, matched_feature_ids::Vector{String}, original_osm::Bool)
    # Creates a variable sized 'items' which means feature_ids can be any length
    items = join(["\$$n" for n in 1:length(matched_feature_ids)], ", ")

    # Selects a multi-linestring or connected linestring from a list of OSM ways
    # ST_LineMerge will attempt to join linestrings end to end if possible
    if original_osm == true
        table = "mm_feature"
    else
        table = "mm_derived_feature"
    end
    select_new_relationship_geom = execute_psql_string(
    """select
    ST_AsGeoJSON(ST_LineMerge(ST_Collect((
    select array_agg(geom_feature)
    from map_manager.$table
    where feature_id in ($(items))
    and b_is_latest  
    ))))""", parameters=matched_feature_ids) 

    if !isempty(select_new_relationship_geom)
        new_relationship_geom = DataFrame(select_new_relationship_geom)[1,1]
    end

    new_relation_json_array = JSON3.read(new_relationship_geom)["coordinates"]
    new_relation_vector = copy(new_relation_json_array)

    # Select the input feature geometry
    select_input_feature_geom = PSQLInterface.execute_psql_string(
        """select ST_AsGeoJSON(geom_feature)
        from map_manager.$table
        where feature_id = \$1
        and b_is_latest;""", 
        parameters=[input_feature_id])

    if !isempty(select_input_feature_geom)
        input_feature_geom = DataFrame(select_input_feature_geom)[1,1]
    end
    input_feat_json_array = JSON3.read(input_feature_geom)["coordinates"]
    input_feat_vector = copy(input_feat_json_array)

    trimmed_relationship_geom, formatted_rel_geom, error = calculate_new_relationship(input_feat_vector, new_relation_vector)
    return trimmed_relationship_geom, formatted_rel_geom, error
end


"""recreate_individual_relationship(input_feat_vector::Vector{Vector{Float64}}, matched_feature_ids::Vector{String}, original_osm::Bool)

This function is a method for calling the calculate_new_relationship function. 
An input vector is provided, but a vector of matched_feature_ids must be extracted 
from the database. 
"""
function recreate_individual_relationship(input_feat_vector::Vector{Vector{Float64}}, matched_feature_ids::Vector{String}, original_osm::Bool)
    # Creates a variable sized 'items' which means feature_ids can be any length
    items = join(["\$$n" for n in 1:length(matched_feature_ids)], ", ")

    # Selects a multi-linestring or connected linestring from a list of OSM ways
    # ST_LineMerge will attempt to join linestrings end to end if possible
    if original_osm == true
        table = "mm_feature"
    else
        table = "mm_derived_feature"
    end

    select_new_relationship_geom = execute_psql_string(
    """select
    ST_AsGeoJSON(ST_LineMerge(ST_Collect((
    select array_agg(geom_feature)
    from map_manager.$table
    where feature_id in ($(items))
    and b_is_latest  
    ))))""", parameters=matched_feature_ids) 

    if !isempty(select_new_relationship_geom)
        new_relationship_geom = DataFrame(select_new_relationship_geom)[1,1]
    end

    new_relation_json_array = JSON3.read(new_relationship_geom)["coordinates"]
    new_relation_vector = copy(new_relation_json_array)

    trimmed_relationship_geom, formatted_rel_geom, error = calculate_new_relationship(input_feat_vector, new_relation_vector)
    return trimmed_relationship_geom, formatted_rel_geom, error
end


"""choose_best_match(metrics_dict::Dict)

This function takes in a dictionary for a specific multi-match, removes matches using specified thresholds and then makes a choice of which road to keep. 
It does this through assessing the angle, error and length of VicMap matches against a specific OSM way. 
Accepts metrics_dict as an input, which has "key": "road_name", and "value": Dict("median_error": int, "total_length": int, "median_angle_diff": int)
Outputs a filtered version of metrics_dict with only the 'chosen' road keys remaining. 
"""
function choose_best_match(metrics_dict::Dict, original_osm::Bool; max_allowed_angle_diff = 50, max_allowed_error = 25, min_allowed_length = 0.0025)
    # Find the minimum median_error, maximum total_length, and minimum median_angle_diff
    best_error = minimum([entry["median_error"] for entry in values(metrics_dict)])
    best_length = maximum([entry["total_length"] for entry in values(metrics_dict)])
    best_angle_diff = minimum([entry["median_angle_diff"] for entry in values(metrics_dict)])
    # Step 1: Remove matches not meeting thresholds: < 25 angle difference, < 25 m^2/m error, > 2.5m length
    # filtered_data = Dict(filter(kv -> kv[2]["median_angle_diff"] < max_allowed_angle_diff && kv[2]["median_error"] < max_allowed_error && kv[2]["total_length"] >= min_allowed_length, metrics_dict))
    # First remove all matches < 2.5m 
    filtered_data = Dict(filter(kv -> kv[2]["total_length"] > min_allowed_length, metrics_dict))
    
    # If there are no options left after filtering or only one option, return. 
    if isempty(filtered_data) || length(filtered_data) == 1
        return filtered_data
    end
    # Step 2: Keep legitimate matches - for original_osm only
    if original_osm == true
        legit_matches = Dict(filter(kv -> (kv[2]["median_angle_diff"] < 8 || kv[2]["median_angle_diff"] <= 1.2 * best_angle_diff) && 
                                        (kv[2]["median_error"] < 10 || kv[2]["median_error"] <= 1.5 * best_error) &&
                                        (kv[2]["total_length"] > 0.0025), filtered_data))
        if !isempty(legit_matches)
            return legit_matches
        end
    end

    # Step 3: Choose best match based on criteria
    theoretical_best_options = Dict(filter(kv -> kv[2]["total_length"] == best_length && 
                                                    kv[2]["median_error"] == best_error && 
                                                    kv[2]["median_angle_diff"] == best_angle_diff, filtered_data))
    if length(theoretical_best_options) == 1
        return theoretical_best_options
    end

    # We would like to force 1:1 matching for DTP matching. We're likely to have good matches with small overlaps
    # We can handle this by choosing the best length matching, while still forcing a certain quality of match 
    if original_osm == false
        best_length_match = Dict(filter(kv -> (kv[2]["median_angle_diff"] < 8 || kv[2]["median_angle_diff"] <= 1.2 * best_angle_diff) && 
        (kv[2]["median_error"] < 10 || kv[2]["median_error"] <= 1.5 * best_error) &&
        (kv[2]["total_length"] == best_length), filtered_data))

        if length(best_length_match) == 1
            return best_length_match
        end
    end
    
    # Step 4: Choose good angle and good error option
    low_angle_error_option = Dict(filter(kv -> kv[2]["median_angle_diff"] == best_angle_diff && kv[2]["median_error"] == best_error, filtered_data))
    if length(low_angle_error_option) == 1
        return low_angle_error_option
    end

    # Step 5: Choose close option
    low_error_high_length_option = Dict(filter(kv -> kv[2]["median_error"] == best_error && kv[2]["total_length"] == best_length &&
                                            (kv[2]["median_angle_diff"] < 10 || kv[2]["median_angle_diff"] < 1.2 * best_angle_diff), filtered_data))
    if length(low_error_high_length_option) == 1
        return low_error_high_length_option
    end

    # Step 6: Choose good angle option
    low_angle_high_length_option = Dict(filter(kv -> kv[2]["median_angle_diff"] == best_angle_diff && kv[2]["total_length"] == best_length &&
                                                (kv[2]["median_error"] < 10 || kv[2]["median_error"] <= 1.5 * best_error), filtered_data))
    if length(low_angle_high_length_option) == 1
        return low_angle_high_length_option
    end
    
    # Filter again - more aggressively to remove matches if they are genuinely poor matches. 
    filtered_data = Dict(filter(kv -> kv[2]["median_angle_diff"] < max_allowed_angle_diff && kv[2]["median_error"] < max_allowed_error, metrics_dict))
    
    # If there are no options left after filtering or only one option, return. 
    if isempty(filtered_data) || length(filtered_data) == 1
        return filtered_data
    end
    # Step 7: Choose the longest length option
    longest_length_option = Dict(filter(kv -> kv[2]["total_length"] == best_length, filtered_data))
    if length(longest_length_option) == 1
        return longest_length_option
    end

    # Step 7: Choose the best error option
    smallest_error_option = Dict(filter(kv -> kv[2]["median_error"] == best_error, filtered_data))
    if length(smallest_error_option) == 1
        return smallest_error_option
    end

    # Provide an empty dictionary if no conditions are satisfied
    empty_dict = Dict()
    return empty_dict
end