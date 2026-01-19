"""
    get_sol_data(experiment_name::AbstractString, sec_into_day::Integer)

Gets combined sol data for all agents for the provided experiment name in raw stringified
JSON format. Throws warning and returns nothing if the sol data is empty.
"""
function get_sol_data(experiment_name::AbstractString, sec_into_day::Integer)
    response = query(
        "getTrafficModelOutput",
        query_args=Dict(
            "experimentConfigurationId" => experiment_name,
            "unixTimestamp" => sec_into_day,
            "resultType" => "SOL_DATA",
        ) 
    )
    all_sol_data = response.data["getTrafficModelOutput"]
    if all_sol_data == "{}"
        @warn("SOL DATA was empty for $experiment_name at sec_into_day $sec_into_day, returning with no data")
        return nothing
    end
    return all_sol_data
end

"""
    get_combined_sol_data_for_all_agents(experiment_name::AbstractString, sec_into_day::Integer)

Gets combined sol data for all agents for the provided experiment name in a sol data dict, containing trip_id, pos, and vel.
"""
function get_combined_sol_data_for_all_agents(experiment_name::AbstractString, sec_into_day::Integer)
    all_sol_data = get_sol_data(experiment_name, sec_into_day)

    if isnothing(all_sol_data)
        return nothing
    end

    sol_data_dict = Dict(
        "trip_id" => Vector{String}(),
        "pos" => Vector{Vector{Float64}}(),
        "vel" => Vector{Vector{Float64}}(),
    )

    temp_data_dict = JSON3.read(all_sol_data, Dict{String, Dict{String, Dict}})
    
    for (_, agent_sol_data) in temp_data_dict["sim_agents"]
        append!(sol_data_dict["trip_id"], agent_sol_data["data"]["trip_id"])
        append!(sol_data_dict["pos"], agent_sol_data["data"]["p"])
        append!(sol_data_dict["vel"], agent_sol_data["data"]["v"])
    end

    return sol_data_dict
end

"""
    get_sol_data_per_agent_dict(experiment_name::AbstractString, sec_into_day::Integer)

Gets the sol data for each agent and returns it in a agent keyed dictionary with non-typed data values.
This format should be type processed as data values are of Any type.
"""
function get_sol_data_per_agent_dict(experiment_name::AbstractString, sec_into_day::Integer)
    all_sol_data = get_sol_data(experiment_name, sec_into_day)

    if isnothing(all_sol_data)
        return nothing
    end

    temp_data_dict = JSON3.read(all_sol_data, Dict{String, Dict{String, Dict}})
    output_agent_sol_data_dict = Dict()
    
    for (agent_name, agent_sol_data) in temp_data_dict["sim_agents"]
        output_agent_sol_data_dict[agent_name] = agent_sol_data["data"]
    end

    return output_agent_sol_data_dict
end