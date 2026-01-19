"""
    GLOBAL_AWS_CONFIG[]

Reference to the global AWS.AWSConfig object, this is used to authenticate across all services.
"""
const GLOBAL_AWS_CONFIG = Ref{AWS.AWSConfig}()

"""
    set_global_config(aws_secret_key_id::String, aws_secret_access_key::String, aws_region::String, aws_profile::String)

Sets the `GLOBAL_AWS_CONFIG[]` reference object with the credentials provided.

This extends the AWS Credential chain sequencing. Order of auth options:

1. Use the profile name if provided 
2. Usage of the access and secret keys
2a. If credentials are not provided explicitly, `GLOBAL_AWS_CONFIG[]` is set with the environment variables:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_DEFAULT_REGION`
3. empty inputs resolve to the AWS credential chain, including machine roles

"""
function set_global_config(aws_secret_key_id::String=get(ENV, "AWS_ACCESS_KEY_ID", ""),
                           aws_secret_access_key::String=get(ENV, "AWS_SECRET_ACCESS_KEY", ""),
                           aws_region::String=get(ENV, "AWS_DEFAULT_REGION", "ap-southeast-2"),
                           aws_profile::String="")
    if !isempty(aws_profile)
        GLOBAL_AWS_CONFIG[] = global_aws_config(profile = aws_profile)
    elseif !isempty(aws_secret_access_key)
        creds = AWSCredentials(aws_secret_key_id, aws_secret_access_key)
        GLOBAL_AWS_CONFIG[] = global_aws_config(region=aws_region, creds=creds)
    else
        GLOBAL_AWS_CONFIG[] = global_aws_config(region=aws_region)
    end
end
set_global_config(aws_credentials::AWSCredentials, aws_region::String=get(ENV, "AWS_DEFAULT_REGION", "ap-southeast-2")) = set_global_config(aws_credentials.access_key_id, aws_credentials.secret_key, aws_region)

"""
    get_global_config()

Returns the `GLOBAL_AWS_CONFIG[]` reference object.
"""
get_global_config() = isassigned(GLOBAL_AWS_CONFIG) ? GLOBAL_AWS_CONFIG[] : set_global_config()
