const AWS_ACCESS_KEY_ID = Ref{String}()
const AWS_SECRET_ACCESS_KEY = Ref{String}()
const AWS_REGION = Ref{String}()
const AWS_S3_BUCKET = Ref{String}()

function initialise_aws()
    AWS_ACCESS_KEY_ID[] = get(ENV, "AWS_ACCESS_KEY_ID", "")
    AWS_SECRET_ACCESS_KEY[] = get(ENV, "AWS_SECRET_ACCESS_KEY", "")
    AWS_REGION[] = get(ENV, "AWS_REGION", "ap-southeast-2")
    AWS_S3_BUCKET[] = get(ENV, "AWS_S3_BUCKET", "dtp-or-map-manager")
    set_global_config(AWS_ACCESS_KEY_ID[], AWS_SECRET_ACCESS_KEY[], AWS_REGION[])
end

function get_most_recent_s3_file(bucket, file_path, file_name)
    # List all object
    absolute_file_paths = S3Interface.list_objects(bucket; prefix=file_path)
    if isempty(absolute_file_paths)
        throw("No files exists in s3 bucket $(bucket) with path: $(file_path)")
    end
    
    # Find the object paths that contain the file name
    matched_paths = [name for name in absolute_file_paths if occursin(file_name, name)]
    if isempty(matched_paths)
        throw(MapImporterException("No files exists in s3 bucket $(bucket) for $(file_name)"))
    end

    # Remove the file path
    file_names = replace.(matched_paths, file_path * "/" => "")

    # Finds the most recent file
    return maximum(file_names)
end

function write_df_to_s3(df::DataFrame, bucket, object_location)
    iter = CSV.RowWriter(df)
    csv_string = join(collect(iter));
    S3Interface.put_object(bucket, object_location, csv_string; content_type="text/csv")
end

function write_source_to_s3(df::DataFrame, source_name, s3_config::S3Config)
    try
        file_name = todays_date() * "_" * snake_to_camel(source_name) * ".csv"
        object_location = joinpath(s3_config.location, file_name)
        s3_bucket = s3_config.bucket

        write_df_to_s3(df, s3_bucket, object_location)
        @info "Wrote $(source_name) data to S3 bucket: $(s3_bucket) with file path: $(object_location)"
    catch err
        @error "MapImporter - Unable to write data to due to" exception=(err, catch_backtrace())
    end
end

function read_df_from_s3(s3_bucket, object_location)
    
    return CSV.read(IOBuffer(df_string), DataFrame; types=String)
end



