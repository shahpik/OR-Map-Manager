module EMInterface

using GraphQLClient
import GraphQLClient: query, mutate, open_subscription
import GraphQLClient: create_introspected_struct, initialise_introspected_struct, get_introspected_type, introspect_object, getjuliatype
using JSON3
using Requires

export get_configuration, save_configuration, execute_configuration, subscribe_to_config,
    @async_display_errors, query, mutate, open_subscription

# Applications
export get_app_data, update_app_data

function __init__()
    @require YAML="ddb6d928-2868-570f-bddf-ab3f9cf99eb6" include("yaml.jl")
end

include("object_introspection.jl")
include("config_struct.jl")
include("config_utilities.jl")
include("config_subscriptions.jl")
include("config_validation.jl")
include("exceptions.jl")
include("connect.jl")
include("utilities.jl")
include("configurations.jl")
include("applications.jl")
include("generic_gql.jl")
include("specialised_gql.jl")

end # module