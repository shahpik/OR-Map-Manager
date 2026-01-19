"""
    pt_dist_to_line(x1, y1, x2, y2, x, y)

Finds euclidean distance between a point and a line (defined by 2 points)
x1 y1, x2 y2 are the points for the line, x, y is the point in question.
"""
function pt_dist_to_line(x1, y1, x2, y2, x, y)
    A = x - x1
    B = y - y1
    C = x2 - x1
    D = y2 - y1
    dot = A * C + B * D
    len_sq = C * C + D * D
    param = -1.0
    if len_sq != 0 # in case of 0 length line
        param = dot / len_sq
    end
    if param < 0.0
        xx = x1
        yy = y1
    elseif param > 1.0
        xx = x2
        yy = y2
    else
        xx = x1 + param * C
        yy = y1 + param * D
    end
    dx = x - xx
    dy = y - yy
    return sqrt(dx * dx + dy * dy)
end


"""
    dist_between_points(a::AbstractArray{<:Real}, b::AbstractArray{<:Real})

Helper function to find the euclidean distance between two points.

# Arguments
- `a::AbstractArray{<:Real}`: Point 1 -> [x, y]
- `b::AbstractArray{<:Real}`: Point 2 -> [x', y']

# Returns
- `::String`: WKT linestring
"""
dist_between_points(a::AbstractArray{<:Real}, b::AbstractArray{<:Real}) = sqrt((a[1] - b[1])^2 + (a[2] - b[2])^2)

"""
    get_line_length(x_values::AbstractArray{<:Real}, y_values::AbstractArray{<:Real})

Returns the length of the line by summing the length of individual segments. Assumes points are ordered.
"""
function get_line_length(x_values::AbstractArray{<:Real}, y_values::AbstractArray{<:Real})
    return reduce(
        (a, b) -> a + (b == 1 ? 0 : dist_between_points(
            [x_values[b] - 1, y_values[b-1]],
            [x_values[b], y_values[b]]
        )),
        1:length(x_values),
        init=0
    )
end