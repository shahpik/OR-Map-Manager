module Dependency
using TOML

const PROJECTDATA = TOML.parsefile("Project.toml")

""" 
Returns service dependency list definition from the project.toml, assuming it has been loaded 
"""
function get_project_service_dependencies() 
    if haskey(PROJECTDATA, "servicedeps")
        validate_service_deps(PROJECTDATA)
        return PROJECTDATA["servicedeps"]
    else
        @warn "Service dependencies not specified in Project.toml!"
        return Dict()
    end
end

get_project_version() = PROJECTDATA["version"]
get_project_name() = PROJECTDATA["name"]

""" Validates the dependency list, by checking that the needed keys all exist """
function validate_service_deps(project_data)
    if haskey(project_data["servicedeps"], "keydeps") && haskey(project_data["servicedeps"], "optional")
        return true
    end
    @error "Service dependencies error, please check Project.toml and ensure [servicedeps.keydeps] and [servicedeps.optional] are correctly set"
    return false
    end
    
end
