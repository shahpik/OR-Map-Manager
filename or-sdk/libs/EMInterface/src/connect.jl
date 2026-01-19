"""
    connect(endpoint, kwargs...; kwargs...)
    connect(endpoint,
            ws_endpoint;
            token::String="",
            headers::Dict=Dict(),
            route="/graphql",
            sub_route="/subscriptions",
            introspect_config=true)

Connect to Experiment Manager GraphQL server.

Uses `endpoint` and `ws_endpoint` variables and performs full instropection
on the server. The client result is stored in a module level constant. If
`ws_endpoint` not supplied, assumed to be the same as `endpoint` with `http`
replaced with `ws`.

Note, `route` is appended to the end of `endpoint` and `sub_route` 
appended to the end of `ws_endpoint`.

An authentication token can be passed to `token`, and generic headers can be
passed as a `Dict` to `headers`. If both are provided, `token` is preferred in
the `headers`. The experiment config will be introspected and subsquently used
by get_configuration if `introspect_config` is set to true.

# Examples
```julia
julia> EMInterface.connect("http://localhost:5100", route="/graphql", sub_route="/subscriptions")
```
"""
connect(endpoint; kwargs...) = connect(endpoint, replace(endpoint, r"^(http)" => "ws"); kwargs...)
function connect(endpoint,
                 ws_endpoint;
                 token::String="",
                 headers::Dict=Dict(),
                 route="/graphql",
                 sub_route="/subscriptions",
                 introspect_config=true)

    full_endpoint = string(endpoint, route)
    full_ws_endpoint = string(ws_endpoint, sub_route)
    client = Client(full_endpoint, full_ws_endpoint, headers=set_headers(token, headers))
    if connected_to_client()
        @warn "Dropping connection to $(global_graphql_client().endpoint) and connecting to $(client.endpoint)"
    end
    global_graphql_client(client)

    # Create config struct
    try
        if introspect_config
            introspect_config_struct()
        else
            # Put in the defaults
            client.introspected_types = DEFAULT_CONFIG_TYPES[]
        end
    catch err
        @warn "Couldn't introspect ExperimentConfigurationObject, error is $(sprint(showerror, err))"
    end
    return
end

"""
    get_headers(token::String)

Builds header dictionary for Experiment Manager.
"""
function get_headers(token::String)
    if !isempty(token)
        headers = Dict("Authorization" => "Bearer $token")
    else
        headers = Dict()
    end
    return headers
end

"""
    set_headers(token::String, headers::Dict)

Preferentially updates the headers with the authorization token if it is non empty.
"""
function set_headers(token::String, headers::Dict)
    if !isempty(token)
        haskey(headers, "Authorization") && @warn "An Authorization token was provided and was set in the headers. Tokens are preferential and headers will be updated."
        headers["Authorization"] = "Bearer $token"
    end
    return headers
end

"""
    get_client()

Returns the GraphQL client if assigned, otherwise throws an exception.
"""
get_client() = global_graphql_client()

"""
    connected_to_client()

Returns `true` if EMInterface has connected to a client.
"""
connected_to_client() = isassigned(GraphQLClient.CLIENT)
