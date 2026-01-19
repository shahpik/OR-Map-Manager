using Pkg
Pkg.activate(@__DIR__)
Pkg.develop(path=dirname(@__DIR__)) # Add Tile38Interface if not already added. This will update Project.toml

using Documenter, DocumenterMarkdown, Tile38Interface

makedocs(sitename="Tile38Interface", format = Markdown())