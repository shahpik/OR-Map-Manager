"""
Dictionary of tokens keyed by the creation time. Tokens last for 15 minutes and need to be rolled out
Separate SortedDict for each host
"""
const TOKENS = Dict{String, SortedDict{Int, String}}()

"""
Global status of token generation
Separate SortedDict for each host
"""
isGenerating = Dict{String, Bool}()

"""
    get_valid_token(db_params)

When requested, manages the rotating tokens for accessing RDS with IAM.
1. If the tokens are older than the expiry time, remove them
2. If the set is (now) empty, add a token, RETURN it
3. If the latest token is older than the rotation threshold, add a new one
4. RETURN first token to use (arbitrarily)

Note, the secondary token is added when the latest token is older than (e.g.) 7.5 minutes. 
If this check is on the first token, it will just spam new tokens after the first 7.5 minutes.

Consider timeline of tokens for a few minutes minutes, expiry 3 minutes, rotation 1.5 minutes

        0   1   2   3   4   5   6   7
    ---------------------------------
    T1  |..--------~|
    T2        |..--------~|
    T3              |..--------~|
    ---------------------------------

- Initially, tokens are empty, add the first
- When T1 (at this point the latest) > 1.5 minutes old, add a second
- Between 1.5 and 3, the _latest_ is 0 to 1.5 minutes old (nothing extra done)
- at >3, the first is old and removed in the first step the latest is now >1.5, new second added 

# Arguments:
- `db_params::PostgreSQLConnectionParams`: Standard connection parameters to determine db type
# Returns:
- `token::String`: token for RDS IAM access
"""
const TOKEN_LOCK = ReentrantLock()
function get_valid_token(db_params)
    lock(TOKEN_LOCK) do
        # Roll tokens, syncopated ~7.5 min apart, expiry 15 minutes
        rotation_threshold = 7.5 * 60 - 5 
        expiry_threshold = 15 * 60 - 5

        db_tokens = get!(TOKENS, db_params.host, SortedDict{Int, String}())

        # Clean out old
        ks = collect(keys(db_tokens))

        for k in ks
            if current_time() - k > expiry_threshold
                @info "Clearing key aged $(current_time() - k)"
                delete!(db_tokens, k)
            end
        end

        # empty tokens need at least one, create and block while its creating
        # just add one and don't bother about another yet

        if isempty(db_tokens)
            new_token(db_params, true)
            return first(db_tokens)[2]
        end

        # find latest key, if older than the rotation threshold, bump in another ready to go
        # (note first will be expiring, but handled above)
        latest_time = last(db_tokens)[1]
        if current_time() - latest_time >= rotation_threshold
            # add new token if the first one is older than 14 minutes
            new_token(db_params, false) # separate thread as this could be nontrivial
        end

        return first(db_tokens)[2]
    end
end

"""
    new_token(db_params, block=false)

Create a new token if not already being done

# Arguments:
- `db_params`: Standard params but tokens keyed by host, and process dependent on db_type 
- `block::Bool`: if true, e.g. need a new token to continue at all, add a 
    token and wait for the response before returning
"""
function new_token(db_params, block=false)

    db_tokens = TOKENS[db_params.host]

    global isGenerating

    if !haskey(isGenerating, db_params.host)
        isGenerating[db_params.host] = false
    end

    if block
        isGenerating[db_params.host] = true
        push!(db_tokens, current_time() => generate_token(db_params));
        isGenerating[db_params.host] = false
        return
    end

    isGenerating[db_params.host] && return

    # not generating, start a new one and return immediately
    t = @task begin; 
        isGenerating[db_params.host] = true;
        push!(db_tokens, current_time() => generate_token(db_params)); 
        isGenerating[db_params.host] = false;
    end
    schedule(t)
    
end

"""
    generate_token(db_params)::String

Generate the auth token from generate_db_auth_token in CLI or SDK
Note this is not yet implemented in RDS service, requires building up a GET request.
"""
function generate_token(db_params)::String

    username = db_params.user
    host = db_params.host
    port = db_params.port
    db_identifier = db_params.db_identifier
    region = "ap-southeast-2"

    if db_params.db_type == :RDS
        auth_token = read(`aws rds generate-db-auth-token --hostname $host --port $port --region $region --username $username`, String)
        auth_token = replace(auth_token, r"\n" => "")
    else
        # get an auth token using standard AWS identity hierarchy
        auth_token_dict = Redshift.get_cluster_credentials(db_identifier, username)
        auth_token = auth_token_dict["GetClusterCredentialsResult"]["DbPassword"]
    end
    return auth_token
end
