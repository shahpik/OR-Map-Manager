"""
    get_issue_details(issue_name::AbstractString)

Uses the Agile API to retrive the issue details for a branch.

# Arguments
- `issue_name`: The name of the issue. Taken from the branch name
"""
function get_issue_details(issue_name::AbstractString)
    return try_get(BASE_URL[] * "jira/rest/agile/latest/issue/$(issue_name)")
end