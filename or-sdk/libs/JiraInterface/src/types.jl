const BASE_URL = Ref{String}()
const META = Ref{Dict{String,String}}()
const BASIC_AUTH = Ref{String}()
const DEAFULT_HEADERS = Ref{Vector{Pair{String, String}}}()


"""
    __init__()

Run on import for JiraInterface. Creates and sets the global variables
for the Interface. 
"""
function __init__()
    BASE_URL[] = get(ENV, "BASE_JIRA_URL", "https://hub.deloittedigital.com.au/")
    BASIC_AUTH[] = get(ENV, "JIRA_AUTH", "")
    DEAFULT_HEADERS[] = ["Accept"=> "application/json", 
                        "Content-Type" => "application/json",
                        "Authorization" => "Basic $(BASIC_AUTH[])"]
    META[] = Dict{AbstractString, AbstractString}()
end


"""
    set_meta_details(params::AbstractDict)

Set the META details for the call. 

# Arguments:
- `params`: Issue parameters from the ticket being queried. 
"""
function set_meta_details(params::AbstractDict)
    PROJECT_ID = params["fields"]["project"]["id"]
    PROJECT_NAME = params["fields"]["project"]["name"]
    PROJECT_KEY = params["fields"]["project"]["key"]
    ASSIGNEE = params["fields"]["assignee"]
    META[] = Dict(
        "PROJECT_ID" => PROJECT_ID,
        "PROJECT_NAME" => PROJECT_NAME,
        "PROJECT_KEY" => PROJECT_KEY,
        "ASSIGNEE_NAME" => ASSIGNEE["name"],
        "ASSIGNEE_EMAIL" => ASSIGNEE["emailAddress"],
    )
end


"""
    TestStatusEnum

The possible status for a Jira Test execution status. This is to be used based 
the result of tests. 
"""
baremodule TestStatusEnum
    const UNEXECUTED = "-1"
    const PASS = "1"
    const FAIL = "2"
    const WIP = "3"
    const BLOCKED = "4"
    const RETEST = "5"
end
