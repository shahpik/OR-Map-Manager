"""
    get_linked_issue(issue_elements::AbstractDict)

Function that takes the "fields" from response body of get_issies_details and returns 
the list of test issues linked to it.

# Arguments
- `issue_elements`: Dictionary of elements returned by the Agile API for an issue
"""
function get_linked_issue(issue_elements::AbstractDict)
    linked =  issue_elements["issuelinks"]
    issue_dict = Dict()
    for issue in linked
        if issue["outwardIssue"]["fields"]["issuetype"]["name"] == "Test" 
            push!(issue_dict, issue["outwardIssue"]["id"] => issue["outwardIssue"]["fields"])
        end
    end
    return issue_dict
end


"""
    link_new_test_issue(parent_issue::AbstractDict; params::AbstractDict=Dict())

Create a new Test issue to link to a parent issue

# Arguments
- `parent_issue`: Dictionary of elements for a parent Issue
- `params=Dict()`: Kwarg that can specify a non-deafult set of params to build a 
ticket from. 
"""
function link_new_test_issue(parent_issue::AbstractDict; params::AbstractDict=Dict())
    parent_id = parent_issue["id"]
    parent_summary = parent_issue["fields"]["summary"]
    labels = append!(parent_issue["fields"]["labels"], ["UnitTest"])

    if isempty(params)
        params = Dict(
                "fields" => Dict(
                    "project" => Dict(
                        "key" => META[]["PROJECT_KEY"]
                    ),
                    "summary" => "Pipeline Testing - $(parent_summary)",
                    "description" => """Ticket has been generated automatically 
                        by JiraInterface for automated testing""",
                    "issuetype" => Dict(
                        "name" => "Test"
                    ),
                    "labels" => labels,
                    "assignee" => Dict(
                        "name" => META[]["ASSIGNEE_NAME"],
                        "emailAddress" => META[]["ASSIGNEE_EMAIL"]
                    )
                )
            )
    end

    child_issue_params = create_issue(params)
    link_issues(parent_id, child_issue_params["id"])
    create_new_execution(child_issue_params)
    parent_params = get_issue_details(parent_issue["key"])
    return get_linked_issue(parent_params["fields"])
end


"""
    create_new_execution(issue_params::AbstractDict; params::AbstractDict=Dict())

If a test issue doesn't have an execution, create one and label it as UNEXECUTED

# Arguments
- `issue_params`: All params from the test ticket where the execution will be made.
- `params=Dict()`: params to be passed into the new execution
"""
function create_new_execution(issue_params::AbstractDict; params::AbstractDict=Dict())
    if isempty(params)
        params = Dict(
            "cycleId" => "3411",
            "issueId" => issue_params["id"],
            "projectId" => META[]["PROJECT_ID"],
            "versionId" => "-1",
            "assigneeType" => "currentUser",
            "assignee" => META[]["ASSIGNEE_EMAIL"],
        )
    end
    return create_execution(params)
end
create_new_execution(issue_id::AbstractString) = create_new_execution(Dict("id"=>issue_id))


"""
    update_execution_status(execution_id::AbstractString, status)

Set the execution status (test result) of an execution based on a result. 
This result should be apart of the enum set TestStatusEnum

# Arguments
- `execution_id`: id of an execution thats associated with a Test issue. 
- `status`: Test result status eg. TestStatusEnum.PASS
"""
function update_execution_status(execution_id::AbstractString, status=TestStatusEnum.FAIL)
    params = Dict(
        "status" => status
    )
    return update_execution(execution_id, params)
end


"""
    process_branch_name(branch_name::AbstractString)

process the branch name from a pipeline build to extract project and 
branch key 

# Arguments
- `branch_name`: git branch name for a pipeline build
"""
function process_branch_name(branch_name::AbstractString)
    branch_names = split(branch_name, "-")
    project = uppercase(branch_names[1])
    issue_key = join([project,branch_names[2]], "-")
    return issue_key
end


"""
    process_linked_issues(params::AbstracDict)

Retrieves the linked issues from a Jira Issues parameters.

# Arguments
- `params`: fields associated with a jira ticket. 
"""
function process_linked_issues(params::AbstractDict)
    linked_issues = get_linked_issue(params["fields"])
    if isempty(linked_issues) 
        @info "Creating and linking a Test issue"
        linked_issues = link_new_test_issue(params)
    end
    return collect(linked_issues)
end


"""
    process_issue(issue_key::AbstractString)

Use the issue key (eg "CORE-1999") to query information about the ticket and 
and eventually grab the execution id needing to be updated based on a test 
result.

# Arguments
- `issue_key`: key for a Jira Issue eg "CORE-1999"
"""
function process_issue(issue_key::AbstractString)
    params = get_issue_details(issue_key)
    set_meta_details(params)
    linked_issues = process_linked_issues(params)
    execution_id = process_execution(linked_issues)
    return string(execution_id)
end


"""
    process_execution(linked_issues)

Processes the creation/retrival of a test issues execution ids. 

# Arguments
- `linked_issues`: Linked Test issues of a Jira feature ticket.
"""
function process_execution(linked_issues)
    test_issue_id = linked_issues[1][1]
    executions = get_executions(test_issue_id)
    if isempty(executions["executions"])
        @info "Creating Execution"
        r = create_new_execution(test_issue_id)
        execution_id = collect(r)[1][1]
    else 
        execution_id = executions["executions"][1]["id"]
    end
    return execution_id
end


"""
    try_get(url::AbstractString; params=[], headers=DEAFULT_HEADERS[])

Calls the _try_request() funciton using the "GET" method.

# Arguments
- `url`: endpoint to hit for the get requests
- `params=[]`: params payload that should be included. Default set to [].
- `headers`: headers to be included in the request. If nothing is specified, 
    DEAFULT_HEADERS[] are used. 
"""
try_get(url::AbstractString; params=[], headers=DEAFULT_HEADERS[]) = _try_request(url, "GET", params, headers)


"""
    try_put(url::AbstractString; params=[], headers=DEAFULT_HEADERS[])

Calls the _try_request() funciton using the "PUT" method.

# Arguments
- `url`: endpoint to hit for the get requests
- `params=[]`: params payload that should be included. Default set to [].
- `headers`: headers to be included in the request. If nothing is specified, 
    DEAFULT_HEADERS[] are used. 
"""
try_put(url::AbstractString; params=[], headers=DEAFULT_HEADERS[]) = _try_request(url, "PUT", params, headers)


"""
    try_post(url::AbstractString; params=[], headers=DEAFULT_HEADERS[])

Calls the _try_request() funciton using the "PSOT" method.

# Arguments
- `url`: endpoint to hit for the post requests
- `params`: params payload that should be included. Default set to []
- `headers`: headers to be included in the request. If nothing is specified, 
    DEAFULT_HEADERS[] are used. 
"""
try_post(url::AbstractString; params=[], headers=DEAFULT_HEADERS[]) = _try_request(url, "POST", params, headers)
    

"""
    _try_request(url::, method::AbstractString; params=[], headers=DEAFULT_HEADERS[])

HTTP post request wrapped in a try catch statement. This will display error and 
return an empy array if the statment errors. It will return a 
Dictionary of the response body. 

# Arguments
- `url`: endpoint to hit for the post requests
- `params`: params payload that should be included. 
- `headers`: headers to be included in the request.  
"""
function _try_request(url::AbstractString, method::AbstractString, params, headers)
    @info "Hitting $url as a $method"
    try
        r = HTTP.request(method, url, headers, params)
        return JSON3.read(r.body, Dict)
    catch e
        @info "Error encountered: $e"
        return []
    end
end