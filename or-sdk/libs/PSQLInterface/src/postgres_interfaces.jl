"""
    with_postgresql(fn::Function)

Establishes a postgresql connection context.

Example:
```julia
with_postgresql() do psql
    execute(psql, "SELECT 1;")
end
```
"""
function with_postgresql(fn::Function)
    # grab a token if required
    pg_params = global_psql_config()
    if pg_params.iam_connection
        pg_params.password = get_valid_token(pg_params)
        # Redshift get_Credentials prepends IAM:
        if pg_params.db_type == :REDSHIFT && !startswith(pg_params.username, "IAM:")
            pg_params.username = "IAM:" * pg_params.username
        end
    end

    conn = get_connection()
    try
        fn(conn)
    finally
        close(conn)
    end
end

"""
    with_postgresql(fn::Function, pg_params::PostgreSQLConnectionParams, options=Dict{String, String}())

Establishes a postgresql connection context.

Example:
```julia
with_postgresql(conn, options) do psql
    execute(psql, "SELECT 1;")
end
```
"""
function with_postgresql(fn::Function, pg_params::PostgreSQLConnectionParams, options=Dict{String, String}())
    # grab a token if required
    if pg_params.iam_connection
        pg_params.password = get_valid_token(pg_params)
        # Redshift get_Credentials prepends IAM:
        if pg_params.db_type == :REDSHIFT && !startswith(pg_params.username, "IAM:")
            pg_params.username = "IAM:" * pg_params.username
        end
    end

    conn = get_connection(pg_params, options)
    try
        fn(conn)
    finally
        close(conn)
    end
end


"""
    is_pg_ready([::PostgreSQLConnectionParams])::Bool

Checks if postgresql is ready using the `pg_isready` shell command.
"""
is_pg_ready(pg_params=global_psql_config())::Bool = success(run(`pg_isready -h $(pg_params.host) -p $(pg_params.port) -U $(pg_params.user) -d $(pg_params.dbname)`))


"""
    table_exists([::PostgreSQLConnectionParams], table_name::AbstractString, options=Dict{String, String}())

Check if the provided table exists in the postgres database. This can be either the table name, or the schema and table names.
"""
function table_exists(pg_params::PostgreSQLConnectionParams, table_name::AbstractString, options=Dict{String, String}())
    @debug "Checking that $table_name exists in $(dbname(pg_params))"

    with_postgresql(pg_params, options) do psql
        test = "SELECT to_regclass('$(_delimit_object_names(table_name))')"
        data =  columntable(execute(psql, test))
        return data.to_regclass[1] !== missing
    end
end
table_exists(table_name::AbstractString) = table_exists(global_psql_config(), table_name)


"""
    drop_table([::PostgreSQLConnectionParams], table_name::AbstractString, options=Dict{String, String}())

Drop the provided table if it exists in the postgres database. This can be either the table name, or the schema and table names.
"""
function drop_table(pg_params::PostgreSQLConnectionParams, table_name::AbstractString, options=Dict{String, String}())
    @warn "Attempting to drop $table_name from $(dbname(pg_params))"
    with_postgresql(pg_params, options) do psql
        drop = "DROP TABLE IF EXISTS $(_delimit_object_names(table_name))"
        execute(psql, drop)
    end
    return nothing
end
drop_table(table_name::AbstractString) = drop_table(global_psql_config(), table_name)


"""
    make_table([::PostgreSQLConnectionParams], table_name::AbstractString, table_metadata::AbstractVector{<:AbstractDict})

Makes a table, named `table_name`, in the postgres database. The table is built using table metadata, which
is a vecotr of column definition dictionaries.

# Arguments
- `pg_params::PostgreSQLConnectionParams` the optional connection parameter
- `table_name::AbstractString` the name of the new table. It can also be extended with schema and database information.
- `table_metadata::AbstractVector{<:AbstractDict}` a vector of column definition dictionaries. The column metadata fields are:
    1. *name*: The column name. **This is always required.**
    1. *type*: SQL type, with or without size, as a string. **This is always required.**
    1. *length*: SQL type's length, as a string or integer.
    1. *check*: SQL check for the column, as a string, which should return a boolean when run.
    1. *not_null*: If included, the column will be set to NOT NULL.
    1. *unique*: If included, the column will be set to UNIQUE.
    1. *primary_key*: If included, the column will be set to be the PRIMARY KEY
"""
function make_table(
        pg_params::PostgreSQLConnectionParams,
        table_name::AbstractString,
        table_metadata::AbstractVector{<:AbstractDict},
        options=Dict{String, String}()
    )
    @debug "Creating a new table in $(dbname(pg_params)) called $table_name"
    column_strings = String[]
    name_list = String[]
    for column_definition in table_metadata
        if haskey(column_definition, "table_constraints")
            @warn "Table constraints have not been implemented in this version of the PSQLInterface. Please make a .sql file and run that for generating the table."
        end
        !haskey(column_definition, "name") && throw(PSQLInterfaceException("All column definitions require a name."))
        !haskey(column_definition, "type") && throw(PSQLInterfaceException("All column definitions require a type."))
        column_definition["name"] = get_unique_name(column_definition["name"], name_list)
        push!(name_list, column_definition["name"])
        push!(column_strings, _generate_column_line(_delimit_object_names(column_definition["name"]), column_definition))
    end
    table_constructor = "CREATE TABLE IF NOT EXISTS " * _delimit_object_names(table_name) * " (\n" * join(column_strings, ",\n") * ");"
    @debug table_constructor
    with_postgresql(pg_params, options) do psql
        execute(psql, table_constructor)
    end
    return nothing
end
make_table(table_name::AbstractString, table_metadata::AbstractVector{<:AbstractDict}) = make_table(global_psql_config(), table_name, table_metadata)


"""
    write_to_table([::PostgreSQLConnectionParams], df::AbstractDataFrame, table_name::AbstractString)
    write_to_table([::PostgreSQLConnectionParams], data::AbstractVector{Vector}, column_names::Union{AbstractVector, Tuple}, table_name::AbstractString)

Write data into a table in the postgres database.

# TODO
- Add support for `NaN` and `nothing`, as only `missing` writes by default (into `NULL`).
"""
function write_to_table(pg_params::PostgreSQLConnectionParams, df::AbstractDataFrame, table_name::AbstractString, options=Dict{String, String}(); on_conflict=:error)
    @debug "Writing $(first(size(df))) rows of data to $table_name"
    column_names = _delimit_object_names.(names(df))
    string_header = "(" * join(column_names, ",") * ")"
    data_target = dollar_marked_values(1:length(column_names))
    conflict_str = ""
    if on_conflict == :nothing
        conflict_str = " ON CONFLICT DO NOTHING"
    end
    
    with_postgresql(pg_params, options) do psql
        execute(psql, "BEGIN;")
        LibPQ.load!(
            df,
            psql,
            "INSERT INTO $(_delimit_object_names(table_name)) $(string_header) VALUES $(data_target)$(conflict_str);",
        )
        execute(psql, "COMMIT;")
    end
    return nothing
end
function write_to_table(
    pg_params::PostgreSQLConnectionParams,
    data::AbstractVector{<:AbstractVector},
    column_names::Union{AbstractVector, Tuple},
    table_name::AbstractString
    )
    length(column_names) != length(data) && throw(DimensionMismatch("Writing to table requires same number of column_names as data vectors."))
    return write_to_table(pg_params, DataFrame(NamedTuple{Tuple(Symbol.(column_names))}(data)), table_name)
end

"""
    write_to_table(pg_params::PostgreSQLConnectionParams, select_script::String, table_name::String, schema::String, columns=nothing, options=Dict{String, String}(); on_conflict::Symbol=:error)

# Arguments
- `conn`: postgresql connection
- `select_script`: string of the SQL script to execute select on
- `table_name`: table name in database
- `schema`: schema name in database
- `columns`: Should be a comma separated string of list of column names, e.g. "id, name, time"
- `on_confict`: The `ON CONFLICT` PSQL behaviour can be controlled using the `on_conflict` keyword argument one of the following symbols.
    - `:error` (default)
    - `:upsert`
    - `:nothing`
It is the user's responsibility to make sure the table columns of the select script matches this argument, order matters.
If not provided, will get all the columns of the target table and insert all.

# Returns
- `LibPQ.Result`: Execute command result
"""
function write_to_table(pg_params::PostgreSQLConnectionParams, select_script::String, table_name::String, schema::String, columns=nothing, options=Dict{String, String}(); on_conflict::Symbol=:error)
    tmp = "\"tmp_table_$(uuid4().value)\""
    schema_table = _delimit_object_names(schema * "." * table_name)
    if isnothing(columns)
        active_columns = _delimit_object_names.(get_column_names(pg_params, schema_table))
        insert_string = schema_table  # expects select cols to match entire target table schema
    else
        active_columns = _delimit_object_names.(split(replace(columns, " " => ""), ","))
        insert_string = "$schema_table($columns)"  # selected columns only
    end

    if on_conflict == :nothing
        conflict_str = " ON CONFLICT DO NOTHING"
    elseif on_conflict == :upsert
        pk = get_primary_key_name(pg_params, table_name)
        set_column_as = join(["$col = EXCLUDED.$col" for col in active_columns], ", ")
        conflict_str = " ON CONFLICT ($pk) DO UPDATE SET $set_column_as"
    elseif on_conflict == :error
        conflict_str = "" 
    else
        throw(PSQLInterfaceException("Incorrect conflict resolution (:$(on_conflict)). The on_conflict options are :upsert, :error, or :nothing"))
    end

    upsert_script = """
    CREATE TABLE $tmp AS
    $select_script;

    INSERT INTO $insert_string
    SELECT *
    FROM $tmp
    $conflict_str;
    DROP TABLE IF EXISTS $tmp;
    """ 

    execute_psql_string(upsert_script)
    return nothing
end

write_to_table(df::AbstractDataFrame, table_name::AbstractString; kwargs...) = write_to_table(global_psql_config(), df, table_name; kwargs...)
write_to_table(data::AbstractVector{Vector}, column_names::Union{AbstractVector, Tuple}, table_name::AbstractString; kwargs...) = write_to_table(global_psql_config(), data, column_names, table_name; kwargs...) 
write_to_table(select_script::String, table_name::String, schema::String, columns=nothing; kwargs...) = write_to_table(global_psql_config(), select_script, table_name, schema, columns; kwargs...)


"""
    batched_write_to_table([::PostgreSQLConnectionParams], df::AbstractDataFrame, table_name::AbstractString, [batch_size::Integer])
    batched_write_to_table([::PostgreSQLConnectionParams], data::AbstractVector{Vector}, column_names::Union{AbstractVector, Tuple}, table_name::AbstractString, [batch_size::Integer])

Write data into a table in the postgres database, batched into `batch_size` rows at a time. By default the
batch size is 500, and the maximum batch size is the total number of rows in the  data.
"""
function batched_write_to_table(pg_params::PostgreSQLConnectionParams, df::AbstractDataFrame, table_name::AbstractString, batch_size::Integer=500)
    total_length = size(df)[1]
    batch_size = min(batch_size, total_length)
    current_length = 0
    while (current_length + batch_size) < total_length
        subdf = @view df[(current_length+1):(current_length+batch_size), :]
        write_to_table(pg_params, subdf, table_name)
        current_length += batch_size
    end
    subdf = @view df[(current_length+1):end, :]
    write_to_table(pg_params, subdf, table_name)
    return nothing
end
function batched_write_to_table(
        pg_params::PostgreSQLConnectionParams,
        data::AbstractVector{Vector},
        column_names::Union{AbstractVector, Tuple},
        table_name::AbstractString,
        batch_size::Integer=500
    )
    total_length = length(data[1])
    batch_size = min(batch_size, total_length)
    current_length = 0
    while (current_lenth + batch_size) < total_length
        data_view = [@view data_row[(current_length+1):(current_length+batch_size)] for data_row in data]
        write_to_table(pg_params, data_view, column_names, table_name)
        current_length += batch_size
    end
    data_view = [@view data_row[(current_length+1):end] for data_row in data]
    write_to_table(pg_params, data_view, column_names, table_name)
    return nothing
end
batched_write_to_table(df::AbstractDataFrame, table_name::AbstractString, batch_size::Integer=500) = batched_write_to_table(global_psql_config(), df, table_name, batch_size)
batched_write_to_table(data::AbstractVector{Vector}, column_names::Union{AbstractVector, Tuple}, table_name::AbstractString, batch_size::Integer=500) = batched_write_to_table(global_psql_config(), data, column_names, table_name, batch_size) 


"""
    copy_to_table([::PostgreSQLConnectionParams], df, table_name::AbstractString, options=Dict{String, String}(); 
        on_conflict::Symbol=:error,
        ignore_missing::Bool=false,
        ref_table::Union{AbstractString,Nothing}=nothing)

Efficiently load dataframe into table by copying a csv-style iterator.
The `ON CONFLICT` PSQL behaviour can be controlled using the `on_conflict` keyword argument one of the following symbols.
- `:error` (default)
- `:upsert`
- `:nothing`
`ignore_missing` defines the ability to only insert into a table if the ref_table has this data. ref_table should be given.
"""
copy_to_table(df, table_name::AbstractString; kwargs...) = copy_to_table(global_psql_config(), df, table_name::AbstractString; kwargs...)
function copy_to_table(pg_params::PostgreSQLConnectionParams,
                       df,
                       table_name::AbstractString,
                       options=Dict{String, String}();
                       on_conflict::Symbol=:error,
                       ignore_missing::Bool=false,
                       ref_table::Union{AbstractString,Nothing}=nothing)
    @debug "Copying dataframe to PostgreSQL table: $table_name"
    if on_conflict == :upsert
        return _copy_to_table_with_conflict_handling(pg_params, df, table_name, options; upsert=true, ignore_missing=ignore_missing, ref_table=ref_table)
    elseif on_conflict == :nothing
        return _copy_to_table_with_conflict_handling(pg_params, df, table_name, options; upsert=false, ignore_missing=ignore_missing, ref_table=ref_table)
    elseif on_conflict == :error
        return _copy_to_table_error(pg_params, df, table_name, options)
    end
    throw(PSQLInterfaceException("Incorrect conflict resolution (:$(on_conflict)). The on_conflict options are :upsert, :error, or :nothing"))
end


"""
    _copy_to_table_error(pg_params::PostgreSQLConnectionParams, df, table_name::AbstractString, options=Dict{String, String}())

Internal function for copying tables into psql, erroring on CONFLICT.
"""
function _copy_to_table_error(pg_params::PostgreSQLConnectionParams, df, table_name::AbstractString, options=Dict{String, String}())
    @warn "Copy with error will force update conflicts"
    uuid = uuid4().value
    tmp_table = "\"tmp_table_$uuid\""
    _table_name = _delimit_object_names(table_name)
    with_postgresql(pg_params, options) do psql
        try
            # Create temp table
            tmp = """
            CREATE TABLE $tmp_table AS
            SELECT * 
            FROM $_table_name
            WITH NO DATA;
            """
            execute(psql, tmp)

            # Write to temp table
            iter = CSV.RowWriter(df, writeheader=false)
            cols = _delimit_object_names.(names(df))
            column_names = join(cols, ",")
            copy_string = "COPY $tmp_table ($column_names) FROM STDIN (FORMAT CSV);"
            copyin = LibPQ.CopyIn(copy_string, iter)
            execute(psql, copyin)

            pk = get_primary_key_name(pg_params, table_name)
            all_columns = join(["$col = EXCLUDED.$col" for col in cols], ", ")
            conflict_str = "ON CONFLICT ($pk) DO UPDATE SET $all_columns"
            
            # Migrate to real table
            migrate = """
            INSERT INTO $_table_name
            SELECT *
            FROM $tmp_table
            $conflict_str;
            """
            execute(psql, migrate)
        finally
            clean_up = "DROP TABLE IF EXISTS $tmp_table;"
            execute(psql, clean_up)
        end
    end
    return nothing
end


"""
    _copy_to_table_with_conflict_handling(
        pg_params::PostgreSQLConnectionParams,
        df,
        table_name::AbstractString,
        options=Dict{String, String}();
        upsert=true,
        ignore_missing=false,
        ref_table=nothing
    )

Uses the PostgreSQL `\\COPY` keyword to load a DataFrame into postgres, updates rows with unique key violation.
"""
function _copy_to_table_with_conflict_handling(
        pg_params::PostgreSQLConnectionParams,
        df,
        table_name::AbstractString,
        options=Dict{String, String}();
        upsert=true,
        ignore_missing=false,
        ref_table=nothing
    )
    uuid = uuid4().value
    tmp_table = "\"tmp_table_$uuid\""
    _table_name = _delimit_object_names(table_name)

    with_postgresql(pg_params, options) do psql
        try
            tmp = """
                CREATE TABLE $tmp_table AS
                SELECT * 
                FROM $_table_name
                WITH NO DATA;
            """
            execute(psql, tmp)

            iter = CSV.RowWriter(df)
            cols = _delimit_object_names.(names(df))
            column_names = join(cols, ",")
            copy_string = "COPY $tmp_table ($column_names) FROM STDIN (FORMAT CSV, HEADER);"
            copyin = LibPQ.CopyIn(copy_string, iter)
            execute(psql, copyin)

            pk = get_primary_key_name(pg_params, table_name)
            conflict_str = "ON CONFLICT DO NOTHING"
            if upsert
                all_columns = join(["$col = EXCLUDED.$col" for col in cols], ", ")
                conflict_str = "ON CONFLICT ($pk) DO UPDATE SET $all_columns"
            end
            
            ignore_string = ""
            if ignore_missing
                _ref_table = isnothing(ref_table) ? _table_name : _delimit_object_names(ref_table)
                ref_pk = get_primary_key_name(_ref_table)
                if contains(ref_pk, ",") # Result will be a stringified list
                    pk_match = join(["rt.$ref_pk_item = $tmp_table.$ref_pk_item" for ref_pk_item in split(ref_pk, ", ")], " and ")
                else 
                    pk_match = "rt.$ref_pk = $tmp_table.$ref_pk"
                end
                ignore_string = "WHERE EXISTS (SELECT '1' FROM $_ref_table as rt where $pk_match)"
            end

            migrate = """
                INSERT INTO $_table_name
                SELECT *
                FROM $tmp_table
                $ignore_string $conflict_str;
            """
            execute(psql, migrate)
        finally
            clean_up = "DROP TABLE IF EXISTS $tmp_table"
            execute(psql, clean_up)
        end
    end
    return nothing
end


"""
    get_primary_key_name([::PostgreSQLConnectionParams], table_name::AbstractString, options=Dict{String, String}())::String

Collects the column name of the provided tables primary key.
"""
function get_primary_key_name(pg_params::PostgreSQLConnectionParams, table_name::AbstractString, options=Dict{String, String}())::String
    @debug "Getting primary key name from $table_name"
    pk_query = "
        SELECT a.attname
        FROM pg_index i
        JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
        WHERE i.indrelid = '$(_delimit_object_names(table_name))'::regclass
        AND i.indisprimary
    "
    with_postgresql(pg_params, options) do psql
        result = execute(psql, pk_query)
        return "\"" * join(columntable(result).attname, "\", \"") * "\""
    end
end
get_primary_key_name(table_name::AbstractString)::String = get_primary_key_name(global_psql_config(), table_name)


"""
    execute_psql_from_file([pg_params::PostgreSQLConnectionParams], 
                           filename::AbstractString; 
                           options=Dict{String, String}(), 
                           parameters::Union{AbstractVector,Tuple}=()
                           )

Executes the provided file as a PostgreSQL string in the defined Postgres connection.
The returned value is not wrapped, and will be a LibPQ data object that works with the
table interface. It's recommended to wrap this function in `columntable` which creates
a `NamedTuple`, or with `DataFrame` which creates a `DataFrame`.

# Arguments
- `pg_params::PostgreSQLConnectionParams`: PostgreSQL connection params, will use global if 
  not provided.
- `filename::AbstractString`: The SQL file to execute.

# Keyword arguments
- `options::Dict{String, String}`: Options to pass to `with_postgresql`.
- `parameters::Union{AbstractVector,Tuple}`: Parameters for the SQL script. Replaces `\$1`, 
  `\$2`, etc. 
  WARNING: USING THIS FUNCTION WITH `parameters` ONLY SUPPORTS A SINGLE SQL STATEMENT.
  See the following for more info:
    - https://docs.juliahub.com/LibPQ/LeQQU/1.6.0/autodocs/#LibPQ.execute
    - https://www.postgresql.org/docs/current/libpq-exec.html#id-1.7.3.10.3.3.1.1.1.2
"""
function execute_psql_from_file(pg_params::PostgreSQLConnectionParams, 
                                filename::AbstractString; 
                                options=Dict{String, String}(), 
                                parameters::Union{Nothing,AbstractVector,Tuple}=nothing
                                )
    @debug "Executing the PSQL query from $filename in $(dbname(pg_params))"
    open(filename, "r") do content_io
        content_text = read(content_io, String)
        with_postgresql(pg_params, options) do psql
            if isnothing(parameters)
                return execute(psql, content_text)
            else
                return execute(psql, content_text, parameters)
            end
        end
    end
end
execute_psql_from_file(filename::AbstractString; kwargs...) = execute_psql_from_file(global_psql_config(), filename; kwargs...)

"""
    execute_sql_script(pg_params::PostgreSQLConnectionParams, script_location::String)

Executes a sql script, with ability to override default PostgreSQLConnectionParams.

# Arguments
- `pg_params::PostgreSQLConnectionParams`
- `script_location::String`: The location of the script.
"""
function execute_sql_script(pg_params::PostgreSQLConnectionParams, script_location::String)
    working_dir = dirname(script_location)
    
    if pg_params.iam_connection
        pg_params.password = get_valid_token(pg_params)
        # Redshift get_Credentials prepends IAM:
        if pg_params.db_type == :REDSHIFT && !startswith(pg_params.username, "IAM:")
            pg_params.username = "IAM:" * pg_params.username
        end
    end

    run(`psql postgresql://$(pg_params.user):$(HTTP.escapeuri(pg_params.password))@$(pg_params.endpoint)/$(pg_params.dbname) -v working_dir=$working_dir -a -f $script_location`)
end
execute_sql_script(script_location::String) = execute_sql_script(global_psql_config(), script_location)

"""
    schema_exists([::PostgreSQLConnectionParams], schema_name::AbstractString, options=Dict{String, String}())

Checks the provided schema exists in the defined Postgres connection.
"""
function schema_exists(pg_params::PostgreSQLConnectionParams, schema_name::AbstractString, options=Dict{String, String}())
    @debug "Checking if $schema_name exists in $(dbname(pg_params))"
    with_postgresql(pg_params, options) do psql
        data = columntable(execute(psql,"SELECT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname = '$(schema_name)');"))
        return data.exists[1]
    end
end
schema_exists(schema_name::AbstractString) = schema_exists(global_psql_config(), schema_name)


"""
    truncate_table([::PostgreSQLConnectionParams], table_name::AbstractString, options=Dict{String, String}())

Truncates all the data in the table, or schema-specific table, from the defined Postgres connection.
"""
function truncate_table(pg_params::PostgreSQLConnectionParams, table_name::AbstractString, options=Dict{String, String}())
    @warn "Truncating $table_name in the $(dbname(pg_params)) database. This is a cascade"
    with_postgresql(pg_params, options) do psql
        execute(psql, "TRUNCATE $(_delimit_object_names(table_name)) CASCADE;")
    end
    return nothing
end
truncate_table(table_name::AbstractString) = truncate_table(global_psql_config(), table_name)


"""
    function select_from_table(
        [::PostgreSQLConnectionParams],
        table_name::AbstractString
        return_as_df::Bool,
        options=Dict{String, String}();
        target_column_map::AbstractVector{<:AbstractDict{<:AbstractString, <:AbstractString}}=Vector{Dict{String, String}}(),
        filter_metadata::AbstractVector{Dict{String, String}}=Vector{Dict{String, String}}()
    )

Selects data from the provided table, based on any subselection of column names and filtering options. 
It is returned as a column table, depending on the value of the `return_as_df` argument the return type will be either
a DataFrame or a PostgresSQL result.

# Arguments
- `[pg_params::PostgreSQLConnectionParams]`,
- `table_name::AbstractString`,
- `return_as_df::Bool`;
    - Set this true to return the data as a DataFrame, else return data would be of type PostgreSQL result.
- `target_column_map::AbstractVector{<:AbstractDict{<:AbstractString, <:AbstractString}}=Vector{Dict{String, String}}()`,
    - If this is an empty vector, all columns are selected with no name mapping.
    - Each element should be a dictionary
    - The dictionary should have a `name` field . **This is required**
    - The dictionary can have an optional `mapping` field to map the column to a new name.
    - Casting or creating a column definition is not supported, and these columns will be skipped.
- `filter_metadata::AbstractVector{Dict{String, String}}=Vector{Dict{String, String}}()`
    - The dictionaries can be 1 of 2 formats, each dictionary can strictly be 1 of the 2 types. It CANNOT include fields from both formats.
    - The 2 formats are:
        - Format 1:
            - The dictionaries require 3 keys: `column_name`, `operator`, and `value`
            - By default, `operator` is assumed to be `"="`
            - All other fields are required
            - E.g. [Dict("column_name"=>"way_id, "operator"=>"=", "value"=>"24143-B")]
        - Format 2:
            - The dictionaries require 1 key: `string_statement`
            - The value of the corresponding `string_statement` key is a condition as a string.
                - E.g. "way_id is NULL" or "e_way_type_pretty IN ('Motorway','Tollway')"
            - All fields are required for this format.
                - E.g. [Dict("string_statement"=>"e_way_type_pretty IN ('Motorway','Tollway')")]
    - If both formats are needed then it is highly recommended to have an array with a dictionary of 1 format while the other dictionary of another format.
        - E.g. [Dict("column_name"=>"way_id, "operator"=>"=", "value"=>"24143-B"), Dict("string_statement"=>"e_way_type_pretty is NULL")]
"""
function select_from_table(
        pg_params::PostgreSQLConnectionParams,
        table_name::AbstractString,
        return_as_df::Bool,
        options=Dict{String, String}();
        target_column_map::AbstractVector{<:AbstractDict{<:AbstractString, <:AbstractString}}=Vector{Dict{String, String}}(),
        filter_metadata::AbstractVector{<:AbstractDict{<:AbstractString, <:Any}}=Vector{Dict{String, Any}}()
    )
    column_names = _delimit_object_names.(get_column_names(pg_params, table_name))
    select_statement = "SELECT \n"

    if length(target_column_map) == 0
        #TODO: get table columnn names to make sure filtering works later.
        select_statement *= "\t*\n"
    end

    for (i, column) in enumerate(target_column_map)
        !haskey(column, "name") && throw(PSQLInterfaceException("All column definitions require a name."))
        col_name = _delimit_object_names(column["name"])

        if col_name ∉ column_names
            @warn "$(column["name"]) not in $(table_name) and will not be collected. If this is a cast or other function, please make an executable string."
            continue
        end

        as_target = _delimit_object_names(get(column, "mapping", column["name"]))
        select_statement *= "$(col_name) as $(as_target)"

        if i < length(target_column_map)
            select_statement *= ","
        end

        select_statement *= "\n"
    end

    select_statement *= " FROM $(_delimit_object_names(table_name))\n"

    if length(filter_metadata) > 0
        for dict in filter_metadata
            if haskey(dict, "string_statement") && (haskey(dict, "column_name") || haskey(dict, "operator") || haskey(dict, "value"))
                @warn "Format 1 & 2 has been found in the same dictionary."
            end
        end
        # If Dict has "string_statement" key THEN append string from "string_statment" ELSE create string from "column_name", "operator" & "value"
        select_statement *= " WHERE " * join(
            [
                haskey(filter_dict, "string_statement") ? "$(filter_dict["string_statement"])" : "$(_delimit_object_names(filter_dict["column_name"])) $(get(filter_dict, "operator", "=")) $(get_value_str(filter_dict["value"]))" 
                for filter_dict in filter_metadata
            ],
            "\n AND "
        )
    end


    with_postgresql(pg_params, options) do psql
        result = execute(psql, select_statement)
        if return_as_df
            return DataFrame(result)
        else
            return result
        end
    end
end
select_from_table(pg_params::PostgreSQLConnectionParams, table_name::AbstractString; kwargs...) = select_from_table(pg_params, table_name, true; kwargs...)
select_from_table(table_name::AbstractString, args...; kwargs...) = select_from_table(global_psql_config(), table_name, args...; kwargs...)
"""
    select_from_table_raw(pg_params::PostgreSQLConnectionParams, table_name::AbstractString; kwargs...)

Selects data from the provided table, based on any subselection of column names and filtering options and returns data in raw PostgreSQL result format.
Refer to the select_fromt_table() docstring for more details.
"""
select_from_table_raw(pg_params::PostgreSQLConnectionParams, table_name::AbstractString; kwargs...) = select_from_table(pg_params, table_name, false; kwargs...)
select_from_table_raw(table_name::AbstractString, args...; kwargs...) = select_from_table_raw(global_psql_config(), table_name, args...; kwargs...)


"""
    function remove_and_return_from_table(
        [::PostgreSQLConnectionParams],
        table_name::AbstractString,
        options=Dict{String, String}();
        returning_columns::AbstractVector{<:AbstractDict{<:AbstractString, <:AbstractString}}=Vector{Dict{String, String}}(),
        filter_metadata::AbstractVector{Dict{String, String}}=Vector{Dict{String, String}}()
    )::DataFrame

Removes data from the provided table, based on filtering options. 
The removed data is returned as a column table, represented as a DataFrame.

# Arguments
- `[pg_params::PostgreSQLConnectionParams]`,
- `table_name::AbstractString`,
- `return_as_df::Bool`;
    - Set this true to return the data as a DataFrame, else return data would be of type PostgreSQL result.
- `returning_columns::AbstractVector{<:AbstractDict{<:AbstractString, <:AbstractString}}=Vector{Dict{String, String}}()`,
    - If this is an empty vector, all columns are selected.
    - Each element should be a dictionary
    - The ditionary should have a `name` field . **This is required**
- `filter_metadata::AbstractVector{Dict{String, String}}=Vector{Dict{String, String}}()`
    - The dictionaries require 3 keys: `column_name`, `operator`, and `value`
    - By default, `operator` is assumed to be `"="`
    - All other fields are required
"""
function remove_and_return_from_table(
        pg_params::PostgreSQLConnectionParams,
        table_name::AbstractString,
        return_as_df::Bool,
        return_data::Bool,
        options=Dict{String, String}();
        returning_columns::AbstractVector{<:AbstractDict{<:AbstractString, <:AbstractString}}=Vector{Dict{String, String}}(),
        filter_metadata::AbstractVector{<:AbstractDict{<:AbstractString, <:Any}}=Vector{Dict{String, Any}}()
    )
    remove_statement = "DELETE FROM $(_delimit_object_names(table_name))\n"
    if length(filter_metadata) > 0
        remove_statement *= " WHERE " * join([
            "$(_delimit_object_names(filter_dict["column_name"])) $(get(filter_dict, "operator", "=")) $(get_value_str(filter_dict["value"]))" 
            for filter_dict in filter_metadata
            ],
            "\n AND ")
    end
    if return_data
        if length(returning_columns) > 0
            remove_statement *= "\nRETURNING " * join([
                "$(_delimit_object_names(returning["name"]))"
                for returning in returning_columns
                ], ",")
        else
            remove_statement *= "\nRETURNING\t*"
        end
    end
    @debug remove_statement
    with_postgresql(pg_params, options) do psql
        result = execute(psql, remove_statement)
        if return_as_df
            return DataFrame(result)
        else
            return result
        end
    end
end
remove_and_return_from_table(pg_params::PostgreSQLConnectionParams, table_name::AbstractString; kwargs...) = remove_and_return_from_table(pg_params, table_name, true, true; kwargs...)
remove_and_return_from_table(table_name::AbstractString, args...; kwargs...) = remove_and_return_from_table(global_psql_config(), table_name, args...; kwargs...)

"""
    remove_and_return_from_table_raw(pg_params::PostgreSQLConnectionParams, table_name::AbstractString; kwargs...)

Removes data from the provided table, based on any subselection of column names and filtering options and returns data in raw PostgreSQL result format.
Refer to the `remove_and_return_from_table` docstring for more details.
"""
remove_and_return_from_table_raw(pg_params::PostgreSQLConnectionParams, table_name::AbstractString; kwargs...) = remove_and_return_from_table(pg_params, table_name, false, true; kwargs...)
remove_and_return_from_table_raw(table_name::AbstractString, args...; kwargs...) = remove_and_return_from_table_raw(global_psql_config(), table_name, args...; kwargs...)

"""
    remove_from_table(pg_params::PostgreSQLConnectionParams, table_name::AbstractString; kwargs...)

Removes data from the provided table, based on any subselection of column names and filtering options.
Refer to the `remove_and_return_from_table` docstring for more details.
"""
remove_from_table(pg_params::PostgreSQLConnectionParams, table_name::AbstractString; kwargs...) = remove_and_return_from_table(pg_params, table_name, false, false; kwargs...)
remove_from_table(table_name::AbstractString, args...; kwargs...) = remove_from_table(global_psql_config(), table_name, args...; kwargs...)

"""
    get_table_length([::PostgreSQLConnectionParams], table_name::AbstractString, options=Dict{String, String}())
    get_table_length([::PostgreSQLConnectionParams], schema_name::AbstractString, table_name::AbstractString, options=Dict{String, String}())

Lazy evaluation of the table length using `COUNT(*)`.
"""
function get_table_length(pg_params::PostgreSQLConnectionParams, table_name::AbstractString, options=Dict{String, String}())
    count_statement = "SELECT COUNT(*) AS ROW_COUNT FROM $(_delimit_object_names(table_name));"
    with_postgresql(pg_params, options) do psql
        output = columntable(execute(psql, count_statement))
        return (output.row_count[1])
    end
end
get_table_length(table_name::AbstractString, options=Dict{String, String}()) = get_table_length(global_psql_config(), table_name, options)
get_table_length(schema_name::AbstractString, table_name::AbstractString, options=Dict{String, String}()) =  get_table_length(global_psql_config(), schema_name * "." * table_name, options)
get_table_length(pg_params::PostgreSQLConnectionParams, schema_name::AbstractString, table_name::AbstractString, options=Dict{String, String}()) =  get_table_length(pg_params, schema_name * "." * table_name, options)

"""
    is_table_populated([::PostgreSQLConnectionParams], table_name::AbstractString, options=Dict{String, String}())::Bool

Checks that the provided table name, or schema and table combination, exists in the defined Postgres connection.
"""
function is_table_populated(pg_params::PostgreSQLConnectionParams, table_name::AbstractString, options=Dict{String, String}())::Bool
    @debug "Checking if $table_name is populated"
    return get_table_length(pg_params, _delimit_object_names(table_name), options) > 0
end
is_table_populated(table_name::AbstractString) = is_table_populated(global_psql_config(), table_name)


"""
    execute_psql_string([::PostgreSQLConnectionParams], psql_string::AbstractString, options=Dict{String, String}())

Executes the provided PostgreSQL formatted string in the defined Postgres connection.

# Arguments
- `pg_params::PostgreSQLConnectionParams`: PostgreSQL connection params, will use global if 
  not provided.
- `psql_string::AbstractString`: The SQL string to execute.

# Keyword arguments
- `options::Dict{String, String}`: Options to pass to `with_postgresql`.
- `parameters::Union{AbstractVector,Tuple}`: Parameters for the SQL script. Replaces `\$1`, 
  `\$2`, etc. 
  WARNING: USING THIS FUNCTION WITH `parameters` ONLY SUPPORTS A SINGLE SQL STATEMENT.
  Example:
  ```julia
  execute_psql_string(
      "select * from map_manager.mm_featurewhere layer_id = \$1 limit \$2;",
      parameters=("DECLARED_NETWORK", 5)
  )
  ```
  See the following for more info:
    - https://docs.juliahub.com/LibPQ/LeQQU/1.6.0/autodocs/#LibPQ.execute
    - https://www.postgresql.org/docs/current/libpq-exec.html#id-1.7.3.10.3.3.1.1.1.2
"""
function execute_psql_string(pg_params::PostgreSQLConnectionParams, 
                             psql_string::AbstractString;
                             options=Dict{String, String}(), 
                             parameters::Union{Nothing,AbstractVector,Tuple}=nothing
                             )
    @debug "Executing a PSQL query from a string"
    @debug psql_string
    with_postgresql(pg_params, options) do psql
        if isnothing(parameters)
            return execute(psql, psql_string)
        else
            return execute(psql, psql_string, parameters)
        end
    end
end
execute_psql_string(psql_string::AbstractString; kwargs...) = execute_psql_string(global_psql_config(), psql_string; kwargs...)

"""
    execute_psql_string_await([::PostgreSQLConnectionParams], psql_string::AbstractString, wait::Bool, options=Dict{String, String}())

Executes the provided PostgreSQL formatted string in the defined Postgres connection.
Uses the async_execute process optionally awaiting a result if needed.

Arguments:
- `pg_params::PostgreSQLConnectionParams
- `psql_string::AbstractString`
- `wait::Bool`: flag to await result or not
- `options::Dict{String, String}`: Options which is required to clear out RedShift incompatible options
- `nowarn=false`: Sneaky warning suppression without having to use suppressor
Returns:
- `result::Union{LibPQ.AsyncResult, LibPQ.Result}`: Async query result or completed result
"""
function execute_psql_string_await(pg_params::PostgreSQLConnectionParams, psql_string::AbstractString, wait::Bool, options=Dict{String, String}(), nowarn=false)
    !nowarn && @debug "Executing a PSQL query from a string"
    @debug psql_string
    with_postgresql(pg_params, options) do psql
        result = async_execute(psql, psql_string)
        if wait
            return fetch(result)
        else
            return result
        end
    end
end
execute_psql_string_await(psql_string::AbstractString) = execute_psql_string_await(global_psql_config(), psql_string, true)


"""
    execute_psql_string_copyin([::PostgreSQLConnectionParams], psql_string::AbstractString, data_iter, options=Dict{String, String}())

Executes the provided PostgreSQL formatted string in the defined Postgres connection.
Uses CopyIn method to execute psql string and data iterable.

Arguments:
- `pg_params::PostgreSQLConnectionParams`
- `psql_string::AbstractString`
- `data_iter`: Data iterable.
"""
function execute_psql_string_copyin(pg_params::PostgreSQLConnectionParams, psql_string::AbstractString, data_iter, options=Dict{String, String}())
    @debug "Executing a PSQL CopyIn Command"
    @debug psql_string
    with_postgresql(pg_params, options) do psql
        execute(psql, LibPQ.CopyIn(psql_string, data_iter))
    end
end
execute_psql_string_copyin(psql_string::AbstractString, data_iter) = execute_psql_string_copyin(global_psql_config(), psql_string, data_iter)


"""
    make_schema([::PostgreSQLConnectionParams], schema_name::AbstractString, options=Dict{String, String}())

Creates the provided schema in the defined Postgres connection.
"""
function make_schema(pg_params::PostgreSQLConnectionParams, schema_name::AbstractString, options=Dict{String, String}())
    @debug "Creating a new schema namespace `$(schema_name)` in the $(dbname(pg_param)) database"
    with_postgresql(pg_params, options) do psql
        execute(psql, "CREATE SCHEMA IF NOT EXISTS $(_delimit_object_names(schema_name));")
    end
    return nothing
end
make_schema(schema_name::AbstractString) = make_schema(global_psql_config(), schema_name)


"""
    get_column_names([::PostgreSQLConnectionParams], table_name::AbstractString)::Vector{String}

Gets the column names of the supplied table and returns them as a vector of strings.
"""
function get_column_names(pg_params::PostgreSQLConnectionParams, table_name::AbstractString)::Vector{String}
    @debug "Getting column names from $table_name"
    col_names = names(DataFrame(
        execute_psql_string(pg_params, "Select * from $(_delimit_object_names(table_name)) where false;")
    ))
    return col_names
end
get_column_names(table_name::AbstractString) = get_column_names(global_psql_config(), table_name)

"""
    get_table_definition(pg_params::PostgreSQLConnectionParams,
        schema_name::AbstractString,
        table_name::AbstractString,
        return_as_df::Bool,
        options=Dict{String, String}())

Gets the column descriptions suitable for recreation if the table is archived to CSV.
Info includes:
    - table name
    - column names
    - column ordering
    - column types
    - column type detail, such as max char length, numeric precision
    - element type, if an array
    - column nullability
    - key status

# Arguments:
- `pg_params::PostgreSQLConnectionParams`: postgres params
- `schema_name::String`: name of the tables schema (usually "public")
- `table_name::String`: name of the table name itself
- `return_as_df::Bool`: if returning as a dataframe, default is `PostgreSQL result`
# Returns:
- `result::Union{DataFrame,LibPQ.Result}`: column details
"""
function get_table_definition(pg_params::PostgreSQLConnectionParams,
        schema_name::AbstractString,
        table_name::AbstractString,
        return_as_df::Bool,
        options=Dict{String, String}())
    @debug "Extracting from information_schema for: $schema_name.$table_name"

    _schema_name = _delimit_object_names(schema_name)
    _table_name = _delimit_object_names(table_name)
    
    # Queries to the information schema but also the element_types for the array types
    qry = """
        with keys as (
            select
                pg_attribute.attname
            from pg_index, pg_class, pg_attribute, pg_namespace 
            where 
                pg_class.oid = '$(_schema_name).$(_table_name)'::regclass
                and indrelid = pg_class.oid
                and nspname = '$(schema_name)'
                and pg_class.relnamespace = pg_namespace.oid
                and pg_attribute.attrelid = pg_class.oid
                and pg_attribute.attnum = any(pg_index.indkey)
                and indisprimary)
        SELECT c.ordinal_position, c.table_name, c.column_name, c.udt_name, c.character_maximum_length, 
            e.udt_name AS element_type, c.column_default, c.is_nullable,
            k.attname is not null as is_key
        FROM information_schema.columns c LEFT JOIN information_schema.element_types e
            ON ((c.table_catalog, c.table_schema, c.table_name, 'TABLE', c.dtd_identifier)
            = (e.object_catalog, e.object_schema, e.object_name, e.object_type, e.collection_type_identifier))
            LEFT JOIN keys k on c.column_name = k.attname
        WHERE c.table_schema = '$(schema_name)' AND c.table_name = '$(table_name)'
        ORDER BY c.ordinal_position;
        """
    
    with_postgresql(pg_params, options) do psql
        result = execute(psql, qry)
        if return_as_df
            return DataFrame(result)
        else
            return result
        end
    end

end
get_table_definition(schema_name::AbstractString, table_name::AbstractString) = get_table_definition(global_psql_config(), schema_name, table_name, false)
get_table_definition(schema_name::AbstractString, table_name::AbstractString, return_as_df) = get_table_definition(global_psql_config(), schema_name, table_name, return_as_df)


"""
    get_constraint_definition(pg_params::PostgreSQLConnectionParams,
        schema_name::AbstractString,
        table_name::AbstractString,
        return_as_df::Bool,
        options=Dict{String, String}())

Queries information about the constraints of a table including information enough to generate DDL later on.
Info includes:
    - constraint name
    - type
    - table name
    - specific actions, such as ON DELETE [...]
    - foreign key info
        - table referenced
        - column referenced

# Arguments:
- `pg_params::PostgreSQLConnectionParams`: postgres params
- `schema_name::String`: name of the tables schema (usually "public")
- `table_name::String`: name of the table name itself
- `return_as_df::Bool`: if returning as a dataframe, default is `PostgreSQL result`
# Returns:
- `result::Union{DataFrame,LibPQ.Result}`: column details

"""
function get_constraint_definition(pg_params::PostgreSQLConnectionParams,
    schema_name::AbstractString,
    table_name::AbstractString,
    return_as_df::Bool,
    options=Dict{String, String}())

    @debug "Extracting from information_schema for: $schema_name.$table_name"

    qry = """
        select 
            tc.constraint_name,
            tc.constraint_type,
            tc.table_name,
            kcu.column_name,
            tc.is_deferrable,
            tc.initially_deferred,
            rc.match_option,
            rc.update_rule,
            rc.delete_rule,
            ccu.table_name as table_referenced,
            ccu.column_name as column_referenced
        from information_schema.table_constraints tc
        left join information_schema.key_column_usage kcu
            on tc.constraint_catalog = kcu.constraint_catalog
            and tc.constraint_schema = kcu.constraint_schema
            and tc.constraint_name = kcu.constraint_name
        left join information_schema.referential_constraints rc
            on tc.constraint_catalog = rc.constraint_catalog
            and tc.constraint_schema = rc.constraint_schema
            and tc.constraint_name = rc.constraint_name
        left join information_schema.constraint_column_usage ccu
            on rc.unique_constraint_catalog = ccu.constraint_catalog
            and rc.unique_constraint_schema = ccu.constraint_schema
            and rc.unique_constraint_name = ccu.constraint_name
        where tc.table_name = '$(table_name)'
            and tc.constraint_schema = '$(schema_name)'
    """
     
    with_postgresql(pg_params, options) do psql
        result = execute(psql, qry)
        if return_as_df
            return DataFrame(result)
        else
            return result
        end
    end

end
get_constraint_definition(schema_name::AbstractString, table_name::AbstractString) = get_constraint_definition(global_psql_config(), schema_name, table_name, false)
get_constraint_definition(schema_name::AbstractString, table_name::AbstractString, return_as_df) = get_constraint_definition(global_psql_config(), schema_name, table_name, return_as_df)
