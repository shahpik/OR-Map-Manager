using Dates

"Dictionary mapping custom scalar types to a Julia type"
const SCALAR_TYPES = merge(
    GraphQLClient.GQL_DEFAULT_SCALAR_TO_JULIA_TYPE,
    Dict(
        "Hexadecimal" => String,
        "JSON" => String,
    )
)

##################
# ApplicationData #
##################

"""
    AbstractApplicationData

Supertype for application data object.
"""
abstract type AbstractApplicationData end

mutable struct ApplicationData <: AbstractApplicationData
    name::Union{Nothing, String}
    version::Union{Nothing, String}
    resultIds::Union{Nothing, Vector{String}}
    lastExecuted::Union{Nothing, Int64}
    progressPct::Union{Nothing, Float64}
    executionParameters::Union{Nothing, String}
end
ApplicationData() = ApplicationData((nothing for i in 1:length(fieldnames(ApplicationData)))...)

function Base.display(app_data::AbstractApplicationData)
    display_text = """
    ApplicationData
        App Name: $(app_data.name)"""
    print(display_text)
end

function Base.show(app_data::T) where {T <: AbstractApplicationData}
    nonnull_fields = Symbol[]
    for field in fieldnames(T)
        if !isnothing(getproperty(app_data, field))
            push!(nonnull_fields, field)
        end
    end
    display_text = "ApplicationData"
    if length(nonnull_fields) == 0
        display_text *= "\n  All fields are nothing"
    else
        longest = maximum(length.(string.(nonnull_fields)))
        for field in nonnull_fields
            display_text *= "\n  "
            display_text *= lpad(field, longest)
            display_text *= " : $(getproperty(app_data, field))"
        end
    end
    print(display_text)
end

function Base.isempty(app_data::T) where {T <: AbstractApplicationData}
    for field in fieldnames(T)
        !isnothing(getproperty(app_data, field)) && return false
    end
    return true
end

##################
# ScheduleConfig #
##################

abstract type AbstractScheduleConfig end

"""
    ScheduleConfig

A utility config for the schedule section of an Agent Config.
All fields are nullable (i.e. can be set to `nothing`). Fields
may not be nullable in the configuration itself, but are here
so that the user can choose what fields they want to use.

All non-null fields of a config can be viewed by:

```julia
julia> schedule_config = EMInterface.ScheduleConfig()
julia> schedule_config.scalingFactorOverride = true
julia> show(schedule_config)
Schedule Config
  scalingFactorOverride : true
```
"""
mutable struct ScheduleConfig <: AbstractScheduleConfig
    # Experimental agents
    expTripIds::Union{Nothing, Vector{String}}
    expAgentStartTimes::Union{Nothing, Vector{Float64}}
    expAgentStartPos::Union{Nothing, Vector{Float64}}
    expPoiPositionOverride::Union{Nothing, Vector{Float64}}
    expPoiTypeOverride::Union{Nothing, Vector{String}}
    
    # Environment info
    segmentId::Union{Nothing, String}
    mapName::Union{Nothing, String}
    areaOfInterest::Union{Nothing, String}

    # Linear Programming
    lpPathReuseLimits::Union{Nothing, Int64}
    lpVehicleWeight::Union{Nothing, Float64}

    # General params
    inProgressProportionThreshold::Union{Nothing, Float64}
    scalingFactorOverride::Union{Nothing, Float64}
    optimisationPeriod::Union{Nothing, Float64}
end

function ScheduleConfig()
    n_nullable_fields = length(fieldnames(ScheduleConfig))
    return ScheduleConfig((nothing for i in 1:n_nullable_fields)...)
end

function Base.display(conf::AbstractScheduleConfig)
    display_text = "Schedule Config"
    print(display_text)
end

###############
# AgentConfig #
###############

abstract type AbstractAgentConfig end

"""
    AgentConfig

A utility config for the agent section of the Experiment Config.
All fields are nullable (i.e. can be set to `nothing`). Fields may
not be nullable in the configuration itself, but are here so that
the user can choose what fields they want to use.

Can be constructed with all nullable fields set to `nothing` by:

```julia
julia> EMInterface.AgentConfig()
Agent Config
    🆔 CAR
```

All non-null fields of a config can be viewed by:

```julia
julia> agent_config = EMInterface.AgentConfig()
julia> agent_config.nAgents = 12
julia> show(agent_config)
Agent Config
  nAgents : 12
```
"""
mutable struct AgentConfig <: AbstractAgentConfig
    # note fields that are non-nullable in 
    # the config may be nullable here, as the user may not need to use them)
    experimentAgentConfigurationId::Union{Nothing, String}
    id::Union{Nothing, String}
    agentConfigurationName::Union{Nothing, String}
    agentType::Union{Nothing, String}

    experimentName::Union{Nothing, String}
    envSupport::Union{Nothing, String}

    nAgents::Union{Nothing, Int64}
    agentSubType::Union{Nothing, String}
    agentLength::Union{Nothing, Float64}
    agentSource::Union{Nothing, String}
    arrLocation::Union{Nothing, String}
    depLocation::Union{Nothing, String}
    pathType::Union{Nothing, String}
    pathStrategy::Union{Nothing, String}
    tripStrategy::Union{Nothing, String}

    scheduleGenerationParams::Union{Nothing, ScheduleConfig}

    basedOnDay::Union{Nothing, Int64}
    nAgentsPerId::Union{Nothing, Int64}
    startTime::Union{Nothing, Int64}
    endTime::Union{Nothing, Int64}

    startStrategy::Union{Nothing, String}
    earliestArrTime::Union{Nothing, Int64}
    latestArrTime::Union{Nothing, Int64}

    # Dynamics
    dynFollowingKp::Union{Nothing, Float64}
    dynFollowingKd::Union{Nothing, Float64}
    dynFollowingDistance::Union{Nothing, Float64}
    dynFollowingTime::Union{Nothing, Float64}
    dynFollowingInteractionDistLowThreshold::Union{Nothing, Float64}
    dynFollowingInteractionDistUpperThreshold::Union{Nothing, Float64}
    dynFollowingInteractionDistTime::Union{Nothing, Float64}
    dynIntersectionDistance::Union{Nothing, Float64}
    dynIntersectionKd::Union{Nothing, Float64}
    dynIntersectionKp::Union{Nothing, Float64}
    dynIntersectionInteractionDistLowerThreshold::Union{Nothing, Float64}
    dynIntersectionInteractionDistUpperThreshold::Union{Nothing, Float64}
    dynIntersectionInteractionDistTime::Union{Nothing, Float64}
    dynPoiDistance::Union{Nothing, Float64}
    dynPoiKd::Union{Nothing, Float64}
    dynPoiKp::Union{Nothing, Float64}
    dynPoiInteractionDistLowerThreshold::Union{Nothing, Float64}
    dynPoiInteractionDistUpperThreshold::Union{Nothing, Float64}
    dynPoiInteractionDistTime::Union{Nothing, Float64}
    dynVelKp::Union{Nothing, Float64}
    dynCornerDist_exp::Union{Nothing, Float64}
    dynCornerAngularThreshold::Union{Nothing, Float64}
    dynCornerMinimumVelocityTarget::Union{Nothing, Float64}
    
    useStochasticity::Union{Nothing, Bool}
    upperPathvRandPercent::Union{Nothing, Float64}
    lowerPathvRandPercent::Union{Nothing, Float64}
    loadInitialConditions::Union{Nothing, Bool}
end

function AgentConfig()
    n_nullable_fields = length(fieldnames(AgentConfig))
    return AgentConfig((nothing for i in 1:n_nullable_fields)...)
end

function Base.display(conf::AbstractAgentConfig)
    display_text = """
    Agent Config
        🆔 $(conf.agentType)"""
    print(display_text)
end

function Base.show(conf::T) where {T <: AbstractAgentConfig}
    nonnull_fields = Symbol[]
    for field in fieldnames(T)
        if !isnothing(getproperty(conf, field))
            push!(nonnull_fields, field)
        end
    end
    display_text = "Agent Config"
    if length(nonnull_fields) == 0
        display_text *= "\n  All fields are nothing"
    else
        longest = maximum(length.(string.(nonnull_fields)))
        for field in nonnull_fields
            display_text *= "\n  "
            display_text *= lpad(field, longest)
            if field in [:schedule_generation_params]
                display_text *= " : Populated schedule params"
            else
                display_text *= " : $(getproperty(conf, field))"
            end
        end
    end
    print(display_text)
end

##############
# TestConfig #
##############

mutable struct TestConfig end

##################
# DecisionConfig #
##################

mutable struct DecisionConfig end

##########
# Config #
##########

abstract type AbstractConfig end

"""
    Config

A utility config for the Experiment Config.

All fields are nullable (i.e. can be set to `nothing`) except for
`experiment_name`. Fields may not be nullable in the configuration itself,
but are here so that the user can choose what fields they want to use.

All non-null fields of a config can be viewed by:

```julia
julia> config = EMInterface.Config("my_test_experiment")
julia> config.simDuration = 200.0
julia> show(config)
Experiment Config
  experimentName : my_test_experiment
     simDuration : 200.0
```

# Examples

The following constructurs can be used to create a `Config`:

```julia
julia> config = Config("my_experiment") # Set every field to nothing except for experiment study_name
Experiment Config
    🆔 my_experiment
```
```julia
julia> experiment_dict = get_configuration("my_experiment"; raw=true)
julia> config = Config(experiment_dict) # Build config struct based on get_configuration query
```

Additionally, more methods become available when you are `using YAML` (this makes use
of Requires.jl):

```julia
julia> using YAML
julia> config = EMInterface.load_config_yaml("example/config.yaml")
Experiment Config
    🆔 ExampleConfig
```
"""
mutable struct Config <: AbstractConfig
    # Non nullable fields in struct (note fields that are non-nullable in 
    # the config may be nullable here, as the user may not need to use them)
    experimentName::Union{Nothing, String}

    id::Union{Nothing, String}
    configParentExperimentName::Union{Nothing, String}

    # Study and experiment metadata
    experimentBase::Union{Nothing, String}
    experimentType::Union{Nothing, String}
    experimentDescription::Union{Nothing, String}
    studyName::Union{Nothing, String}
    studyDescription::Union{Nothing, String}
    version::Union{Nothing, Int64}
    randomSeed::Union{Nothing, Int64}
    comment::Union{Nothing, String}
    experimentScore::Union{Nothing, Int64}
    configParent::Union{Nothing, String}
    sessionName::Union{Nothing, String}
    environmentType::Union{Nothing, Vector{String}}
    environmentFile::Union{Nothing, String}
    createdBy::Union{Nothing, String}
    createdByUsername::Union{Nothing, String}
    createdOn::Union{Nothing, Int64}
    # createdOn::Union{Nothing, DateTime}
    lastExecutedBy::Union{Nothing, String}
    lastExecutedByUsername::Union{Nothing, String}
    lastExecutedOn::Union{Nothing, Int64}

    # simulation settings
    nSimulations::Union{Nothing, Int64}
    simDuration::Union{Nothing, Float64}
    scheduleGenerationPeriod::Union{Nothing, Float64}
    simStartTime::Union{Nothing, Float64}
    solMajorTimestep::Union{Nothing, Float64}

    # solver options
    solDt::Union{Nothing, Float64}
    solType::Union{Nothing, String}
    solDtMax::Union{Nothing, Float64}
    solDtMin::Union{Nothing, Float64}
    solAbsTol::Union{Nothing, Float64}
    solRelTol::Union{Nothing, Float64}
    solVersion::Union{Nothing, String}
    solMaxIters::Union{Nothing, Int64}
    solLogEvents::Union{Nothing, Bool}
    solSeqInterval::Union{Nothing, Float64}
    solSequenceSpacingRatio::Union{Nothing, Float64}
    solLastStepOnly::Union{Nothing, Bool}
    solEnablePerfTest::Union{Nothing, Bool}
    solEnableDenseOutput::Union{Nothing, Bool}
    solOutputResolution::Union{Nothing, Float64}

    # Units
    unitsSolTime::Union{Nothing, String}
    unitsDistance::Union{Nothing, String}
    unitsVelocity::Union{Nothing, String}
    unitsSimDuration::Union{Nothing, String}
    unitsAcceleration::Union{Nothing, String}

    # Results
    applicationData::Union{Nothing, Vector{ApplicationData}}
    decisionIds::Union{Nothing, Vector{String}}

    #
    agentLevelOutput::Union{Nothing, Bool}
    rawOutput::Union{Nothing, Bool}
    positionOutput::Union{Nothing, Bool}

    executionParameters::Union{Nothing, Vector{String}}
    applicationVersions::Union{Nothing, Vector{String}}

    # Segmenter
    segAgentMin::Union{Nothing, Int64}
    segMaxNumber::Union{Nothing, Int64}

    # Modifications
    nodeParamMod::Union{Nothing, String}
    edgeParamMod::Union{Nothing, String}
    agentParamMod::Union{Nothing, String}
    eventMod::Union{Nothing, String}

    computeResourceAllocation::Union{Nothing, String}
    executionEnvironment::Union{Nothing, String}

    # Additional Configs
    agentConfigurations::Union{Nothing, Vector{AgentConfig}}
    # test_config::Union{Nothing, Vector{TestConfig}}
    # decision_config::Union{Nothing, Vector{DecisionConfig}}
end

Config() = Config((nothing for i in 1:length(fieldnames(Config)))...)
function Config(experiment_name::AbstractString)
    n_fields_to_null = length(fieldnames(Config)) - 1
    return Config(experiment_name, (nothing for i in 1:n_fields_to_null)...)
end

function Base.display(conf::AbstractConfig)
    display_text = """
    Experiment Config
        🆔 $(conf.experimentName)"""
    print(display_text)
end

function Base.show(conf::T) where T <: AbstractConfig
    nonnull_fields = Symbol[]
    for field in fieldnames(T)
        if !isnothing(getproperty(conf, field))
            push!(nonnull_fields, field)
        end
    end
    display_text = "Experiment Config"
    if length(nonnull_fields) == 0
        display_text *= "\n  All fields are nothing"
    else
        longest = maximum(length.(string.(nonnull_fields)))
        for field in nonnull_fields
            display_text *= "\n  "
            display_text *= lpad(field, longest)
            if field in [:agent_configurations]
                display_text *= " : $(length(getproperty(conf, field))) configs"
            else
                display_text *= " : $(getproperty(conf, field))"
            end
        end
    end
    print(display_text)
end

########################
# Config Introspection #
########################

"""
    introspect_config_struct()

Introspect a config struct. Currently this creates a new struct for both the Config
and any fields that are GraphQL objects or arrays of GraphQL objects.

Structs are stored in the client object can can be accessed with `get_introspected_types()`.
"""
function introspect_config_struct(;force=false,
                                  parent_type=AbstractConfig,
                                  mutable=true)
    parent_map = Dict(
        "ExperimentConfigurationObject" => parent_type,
        "ExperimentAgentConfigurationObject" => AbstractAgentConfig,
        "ApplicationDataObject" => AbstractApplicationData,
        "ScheduleGenerationParamsObject" => AbstractScheduleConfig,
    )
    return GraphQLClient.introspect_object("ExperimentConfigurationObject"; force, parent_map, mutable, allowed_level=3, custom_scalar_types=SCALAR_TYPES)
end

"""
    initialise_config(experiment_name::String)

Initialise a config struct with `exeperimentName` set.
"""
function initialise_config(experiment_name::String)
    config = initialise_introspected_struct("ExperimentConfigurationObject")
    config.experimentName = experiment_name
    return config
end

############################
# Full Config Constructors #
############################

"""
    build_schedule_config_struct(str::Nothing)
    build_schedule_config_struct(str::String)
    build_schedule_config_struct(raw_config::Dict)

Load contents of `scheduleConfigParams` (from an `agentConfiguration`)
into a new `ScheduleConfig` object.

If input is a `String`, it is first converted into a `Dict` using JSON3. If
input is `nothing`, an empty `ScheduleConfig` is returned.
"""
build_schedule_config_struct(str::Nothing) = initialise_introspected_struct("ScheduleGenerationParamsObject")
build_schedule_config_struct(str::String) = build_schedule_config_struct(JSON3.read(str, Dict))
function build_schedule_config_struct(raw_config::Dict)
    schedule_config = initialise_introspected_struct("ScheduleGenerationParamsObject")
    for (key, val) in raw_config
        setproperty!(schedule_config, Symbol(key), val)
    end
    return schedule_config
end

"""
    build_agent_config_struct(agent_config_dict::Dict)

Load contents of `agent_config_dict` (element of `config.agentConfigurations`)
into a new `AgentConfig` object.
"""
function build_agent_config_struct(agent_config_dict::Dict)
    agent_config = initialise_introspected_struct("ExperimentAgentConfigurationObject")
    for (key, val) in agent_config_dict
        if key == "scheduleGenerationParams"
            setproperty!(agent_config, :scheduleGenerationParams, build_schedule_config_struct(val))
            continue
        end
        setproperty!(agent_config, Symbol(key), val)
    end
    return agent_config
end

"""
    build_config_struct(config_dict::Dict)

Load contents of `config_dict` into a `AbstractConfig` object using
introspected object definitions.
"""
function build_config_struct(config_dict::Dict)
    config = initialise_config(get(config_dict, "experimentName", "UnknownConfig"))
    for (key, val) in config_dict
        key == "experimentName" && continue # Already added on initialise
        object_type = GraphQLClient.getobjtype(get_client().type_to_fields_map["ExperimentConfigurationObject"][key])
        if key == "agentConfigurations"
            config.agentConfigurations = get_introspected_type("ExperimentAgentConfigurationObject")[]
            append!(config.agentConfigurations, build_agent_config_struct.(val))
            continue
        elseif object_type in keys(get_introspected_types())
            if isnothing(val)
                setproperty!(config, Symbol(key), val)
            elseif val isa Vector
                setproperty!(config, Symbol(key), create_introspected_struct.(Ref(object_type), val))
            else
                setproperty!(config, Symbol(key), create_introspected_struct(object_type, val))
            end
        else
            setproperty!(config, Symbol(key), val)
        end
    end
    return config
end

#########################################################
# Constructors when not connected to Experiment Manager #
#########################################################

function populate_struct!(struct_instance, dict)
    for (key, val) in dict
        if key == "scheduleGenerationParams"
            setproperty!(struct_instance, Symbol(key), populate_struct!(ScheduleConfig(), val))
        else
            setproperty!(struct_instance, Symbol(key), val)
        end
    end
    return struct_instance
end

"""
    build_config_struct_offline(config_dict::Dict)

Load contents of `config_dict` into a `Config` object using structs
defined in this file.
"""
function build_config_struct_offline(config_dict::Dict)
    config = Config(get(config_dict, "experimentName", "UnknownConfig"))
    for (key, val) in config_dict
        key == "experimentName" && continue # Already added on initialise
        if key == "agentConfigurations"
            config.agentConfigurations = AgentConfig[]
            for agent_config in val
                push!(config.agentConfigurations, populate_struct!(AgentConfig(), agent_config))
            end
            continue
        elseif key == "applicationData"
            if isnothing(val)
                setproperty!(config, Symbol(key), val)
            else
                config.applicationData = ApplicationData[]
                for app in val
                    push!(config.applicationData, populate_struct!(ApplicationData(), app))
                end
            end
        else
            setproperty!(config, Symbol(key), val)
        end
    end
    return config
end

"""
    DEFAULT_CONFIG_TYPES

Contains the default types used by the experiment configuration.
"""
const DEFAULT_CONFIG_TYPES = Ref{Dict{String, DataType}}(Dict{String, DataType}(
    "ExperimentAgentConfigurationObject" => AgentConfig,
    "ExperimentConfigurationObject" => Config,
    "ScheduleGenerationParamsObject" => ScheduleConfig,
    "ApplicationDataObject" => ApplicationData,
))