"""
    tryparse_string_to_number(str::AbstractString)::Union{Number, AbstractString}

Attempts to parse a stringified number as an Int64 and then as a Float64.

# Source
`IntersectionEditor.src.utilities`
"""
function tryparse_string_to_number(str::U)::Union{Number, U} where U <: AbstractString
    result = tryparse(Int, str)
    if !(isnothing(result))
        return result
    end
    result2 = tryparse(Float64, str)
    if !(isnothing(result2))
        return result2
    end
    return str
end


"""
Converts camel case to snake case.
"""
camel_to_snake(str::AbstractString) = lowercase(replace(str, r"(?<=[a-z])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])" => "_"))


"""
Converts snake case to camel case.
"""
function snake_to_camel(str::AbstractString)
    camel_str = join(uppercasefirst.(split(str, "_")))
    return lowercase(camel_str[1]) * camel_str[2:end]
end