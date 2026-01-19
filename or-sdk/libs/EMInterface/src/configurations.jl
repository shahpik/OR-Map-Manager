"""
     build_config_output_fields(output_fields, agent_fields)

Takes vectors of field names (as strings) and nests them correctly for the output fields
argument of configuration queries and mutations.

Following structure is required by the Experiment Manager.
```
{
    output_field1
    output_field2
    agentConfigurations : {
        agent_field1
        agent_field2
    }
}
And is acheived by using `Dict`s to represent levels, as per GraphQLClient documentation.
```
"""
function build_config_output_fields(output_fields, agent_fields)
    output_fields = convert(Vector{Any}, output_fields)  # So we can push Dicts to it
    !isempty(agent_fields) && push!(output_fields, Dict("agentConfigurations" => agent_fields))
   return output_fields
end

"""
    get_configuration(experimentName::String;
                      search_args::Dict=Dict(),
                      output_fields::Vector=String[],
                      agent_fields::Vector=String[],
                      dict_output::Bool=false)
    get_configuration(;search_args::Dict=Dict(),
                      output_fields::Vector=String[],
                      agent_fields::Vector=String[],
                      dict_output::Bool=false)

Get configurations from the Experiment Manager. If all the output field arguments are empty,
then all fields are returned. If no matching confurations  exist, `nothing` is returned.

If supplied with `experimentName`, the returned config is a `Config` or a dictionary.
Otherwise, it is an array of `Config`s/dictionaries.

# Arguments
- `experimentName::String`: name of experiment. This is optional, and can also be included in `search_args`.
- `output_fields::Vector=String[]`: output fields to be returned (this includes updatedConfig fields). Elements
    of the vector can either be `String`s, `Dict{String, String}` or `Dict{String, Vector{String}}`.
- `agent_fields::Vector=String[]`: output fields for agentConfiguration. Elements of the vector can either be
    `String`s, `Dict{String, String}` or `Dict{String, Vector{String}}`.
- `dict_output::Bool=false`: if `true`, returns `Config`(s) rather than `Dict`(s).
 
# Examples
```julia
julia> get_configuration()  # Get all configurations
18-element Array{Any, 1}: ...

julia> get_configuration("_exp_Exp1_std_Study1_ver1")
Dict{String, Any} with 59 entries: ...

julia> get_configuration("_exp_Exp1_std_Study1_ver1", output_fields=["nSimulations"])
Dict{String ,Any} with 1 entry:
  "nSimulations" => 1

julia> get_configuration("_exp_Exp1_std_Study1_ver1", output_fields=["nSimulations"], agent_fields=["agentType"]))
Dict{String, Any} with 2 entries:
  "nSimulations"        => 1
  "agentConfigurations" => Any[]
```
"""
function get_configuration(experimentName::String;
                           search_args::Dict=Dict(),
                           kwargs...)

    config = get_configuration(;search_args=merge_exp_name!(search_args, experimentName), kwargs...)
    return isnothing(config) ? nothing : config[1]
end
function get_configuration(;search_args::Dict=Dict(),
                           output_fields::Vector=String[],
                           agent_fields::Vector=String[],
                           dict_output::Bool=false)

    check_valid_search(search_args, "getExperimentConfiguration")
    output_fields = build_config_output_fields(output_fields, agent_fields)
    response = query(get_client(), "getExperimentConfiguration", query_args=search_args, output_fields=output_fields)
    config = response.data["getExperimentConfiguration"]

    if isempty(config)
        @info "No configuration(s) found"
        return nothing
    end
    return dict_output ? config : build_config_struct.(config)
end

"""
    save_configuration(experimentBase,
                       studyName;
                       updateExisting=true,
                       setConfigParams=Dict(),
                       agentBuilder::Union{Dict, Vector{Dict}}=Dict[],
                       testBuilder::Union{Dict, Vector{Dict}}=Dict[],
                       output_fields::Vector{<:String}=String[], 
                       agent_fields::Vector{<:String}=String[]
                       )

Save a configuration, returning a dictionary containing the `message` and any output fields
in `configOut`.

# Arguments
- `experimentBase`: experiment base.
- `studyName`: study name.
- `updateExisting=true`: set to true to create a new versino of the experiment if one already exists.
- `configUpdates=Dict()`: dictionary containing configUpdates arguments in key value pairs.
- `agentConfiguration::Union{Dict, Vector{Dict}}=Dict[]`: dictionary containing agentConfiguration
    arguments in key value pairs, or a vector containing similar dictionaries.
- `output_fields::Vector{<:String}=String[]`: top level output fields to be returned (this includes
configUpdates fields). Note `message` and `experimentName` are automatically returned.
- `agent_fields::Vector{<:String}=String[]`: output fields for `agentConfiguration`.

# Examples
```julia
julia> save_configuration("exp","std")
Dict{String, Any} with 2 entries:
  "updatedConfig" => Dict{String, Any}("experimentName"=>"_exp_std_std_exp_ver_0")
  "message"       => "Created new experiment configuration, study name: std, experiment base: exp, version: 0"

julia> configUpdates = Dict("nSimulations" => 8)
julia> save_configuration("exp", "std", output_fields=["experimentName", "nSimulations"], configUpdates=configUpdates)
Dict{String, Any} with 2 entries:
  "updatedConfig" => Dict{String, Any}("experimentName"=>"_exp_std_std_exp_ver_1", "nSimulations"=>8)
  "message"       => "Updated experiment configuration, study name: std, experiment base: exp, version: 1"

julia> configUpdates = Dict("nSimulations" => 8)
julia> agentConfiguration = Dict("agentType" => "GND_car_generic", "agentConfigurationName" => "1")
julia> agent_fields = ["agentType""]
julia> save_configuration("exp", "std", output_fields=["experimentName", "nSimulations"], configUpdates=configUpdates, agentConfiguration=agentConfiguration, agent_fields=agent_fields)
Dict{String, Any} with 2 entries:
  "updatedConfig" => Dict{String, Any}("experimentName"=>"_exp_std_std_exp_ver_2", "nSimulations"=>8, "agentConfigurations"=>Any[Dict{String, Any}("agentType"=>"GND_car_generic")])
  "message"       => "Updated experiment configuration, study name: std, experiment base: exp, version: 2"
```
"""
function save_configuration(experimentBase,
                            studyName;
                            updateExisting=true,
                            configUpdates=Dict(),
                            agentConfiguration::Union{Dict, Vector{<:Dict}}=Dict[],
                            output_fields::Vector{<:String}=String[], 
                            agent_fields::Vector{<:String}=String[]
                            )
    
    all_configUpdates = Dict{String, Any}(
        "studyName" => studyName, 
        "experimentBase" => experimentBase, 
        "updateExisting" => updateExisting
    )
    merge!(all_configUpdates, convert(Dict{String, Any}, configUpdates))
    !isempty(agentConfiguration) && push!(all_configUpdates, "agentConfigurations" => isa(agentConfiguration, Vector) ? agentConfiguration : [agentConfiguration])
    args = Dict{String, Any}()
    !isempty(all_configUpdates) && push!(args, "configUpdates" => all_configUpdates)

    # Add output results, ensuring message and experimentName is returned
    output_fields = unique(push!(output_fields, "experimentName"))
    output_fields = build_config_output_fields(output_fields, agent_fields)
    output_fields = ["message", Dict("updatedConfig" => output_fields)]

    @show output_fields
    # Run mutation
    response = mutate(get_client(), "updateExperimentConfiguration", args, output_fields=output_fields)
    result = response.data["updateExperimentConfiguration"]
    @info "Configuration saved, experiment name: $(result["updatedConfig"]["experimentName"])"
    return result
end

"""
    execute_configuration(experimentName::String,
                          app::String;
                          output_fields::Vector{<:String}=String[],
                          apps_to_reset::Vector=String[])
    execute_configuration(experimentName::String,
                          apps::Vector;
                          output_fields::Vector{<:String}=String[],
                          apps_to_reset::Vector=String[])

Execute configuration `experimentName`.

# Arguments
- `experimentName::String`: experiment to be executed.
- `apps`: app name or vector of apps to be executed.
- `output_fields::Vector{<:String}=String[]`: fields to be returned
    (note, message is automatically returned).
- `apps_to_reset::Vector=String[]`: add in the names of
    applications to reset the application data of.
"""
function execute_configuration(experimentName::String, apps::String; kwargs...)
    return execute_configuration(experimentName, [apps]; kwargs...)
end
function execute_configuration(experimentName::String,
                               apps::Vector;
                               output_fields=String[],
                               apps_to_reset::Vector=String[])

    args = Dict{String, Any}(
        "experimentName" => experimentName,
        "resetApplicationData" => apps_to_reset,
    )
    push!(args, "appsToExecute" => apps)
    output_fields = convert(Vector{<:Any}, output_fields)
    push!(output_fields, "message")
    result = mutate(get_client(), "executeExperimentConfiguration", args, output_fields=output_fields)
    return result
end

"""
    subscribe_to_config(fn, experiment_name, application::String; kwargs...)
    subscribe_to_config(fn,
                        experiment_name,
                        applications::Vector;
                        application_output_fields=String[],
                        config_output_fields=String[],
                        subtimeout=0,
                        stopfn=nothing,
                        initfn=nothing)

Subscribe to config specified by `experiment_name` and run `fn` on each
result recieved.

# Arguments
- `experiment_name`: experiment name of configuration to subscibe too
- `applications::Vector`: list of applications to subscribe to.
- `application_output_fields=String[]`: fields to include in subscription
    response. If nothing entered, all fields of applicationData are returned.
- `config_output_fields=String[]`: config fields to include in subscription
    response. If nothing entered, no fields are returned.
- `subtimeout=0`: see `open_subscription` documentation.
- `stop_fn=nothing`: see `open_subscription` documentation.
- `init_fn=nothing`: see `open_subscription` documentation.
"""
subscribe_to_config(fn, experiment_name, application::String; kwargs...) = subscribe_to_config(fn, experiment_name, [application]; kwargs...)
function subscribe_to_config(fn, 
                             experiment_name,
                             applications::Vector;
                             application_output_fields=String[],
                             config_output_fields=String[],
                             subtimeout=0,
                             stopfn=nothing,
                             initfn=nothing)

    isempty(application_output_fields) && append!(application_output_fields, string.(get_introspected_type("ApplicationDataObject")))
    
    output_fields = Any[Dict("applicationData" => application_output_fields)]
    append!(output_fields, config_output_fields)

    EMInterface.open_subscription(
        "subExperimentConfiguration",
        sub_args=Dict(
            "experimentName" => experiment_name,
            "applicationNames" => applications,
        ),
        output_fields=output_fields,
        retry=true,
        subtimeout=subtimeout,
        stopfn=stopfn,
        initfn=initfn,
        ) do result
            config = result.data["subExperimentConfiguration"]
            fn(build_config_struct(config))
    end
end