module StepFunctionInterface

using AWS
using AWS.AWSServices: sfn
using AWSInterface
using AWS: @service
@service Sfn

include("../exceptions/step_function.jl")
include("../utilities.jl")

"""
    list_state_machines(; aws_config::AbstractAWSConfig=global_aws_config())

`Returns`:
- `OrderedCollections.LittleDict`: all the state machines within the AWS account, has 'creationDate', 'name' and 'arn' information about each state machine. 
"""
function list_state_machines(; aws_config::AbstractAWSConfig=global_aws_config())
    return Sfn.list_state_machines(; aws_config)
end

"""
    execute_state_machine(arn::String; aws_config::AbstractAWSConfig=global_aws_config())

`Arguments`:
    - `arn`: ARN of state machine to be executed
    - `params`: Parameters can be passed as a `params::Dict{String,<:Any}`. Valid keys are:
        - `"input"`: The string that contains the JSON input data for the execution, for example:
        \"input\": \"{\"first_name\" : \"test\"}\"   If you don't include any JSON input data, you
        still must include the two braces, for example: \"input\": \"{}\"   Length constraints
        apply to the payload size, and are expressed as bytes in UTF-8 encoding.
        - `"name"`: Optional name of the execution. This name must be unique for your Amazon Web
        Services account, Region, and state machine for 90 days. For more information, see  Limits
        Related to State Machine Executions in the Step Functions Developer Guide. If you don't
        provide a name for the execution, Step Functions automatically generates a universally
        unique identifier (UUID) as the execution name. A name must not contain:   white space
        brackets &lt; &gt; { } [ ]    wildcard characters ? *    special characters \" # %  ^ | ~ `
        &amp; , ; : /    control characters (U+0000-001F, U+007F-009F)   To enable logging with
        CloudWatch Logs, the name should only contain 0-9, A-Z, a-z, - and _.
        - `"traceHeader"`: Passes the X-Ray trace header. The trace header can also be passed in
        the request payload.
    - `aws_config`: AWS Config for connection to the account. (Optional)
    
"""
function execute_state_machine(
    arn::String,
    params::AbstractDict{String}=Dict();
    aws_config::AbstractAWSConfig=global_aws_config())
    return Sfn.start_execution(arn, params; aws_config)
end

"""
    list_executions(state_machine_arn::String; aws_config::AbstractAWSConfig=global_aws_config())

`Arguments`:
    - `state_machine_arn`: ARN of state machine to be examined
    - `aws_config`: AWS Config for connection to the account

`Returns`:
- `Vector{OrderedCollections.LittleDict}`: Step-by-step execution of the specified state machine
"""
function list_executions(state_machine_arn::String; aws_config::AbstractAWSConfig=global_aws_config())
    return Sfn.list_executions(state_machine_arn; aws_config)["executions"]
end

"""
    get_execution_history(execution_arn::String; aws_config::AbstractAWSConfig=global_aws_config())

`Arguments`:
    - `execution_arn`: ARN of excution to be examined
    - `aws_config`: AWS Config for connection to the account

`Returns`:
- `Vector{OrderedCollections.LittleDict}`: Step-by-step events of the specified execution
"""
function get_execution_history(execution_arn::String; aws_config::AbstractAWSConfig=global_aws_config())
    return Sfn.get_execution_history(execution_arn; aws_config)["events"]
end

end # module