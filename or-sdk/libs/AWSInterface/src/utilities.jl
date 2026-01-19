AbstractByteArray = AbstractArray{<:UInt8}

"""
    _bytes(s::String)

Taken from HTTP.jl. Get a `Vector{UInt8}`, a vector of bytes of a string.
"""
function _bytes end
_bytes(s::SubArray{UInt8}) = unsafe_wrap(Array, pointer(s), length(s))
_bytes(s::Union{Vector{UInt8}, Base.CodeUnits}) = _bytes(String(s))
_bytes(s::String) = codeunits(s)
_bytes(s::SubString{String}) = codeunits(s)
_bytes(s::Vector{UInt8}) = s

utf8_chars(str::AbstractString) = (Char(c) for c in _bytes(str))

const absent = SubString("absent", 1, 0)

@inline issafe(c::Char) = c == '-' ||
                          c == '.' ||
                          c == '_' ||
                          (isascii(c) && (isletter(c) || isnumeric(c)))

"""
    escapeuri(x)

Taken from HTTP.jl. Apply URI percent-encoding to escape special characters in `x`.
"""
function escapeuri end

escapeuri(c::Char) = string('%', uppercase(string(Int(c), base=16, pad=2)))
escapeuri(str::AbstractString, safe::Function=issafe) = join(safe(c) ? c : escapeuri(c) for c in utf8_chars(str))
escapeuri(bytes::Vector{UInt8}) = bytes
escapeuri(v::Number) = escapeuri(string(v))
escapeuri(v::Symbol) = escapeuri(string(v))

"""
    escapeuri(key, value)
    escapeuri(query_vals)

Taken from HTTP.jl. Percent-encode and concatenate a value pair(s) as they would conventionally be
encoded within the query part of a URI.
"""
escapeuri(key, value) = string(escapeuri(key), "=", escapeuri(value))
escapeuri(key, values::Vector) = escapeuri(key => v for v in values)
escapeuri(query) = isempty(query) ? absent : join((escapeuri(k, v) for (k,v) in query), "&")
escapeuri(nt::NamedTuple) = escapeuri(pairs(nt))

ispathsafe(c::Char) = c == '/' || issafe(c)
"""
    escapepath(path)

Taken from HTTP.jl. Escape the path portion of a URI, given the string `path` containing embedded
`/` characters which separate the path segments.
"""
escapepath(path) = escapeuri(path, ispathsafe)


"""
    is_valid_s3_path(path::String, trailing_slash::Symbol)

Check a pathstring is a valid s3 path syntactically

# Arguments:
- `trailing_slash::Symbol`: does the path need to end with a /, some services require this, others not
    ∈ (:required, :disallowed, :optional)

"""
function is_valid_s3_path(path::String, trailing_slash::Symbol=:optional)

    if trailing_slash == :required
        return !isnothing(findfirst(r"s3:\/\/.*\/$", path))
    elseif trailing_slash == :disallowed
        return !isnothing(findfirst(r"s3:\/\/.*[^\/]$", path))
    elseif trailing_slash != :optional
        throw(ArgumentError("Invalid option for is_valid_s3_path, received :$(trailing_slash), require one of: :required, :disallowed, :optional"))
    end

    # else optional
    return !isnothing(findfirst(r"s3:\/\/.*", path))

end

"""
    get_robust_case(x, key)

    # Utility function to workaround https://github.com/JuliaCloud/AWS.jl/issues/547
"""
function get_robust_case(x, key)
    lkey = lowercase(key)
    haskey(x, lkey) && return x[lkey]
    return x[key]
end

 
"""
	parse(r::AWS.Response, mime::MIME)

Returns parsed data based on the mime type for AWS Response types.

NOTE: Use must have included the AWS.jl library, before using this function.
"""
function parse(r::AWS.Response, mime::MIME)
    # AWS doesn't always return a Content-Type which results the parsing returning bytes
    # instead of a dictionary. To address this we'll allow passing in the MIME type.
    return try
        AWS._rewind(r.io) do io
            AWS._read(io, mime)
        end
    catch e
        @warn "Failed to parse the following content as $mime:\n\"\"\"$(String(r.body))\"\"\""
        rethrow(e)
    end
end
parse(args...; kwargs...) = Base.parse(args...; kwargs...)
