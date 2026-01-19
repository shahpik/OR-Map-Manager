module AppTypes

using StructTypes
using ...MapImporter  # for accessing the App module

export RESTConfig, S3Config, PostProcessingFunction, SourceConfig, PostgreSQLConnection, OSMConfig

mutable struct RESTConfig
    url::String
    request_method::String
    headers::Dict{String,String}
    query::Dict{String,String}
end
StructTypes.StructType(::Type{RESTConfig}) = StructTypes.Struct()
StructTypes.defaults(::Type{RESTConfig}) = Dict(
    :headers => Dict{String,String}(),
    :query => Dict{String,String}()
)

mutable struct S3Config
    bucket::String
    location::String
end
StructTypes.StructType(::Type{S3Config}) = StructTypes.Struct()

mutable struct OSMConfig
    place_name::Union{Nothing,String}
    overpass_filters::Union{Nothing,String}
end
StructTypes.StructType(::Type{OSMConfig}) = StructTypes.Struct()

mutable struct H3HexConfig
    bounding_box::Vector{Vector{Float64}}
    resolution::Int
end
StructTypes.StructType(::Type{H3HexConfig}) = StructTypes.Struct()

mutable struct PostProcessingFunction
    fn::Function
    final_only::Bool
end
StructTypes.StructType(::Type{PostProcessingFunction}) = StructTypes.Struct()
StructTypes.defaults(::Type{PostProcessingFunction}) = Dict(
    :final_only => false
)
StructTypes.constructfrom(::Type{Function}, x) = getfield(MapImporter.App, Symbol(x))

mutable struct SourceConfig
    name::Symbol
    download_method::Symbol
    download_rest_config::Union{Nothing,RESTConfig}
    download_osm_config::Union{Nothing,OSMConfig}
    download_s3_config::Union{Nothing,S3Config}
    download_h3_hex_config::Union{Nothing,H3HexConfig}
    file_format::Symbol
    prerequisite_sources::Vector{Symbol}
    archive_s3::Bool
    archive_s3_config::Union{Nothing,S3Config}
    postprocessing::Vector{PostProcessingFunction}
end
StructTypes.StructType(::Type{SourceConfig}) = StructTypes.Struct()
StructTypes.defaults(::Type{SourceConfig}) = Dict(
    :name => Symbol(),
    :prerequisite_sources => Symbol[],
    :archive_s3 => false,
    :postprocessing => PostProcessingFunction[]
)


end # module