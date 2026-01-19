"""
    e_polygon_area(ls1::Vector{Vector{Float64}}, 
                   ls2::Vector{Vector{Float64}}
                   )::Tuple{Float64, Float64, Float64}

Calculate the polygon area error metric between two linestrings. This is a value that aims 
to indicate how good a match is. 

# Arguments
- `ls1, ls2`: Linestrings to compare

# Keyword arguments
- `e_polygon_area_threshold::Float64=10.0`: Threshold for displaying polygon area error 
    metric graphs. Will not affect the error metric output itself.

# Returns
- `::Tuple`
    - `::Float64`: Polygon area metric normalised by length, in m^2/m.
    - `::Float64`: Total polygon area, in m^2.
    - `::Float64`: Shortest linestring length, in m.
"""
function e_polygon_area(ls1::Vector{Vector{Float64}}, 
                        ls2::Vector{Vector{Float64}}
                        )::Tuple{Float64, Float64, Float64}
    # Distance value for normalisation. Choose the average value to avoid bias towards shorter or longer matches.
    d1 = SpatialUtilities.lstring_distance(ls1)
    d2 = SpatialUtilities.lstring_distance(ls2)
    d = ((d1+d2)/2) * 1000  # Convert from km to m

    polygon = vcat(ls1, reverse(ls2), [ls1[1]])
    area = calculate_area_2d_polygon_geo(polygon)
    return area / d, area, d
end

"""
    e_polygon_area(input_ls::Vector{Vector{Float64}}, 
                   multi_ls::Vector{Vector{Vector{Float64}}}
                   )::Tuple{Float64, Float64, Float64}

Calculate the polygon area error metric between two linestrings. This is a value that aims 
to indicate how good a match is. 

# Arguments
- `input_ls`: Input linestring to compare
- `multi_ls`: Input multi-linestrings to compare to

# Keyword arguments
- `e_polygon_area_threshold::Float64=10.0`: Threshold for displaying polygon area error 
    metric graphs. Will not affect the error metric output itself.

# Returns
- `::Tuple`
    - `::Float64`: Polygon area metric normalised by length, in m^2/m.
    - `::Float64`: Total polygon area, in m^2.
    - `::Float64`: Shortest linestring length, in m.
"""
function e_polygon_area(multi_ls::Vector{Vector{Vector{Float64}}}, 
                        input_ls::Vector{Vector{Float64}})::Tuple{Float64, Float64, Float64}
# Distance value for normalisation. Choose the shortest value so it doesn't bias 
# shorter or longer matches.
d1 = SpatialUtilities.lstring_distance(input_ls) # Distance value for normalisation. 
# Use the input feature length since all should be normalised by this length.
d = d1 * 1000  # Convert from km to m
individual_polygons = Vector{Any}(undef, length(multi_ls))  # Create empty polygon array

# For all lineStrings contained in multiVector, create a polygon with the input linestring and store in polygon
for i in eachindex(multi_ls)
individual_polygons[i] = vcat(input_ls, reverse(multi_ls[i]), [input_ls[1]])
end
# Create empty combined polygon variable
# For all polygons stored in polygon, union into a single 'combined_polygon'
area = zeros(Float64, length(individual_polygons))
for i in 1:length(individual_polygons)
area[i] = calculate_area_2d_polygon_geo(individual_polygons[i])
end
avg_area = sum(area)/length(area)
# Calculate area of combined_polygon
return avg_area / d, avg_area, d
end

"""
    print_error_metrics(errors::Vector{Float64}, 
                        total_features::Int64, 
                        total_matched::Int64,
                        average_error::Float64;
                        e_polygon_area_threshold::Float64=10.0
                        )

# Arguments
- `errors::Vector{Float64}`: All error values for all features.
- `total_features::Int64`: Total number of features.
- `total_matched::Int64`: Number of features with a successful match.
- `average_error::Float64`: Weighted average error across all features.

# Keyword arguments
- `e_polygon_area_threshold::Float64=10.0`: Threshold for displaying polygon area error 
    metric graphs. Will not affect the error metric output itself.
"""
function print_error_metrics(errors::Vector{Float64}, 
                             total_features::Int64, 
                             total_matched::Int64,
                             average_error::Float64;
                             e_polygon_area_threshold::Float64=10.0
                             )
    # Plot a bit more than the cutoff value
    plot_cutoff = round(e_polygon_area_threshold * 3, digits=2)
    to_plot = errors .<= plot_cutoff

    percent_matched = round(
        total_matched / total_features * 100,
        digits=2
    )
    count_threshold = count(errors .< e_polygon_area_threshold)
    percent_threshold = round(
        count_threshold / total_matched * 100, 
        digits=2
    )

    @info """
    Error metrics:
    $total_matched out of $total_features features successfully matched ($percent_matched%).
    The average error across all features is $average_error m^2/m.
    $count_threshold out of $total_matched matched features are below the threshold $e_polygon_area_threshold m^2/m ($percent_threshold%).
    """
    # Sometimes histograms don't work, make sure it fails gracefully
    try
        println(
            histogram(errors[to_plot], nbins=15),
            "\n...$(count(.!to_plot)) more features with error >$plot_cutoff."
        )
    catch err
        @warn "Error plotting histogram, skipping. Error was: $err" # exception=(err, catch_backtrace())
    end
end

"""
    calculate_error_geojson!(geoj::AbstractDict)

Calculate map matching error metrics for all features in a GeoJSON. Adds all of them to 

# Keyword arguments
- `e_polygon_area_threshold::Float64=10.0`: Threshold for displaying polygon area error 
    metric graphs. Will not affect the error metric output itself.
- `output_progress::Bool=true`: Whether to output progress messages.
"""
function calculate_error_geojson!(geoj::AbstractDict;
                                  e_polygon_area_threshold::Float64=10.0,
                                  output_progress::Bool=true
                                  )
    # Init
    total_features = length(geoj["features"])
    total_matched = zero(Int64)
    total_area = zero(Float64)
    total_length = zero(Float64)
    errors = Float64[]
    # Calculate error for each feature
    for (i, f) in enumerate(geoj["features"])
        id = get(f, "id", "")
        id_string = isempty(id) ? "" : " (id=$id)"
        if f["geometry"]["type"] != "LineString" && f["geometry"]["type"] != "MultiLineString"
            @warn "Cannot generate error for non-LineString type: $(f["geometry"]["type"])$id_string\n    Setting error to missing"
            f["properties"]["mapmatching_error"] = missing
            continue
        end
        if output_progress
            @info "Calculating error $i out of $(length(geoj["features"]))$id_string...."
        end

        # Get geometry
        ls1 = f["geometry"]["coordinates"]
        isempty(ls1) && continue
        ls2 = f["properties"]["mapmatching_sourcegeom"]
        
        # Calculate error and add to GeoJSON
        error, area, len = e_polygon_area(ls1, ls2)
        f["properties"]["mapmatching_error"] = error

        # Stats
        total_matched += 1
        total_area += area
        total_length += len
        push!(errors, error)
    end

    # Calculate average overall error
    average_error = round(
        total_area / total_length,
        digits=2
    )

    print_error_metrics(
        errors, 
        total_features, 
        total_matched, 
        average_error, 
        e_polygon_area_threshold=e_polygon_area_threshold
    )

    return geoj
end

function calculate_error_geojson!(input_file::String, output_file::String; e_polygon_area_threshold::Float64=10.0)
    #open a file called geoj and read it into an AbstractDict
    geoj = open(input_file) do f
        JSON3.read(f, Dict)
    end
    @info "Opened file $input_file, beginning error calculation..."
    errored_geoj = calculate_error_geojson!(geoj::AbstractDict; e_polygon_area_threshold)
    @info "Writing result to file $output_file..."
    open(output_file, "w") do f
        JSON3.write(f, errored_geoj)
    end
end
