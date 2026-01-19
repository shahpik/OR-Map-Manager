using SparseArrays

const PRIORITIES_DEFAULT = Int32(-9)
const PATH_2_POINT_DEFAULT = Float32(1.0e8)

################
# path_2_point #
################

Base.@propagate_inbounds function get_path_2_point(pathL, path_nodes, nodeIntMap, n_intersections)
    p2p = Vector{Vector{Float32}}(undef, length(path_nodes))
    p2p, s2i_vehs, X, I, J = make_p2p!(p2p, path_nodes, pathL, nodeIntMap, n_intersections)
    return p2p, s2i_vehs, X, I, J
end

Base.@propagate_inbounds function get_path_2_point_matrix(pathL, path_nodes, nodeIntMap, n_intersections)
    p2p_matrix = fill(Float32(PATH_2_POINT_DEFAULT), length(path_nodes), n_intersections)
    p2p_matrix, s2i_vehs, X, I, J = make_p2p!(p2p_matrix, path_nodes, pathL, nodeIntMap, n_intersections)
    return p2p_matrix, s2i_vehs, X, I, J
end

Base.@propagate_inbounds function make_p2p!(p2p,path_nodes, pathL, nodeIntMap, n_intersections)
    n_vehs = length(path_nodes)
	pathL_with_zero::Vector{Vector{Float32}} = map(x->vcat(Float32(0.0), x), pathL) # TODO we shouldn't need to allocate this!!
    s2i_vehs = Vector{Vector{Int64}}(undef, n_vehs)
    X = Vector{Vector{Float32}}(undef, n_vehs)
    I = Vector{Vector{Int64}}(undef, n_vehs)
    J = Vector{Vector{Int64}}(undef, n_vehs)
    nodeIntMap_keys = keys(nodeIntMap)

	# Check use of @inbounds before entering threaded loop because @inbounds gets lost when threading
	using_inbounds = @is_inbounds_on

	@custom_threads for i = 1:n_vehs  # loop through every vehicle's path
		@optional_inbounds using_inbounds begin
			initialise_p2p_row(p2p, i, n_intersections)
			X[i] = Float32[]
			I[i] = Int64[]
			J[i] = Int64[]
			n_segments = length(pathL_with_zero[i]) # -1 # -1 using in old input_loader, but removed here to ensure matrices the same. TODO: Need to properly sort out end of trip behaviour
			s2i_vehs[i] = fill(-1, n_segments)
			_jLastSeenInt = 1  # index of the last node where an intersection was seen
			for j = 2:n_segments  # for each node (excluding start), check if nodes match any that are in intersection
				if path_nodes[i][j] in nodeIntMap_keys  #check dict of centroidnodes and see if it's in the list keylist of nodeIntMap
					# if found, lookup intersection's index the node belongs to
					# p2p is for intersection, needs find the intersections using the centroid node
					kInt = nodeIntMap[path_nodes[i][j]]
					if get_value(p2p, i, kInt) == PATH_2_POINT_DEFAULT  # check if p2p[i, kInt] is 1e8, else it has already reached this int, and veh is passing another centroid node in same intersection
						set_value(p2p, i, kInt, pathL_with_zero[i][j])
						@view(s2i_vehs[i][_jLastSeenInt:j-1]) .= kInt  # j-1 because 1 less edge than node, s2i is about edges
						_jLastSeenInt = j
						push!(X[i], pathL_with_zero[i][j])
						push!(I[i], i) # Don't need to do this. I should be constructed on other side.
						push!(J[i], kInt)
					end
				end
			end
		end
    end
    return p2p, s2i_vehs, X, I, J
end

Base.@propagate_inbounds initialise_p2p_row(p2p::AbstractVector, i, n_intersections) = p2p[i] = fill(Float32(PATH_2_POINT_DEFAULT), n_intersections)
initialise_p2p_row(p2p::AbstractMatrix, i, n_intersections) = nothing

##############
# Priorities #
##############

# TODO: can we combine priorities and path_2_point for loop, I and J vectors?

Base.@propagate_inbounds function get_priorities_matrix(path_nodes, p2p, intObjects)
    X, I, J = get_priorities(path_nodes, p2p, intObjects)
    return sparse(reduce(vcat, I), reduce(vcat, J), reduce(vcat, X))
end

Base.@propagate_inbounds function get_priorities(path_nodes, p2p, intObjects)  # lowest priority by default
	# NOTE for debug, should set default to stop if reaching somewhere it should not be/did not correctly get assigned to somewhere it has reached
	n_vehs = length(path_nodes)
	n_intersections = length(intObjects)

    X = Vector{Vector{Int8}}(undef, n_vehs)
    I = Vector{Vector{Int64}}(undef, n_vehs)
	J = Vector{Vector{Int64}}(undef, n_vehs)
	
	# Check use of @inbounds before entering threaded loop because @inbounds gets lost when threading
	using_inbounds = @is_inbounds_on

	@custom_threads for i in 1:n_vehs  # n rows should be n_vehicles
		@optional_inbounds using_inbounds begin
			X[i] = Int8[]
			I[i] = Int64[]
			J[i] = Int64[]
			for j in 1:n_intersections
				if get_value(p2p, i, j) == Float32(1e8)
					continue
				else
					val = get_path_priority_from_int(intObjects[j], path_nodes[i], PRIORITIES_DEFAULT)
					push!(X[i], val)
					push!(I[i], i)
					push!(J[i], j)
				end  # Won't update from defualt if never reaches
			end
			clamp!(X[i],-9,9)
		end
	end
	return X, I, J
end

""" looks up the priority of the path at a single int. If path not found, returns default priority"""
Base.@propagate_inbounds function get_path_priority_from_int(intObject::Dict{String,Any}, path::AbstractArray{Int64,1}, default::Int32)
	# Further improvements can be made by improving typing of intObject (too many "Anys").
	# Should probably prefer the Struct version rahter than dict version, where possible
	pathlen = size(path)[1]
	priorities_dict::Dict{Int64, Dict{Int64, Dict{String, Any}}} = intObject["priorities"]
	priority_keys::Base.KeySet{Int64, Dict{Int64, Dict{Int64, Dict{String, Any}}}} = keys(priorities_dict)
	for i in 1:pathlen-1  # searching for incoming node, but not the very last one - use 0
		if path[i] == path[i+1] && i > 1
			# println("Warning: end of path, but entry node not found at int: ", intObject["centroid_nodes"])
			return Int32(0)  # use ignore intersection functionality
		end
		if path[i] in priority_keys  # only if found in incoming nodes
			if i >= pathlen - 2  # no more nodes left
				return Int32(0)  # ignore intersection
			end
			_inNode = path[i]
			innode_keys::Base.KeySet{Int64,Dict{Int64,Dict{String,Any}}} = keys(priorities_dict[_inNode])
			c_nodes_raw = intObject["centroid_nodes"]  # convert raw nodes to ints, if string
			nodes::Vector{Int64} = convert_vec_to_number_type(c_nodes_raw)
			for o in i+1:pathlen  # searching for outgoing nodes
				if path[o] in nodes continue end # skip centroid nodes
				if path[o] in innode_keys
					_outNode = path[o]
					priority::Int32 = priorities_dict[_inNode][_outNode]["priority"]
					return priority
				end
			end
		end
	end
	@debug "Path $path tried to go through intersection $nodes, but priority was not found"
	return default
end


"""
	convert_vec_to_number_type(input_vec::Vector{U}; to_type::Type=Int64)

Converts vectors to ints, handling for element type being unstable upon being read in via a Json

# Arguments
- `input_vec`: Vector to be converted of dim
- `to_type`: Type of vector to convert input to. 
""" 
function convert_vec_to_number_type(input_vec::Vector{U}; to_type::Type=Int64) where U <: Any
	if length(input_vec) == 0
		@warn "Empty input vector"
		return to_type[]
	end
	
	if U <: AbstractString 
		method = parse
	elseif typeof(input_vec[1]) <: AbstractString
		method = parse
	else
		method = convert
	end

	resolved = method.(Float64, input_vec)
	if to_type <: Integer
		return Int.(resolved)
	end
	return convert.(to_type,resolved)
end
