# Line/corridor/path merging utilities

# Global variables
const DEFAULT_LINE_MERGE_BUFFER = 0.00001;
const DEFAULT_LINE_MERGE_IGNORE_BRANCHES = true;
const DEFAULT_LINE_MERGE_AREA_RATIO_THRESHOLD = 0.001;
const DEFAULT_DIFFERENCE_BUFFER_RATIO = 1/2

"Internal function (DO NOT USE)"
function _up_nmin!(a, n, min_vals, min_idxs)
    @inbounds for (idx, val) in pairs(a)
        if val < min_vals[n]
            i = searchsortedfirst(min_vals, val)
            for j = n:-1:i+1
                min_vals[j] = min_vals[j-1]
                min_idxs[j] = min_idxs[j-1]
            end
            min_vals[i] = val
            min_idxs[i] = idx
        end
    end
    return nothing
end

"""
    nmin(a::AbstractArray{T,N}, n::Integer) where {T,N}

Find indices of N lowest values in an array. Function is sourced from
https://discourse.julialang.org/t/find-n-smallest-values-in-an-n-dims-array/81092/7

# Arguments
- `a::AbstractArray{T,N}`: Input array
- `n::Integer`: Number of minimum elements to find

# Returns
- `::Array{CartesianIndex, 1}`: Vector of CartesianIndex for N minimum values in the array
"""
function nmin(a::AbstractArray{T,N}, n::Integer) where {T,N}
    min_vals = [typemax(T) for _ in 1:n]
    min_idxs = Vector{CartesianIndex{N}}(undef, n)
    _up_nmin!(a, n, min_vals, min_idxs)
    return min_idxs, min_vals
end

"""
This file adds line based helper functions to the library.
"""

"""
    get_line_wkt(x_values::AbstractArray{<:Real}, y_values::AbstractArray{<:Real})::String

Create a WKT linestring from a set of points (x,y) provided in a ordered sequence.

# Arguments
- `x_values::AbstractArray{<:Real}`: X coordinates on the line
- `y_values::AbstractArray{<:Real}`: X coordinates on the line

# Returns
- `::String`: WKT linestring
"""
function get_line_wkt(x_values::AbstractArray{<:Real}, y_values::AbstractArray{<:Real})::String

    if length(x_values) != length(y_values)
        @error "GET WKT LINE: input vector length does not match - $(length(x_values)) != $(length(y_values))"
        throw(ArgumentError("Vector length does not match: $(length(x_values)) != $(length(y_values))"))
    end
    return "LINESTRING(" * join(["$(val[1]) $(val[2])" for val in zip(x_values, y_values)], ", ") * ")"
end

function get_line_wkt(input_array::AbstractArray{<:Real,2})

    if size(input_array, 1) !== 2 && size(input_array, 2) !== 2
        @error "GET WKT LINE: bad input array size '$(size(input_array))'"
        throw(ArgumentError("bad input array size '$(size(input_array))'"))
    end

    if size(input_array, 2) > size(input_array, 1)
        return get_line_wkt(input_array[1, :], input_array[2, :])
    end
    return get_line_wkt(input_array[:, 1], input_array[:, 2])
end

"""
    merge_lines(
        lines::Vector{Vector{Vector{T}}};
        line_buffer::Number=DEFAULT_LINE_MERGE_BUFFER,
        ignore_branches::Bool=DEFAULT_LINE_MERGE_IGNORE_BRANCHES
    )::Vector{Vector{T}} where {T<:Real}

Merge multiple lines into a single line. Assumptions include:
- points are 2D
- Euclidean distance is used where distance is required
- Longest line is used as the base line
- Branches are not supported
- If algorithm cannot identify whether a line is a branch or extension, the function will throw

# Arguments
- `lines::Vector{Vector{Vector{T}}}`: Vector of lines (see example for possible inputs)
- `line_buffer::Real`: The buffer used to create the line polygon to avoid in the merged line.
- `ignore_branches::Bool`: Throw if set to `false` and a branch is found.
- `area_ratio_threshold::Real`: Area ratio threshold to decide if a line should be merged into base_line.
- `difference_buffer_multiplier::Real`: Buffer multiplier for the difference ploygon used to find points to add to the base line.

# Returns
- `::Vector{Vector{<:Real}}`: Vector of X and Y vectors for the line

## Example Input:
```julia-repl
julia> lines = [[[x1, x2, x3], [y1, y2, y3]], [[x1', x2'], [y1', y2']]]
```
"""
function merge_lines(
    lines::Vector{Vector{Vector{T}}};
    line_buffer::Real=DEFAULT_LINE_MERGE_BUFFER,
    ignore_branches::Bool=DEFAULT_LINE_MERGE_IGNORE_BRANCHES,
    area_ratio_threshold::Real=DEFAULT_LINE_MERGE_AREA_RATIO_THRESHOLD,
    difference_buffer_multiplier::Real=DEFAULT_DIFFERENCE_BUFFER_RATIO
)::Vector{Vector{Float64}} where {T<:Real}
    # error immediately if there are no lines provided
    if length(lines) == 0 || length(lines[1]) == 0 || length(lines[1][1]) == 0
        throw(ArgumentError("No lines provided to the merge function"))
    end

    # return the main line provided with a soft warning
    if length(lines[1]) == 1
        @warn "Requested to merge a line with only one segment"
        return lines[1]
    end

    # Sort lines by length
    ordered_lines = sort(lines, by=x -> get_line_length(x[1], x[2]), rev=true)

    # form the base line - this will be mutated in the algorithm
    base_line = ordered_lines[1] # vector_x, vector_y
    base_line_string = LibGEOS.geomFromGEOS(
        LibGEOS.createLineString([Vector{Float64}([base_line[1][i], base_line[2][i]]) for (i, _) in enumerate(base_line[1])])
    )
    base_line_buffered = bufferWithStyle(base_line_string, line_buffer, endCapStyle=LibGEOS.GEOSBUF_CAP_ROUND)

    for next_line in ordered_lines[2:end]
        next_linestring = LibGEOS.geomFromGEOS(
            LibGEOS.createLineString([Vector{Float64}([next_line[1][i], next_line[2][i]]) for (i, _) in enumerate(next_line[1])])
        )

        # Intersect - make sure there is some intersection between the two polygons else they are
        # not joined and we should not merge them
        has_intersection = intersects(buffer(next_linestring, line_buffer), base_line_buffered)
        if !has_intersection
            @info "No intersection found between the two lines so they can't be merged"
            continue;
        end

        # Difference - use a buffered base line
        diff_polygon = difference(next_linestring, base_line_buffered)

        # since we use polygons, it is possible that there could be multiple polygon geometries returned
        # getGeometries handles single or multiple geometries
        @debug "Number of diff geometries found: $(numGeometries(diff_polygon))"
        diff_geoms = getGeometries(diff_polygon)
        for diff_geom in diff_geoms
            diff_polygon_buffered = bufferWithStyle(
                diff_geom,
                line_buffer * difference_buffer_multiplier,
                endCapStyle=LibGEOS.GEOSBUF_CAP_ROUND
            )

            # get difference in area between the base line and the compared line.
            base_line_area = LibGEOS.area(base_line_buffered)
            diff_area = LibGEOS.area(diff_polygon_buffered)

            # TODO - I think this is not a very god metric. Also it needs a hardcoded threshold. Need to find a better metric.
            # Decide if we should add this new geometry to the base linestring
            if diff_area / base_line_area < area_ratio_threshold
                @debug "Data variance found of only '$(diff_area / base_line_area)' with threshold '$(area_ratio_threshold)'. Skipping..."
                continue
            end

            @debug "Ratio of difference area to longest line area: $(diff_area/base_line_area)"

            # This could be slow for extremely large polygons.
            # Find out the data points that belong inside the difference polygon
            in_bounds_index = filter(
                x -> intersects(diff_polygon_buffered, readgeom("POINT($(next_line[1][x]) $(next_line[2][x]))")),
                [index for (index, _) in enumerate(next_line[1])]
            )
            in_bounds_data = [next_line[1][in_bounds_index], next_line[2][in_bounds_index]]

            # For those minute buffered polygons generated as a result of diffing two areas.
            if isempty(in_bounds_index)
                @debug "Nothing found in bounds. Continuing..."
                continue
            end

            # Find out which end to add this new data to. It could be a branch as well in which case return nothing
            # Get the distance between each point on the base line (M) and in_bounds_data (N). This will give a
            # matrix that we can then use to find the index of the closest point
            # NOTE - this is very fast but has data size limitations.
            # TODO - if we have long distances, we might want to investigate using LighOSM.distance here to
            # calculate the real distances. See link below.
            # `https://deloitteoptimalreality.github.io/LightOSM.jl/docs/geolocation/#LightOSM.distance`
            distance_between_points = sqrt.(
                (base_line[1]' .- in_bounds_data[1]) .^ 2 .+
                (base_line[2]' .- in_bounds_data[2]) .^ 2
            )

            closest_points = nmin(distance_between_points, 2)
            nearest_index = closest_points[1][1]
            if distance_between_points[closest_points[1][1]] == distance_between_points[closest_points[1][2]]
                # TODO - there are ways we can determine if this is a branch or an extension but that
                # is out of scope for DOTOR-14655
                @error "Cannot determine whether line is a branch or extension! Continuing..."
                continue;
            elseif distance_between_points[closest_points[1][1]] > distance_between_points[closest_points[1][2]]
                nearest_index = closest_points[1][2]
            end

            # nearest_index[1] == in_bounds_index
            # nearest_index[2] == base_line index
            if !(nearest_index[1] in [1, length(in_bounds_data[1])]) || !(nearest_index[2] in [1, length(base_line[1])])
                @debug "Looks like the line branches out from the base line. Skipping..."
                if !ignore_branches
                    throw(ArgumentError("Cannot merge lines due to  a branch found!"))
                end
                continue
            end

            @debug "Found '$(length(in_bounds_data[1]))' rows to add to the base line."

            # now we know that the line is appended to the front or end
            if nearest_index[2] == 1
                @debug "Appending the data to the start"
                if nearest_index[1] == length(in_bounds_data[1])
                    base_line[1] = vcat(in_bounds_data[1], base_line[1])
                    base_line[2] = vcat(in_bounds_data[2], base_line[2])
                else
                    @debug "Appended data direction is reversed"
                    base_line[1] = vcat(reverse(in_bounds_data[1]), base_line[1])
                    base_line[2] = vcat(reverse(in_bounds_data[2]), base_line[2])
                end
            else
                @debug "Appending the data to the end"
                if nearest_index[1] == 1
                    base_line[1] = vcat(base_line[1], in_bounds_data[1])
                    base_line[2] = vcat(base_line[2], in_bounds_data[2])
                else
                    @debug "Appended data direction is reversed"
                    base_line[1] = vcat(base_line[1], reverse(in_bounds_data[1]))
                    base_line[2] = vcat(base_line[2], reverse(in_bounds_data[2]))
                end
            end
            # Remove duplicates - this is important due to exposing `difference_buffer_multiplier`
            base_line_duplicates = [0; [r[1] == 0 && r[2] == 0 for r in zip(diff(vec(base_line[1])), diff(vec(base_line[2])))]]
            base_line[1] = base_line[1][base_line_duplicates .== 0]
            base_line[2] = base_line[2][base_line_duplicates .== 0]
        end

        base_line_string = LibGEOS.geomFromGEOS(
            LibGEOS.createLineString([Vector{Float64}([base_line[1][i], base_line[2][i]]) for (i, _) in enumerate(base_line[1])])
        )
        base_line_buffered = bufferWithStyle(
            base_line_string,
            line_buffer,
            endCapStyle=LibGEOS.GEOSBUF_CAP_ROUND
        )
    end
    return base_line
end


"""
## Example Input:
```julia-repl
julia> raw_lines = [[[x1, y1], [x2, y2], [x3, y3]], [[x1', y1'], [x2', y2']]]
```
"""
function merge_lines(
    raw_lines::Vector{T} where {T<:AbstractArray{U,1}} where {U<:AbstractArray{<:Real}};
    line_buffer::Real=DEFAULT_LINE_MERGE_BUFFER,
    ignore_branches::Bool=DEFAULT_LINE_MERGE_IGNORE_BRANCHES,
    area_ratio_threshold::Real=DEFAULT_LINE_MERGE_AREA_RATIO_THRESHOLD,
    difference_buffer_multiplier::Real=DEFAULT_DIFFERENCE_BUFFER_RATIO
)::Vector{AbstractArray{Float64}}
    # line = [[x1,y1],[x2,y2], ...]
    # point = [x,y]
    line_x_vectors = [Vector{Float64}([point[1] for point in line]) for line in raw_lines]
    line_y_vectors = [Vector{Float64}([point[2] for point in line]) for line in raw_lines]

    lines = map(x -> [x[1], x[2]], zip(line_x_vectors, line_y_vectors))
    merged_line = merge_lines(
        lines,
        line_buffer=line_buffer,
        ignore_branches=ignore_branches,
        area_ratio_threshold=area_ratio_threshold,
        difference_buffer_multiplier=difference_buffer_multiplier,
    )
    return map(x -> [x[1] x[2]], zip(merged_line[1], merged_line[2]))
end

"""
## Example Input:
```julia-repl
julia> lines_dataframes = [
    DataFrame(x=[x1, x2, x3], y=[y1, y2, y3]),
    DataFrame(x=[x1', x2'], y=[y1', y2'])
]
```
"""
function merge_lines(
    lines_dataframes::Vector{DataFrame};
    x_column::String,
    y_column::String,
    line_buffer::Real=DEFAULT_LINE_MERGE_BUFFER,
    ignore_branches::Bool=DEFAULT_LINE_MERGE_IGNORE_BRANCHES,
    area_ratio_threshold::Real=DEFAULT_LINE_MERGE_AREA_RATIO_THRESHOLD,
    difference_buffer_multiplier::Real=DEFAULT_DIFFERENCE_BUFFER_RATIO
)::DataFrame
    # sending the right column names is the user's responsibility - no validation required

    # typed for stability
    lines = Vector{Vector{Vector{Float64}}}([[line[:, x_column], line[:, y_column]] for line in lines_dataframes])
    merged_line = merge_lines(
        lines,
        line_buffer=line_buffer,
        ignore_branches=ignore_branches,
        area_ratio_threshold=area_ratio_threshold,
        difference_buffer_multiplier=difference_buffer_multiplier,
    )
    return DataFrame(Symbol(x_column) => merged_line[1], Symbol(y_column) => merged_line[2])
end
