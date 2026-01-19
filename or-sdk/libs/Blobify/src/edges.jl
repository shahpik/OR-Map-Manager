using LightOSM

####################
# pathV, pathEdges #
#####################

"""
    get_path_edges_and_velocities(g, path_nodes::AbstractVector{<:AbstractVector})

path_edges is Vector{Vector{Int64}
path_v is Vector{Vector{Float32}}}, in m/s
"""
Base.@propagate_inbounds function get_path_edges_and_velocities(g, path_nodes::AbstractVector{<:AbstractVector})
    edge = [0, 0]
    n_paths = length(path_nodes)
    path_edges = Vector{Vector{Int64}}(undef, n_paths)
    path_velocities = Vector{Vector{Float32}}(undef, n_paths)
    for i_path in 1:n_paths
        n_nodes = length(path_nodes[i_path])
        path_edges[i_path] = Vector{Int64}(undef, n_nodes-1)
        path_velocities[i_path] = Vector{Int64}(undef, n_nodes-1)
        way = Int[]
        for i_edge = 1:n_nodes - 1
            edge[1] = path_nodes[i_path][i_edge]
            edge[2] = path_nodes[i_path][i_edge + 1]
            way = g.edge_to_way[edge]
            path_edges[i_path][i_edge] = way
            # convert velocity from km/h to m/s
            path_velocities[i_path][i_edge] = g.ways[way].tags["maxspeed"] / 3.6
        end
    end
    return path_edges, path_velocities
end

########################
# seg_order, seg_lanes #
########################

Base.@propagate_inbounds function calc_seg_matrix(g, path_nodes)
	# 1.
	# od_path_edges, edge_osm_map = _get_edge_id_from_od_nodes(g, path_nodes, path_edges)
	edge_to_way_map = g.edge_to_way
	od_path_edges = collect(keys(g.edge_to_way))
	unique_edges = sort(unique(od_path_edges))
	n_unique_edges = length(unique_edges)

	# 3. - Lane info should be retrieved before placeholder edgeIDs are used
	seg_lanes = _find_lanes_on_edge(unique_edges, g, edge_to_way_map)

	# 4.
	unique_edges, seg_order, edge_2_seg = _make_edge_ids(unique_edges, path_nodes, n_unique_edges)
	@info "done making edges"
	return seg_order, seg_lanes, n_unique_edges, edge_2_seg # old names: seg_order, seg_lane, n_edges
end

"""
road_graph::LightOSM version
Lane detection logic:
    if there's no lane tag at all: use default
    if there is lane tag:
        if it has a oneway key -> use it's value to determine if lanes need to be halved (for 2 way streets)
        else, assume 2 way, do a max(Int(floor(lanes/2)), 1)
"""
Base.@propagate_inbounds function _find_lanes_on_edge(unique_edges, road_graph::OSMGraph, edge_osm_map; default_lanes=1)
    
    n_edges::Int64 = size(unique_edges)[1]
    edge_seg_lane::Array{Int64, 1} = fill(default_lanes, n_edges)  # set default
    @warn "not checking/handling if lane data doesn't exist, replacing with default"
    for i in 1:n_edges
        # get the ways id for each unique segment/sub part of the way
        osm_edge_id = edge_osm_map[unique_edges[i]]

        if !haskey(road_graph.ways, osm_edge_id)  # check the edge we're looking for exists
            continue  # skip, default lane count will be used
        end
        if haskey(road_graph.ways[osm_edge_id].tags, "lanes")  # only do this update if the lanes data exists
            _lanes = Int(floor(road_graph.ways[osm_edge_id].tags["lanes"]))  # property comes in as string, people do silly things like 1.5 lanes
            if haskey(road_graph.ways[osm_edge_id].tags, "oneway")  # use the oneway tag, if exists
                _oneway = road_graph.ways[osm_edge_id].tags["oneway"]  # assumes lightosm already parses this properly
                if !_oneway # if it is 1 way, then don't half lanes. not one way = two ways -> half lanes
                    _lanes = max(Int(floor(_lanes/2)), 1)
                end  # divide by 2 for both directions, round down with a minimum of 1
            end
            edge_seg_lane[i] = _lanes
        end
    end
    return edge_seg_lane
end

"""
    assigns sequential segment ids (ints)
    starting at 1 up to max number of unique edges
    for prod will have to do this in pathgen, make sure sensible values are used
"""
Base.@propagate_inbounds function _make_edge_ids(unique_edges, path_nodes::AbstractVector{<:AbstractVector{Int64}}, n_unique_edges::Int)
    edge_2_seg::Dict{Vector{<:Int64}, Int64} = Dict(unique_edges[i] => i for i = 1:n_unique_edges)
    n_vehicles = length(path_nodes)
	seg_order = Vector{Vector{Int32}}(undef, n_vehicles)
	edge = [0, 0] # Pre-allocation
    for i in 1:n_vehicles
        n_edges = length(path_nodes[i]) - 1
        seg_order[i] = Vector{Int32}(undef, n_edges)
		for j in 1:n_edges
			edge[1] = path_nodes[i][j]
			edge[2] = path_nodes[i][j+1]
			seg_order[i][j] = edge_2_seg[edge]
		end
	end
	index_edges = collect(1:n_unique_edges)  # creates the list from a range
	return index_edges, seg_order, edge_2_seg
end

#############
# seg_2_int #
#############

Base.@propagate_inbounds function calc_seg_2_int(seg_order, s2i_veh, n_unique_edges)
	# for s2i_vehs, if the entire row is -1, then the vehicle does not reach any known intersection (or intersections were not generated along it's path)
	@warn "WARNING: DEFAULT seg_2_int is set to 1, please fix this after show case. Should make dedicated placeholder light"
	seg_2_intersections = ones(Int64, n_unique_edges) # initialise to 1, means segments will default to pointing to this intersection for intersection checks, if vehicles on it do not reach a 'real' intersection

	for i = 1:length(seg_order)
        max_n_segs = length(s2i_veh[i])
		if sum(abs.(s2i_veh[i])) == max_n_segs
			# NOTE/WARNING: default s2i_veh values must be -1 OR +1 (hence use of abs())
			# This is to filter out vehicles that never reach a intersection, do not attempt to use their paths to get seg_2_intersections
			continue
		end
		for j = 1:length(seg_order[i])
			if s2i_veh[i][j] < 0  # check if < -1, skip because data not there
				continue
			end
            seg_2_intersections[seg_order[i][j]] = s2i_veh[i][j]
		end
	end
	return seg_2_intersections
end

###################
# seg_corrections #
###################

Base.@propagate_inbounds function calc_seg_corrections_matrix(seg_order, seg_2_intersections, p2p_matrix)
    I, J, X = calc_seg_corrections(seg_order, seg_2_intersections, p2p_matrix)
    return sparse(reduce(vcat, I), reduce(vcat, J), reduce(vcat, X))
end
Base.@propagate_inbounds function calc_seg_corrections(seg_order, seg_2_intersections, p2p::AbstractVector)
    p2p_matrix = transpose(reduce(hcat, p2p))
    return calc_seg_corrections(seg_order, seg_2_intersections, p2p_matrix)
end
Base.@propagate_inbounds function calc_seg_corrections(seg_order, seg_2_intersections, p2p_matrix::AbstractMatrix)
    n_vehicles = length(seg_order)
    # pre build array of p2p minimums for each intersections
    n_ints = size(p2p_matrix, 2)
    _min_p2p_per_int = Array{Float32,1}(undef, n_ints)

    # Check use of @inbounds before entering threaded loop because @inbounds gets lost when threading
	using_inbounds = @is_inbounds_on

    @custom_threads for k=1:n_ints  # for every intersection, run only k times
        @optional_inbounds using_inbounds _min_p2p_per_int[k] = minimum(@view(p2p_matrix[:,k]))
    end

    I = Vector{Vector{Int64}}(undef, n_vehicles)  # create indicies to hold the values/indicies that will be used to build sparse matrix
    J = Vector{Vector{Int64}}(undef, n_vehicles)
    X = Vector{Vector{Float64}}(undef, n_vehicles)
    @custom_threads for i in 1:n_vehicles  # each vehicle
        @optional_inbounds using_inbounds begin
            n_edges = length(seg_order[i])
            I[i] = Vector{Int64}(undef, n_edges)
            J[i] = Vector{Int64}(undef, n_edges)
            X[i] = Vector{Float64}(undef, n_edges)
            for j in 1:n_edges  # each segment index, across all vehicles
                seg_id = seg_order[i][j]
                int_watched = seg_2_intersections[seg_id]
                p2p_current = p2p_matrix[i, int_watched]
                p2p_min = _min_p2p_per_int[int_watched]
                X[i][j] = (p2p_current-p2p_min)+0.0001
                I[i][j] = i
                J[i][j] = seg_id
            end
        end
    end
    return I, J, X
end