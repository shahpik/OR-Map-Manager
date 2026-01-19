using Pkg
Pkg.activate(@__DIR__)
Pkg.develop(path=dirname(@__DIR__)) # Add MapOrchestrator if not already added. This will update Project.toml

using Documenter, DocumenterMarkdown, MapOrchestrator

makedocs(sitename="MapOrchestrator", format = Markdown())