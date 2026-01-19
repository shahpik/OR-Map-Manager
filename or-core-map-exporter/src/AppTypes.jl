module AppTypes
using StructTypes
using ...MapExporter

export S3Config

mutable struct S3Config
    bucket::String
    location::String
end
StructTypes.StructType(::Type{S3Config}) = StructTypes.Struct()
end # module