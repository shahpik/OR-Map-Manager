"""
    merge_exp_name!(search_args, experimentName)

Ensure `search_args` is a `Dict{String, Any}` and add `experimentName`.
"""
function merge_exp_name!(search_args, experimentName)
    search_args = convert(Dict{String, Any}, search_args)
    merge!(search_args, Dict("experimentName" => experimentName))
    return search_args
end

"""
    check_valid_search(search_args::Dict, query::String)

Error if any keys of `search_args` are not allowed to be used in `query`. If a full
introspection of the GraqphQL server has been completed, the arguments are compared
to the schema. If not, they are compared to hardcoded lists in this function.
"""
function check_valid_search(search_args::Dict, query::String)
    if get_client().introspection_complete
        @debug "Using introspected GQL server schema to check allowed search fields."
        allowed_keys = keys(get_client().query_to_args_map[query])
    else
        @debug "GQL schema not available, using hardcoded lists of allowed search fields."
        if query == "getSimulation"
            allowed_keys = ("experimentName", "primaryKey", "simName", "objectId", "p", "timestamp")
        elseif query == "getSimulationAgent"
            allowed_keys = ("experimentName", "primaryKey", "simName", "objectId")
        elseif query == "getConfigurations"
            allowed_keys = ("experimentName", "studyName", "experimentBase", "configParent",
                            "createdBy")
        else
            throw(ExperimentManagerException("No available search fields for query \"$query\".\nIf not expected, try running full_introspection() to get schema"))
        end
    end

    map(collect(keys(search_args))) do key
        if !(key in allowed_keys)
            throw(ExperimentManagerException("Cannot search simulation results on field \"$key\""))
        end
    end
end

"""
    macro async_display_errors expr

Wraps `expr` in a try catch and runs it aysnchronously. If an error is thrown,
this is displayed as a warning.

# Examples
```julia
julia> @async_display_errors foo(bar)
```
"""
macro async_display_errors(expr)
    caught_expr = quote
        @async try
            $(esc(expr))
        catch err
            @error "Async function failed: $(typeof(err))" exception=(err, catch_backtrace())
        end
    end
    return caught_expr
end

######################
# sec_into_day_calcs #
######################
# TODO: Since these calculations are now centralised, remove duplication in other services.

"""
    round_to_nearest(num, base)

Round to nearerst `base`.

# Examples

```julia
julia> round_to_nearest(1,10)
0
julia> round_to_nearest(11,10)
10
```
"""
round_to_nearest(num, base) = base * round(Int, num / base)

"""
    floor_to_nearest(num, base)

Floor to nearerst `base` to ensure numbers align for different bases.

# Examples

```julia
julia> floor_to_nearest(1,10)
0
julia> floor_to_nearest(6,10)
0
julia> floor_to_nearest(11,10)
10
julia> floor_to_nearest(11,10)
10
```
"""
floor_to_nearest(num, base) = base * floor(Int, num / base)


"""
    sec_into_day_from_timestamp(timestamp::Integer, frequency::Integer)
    sec_into_day_from_timestamp(timestamp::Integer, frequency)
    sec_into_day_from_timestamp(timestamp::Float64, frequency)

From a unix timestamp, get the seconds into day floored to the frequency specified.
"""
sec_into_day_from_timestamp(timestamp::Integer, frequency::Integer) = floor_to_nearest(timestamp % 86400, frequency)
sec_into_day_from_timestamp(timestamp::Integer, frequency) = floor_to_nearest(timestamp % 86400, floor(Int, frequency))
sec_into_day_from_timestamp(timestamp::Float64, frequency) = sec_into_day_from_timestamp(floor(Int, timestamp), floor(Int, frequency))