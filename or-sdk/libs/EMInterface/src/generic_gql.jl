@doc """
    query(query_name, output_type::Type=Any; kwargs...)

Re-exported from GraphQLClient. For details of all arguments see `GraphQLClient` docstring.

# Examples
```julia
julia> # Get all configurations
julia> resp = query("getExperimentConfiguration", output_fields=["experimentName"])
julia> resp.data["getExperimentConfiguration"]
1-element Vector{Any}:
 Dict{String, Any}("experimentName" => "_exp_asd_std_asd_ver_0")
```
""" GraphQLClient.query

@doc """
    mutate(mutation_name, args::AbstractDict, output_type::Type=Any; kwargs...)

Re-exported from GraphQLClient. For details of all arguments see `GraphQLClient` docstring.

# Examples
Saving a configuration (in this example, it needs an output field)
```julia
julia> args = Dict("configUpdates" => Dict("experimentBase" => "exp", "studyName" => "std", "experimentType" => "HISTORIC"))
julia> output_fields = ["message"]
julia> resp = mutate("updateExperimentConfiguration", args, output_fields=output_fields)
julia> resp.data["updateExperimentConfiguration"]
Dict{String, Any} with 1 entry:
  "message" => "Created new experiment configuration, study name: std, experiment base: exp, version: 0"
```
""" GraphQLClient.mutate

@doc """
    open_subscription(fn::Function,
                      subscription_name,
                      output_type::Type=Any;
                      kwargs...)

Re-exported from GraphQLClient. For details of all arguments see `GraphQLClient` docstring.

# Examples
```julia
julia> args = Dict("segmentIds" => ["ID1"])
julia> output_fields = Dict("eventLogs"=>"eventId")
julia> open_subscription("subNewEvent", sub_args=args, output_fields=output_fields) do result
           fn(result)
       end
[ Info: Starting subNewEvent subscription with ID 1-1
```
""" GraphQLClient.open_subscription
