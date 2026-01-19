mutable struct PostgreSQLConnectionParams
    endpoint::String
    host::String
    port::Int
    dbname::String
    user::String
    password::String
    iam_connection::Bool
    db_type::Symbol
    db_identifier::String
end


endpoint(pg_params::PostgreSQLConnectionParams) = pg_params.endpoint
host(pg_params::PostgreSQLConnectionParams) = pg_params.host
port(pg_params::PostgreSQLConnectionParams) = pg_params.port
dbname(pg_params::PostgreSQLConnectionParams) = pg_params.dbname
user(pg_params::PostgreSQLConnectionParams) = pg_params.user
password(pg_params::PostgreSQLConnectionParams) = pg_params.password
iam_connection(pg_params::PostgreSQLConnectionParams) = pg_params.iam_connection
db_type(pg_params::PostgreSQLConnectionParams) = pg_params.db_type
db_identifier(pg_params::PostgreSQLConnectionParams) = pg_params.db_identifier


function Base.show(pg_params::PostgreSQLConnectionParams)
    pword = (length(pg_params.password) > 0) ? "********" : ""
    text = """
    Postgres Connection Parameters
        Endpoint: $(pg_params.endpoint)
        Database: $(pg_params.dbname)
        Username: $(pg_params.user)
        Password: $(pword)
        IAM: $(pg_params.iam_connection)
        DB Type: $(pg_params.db_type)
        DB Identifier: $(pg_params.db_identifier)
    """
    print(text)
end


function Base.display(pg_params::PostgreSQLConnectionParams)
    display_text = "Postgres Connection Parameters"
    print(display_text)
end


function Base.string(pg_params::PostgreSQLConnectionParams)
    return "Postgres Connection Parameters to $(pg_params.dbname)"
end


"""
    PostgreSQLConnectionParams(;
        endpoint::String="localhost:5432",
        dbname::String="postgres",
        user::String="postgres",
        password::String="postgres",
        iam_connection::Bool=false,
        db_type::Symbol=:RDS,
        db_identifier::String=""
    )

Creates a PostgreSQLConnectionParams struct from any of the provided parameters. By default, this is based on environment variables.

# Arguments
- `endpoint::String` formatted as `host`:`port` which is defaulted to localhost:5432.
- `dbname::String` name of the database which is defaulted to `"postgres"`.
- `user::String` username for database login which is defaulted to `"postgres"`.
- `password::String` password for database login which is defaulted to `"postgres"`.
- `iam_connection::Bool`: conditional of whether IAM authentication with token is in use.
- `db_type::Symbol`: Database type to use IAM auth with, ∈ [:RDS, :REDSHIFT]
- `db_identifier::String`: Database identifier, used for redshift IAM auth token request
"""
function PostgreSQLConnectionParams(;
    endpoint::String="localhost:5432",
    dbname::String="postgres",
    user::String="postgres",
    password::String="postgres",
    iam_connection::Bool=false,
    db_type::Symbol=:RDS,
    db_identifier::String=""
)
    host, port = split(endpoint, ":")

    db_type ∉ [:REDSHIFT, :RDS] && @error "PostgreSQLConnectionParams.db_type is only allowed as :REDSHIFT, or :RDS"
    iam_connection && @warn "IAM Authentication connection currently requires AWS CLI installed."
    
    return PostgreSQLConnectionParams(
        endpoint,
        host,
        parse(Int, port),
        dbname,
        user,
        password,
        iam_connection,
        db_type,
        db_identifier
    )
end


"""
    update_pg_params!(
        pg_params::PostgreSQLConnectionParams;
        endpoint::String=pg_params.endpoint,
        dbname::String=pg_params.dbname,
        user::String=pg_params.user,
        password::String=pg_params.password,
        iam_connection::Bool=false,
        db_type::Symbol=pg_params.db_type,
        db_identifier::String=pg_params.db_identifier
    )

Update the provided PostgreSQLConnectionParams object, based on any provided kwargs.

# Arguments
- `endpoint::String` formatted as `host`:`port` which is defaulted to the value in the provided connection parameters.
- `dbname::String` name of the database which is defaulted to the value in the provided connection parameters.
- `user::String` username for database login which is defaulted to the value in the provided connection parameters.
- `password::String` password for database login which is defaulted to the value in the provided connection parameters.
- `iam_connection::Bool`: conditional of whether IAM authentication with token is in use.
- `db_type::Symbol`: Database type to use IAM auth with, ∈ [:RDS, :REDSHIFT]
- `db_identifier::String`: Database identifier, used for redshift IAM auth token request
"""
function update_pg_params!(
    pg_params::PostgreSQLConnectionParams;
    endpoint::String=pg_params.endpoint,
    dbname::String=pg_params.dbname,
    user::String=pg_params.user,
    password::String=pg_params.password,
    iam_connection::Bool=pg_params.iam_connection,
    db_type::Symbol=pg_params.db_type,
    db_identifier::String=pg_params.db_identifier
)
    host, port = split(endpoint, ":")
    pg_params.endpoint = endpoint
    pg_params.host = host
    pg_params.port = parse(Int, port)
    pg_params.dbname = dbname
    pg_params.user = user
    pg_params.password = password
    pg_params.iam_connection = iam_connection
    pg_params.db_type = db_type
    pg_params.db_identifier = db_identifier
end
