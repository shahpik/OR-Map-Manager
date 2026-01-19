const AWS_ACCESS_KEY_ID = Ref{String}()
const AWS_SECRET_ACCESS_KEY = Ref{String}()
const AWS_REGION = Ref{String}()
const AWS_S3_BUCKET = Ref{String}()
const AWS_S3_LOCATION = Ref{String}()

function initialise_aws()
    AWS_ACCESS_KEY_ID[] = get(ENV, "AWS_ACCESS_KEY_ID", "")
    AWS_SECRET_ACCESS_KEY[] = get(ENV, "AWS_SECRET_ACCESS_KEY", "")
    AWS_REGION[] = get(ENV, "AWS_REGION", "ap-southeast-2")
    AWS_S3_BUCKET[] = get(ENV, "AWS_S3_BUCKET", "dtp-or-map-manager")
    AWS_S3_LOCATION[] = get(ENV, "AWS_S3_LOCATION", "map_manager/")
    set_global_config(AWS_ACCESS_KEY_ID[], AWS_SECRET_ACCESS_KEY[], AWS_REGION[])
end

function write_to_s3(json_string::IOBuffer, bucket, object_location; tags=Dict(), metadata=Dict())
    S3InterfaceExtended.multipart_upload(
        bucket,
        object_location,
        json_string;
        tags=tags,
        metadata=metadata,
    );
end

function write_osm_export_to_s3(json_string::IOBuffer, file_name::String, metadata::Dict=Dict())
    try
        s3_location = AWS_S3_LOCATION[]
        object_location = joinpath(s3_location, file_name)
        s3_bucket = AWS_S3_BUCKET[]
        write_to_s3(json_string, s3_bucket, object_location; metadata=metadata)
        @info "Wrote OSM export data to S3 bucket: $(s3_bucket) with file path: $(object_location)"
    catch err
        @error "MapExporter - Unable to write data due to" exception=(err, catch_backtrace())
    end
end


function copy_s3_object(to_bucket,to_key, from_bucket, from_key) 
    S3Interface.copy_object(to_bucket,to_key, from_bucket, from_key)
end

function copy_export_file(file_name_from::String)
    try
        file_name_to = "latest/dtp_osm_road_network.json"
        s3_location = AWS_S3_LOCATION[]
        object_location_to = joinpath(s3_location, file_name_to)
        object_location_from = joinpath(s3_location, file_name_from)
        s3_bucket = AWS_S3_BUCKET[]
        copy_s3_object(s3_bucket, object_location_to, s3_bucket, object_location_from)
        @info "Copied OSM export data from $(s3_bucket) with file path: $(object_location_from) to $(s3_bucket) with file path: $(object_location_to)"
    catch err
        @error "MapExporter - Unable to copy data to due to" exception=(err, catch_backtrace())
    end
end
