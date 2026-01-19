"""
    GLOBAL_CONNECTION[]

Reference to the global JedisCluster.Client connection.
"""
const GLOBAL_CONNECTION = Ref{JedisCluster.Client}()


"""
    set_global_connection() -> JedisCluster.Client
    set_global_connection(endpoint) -> JedisCluster.Client
    set_global_connection(host::String, port::Int) -> JedisCluster.Client

Sets the global `GLOBAL_CONNECTION` to a Jedis client using either:
- Globally available `TILE38_ENDPOINT` environment variable, e.g. `localhost:9851`
- `endpoint` string, e.g. `localhost:9851`
- `host` and `port` arguments
"""
function set_global_connection(host::String, port::Int)
    global_client = JedisCluster.set_global_client(host=String(host), port=port)
    GLOBAL_CONNECTION[] = JedisCluster.get_client(global_client, ["*"], true, false)
end
function set_global_connection(endpoint::String)
    host, port = split(endpoint, ":")
    set_global_connection(String(host), parse(Int64, port))
end
function set_global_connection()
    endpoint = get(ENV, "TILE38_ENDPOINT", "localhost:9851")
    set_global_connection(endpoint)
end

"""
    get_global_connection()

Gets the global GLOBAL_CONNECTION containing the Jedis client
"""
get_global_connection() = isassigned(GLOBAL_CONNECTION) ? GLOBAL_CONNECTION[] : set_global_connection()

"""
    with_tile38(fn, conn::JedisCluster.Client=get_global_connection())

Establishes a tile38 connection context.

Examples:
```
with_tile38() do conn
    JedisCluster.execute(conn, "SET example group 1.1 1.1")
end

with_tile38() do conn
    Tile38Interface.scan_key("a", conn)
end
```
"""
function with_tile38(fn, conn::JedisCluster.Client=get_global_connection())
    try
        fn(conn)
    finally
        conn != get_global_connection() && disconnect!(conn)
    end
end

"""
    tile38_isready()

Checks if Tile38 global Jedis connection is ready.
"""
function tile38_isready()
    with_tile38() do conn
        if JedisCluster.execute(["PING"], conn) == "PONG"
            @info "Tile38 is ready: $conn"
        else
            throw(ErrorException("Tile38 is not ready: $conn"))
        end
    end
end