"""
    load_intersection_light_objects(intersections_file)

Reads a specially designed json file that has the essential info needed to 
generate int/lights data. For ScheduleGeneration/TrafficModel.

# Arguments
- `intersections_file`: File path with JSON array of dicts containing the fields
  - `int_pos`
  - `int_nodes`
  - `intObjects`
  - `nodeIntMap`: Map of node ids to the index/position of the int object, 
    allows pointing of complex nodes to correct intersection

# Returns
- `::Tuple`:
  - `::AbstractVector{<:AbstractDict}`: Populated intersection dictionaries.
  - `::Dict{Int64,Int64}`: Mapping of centroids to intersection indices.
  - `::Integer`: Number of intersections.
  - `::Vector{Bool}`: For each intersection, whether it has a light.
"""
Base.@propagate_inbounds function load_intersection_light_objects(intersections_file)
	intObjects = JSON3.read(open(intersections_file), Vector{Dict{String,Any}})
	nInts = size(intObjects)[1]
	@info "$nInts loaded from file: $intersections_file"
	return calculate_intersection_fields!(intObjects)
end

"""
    calculate_intersection_fields!(intObjects::AbstractVector{<:AbstractDict})

Populates the fields from a serialized JSON of intersections.

# Arguments
- `intObjects::AbstractVector{<:AbstractDict}`: Loaded JSON dict with fields:
  - `int_pos`
  - `int_nodes`
  - `intObjects`
  - `nodeIntMap`: Map of node ids to the index/position of the int object, 
    allows pointing of complex nodes to correct intersection

# Returns
- `::Tuple`:
  - `::AbstractVector{<:AbstractDict}`: Populated intersection dictionaries.
  - `::Dict{Int64,Int64}`: Mapping of centroids to intersection indices.
  - `::Integer`: Number of intersections.
  - `::Vector{Bool}`: For each intersection, whether it has a light.
"""
Base.@propagate_inbounds function calculate_intersection_fields!(intObjects::AbstractVector{<:AbstractDict})
	nInts = size(intObjects)[1]

	int_pos = Array{Float64,2}(undef, 2, nInts)  # 2 rows, (long lat), x
	# int_nodes = Array{Int64,1}()
	# intObjects = Vector{Dict{String,Any}}(undef, nInts)
	nodeIntMap = Dict{Int64,Int64}()  # for complex ints with multi-node centroids, know which int it's referring to
	has_lights = Vector{Bool}(undef, nInts)

	for i in 1:nInts
		_i = intObjects[i]  # reference to current light
		int_pos[1,i] = _i["centroid_lon"]
		int_pos[2,i] = _i["centroid_lat"]
		# append!(int_nodes, _i["centroid_nodes"])
		for val in _i["centroid_nodes"]
			val = typeof(val) == String ? parse(Int64, val) : val		
			push!(nodeIntMap, val=>i)
		end
		_i["centroid_nodes"] = typeof(_i["centroid_nodes"]) == Vector{String} ? parse.(Int64, _i["centroid_nodes"]) : _i["centroid_nodes"]

		# convert dict keys to ints (for easier node access)
		# for each inbound node key, and the out node keys
		# build a new dict with correct key types to replace old
		_priorityIn = Dict{Int, Dict{Int64, Dict{String, Any}}}()
		for (_k, _v) in _i["priorities"]  # inbound node
			_inkey = isa(_k, Int) ? _k : parse(Int, _k)
			_priorityOut = Dict{Int, Dict{String, Any}}()  # outbound node
			for (_ko, _vo) in _v
				_outkey = isa(_ko, Int) ? _ko : parse(Int, _ko)
				push!(_priorityOut, _outkey => _vo)
				# _priorityOut[_outkey]["priority"] = Int32(_priorityOut[_outkey]["priority"])
			end
			push!(_priorityIn, _inkey => _priorityOut)
		end
		_i["priorities"] = _priorityIn

		has_lights[i] = _i["has_light"]
	end
	return intObjects, nodeIntMap, length(intObjects), has_lights
end

"""
    function export_intersection_json(intersections::Vector{<:Intersection}, out_file::String)
    function export_intersection_json(intersections::Vector{<:Intersection})

Exporting generated intersection/intersection priorities into a JSON file (if `out_file`
supplied) or returns a `Dict`.

Converts all node ids to strings.
"""
function export_intersection_json(intersections::Vector{<:Intersection})
    output = Dict[]
    for (intid, int) in enumerate(intersections)
        for (_, out_dict) in int.path_priorities
            for (_, priorities) in out_dict
                if haskey(priorities, "via_nodes")
                    priorities["via_nodes"] = string.(priorities["via_nodes"])
                else
                    priorities["via_nodes"] = []
                end
            end
        end

        data = Dict(
            "centroid_nodes" => string.(int.centroid_nodes),
            "centroid_lat" => int.nodes[int.centroid_nodes[1]].location.lat,
            "centroid_lon" => int.nodes[int.centroid_nodes[1]].location.lon,
            "has_light" => int.has_light,
            "priorities" => int.path_priorities,
            # placeholder: ID being generated here, to be replaced with proper global intersection ID system
            "id" => string(intid)
        )
        push!(output, data)
    end
    return output
end
function export_intersection_json(intersections::Vector{<:Intersection}, out_file::String)
    intersections_dict = export_intersection_json(intersections)
    write(out_file, JSON3.write(intersections_dict))
    @info "Wrote intersections to disk: $out_file"
end
