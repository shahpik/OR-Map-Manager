# Note, functions defined here are only available to the user when they have YAML loaded already.
# This makes use of Requires.jl

using .YAML

"""
    load_config_yaml(file)

Load contents of `file` into a `Config` object.
"""
function load_config_yaml(file)
    yaml_dict = YAML.load_file(file)
    !haskey(yaml_dict, "experimentName") && throw(ArgumentError("config yaml must have an experiment name"))
    config = connected_to_client() ? build_config_struct(yaml_dict) : build_config_struct_offline(yaml_dict)
    return config
end