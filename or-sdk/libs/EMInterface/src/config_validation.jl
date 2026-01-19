"""
    is_chunked_sim(config::AbstractConfig)

Determines from the config whether or not this simulation is a chunked sim.

A chunked sim is one where the simulation is split into multiple sub-simulations
each with their own schedule, typically so that each sim can use less memory.
"""
function is_chunked_sim(config::AbstractConfig)
    if config.simDuration == config.scheduleGenerationPeriod
        return false
    end
    config.simDuration % config.scheduleGenerationPeriod != 0.0 && throw(ArgumentError("scheduleGenerationPeriod must be equal to or a divisor of sim_duration"))
    return true
end


"""
    check_sim_config(config::AbstractConfig)

Checks that `config` is valid.

# Checks:
- Check all required fields are present
- Check values of various durations and timesteps are compatible

# Source
`TrafficModel.src.em_config`
agent checking: `ScheduleGeneration.src.em_config`
"""
function check_sim_config(config::AbstractConfig)
    # TODO: more may need adding, these are just params required for local development
    # Check vars for all sims
    @assert !isnothing(config.experimentName)
    @assert !isnothing(config.experimentType)
    @assert !isnothing(config.simDuration)
    @assert !isnothing(config.simStartTime)
    @assert !isnothing(config.solMajorTimestep)
    @assert !isnothing(config.nSimulations)
    @assert config.nSimulations > 0
    @assert !isnothing(config.solDt)
    @assert !isnothing(config.rawOutput)
    @assert !isnothing(config.agentLevelOutput)
    @assert !isnothing(config.positionOutput)
    @assert !isnothing(config.agentConfigurations)
    @assert !isnothing(config.sessionName)
    @assert length(config.agentConfigurations) > 0 
    @assert !isnothing(config.agentConfigurations[1].scheduleGenerationParams) # TODO: remove when reference environments are being used
    @assert !isnothing(config.agentConfigurations[1].scheduleGenerationParams.mapName) # TODO: remove when reference environments are being used

    # Check combination of simDuration, scheduleGenerationPeriod and solMajorTimestep is valid
    if !isnothing(config.scheduleGenerationPeriod)
        config.simDuration % config.scheduleGenerationPeriod != 0.0 && throw(ArgumentError("scheduleGenerationPeriod must be a divisor of simDuration"))
        config.scheduleGenerationPeriod % config.solMajorTimestep != 0.0 && throw(ArgumentError("solMajorTimestep must be a divisor of schedule_generation_period"))
    else
        config.simDuration % config.solMajorTimestep != 0.0 && throw(ArgumentError("solMajorTimestep must be a divisor of simDuration"))
    end
    # for agent_config in config.agentConfigurations  # Is this valid in general? SOURCE: `ScheduleGeneration.src.em_config`
    #     check_agent_config(agent_config, config)
    # end
    check_one_agent_env(config) # TODO: remove when reference environments are being used
end


"""
    check_sim_config_blob_already_ready(config::AbstractConfig)

Checks that `config` is valid for the case when the blob has already
been constructed.

# Source
`TrafficModel.src.em_config`
"""
function check_sim_config_blob_already_ready(config::AbstractConfig)
    # TODO: more may need adding, these are just params required for local development
    # Check vars for all sims
    @assert !isnothing(config.experimentName)
    @assert !isnothing(config.simDuration)
    @assert !isnothing(config.simStartTime)
    @assert !isnothing(config.solMajorTimestep)
    @assert !isnothing(config.solDt)
    @assert !isnothing(config.rawOutput)
    @assert !isnothing(config.agentLevelOutput)
    @assert !isnothing(config.positionOutput)

    # Check combination of simDuration, scheduleGenerationPeriod and solMajorTimestep is valid
    if !isnothing(config.scheduleGenerationPeriod)
        config.simDuration % config.scheduleGenerationPeriod != 0.0 && throw(ArgumentError("scheduleGenerationPeriod must be a divisor of simDuration"))
        config.scheduleGenerationPeriod % config.solMajorTimestep != 0.0 && throw(ArgumentError("solMajorTimestep must be a divisor of schedule_generation_period"))
    else
        config.simDuration % config.solMajorTimestep != 0.0 && throw(ArgumentError("solMajorTimestep must be a divisor of simDuration"))
    end
end


"""
    check_one_agent_env(config::AbstractConfig)

Temporary checks whilst reference environment is not being used.
Checks that all agents configurations are using the same environment parameters.

# Source
`TrafficModel.src.em_config`
"""
function check_one_agent_env(config::AbstractConfig)
    map_names = [agent_conf.scheduleGenerationParams.mapName for agent_conf in config.agentConfigurations]
    !all(map_names .== map_names[1]) && error("All agent configurations must have the same map name.") # TODO: remove when reference environments are being used
end


"""
    is_live_sim(config::AbstractConfig)
    is_live_sim(config::AbstractAgentConfig)

Checks if config experiment type is equal to `LIVE`, used by Realtime Manager.
Or check if the config agent source is equal to `LIVE`.

# Source
`TrafficModel.src.em_config`
"""
is_live_sim(config::AbstractConfig) = config.experimentType == "LIVE"
is_live_sim(config::AbstractAgentConfig) = config.agentSource == "LIVE"


"""
    check_agent_config(agent_config::AbstractAgentConfig, config::AbstractConfig)

Check necessary fields of agent config are not nothing.

# Source
`ScheduleGeneration.src.em_config`
"""
function check_agent_config(
        agent_config::AbstractAgentConfig,
        config::AbstractConfig
    )
    @assert !isnothing(agent_config.experimentAgentConfigurationId)
    @assert !isnothing(agent_config.tripStrategy)
    @assert !isnothing(agent_config.agentType)
    if agent_config.tripStrategy == "VALIDATED_OPTIMISED"
        @assert !isnothing(agent_config.startTime) || !isnothing(config.simStartTime) # default to simStartTime if not present
        @assert !isnothing(agent_config.endTime) || (!isnothing(config.simStartTime) && !isnothing(config.simDuration)) # default to simStartTime plus duration if not present
        @assert !isnothing(agent_config.scheduleGenerationParams.areaOfInterest)
        @assert !isnothing(agent_config.scheduleGenerationParams.optimisationPeriod)
        @assert !isnothing(agent_config.scheduleGenerationParams.inProgressProportionThreshold)
    end
    is_live_sim(agent_config) && @assert !isnothing(agent_config.scheduleGenerationParams.segmentId)
    return
end


"""
    is_latest_realtime_run(local_config::AbstractConfig)

If the rt_execute_timestamp of the local_config app data is not equal to the remote version of rt_execute_timestamp
it means that the rtrun is not the latest, returning false. Otherwise it is the latest, returning true.
"""
function is_latest_realtime_run(local_config::AbstractConfig)
    @info "Checking rt run is latest for experiment: $(local_config.experimentName)"
    if isnothing(local_config.experimentType)
        return false
    end
    return _is_latest_realtime_run(get_config_session_start_time(local_config), local_config.sessionName)
end

function _is_latest_realtime_run(local_start_time::Integer, session_name::AbstractString) 
    session_start_time = get_current_session_timestamp(session_name)
    if local_start_time != session_start_time
        timing = local_start_time > session_start_time ? "later" : "earlier"
        @info "Local Realtime Manager start time $timing than session timestamp"
    end
    return local_start_time == session_start_time
end