"""
	get_value(mat::AbstractMatrix, i, j)
	get_value(nested_vec::AbstractVector{<:AbstractVector}, i, j)

Utility to have a common interface for accessing a value from a matrix or a
vector of vectors.
"""
Base.@propagate_inbounds get_value(mat::AbstractMatrix, i, j) = mat[i, j]
Base.@propagate_inbounds get_value(nested_vec::AbstractVector{<:AbstractVector}, i, j) = nested_vec[i][j]

"""
    set_value(mat::AbstractMatrix, i, j, val)
    set_value(nested_vec::AbstractVector{<:AbstractVector}, i, j, val)

Utility to have a common interface for setting a value from a matrix or a
vector of vectors.
"""
Base.@propagate_inbounds set_value(mat::AbstractMatrix,i, j, val) = mat[i, j] = val
Base.@propagate_inbounds set_value(nested_vec::AbstractVector{<:AbstractVector},i, j, val) = nested_vec[i][j] = val


function flatten(array::AbstractArray)
    flattened = collect(Iterators.flatten(array))
    if any(x -> typeof(x) <: AbstractArray, flattened)
        return flatten(flattened)
    end
    return flattened
end

""" Intersection generation utility, to move to dedicated library """
function join_arrays_on_common_trailing_elements(arrays::AbstractArray{T}...)::AbstractArray{T} where T <: Any
    current = arrays[1]
    others = setdiff(arrays, [current])

    if !isempty(others)
        for (i, other) in enumerate(others)
            try
                current = join_two_arrays_on_common_trailing_elements(current, other)
                deleteat!(others, i)
                return join_arrays_on_common_trailing_elements(current, others...)
            catch
                continue
            end
        end
        throw(ErrorException("Could not join $current on $others"))
    else
        return current
    end
end

""" Intersection generation utility, to move to dedicated library """
function first_common_trailing_element(a1::AbstractArray{T}, a2::AbstractArray{T})::T where T <: Any
    intersection = intersect(trailing_elements(a1), trailing_elements(a2))
    return length(intersection) >= 1 ? intersection[1] :  throw(ErrorException("No common trailinging elements between $a1 and $a2"))
end

""" Intersection generation utility, to move to dedicated library """
function join_two_arrays_on_common_trailing_elements(a1::AbstractArray{T}, a2::AbstractArray{T})::AbstractArray{T} where T <: Any
    el = first_common_trailing_element(a1, a2)

    if el == a1[1] == a2[1]
        return [reverse(a1)..., a2[2:end]...]
    elseif el == a1[1] == a2[end]
        return [reverse(a1)..., reverse(a2)[2:end]...]
    elseif el == a1[end] == a2[1]
        return [a1..., a2[2:end]...]
    elseif el == a1[end] == a2[end]
        return [a1..., reverse(a2)[2:end]...]
    end 
end

"""
    get_relative_dir(ref_dir::Number, target_dir::Number)

Gets relative angle compared to a reference angle, returns result in the range +/- 180
Intersection generation utility, to move to dedicated library

# Examples
julia> get_relative_dir(100,-30)
-130

julia> get_relative_dir(-10,-30)
-20

julia> get_relative_dir(-190,-30)
160

julia> get_relative_dir(180,-190)
-10

"""
function get_relative_dir(ref_dir::Number, target_dir::Number)
    rel_dir = target_dir - ref_dir
    if (abs(rel_dir) >= 180) 
        rel_dir += (sign(rel_dir) * -360)
    end
    return rel_dir
end
