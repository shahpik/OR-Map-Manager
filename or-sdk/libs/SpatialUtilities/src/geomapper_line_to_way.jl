""" 
    get_best_way_path_from_linestring(g, linestring, g_tree, error_fn::Function; apad=45, bpad=0.0007)

Finds the best way path from a linestring, using that minimises error metric

DEPRECATED! Use `match_linestring` instead.

# Arguments
- `g::OSMGraph`: LightOSM Graph
- `linestring`: Vector of Vector Lat longs, expects in xy (i.e. lon-lat) format
- `g_tree`: rtree built from the lightosm graph, using the get_osm_rtree method
- `error_fn`: One of the error functions used to evaluate way path against linestring
- `apad=45`: Angle Padding, how much ways are allowed do deviate from linestring angle in initial search 
- `bpad=0.001` Bounding box padding in lat-long degrees, how much area around the linestring to search
- `weights_t=nothing`: Optional transposed weights matrix, see docs for get_adjacent_nodes_on_graph
"""
function get_best_way_path_from_linestring(g, 
                                           linestring, 
                                           g_tree, 
                                           error_fn::Function; 
                                           apad=45, 
                                           bpad=0.0007, 
                                           weights_t=nothing, 
                                           return_error=false)
    Base.depwarn(
        "`get_best_way_path_from_linestring` is deprecated and has been" *
        "replaced with `match_linestring`, which uses a new matching method. " * 
        "`match_linestring` has been called automatically here but this " *
        "will be removed in a future release!",
        :get_best_way_path_from_linestring
    )
    match = match_linestring(g, linestring, g_tree)
    if return_error
        return isnothing(match) ? missing : (match.matched_ways, 0.0)
    end
    return isnothing(match) ? missing : match.matched_ways
end

""" 
Multi-threaded search for all a list of all way paths. 
This implementation modifies a geojson with the updated linestrings
"""
function get_all_way_paths!(g, gjson, g_tree, err_fn::Function)
    Base.depwarn(
        "`get_all_way_paths!` is deprecated and has been replaced with " *
        "`match_geojson_linestrings`, which uses a new matching method. " * 
        "`match_geojson_linestrings` has been called automatically here but " *
        "this will be removed in a future release!",
        :get_all_way_paths!
    )

    total_count = length(gjson["features"])
    nthread = Threads.nthreads()  # check n threads loaded
    @info "Running mapper across $nthread theads"
    lk = Threads.ReentrantLock()
    counter = 0
    weights_t = copy(transpose(g.weights))  # transposed weights, for fast column lookup
    errors = Union{Float64, Missing}[]

    Threads.@threads for i = 1:total_count
        ls_data = gjson["features"][i]
        lsc = ls_data["geometry"]["coordinates"]
        mapped_ways, error = get_best_way_path_from_linestring(g, lsc, g_tree, err_fn, weights_t=weights_t, return_error=true)
        push!(errors, error)
        if !isempty(mapped_ways)
            ls_data["properties"]["way_path"] = get_way_path_dir_oab(g, mapped_ways)
            ls_data["properties"]["error"] = error
            ls_data["geometry"]["coordinates"] = get_way_ls_coords(g, mapped_ways)
        else
            ls_data["properties"]["way_path"] = ""
            ls_data["properties"]["error"] = ""
            ls_data["geometry"]["coordinates"] = ""
        end
        lock(lk)
        try
            counter += 1
            id = get(ls_data["properties"], "id", "")
            @info "Doing $counter/$total_count for id $id on thread: $(Threads.threadid())"
        finally
            unlock(lk)
        end
    end

    return errors
end
