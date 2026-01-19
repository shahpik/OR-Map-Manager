"""
    simple_element_product(a::Vector, b::Vector)

Simple element-by-element vector multiplication that throws errors if vectors of different lengths.
"""
function simple_element_product(a::Vector, b::Vector)
    length(a) != length(b) && throw(ArgumentError("Input lengths are not the same: $(length(a)) : $(length(b))"))

    return [i*j for (i, j) in zip(a,b)]
end

"""
    simple_element_product(a::Vector, b::Vector)

Simple element-by-element vector dot product that throws errors if vectors of different lengths.
"""
function simple_dot_product(a::Vector, b::Vector)
    length(a) != length(b) && throw(ArgumentError("Input lengths are not the same: $(length(a)) : $(length(b))"))

    return sum(simple_element_product(a, b))
end

"""
    get_veh_proportions(veh_proportions::Missing, category::Symbol)

Getting the vehicle proportions, if no vehicle proportions is provided (missing)
then the default vehicle proportions will be used for either `delay` or `voc`.
"""
function get_veh_proportions(veh_proportions::Missing, category::Symbol)
    # Using the default proportions
    veh_proportions = [CC_PROP_VEHICLES_MAPPING[category][name] for name in CC_ORDER_MAPPING[category]]
    return veh_proportions
end

"""
    get_veh_proportions(veh_proportions::Dict, category::Symbol)

Getting the vehicle proportions, if no vehicle proportions is provided (missing)
then the default vehicle proportions will be used for either `delay` or `voc`.
"""
function get_veh_proportions(veh_proportions::Dict, category::Symbol)
    # Using the custom proportions
    veh_proportions = [veh_proportions[name] for name in CC_ORDER_MAPPING[category]]
    return veh_proportions
end