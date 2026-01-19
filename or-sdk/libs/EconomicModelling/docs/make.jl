using Pkg
Pkg.activate(@__DIR__)
Pkg.develop(path=dirname(@__DIR__)) # Add EconomicModelling if not already added. This will update Project.toml

using Documenter, DocumenterMarkdown, EconomicModelling

makedocs(sitename="EconomicModelling", format = Markdown())