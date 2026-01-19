using Pkg
Pkg.activate(@__DIR__)
Pkg.develop(path=dirname(@__DIR__)) # Add MapExporter if not already added. This will update Project.toml

using Documenter, DocumenterMarkdown, MapExporter

makedocs(sitename="MapExporter", format = Markdown())