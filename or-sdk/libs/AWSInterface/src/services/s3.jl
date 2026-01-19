module S3Interface

using AWS
@service S3

using EzXML
using XMLDict
using JSON3
using Base64
using Dates: now, format, datetime2unix, UTC
using MbedTLS: digest, MD_SHA256, MD_SHA1
using OrderedCollections: OrderedDict

include("../exceptions/s3.jl")
include("../utilities.jl")

"""
	object_exists(bucket, key; aws_config=global_aws_config())

Returns true if an object exists by fetching its headers, throws an error otherwise.
"""
function object_exists(bucket, key; aws_config=global_aws_config())
	try
		S3.head_object(bucket, key; aws_config=aws_config)
		return true
	catch
		throw(S3ObjectDoesNotExist("S3 Object $bucket/$key does not exist"))
	end
end

"""
	list_objects(bucket; prefix="", delimiter="", max_keys=Inf, continuation_token="", aws_config=global_aws_config())

Lists S3 object keys, set `max_keys < Inf` to specifically limit the number of keys.

WARNING: Every 1000 listed objects count as 1 read request, beware costs of recursive calls.
"""
function list_objects(bucket; prefix="", delimiter="", max_keys=Inf, continuation_token="", aws_config=global_aws_config())
	if max_keys <= 0
		return String[]
	end
	
	headers = Dict{String, Any}("prefix" => prefix, "delimiter" => delimiter)

	if !isempty(continuation_token)
		headers["continuation-token"] = continuation_token
	end

	if max_keys <= 1000
		headers["max-keys"] = max_keys
	else
		headers["max-keys"] = 1000
	end

	max_keys -= 1000
		
	response = Dict(S3.list_objects_v2(bucket, headers, aws_config=aws_config))
	
	if !haskey(response, "Contents")
		# no objects
		return String[]
	end

	objects = response["Contents"]

	if !(objects isa AbstractArray)
		# single object
		result = [objects.vals[1]]
	else
		# multiple object
		result = [k.vals[1] for k in objects]
	end

	if response["IsTruncated"] == "true"
		append!(result, list_objects(bucket; prefix=prefix, delimiter=delimiter, max_keys=max_keys, continuation_token=response["NextContinuationToken"], aws_config=aws_config))
	end

	return result
end

function _handle_get_object_string_or_byte_array(input_object::Union{AbstractString,AbstractByteArray},
	                                             return_type::Type,
							                     save_file_location::Union{String,Nothing}=nothing
							                     )::return_type
	!isnothing(save_file_location) && write(save_file_location, input_object)
	
	if !(input_object isa return_type)
		if return_type <: AbstractString || return_type <: AbstractByteArray
			input_object = return_type(input_object)
		else
			try
				input_object = JSON3.read(input_object, return_type)
			catch
				throw(S3GetObjectTypeError("S3 object of type $(typeof(input_object)) could not be JSON deserialised as type $return_type"))
			end
		end
	end

	return input_object
end


"""
	_handle_get_object_abstract(input_object::Any, return_type::Type, save_file_location::Union{String,Nothing}=nothing)::return_type

Convert S3 object result based on object return type.

WARNING: When calling the multipart_upload() function to upload files to S3, fetching the uploaded object with get_object() will yield a return type of AWS.Response{IOBuffer}. 
To make it suitable for downstream consumers, we transform this data type from AWS.Response{IOBuffer} to a String.
"""
function _handle_get_object_abstract(input_object::Any,
								     return_type::Type,
	                                 save_file_location::Union{String,Nothing}=nothing
								     )::return_type
	if !isnothing(save_file_location)
		write_target = nothing

		if input_object isa AbstractString || input_object isa AbstractByteArray
			write_target = input_object
		else
			try
				write_target = JSON3.write(input_object)
			catch
				throw(S3GetObjectTypeError("Could not write object to disk $save_file_location, S3 object of type $(typeof(input_object)) could not be JSON serialised"))
			end
		end
		
		write(save_file_location, write_target)
	end

	if !(input_object isa return_type)
		# input_object cannot be AbstractString or AbstractByteArray here as they are handled elsewhere
		try
			if return_type <: AbstractString
				input_object = JSON3.write(input_object)
			elseif return_type <: AbstractByteArray
				input_object = Vector{UInt8}(JSON3.write(input_object))
			else
				input_object = convert(return_type, input_object)
			end
		catch
			throw(S3GetObjectTypeError("S3 object of type $(typeof(input_object)) could not be converted to type $return_type"))
		end
	end

	return input_object
end

function _get_object_handler(input_object_type::Type)
	if input_object_type <: AbstractString || input_object_type <: AbstractByteArray
		return _handle_get_object_string_or_byte_array
	else
		return _handle_get_object_abstract
	end
end

"""
	get_object(bucket,
	           key;
	           return_type::Type=String,
	           save_file_location::Union{String,Nothing}=nothing,
	           aws_config=global_aws_config()
	           )::return_type

Downloads an S3 object in-memory, defaults to string response, option to specify return type or save object to disk.
"""
function get_object(bucket,
	                key;
					return_type::Type=String,
					save_file_location::Union{String,Nothing}=nothing,
					aws_config=global_aws_config()
					)::return_type
	obj = S3.get_object(bucket, key, Dict("return_raw"=>true); aws_config=aws_config)
	handler = _get_object_handler(typeof(obj))
	return handler(obj, return_type, save_file_location)
end

"""
	get_object_as_string(bucket, key; save_file_location::Union{String,Nothing}=nothing, aws_config=global_aws_config())

Downloads an S3 object in-memory as a string response, option to save object to disk.
"""
get_object_as_string(bucket, key; save_file_location::Union{String,Nothing}=nothing, aws_config=global_aws_config()) = get_object(bucket, key; return_type=String, save_file_location=save_file_location, aws_config=aws_config)

"""
	get_object_as_bytes(bucket, key; save_file_location::Union{String,Nothing}=nothing, aws_config=global_aws_config())

Downloads an S3 object in-memory as a byte array response, option to save object to disk.
"""
get_object_as_bytes(bucket, key; save_file_location::Union{String,Nothing}=nothing, aws_config=global_aws_config()) = get_object(bucket, key; return_type=AbstractByteArray, save_file_location=save_file_location, aws_config=aws_config)

"""
	get_object_tags(bucket, key; aws_config=global_aws_config())

Retrieves tag set of an S3 object.
"""
function get_object_tags(bucket, key; aws_config=global_aws_config())
	tags = Dict(S3.get_object_tagging(bucket, key; aws_config=aws_config).vals[1])

	# no tags
	isempty(tags) && return tags

	tags = tags["Tag"]

	# single tag
	!(tags isa AbstractArray) && return Dict(tags.vals[1] => tags.vals[2])
	
	# multiple tags
	return Dict(tag.vals[1] => tag.vals[2] for tag in tags)
end

"""
	get_object_headers(bucket, key; aws_config=global_aws_config())

Retrieves headers of an S3 object.
"""
get_object_headers(bucket, key; aws_config=global_aws_config()) = Dict(S3.head_object(bucket, key; aws_config=aws_config))

"""
	get_object_metadata(bucket, key; aws_config=global_aws_config())

Retrieves metadata of an S3 object.
"""
get_object_metadata(bucket, key; aws_config=global_aws_config()) = Dict(replace(string(k), "x-amz-meta-" => "") => v for (k, v) in get_object_headers(bucket, key; aws_config=aws_config) if startswith(k, "x-amz-meta-"))

"""
	put_object(bucket, 
	           key,
	           object;
	           acl::String="private",
	           tags::AbstractDict=Dict(),
	           metadata::AbstractDict=Dict(),
	           content_encoding::String="",
	           content_type::String="",
	           aws_config=global_aws_config())

Uploads an S3 object, ignore the `object` argument to upload a folder, `object` must be binary.
"""
function put_object(bucket, 
					key,
					object;
					acl::String="private",
					tags::AbstractDict=Dict(),
					metadata::AbstractDict=Dict(),
					content_encoding::String="",
					content_type::String="",
					aws_config=global_aws_config())
	meta = Dict("x-amz-meta-$k" => v for (k, v) in metadata)
	head = merge!(
		Dict(
			"x-amz-acl" => acl,
			"x-amz-tagging" => escapeuri(tags),
			"Content-Encoding" => content_encoding,
			"Content-Type" => content_type,
		),
		meta
	)
	S3.put_object(bucket, key, Dict("body" => object, "headers" => head); aws_config=aws_config)
	return
end

"""
	copy_object(to_bucket,
				to_key,
				from_bucket,
				from_key;
				new_tags::AbstractDict=Dict(),
				new_metadata::AbstractDict=Dict(),
				aws_config=global_aws_config())

Copies an S3 object from from location to another, option to replace with new tags or metadata.
"""
function copy_object(to_bucket,
	                 to_key,
					 from_bucket,
					 from_key;
					 new_tags::AbstractDict=Dict(),
					 new_metadata::AbstractDict=Dict(),
					 aws_config=global_aws_config())
	headers = Dict()

	if !isempty(new_tags)
		headers["x-amz-tagging"] = escapeuri(new_tags)
		headers["x-amz-tagging-directive"] = "REPLACE"
	end

	if !isempty(new_metadata)
		merge!(headers, Dict("x-amz-meta-$k" => v for (k, v) in new_metadata))
		headers["x-amz-metadata-directive"] = "REPLACE"
	end

	S3.copy_object(to_bucket, to_key, "$from_bucket/$from_key", Dict("headers" => headers); aws_config=aws_config)
	return
end

"""
	_tagging_payload(tags::AbstractDict)

Forms the PUT XML body for the S3 object tagging API.
"""
function _tagging_payload(tags::AbstractDict)
	payload = ""

	for (k, v) in tags
		payload *= """
		<Tag>
			<Key>$k</Key>
			<Value>$v</Value>
		</Tag>
		"""
	end

	return """
	<Tagging>
		<TagSet>
			$payload
		</TagSet>
	</Tagging>
	"""
end

"""
	put_object_tags(bucket, key, tags::AbstractDict; aws_config=global_aws_config())

Add or overwrites existing S3 object's tags.
"""
function put_object_tags(bucket, key, tags::AbstractDict; aws_config=global_aws_config())
	object_exists(bucket, key; aws_config=aws_config)
	tags_to_edit = get_object_tags(bucket, key; aws_config=aws_config)
	merge!(tags_to_edit, tags)
	AWSServices.s3("PUT", "/$(bucket)/$(key)?tagging", Dict("body" => _tagging_payload(tags_to_edit)); aws_config=aws_config)
	return
end

"""
	put_object_acl(bucket, key, acl::String; aws_config=global_aws_config())

Edits an existing S3 object's acl.
"""
function put_object_acl(bucket, key, acl::String; aws_config=global_aws_config())
	object_exists(bucket, key; aws_config=aws_config)
	headers = Dict("headers" => Dict("x-amz-acl" => acl))
	S3.put_object_acl(bucket, key, headers, aws_config=aws_config)
	return
end

"""
	put_object_metadata(bucket, key, metadata::AbstractDict; aws_config=global_aws_config())

Add or overwrites existing S3 object's metadata.
"""
function put_object_metadata(bucket, key, metadata::AbstractDict; aws_config=global_aws_config())
	meta_to_edit = get_object_metadata(bucket, key)
	merge!(meta_to_edit, metadata)
	copy_object(bucket, key, bucket, key; new_metadata=meta_to_edit, aws_config=aws_config)
	return
end

"""
	delete_object(bucket, key; aws_config=global_aws_config())

Deletes an S3 object if it exists, throws an error otherwise.
"""
delete_object(bucket, key; aws_config=global_aws_config()) = (object_exists(bucket, key; aws_config=aws_config) && S3.delete_object(bucket, key; aws_config=aws_config); return)

"""
	generate_presigned_url(bucket, path; url="", expires_in=86400, http_method="GET", aws_config=global_aws_config())

Generate a presigned url for accessing an S3 object, `expires_in` uses seconds and maximum 7 days.
Compatible with PrivateLink pass through using the `url` kwarg.
"""
function generate_presigned_url(bucket, path; url="", expires_in=86400, http_method="GET", aws_config=global_aws_config())
    path = escapepath(path)

    expires = round(Int, datetime2unix(now(UTC)) + expires_in)

    query = Dict{String, String}(
        "AWSAccessKeyId" => aws_config.credentials.access_key_id,
        "x-amz-security-token" => aws_config.credentials.token,
        "Expires" => string(expires),
        "response-content-disposition" => "attachment",
    )

    if http_method != "PUT"
        content_type = ""
    end

    to_sign =
        "$http_method\n\n$content_type\n$(query["Expires"])\n" *
        "x-amz-security-token:$(query["x-amz-security-token"])\n" *
        "/$bucket/$path?" *
        "response-content-disposition=attachment"

    key = aws_config.credentials.secret_key
    query["Signature"] = strip(base64encode(digest(MD_SHA1, to_sign, key)))

    endpoint = string("https", "://", bucket, ".s3.", aws_config.region, ".amazonaws.com")
    if !isempty(url)
        endpoint = "$url/$bucket"
    end
    return "$endpoint/$path?$(escapeuri(query))"
end

end # module
