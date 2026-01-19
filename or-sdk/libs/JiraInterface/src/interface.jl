
"""
    process_test_result(branch_name::AbstractString; test_result=TestStatusEnum.FAIL)

Processes the test results of a branch test and publishes the results
to a test ticket asociated with the branch. 

# Arguments
- `branch_name`: Name of the branch the pipeline is running on.
- `test_result`: A result for pass or fail which is a TestStatusEnum.
Possible values are:
    - UNEXECUTED
    - PASS
    - FAIL
    - WIP
    - BLOCKED
    - RETEST
"""
function process_test_result(branch_name::AbstractString, test_result=TestStatusEnum.FAIL)
    issue_key = process_branch_name(branch_name)
    execution_id = process_issue(issue_key)
    r = update_execution_status(execution_id, test_result)
    return 
end