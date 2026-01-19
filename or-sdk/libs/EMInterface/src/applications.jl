####################
# Application Data #
####################

"""
    update_app_data(experiment_name,
                    app_name;
                    result_ids::Union{Int, Vector{<:Int}}=Int[],
                    execution_params::Union{String, Dict}=Dict{String, String}(),
                    progress_percent::Float64=-1.0)

Updates the application data for `app_name` in the experiment configuration
with experiment name `experiment_name`.

`result_ids` are appended to existing ids, values in execution param dictionary
are updated or added, and the progress percent is updated.
"""
function update_app_data(experiment_name,
                         app_name;
                         result_ids::Union{String, Vector{<:String}}=String[],
                         execution_params::Union{String, Dict}=Dict{String, String}(),
                         progress_percent::Float64=-1.0)
    
    application_data = Dict{String, Any}()

    # Result ids
    result_ids_list = isa(result_ids, Int) ? [result_ids] : result_ids
    !isempty(result_ids_list) && push!(application_data, "resultIds" => result_ids_list)

    # Execution params
    execution_params_str = isa(execution_params, String) ? execution_params : JSON3.write(execution_params)
    !isempty(execution_params) && push!(application_data, "executionParameters" => execution_params_str)

    # Progress percent
    progress_percent >= 0.0 && push!(application_data, "progressPct" => progress_percent)

    isempty(application_data) && throw(ExperimentManagerException("No application data inputted to update_app_data"))

    # If there is data, add name to dict and mutate
    push!(application_data, "name" => app_name)

    return mutate(
        "updateApplicationData",
        Dict(
            "experimentName" => experiment_name,
            "applicationDataUpdates" => [application_data]
        ),
        output_fields=["message"]
    )
end

"""
    query_app_data(experiment_name, fields)

Query applicationData field of configuration specified by `experiment_name`.
"""
function query_app_data(experiment_name, fields)
    if isempty(fields)
        append!(fields, string.(fieldnames(get_introspected_type("ApplicationDataObject"))))
    end

    !in("name", fields) && push!(fields, "name")

    config = get_configuration(
        experiment_name,
        output_fields = [Dict("applicationData" => fields)]
    )
    return config
end

"""
    get_app_data(config::AbstractConfig, app_name::AbstractString)
    get_app_data(config::AbstractConfig, app_names::AbstractVector)

Extract application data from config for apps specified.
    
Note, if when downloading the original config the applicationData field
and necessary subfields were not included in the `output_fields` keyword
argument of `get_configuration`, then they won't be available here. If that
is the case then use `get_app_data(config.experimentName, app_name)` to get
the corresponding fields from the Experiment Manager, or add those fields
to the call to `get_configuration`.
"""
function get_app_data(config::AbstractConfig, app_name::AbstractString)
    if !isnothing(config.applicationData) && !isempty(config.applicationData)
        for app_data in config.applicationData
            app_data.name == app_name && return app_data
        end
    end
    # Application data doesn't exist for this app OR
    # applicationData fields were just not included in get_configuration query
    @info "No app data found for $app_name in the config object supplied to get_app_data.\nEmpty app data struct will be returned."
    return initialise_introspected_struct("ApplicationDataObject")
end
function get_app_data(config::AbstractConfig, app_names::AbstractVector)
    app_data = get_introspected_type("ApplicationDataObject")
    if !isnothing(config.applicationData) && !isempty(config.applicationData)
        for individual_app_data in config.applicationData
            in(individual_app_data.name, app_names) && push!(app_data, individual_app_data)
        end
    end
    # Application data doesn't exist for any apps requested OR
    # applicationData fields were just not included in get_configuration query
    if length(app_data) == 0
        @info "No app data found for any of the requested apps in the config supplied to get_app_data.\nEmpty vector will be returned."
    elseif length(app_data) < length(app_names)
        @info "No app data found for some of the requested apps in the config supplied to get_app_data."
    end
    return app_data
end

"""
    get_app_data(experiment_name::String; fields=String[])
    get_app_data(experiment_name::String, app_name::AbstractString; fields=String[])
    get_app_data(experiment_name::String, app_names::AbstractVector; fields=String[])

Get application data for `app_name` in configuration of `experiment_name`
by querying the configuration. Fields to return can be specified by `fields`.

If multiple names are supplied, a `Vector` is returned. If no app names are supplied,
application data for all apps returned in a `Vector`.
"""
function get_app_data(experiment_name::String, app_name::AbstractString; fields=String[])
    config = query_app_data(experiment_name, fields)
    return get_app_data(config, app_name)
end
function get_app_data(experiment_name::String, app_names::AbstractVector; fields=String[])
    config = query_app_data(experiment_name, fields)
    return get_app_data(config, app_names)
end
function get_app_data(experiment_name::String; fields=String[])
    config = query_app_data(experiment_name, fields)
    return config.applicationData
end