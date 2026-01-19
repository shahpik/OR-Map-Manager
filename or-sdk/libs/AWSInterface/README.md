# AWSInterface

## Setting up

```
using AWSInterface
# Initialises global credentials on init using environment variables:
# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY
# AWS_DEFAULT_REGION
#
# If these are not present, aws profiles can be used or assumed roles as per AWS authentication chain
#
# Refer to: https://docs.aws.amazon.com/sdk-for-java/v1/developer-guide/credentials.html

# Manually set global credentials to environment variables:
set_global_config()

# Manually set global credentials to custom values:
custom_key_id = "fake"
custom_access_key = "key"
custom_region = "ap-southeast-2"
set_global_config(custom_key_id, custom_access_key, custom_region)
```

## S3 Interface

Checking if an object exists:

```
S3Interface.object_exists("my-bucket", "path/to/file.json")
```

Listing object keys, with a common prefix:

```
S3Interface.list_objects("my-bucket", prefix="common/prefix/")
```

Retrieving an object:

```
# Download in-memory as a string
S3Interface.get_object("my-bucket", "path/to/file.json")

# Download in-memory deserialised as any JSON format
S3Interface.get_object("my-bucket", "path/to/file.json"; return_type=Dict{String,Any})

# Alternatively use these type safe methods
S3Interface.get_object_as_string("my-bucket", "path/to/file.json")
S3Interface.get_object_as_bytes("my-bucket", "path/to/file.json")

# Download and save to disk
S3Interface.get_object("my-bucket", "path/to/file.json"; save_file_location="save/location/file.json")
```

Retrieve information on an object:

```
# Retrieve raw HTTP headers
S3Interface.get_object_headers("my-bucket", "path/to/file.json")

# Retrieve tag set
S3Interface.get_object_tags("my-bucket", "path/to/file.json")

# Retrieve metadata
S3Interface.get_object_metadata("my-bucket", "path/to/file.json")
```

Put an object:

```
data_string_to_put = """{key: value}"""
acl = "public-read"
tags = Dict("example" => "tag")
metadata = Dict("example" => "metadata")

S3Interface.put_object("my-bucket", "path/to/file.json", data_string_to_put, acl=acl, tags=tags, metadata=metadata)

```

Put an image:

```
image_binary = read("path/to/image.png")

S3Interface.put_object("my-bucket", "path/to/image.png", image_binary)
```

Copy an object from one location to another:

```
new_tags = Dict("to" => "replace")
new_metadata = Dict("to" => "replace")

S3Interface.copy_object("to-bucket", "to-key", "from-bucket", "from-key", new_tags=new_tags, new_metadata=new_metadata)
```

Put object information (overwrites if tag/metadata key exists):

```
# acl
new_acl = "private"
S3Interface.put_object_acl("my-bucket", "path/to/file.json", new_acl)

# tags
new_tags = Dict("example" => "overwrite",  "new" => "tag")
S3Interface.put_object_tags("my-bucket", "path/to/file.json", new_tags)

# metadata
new_metadata = Dict("example" => "overwrite",  "new" => "metadata")
S3Interface.put_object_metadata("my-bucket", "path/to/file.json", new_metadata)

```

Delete an object:

```
# Errors if object does not exist
S3Interface.delete_object("my-bucket", "path/to/file.json")
```

Generate a pre-signed URL for accessing an object:

```
S3Interface.generate_presigned_url("my-bucket", "path/to/file.json")
```