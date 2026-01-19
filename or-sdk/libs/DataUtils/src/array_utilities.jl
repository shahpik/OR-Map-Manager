
"""
    map_key_to_item(items::AbstractArray{<:AbstractDict}, key)

Create a reversed hashmap of the value at each dictionary `key` to the dictionary itself.
This assumes that the value of the provided key is unique across all dictionaries.

# Source
`IntersectionEditor.src.utilities`
"""
map_key_to_item(items::AbstractArray{<:AbstractDict}, key) = Dict(item[key] => item for item in items)


"""
    get_non_unique_values_from_array(array::AbstractArray{U}) where U

Get the non unique values from an array.

# Source
`IntersectionEditor.src.utilities`
"""
function get_non_unique_values_from_array(array::AbstractArray{U}) where U
    non_unique = Vector{U}()
    for value in unique(array)
        count(==(value), array) > 1 && push!(non_unique, value)
    end

    return non_unique
end