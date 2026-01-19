module PSQLInterface


using DataFrames
using LibPQ
using Tables
using UUIDs
using HTTP
using CSV
using DataStructures
using AWS
@service Redshift

# Parameters
export PostgreSQLConnectionParams, Connection, global_psql_config,  # Config generators
    update_pg_params!,  # set parameters
    endpoint, host, port, dbname, user, password,  # get individual parameters
    is_pg_ready, with_postgresql  # postgres functions

# Functions
export table_exists, is_table_populated, get_table_length,  # Table functions
    make_table, generate_column_line,  # Table functions
    write_to_table, batched_write_to_table,  # Table functions
    select_from_table,  copy_to_table, # Table functions
    drop_table, truncate_table,  # Table functions
    execute_psql_from_file, execute_sql_script,  execute_psql_string, execute_psql_string_await, # Generic functions
    schema_exists, make_schema,  # Schema functions
    get_table_definition, # Information functions
    get_valid_token # AWS Specific PSQL function

# LibPQ Utilities
export libpq_result_as_dict

include("exceptions.jl")
include("utilities.jl")
include("libpq_utilties.jl")
include("postgres_types.jl")
include("postgres_interfaces.jl")
include("rds.jl")

const PG_PARAMS = Ref{PostgreSQLConnectionParams}()

"""
    global_psql_config()

Returns the global Postgres connection parameters. If there are no global parameters set,
then a default connection to localhost:5432 is created with default connection details.
"""
function global_psql_config()
    if !isassigned(PG_PARAMS)
        @warn "Connecting to Postgres connection with default parameters (localhost:5432)."
        PG_PARAMS[] = PostgreSQLConnectionParams()
    end
    return PG_PARAMS[]
end


"""
    global_psql_config(pg_params::PostgreSQLConnectionParams)

Sets the global Postgres connection paramter to the provided parameters and then returns the global Postgres
connection parameters.
"""
function global_psql_config(pg_params::PostgreSQLConnectionParams)
    return PG_PARAMS[] = pg_params
end


"""
    get_connection([::PostgreSQLConnectionParams])

Connect to a Postgres Database, using either the global connection values or a provided
PostgreSQLConnectionParams struct.
"""
function get_connection(pg_params::PostgreSQLConnectionParams = global_psql_config(), options=nothing)
    try
        return _get_conn(pg_params, options)
    catch
        return _get_conn(pg_params, nothing)
    end
end

_get_conn(pg_params, ::Any) = LibPQ.Connection("host=$(pg_params.host) port=$(pg_params.port) dbname=$(pg_params.dbname) user=$(pg_params.user) password=$(pg_params.password)")
_get_conn(pg_params, options::Dict) = LibPQ.Connection("host=$(pg_params.host) port=$(pg_params.port) dbname=$(pg_params.dbname) user=$(pg_params.user) password=$(pg_params.password)"; options=options)

end # module
