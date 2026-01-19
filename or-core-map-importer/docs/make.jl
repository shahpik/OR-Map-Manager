using Pkg
Pkg.activate(@__DIR__)
Pkg.develop(path=dirname(@__DIR__)) # Add MapImporter if not already added. This will update Project.toml

using Documenter, DocumenterMarkdown, MapImporter

makedocs(sitename="MapImporter", format = Markdown())