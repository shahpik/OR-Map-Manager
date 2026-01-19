function download_source(source_config::SourceConfig)
    if source_config.download_method == :REST
        @info "Downloading from REST API..."
        return download_source_from_API(source_config)
    elseif source_config.download_method == :ARCGIS_REST
        @info "Downloading from ArcGIS REST API..."
        return download_source_from_arcgis_rest(source_config)
    elseif source_config.download_method == :S3
        @info "Downloading from S3..."
        return download_source_from_s3(source_config)
    elseif source_config.download_method == :OSM
        @info "Downloading from OpenStreetMap..."
        return download_source_from_osm(source_config)
    elseif source_config.download_method == :H3_HEX
        @info "Generating H3 hex data..."
        return download_source_from_h3_hex(source_config)
    else
        throw(MapImporterException("Download method $(source_config.download_method) not defined!"))
    end
end

"""
    download_source_from_osm(source_config::SourceConfig)::Dict{String,Any}

Download OSM data from either a place name or custom filters. Custom filters take precedence
over place name.

# Arguments
- `source_config::SourceConfig`: Source config with download_osm_config defined

# Returns
- `Dict{String,Any}`: Overpass API JSON response
"""
function download_source_from_osm(source_config::SourceConfig)::Dict{String,Any}
    osm_config = source_config.download_osm_config
    if !isnothing(osm_config.overpass_filters)
        return LightOSM.download_osm_network(
            :custom_filters, 
            custom_filters=osm_config.overpass_filters,
            download_format=:json
        )
    elseif !isnothing(osm_config.place_name)
        return LightOSM.download_osm_network(
            :place_name, 
            place_name=source_config.download_osm_config.place_name,
            download_format=:json
        )
    end
    throw(MapImporterException("No OSM ingestion method defined for download_osm_config=$(osm_config)!"))
end

function download_source_from_s3(source_config::SourceConfig)
    source_name = snake_to_camel(source_config.name)
    s3_config = source_config.download_s3_config
    folder_path = s3_config.location
    # s3_bucket = s3_config.bucket
    s3_bucket = AWS_S3_BUCKET[]
    # First get the most up to date file
    recent_file = get_most_recent_s3_file(s3_bucket, folder_path, source_name)
    object_location = joinpath(folder_path, recent_file)
    response_string = S3Interface.get_object_as_string(s3_bucket, object_location)
    @info "Read $(source_name) data from S3 bucket: $(s3_bucket) with file path: $(object_location)"

    return response_string
end

function download_source_from_rest(source_config::SourceConfig)
    # First download data from the API and convert to a DataFrame
    source_name = snake_to_camel(source_config.name)
    # Attempts API request with backoff logic
    api_data = backoff_http_request(source_config.download_rest_config)
    if isnothing(api_data)
        # Code should exit here since there is no data to write
        throw(MapImporterException("$(source_name) API call was blocked"))
    end

    return api_data
end

function download_source_from_arcgis_rest(source_config::SourceConfig) # First download data from the API and convert to a DataFrame
    query_dict = source_config.download_rest_config.query
    query_dict["resultOffset"] = "0"
    batch_size = parse(Int, source_config.download_rest_config.query["resultRecordCount"])
    consol_output = Dict{String,Any}("features"=>Dict{String,Any}[])

    # While loop here allows us to query the API data from datashare in batches (2000 rows)
    while true
        output = backoff_arcgis_request(source_config.download_rest_config, query=query_dict)

        # Append the output features to the consol_output dictionary each loop
        append!(consol_output["features"], output["features"])

        len = length(output["features"])
        resultOffset = parse(Int64, query_dict["resultOffset"])
        @info "Downloaded $(resultOffset + len) features"

        # Test the length - any length of output less than batch_size means the loop should exit because we are at the end of the data
        if len < batch_size
            break 
        end

        # Next offset
        query_dict["resultOffset"] = string(resultOffset + batch_size)
    end

    return consol_output
end

"""
    download_source_from_h3_hex(source_config::SourceConfig)

Generate H3 hex index data according to H3 hex config for a given source.

# Arguments
- `source_config::SourceConfig`: Source config for current source.

# Returns
- `::String`: GeoJSON string of H3 hex indexes for the source.
"""
function download_source_from_h3_hex(source_config::SourceConfig)::Dict
    hex_config = source_config.download_h3_hex_config

    # Construct bounding box polygon
    # Input MUST be [top-left, bottom-right] in [lon,lat] format
    bbox = hex_config.bounding_box
    bbox = [
        bbox[1],                   # top-left
        [bbox[2][1], bbox[1][2]],  # top-right
        bbox[2],                   # bottom-right
        [bbox[1][1], bbox[2][2]],  # bottom-left
        bbox[1]                    # top-left
    ]
    # H3 library acceps lat,lon coordinates so swap the coordinates
    bbox = SpatialUtilities.swapxy(bbox)

    # Get hex indexes from polygon
    hexes = SpatialUtilities.get_hexes_inside_polygon(bbox, hex_config.resolution)

    # Convert to GeoJSON
    geoj_hexes = SpatialUtilities.get_geojson_from_hexs(hexes)

    # Weird issue with JSON3 adding 1 to hex_int. Convert to string to prevent this.
    for f in geoj_hexes["features"]
        f["properties"]["hex_int"] = string(f["properties"]["hex_int"], base=10)
    end

    return geoj_hexes
end

"""
    backoff_http_request([url], api_config; max_retries, sleep_time, multi_call, query)

Attempt a HTTP request according to a config object. Retry multiple times if failed.

# Arguments
- `url::String`: URL to download from.
- `api_config::RESTConfig`: Config object to use.

# Keyword arguments
- `max_retries::Integer=5`: How many times to attempt if failed.
- `sleep_time::Integer=60`: How many seconds to wait between attempts.
- `multi_call::Bool=false`: Reduce console output if this is being called multiple times.
- `query::Dict{String,String}`: HTTP query parameters. Overrides `api_config`.
"""
function backoff_http_request(url::String, 
                              api_config::RESTConfig; 
                              max_retries::Integer=5, 
                              sleep_time::Integer=60, 
                              multi_call::Bool=false, 
                              query::Union{Nothing,Dict{String,String}}=nothing
                              )
    # Override query
    query_dict = isnothing(query) ? query : api_config.query
    retries = 0
    while retries <= max_retries
        try
            response = http_request(url, api_config, query_dict)
            if multi_call
                @debug "Successfully downloaded data from $(url)"
            else
                @info "Successfully downloaded data from $(url)"
            end
            string_response = String(response.body)
            return string_response
        catch err
            @error "$(url) request failed due to $(err) - Retrying in $(sleep_time) seconds"
            retries += 1
            sleep(sleep_time)
        end
    end
    @error "$(url) did not respond with backoff in $(max_retries) attempts"
    return nothing
end
backoff_http_request(api_config::RESTConfig; kwargs...) = backoff_http_request(api_config.url, api_config; kwargs...)

function http_request(url, api_config::RESTConfig, query_dict=nothing)
    return HTTP.request(
        api_config.request_method,
        url,
        api_config.headers;
        sslconfig=MbedTLS.SSLConfig(false),
        query=query_dict
    )
end
http_request(api_config::RESTConfig, query_dict::Dict=nothing) = http_request(api_config.url, api_config, query_dict)

"""
    backoff_arcgis_request(api_config::RESTConfig; 
                           max_retries::Integer=5, 
                           sleep_time::Integer=30
                           )::Dict{String,Any}

Download data from ArcGIS REST API. Retry if there was an error.

# Arguments
- `api_config::RESTConfig`: Config object to use for REST API request.

# Keyword arguments
- `max_retries::Integer=5`: How many times to attempt if failed.
- `sleep_time::Integer=60`: How many seconds to wait between attempts.
- `query::Dict{String,String}`: HTTP query parameters. Overrides `api_config`.

# Returns
- `::Dict{String,Any}`: Parsed JSON response from API.
"""
function backoff_arcgis_request(api_config::RESTConfig; 
                                max_retries::Integer=5, 
                                sleep_time::Integer=30, 
                                query::Union{Nothing,Dict{String,String}}=nothing
                                )::Dict{String,Any}
    for i = 1:max_retries
        # Attempt HTTP request
        api_data = backoff_http_request(api_config, query=query)

        if isnothing(api_data)
            # Code should exit here since there is no data to write
            throw(MapImporterException("Unable to reach server after multiple attempts!"))
        end

        # Parse response
        try
            output = JSON3.read(api_data, Dict{String,Any})
            !haskey(output, "features") && throw(KeyError)    # Invalid GeoJSON
            return output
        catch
            @warn "ArcGIS server returned invalid response, retrying in 30 seconds: $api_data"
        end

        # Max retries reached
        if i >= max_retries
            throw(MapImporterException("ArcGIS REST API returned invalid response after $i attempts!"))
        end

        sleep(sleep_time)
    end
end
