"""
    Client([; host="127.0.0.1", port=6379, database=0, password="", username="", ssl_config=nothing, retry_when_closed=true, retry_max_attemps=1, retry_backoff=(x) -> 2^x, keepalive_enable=false, keepalive_delay=60]) -> Client

Creates a Client instance connecting and authenticating to a Redis host, provide an `MbedTLS.SSLConfig` 
(see `get_ssl_config`) for a secured Redis connection (SSL/TLS).

# Fields
- `id::AbstractString`: Client unique identifier, defaults to a uuid4.
- `host::AbstractString`: Redis host.
- `port::Integer`: Redis port.
- `database::Integer`: Redis database index.
- `password::AbstractString`: Redis password if any.
- `username::AbstractString`: Redis username if any.
- `socket::Union{TCPSocket,MbedTLS.SSLContext}`: Socket used for sending and reveiving from Redis host.
- `lock::Base.AbstractLock`: Lock for atomic reads and writes from client socket.
- `ssl_config::Union{MbedTLS.SSLConfig,Nothing}`: Optional ssl config for secured redis connection.
- `is_subscribed::Bool`: Whether this Client is actively subscribed to any channels or patterns.
- `subscriptions::AbstractSet{<:AbstractString}`: Set of channels currently subscribed on.
- `psubscriptions::AbstractSet{<:AbstractString}`: Set of patterns currently psubscribed on.
- `retry_when_closed::Bool`: Set `true` to try and reconnect when client socket status is closed, defaults to `true`.
- `retry_max_attemps`::Int`: Maximum number of retries for reconnection, defaults to `1`.
- `retry_backoff::Function`: Retry backoff function, called after each retry and must return a single number, where that number is the sleep time (in seconds) until the next retry, accepts a single argument, the number of retries attempted.
- `keepalive_enable::Bool=false`: Set `true` to enable TCP keep-alive.
- `keepalive_delay::Int=60`: Initial delay in seconds, defaults to 60s, ignored when `keepalive_enable` is `false`. After delay has been reached, 10 successive probes, each spaced 1 second from the previous one, will still happen. If the connection is still lost at the end of this procedure, then the handle is destroyed with a UV_ETIMEDOUT error passed to the corresponding callback.

# Note
- Connection parameters `host`, `port`, `database`, `password`, `username` will not change after 
client istance is constructed, even with `SELECT` or `CONFIG SET` commands.

# Examples
Basic connection:
```julia-repl
julia> client = Client();

julia> set("key", "value"; client=client)
"OK"

julia> get("key"; client=client)
"value"

julia> execute(["DEL", "key"], client)
1
```

SSL/TLS connection:
```julia-repl
julia> ssl_config = get_ssl_config(ssl_certfile="redis.crt", ssl_keyfile="redis.key", ssl_ca_certs="ca.crt");

julia> client = Client(ssl_config=ssl_config);
```
"""
mutable struct Client
    id::AbstractString
    host::AbstractString
    port::Integer
    database::Integer
    password::AbstractString
    username::AbstractString
    socket::Union{TCPSocket,MbedTLS.SSLContext}
    lock::Base.AbstractLock
    ssl_config::Union{MbedTLS.SSLConfig,Nothing}
    is_subscribed::Bool
    subscriptions::AbstractSet{<:AbstractString}
    psubscriptions::AbstractSet{<:AbstractString}
    ssubscriptions::AbstractSet{<:AbstractString}
    retry_when_closed::Bool
    retry_max_attemps::Int
    retry_backoff::Function
    keepalive_enable::Bool
    keepalive_delay::Int
end

function Client(
    ; host="127.0.0.1",
    port=6379,
    database=0,
    password="",
    username="",
    ssl_config=nothing,
    retry_when_closed=true,
    retry_max_attemps=1,
    retry_backoff=(x) -> 2^x,
    keepalive_enable=false,
    keepalive_delay=60,
    id=string(uuid4())
)
    client = Client(
        id,
        host,
        port,
        database,
        password,
        username,
        isnothing(ssl_config) ? connect(host, port) : ssl_connect(host, port, ssl_config),
        ReentrantLock(),
        ssl_config,
        false,
        Set{String}(),
        Set{String}(),
        Set{String}(),
        retry_when_closed,
        retry_max_attemps,
        retry_backoff,
        keepalive_enable,
        keepalive_delay
    )
    prepare!(client)

    return client
end

"""
    prepare!(client::Client)

Prepares a new client, involves pre-pinging the server, logging in with the correct username
and password, selecting the chosen database, and setting keepalive if applicable.

Pinging the server is to test connection and set socket status to Base.StatusPaused (i.e. a ready state).
Raw execution is used to bypass locks and retries
"""
function prepare!(client::Client)
    write(client.socket, resp(["PING"]))

    recv(client.socket)

    !isempty(client.password * client.username) && auth(client.password, client.username; client=client)
    client.database != 0 && select(client.database; client=client)

    client.keepalive_enable && keepalive!(client.socket, Cint(1), Cint(client.keepalive_delay))

    # Async garbage collect is needed to clear any stale clients
    @async GC.gc()
end

"""
    get_ssl_config([; ssl_certfile=nothing, ssl_keyfile=nothing, ssl_ca_certs=nothing]) -> MbedTLS.SSLConfig

Loads ssl cert, key and ca cert files from provided directories into MbedTLS.SSLConfig object.

# Examples
```julia-repl
julia> ssl_config = get_ssl_config(ssl_certfile="redis.crt", ssl_keyfile="redis.key", ssl_ca_certs="ca.crt");
```
"""
function get_ssl_config(; ssl_certfile=nothing, ssl_keyfile=nothing, ssl_ca_certs=nothing)
    ssl_config = MbedTLS.SSLConfig(false)

    if !isnothing(ssl_certfile) && !isnothing(ssl_keyfile)
        cert = MbedTLS.crt_parse_file(ssl_certfile)
        key = MbedTLS.parse_keyfile(ssl_keyfile)
        MbedTLS.own_cert!(ssl_config, cert, key)
    end

    if !isnothing(ssl_ca_certs)
        ca_certs = MbedTLS.crt_parse_file(ssl_ca_certs)
        MbedTLS.ca_chain!(ssl_config, ca_certs)
    end

    return ssl_config
end

"""
    ssl_connect(host::AbstractString, port::Integer, ssl_config::MbedTLS.SSLConfig) -> MbedTLS.SSLContext

Connects to the redis host and port, returns a socket connection with ssl context.
"""
function ssl_connect(host::AbstractString, port::Integer, ssl_config::MbedTLS.SSLConfig)
    tcp = connect(host, port)
    io = MbedTLS.SSLContext()
    MbedTLS.setup!(io, ssl_config)
    MbedTLS.associate!(io, tcp)
    MbedTLS.hostname!(io, host)
    MbedTLS.handshake!(io)
    return io
end



# === GLOBAL CLIENT === #
"""
    Global_client

Manages multiple clients for the cluster-mode system

# Fields
- `id::AbstractString`: Global client unique identifier, defaults to a uuid4.
- `clients::Dict{String,Any}`: Dict of client node ID to individual clients that the global client is connected to.
- `cluster::Bool`: Whether or not this is a cluster client
- `slots::Dict{Int,Vector{String}}`: Dict of hash slot to a vector of client node IDs managing that node, in [primary, replica, replicas...] format.
- `host::AbstractString`: Redis host from input (i.e. DNS host name rather than raw IP).
- `port::Integer`: Redis port from input.
"""
mutable struct Global_client
    id::String
    clients::Dict{String,Any}
    cluster::Bool
    slots::Dict{Int,Vector{String}}
    host::String
    port::Int
end

"""
    GLOBAL_CLIENT = Ref{Global_client}()

Reference to the Global Client object, the default client used when no client is provided in commands.
"""
const GLOBAL_CLIENT = Ref{Global_client}()

"""
    GLOBAL_CLIENTS = Ref{Dict{String,Global_client}}()

Reference to a mapping of client IDs (Client/Global_client) to Global_client objects.
"""
GLOBAL_CLIENTS = Ref{Dict{String,Global_client}}()

function update_client(client=Client, slots=Dict{Int,Vector{String}}, id=string(uuid4()))

    cluster_check = execute(["INFO", "CLUSTER"], client)

    if collect(split(collect(split(cluster_check, "\r"))[2], ":"))[2] == "1"
        @info "Cluster mode detected - configuring node connections for cluster mode - ID $id"
        node_connections = configure_client_cluster(client)
        cluster = true

    else
        @info "Single instance Redis in use - ID $id"
        node_connections = configure_client_single(client)
        cluster = false
    end

    update_slots(slots, node_connections)

    global_client = Global_client(
        id,
        node_connections,
        cluster,
        slots,
        client.host,  # Keep track of the original hostname for reconfiguration on cluster change
        client.port
    )

    # Establish GLOBAL_CLIENTS Reference
    if !isassigned(GLOBAL_CLIENTS)
        GLOBAL_CLIENTS[] = Dict()
    end

    GLOBAL_CLIENTS[][id] = global_client
    for (_, client) in global_client.clients
        GLOBAL_CLIENTS[][client["client"].id] = global_client
    end

    return global_client
end

"""
    set_global_client(client::Client)
    set_global_client([; host="127.0.0.1", port=6379, database=0, password="", username="", ssl_config=nothing, retry_when_closed=true, retry_max_attemps=1, retry_backoff=(x) -> 2^x, keepalive_enable=false, keepalive_delay=60])

Sets a Client object as the `GLOBAL_CLIENT[]` instance.
"""
function set_global_client(client::Client, slots::Dict{Int,Vector{String}}, id=string(uuid4()))
    GLOBAL_CLIENT[] = update_client(client, slots, id)
end
function set_client(client::Client, slots::Dict{Int,Vector{String}}, id::String)
    return update_client(client, slots, id)
end

function set_global_client(; host="127.0.0.1", port=6379, database=0, password="", username="", ssl_config=nothing, retry_when_closed=true, retry_max_attemps=1, retry_backoff=(x) -> 2^x, keepalive_enable=false, keepalive_delay=60, id=string(uuid4()))
    client = Client(; host=host, port=port, database=database, password=password, username=username, ssl_config=ssl_config, retry_when_closed=retry_when_closed, retry_max_attemps=retry_max_attemps, retry_backoff=retry_backoff, keepalive_enable=keepalive_enable, keepalive_delay=keepalive_delay)
    set_global_client(client, generate_slots(), id)
end
function set_client_instance(; host="127.0.0.1", port=6379, database=0, password="", username="", ssl_config=nothing, retry_when_closed=true, retry_max_attemps=1, retry_backoff=(x) -> 2^x, keepalive_enable=false, keepalive_delay=60, id=string(uuid4()))
    client = Client(; host=host, port=port, database=database, password=password, username=username, ssl_config=ssl_config, retry_when_closed=retry_when_closed, retry_max_attemps=retry_max_attemps, retry_backoff=retry_backoff, keepalive_enable=keepalive_enable, keepalive_delay=keepalive_delay)
    JedisCluster.set_client(client, generate_slots(), id)
end

"""
    get_global_client() -> GLOBAL_CLIENT

Retrieves the `GLOBAL_CLIENT[]` instance, if unassigned then initialises it with default values 
`host="127.0.0.1"`, `port=6379`, `database=0`, `password=""`, `username=""`.
"""
function get_global_client()
    if isassigned(GLOBAL_CLIENT)
        return GLOBAL_CLIENT[]
    else
        return set_global_client()
    end
end


# === METHODS FOR CLIENTS AND GLOBAL_CLIENTS

"""
    endpoint(client::Client)

Retrieves the endpoint (host:port) of the client.
"""
function endpoint(client::Client)
    return "$(client.host):$(client.port)"
end

"""
    copy(client::Client) -> Client

Creates a new Client instance, copying the connection parameters of the input.
"""
function Base.copy(client::Client)
    return Client(;
        host=client.host,
        port=client.port,
        database=client.database,
        password=client.password,
        username=client.username,
        ssl_config=client.ssl_config,
        retry_when_closed=client.retry_when_closed,
        retry_max_attemps=client.retry_max_attemps,
        retry_backoff=client.retry_backoff,
        keepalive_enable=client.keepalive_enable,
        keepalive_delay=client.keepalive_delay,
        id=client.id
    )
end

"""
    disconnect!(client::Client)

Closes the client socket connection, it will be rendered unusable.
"""
function disconnect!(client::Client)
    close(client.socket)
end

"""
    disconnect!(client::JedisCluster.Global_client)

Closes the client socket connection, it will be rendered unusable.
"""
function disconnect!(client::JedisCluster.Global_client)
    for (_, node) in client.clients
        disconnect!(node["client"])
    end
end


"""
    reconnect!(client::Client) -> Client

Reconnects the input client socket connection.
"""
function reconnect!(client::Client)
    disconnect!(client)
    @info "Attempting to reconnect to $client"
    client.socket = isnothing(client.ssl_config) ? connect(client.host, client.port) : ssl_connect(connect(client.host, client.port), client.host, client.ssl_config)
    prepare!(client)
    return client
end
function reconnect!(client::JedisCluster.Global_client)
    for (_, node) in client.clients
        reconnect!(node["client"])
    end
    return client
end

"""
    flush!(client::Client)

Reads and discards any bytes that remain unread in the client socket.
"""
function flush!(client::Client)
    nb = bytesavailable(client.socket)
    if nb > 0
        buffer = Vector{UInt8}(undef, nb)
        readbytes!(client.socket, buffer, nb)
    end
end
function flush!(client::JedisCluster.Global_client)
    for (_, c) in client.clients
        node = c["client"]
        Base.@lock node.lock begin
            flush!(node)
        end
    end
end

"""
    status(client::Client)

Returns the status of the client socket.
"""
function status(client::Client)
    if client.socket isa TCPSocket
        return client.socket.status
    elseif client.socket isa MbedTLS.SSLContext
        return client.socket.bio.status
    else
        throw(RedisError("INVALIDSOCKET", "Invalid socket type: $(typeof(client.socket))"))
    end
end

"""
    isclosed(client::Client)

Returns `true` if client socket status is `Base.StatusClosing`, `Base.StatusClosed` or 
`Base.StatusOpen`, `false` otherwise. It turns out when status is `Base.StatusOpen` the socket 
is already unusable. `Base.StatusPaused` is the true ready state.
"""
function isclosed(client::Client)
    return status(client) == Base.StatusClosing || status(client) == Base.StatusClosed
end
function isclosed(client::Global_client)
    closed = []
    for (key, node) in client.clients
        push!(closed, isclosed(node["client"]))
    end
    return all(closed)
end

"""
    retry!(client::Client)

Attempts to re-estiablish client socket connection, behaviour is determined by the retry parameters;
`retry_when_closed`, `retry_max_attemps`, `retry_backoff`.
"""
function retry!(client::Client)
    if !isclosed(client)
        return
    end

    if !client.retry_when_closed
        throw(Base.IOError("Client connection to $(endpoint(client)) is closed or unusable, try establishing a new connection, or set `retry_when_closed` field to `true`", Base.StatusUninit))
    end

    @warn "Client socket is closed or unusable, retrying connection to $(endpoint(client))"
    attempts = 0

    while attempts < client.retry_max_attemps
        attempts += 1
        @info "Reconnection attempt #$attempts to $(endpoint(client))"

        try
            reconnect!(client)
            @info "Reconnection attempt #$attempts to $(endpoint(client)) was successful"
            return
        catch err
            reconfigure_client(client)

            if !(err isa Base.IOError)
                rethrow()
            end

            @warn "Reconnection attempt #$attempts to $(endpoint(client)) was unsuccessful"
        end

        if attempts < client.retry_max_attemps
            backoff = client.retry_backoff(attempts)
            @info "Sleeping $(backoff)s until next reconnection attempt to $(endpoint(client))"
            sleep(backoff)
        end
    end

    throw(Base.IOError("Client connection to $(endpoint(client)) is closed or unusable, try establishing a new connection, or set `retry_when_closed` field to `true`", Base.StatusUninit))
end

"""
    set_subscribed!(client::Client)

Marks the Client instance as subscribed, should not be used publicly.
"""
function set_subscribed!(client::Client)
    client.is_subscribed = true
end

"""
    set_unsubscribed!(client::Client)

Marks the Client instance as unsubscribed, should not be used publicly.
"""
function set_unsubscribed!(client::Client)
    client.is_subscribed = false
end

"""
    wait_until_subscribed(client::Client)

Blocks until client changes to a subscribed state.
"""
function wait_until_subscribed(client::Client)
    if !client.is_subscribed
        while !client.is_subscribed
            sleep(0.001)
        end
    end
end

"""
    wait_until_unsubscribed(client::Client)

Blocks until client changes to a unsubscribed state.
"""
function wait_until_unsubscribed(client::Client)
    if client.is_subscribed
        while client.is_subscribed
            sleep(0.001)
        end
    end
end

"""
    wait_until_channel_unsubscribed(client::Client[, channels...])

Blocks until client is unsubscribed from channel(s), leave empty to wait until unsubscribed from all channels.
"""
function wait_until_channel_unsubscribed(client::Client, channels...)
    if isempty(channels)
        while !isempty(client.subscriptions)
            sleep(0.001)
        end
    else
        while !isempty(intersect(client.subscriptions, Set{String}(channels)))
            sleep(0.001)
        end
    end
end

"""
    wait_until_pattern_unsubscribed(client::Client[, patterns...])

Blocks until client is unsubscribed from pattern(s), leave empty to wait until unsubscribed from all patterns.
"""
function wait_until_pattern_unsubscribed(client::Client, patterns...)
    if isempty(patterns)
        while !isempty(client.psubscriptions)
            sleep(0.001)
        end
    else
        while !isempty(intersect(client.psubscriptions, Set{String}(patterns)))
            sleep(0.001)
        end
    end
end

"""
    wait_until_shard_unsubscribed(client::Client[, shards...])

Blocks until client is unsubscribed from shard(s), leave empty to wait until unsubscribed from all shards.
"""
function wait_until_shard_unsubscribed(client::Client, shards...)
    if isempty(shards)
        while !isempty(client.ssubscriptions)
            sleep(0.001)
        end
    else
        while !isempty(intersect(client.ssubscriptions, Set{String}(shards)))
            sleep(0.001)
        end
    end
end

function reconfigure_client(client::Client)
    @info "Previous command was unsuccessful and not executed (see RedisError below), try again after reconfiguration"

    gc = GLOBAL_CLIENTS[][client.id]  # Get global client mutable struct from client ID

    # TODO: Do we remove the sub-client references out of the GLOBAL_CLIENTS[] dict or keep in case they are still referenced?
    # for (_, c) in gc.clients
    #     delete!(GLOBAL_CLIENTS[], c["id"])
    # end

    # Create a new Client of the same parameters of the current client and global client's host/port inputs
    client = Client(;
        host=gc.host,
        port=gc.port,
        database=client.database,
        password=client.password,
        username=client.username,
        ssl_config=client.ssl_config,
        retry_when_closed=client.retry_when_closed,
        retry_max_attemps=client.retry_max_attemps,
        retry_backoff=client.retry_backoff,
        keepalive_enable=client.keepalive_enable,
        keepalive_delay=client.keepalive_delay
    )
    new_gc = JedisCluster.set_client(client, generate_slots(), gc.id)

    # Replace global client's mutable fields with new global client's clients and slots
    gc.clients = new_gc.clients
    gc.slots = new_gc.slots

    @info "Global Client has been reconfigured with new clients and slots - ID $(gc.id)"
end

function configure_client_single(client::Client)
    node_connections = Dict()
    node_connections["instance"] = Dict()
    node_connections["instance"]["id"] = string(uuid4())
    node_connections["instance"]["port"] = client.port
    node_connections["instance"]["host"] = client.host
    node_connections["instance"]["node"] = "instance"
    node_connections["instance"]["slots"] = collect(0:16383)
    node_connections["instance"]["node_type"] = "primary"

    node_connections["instance"]["client"] = Client(
        id=node_connections["instance"]["id"],
        port=node_connections["instance"]["port"],
        host=node_connections["instance"]["host"],
        database=client.database,
        password=client.password,
        username=client.username,
        ssl_config=client.ssl_config,
        retry_when_closed=client.retry_when_closed,
        retry_max_attemps=client.retry_max_attemps,
        retry_backoff=client.retry_backoff,
        keepalive_enable=client.keepalive_enable,
        keepalive_delay=client.keepalive_delay
    )

    @info "Establishing connection with: host:$(node_connections["instance"]["host"]) port:$(node_connections["instance"]["port"]) type:$(node_connections["instance"]["node_type"])"
    return node_connections
end

function configure_client_cluster(client::Client)
    cluster_config = execute(["CLUSTER", "SLOTS"], client)
    node_count = 0
    node_connections = Dict()
    for shard in cluster_config
        for (i, node) in enumerate(shard[3:end, :])
            if !haskey(node_connections, node[3])
                node_connections[node[3]] = Dict()
                node_connections[node[3]]["id"] = string(uuid4())
                node_connections[node[3]]["port"] = node[2]
                node_connections[node[3]]["host"] = node[1]
                node_connections[node[3]]["node"] = node[3]

                node_connections[node[3]]["client"] = Client(
                    id=node_connections[node[3]]["id"],
                    port=node_connections[node[3]]["port"],
                    host=node_connections[node[3]]["host"],
                    database=client.database,
                    password=client.password,
                    username=client.username,
                    ssl_config=client.ssl_config,
                    retry_when_closed=client.retry_when_closed,
                    retry_max_attemps=client.retry_max_attemps,
                    retry_backoff=client.retry_backoff,
                    keepalive_enable=client.keepalive_enable,
                    keepalive_delay=client.keepalive_delay
                )

                if i == 1
                    node_connections[node[3]]["node_type"] = "primary"
                else
                    node_connections[node[3]]["node_type"] = "replica"
                    execute(["READONLY"], node_connections[node[3]]["client"])
                end

                node_count += 1
                @info "Establishing connection with: host:$(node_connections[node[3]]["host"]) port:$(node_connections[node[3]]["port"]) type:$(node_connections[node[3]]["node_type"])"
            end

            if !haskey(node_connections[node[3]], "slots")
                node_connections[node[3]]["slots"] = collect(shard[1]:shard[2])
            else
                append!(node_connections[node[3]]["slots"], collect(shard[1]:shard[2]))
            end
        end
    end
    @info "Connected to $node_count nodes in cluster"
    return node_connections
end



"""
    generate_slots()

Generate slots for node allocation.
    returns a Dict with slots as keys and array of nodes as values - this is initalised as empty
"""
function generate_slots()
    total_slots = 16383
    slots = Dict(0 => String[])
    for slot in 1:total_slots
        slots[slot] = String[]
    end
    return slots
end


"""
    update_slots(slots::Dict{Int, Vector{String}}, node_connections)

Generate slots for node allocation per client.
    returns a Dict with slots as keys and array of nodes as values - this is initalised as empty
"""
function update_slots(slots::Dict{Int,Vector{String}}, node_connections)

    @info "Pre-allocating slots to nodes"
    for (_, node) in node_connections
        for slot in node["slots"]
            push!(slots[slot], node["node"])
        end
    end
    for (key, slot) in slots
        primary = ""
        replicas = []
        for node in slot
            if node_connections[node]["node_type"] == "primary"
                primary = node_connections[node]["node"]
            else
                push!(replicas, node_connections[node]["node"])
            end
        end
        slots[key] = vcat(primary, replicas)
    end
    @info "Slot allocation established"
end

const CRC16_TABLE = Ref{CRC.var"#handler#7"{CRC.var"#handler#4#8"{Multiple{UInt64},CRC.Spec{UInt16},CRC.Forwards{UInt64},DataType}}}(crc(CRC_16_XMODEM))

function get_hash_slot(key::String)
    hash_temp = CRC16_TABLE[](key)
    slot = mod(hash_temp, 16384)
    return slot
end

function get_hash_key(key::String)
    a = findfirst("{", key)[1]
    return collect(split(key[a+1:end], "}"))[1]
end

function get_client(client::JedisCluster.Global_client, keys::Vector{String}, write::Bool=false, replica::Bool=false)
    if !client.cluster
        node = rand(client.clients)[1]
    elseif keys[1] == "*" && !write && !replica
        # @info "Subscribe or publish to any node"
        node = rand(client.clients)[1]
    elseif keys[1] == "*" && write && !replica
        # @info "Subscribe or publish to a primary node"
        node = get_any_primary_node(client)
    elseif keys[1] == "*" && !write && replica && client.cluster
        node = get_any_replica_node(client)
    else
        slots = []
        for key::String in keys
            if occursin("{", key) && occursin("}", key)
                key = get_hash_key(key)
            end

            push!(slots, key)
        end
        allequal(x) = all(y -> y == x[1], x)
        if allequal(slots)
            slot = get_hash_slot(slots[1])
            if ~write && replica && length(client.slots[slot]) >= 2
                node = rand(client.slots[slot][2:end])
            else
                node = client.slots[slot][1]
            end
        else
            throw(RedisError("CROSSSLOT", "Keys in request don't hash to the same slot"))
        end

    end
    client_connection = client.clients[node]["client"]
    return client_connection
end

function get_client(client::Client, keys::Vector{String}, write::Bool=false, replica::Bool=false)
    return client
end

function get_any_primary_node(client::JedisCluster.Global_client)
    nodes = []
    for (key, _) in client.clients
        if client.clients[key]["node_type"] == "primary"
            push!(nodes, key)
        end
    end
    return rand(nodes)
end

function get_primary_nodes(client)
    nodes = []
    for (key, node) in client.clients
        if node["node_type"] == "primary"
            push!(nodes, node)
        end
    end
    return nodes
end

function get_any_replica_node(client::JedisCluster.Global_client)
    nodes = []
    for (key, _) in client.clients
        if client.clients[key]["node_type"] == "replica"
            push!(nodes, key)
        end
    end
    return rand(nodes)
end

function get_replica_nodes(client)
    nodes = []
    for (key, node) in client.clients
        if node["node_type"] == "replica"
            push!(nodes, node)
        end
    end
    return nodes
end

function get_all_nodes(client)
    nodes = []
    for (key, node) in client.clients
        push!(nodes, node)
    end
    return nodes
end

# === OTHER UTILITIES

function Base.show(io::IO, client::Client)
    write(io, string(client))
end

function Base.string(client::Client)
    return "Client $(client.id) on $(client.host):$(client.port)"
end

function Base.show(io::IO, client::Global_client)
    str = "Global Client - $(client.id)\n"
    for node_manager in values(client.clients)
        node = node_manager["client"]
        str *= "  $(node)\n"
    end
    write(io, str)
end