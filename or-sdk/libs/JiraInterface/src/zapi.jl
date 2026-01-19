"""
    get_executions(issue_id::AbstractString)

Get a list of test executions associated with a Test Issue

# Arguments
- `issue_id`: String of the form "543221" used to identify an issue
"""
function get_executions(issue_id::AbstractString)
    return try_get(BASE_URL[] * "jira/rest/zapi/latest/execution?issueId=$(issue_id)")
end


"""
    create_execution(params::AbstractDict)

If a test issue doesn't have an execution, create one and label it as UNEXECUTED

# Arguments
- `params`: Dict of details for new exectution
"""
function create_execution(params::AbstractDict)
    return try_post(BASE_URL[] * "jira/rest/zapi/latest/execution"; params=JSON3.write(params))
end


"""
    update_execution(execution_id::AbstractString, params::AbstractDict)

Update an existing exectution to values in params for execution 
with id: execution_id

# Arguments:
- `execution_id`: id (digits) that relates to a specific execution (eg "11234")
- `params`: Dict of details for updating the execution. 
"""
function update_execution(execution_id::AbstractString, params::AbstractDict)
    return try_put(BASE_URL[]* "jira/rest/zapi/latest/execution/$execution_id/execute"; params=JSON3.write(params))
end