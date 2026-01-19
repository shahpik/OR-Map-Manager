"""
    get_config_session_start_time(config::AbstractConfig)
    get_config_session_start_time(experiment_name::AbstractString)

From an experiment config or experiment name, return the rt_execute_timestamp from the application data.
Throw an error if it does not exist for the live experiment.
Use this to get the session start time (for realtime sims) as was recorded in the local copy of the config.
"""
function get_config_session_start_time(config::AbstractConfig)
    rtman_app_data = get_app_data(config, "REALTIME_MANAGER")
    if !isempty(rtman_app_data) && !isnothing(rtman_app_data.executionParameters)
        rtman_execution_params = JSON3.read(rtman_app_data.executionParameters, Dict)
    else
        throw(ExperimentManagerException("LIVE sim execution time is missing - please check that Realtime Manager service is running"))
    end

    return rtman_execution_params["rt_execute_timestamp"]
end


"""
    get_current_session_timestamp(session_name)

Get the session start time for session_name from the get session query timestamp.
"""
function get_current_session_timestamp(session_name)
    response = query("getSession", query_args=Dict("name" => session_name), output_fields=["timestamp", "status"])
    session_output = response.data["getSession"]
    if session_output[1]["status"] != "LIVE"
        throw(ExperimentManagerException("Session status is not live, please check the session for: $session_name"))
    end
    if isnothing(session_output[1]["timestamp"])
        throw(ExperimentManagerException("Session timestamp is not populated, please check the session for: $session_name"))
    end

    return session_output[1]["timestamp"]
end


"""
    _create_schedule_id(args...)

Create a schedule_id from the provided arguments. Schedule ids follow the format:

`"schedule_<arg1>_<arg2>..."`

This is an internal function. It is preferred you do not invoke directly.
"""
_create_schedule_id(args...) = "schedule_" * join(args, "_")


"""
    create_schedule_id(config::AbstractConfig; app_name="TRAFFIC_MODEL", use_rt_start_time=false)
    create_schedule_id(config::AbstractConfig, n_chunks_completed::Integer;  use_rt_start_time=false)

Creates a schedule_id from the configuration information. The schedule_id will always be 
based on the config that is provided:
`"schedule_\$(experiment_name)_\$(n_simulations)_\$(sec_into_day)"`
Where the sec_into_day is calculated depending on if use_rt_start_time is used and the chunks
    that traffic has already completed, to determine start time of next chunk.

# Arguments
- `config::AbstractConfig`: Experiment Config.
- `n_chunks_completed`: Chunk number to use for schedule id, which is converted to an integer if possible
- `app_name="TRAFFIC_MODEL"`: Name of the application to check for chunked completion, liveliness, etc.
- `use_rt_start_time::Bool=false`: If true, will attempt to create a schedule id from the the start time provided by the Realtime Manager (rt)
If False, will create the start time from the config's simStartTime

# Note
Caution: When using the use_rt_start_time option, config must be an up-to-date copy from
the EM before this function is used, or the rt start time may be out of date.
"""
function create_schedule_id(config::AbstractConfig; app_name="TRAFFIC_MODEL", use_rt_start_time=false)
    chunk_time = get_current_chunk_time(config; app_name=app_name, use_rt_start_time=use_rt_start_time)
    sec_into_day = sec_into_day_from_timestamp(chunk_time, config.solMajorTimestep)
    return _create_schedule_id(config.experimentName, config.nSimulations, sec_into_day)
end
function create_schedule_id(config::AbstractConfig, n_chunks_completed::Integer; app_name="TRAFFIC_MODEL", use_rt_start_time=false)
    current_chunk = 0
    if is_chunked_sim(config)
        current_chunk = get_n_chunks_completed(config, app_name)
    end
    if n_chunks_completed > current_chunk
        @error "The schedule_id will be for the current chunk ($current_chunk) and not chunk $n_chunks_completed"
        n_chunks_completed = current_chunk
    end
    chunk_time = get_current_chunk_time(config, n_chunks_completed; app_name=app_name, use_rt_start_time=use_rt_start_time)
    sec_into_day = sec_into_day_from_timestamp(chunk_time, config.solMajorTimestep)
    return _create_schedule_id(config.experimentName, config.nSimulations, sec_into_day)
end
create_schedule_id(config::AbstractConfig, n_chunks_completed::Number; app_name="TRAFFIC_MODEL", use_rt_start_time=false) = create_schedule_id(config, floor(Int64,n_chunks_completed); app_name=app_name, use_rt_start_time=use_rt_start_time)
create_schedule_id(config::AbstractConfig, n_chunks_completed::AbstractString; app_name="TRAFFIC_MODEL", use_rt_start_time=false) = create_schedule_id(config, parse(Int64,n_chunks_completed); app_name=app_name, use_rt_start_time=use_rt_start_time)


"""
    get_n_chunks_completed(config::AbstractConfig, app_name::AbstractString="TRAFFIC_MODEL")
    get_n_chunks_completed(experiment_name::AbstractString, app_name::AbstractString="TRAFFIC_MODEL")

Return the number of simulation chunks (sub-simulations) that have already been 
completed by a service. By default, it will check the number of chunks completed
by the Traffic Model.

Note, if when downloading the original config the applicationData field
and necessary subfields were not included in the `output_fields` keyword
argument of `get_configuration`, then they won't be available here. If that
is the case then use `get_app_data(config.experimentName, app_name)` to get
the corresponding fields from the Experiment Manager, or add those fields
to the call to `get_configuration`.
"""
function get_n_chunks_completed(config::AbstractConfig, app_name::AbstractString="TRAFFIC_MODEL")
    app_data = get_app_data(config, app_name)
    return get_chunk_number(app_data)
end
function get_n_chunks_completed(experiment_name::AbstractString, app_name::AbstractString="TRAFFIC_MODEL")
    app_data = get_app_data(experiment_name, app_name)
    return get_chunk_number(app_data)
end


"""
    get_n_schedules_generated(config)

Get the current number of schedules generated by Schedule Generation
by checking its result IDs.

# Source
`TrafficModel.src.schedule_subscriptions`

# TODO Replace this with the generic process above
"""
function get_n_schedules_generated(config)
    app_data = get_app_data(config.experimentName, "SCHEDULE_GENERATION") # Use experimentName to get latest resultIds
    isnothing(app_data.resultIds) && return 0
    return length(app_data.resultIds)
end


"""
    get_chunk_number(app_data)

Gets the total chunks from an app_data resultIds.
"""
get_chunk_number(app_data) = (isempty(app_data) || isnothing(app_data.resultIds) || isempty(app_data.resultIds)) ? 0 : length(app_data.resultIds)


"""
    get_times_and_ids(config::AbstractConfig)

Constructs the schedule_id and the associated unix_times of all the simulation
outputs, paths, etc. Returns 2 arrays: `schedule_ids`, `unix_time`

# Source
`SimulationValidation.src.App`
"""
function get_times_and_ids(config::AbstractConfig)
    @debug "Constructing times and schedule id from config information"
    # Total_items is number of outputs that need to be computed against
    total_items = Int64(config.simDuration / config.solMajorTimestep)
    total_chunks = Int64(config.simDuration / config.scheduleGenerationPeriod)
    ts_per_chunk = Int64(config.scheduleGenerationPeriod / config.solMajorTimestep)
    sim_start_time = get_config_data_start_time(config)

    unix_time = zeros(Int64, total_items)
    for i in 1:total_chunks, j in 1:ts_per_chunk
        @debug "line number $(j + (i - 1) * ts_per_chunk)"
        unix_time[j + (i - 1) * ts_per_chunk] = floor_to_nearest(
            sim_start_time + (i - 1) * config.scheduleGenerationPeriod + (j - 1) * config.solMajorTimestep,
            config.solMajorTimestep
        )
    end
    schedule_ids = [
        _create_schedule_id(
            config.experimentName,
            config.nSimulations,
            sec_into_day_from_timestamp(time, config.scheduleGenerationPeriod)
        ) for time in unix_time
    ]
    return schedule_ids, unix_time
end


"""
    get_config_data_start_time(config::AbstractConfig)

Retrieves the start time of the sim at the config level, depending on if it's a live sim or not.

# Source
`SimulationValidation.src.utilities`
"""
function get_config_data_start_time(config::AbstractConfig)
    if is_live_sim(config)
        rtman_app_data = get_app_data(config.experimentName, "REALTIME_MANAGER")  # get latest copy of RTman app data from EM
        if isempty(rtman_app_data) || isnothing(rtman_app_data.executionParameters)
            throw(error("LIVE sim execution time is missing - please check that Realtime Manager service is running"))
        end
        rtman_execution_params = JSON3.read(rtman_app_data.executionParameters, Dict)
        return rtman_execution_params["rt_execute_timestamp"]
    elseif config.experimentType in ["HISTORIC","EXPERIMENTAL"]
        return config.simStartTime
    end
    #Guard:
    throw(ExperimentManagerException("Unsupported agentConfig.agentSource: $(config.experimentType) for get_schedule_data_start_time"))
end


"""
    get_bucket_size(config, agent_config)

Returns `agent_config.scheduleGenerationParams.optimisationPeriod` if
it's not nothing, otherwise returns `config.scheduleGenerationPeriod`.

# Source
`ScheduleGeneration.src.data_import`
"""
function get_bucket_size(config, agent_config)
    if !isnothing(agent_config.scheduleGenerationParams.optimisationPeriod)
        bucket_size = agent_config.scheduleGenerationParams.optimisationPeriod
    else
        bucket_size = config.scheduleGenerationPeriod
    end
    return bucket_size
end


"""
    get_schedule_data_start_time(config, agent_config)
Gets the start time for generating schedules, based on the source type

# Source
`ScheduleGeneration.src.data_import`
""" 
function get_schedule_data_start_time(config, agent_config)
    if is_live_sim(agent_config)
        rtman_app_data = get_app_data(config, "REALTIME_MANAGER")
        if !isempty(rtman_app_data) && !isnothing(rtman_app_data.executionParameters)
            rtman_execution_params = JSON3.read(rtman_app_data.executionParameters, Dict)
        else
            throw(ScheduleGenException("LIVE sim execution time is missing - please check that Realtime Manager service is running"))
        end
        return rtman_execution_params["rt_execute_timestamp"]
    elseif agent_config.agentSource in ["HISTORICAL","EXPERIMENTAL"]
        return agent_config.startTime
    end
    throw(ScheduleGenException("Unsupported agentConfig.agentSource: $(agent_config.agentSource) for get_schedule_data_start_time"))
end


"""
    get_live_sim_start_time(config)

Gets the start time (unix) of an Realtime Manager configured sim.

# Source
`TrafficModel.src.em_config`
"""
function get_live_sim_start_time(config)
    rt_app_data = get_app_data(config, "REALTIME_MANAGER")
    step_size = config.solMajorTimestep
    if !isempty(rt_app_data) && !isnothing(rt_app_data.executionParameters)
        rt_start_timestamp = floor_to_nearest(
            JSON3.read(rt_app_data.executionParameters)[:rt_execute_timestamp],
            step_size)
        @info "Config $(config.experimentName) Realtime sim start time set to $rt_start_timestamp"
        return rt_start_timestamp
    end
    throw(ErrorException("Live Sim $(config.experimentName) requested, but rt sim time not set, check Realtime manager is running"))
end


"""
    get_sim_start_and_end_from_config(config::AbstractConfig)::Tuple{Float64, Float64}

Get start and end time of simulation from config. If experimentType is `LIVE`, then tstart is pulled
from RealtimeManager's ApplicationData. 

# Assumptions 
- `get_live_sim_start_time` assumes `config` is up to date, doesn't grab another update of it from Experiment Manager.

# Source
`TrafficModel.src.em_config`
"""
function get_sim_start_and_end_from_config(config::AbstractConfig)::Tuple{Float64, Float64}
    tstart = is_live_sim(config) ? get_live_sim_start_time(config) : config.simStartTime 
    tend = tstart + config.simDuration
    return tstart, tend
end


"""
    get_current_chunk_number(config::AbstractConfig, app_name::AbstractString="TRAFFIC_MODEL")

Get the chunk currently being simulated by adding 1 to the length of app_name
result IDs.

# Assumptions

This assumes that `config` is up to date, that is it doesn't re-pull the config
from the Experiment Manager.

# Source
`TrafficMdoel.src.em_config`
"""
function get_current_chunk_number(config::AbstractConfig, app_name::AbstractString="TRAFFIC_MODEL")
    app_data = get_app_data(config, app_name) # Use already downloaded config
    current_chunk_number = 1
    if !isnothing(app_data.resultIds)
        max_result = maximum(parse.(Int64, app_data.resultIds))
        if max_result > length(app_data.resultIds)
            @warn "The length of the $app_name result ids is $(length(app_data.resultIds)) but the most recent id is $max_result"
        end
        current_chunk_number = length(app_data.resultIds) + 1
    end
    return current_chunk_number
end


"""
    is_next_chunk_available(local_config::AbstractConfig, app_name::AbstractString)
    is_next_chunk_available(local_config::U, remote_config::U, app_name::AbstractString) where U<:AbstractConfig

Compares the app data of two configs of the same type, for a specified app name. If only the local is provided,
then the remote is also collected.

1. If the remote app is empty, it can't be available.
1. If the length of the remote is zero and there is no data in the local then it can't be available.
1. If the remote is longer and there is no data in the local then it is available.
1. Otherwise, it is based on the length of the `resultIds` field: Available if the remote is longer.
"""
function is_next_chunk_available(local_config::U, remote_config::U, app_name::AbstractString) where U<:AbstractConfig
    local_app = get_app_data(local_config, app_name)
    remote_app = get_app_data(remote_config, app_name)
    if isnothing(remote_app)
        return false
    end
    len_remote = isnothing(remote_app.resultIds) ? 0 : length(remote_app.resultIds)
    if isnothing(local_app) && len_remote == 0
        return false
    end
    if isnothing(local_app) && len_remote > 0
        return true
    end
    len_local = isnothing(local_app.resultIds) ? 0 : length(local_app.resultIds)
    return len_remote > len_local
end
function is_next_chunk_available(local_config::AbstractConfig, app_name::AbstractString)
    remote_config = get_configuration(local_config.experimentName)
    return is_next_chunk_available(local_config, remote_config, app_name)
end


"""
    is_next_chunk_available!(local_config::AbstractConfig, app_name::AbstractString)
    is_next_chunk_available!(local_config::U, remote_config::U, app_name::AbstractString) where U<:AbstractConfig

Compares the app data of two configs of the same type, for a specified app name using the
`is_next_chunk_available` function. If a new chunk is available, then the local config is
updated with the `applicationData` field of the remote. Ifonly the local config is provided
then the remote is also collected.
"""
function is_next_chunk_available!(local_config::U, remote_config::U, app_name::AbstractString) where U<:AbstractConfig
    chunk_available = is_next_chunk_available(local_config, remote_config, app_name)
    if chunk_available
        if isnothing(local_config.applicationData)
            local_config.applicationData = remote_config.applicationData
        else
            for i in 1:length(local_config.applicationData), j in 1:length(remote_config.applicationData)
                if local_config.applicationData[i].name == app_name && local_config.applicationData[i].name == remote_config.applicationData[j].name
                    local_config.applicationData[i] = remote_config.applicationData[j]
                    break
                end
            end
        end
    end
    return chunk_available
end
function is_next_chunk_available!(local_config::AbstractConfig, app_name::AbstractString)
    remote_config = get_configuration(local_config.experimentName)
    return is_next_chunk_available!(local_config, remote_config, app_name)
end


"""
    get_current_chunk_time(config::AbstractConfig; app_name="TRAFFIC_MODEL", use_rt_start_time=false)
    get_current_chunk_time(config::AbstractConfig, n_chunks_completed::Integer; use_rt_start_time=false, kwargs...)

Get the current chunk time for a config, based on the completed app results, or the provided chunk completion.
"""
function get_current_chunk_time(config::AbstractConfig; app_name="TRAFFIC_MODEL", use_rt_start_time=false)
    n_chunks_completed = 0
    if is_chunked_sim(config)
        n_chunks_completed = get_n_chunks_completed(config, app_name)
    end
    return get_current_chunk_time(config, n_chunks_completed; app_name=app_name, use_rt_start_time=use_rt_start_time)
end
function get_current_chunk_time(config::AbstractConfig, n_chunks_completed::Integer; use_rt_start_time=false, kwargs...)
    start_time = config.simStartTime
    if use_rt_start_time
        if !is_live_sim(config)
            @warn("RT schedule id is requested but experimentType is NOT LIVE, please check intended behaviour of service") 
        end
        start_time = get_config_session_start_time(config)
    end
    start_time_offset = n_chunks_completed * config.scheduleGenerationPeriod
    return start_time + start_time_offset
end