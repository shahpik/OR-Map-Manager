module AWS

using AWSInterface

const AWS_ACCESS_KEY_ID = Ref{String}()
const AWS_SECRET_ACCESS_KEY = Ref{String}()
const AWS_REGION = Ref{String}()

function initialise_aws(access_key::String, secret_access_key::String, aws_region::String)
    AWS_ACCESS_KEY_ID[] = get(ENV, "AWS_ACCESS_KEY_ID", access_key)
    AWS_SECRET_ACCESS_KEY[] = get(ENV, "AWS_SECRET_ACCESS_KEY", secret_access_key)
    AWS_REGION[] = get(ENV, "AWS_REGION", aws_region)
    set_global_config(AWS_ACCESS_KEY_ID[], AWS_SECRET_ACCESS_KEY[], AWS_REGION[])
    return AWSInterface.global_aws_config()
end

function execute_state_machine(arn::String; aws_config=global_aws_config())
    StepFunctionInterface.execute_state_machine(arn; aws_config)
end

function list_state_machines(; aws_config=global_aws_config())
    StepFunctionInterface.list_state_machines(;aws_config)["stateMachines"][1]
end

function list_executions(state_machine_arn::String; aws_config=global_aws_config())
    StepFunctionInterface.list_executions(state_machine_arn; aws_config)
end

function get_execution_history(execution_arn::String; aws_config=global_aws_config())
    StepFunctionInterface.get_execution_history(execution_arn; aws_config)
end

end # module
