# These are all placeholders kept for backwards compatibility and will be 
# removed in a future release.
function e_metric_path_length(g, linestring, possible_paths)
    Base.depwarn(
        "`e_metric_path_length` is deprecated and will return `nothing`.",
        :e_metric_path_length
    )
    return nothing
end

function e_metric_start_to_end_heading(g, linestring, possible_paths, xy=true)
    Base.depwarn(
        "`e_metric_start_to_end_heading` is deprecated and will return `nothing`.",
        :e_metric_start_to_end_heading
    )
    return nothing
end

function e_metric_start_end_dist(g, linestring, possible_paths, xy=true)
    Base.depwarn(
        "`e_metric_start_end_dist` is deprecated and will return `nothing`.",
        :e_metric_start_end_dist
    )
    return nothing
end

function e_metric_total_length(g, linestring, possible_paths, xy=true)
    Base.depwarn(
        "`e_metric_total_length` is deprecated and will return `nothing`.",
        :e_metric_total_length
    )
    return nothing
end

function e_metric_interpolated_path_distance(g, linestring, possible_paths, xy=true, interval=0.1)
    Base.depwarn(
        "`e_metric_interpolated_path_distance` is deprecated and will return `nothing`.",
        :e_metric_interpolated_path_distance
    )
    return nothing
end

function e_metric_combined(g, linestring, possible_paths)
    Base.depwarn(
        "`e_metric_combined` is deprecated and will return `nothing`.",
        :e_metric_combined
    )
    return nothing    
end

function e_metric_start_end_dist_length(g, linestring, possible_paths, xy=true, dist_weight=0.5)
    Base.depwarn(
        "`e_metric_start_end_dist_length` is deprecated and will return `nothing`.",
        :e_metric_start_end_dist_length
    )
    return nothing
end

function e_metric_weighted_angle_length(g, linestring, possible_paths, xy=true, dist_weight=0.8)
    Base.depwarn(
        "`e_metric_weighted_angle_length` is deprecated and will return `nothing`.",
        :e_metric_weighted_angle_length
    )
    return nothing
end
