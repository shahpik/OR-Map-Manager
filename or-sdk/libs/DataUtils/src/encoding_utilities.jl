const INFO_LOGGER = Logging.ConsoleLogger(stderr, Logging.Info)
const Codec = TranscodingStreams.Codec

"""
    encode(array::AbstractVector{<:Number}, compress::Bool=false; codec::Union{Codec, Type{Codec}}=GzipCompressor)::String
    encode(array::AbstractVector{<:Number}, codec::Union{<:Codec, Type{<:Codec}})::String

Encodes an array of numbers to Base64 string.

Optionally compress the data first using a compression codec. Default codec is
gzip but this can be modified using the `codec` argument.

# Arguments
- `array::AbstractVector{<:Number}`: Vector of numbers to encode.
- `compress::Bool`: Set `true` to compress using a compression algorithm.
- `codec::Union{Codec, Type{Codec}}`: Codec to use. Either give the codec type
  or a pre-initialised codec object from `initialise_encoding_codec`.

# Return
- `::AbstractString`: Base64 encoded string.

See also: [initialise_encoding_codec](@ref)
"""
function encode(array::AbstractVector{<:Number}, 
                compress::Bool=false;
                codec::Union{<:Codec, Type{<:Codec}}=GzipCompressor
                )::String
    bytearray = reinterpret(UInt8, array)

    if compress
        # Use INFO_LOGGER to stop debug logs in transcode
        transcoded_bytearray = with_logger(INFO_LOGGER) do
            transcode(codec, collect(bytearray))
        end
        return base64encode(transcoded_bytearray)
    end

    return base64encode(bytearray)
end
encode(array::AbstractVector{<:Number}, 
       codec::Union{<:Codec, Type{<:Codec}}
       )::String = encode(array, true, codec=codec)

"""
    encode(string::AbstractString, compress::Bool=false; codec::Union{Codec, Type{Codec}}=GzipCompressor)::String
    encode(string::AbstractString, codec::Union{<:Codec, Type{<:Codec}})::String

Encodes a string to Base64 string.

Optionally compress the data first using a compression codec. Default codec is
gzip but this can be modified using the `codec` argument.

# Arguments
- `string::AbstractString`: String to encode.
- `compress::Bool`: Set `true` to compress using a compression algorithm.
- `codec::Union{Codec, Type{Codec}}`: Codec to use. Either give the codec type
  or a pre-initialised codec object from `initialise_encoding_codec`.

# Return
- `::AbstractString`: Base64 encoded string.

See also: [initialise_encoding_codec](@ref)
"""
function encode(string::AbstractString;
                compress::Bool=true,
                codec::Union{<:Codec, Type{<:Codec}}=GzipCompressor
                )::String
    if compress
        # Use INFO_LOGGER to stop debug logs in transcode
        transcoded_string = with_logger(INFO_LOGGER) do
            transcode(codec, string)
        end
        return base64encode(transcoded_string)
    end

    return base64encode(string)
end

"""
    initialise_encoding_codec(fn::Function, Codec=GzipCompressor)

Initialises a compression codec to be used by multiple calls to `encode`.
This is quicker when doing lots of encoding at once.

# Example
```julia
initialise_encoding_codec() do codec
    encode(my_array, codec)
end
```
"""
function initialise_encoding_codec(fn::Function, Codec=GzipCompressor)
    _codec_wrapper(fn, Codec)
end

"""
decode(base64_string::AbstractString, U::Type, decompress::Bool=false; codec::Union{<:Codec, Type{<:Codec}}=GzipDecompressor)::Vector{U}
decode(base64_string::AbstractString, U::Type, codec::Union{<:Codec, Type{<:Codec}})::Vector{U}

Decodes Base64 string to array of numbers. 

Optionally decompress the data first using a decompression codec. Default codec
is gzip but this can be modified using the `codec` argument.

# Arguments
- `base64_string::AbstractString`: String to decode.
- `U::Type`: Return vector data type (`Number` types only).
- `decompress::Bool`: Set true to decompress with codec before reinterpreting.
- `codec::Union{Codec, Type{Codec}}`: Codec to use. Either give the codec type
or a pre-initialised codec object from `initialise_decoding_codec`.

# Return
- `::Vector{U}`: Vector of type `U`.
"""
function decode(base64_string::AbstractString, 
                U::Type, 
                decompress::Bool=false;
                codec::Union{<:Codec, Type{<:Codec}}=GzipDecompressor
                )::Vector{U}
    bytearray = base64decode(base64_string)

    if decompress
        # Use INFO_LOGGER to stop debug logs in transcode
        bytearray_output = with_logger(INFO_LOGGER) do
            transcode(codec, bytearray)
        end
        return reinterpret(U, bytearray_output)
    end

    return reinterpret(U, bytearray)
end
decode(base64_string::AbstractString, 
       U::Type, 
       codec::Union{<:Codec, Type{<:Codec}}
       )::Vector{U} = decode(base64_string, U, true, codec=codec)

"""
decode(base64_string::AbstractString; codec::Union{<:Codec, Type{<:Codec}}=GzipDecompressor)::String

Decodes Base64 string to array of numbers. 

Optionally decompress the data first using a decompression codec. Default codec
is gzip but this can be modified using the `codec` argument.

# Arguments
- `base64_string::AbstractString`: String to decode.
- `codec::Union{Codec, Type{Codec}}`: Codec to use. Either give the codec type
or a pre-initialised codec object from `initialise_decoding_codec`.

# Return
- `::String`.
"""
function decode(base64_string::AbstractString;
                codec::Union{<:Codec, Type{<:Codec}}=GzipDecompressor
                )::String
    bytearray = base64decode(base64_string)
    # Use INFO_LOGGER to stop debug logs in transcode
    bytearray_output = with_logger(INFO_LOGGER) do
        transcode(codec, bytearray)
    end

    return String(bytearray_output)
end

"""
    initialise_decoding_codec(fn::Function, Codec=GzipCompressor)

Initialises a compression codec to be used by multiple calls to `decode`.
This is quicker when doing lots of decoding at once.

# Example
```julia
initialise_decoding_codec() do codec
    decode(my_encoded_Int64_string, Int64, codec)
end
```
"""
function initialise_decoding_codec(fn::Function, Codec=GzipDecompressor)
    _codec_wrapper(fn, Codec)
end

function _codec_wrapper(fn, Codec)
    codec = Codec()
    TranscodingStreams.initialize(codec)
    try
        return fn(codec)
    finally
        TranscodingStreams.finalize(codec)
    end
end


"""
    base64_serialize(x)

Serialize a variable into a base64 encoded string. This is used for passing complex
structures in a string format or storing them for later use.
"""
function base64_serialize(x)
    io = IOBuffer()
    serialize(io, x)
    return base64encode(take!(io))
end


"""
    base64_deserialize(x::String)

Deserialize a base 64 encoded string into a variable. This is used for passing complex
structures in a string format or storing them for later use.
"""
function base64_deserialize(x::String)
    io = IOBuffer()
    write(io, base64decode(x))
    seekstart(io)
    return deserialize(io)
end

"""
    encode_coordinates(coordinates::AbstractVector{<:Any}; compress::Bool=false, codec::Union{<:Codec, Type{<:Codec}}=GzipCompressor, flatten::Bool=true, precision64::Bool=false)::String

Encodes coordinates, first flattens the coordinates to list of floats, converts 
to bytes, optionally compress with codec, then finally outputs base64 string.

This function mirrors the same function in Experiment Manager.

# Arguments
- `coordinates::Vector{<:Any}`: Coordinates to encode. Can be nested arbitrarily
  deep as long as values are convertable to Float32.
- `compress::Bool`: Set `true` to compress data before converting to base64.
- `codec::Union{<:Codec, Type{<:Codec}}`: If compressing, which compression 
  codec to use.
- `flatten::Bool`: Set `true` to flatten the coordinates into a flat list.
- `precision64::Bool`: Set `true` to encode as float64 value, otherwise float32.

# Returns
- `::String`: Base64-encoded string.
"""
function encode_coordinates(coordinates::AbstractVector{<:Any}; 
                            compress::Bool=false,
                            codec::Union{<:Codec, Type{<:Codec}}=GzipCompressor,
                            flatten::Bool=true,
                            precision64::Bool=false
                            )::String
    # Copy so original is not modified
    coords = deepcopy(coordinates)

    if flatten
        coords = collect(Iterators.flatten(coords))
    end

    # Convert to Float32 or Float64 - ExpManager new default is Float64 for better accuracy
    if precision64
        coords = Float64.(coords)
    else
        coords = Float32.(coords)
    end

    return encode(coords, compress, codec=codec)
end

"""
    decode_coordinates(encoded_str::AbstractString; decompress::Bool=false, codec::Union{<:Codec, Type{<:Codec}}=GzipDecompressor, precision64::Bool=false)::Vector{Vector{Union{Float32, Float64}}}

Decodes an encoded base64 string to an array of coordinate pairs.

This function mirrors the same function in Experiment Manager.

# Arguments
- `encoded_str::AbstractString`: Base64-encoded string to decode.
- `decompress::Bool`: Set `true` to decompress using a decompression codec.
- `codec::Union{<:Codec, Type{<:Codec}}`: If decompressing, which decompression 
codec to use.
- `precision64::Bool`: Set `true` to decode as float64 value, otherwise float32.

# Returns
- `::Vector{Vector{Union{Float32, Float64}}}`: Array of coordinate pairs.
"""
function decode_coordinates(encoded_str::AbstractString;
                            decompress::Bool=false,
                            codec::Union{<:Codec, Type{<:Codec}}=GzipDecompressor,
                            precision64::Bool=false,
                            )::Vector{Vector{Union{Float32, Float64}}}
    if precision64
        precision = Float64
    else
        precision = Float32
    end
    coords = decode(encoded_str, precision, decompress, codec=codec)
    return [[coords[i], coords[i+1]] for i in 1:2:length(coords)]
end

"""
    base64_decompress(encoded_str::AbstractString, codec::Union{<:Codec, Type{<:Codec}}=GzipDecompressor)

Decompress a Base64 encoded string into the specified codec, defaults to GZip.
You can JSON3.read(r) or String(r) the binary aray result into your desired format.

# Arguments
- `encoded_str::AbstractString`: Base64-encoded string to decode.
- `codec::Union{<:Codec, Type{<:Codec}}`: If decompressing, which decompression 
codec to use.

# Returns
- `::Vector{UInt8}`: Decompressed result
"""
function base64_decompress(encoded_str::AbstractString,
                           codec::Union{<:Codec, Type{<:Codec}}=GzipDecompressor,
                           )::Vector{UInt8}
    array = base64decode(encoded_str)
    return transcode(codec, array)
end