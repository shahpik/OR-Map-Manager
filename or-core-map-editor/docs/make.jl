using Pkg
Pkg.activate(@__DIR__)
Pkg.develop(path=dirname(@__DIR__)) # Add MapEditor if not already added. This will update Project.toml

using Documenter, DocumenterMarkdown, MapEditor

makedocs(sitename="MapEditor", format = Markdown())