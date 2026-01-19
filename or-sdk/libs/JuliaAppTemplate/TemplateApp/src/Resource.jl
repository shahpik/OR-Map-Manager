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
    APP_PORT[] =  get(ENV, "APP_PORT", "5082")
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
