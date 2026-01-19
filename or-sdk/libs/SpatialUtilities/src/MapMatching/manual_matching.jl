"""
find_nearest_points(source_ls, osm_ls)

This function searches an OSM linestring to find the points which are closest to the input feature linestring endpoints. 
It returns the points that were closest to the start and end, as well as their indexes
"""
function find_nearest_points(source_ls, osm_ls)
    dist_start = []
    dist_end = []
    start_point = source_ls[1]
    end_point = source_ls[end]
    for (i, node) in enumerate(osm_ls)
        push!(dist_start, sqrt((start_point[1]-node[1])^2 + (start_point[2]-node[2])^2))
        push!(dist_end, sqrt((end_point[1]-node[1])^2 + (end_point[2]-node[2])^2))
    end
    # Find the OSM node closest in distance to the first point in the source line
    s_min = findmin(dist_start)
    start_index = s_min[2]
    closest_node_to_start = osm_ls[start_index]

    # Find the OSM node closest in distance to the last point in the source line
    e_min = findmin(dist_end)
    end_index = e_min[2]
    # For the case where start_index = end_index, this is an unfortunate (and wrong match) but we should be able to handle this
    # Check which of the nodes either side is closer
    if start_index == end_index
        if start_index == 1
            end_index = start_index+1
        elseif start_index == length(osm_ls)
            end_index = start_index-1
        else
            forward = osm_ls[end_index+1]
            backward = osm_ls[end_index-1]
            dist_forward = sqrt((start_point[1]-forward[1])^2 + (start_point[2]-forward[2])^2)
            dist_backward = sqrt((start_point[1]-backward[1])^2 + (start_point[2]-backward[2])^2)
            if dist_forward < dist_backward
                end_index = end_index+1
            else
                end_index = end_index-1
            end
        end
    end
    closest_node_to_end = osm_ls[end_index]
    return closest_node_to_start, start_index, closest_node_to_end, end_index
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
calculate_return_geom(source_ls,osm_ls)

This function accepts two sets of linestrings. An input feature linestring, and the osm linestrings that have been matched to it.
It trims the OSM way linestrings to match the input feature linestring by calculating the nearest points to the end points of 
the input feature linestring, and interpolating new endpoints (if needed), such that the relationship geometry created represents
only the section of OSM ways that matches to the input feature linestring. 
"""
function calculate_return_geom(source_ls,osm_ls)
    # This function takes in the geom from OSM ways as multilinestrings and separates them into a set of contiguous linestrings
    # SORT OUT DOUBLE POINTS
    # cleaned_linestrings = connected_linestring_search(osm_ls)
    # We expect osm_ls to be a multilinestring - if it is not, the loop does not work. Therefore convert linestrings into multilinestrings (of size 1) if needed.
    if typeof(osm_ls) == Vector{Vector{Float64}}
        osm_ls = [osm_ls]
    end
    cleaned_linestrings = osm_ls
    relationship_geom = []
    for ls in cleaned_linestrings
        # Find the start and end points of the source (VMT) linestring - we will cut the OSM linestrings to match this
        X = source_ls[1]
        Y = source_ls[end]
        # Create the base vector x->y - I used the next index here because sometimes it's not a straight line
        base_vector = source_ls[2] - X
        # Find the nearest points in the OSM linestring to the start and end points of VMT
        closest_node_to_start, start_index, closest_node_to_end, end_index = find_nearest_points(source_ls, ls)
        # It's possible that start index > end_index which becomes very problematic. Reorder here instead.
        if start_index > end_index 
            ls = reverse(ls)
            closest_node_to_start, start_index, closest_node_to_end, end_index = find_nearest_points(source_ls, ls)
        end
        # START POINT
        # If 'closest point' we found has nodes on left and right:
        if  start_index > 1 && start_index < length(ls)
            # Guess that OSM node that sits on the other side of the actual point is to the right of the closest point
            next_nearest_node = ls[start_index+1]
            # Find the vectors x->a and x->b
            vector_start_closest = closest_node_to_start - X
            vector_start_next = next_nearest_node - X
            # Dot product of x->a with x->y, and Dot product of x->b with x->y gives directionality 
            dot_prod_a = LinearAlgebra.dot(vector_start_closest, base_vector)
            dot_prod_b = LinearAlgebra.dot(vector_start_next, base_vector)
            # If the dot products have the same sign, then they are both to the left or the right of the point
            # And we need to adjust our other point to be start_index - 1
            if (dot_prod_a * dot_prod_b) > 0 
                next_nearest_node = ls[start_index-1]  
                final_start_coordinates = interpolate_point_from_a_b_endpoint(closest_node_to_start, next_nearest_node, X)
                middle_coords_st_index = start_index 
            elseif (dot_prod_a * dot_prod_b) == 0
                if dot_prod_a == 0
                    final_start_coordinates = closest_node_to_start
                    middle_coords_st_index = start_index+1
                else
                    final_start_coordinates = next_nearest_node
                    middle_coords_st_index = start_index+2
                end
            else 
                # Otherwise we guessed correctly - do nothing
                final_start_coordinates = interpolate_point_from_a_b_endpoint(closest_node_to_start, next_nearest_node, X)
                middle_coords_st_index = start_index+1
            end    
        # If we have found that the closest node is actually the first or last in the linestring 
        # We need to check whether we should interpolate a point in between or not
        elseif start_index == 1 || start_index == length(ls)
            # Guess that OSM node sits on the right of the closest point
            if start_index == 1
                next_nearest_node = ls[start_index+1]
            # Forced to guess that the OSM node sits on the left side of the actual point 
            else
                next_nearest_node = ls[start_index-1]
            end
            # Find the vectors x->a and x->b
            vector_start_closest = closest_node_to_start - X
            vector_start_next = next_nearest_node - X
            # Dot product of x->a with x->y, and Dot product of x->b with x->y gives directionality 
            dot_prod_a = LinearAlgebra.dot(vector_start_closest, base_vector)
            dot_prod_b = LinearAlgebra.dot(vector_start_next, base_vector)
            # If the dot products have the same sign, then they are both on the same side of the point
            # In this case, we have no points in position ls[start_index-1], so we will just use the closest point
            # and not interpolate
            if (dot_prod_a * dot_prod_b) > 0 
                # No interpolation needed, OSM is shorter (on this side) than the source link
                final_start_coordinates = closest_node_to_start
                middle_coords_st_index = start_index+1
            elseif (dot_prod_a * dot_prod_b) == 0
                if dot_prod_a == 0
                    final_start_coordinates = closest_node_to_start
                    middle_coords_st_index = start_index+1
                else
                    final_start_coordinates = next_nearest_node
                    middle_coords_st_index = start_index+2
                end
            else 
                # If we did guess correctly, then we need to interpolate between a and b
                final_start_coordinates = interpolate_point_from_a_b_endpoint(closest_node_to_start, next_nearest_node, X)
                middle_coords_st_index = start_index+1
            end   
        else 
            @info "ERROR"
        end    
        # Create the base vector y->x 
        base_vector = source_ls[end-1] - Y
        # END POINT
        # If we haven't found that the first OSM node is closest to the first or last point in the linestring
        # Meaning that the 'closest point' we found has nodes on left and right:
        if end_index < length(ls) && end_index > 1
            # Guess that OSM node that sits on the other side of the actual point is to the right of the closest point
            next_nearest_node = ls[end_index+1]
            # Find the vectors y->a and y->b
            vector_end_closest = closest_node_to_end - Y
            vector_end_next = next_nearest_node - Y
            # Dot product of y->a with y->x, and Dot product of y->b with y->x gives directionality 
            dot_prod_a = LinearAlgebra.dot(vector_end_closest, base_vector)
            dot_prod_b = LinearAlgebra.dot(vector_end_next, base_vector)
            # If the dot products have the same sign, then they are both to the left or the right of the point
            # And we need to adjust our other point to be end_index - 1
            if (dot_prod_a * dot_prod_b) > 0
                next_nearest_node = ls[end_index-1]  
                final_end_coordinates = interpolate_point_from_a_b_endpoint(closest_node_to_end, next_nearest_node, Y)
                middle_coords_end_index = end_index-1
            elseif (dot_prod_a * dot_prod_b) == 0
                if dot_prod_a == 0
                    final_end_coordinates = closest_node_to_end
                    middle_coords_end_index = end_index-1
                else
                    final_end_coordinates = next_nearest_node
                    middle_coords_end_index = end_index
                end
            else
                # Otherwise we guessed correctly - do nothing
                final_end_coordinates = interpolate_point_from_a_b_endpoint(closest_node_to_end, next_nearest_node, Y)   
                middle_coords_end_index = end_index
            end    
        # If we have found that the closest node is actually the first or last in the linestring 
        # We need to check whether we should interpolate a point in between or not
        elseif end_index == 1 || end_index == length(ls)
            # Guess that OSM node sits on the right of the closest point
            if end_index == 1
                next_nearest_node = ls[end_index+1]
            # Forced to guess that the OSM node sits on the left side of the actual point 
            else
                next_nearest_node = ls[end_index-1]
            end
            # Find the vectors x->a and x->b
            vector_end_closest = closest_node_to_end - Y
            vector_end_next = next_nearest_node - Y
            # Dot product of x->a with x->y, and Dot product of x->b with x->y gives directionality 
            dot_prod_a = LinearAlgebra.dot(vector_end_closest, base_vector)
            dot_prod_b = LinearAlgebra.dot(vector_end_next, base_vector)
            # If the dot products have the same sign, then they are both on the same side of the point
            # In this case, we have no points in position ls[end_index-1], so we will just use the closest point
            # and not interpolate
            if (dot_prod_a * dot_prod_b) > 0 
                # No interpolation needed, OSM is shorter (on this side) than the source link
                final_end_coordinates = closest_node_to_end
                middle_coords_end_index = end_index-1
            elseif (dot_prod_a * dot_prod_b) == 0
                if dot_prod_a == 0
                    final_end_coordinates = closest_node_to_end
                    middle_coords_end_index = end_index-1
                else
                    final_end_coordinates = next_nearest_node
                    middle_coords_end_index = end_index
                end
            else 
                # If we did guess correctly, then we need to interpolate between a and b
                final_end_coordinates = interpolate_point_from_a_b_endpoint(closest_node_to_end, next_nearest_node, Y)   
                middle_coords_end_index = end_index - 1
            end   
        else 
            @info "Spatial Utilities Error - check error.jl"
        end 

        if middle_coords_st_index == 0
            middle_coords_st_index = 1 
        elseif middle_coords_end_index == 0
            middle_coords_end_index = 1
        end

        if middle_coords_st_index > middle_coords_end_index
            middle_coords = ls[middle_coords_end_index:middle_coords_st_index]
            ls_geom = [[final_end_coordinates]; middle_coords; [final_start_coordinates]]
        else
            middle_coords = ls[middle_coords_st_index:middle_coords_end_index]
            ls_geom = [[final_start_coordinates]; middle_coords; [final_end_coordinates]]
        end
        
        push!(relationship_geom, ls_geom)
    end

    return relationship_geom
end

"""
interpolate_point_from_a_b_endpoint(a, b, endPoint)

This function takes in 3 points, a, b and a point that we want an interpolated point to be perpendicular to. 
The point is interpolated along the vector a->b using the SpatialUtilities 'lerp' function. 
The ratio between a to b is determined by the normalised projection of x->a on a->b divided by the total length.
"""
function interpolate_point_from_a_b_endpoint(a, b, endPoint)
    # Find alpha proportion between a -> b  (a = closest_node_to_start, b = next_nearest_node)
    # abs of dot(x->a with a->b)
    vector_a_to_b = b - a
    vector_x_to_a = a - endPoint
    dot = abs(LinearAlgebra.dot(vector_a_to_b, vector_x_to_a))
    length = sqrt((b[1]-a[1])^2 + (b[2]-a[2])^2)
    projection = (dot/length)
    normalised_projection = projection/length
    # If projection > 1, we can only choose the end point, if projection < 0, we can only choose the start point
    if normalised_projection > 1
        normalised_projection = 1.0
    elseif normalised_projection < 0
        normalised_projection = 0.0
    end
    # Interpolate between the nearest point, and the next point - make sure alpha is the right direction
    final_start_coordinates = SpatialUtilities.lerp(GeoLocation(a), GeoLocation(b), normalised_projection)
    final_start_coordinates = [final_start_coordinates.lat, final_start_coordinates.lon]
    return final_start_coordinates
end
