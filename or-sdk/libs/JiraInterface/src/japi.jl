"""
    create_issue(params::AbstractDict)

Create a new Test issue to link to a parent issue

# Arguments
- `params`: Dictionary of elements for the issue that is being created
"""
function create_issue(params::AbstractDict)
    return try_post(BASE_URL[]* "jira/rest/api/latest/issue/"; params=JSON3.write(params))
end

"""
    link_issues(parent_id::AbstractString, child_id::AbstractString)

Links to issues together. Used for linking a child test issue to a parent
feature issue. 

# Arguments
- `parent_id`: digits for 
- `child_id`: 
"""
function link_issues(parent_id::AbstractString, child_id::AbstractString)
    return try_post(BASE_URL[] * "jira/rest/zapi/latest/test/addIssueLink?parentIssueId=$(parent_id)&testcaseId=$(child_id)")
end