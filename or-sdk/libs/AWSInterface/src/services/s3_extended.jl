module S3InterfaceExtended

using AWS
@service S3 use_response_type = true

using EzXML
using XMLDict

include("../exceptions/s3.jl")
include("../utilities.jl")

"""
    s3_get([::AbstractAWSConfig], bucket, path; <keyword arguments>)

Retrieves an object from the `bucket` for a given `path`.

# Optional Arguments
- `version=nothing`: version of object to get.
- `raw=false`:  return response as `Vector{UInt8}`
- `byte_range=nothing`:  given an iterator of `(start_byte, end_byte)` gets only
  the range of bytes of the object from `start_byte` to `end_byte`.  For example,
  `byte_range=1:4` gets bytes 1 to 4 inclusive.  Arguments should use the Julia convention
  of 1-based indexing.
- `header::Dict{String,String}`: pass in an HTTP header to the request.

As an example of how to set custom HTTP headers, the below is equivalent to
`s3_get(bucket, path; byte_range=range)`:

```julia
s3_get(bucket, path; headers=Dict{String,String}("Range" => "bytes=\$(first(range)-1)-\$(last(range)-1)"))
```

# API Calls

- [`GetObject`](https://docs.aws.amazon.com/AmazonS3/latest/API/API_GetObject.html)

# Permissions

- [`s3:GetObject`](https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazons3.html#amazons3-GetObject):
  (conditional): required when `version === nothing`.
- [`s3:GetObjectVersion`](https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazons3.html#amazons3-GetObjectVersion):
  (conditional): required when `version !== nothing`.
- [`s3:ListBucket`](https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazons3.html#amazons3-ListBucket)
  (optional): allows requests to non-existent objects to throw a exception with HTTP status
  code 404 (Not Found) instead of HTTP status code 403 (Access Denied).
"""
function s3_get(
    bucket,
    path;
    aws=global_aws_config(),
    version=nothing,
    raw::Bool=false,
    byte_range=nothing,
    headers=Dict{String,Any}(),
    return_stream::Bool=false,
    kwargs...,
)
    params = Dict{String,Any}()
    return_stream && (params["response_stream"] = Base.BufferStream())
    if version !== nothing
        params["versionId"] = version
    end

    if byte_range !== nothing
        headers = copy(headers)  # make sure we don't mutate existing object
        # we make sure we stick to the Julia convention of 1-based indexing
        a, b = (first(byte_range) - 1), (last(byte_range) - 1)
        headers["Range"] = "bytes=$a-$b"
    end

    if !isempty(headers)
        params["headers"] = headers
    end

    r = S3.get_object(bucket, path, params; aws_config=aws, kwargs...)
    return if return_stream
        close(r.io)
        r.io
    elseif raw
        r.body
    else
        parse(r)
    end
end

s3_get(a...; b...) = s3_get(global_aws_config(), a...; b...)


"""
	complete_multipart_upload(aws,upload,parts::Vector{String},args=Dict{String,Any}();kwargs...)

	Complete the multipart upload activity to S3.

# Optional Arguments
- `kwargs`: additional kwargs passed through into `s3_upload_part` and `s3_complete_multipart_upload`

# API Calls
- [`CompleteMultipartUpload`](https://docs.aws.amazon.com/AmazonS3/latest/API/API_CompleteMultipartUpload.html)
"""
function complete_multipart_upload(
    aws,
    upload,
    parts::Vector{String},
    args=Dict{String,Any}();
    kwargs...,
)
    doc = XMLDocument()
    rootnode = setroot!(doc, ElementNode("CompleteMultipartUpload"))

    for (i, etag) in enumerate(parts)
        part = addelement!(rootnode, "Part")
        addelement!(part, "PartNumber", string(i))
        addelement!(part, "ETag", etag)
    end

    args["body"] = string(doc)

    response = S3.complete_multipart_upload(
        upload["Bucket"],
		upload["Key"],
		upload["UploadId"],
		args;
		aws_config=aws,
		kwargs...,
    )

    return response
end

"""
	upload_part(aws,upload,part_number,part_data;args=Dict{String,Any}(),kwargs...)

	Upload part of the file into S3 bucket

# Optional Arguments
- `kwargs`: additional kwargs passed through into `s3_upload_part` and `s3_complete_multipart_upload`

# API Calls
- [`UploadPart`](https://docs.aws.amazon.com/AmazonS3/latest/API/API_UploadPart.html)
"""
function upload_part(
    aws,
    upload,
    part_number,
    part_data;
    args=Dict{String,Any}(),
    kwargs...,
)
    args["body"] = part_data

    response = S3.upload_part(
        upload["Bucket"],
        upload["Key"],
        part_number,
        upload["UploadId"],
        args;
        aws_config=aws,
        kwargs...,
    )

    return get_robust_case(Dict(response.headers), "ETag")
end

"""
	multipart_upload(bucket,key,data::IO;aws=global_aws_config(),part_size_mb=50,tags::AbstractDict=Dict(),metadata::AbstractDict=Dict(),kwargs...)

	Upload `data` at `path` in `bucket` using a [multipart upload](https://docs.aws.amazon.com/AmazonS3/latest/userguide/mpuoverview.html)

# Optional Arguments
- `part_size_mb`: maximum size per uploaded part, in bytes.
- `kwargs`: additional kwargs passed through into `s3_upload_part` and `s3_complete_multipart_upload`

# API Calls
- [`CreateMultipartUpload`](https://docs.aws.amazon.com/AmazonS3/latest/API/API_CreateMultipartUpload.html)
- [`UploadPart`](https://docs.aws.amazon.com/AmazonS3/latest/API/API_UploadPart.html)
- [`CompleteMultipartUpload`](https://docs.aws.amazon.com/AmazonS3/latest/API/API_CompleteMultipartUpload.html)

# Example
tags = Dict(
	"tag1" => "1.0.0",
	"tag2" => "2.0.0"
)
metadata = Dict(
	"metadata1" => "0.0.0",
	"metadata2" => "user-metadata"
)

open("./data.json", "r") do file_io::IO
	S3Interface.multipart_upload(
		App.AWS_S3_MM_BUCKET[],
		"map_exporter/osm_export/latest/new.json",
		file_io;
		tags=tags,
		metadata=metadata,
	);
end
"""
function multipart_upload(
	bucket,
    key,
    data::IO;
    aws=global_aws_config(),
    part_size_mb=50,
    tags::AbstractDict=Dict(),
    metadata::AbstractDict=Dict(),
    kwargs...,
)
	@info "========== Started S3 Multipart Upload ========== \n"
    part_size = part_size_mb * 1024 * 1024
 
    args = Dict{String,Any}()
 
    if !isempty(tags)
		# This functionality is not supported for directory buckets as of now (04/2024).
		# https://docs.aws.amazon.com/AmazonS3/latest/API/API_CreateMultipartUpload.html
        args["x-amz-tagging"] = escapeuri(tags)
    end
 
    if !isempty(metadata)
        merge!(args, Dict("x-amz-meta-$k" => v for (k, v) in metadata))
    end

	upload = S3.create_multipart_upload(
		bucket,
		key,
		args;
		aws_config=aws,
		kwargs...,
	)

    etags = Vector{String}()
    buf = Vector{UInt8}(undef, part_size)
 
    i = 0
    while (n = readbytes!(data, buf, part_size)) > 0
        if n < part_size
            resize!(buf, n)
        end
		part_id = i += 1
 
		@info "\t Uploading Part $(part_id) Started."
		etag = upload_part(
			aws,
			upload,
			part_id,
			buf;
			kwargs...,
		)
		@info "\t Uploading Part $(part_id) Completed. Etag: $(etag)"
        push!(etags, etag)
    end

	complete_resp = complete_multipart_upload(aws, upload, etags; kwargs...)
	@info "========== Completed S3 Multipart Upload, $(i) Parts Uploaded. =========="
    return complete_resp
end

end # module


