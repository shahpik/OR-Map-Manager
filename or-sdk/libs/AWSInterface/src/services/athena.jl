module AthenaInterface

using AWS
@service Athena

include("../exceptions/athena.jl")
include("../utilities.jl")

"""
    start_query_from_string(config=global_aws_config();
        output_location,
        catalogue="AwsDataCatalog",
        workgroup="primary",
        database,
        query)

`Arguments`:
- `config`: AWS Config for connection to the account
- `output_location::String`: Athena query output sent to which folder, required to be configured considering roles, etc
- `catalogue::String`: Athena catalogue where the database is, e.g. AwsDataCatalog
- `workgroup::String`: Athena workgroup with potential overwriting parameteres
- `database::String`: Database name to connect to, likely defined by glue catalogue
- `query::String`: SQL query to execute, this may potentially be rejected if no "where" or "limit" clause

`Returns`:
- `athena_query::Dict`: Result dictionary in the Athena structure, results in res["ResultSet"]["Rows"], that includes a row for the header
"""
function start_query_from_string(config=global_aws_config();
    output_location, 
    catalogue="AwsDataCatalog",
    workgroup="primary",
    database,
    query)

    if !is_valid_s3_path(output_location, :required)
        throw(AthenaPathError("Athena requires s3 paths with a trailing slash as the output_location"))
    end

    execution_params = _make_athena_parameters(output_location, database, catalogue, workgroup)

    athena_query = Athena.start_query_execution(query, execution_params; aws_config = config)

    return athena_query
end

"""
    query_from_string_and_await(config=global_aws_config();
        output_location,
        catalogue="AwsDataCatalog",
        workgroup="primary",
        database,
        query,
        all_results=true,
        results_per_increment_max=1000)

`Arguments`:
- `config`: AWS Config for connection to the account
- `output_location::String`: Athena query output sent to which folder, required to be configured considering roles, etc
- `catalogue::String`: Athena catalogue where the database is, e.g. AwsDataCatalog
- `workgroup::String`: Athena workgroup with potential overwriting parameteres
- `database::String`: Database name to connect to, likely defined by glue catalogue
- `query::String`: SQL query to execute, this may potentially be rejected if no "where" or "limit" clause
- `all_results::Boolean`: whether to show all results or the first n results
- `results_per_increment_max::Integer`: number of results per poll of Athena getting query results

`Returns`:
- `athena_query::Dict`: Result dictionary in the Athena structure, results in res["ResultSet"]["Rows"], that includes a row for the header

Example call: query_from_string_and_await(global_aws_config();
    output_location="s3://or-dot-post-monitoring/",
    catalogue="AwsDataCatalog",
    workgroup="primary",
    database="or-post-monitoring",
    query="select * from event_log_transformed where event_id = 'EVENT&&TOW_ALLOCATION&&1513566'",
    all_results=true,
    results_per_increment_max=15)

"""
function query_from_string_and_await(config=global_aws_config();
    output_location,
    catalogue="AwsDataCatalog",
    workgroup="primary",
    database,
    query,
    all_results=true,
    results_per_increment_max=1000)

    if !is_valid_s3_path(output_location, :required)
        throw(AthenaPathError("Athena requires s3 paths with a trailing slash as the output_location"))
    end

    execution_params = _make_athena_parameters(output_location, database, catalogue, workgroup)
    athena_query = Athena.start_query_execution(query, execution_params; aws_config=config)

    query_params = Dict{String, Any}()
    !isempty(results_per_increment_max) && push!(query_params, "MaxResults" => results_per_increment_max)

    # Query results are back as updates of status, so iterate and handle current status
    while true
        ex = Athena.get_query_execution(athena_query["QueryExecutionId"]; aws_config=config)
        status = ex["QueryExecution"]["Status"]["State"] 
        if status == "FAILED"
            details = ""
            if haskey(ex["QueryExecution"]["Status"], "StateChangeReason")
                details = "\n$(ex["QueryExecution"]["Status"]["StateChangeReason"])"
            end

            throw(AthenaQueryError("Athena query failed: $(query)$(details)"))
            return nothing
        elseif status == "CANCELLED"
            throw(AthenaQueryError("Athena query was cancelled: $(query)"))
            return nothing
        elseif status in ["QUEUED", "RUNNING"]
            sleep(0.1)
            continue
        end
        # else SUCCEEDED (only other available status)
        break
    end

    @debug "Query succeeded."

    all_results && return get_results_all(config; athena_query=athena_query, query_params=query_params)
    
    return get_results_single(config; athena_query=athena_query, query_params=query_params)
    
end

"""
    get_results_single(config; athena_query, query_params)

`Arguments`:
- `config`: AWS Config for connection to the account
- `athena_query::Dict`: Athena query dictionary containing QueryExecutionId
- `query_params::Dict`: Parameters to feed in to the get api endpoint, including MaxResults (relevant for get_results_single)

`Returns`:
- `athena_query::Dict`: Result dictionary in the Athena structure, results in res["ResultSet"]["Rows"], that includes a row for the header
"""
function get_results_single(config; athena_query, query_params)
    return Athena.get_query_results(athena_query["QueryExecutionId"], query_params; aws_config=config)
end

"""
    get_results_all(config; athena_query, query_params)

`Arguments`:
- `config`: AWS Config for connection to the account
- `athena_query::Dict`: Athena query dictionary containing QueryExecutionId
- `query_params::Dict`: Parameters to feed in to the get api endpoint, including MaxResults (relevant for get_results_single)

`Returns`:
- `athena_query::Dict`: Result dictionary in the Athena structure, results in res["ResultSet"]["Rows"], that includes a row for the header
"""
function get_results_all(config; athena_query, query_params)
    return get_query_result!([], config; 
        athena_query=athena_query, 
        query_params=query_params,
        next_token="")
end

"""
    get_query_result!(all_res, config; athena_query, query_params, next_token)

Recursively retrieve results from Athena, for large queries results only come back 1000 at a time at max
which can be used for a feature if Athena queries are returning exploratory info from archived data. If that
use case is required, use the get_results_single and provide info to the query caller on usage of NextToken

`Arguments`:
- `all_res`: results that are appended to
- `config`: AWS Config for connection to the account
- `athena_query::Dict`: Athena query dictionary containing QueryExecutionId
- `query_params::Dict`: Parameters to feed in to the get api endpoint, including MaxResults (relevant for get_results_single)
- `next_token::String`: Next token as pulled out of query results from Athena

`Returns`:
- `athena_query::Dict`: Result dictionary in the Athena structure, results in res["ResultSet"]["Rows"], that includes a row for the header
"""
function get_query_result!(all_res, config; athena_query, query_params, next_token)

    if !isempty(next_token)
        push!(query_params, "NextToken" => next_token)
    end

    res = Athena.get_query_results(
        athena_query["QueryExecutionId"],
        query_params;
        aws_config=config)

    # may need to configure this
    if isempty(all_res)
        all_res = res
    else
        push!(all_res["ResultSet"]["Rows"], res["ResultSet"]["Rows"]...)
    end

    if haskey(res, "NextToken")
        all_res=get_query_result!(all_res, config; 
            athena_query=athena_query, query_params=query_params, next_token=res["NextToken"])
    end
    return all_res
end


"""
    _make_athena_parameters(output_location, database, catalogue, workgroup)

Generates an execution parameter dictionary to be sent through to the Athena API

`Arguments`:
- `output_location::String`: Athena query output sent to which folder, required to be configured considering roles, etc
- `catalogue::String`: Athena catalogue where the database is, e.g. AwsDataCatalog
- `workgroup::String`: Athena workgroup with potential overwriting parameteres
- `database::String`: Database name to connect to, likely defined by glue catalogue

`Returns`:
- `execute_parameters::Dict`: Parameters for querying Athena: https://docs.aws.amazon.com/athena/latest/APIReference/API_StartQueryExecution.html
    Structure supported in AWSInterface:
    Dict(
        "ResultConfiguration"=>Dict{String, Any}(
            "OutputLocation"=>"s3://some_bucket_athena_can_access/"
        ),
        "QueryExecutionContext"=>Dict{String, Any}(
            "Database"=>"database_name",
            "Catalog"=>"catalogue_name_eg_from_glue"
        ),
        "WorkGroup"=>"primary"
      )

"""
function _make_athena_parameters(output_location, database, catalogue, workgroup)
    return Dict(
        "ResultConfiguration"=>Dict{String, Any}(
            "OutputLocation"=>output_location
        ),
        "QueryExecutionContext"=>Dict{String, Any}(
            "Database"=>database,
            "Catalog"=>catalogue
        ),
        "WorkGroup"=>workgroup
      )
end

end # module