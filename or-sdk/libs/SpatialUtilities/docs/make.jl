using Pkg
Pkg.activate(@__DIR__)
Pkg.develop(path=dirname(@__DIR__)) # Add SpatialUtilities if not already added. This will update Project.toml

using Documenter, DocumenterMarkdown, SpatialUtilities

makedocs(sitename="SpatialUtilities", format = Markdown())