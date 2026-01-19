"""
    source_ingestion(source_name; refresh_data=true, debug=false, file=nothing)

Run the ingestion process for a given source. Steps are:
1. Ingest pre-requisite sources
2. Download the source data
3. Convert from raw format to a DataFrame
4. Write DataFrame to the database in a staging table
5. Execute transform/load SQL script to move data from staging to final table
6. Run post-processing functions

# Arguments
- `source_name::Symbol`: The name of the source to ingest
- `refresh_data::Bool`: Whether to force run the ingestion process even if the source has already been ingested
- `debug::Bool`: Debug flag, disables staging table drop
- `file`: Optional file content to use instead of downloading from source
"""
function source_ingestion(source_name; refresh_data=true, debug=false, file=nothing)
    @info "============== STARTING INGESTION PROCESS FOR $(source_name) =============="

    # Enforce uppercase to improve error handling
    source_name = Symbol(uppercase(string(source_name)))
    # TODO check add line to check if CONFIG is loaded if not -> load CONFIG
    source_config = CONFIG[][source_name]

    # Check if the source has previously been ingested
    if INGESTION_LIST[][source_name]
        @info "Already ingested $(source_name) - skipping"
        return nothing
    end

    # Loads all required pre-requisite sources
    if !isempty(source_config.prerequisite_sources)
        @info "Loading pre-requisite source data before proceeding: $(source_config.prerequisite_sources)"
        for prereq_source in source_config.prerequisite_sources
            source_ingestion(prereq_source; refresh_data=false)
            @info "$(source_name) - Finished load of prerequisite source: $(prereq_source)"
        end
    end
    
    # Ingest file from source
    if isnothing(file)
        file = download_source(source_config)
    end

    # Convert from raw format to DataFrame
    df = convert_to_df(file, source_config)

    # Updates to lowercase for DB usage
    source_name_lower = lowercase(string(source_name))
    df_to_db(df, source_name_lower; debug=debug)

    # Once ingested set the Boolean to true
    INGESTION_LIST[][source_name] = true

    # Run post-processing functions
    for ppf in source_config.postprocessing
        # Check any conditions for this post-processing function
        if ppf.final_only && !refresh_data
            continue
        end

        @info "Running post-processing function $(ppf.fn)"
        ppf.fn()
    end

    return nothing
end

function df_to_db(df, source_name; script_directory=SCRIPT_DIRECTORY[], tz="Australia/Melbourne", debug=false)
    try
        execute_psql_string("SET timezone TO '$(tz)';")
        @info "Set PostgreSQL timezone to $(tz)"

        source_elt(df, source_name; path=script_directory, schema="map_manager", debug=debug)
        @info "Finished $(source_name) data load process"
    finally
        execute_psql_string("SET timezone TO 'GMT';")
        @info "Reset PostgreSQL timezone to GMT"
    end
end

function write_delta_to_db(source_delta::String, changeset_id::String; script_directory=SCRIPT_DIRECTORY[])
    file_name = "$(source_delta).sql"
    script_path = joinpath(script_directory, file_name)
    delta_statement = replace(read(script_path, String), ":changeset_id" => "'$changeset_id'")
    PSQLInterface.execute_psql_string(delta_statement)
end
