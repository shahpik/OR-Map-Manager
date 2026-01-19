"""
    delete_keys_not_in_list!(dict::AbstractDict, key_list::Vector{<:AbstractString})

Deletes all keys in a dictionary that are not present in a list of keys.

# Source
`DataLoader.src.utilities`
"""
function delete_keys_not_in_list!(dict::AbstractDict, key_list)
    for (k, _) in dict
        if !(k in key_list)
            delete!(dict, k)
        end
    end
end


"""
    pop_from_a_to_b!(a::AbstractDict, b::AbstractDict, key::AbstractString)

Pops key from 'a' and sets it as a new key-value pair in 'b'.

# Source
`DataLoader.src.utilities`
"""
pop_from_a_to_b!(a::AbstractDict, b::AbstractDict, key) = b[key] = pop!(a, key)


"""
    merge_dicts_on_matching_key(dict1::Dict, dict2::Dict, key::AbstractString)

Merges two dictionaries if the key provided is of matching value in both dicts

# Source
`IntersectionEditor.src.utilities`
"""
function merge_dicts_on_matching_key(dict1::AbstractDict, dict2::AbstractDict, key)
    dict1[key] == dict2[key] && return merge(dict1, dict2)
    return
end


"""
    delete_keys!(dict::AbstractDict, key_list)
    
Delete keys from a dictionary from the provided key_list array

# Source
`IntersectionEditor.src.utilities`
"""
delete_keys!(dict::AbstractDict, key_list) = foreach((k) -> delete!(dict, k), key_list)
