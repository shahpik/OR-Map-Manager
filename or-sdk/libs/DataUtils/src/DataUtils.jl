module DataUtils

using Logging
using DataFrames
using Base64, CodecZlib, TranscodingStreams
using Serialization: serialize, deserialize
using DataStructures

# Encoding utilities
export encode, decode, base64_serialize, base64_deserialize, encode_coordinates, decode_coordinates, base64_decompress
# Macros
export retry
# String utilities
export tryparse_string_to_number, camel_to_snake, snake_to_camel
# Dictionary utilities
export delete_keys_not_in_list!, delete_keys!, pop_from_a_to_b!, merge_dicts_on_matching_key
# Array utilities
export map_key_to_item, get_non_unique_values_from_array

# expiring Queue functions, extends DataStructures, needs that package to operate
export TimedVal, TimedNumber, TimedInt, TimedFloat, expiring_avg!, expiring_sum!, expiring_count!, expire_elements_by_ts!, add_now!

include("encoding_utilities.jl")
include("string_utilities.jl")
include("array_utilities.jl")
include("dictionary_utilities.jl")
include("macros.jl")
include("dataframe_utilities.jl")

# datastruct
include("expiring_queues.jl")

end # module
