using Documenter
using GQLInterface
using StructTypes
using JSON3

DocMeta.setdocmeta!(GQLInterface, :DocTestSetup, :(using GQLInterface); recursive=true)

makedocs(
    modules=[GQLInterface],
    authors="Malcolm Miller",
    sitename="GQLInterface.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://deloittedigitalapac.github.io/GQLInterface.jl/stable",
    ),
    pages=[
        "Home" => "index.md",
        "Manual" => [
            "client.md",
            "operations.md",
            "struct_types_usage.md",
            "type_introspection.md",
            "low_level_execution.md",
            "limitations.md",
        ],
        "Library" => [
            "public.md",
            "private.md",
        ],
        "Contributing" => "contributing.md",
    ],
)

deploydocs(;
    repo="github.com/DeloitteDigitalAPAC/GQLInterface.jl",
    push_preview=true,
)