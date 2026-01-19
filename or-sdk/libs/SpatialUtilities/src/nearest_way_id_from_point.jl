"""
    knn_pairs(g, geo_point, k=100)
For a given point, find all KNN(k) of osm node ids. default k: 100, to make sure the search range is reasonably sufficient.

Return all possible unique pairs of node ids.

Note: here as function (edge_to_way) for node pairs are symmetric, therefore we only need to return all pairs (a, b) where a < b
"""
function knn_pairs(g, geo_point::Vector{Float64}, k=100)
    nearest_node_list = nearest_nodes(g, GeoLocation(geo_point), k)[1]
    @debug nearest_node_list
    possibilities = Iterators.product(nearest_node_list, nearest_node_list)
    return ([i...] for i in possibilities if i[1] < i[2])
end


"""
    calculate_edge_distance(g, edge_list, exam_point_x, exam_point_y, key_pairs)

For any given point, calculate the distances to all given way edges.
Return the way id from the way edge and the distance

Note: here distance is calculate from function pt_dist_to_line in distance.jl 

# Args
- `g`: osm graph
- `edge_list`: all possible edge list, usually would be keys(g.edge_to_way)
- `exam_point_x`: lontitude of given point 
- `exam_point_y`: latitude of give point 
- `key_pairs`: all combinations of osm node id pairs

# Return
- `distance_df`: a DataFrame contains 2 columns:
    - the corresponding way_id;
    - the distances from given point to the way segment 
"""
function calculate_edge_distance(g, edge_list, exam_point_x, exam_point_y, key_pairs)
    distance_df = DataFrame(way_id = Int[], distance = Float64[])
    for key_pair in key_pairs
        if key_pair in edge_list
            # calculate distance from exam point to lines determined by node key_pairs
            # x: lon, 144
            start_point = g.nodes[key_pair[1]].location
            end_point = g.nodes[key_pair[2]].location
            distance = SpatialUtilities.pt_dist_to_line(
                start_point.lon,
                start_point.lat,
                end_point.lon,
                end_point.lat,
                exam_point_x, # df.X
                exam_point_y) # df.Y
            push!(distance_df, [g.edge_to_way[key_pair], distance])
        end
    end
    return distance_df
end


"""
    min_dist_way_id(dist_df::AbstractDataFrame, return_items::Int64=1)
Group by way_id and calculate the mean distance to way segment 

Return a set number of corresponding way_ids with the smallest means

# Args
- `dist_df`: dataframe containing the average distance for different way ids
- `return_items`: the number of closest ways to return

Note: input dataframe must have two columns: way_id and distance
"""
function min_dist_way_id(dist_df::AbstractDataFrame, return_items::Int64=1)
    # check if both columns way_id and distance exist
    for col in ("way_id", "distance")
        if col ∉ names(dist_df)
            throw(ArgumentError(col, "$col does not exist! Input dataframe must have both way_id and distance columns!"))
        end
    end
    # group distance based on way id
    gdf_dist = groupby(dist_df, :way_id; sort=true, skipmissing=false)
    # calculate the mean distance and sort in ascending orders
    sorted_mean_dist = sort!(combine(gdf_dist, :distance => mean), :distance_mean)
    if return_items == 1
        return sorted_mean_dist.way_id[1]
    else
        return sorted_mean_dist.way_id[1:return_items]
    end 
end


"""
    get_way_id_from_point(g, geopoint, k=100, return_items=1)
Retreive the nearest way ids for a given geocoordinate

High level steps:
  * do a knn search of any given point (default n to 100) and return all osm node ids
  * for all above node id list, return all possible key pair (a, b) where a < b.
  * for each pair, if exist in keys(g.edge_to_way)
        calculate point to line distance, where line is determined by node id pairs
  * calculate the average distance and returns the corresponding way_id with min average distance

Note: geo_point input must a Vector of Float64, sample input: [-38.02914, 145.32085]
"""
function get_way_id_from_point(g, geopoint::Vector{Float64}, k=100, return_items=1)
    edge_list = keys(g.edge_to_way)
    key_pair_list = knn_pairs(g, geopoint, k)
    dist_df = calculate_edge_distance(g, edge_list, geopoint[2], geopoint[1], key_pair_list)
    if size(dist_df)[1] == 0
        @warn "No ways found. Consider increase k value to increase KNN search range."
        return nothing
    else
        way_id = min_dist_way_id(dist_df, return_items)
        return way_id
    end
end
