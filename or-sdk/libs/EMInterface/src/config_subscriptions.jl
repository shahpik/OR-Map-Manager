"""
    is_simulation_finished(config::AbstractConfig)

Checks that the simulation is finished, using the number of resultIds and the
expected number (based on Duration / Generation Time). True when the length matches
the expected number of items.

# Source
`SimulationValidation.src.graphql_interfaces`
"""
function is_simulation_finished(config::AbstractConfig)::Bool
    # Should move this logic to EMInterface
    @debug "Checking if simulation is finished"
    traffic = get_app_data(config, "TRAFFIC_MODEL")
    if traffic.resultIds === nothing
        @debug "There are no result ids for the $(config.experimentName) config"
        return false
    end
    # Make sure this operates on fields from the subscription, as that is returned from the subscription
    @debug """
    Simulation Details:
    config.simDuration: $(config.simDuration)
    config.scheduleGenerationPeriod: $(config.scheduleGenerationPeriod)
    traffic.resultIds: $(traffic.resultIds)
    """
    expected = Int64(config.simDuration / config.scheduleGenerationPeriod)
    actual = length(traffic.resultIds)
    return (actual == expected)
end


"""
    subscribe_to_simulation(config_fn, config::AbstractConfig)

Subscribes to the Traffic Model simulation config to check when it's done based on the passed
config_fn.

# Arguments
- `config_fn`: Function on a config that returns a bool. Designed for use with
`is_simulation_finished(config::AbstractConfig)::Bool`
- `config::AbstractConfig`: An experiment configuration that is using the `TRAFFIC_MODEL`
for simulations

# Source
`SimulationValidation.src.graphql_interfaces`
"""
function subscribe_to_simulation(config_fn, config::AbstractConfig)
    @debug "Subscribing to $(config.experimentName) config."
    subscribe_to_config(
        config.experimentName,
        "TRAFFIC_MODEL",
        application_output_fields=["name", "resultIds", "executionParameters"],  # NAME IS REQUIRED BUT NOT ENFORCED!
        config_output_fields=[
            "experimentName",
            "experimentType",
            "simStartTime",
            "simDuration",
            "scheduleGenerationPeriod",
            "solMajorTimestep",
            "solDt",
            "nSimulations",
            Dict("agentConfigurations" => "experimentAgentConfigurationId")
        ]
    ) do config_object
        config_fn(config_object)
    end
end