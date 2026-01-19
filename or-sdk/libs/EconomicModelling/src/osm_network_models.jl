#metafunction, to apply the sum of all congestion cost functions with kwarg input
"""
    _cost_of_congestion(args...; kwargs...)

Attempts to run all supplied functions in `args` with all supplied `kwargs`. Takes the sum of all outputs, with a floor of 0.0
as congestion should never generate profit (-ve cost).
"""
function _cost_of_congestion(args...; kwargs...)
    @debug kwargs
    a = 0.0
    for fn in args
        b = fn(;kwargs...)
        @debug "$fn: $b"
        a += b
    end
    # Cost of congestion cannot be less than $0.00
    a = a < 0 ? 0.0 : a
    return a
end

# Congestion cost in AUD
"""
    calc_f_aud_congestion(v_act, v_nom, total_vehicles, l_link)

Calculates the current cost of congestion on a given link using a delay-proxy from speed difference, and proportional
vehicle density.

# Key Word Arguments
- `v_act::Real` - The current speed of vehicles on a given link
- `v_nom::Real` - The nominal speed reference of vehicles on a given link
- `total_vehicles::Real` - The current count of traffic of vehicles on a given link
- `l_link::Real` - The length of the link in Km

# Returns
- `cost::Real` - Current cost of congestion, in \$AUD, for a given link.

### TODO
- Add social and environmental drivers of cost
"""
function calc_f_aud_congestion(v_act, v_nom, total_vehicles, l_link)
    #TODO: Extend from Bronze to include Gold societal and environmental cost as well
    # If the actual speed is greater than nominal speed then the cost of congestion will be $0.00
    v_act > v_nom && return 0.0

    # Recalcualting the volume count
    total_vehicles = iszero(v_act) ? 0 : (60 * l_link) / v_act * total_vehicles

    final_cost = _cost_of_congestion(delay_cost, voc_cost_estimate; v_act=v_act, v_nom=v_nom, total_vehicles=total_vehicles)
    return round(final_cost, digits=2)
end

"""
    delay_cost(;kwargs...)

Calculates the current cost of vehicle delay on a given link using a delay-proxy from speed difference, and proportional
vehicle density.

# Key Word Arguments
- `v_act::Real` - The current speed of vehicles on a given link
- `v_nom::Real` - The nominal speed reference of vehicles on a given link
- `total_vehicles::Real` - The current count of traffic of vehicles on a given link

# Returns
- `cost::Real` - Current cost of vehicle delays, in \$AUD, for a given link.
"""
function delay_cost(;kwargs...)
    v_act = get(kwargs, :v_act, missing)
    v_nom = get(kwargs, :v_nom, missing)
    total_vehicles = get(kwargs, :total_vehicles, missing)
    delay_prop_vehicles = get(kwargs, :delay_prop_vehicles, missing)

    delay_prop_vehicles = get_veh_proportions(delay_prop_vehicles, :delay)

    if (ismissing(v_act) || ismissing(v_nom) || ismissing(total_vehicles))
        @warn "Delay cost requires v_act, v_nom, total_vehicles in the key word arguments. Assuming cost is zero."
        return 0.0
    end

    # s
    delay_value = _speed_proxy_delay(v_act, v_nom)

    # veh/min
    proportion_of_vehicles = _n_vehicles(total_vehicles, delay_prop_vehicles)

    # veh-s/min
    proportion_delayed = delay_value * proportion_of_vehicles

    # dollar/veh-hr
    occupancy_cost = simple_element_product(TOTAL_VEHICLE_OCCUPANCY, DOLLAR_VEHICLE_OCCUPANCY)

    # dollar/veh-hr
    cost_vector = occupancy_cost + DOLLAR_VEHICLE_TIME

    # scale by inflation between 2013 and 2022 on proportion_delayed - x1.253
    proportion_delayed = DELAY_INFLATION_MULTIPLIER * proportion_delayed

    # dollar-s/min-hr
    delay_cost = simple_dot_product(proportion_delayed, cost_vector)

    # dollar/min
    delay_cost_per_min = delay_cost / 3600.0

    return delay_cost_per_min
end

"""
    voc_cost_estimate(;kwargs...)

Calculates the estimated vehicle operation costs on a given link using a delay-proxy from speed difference, and proportional
vehicle density.

# Key Word Arguments
- `v_act::Real` - The current speed of vehicles on a given link
- `v_nom::Real` - The nominal speed reference of vehicles on a given link
- `total_vehicles::Real` - The current count of traffic of vehicles on a given link

# Returns
- `cost::Real` - Current cost of vehicle delays, in \$AUD, for a given link.
"""
function voc_cost_estimate(;kwargs...)
    v_act = get(kwargs, :v_act, missing)
    v_nom = get(kwargs, :v_nom, missing)
    total_vehicles = get(kwargs, :total_vehicles, missing)
    voc_prop_vehicles = get(kwargs, :voc_prop_vehicles, missing)

    voc_prop_vehicles = get_veh_proportions(voc_prop_vehicles, :voc)

    if (ismissing(v_act)|| ismissing(total_vehicles))  #  || ismissing(v_nom) 
        @warn "Vehicle operation cost requires v_act,total_vehicles in the key word arguments. Assuming cost is zero."
        return 0.0
    end

    # veh/min
    proportion_of_vehicles = _n_vehicles(total_vehicles, voc_prop_vehicles)

    # cents/veh-km
    if v_act < CRITICAL_V_FOR_OPERATION_COST
        v_act_cost = _cost_velocity_vehicle_1(v_act)

    else
        v_act_cost = _cost_velocity_vehicle_2(v_act)

    end

    if v_nom < CRITICAL_V_FOR_OPERATION_COST
        v_nom_cost = _cost_velocity_vehicle_1(v_nom)

    else
        v_nom_cost = _cost_velocity_vehicle_2(v_nom)

    end

    # veh-s/min
    proportion_delayed = proportion_of_vehicles * DELTA_T

    # veh-km-s/min-hr
    v_scaled_delay = v_act * proportion_delayed

    # cents / veh-km
    delta_v_cost = v_act_cost - v_nom_cost

    # scale by inflation between 2013 and 2022 on delta_v_cost - small, medium, large & business x1.242 - commercial x1.176
    delta_v_cost = simple_element_product(VOC_INFLATION_MULTIPLIER, delta_v_cost)

    # cent-s/min-hr
    cost_voc_cents = simple_dot_product(delta_v_cost, v_scaled_delay)

    # dollar-s/min-hr
    cost_voc = cost_voc_cents / 100.0

    #dollars / min
    voc_per_min = cost_voc / 3600.0

    return voc_per_min
end

# Driven by input only
"""
    _speed_proxy_delay(v_act, v_nom)

Speed-proportional delay, for a fixed reference timestep delta `DELTA_T`.
"""
function _speed_proxy_delay(v_act, v_nom)
    v_ratio = v_act / v_nom
    if v_ratio >= 1.0
        return 0.0
    end

    delay_value = (1.0 - v_ratio) * DELTA_T
    return delay_value
end

# Driven by input and constants
"""
    _n_vehicles(total_vehicles, delay_prop_vehicles)

Distributes total vehicles across `prop_vehicles` to vectorise the total across expected
vehicle distribution.
"""
function _n_vehicles(total_vehicles, prop_vehicles)
    total_proportions = total_vehicles * prop_vehicles / sum(prop_vehicles)
    return total_proportions
end

"""
    _cost_velocity_vehicle_1(v)

Velocity cost of vehicle operation with a `1/v` cost driver. Provided from ATAP:
https://www.atap.gov.au/parameter-values/road-transport/5-vehicle-operating-cost-voc-models
"""
function _cost_velocity_vehicle_1(v)
    iszero(v) && return [0.0 for i in 1:length(COST_TO_VEHICLE_A)]
    scaled_b = (1.0 / v) * COST_TO_VEHICLE_B
    cost_velocity = COST_TO_VEHICLE_A + scaled_b
    return cost_velocity
end

"""
    _cost_velocity_vehicle_2(v)

Velocity cost of vehicle operation with a `v*v` cost driver. Provided from ATAP:
https://www.atap.gov.au/parameter-values/road-transport/5-vehicle-operating-cost-voc-models
"""
function _cost_velocity_vehicle_2(v)
    v_squared = v * v

    c1_scaled = COST_TO_VEHICLE_C1 * v
    c2_scaled = COST_TO_VEHICLE_C2 * v_squared

    cost_velocity = COST_TO_VEHICLE_C0 + c1_scaled + c2_scaled
    return cost_velocity
end
