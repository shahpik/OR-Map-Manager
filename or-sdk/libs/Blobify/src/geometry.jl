using LightOSM

########################
# pathL, pathX, path Y #
########################

Base.@propagate_inbounds function get_path_information(g, path_nodes)
    path_x, path_y = get_positions_from_nodes(g, path_nodes)
    path_l = calc_pathL(path_x, path_y)
    return path_x, path_y, path_l
end

Base.@propagate_inbounds function get_positions_from_nodes(g, path_nodes)
    n_vehicles = length(path_nodes)
    path_x = Vector{Vector{Float32}}(undef, n_vehicles)
    path_y = Vector{Vector{Float32}}(undef, n_vehicles)
    for i_veh in 1:n_vehicles
        n_nodes = length(path_nodes[i_veh])
        path_x[i_veh] = Vector{Float32}(undef, n_nodes)
        path_y[i_veh] = Vector{Float32}(undef, n_nodes)
        for i_nodes in 1:n_nodes
            # TODO: can we abstract this for different graph types?
            path_x[i_veh][i_nodes] = g.nodes[path_nodes[i_veh][i_nodes]].location.lon
            path_y[i_veh][i_nodes] = g.nodes[path_nodes[i_veh][i_nodes]].location.lat
        end
    end
    return path_x, path_y
end

Base.@propagate_inbounds function calc_pathL(pathX::Vector{Vector{Float32}}, pathY::Vector{Vector{Float32}})
	"""
	haversine Calculation of great circle distance between two points
	inputs: dataframe columns or np columns, in decimal degrees
	returns: np vector of distance in km
	"""
	R = 6378.137  # slightly better approximate radius of earth in km, at equator
    
    n_agents = length(pathX)
    dist = Vector{Vector{Float32}}(undef, n_agents)
    
    for i in 1:n_agents
        n_edges = length(pathX[i]) - 1
        dist[i] = Vector{Float32}(undef, n_edges)
        for j in 1:n_edges
			d = sin((deg2rad(pathY[i][j+1]) - deg2rad(pathY[i][j])) / 2) ^ 2 + cos(deg2rad(pathY[i][j])) * cos(deg2rad(pathY[i][j+1])) * sin((deg2rad(pathX[i][j+1]) - deg2rad(pathX[i][j])) / 2) ^ 2
			dist[i][j] = 2.0 * R * asin(sqrt(d)) * 1000.0  # convert from km to m
		end
		cumsum!(dist[i], dist[i])
	end

	return dist
end

function get_relative_dir(ref_dir, target_dir)
    rel_dir = target_dir - ref_dir
    if rel_dir < -180
        rel_dir = rel_dir + 360
    elseif rel_dir > 180
        rel_dir = rel_dir - 360
    end
    return rel_dir
end


"""
`get_heading_between_nodes`
Get angles between two nodes from a dict, or calculate it if it doesn't exist and add to the dict
relative: 0 will return absolute. If non 0, returns the relative angle compared to that
Don't think it should be sparse dict: Elementwise insertions are slow, cos it needs to re-order.

`Arguments`
	n1: node id, integer
	n2: 2nd node id, integer
	headings_lookup: dict of existing, already calculated angles between any 2 nodes
	road_graph: graph object containing the positions of the two nodes. Used to derive the headings_lookup
"""
Base.@propagate_inbounds function get_heading_between_nodes!(n1::Integer, n2::Integer, headings_lookup, nodes::Dict{Int64,Node{Int64}})
    if haskey(headings_lookup, n1)
        if haskey(headings_lookup[n1], n2)
            return headings_lookup[n1][n2]
        end
    else
        headings_lookup[n1] = Dict{Int64, Float64}()    
	end
	if haskey(nodes, n1) && haskey(nodes, n2)
		if n1 != n2
			# Light_OSM way of retrieving node data lat longs
			new_heading::Float64 = heading(nodes[n1], nodes[n2]) # Remove allocations from LightOSM function
			headings_lookup[n1][n2] = new_heading
		else
			new_heading = 0.0  # same node -> no change.
			headings_lookup[n1][n2] = new_heading
		end
	else
		# @warn "One of nodes $n1 $n2 does not exist in dict - cornering ignored"
		new_heading = 0.0
		headings_lookup[n1][n2] = new_heading
	end
    return new_heading
end

################
# pathHeadings #
################

Base.@propagate_inbounds function get_path_headings(path_nodes::AbstractVector{<:AbstractVector{<:Integer}}, nodes::Dict{Int64,Node{Int64}})
    n_vehs = length(path_nodes)
    headings_lookup = Dict{Int64, Dict{Int64, Float64}}()
    path_headings = Vector{Vector{Float64}}(undef, n_vehs)
    for i in 1:n_vehs  # each road segment in path_nodes
        # set up previous abs dir, used to calc next relative dir. But leave first rel dir as 0
        prev_abs_dir = get_heading_between_nodes!(path_nodes[i][1], path_nodes[i][2], headings_lookup, nodes)  
        n_nodes = length(path_nodes[i])
        individual_path_headings = zeros(Float64, n_nodes)
        individual_path_headings[1] = 0.0  # initial rel heading is 0
        for j in 2:(n_nodes-1)
            abs_angle = get_heading_between_nodes!(path_nodes[i][j], path_nodes[i][j+1], headings_lookup, nodes)
            individual_path_headings[j] = get_relative_dir(prev_abs_dir, abs_angle)
            prev_abs_dir = abs_angle  # reset for next angle calculation
        end
        path_headings[i] = individual_path_headings
    end
    return path_headings
end

"""
    nearest_node_from_list(src_node_id::T,
                           node_list::Vector{T},
                           g::OSMGraph{U, T, W}
                           )::Tuple{T, <:Real} where {U <: Integer, T <: Integer, W <: Real}

Get the node in `node_list` that is nearest to `src_node`. All nodes must be
members of the `OSMGraph`, `g`. Uses the `LightOSM.distance` function and the
Haversine distance measure.

# Arguments
- `src_node_id::T`, OSM Node ID of the node to search from.
- `node_list::Vector{T}`, List of OSM Node IDs 
- `g::OSMGraph{U, T, W}`, LightOSM graph representation of the network.

# Returns
- A `Tuple{<:Integer, <:Real}` of the OSM ID of the nearest node from `node_list`
    and the Haversine distance to that node.
"""
function nearest_node_from_list(src_node_id::T,
                                node_list::Vector{T},
                                g::OSMGraph{U, T, W}
                                )::Tuple{T, <:Real} where {U <: Integer, T <: Integer, W <: Real}

    distances = Vector{Float64}(undef, length(node_list))
    for (n, node) in enumerate(node_list)
        distances[n] = LightOSM.distance(g.nodes[src_node_id], g.nodes[node])
    end
    dist, index = findmin(distances)
    nearest = node_list[index]

    return nearest, dist
end