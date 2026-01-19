"""
`Resource` handles the creation of the HTTP server and the endpoints.

By default, the following endpoints are set:
- `/live` - used to check microservice is live. Returns status 200 and "OK"
- `/ready` - used to check microservice is ready. Returns status 200 and "READY" if ready. By default, the microservice checks that the Experiment Manager is ready.
- `/execute` - calls `App.execute_app()` with the request
"""
module Resource

using EMInterface
using HTTP
using URIs
using JSON3
using UUIDs: uuid4
using ..App
using ..Workers

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
    APP_PORT[] =  get(ENV, "APP_PORT", "6701")
    APP_ADDRESS[] = get(ENV, "APP_ADDRESS", "0.0.0.0")
    EXPERIMENT_MANAGER_ENDPOINT[] = get(ENV, "EXPERIMENT_MANAGER_ENDPOINT", "http://localhost:5100")
    EXPERIMENT_MANAGER_WS_ENDPOINT[] = get(ENV, "EXPERIMENT_MANAGER_WS_ENDPOINT", "ws://localhost:5100")
end

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

function execute_ingestion(req)
    # Converts from byte array (Vector{UInt8}) to String
    body = uppercase(String(req.body))
    if !haskey(App.CONFIG[], body)
        msg = "MapImporter - No Ingestion method currently defined for $(body)"
        @info msg
        code = 422 # Error code for Unprocessable Entity
    end

    try
        @info "MapImporter - Starting ingestion of $(body)"
        tsk = Workers.@async App.source_ingestion(body; refresh_data=true)
        result = fetch(tsk)
        result isa Exception && rethrow(result)
        @info "MapImporter - Ingestion of $(body) successfully completed"
        code = 200

    catch err
        @error "MapImporter - Ingestion of $(body) failed due to " exception=(err, catch_backtrace())
        msg = "MapImporter - Ingestion of $(body) failed - check logs for error details"
        code = 400
    end
    return code, msg
end
HTTP.@register(ROUTER, "/execute", execute_ingestion)

### Define request handler
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

    local resp

    try
        resp = HTTP.handle(ROUTER, req)
    catch err
        @error "Function failed: $(typeof(err))" exception=(err, catch_backtrace())
        resp = 400, string(err)
    end

    if resp isa HTTP.Messages.Response
        return resp
    elseif resp isa Tuple{Int64, Any}
        # Response includes the status, so use it
        # If object is a string, return as is. Otherwise write with JSON3.
        status, obj = resp
        return HTTP.Response(status, obj isa String ? obj : JSON3.write(obj))
    elseif resp isa Exception
        return HTTP.Response(400, string(resp))
    else
        # Assume successful and return status 200
        # If object is a string, return as is. Otherwise write with JSON3.
        return HTTP.Response(200, resp isa String ? resp : JSON3.write(resp))
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
