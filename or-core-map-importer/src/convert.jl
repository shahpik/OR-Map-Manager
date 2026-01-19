function convert_to_df(file, source_config::SourceConfig)::DataFrame
    if source_config.file_format == :CSV
        @info "Converting CSV input to DataFrame..."
        return convert_csv_to_df(file)
    elseif source_config.file_format == :GEOJSON
        @info "Converting GeoJSON input to DataFrame..."
        return convert_geojson_to_df(file)
    elseif source_config.file_format == :OSM
        @info "Converting OpenStreetMap input to DataFrame..."
        return convert_osm_to_df(file)
    else
        throw(MapImporterException("File format $(source_config.file_format) not defined!"))
    end
end

function convert_csv_to_df(file_string::String)::DataFrame
    parse_csv_result = CSV.File(IOBuffer(file_string), header=true)
    return DataFrame(parse_csv_result)
end

function convert_osm_to_df(file::Dict)::DataFrame
    elements = file["elements"]

    # Define default DataFrame fields
    df = DataFrame(
        geometry=String[],
        tags=String[],
        type=String[],
        id=String[]
    )

    # Fast location lookup dictionary for nodes
    node_positions = Dict{String,Vector{Float64}}()
    for e in elements
        (e["type"] != "node") && continue
        node_positions["OSM&&NODE" * string(e["id"])] = [e["lon"], e["lat"]]
    end

    # Construct output DataFrame
    rows = Dict{String,Any}[]
    @showprogress 0.1 "" for e in elements
        # Only want nodes and ways
        if e["type"] != "node" && e["type"] != "way"
            continue
        end

        # Init new row
        tags = haskey(e, "tags") ? e["tags"] : missing

        if !ismissing(tags)
            if e["type"] == "way"
                nodes = e["nodes"]
                for i in 1:length(nodes)
                    nodes[i] = "OSM&&NODE" * string(nodes[i])
                end
                tags["nodes"] = nodes
            end
            tags = JSON3.write(tags)
        end

        row = Dict{String,Any}(
            "type" => e["type"],
            "id" => e["id"],
            "tags" => tags,
            "geometry" => ""    # Pre-allocate this memory
        )
        # Node-specific logic
        if e["type"] == "node"
            coordinates = JSON3.write([e["lon"], e["lat"]])
            # Hard-code string for efficiency
            row["geometry"] = "{\"type\":\"Point\",\"coordinates\":$coordinates}"

            # Way-specific logic
        elseif e["type"] == "way"
            # Get node positions
            coordinates = JSON3.write(
                [node_positions[node_id] for node_id in e["nodes"]]
            )
            # Hard-code string for efficiency
            row["geometry"] = "{\"type\":\"LineString\",\"coordinates\":$coordinates}"
        end
        # Append to list of rows
        push!(rows, row)
    end

    # Convert rows to DataFrame, faster to create DataFrame all at once instead of appending
    df = DataFrame(rows)

    return df
end

function convert_geojson_to_df(file::Dict)::DataFrame
    #Take in a dict instead of a string
    features = file["features"]
    df = DataFrame(geometry=String[])

    for f in features
        # New row contains all properties
        row = Dict{Any,Any}(f["properties"])

        for (k, v) in row
            if v isa Array
                row[k] = JSON3.write(v)
            end
        end
        # Transform geometry into JSON string
        row["geometry"] = JSON3.write(f["geometry"])

        if haskey(f, "id")
            row["id"] = f["id"]
        end
        # Append to DataFrame
        append!(df, DataFrame(row); cols=:union)
    end

    return df
end

function convert_geojson_to_df(file::String)::DataFrame
    # Accepts a file string instead of Dict
    file_dict = JSON3.read(file, Dict)
    return convert_geojson_to_df(file_dict)
end
