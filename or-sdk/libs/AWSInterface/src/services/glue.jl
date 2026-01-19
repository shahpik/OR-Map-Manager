module GlueInterface

using AWS
@service Glue

include("../exceptions/glue.jl")
include("../utilities.jl")

"""
    _make_glue_parameters(; 
        command_name,
        job_name,
        description="Job description",
        script_location="",
        role="arn:aws:iam::438954004210:role/or_dev_glue_role",
        glue_args=Dict{String, String}(),
        allocated_capacity=10,
        python_version="3",
        connections=nothing,
        max_concurrent_runs=1,
        glue_version= "3.0",
        log_uri=nothing,
        max_capacity= 10.0,
        max_retries=0,
        number_of_workers=10,
        security_configuration=nothing,
        tags=Dict{String, String}(),
        timeout=2880,
        worker_type="G.1X",
        glue_bucket="",
        glue_bucket_path_prefix=""
    )
Creates the specific dict structure for the Glue SDK

# Arguments:
- command_name: "glueetl" usually, this will define the type of job
- job_name: job name as used when calling
- description: job details
- script_location: location in S3 where the script to run is stored
- role: glue role for AWS access requirements
- glue_args: Dict of specific extra args, e.g. {"--job-language": "python"}
- allocated_capacity: (not for python jobs) allocated DPU to 
- python_version: Version of python for the job
- connections: list of connections to use (e.g. VPC endpoint)
- max_concurrent_runs: number of concurrent glue jobs that can run at the one time
- glue_version: glue api version
- log_uri: 
- max_capacity: number of AWS Glue data processing units (DPUs) that can be allocated when this job runs
- max_retries: number of times to retry on a fail (e.g. timeouts), not useful for data format issues
- number_of_workers: number of workers to start
- security_configuration: 
- tags: tags for the glue job
- timeout: 2880 in seconds for the job if stalled
- worker_type: "G.1X", node type to use
- glue_bucket: glue specific bucket
- glue_bucket_path_prefix: environment / path key specifications

# Returns:
- glue parameters: Dict{String, Any}: formatted arguments
"""
function _make_glue_parameters(; 
        command_name,
        job_name,
        description="Job description",
        script_location="",
        role="arn:aws:iam::438954004210:role/or_dev_glue_role",
        glue_args=Dict{String, String}(),
        allocated_capacity=10,
        python_version="3",
        connections=nothing,
        max_concurrent_runs=1,
        glue_version= "3.0",
        log_uri=nothing,
        max_capacity= 10.0,
        max_retries=0,
        number_of_workers=10,
        security_configuration=nothing,
        tags=Dict{String, String}(),
        timeout=2880,
        worker_type="G.1X",
        glue_bucket="",
        glue_bucket_path_prefix=""
    )

    if isempty(glue_args)
        glue_args = Dict{}(
            "--TempDir" => "s3://$(glue_bucket)/$(glue_bucket_path_prefix)/temporary/",
            "--class" => "GlueApp",
            "--enable-continuous-cloudwatch-log" => "true",
            "--enable-glue-datacatalog" => "true",
            "--enable-job-insights" => "true",
            "--enable-metrics" => "true",
            "--enable-spark-ui" => "true",
            "--job-bookmark-option" => "job-bookmark-enable",
            "--job-language" => "python",
            "--spark-event-logs-path" => "s3://$(glue_bucket)/$(glue_bucket_path_prefix)/sparkHistoryLogs/",
            "--write-shuffle-files-to-s3" => "true", # for large jobs
            "--write-shuffle-spills-to-s3" => "true" # for large jobs
        )
    end

    settings = Dict{String, Any}(
        "AllocatedCapacity" => allocated_capacity,
        "Command" => Dict{}(
            "Name" => command_name,
            "PythonVersion" => python_version,
            "ScriptLocation" => script_location
        ),
        "DefaultArguments" => glue_args,
        "Description" => description,
        "ExecutionProperty" => Dict{}(
            "MaxConcurrentRuns" => max_concurrent_runs
        ),
        "GlueVersion" => glue_version,
        "MaxCapacity" => max_capacity,
        "MaxRetries" => max_retries,
        "Name" => job_name,
        "NumberOfWorkers" => number_of_workers,
        "Role" => role,
        "Timeout" => timeout,
        "WorkerType" => worker_type,
        "Tags" => tags
    )
    if !isnothing(security_configuration)
        settings["SecurityConfigurations"]=security_configuration
    end
    if !isnothing(log_uri)
        settings["LogURI"]=log_uri
    end
    if !isnothing(connections)
        settings["Connections"]=connections
    end

    # clear out one or the other
    if haskey(settings, "AllocatedCapacity") && haskey(settings, "MaxCapacity")
        delete!(settings, "AllocatedCapacity")
    end

    # clear out one or the other
    if haskey(settings, "WorkerType") && haskey(settings, "NumberOfWorkers") && haskey(settings, "MaxCapacity")
        delete!(settings, "MaxCapacity")
    end

    return settings
end

"""
    create_glue_job(...)

Creates a new job for glue
# Arguments:
- config: AWS Config to use for the SDK
- command_name: "glueetl" usually, this will define the type of job
- job_name: job name as used when calling
- description: job details
- script_location: location in S3 where the script to run is stored
- role: glue role for AWS access requirements
- glue_args: Dict of specific extra args, e.g. {"--job-language": "python"}
- allocated_capacity: (not for python jobs) allocated DPU to 
- python_version: Version of python for the job
- connections: list of connections to use (e.g. VPC endpoint)
- max_concurrent_runs: number of concurrent glue jobs that can run at the one time
- glue_version: glue api version
- log_uri: 
- max_capacity: number of AWS Glue data processing units (DPUs) that can be allocated when this job runs
- max_retries: number of times to retry on a fail (e.g. timeouts), not useful for data format issues
- number_of_workers: number of workers to start
- security_configuration: 
- tags: tags for the glue job
- timeout: 2880 in seconds for the job if stalled
- worker_type: "G.1X", node type to use
- glue_bucket: glue specific bucket
- glue_bucket_path_prefix: environment / path key specifications

# Returns:
- Mapping of the new job name as dictionary {"Name": "job_name"}
"""
function create_glue_job(config=global_aws_config(); 
        command_name="glueetl",
        allocated_capacity=10,
        python_version="3",
        script_location="",
        connections=nothing,
        glue_args=Dict{String, String}(),
        description="Job description",
        max_concurrent_runs=1,
        glue_version="3.0",
        log_uri=nothing,
        max_capacity=10.0,
        max_retries=0,
        job_name="dev_route_etl",
        number_of_workers=10,
        role="arn:aws:iam::438954004210:role/or_dev_glue_role",
        security_configuration=nothing,
        tags = Dict{String, String}(),
        timeout = 2880,
        worker_type = "G.1X",
        glue_bucket="",
        glue_bucket_path_prefix="")

    parameters = _make_glue_parameters(;command_name,
        allocated_capacity,
        python_version,
        script_location,
        connections,
        glue_args,
        description,
        max_concurrent_runs,
        glue_version,
        log_uri,
        max_capacity,
        max_retries,
        job_name,
        number_of_workers,
        role,
        security_configuration,
        tags,
        timeout,
        worker_type,
        glue_bucket,
        glue_bucket_path_prefix)
        
    return Glue.create_job(
            parameters["Command"],
            parameters["Name"],
            parameters["Role"],
            parameters;
            aws_config=config)
end

"""
    start_run(config=global_aws_config(); job_name)
Starts a glue job already defined by the job_name

# Returns:
- Job Run ID for querying status
"""
start_run(config=global_aws_config(); job_name) = Glue.start_job_run(job_name; aws_config=config)


end