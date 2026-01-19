"""
    match_geojson_linestrings(g::OSMGraph,
                              geoj::AbstractDict,
                              rtree::Union{Nothing,RTree}=nothing;
                              id_property::Union{Nothing,AbstractString}=nothing,
                              output_progress::Bool=true,
                              kwargs...
                              )
    match_geojson_linestrings(g::OSMGraph,
                              input_file::AbstractString,
                              output_file::AbstractString,
                              rtree::Union{Nothing,RTree}=nothing;
                              id_property::Union{Nothing,AbstractString}=nothing,
                              output_progress::Bool=true,
                              kwargs...
                              )

Matches all linestrings in a GeoJSON `FeatureCollection` to an OpenStreetMap 
road network. All `Feature`s must be `LineString`s.

# Arguments
- `g::OSMGraph`: LightOSM graph.
- `geoj::AbstractDict`: GeoJSON object to read.
- `input_file::AbstractString`: GeoJSON file to read.
- `output_file::AbstractString`: Where to output the resulting matches to 
  GeoJSON.
- `rtree::Union{Nothing,RTree}=nothing`: R-tree to use. Will auto-generate if 
  not supplied.
- `output_progress::Bool=true`: Whether to print matching progress.
- `multils_handling::Symbol=:concatenate`: How to handle `MultiLineString`s:
    - `:concatenate`: Concatenate the constituent parts into a single `LineString`.
    - `:split`: Split the constituent parts into separate `LineString`s.
- `calculate_error::Bool=true`: Calculate polygon error metric 
- `e_polygon_area_threshold::Float64=10.0`: Threshold for displaying polygon area error 
    metric graphs. Will not affect the error metric output itself.
- `kwargs...`: Any arguments to pass to `match_linestring`.

# Returns
- `::Dict{String,Any}`: Matched GeoJSON if `output_file` was not provided. Geometry 
    coordinates will be replaced with the matched geometry, or empty if matching failed.
    Features will have the following additional properties if matched successfully:
    - `mapmatching_sourcegeom`: The original geometry of the feature.
    - `mapmatching_error`: Error metric value for this feature.
    - `matched_nodes`: OSM node IDs of the matched path.
    - `matched_ways`: OSM way IDs of the matched path.
    - `offset_start`: Offset of the start of the matched path from the first way in metres.
    - `offset_end`: Offset of the end of the matched path from the last way in metres.
- `Nothing`: If writing GeoJSON to file.
"""
function match_geojson_linestrings(g::OSMGraph,
    geoj::AbstractDict,
    rtree::Union{Nothing,RTree}=nothing;
    output_progress::Bool=true,
    multils_handling::Symbol=:concatenate,
    calculate_error::Bool=true,
    is_vicmap_source::Bool=true,
    e_polygon_area_threshold::Float64=10.0,
    kwargs...
    )
    # Generate R-tree
    if isnothing(rtree)
        output_progress && @info "Constructing R-tree of OSM graph..."
        rtree = construct_rtree(g)
    end

    # Fix MultiLineStrings
    n = length(geoj["features"])
    fix_count = 0
    for f in geoj["features"]
        ls = f["geometry"]["coordinates"]
        # MultiLineString handling
        # TODO: move handling into functions and test them
        if f["geometry"]["type"] == "MultiLineString"
            fix_count += 1
            if multils_handling == :concatenate
                # Current feature is replaced by concatenated linestrings
                ls = vcat(ls...)
            elseif multils_handling == :split
                if length(ls) > 1
                    # Append new features
                    for (idx, ls_part) in enumerate(ls)
                        idx == 1 && continue  # The current `f` will use `ls[1]`
                        f_new = deepcopy(f)
                        f_new["geometry"]["type"] = "LineString"
                        f_new["geometry"]["coordinates"] = ls_part
                        push!(geoj["features"], f_new)
                    end
                end
                # Current feature is replaced by first linestring section
                ls = ls[1]
            else
                msg = "multils_handling=$multils_handling is unsupported in match_geojson_linestrings!"
                @error msg
                throw(SpatialUtilities.SpatialUtilitiesException(msg))
            end
        # Bad geometry type
        elseif f["geometry"]["type"] != "LineString"
            @debug "Skipping unsupported geometry type $(feature["geometry"]["type"])"
            # Notice is given later that it will be skipped, no need to double up
            continue
        end

        # Write new linestring back to geometry
        f["geometry"]["type"] = "LineString"
        f["geometry"]["coordinates"] = Vector{Float64}.(ls)  # Enforce types
    end
    (fix_count > 0) && (@warn "Performed $multils_handling on $fix_count features")

   
    # Set up dictionary to record each OSM&&WAY match set 
    osm_dict = Dict{String, Dict}()
    # Do the matching for all features and assign the direction code
    @time for (i, f) in enumerate(geoj["features"])
        id = get(f, "id", "")
        id_string = isempty(id) ? "" : " (id=$id)"

        if f["geometry"]["type"] != "LineString"
            @warn "Skipping unsupported geometry type $(f["geometry"]["type"])$id_string"
            continue
        end
        # Progress output
        if output_progress
            @info "Matching $i out of $(length(geoj["features"]))$id_string...."
        end

        # Extract source geometry,
        ls = f["geometry"]["coordinates"]
        ls = Vector{Float64}.(ls)  # Enforce types

        # Save source geometry in a property
        merge!(f["properties"], Dict(
            "mapmatching_sourcegeom" => ls
        ))

        # Run the mapmatch for this feature
        mapmatch = match_linestring(g, ls, rtree; source_id=id, kwargs...)

        # Failed condition - no path found or only a single coordinate
        if isnothing(mapmatch) || (length(mapmatch.matched_path) <= 1)
            f["geometry"]["coordinates"] = []
            merge!(f["properties"], Dict(
                "mapmatching_error" => "Failed to find path"
            ))
            continue
        end
    
        # Modify GeoJSON with original matched data
        f["geometry"]["coordinates"] = geoloc_to_coords(mapmatch.matched_path)
        merge!(f["properties"], Dict(
            "matched_nodes" => mapmatch.matched_nodes,
            "matched_ways" => mapmatch.matched_ways,
            "offset_start" => mapmatch.offset_start,
            "offset_end" => mapmatch.offset_end
        ))

        # If this is the vicmap dataset which is to be post-processed, we retrieve direction_code and road_name and do dual carriageway matching
        if is_vicmap_source == true
            # Retrieve direction code and road name
            direction_code = get(f,"direction_code","")
            road_name = get(f, "road_name","")
            # Assign empty oneway list
            oneway_list = []
            matched_way_ids = mapmatch.matched_ways

            # Retrieve the 'oneway' status of the matched osm ways as either true of false
            for way_id in matched_way_ids
                is_oneway = get(g.ways[way_id].tags, "oneway", false)
                push!(oneway_list,is_oneway)
            end

            # Check for features where direction code is B and the with OSM way that has been matched is oneway
            if direction_code == "B" && isnothing(mapmatch) == false && any(oneway_list)
                # If any of the ways in the oneway list are 'true' i.e. the way is oneway, run this code
                @info "One way road found for ls = $ls, rerunning map match with reversed geometry"
                # Reverse the coordinates for this linestring
                rev_ls = reverse(ls)
                # Rerun mapmatching - this should hopefully find the other side of the road
                mapmatch_rev = match_linestring(g, rev_ls, rtree; source_id=id, kwargs...)
                # It's possible this yields no results, which indicates that either the 'B' or 'oneway' attribute is wrong 
                # If so, continue
                if isnothing(mapmatch_rev) == false && (length(mapmatch_rev.matched_path) >= 1)
                    # Join the unique ways and unique nodes that were matched to original results
                    # Also add the geometry for both matches together as a multilinestring
                    matched_ways_joined = unique(vcat(mapmatch.matched_ways, mapmatch_rev.matched_ways))
                    matched_nodes_joined = unique(vcat(mapmatch.matched_nodes, mapmatch_rev.matched_nodes))
                    matched_path_joined = [geoloc_to_coords(mapmatch.matched_path), geoloc_to_coords(mapmatch_rev.matched_path)]
                    #Modify GeoJSON with matched data
                    f["geometry"]["type"] = "MultiLineString"
                    f["geometry"]["coordinates"] = matched_path_joined
                    merge!(f["properties"], Dict(
                        "matched_nodes" => matched_nodes_joined,
                        "matched_ways" => matched_ways_joined,
                        "offset_start" => mapmatch.offset_start,
                        "offset_end" => mapmatch.offset_end
                    ))
                end
            end
        end

        # If a match was formed we'll record this in the OSM dictionary for Post-Processing
        if haskey(f["properties"], "matched_ways")
            # Get the values from the current dictionary
            matched_ways_ids = f["properties"]["matched_ways"]
            # matched_ways_ids = ["OSM&&WAY$way_id" for way_id in matched_ways]
            id = f["id"]
            
            # If the source if VICMAP, we will store road names for road name specific post processing
            if is_vicmap_source == true
                road_name = f["road_name"]
                # Update or create the entry for each item in "matched_ways" including 'road name' for VicMap post-processing
                for way_key in matched_ways_ids
                    # Initialize the entry if not present
                    if !haskey(osm_dict, way_key)
                        osm_dict[way_key] = Dict("road_names" => [road_name], "input_source_linestrings" => [id], "individual_lengths" => Float64[])
                    else
                        # Update existing entry
                        entry = osm_dict[way_key]
                        push!(entry["road_names"], road_name)
                        push!(entry["input_source_linestrings"], id)
                        osm_dict[way_key] = entry
                    end
                end
            # Otherwise, create the general entry for each item in "matched_ways" for 1:1 match post-processing 
            else
                for way_key in matched_ways_ids
                    # Initialize the entry if not present
                    if !haskey(osm_dict, way_key)
                        osm_dict[way_key] = Dict("input_source_linestrings" => [id], "individual_lengths" => Float64[])
                    # Else update existing entry
                    else
                        entry = osm_dict[way_key]
                        push!(entry["input_source_linestrings"], id)
                        osm_dict[way_key] = entry
                    end
                end
            end
        end
    end

calculate_error && @time calculate_error_geojson!(geoj, e_polygon_area_threshold=e_polygon_area_threshold, output_progress=output_progress)
return geoj, osm_dict
end


function match_geojson_linestrings(g::OSMGraph,
                                   input_file::AbstractString,
                                   output_file::AbstractString,
                                   rtree::Union{Nothing,RTree}=nothing;
                                   output_progress::Bool=true,
                                   kwargs...
                                   )
    if input_file == output_file
        error("input_file and output_file are them same, this will overwrite the original file!")
    end

    # Load GeoJSON
    output_progress && @info "Loading $input_file..."
    JSON3.read(open(input_file, "r"), Dict)

    geoj = match_geojson_linestrings(g, geoj, rtree; output_progress=output_progress, kwargs...)

    # Save GeoJSON
    output_progress && @info "Writing result to file $output_file..."
    JSON3.write(output_file, geoj)
end

"""
    geojson_feature(properties::Dict{String,Any}, 
                    type::String, 
                    coords::Vector
                    )

Creates a GeoJSON `Feature` as a `Dict`.

# Arguments
- `properties::Dict{String,Any}`: `Feature` properties.
- `type::String`: `geometry` type.
- `coords::Vector`: `geometry` coordinates.

# Returns
- `::Dict{String,Any}`: A GeoJSON `Feature`.
"""
function geojson_feature(properties::Dict{String,Any}, 
                         type::String, 
                         coords::Vector
                         )
    return Dict{String,Any}(
        "type" => "Feature",
        "properties" => properties,
        "geometry" => Dict{String,Any}(
            "type" => type,
            "coordinates" => coords
        )
    )
end

"""
    to_geojson(g::OSMGraph, 
               hmm_g::HMMGraph, 
               [filename::AbstractString; 
               ls::Union{Nothing,AbstractVector{<:GeoLocation}}=nothing]
               )

For debugging. Outputs a `HMMGraph` to GeoJSON including states, emission and 
transition costs, and distances.

# Arguments
- `g::OSMGraph`: LightOSM graph.
- `hmm_g::HMMGraph`: HMM graph.
- `filename::AbstractString` (optional): Output location for GeoJSON. Omit this 
  argument to return as `Dict` instead.
- `ls::Union{Nothing,AbstractVector{<:GeoLocation}}=nothing`: Source linestring 
  to add to GeoJSON file, if desired.

# Returns
- `::Dict{String,Any}`: If `filename` was not provided.
- `::Nothing`: If writing to file.
"""
function to_geojson(g::OSMGraph, 
                    hmm_g::HMMGraph; 
                    ls::Union{Nothing,AbstractVector{<:GeoLocation}}=nothing
                    )
    features = Dict{String,Any}[]

    if !isnothing(ls)
        push!(features, geojson_feature(
            Dict{String,Any}(
                "type" => "input"
            ),
            "LineString",
            geoloc_to_coords(ls)
        ))
    end

    for (trellis_pos, states) in enumerate(hmm_g.trellis)
        for u in states
            state = hmm_g.states[u]
            coords = geoloc_to_coords(location(g, state.osm_point))
            emission_cost = prob_to_cost(emission_prob(state))
            (emission_cost == Inf) && (emission_cost = nothing)

            push!(features, geojson_feature(
                Dict{String,Any}(
                    "type" => "state",
                    "cost" => emission_cost,
                    "u" => u,
                    "timestep" => trellis_pos
                ),
                "Point",
                coords
            ))

            push!(features, geojson_feature(
                Dict{String,Any}(
                    "type" => "distance",
                    "distance" => state.dist,
                    "u" => u,
                    "timestep" => trellis_pos
                ),
                "LineString",
                [coords, geoloc_to_coords(state.source_point)]
            ))

            for v in outneighbors(hmm_g.graph, u)
                transition_cost = prob_to_cost(transition_prob(g, hmm_g, u, v))
                (transition_cost == Inf) && (transition_cost = nothing)

                push!(features, geojson_feature(
                    Dict{String,Any}(
                        "type" => "transition",
                        "cost" => transition_cost,
                        "u" => u,
                        "v" => v,
                        "timestep" => trellis_pos
                    ),
                    "LineString",
                    [coords, geoloc_to_coords(location(g, hmm_g.states[v].osm_point))]
                ))
            end
        end
    end

    geoj = Dict{String,Any}(
        "type" => "FeatureCollection",
        "features" => features
    )
    return geoj
end

function to_geojson(g::OSMGraph, 
                    hmm_g::HMMGraph, 
                    filename::AbstractString; 
                    kwargs...
                    )
    geoj = to_geojson(g, hmm_g; kwargs...)
    JSON3.write(filename, geoj)
end

"""
    to_geojson(g::OSMGraph, 
               m::MapMatch, 
               [filename::AbstractString; 
               kwargs...]
               )
For debugging. Outputs a `MapMatch` to GeoJSON including mapped nodes, mapped 
ways, mapped path, and source geometry.

# Arguments
- `g::OSMGraph`: LightOSM graph.
- `m::MapMatch`: HMM graph.
- `filename::AbstractString` (optional): Output location for GeoJSON. Omit this 
  argument to return as `Dict` instead.
- `ls::Union{Nothing,AbstractVector{<:GeoLocation}}=nothing`: Source linestring 
  to add to GeoJSON file, if desired.

# Returns
- `::Dict{String,Any}`: If `filename` was not provided.
- `::Nothing`: If writing to file.
"""
function to_geojson(g::OSMGraph, m::MapMatch; kwargs...)
    features = Dict{String,Any}[]

    # Mapped ways
    for (i, wid) in enumerate(m.matched_ways)
        push!(features, geojson_feature(
            Dict{String,Any}(
                "type" => "matched way",
                "way_id" => wid,
                "sequence" => i
            ),
            "LineString",
            geoloc_to_coords([g.nodes[nid].location for nid in g.ways[wid].nodes])
        ))
    end

    # Mapped nodes
    for (i, nid) in enumerate(m.matched_nodes)
        push!(features, geojson_feature(
            Dict{String,Any}(
                "type" => "matched node",
                "node_id" => nid,
                "sequence" => i
            ),
            "Point",
            geoloc_to_coords(g.nodes[nid].location)
        ))
    end

    # Source geometry
    push!(features, geojson_feature(
        Dict{String,Any}(
            "type" => "source geometry",
            "source_id" => m.source_id,
            m.meta...
        ),
        "LineString",
        geoloc_to_coords(m.source_geom)
    ))

    # Mapped line
    push!(features, geojson_feature(
        Dict{String,Any}(
            "type" => "matched path",
            "source_id" => m.source_id,
            "offset_start" => m.offset_start,
            "offset_end" => m.offset_end,
            m.meta...
        ),
        "LineString",
        geoloc_to_coords(m.matched_path)
    ))

    geoj = Dict{String,Any}(
        "type" => "FeatureCollection",
        "features" => features
    )
    return geoj
end
function to_geojson(g::OSMGraph, m::MapMatch, filename::AbstractString; kwargs...)
    geoj = to_geojson(g, m; kwargs...)
    JSON3.write(filename, geoj)
end
