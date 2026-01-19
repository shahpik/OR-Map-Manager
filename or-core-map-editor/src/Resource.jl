"""
`Resource` handles the creation of the HTTP server and the endpoints.

By default, the following endpoints are set:
- `/live` - used to check microservice is live. Returns status 200 and "OK"
- `/ready` - used to check microservice is ready. Returns status 200 and "READY" if ready. By default, the microservice checks that the Experiment Manager is ready.
- `/execute` - calls `App.execute_app()` with the request
- `/version` - returns the version of this app
- `/dependency` - returns the service (not package) dependencies as configured in the project.toml

"""
module Resource

using EMInterface
using HTTP
using JSON3
using UUIDs: uuid4
using ..App
using ..Workers

include("Dependency.jl")
using .Dependency

export EXPERIMENT_MANAGER_ENDPOINT, EXPERIMENT_MANAGER_WS_ENDPOINT

"HTTP Router"
const ROUTER = HTTP.Router()
"App port number, set by environment variable APP_PORT"
const APP_PORT = Ref{String}()
"App address, set by environment variable APP_ADDRESS"
const APP_ADDRESS = Ref{String}()
"Experiment Manager Endpoint, set by environment variable EXPERIMENT_MANAGER_ENDPOINT"
const EXPERIMENT_MANAGER_ENDPOINT = Ref{String}()
"Experiment Manager Websocket Endpoint, set by environment variable EXPERIMENT_MANAGER_WS_ENDPOINT"
const EXPERIMENT_MANAGER_WS_ENDPOINT = Ref{String}()

"""
    __init__()

Set values of all constants that take value from environment variables.

Must be done at runtime, otherwise values will be compiled into system image
and be fixed.
"""
function __init__()
    APP_PORT[] =  get(ENV, "APP_PORT", "6703")
    APP_ADDRESS[] = get(ENV, "APP_ADDRESS", "0.0.0.0")
    EXPERIMENT_MANAGER_ENDPOINT[] = get(ENV, "EXPERIMENT_MANAGER_ENDPOINT", "http://localhost:5100")
    EXPERIMENT_MANAGER_WS_ENDPOINT[] = get(ENV, "EXPERIMENT_MANAGER_WS_ENDPOINT", "ws://localhost:5100")
end

"""
    version(req)
"""
function version(req)
    return Dependency.get_project_version()
end
HTTP.@register(ROUTER, "/version", version)
"""
    dependency(req)
"""
function dependency(req)
    return JSON3.write(Dependency.get_project_service_dependencies())
end
HTTP.@register(ROUTER, "/dependency", dependency)


### Liveness and readiness functions
"""
    live(req)

Returns text "OK".
"""
live(req) = "OK"
HTTP.@register(ROUTER, "/live", live)

"""
    experiment_manager_ready()::Bool

Return `true` if the Experiment Manager is ready.
"""
function experiment_manager_ready()::Bool
    EM_ready_endpoint = string(EXPERIMENT_MANAGER_ENDPOINT[], "/ready")
    try
        resp = HTTP.request("GET", EM_ready_endpoint, [])
        return resp.status == 200
    catch
        @warn "Could not connect to $EM_ready_endpoint"
        return false
    end
end

"""
    ready(req="")

Check if the application is ready. Returns code 200 and "READY" if so,
and code 503 and a message if not.
"""
function ready(req="")
    # Check EM connection
    !experiment_manager_ready() && return 503, "NOT READY - Experiment Manager is not ready or could not be reached."

    # Add any other readiness checks here

    return 200, "READY"
end
HTTP.@register(ROUTER, "/ready", ready)

# App execution
# Run asynchronously on any thread except for the main thread
function execute_app(req)
    params = HTTP.queryparams(HTTP.URI(req.target))
    !haskey(params, "experiment_name") && error("Missing param experiment_name in HTTP target")
    # If no response needed, just use Workers.@async
    Workers.@async App.execute_app(params["experiment_name"])
    return "App executed"
    # If response is needed, use and fetch Workers.@async
    # return fetch(Workers.@async(App.execute_app(["experiment_name"])))
end
HTTP.@register(ROUTER, "/execute", execute_app)

function execute_create_changeset(req)
    # Read the HTTP Post request and separate into inputs
    println(req)
    body = JSON3.read(String(req.body))
    layer_id = body.layer_id
    userName = body.userName
    e_changeset_edit_type = body.e_changeset_edit_type
    code = 200
    msg = nothing
    try 
        blocking_changeset = App.validate_changeset(layer_id)
        if blocking_changeset != "EMPTY" 
            msg = "MapEditor - changeset creation blocked by $blocking_changeset"
            @info msg
            code = 500
        else 
            msg = App.create_changeset(layer_id, userName = userName, e_changeset_edit_type = e_changeset_edit_type)
            msg isa Exception && rethrow(msg)
            code = 200 
            @info "MapEditor - changeset successfully created"
        end
    catch err
        @error "MapEditor - creation of new changeset for $layer_id failed due to " exception=(err, catch_backtrace())
        msg = "MapEditor - creation of new changeset for $layer_id failed - check logs for error details"
        code = 400
    end
    return code, msg
end
HTTP.@register(ROUTER, "/changeset/create", execute_create_changeset)


function execute_edit_relationship(req)
    body = JSON3.read(req.body, Dict)

    changeset_id = body["changeset_id"]
    if isnothing(changeset_id)
        return 500, "Changeset id must be provided"
    end

    input_feature_id = body["input_feature_id"]
    if isnothing(input_feature_id)
        return 500, "Input feature id must be provided"
    end

    matched_feature_ids = body["matched_feature_ids"]
    matched_feature_ids = [string(matched_feature_id) for matched_feature_id in matched_feature_ids]
    
    if isnothing(matched_feature_ids)
        return 500, "Matched feature ids must be provided"
    end

    try
        is_changeset_exists = App.is_changeset_exists(changeset_id)
        if is_changeset_exists[1] == 200
            App.edit_relationship(changeset_id, input_feature_id, matched_feature_ids)
        end
    catch e
        rethrow(e)
    end
end
HTTP.@register(ROUTER, "/edit/relationship", execute_edit_relationship)


function execute_publish_changeset(req)
    # Read the HTTP Post request and separate into inputs
    println(req)
    body = JSON3.read(String(req.body))
    @info "request body is: '$body'"
    changeset_id = body.changeset_id
    if isnothing(changeset_id)
        return 500, "Changeset id must be provided"
    end
    code = 200
    msg = nothing
    try
        blocking_changeset = App.validate_unpublished_changeset_source_update(changeset_id)
        if blocking_changeset != "EMPTY"
            msg = "MapEditor - changeset creation blocked by $blocking_changeset"
            @info msg
            code = 500
        else
            msg = App.publish_changeset(changeset_id)
            msg isa Exception && rethrow(msg)
            code = 200
            @info "MapEditor - changeset successfully published"
        end
    catch err
        @error "MapEditor - Error publishing changeset" exception=(err, catch_backtrace())
        msg = "MapEditor - Error publishing changeset"
        code = 400
    end
    return code, msg
end
HTTP.@register(ROUTER, "/changeset/publish", execute_publish_changeset)


function execute_reject_edit(req)
    # Read the HTTP Post request into a dictionary
    println(req)
    body = JSON3.read(req.body, Dict)

    # Access and check whether changeset_id was provided
    changeset_id = body["changeset_id"]
    if isnothing(changeset_id)
        return 500, "Changeset id must be provided"
    end

    # Recover list of rejected_feature_ids and convert to a vector of strings
    rejected_feature_ids = body["rejected_feature_ids"]
    rejected_feature_ids = [string(feat_id) for feat_id in rejected_feature_ids]
    
    if isnothing(rejected_feature_ids)
        return 500, "Rejected feature ids must be provided"
    end
    
    code = 200
    msg = nothing
    try
        msg = App.reject_edit(changeset_id, rejected_feature_ids)
        msg isa Exception && rethrow(msg)
        code = 200
        @info "MapEditor - features successfully marked as rejected"
    catch err
        @error "MapEditor - Error rejecting feature_ids" exception=(err, catch_backtrace())
        msg = "MapEditor - Error rejecting feature_ids"
        code = 400
    end
    return code, msg

end
HTTP.@register(ROUTER, "/changeset/feature/reject", execute_reject_edit)


function execute_restore_edit(req)
    # Read the HTTP Post request into a dictionary
    println(req)
    body = JSON3.read(req.body, Dict)

    # Access and check whether changeset_id was provided
    changeset_id = body["changeset_id"]
    if isnothing(changeset_id)
        return 500, "Changeset id must be provided"
    end

    # Recover list of restored_feature_ids and convert to a vector of strings
    restored_feature_ids = body["restored_feature_ids"]
    restored_feature_ids = [string(feat_id) for feat_id in restored_feature_ids]
    
    if isnothing(restored_feature_ids)
        return 500, "Restored feature ids must be provided"
    end
    
    code = 200
    msg = nothing
    try
        msg = App.restore_edit(changeset_id, restored_feature_ids)
        msg isa Exception && rethrow(msg)
        code = 200
        @info "MapEditor - features successfully restored"
    catch err
        @error "MapEditor - Error restoring feature_ids" exception=(err, catch_backtrace())
        msg = "MapEditor - Error restoring feature_ids"
        code = 400
    end
    return code, msg

end
HTTP.@register(ROUTER, "/changeset/feature/restore", execute_restore_edit)


function execute_edit_attribute(req)
    body = JSON3.read(String(req.body))

    changeset_id = body.changeset_id
    if isnothing(changeset_id)
        return 500, "Changeset id must be provided"
    end
    feature_id = body.feature_id
    if isnothing(feature_id)
        return 500, "Feature id must be provided"
    end

    attributes = body.attributes
    if isnothing(attributes)
        return 500, "Attribute id must be provided"
    end

    for attribute in attributes
        s_name = attribute["s_name"]
        s_value = attribute["s_value"]
        if s_name in ["RD_NUM", "RMANUM"] && (length(s_value)!= 4 || all(isdigit, s_value) == false)
            return 500, "This attribute value must be exactly 4 digits" 
        end
    end
    
    attribute_ids = String[]
    try
        is_changeset_exists = App.is_changeset_exists(changeset_id)
        if is_changeset_exists[1] == 200
            for attribute in attributes
                s_name = attribute["s_name"]
                s_value = attribute["s_value"]
                attribute_id = App.edit_attributes(changeset_id, feature_id, s_name, s_value)
                @info "attribute id is: $attribute_id"
                push!(attribute_ids, attribute_id)
            end
            attribute_json = JSON3.write(Dict("attribute_ids" => attribute_ids))
            return attribute_json
        end
    catch e
        rethrow(e)
    end
end
HTTP.@register(ROUTER, "/edit/attribute", execute_edit_attribute)

### Define request handler

"""
    format_response(resp::HTTP.Messages.Response) = resp
    format_response(resp::Exception) = HTTP.Response(400, string(resp))
    format_response(resp) = format_response((200, resp))
    format_response(resp::Tuple{Int64, Any})

Take output from `HTTP.handle` and format into `HTTP.Response`
"""
format_response(resp::HTTP.Messages.Response) = resp
format_response(resp::Exception) = HTTP.Response(400, string(resp))
format_response(resp) = format_response((200, resp))
function format_response(resp::Tuple{Int64, Any})
    # Response includes the status, so use it
    # If object is a string, return as is. Otherwise write with JSON3.
    status, obj = resp
    return HTTP.Response(status, obj isa String ? obj : JSON3.write(obj))
end

"""
    requestHandler(req)

Handles all HTTP requests. They are passed to the router via `HTTP.handle`.
Accepted response types from the handle (and therefore the functions called
by endpoints) are:
- `HTTP.Messages.Reponse` - Response is returned directly.
- `Tuple{Int64, Any}` - First element of tuple is returned as the status code,
    second element is returned as text (if `String`) or written with `JSON3.write`.
- `Any` - Status 200 returned, and response is returned as text (if `String`) or
    written with `JSON3.write`.
"""
function requestHandler(req)
    # Attach http request id to headers
    if !haskey(Dict(req.headers), "X-Request-Id")
        id_key = SubString("X-Request-Id")
        id_value = SubString((string(uuid4())))
        push!(req.headers, Pair(id_key, id_value))
    end

    try
        resp = HTTP.handle(ROUTER, req)
        return format_response(resp)
    catch err
        @error "Function failed: $(typeof(err))" exception=(err, catch_backtrace())
        return format_response(err)
    end
end

### Run function
"""
    run()

This is the top level run function for the application. It starts a HTTP server.
"""
function run()
    HTTP.serve(requestHandler, APP_ADDRESS[], parse(Int, APP_PORT[]))
end

end # module
