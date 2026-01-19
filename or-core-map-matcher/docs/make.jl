using Pkg
Pkg.activate(@__DIR__)
Pkg.develop(path=dirname(@__DIR__)) # Add MapMatcher if not already added. This will update Project.toml

using Documenter, DocumenterMarkdown, MapMatcher

makedocs(sitename="MapMatcher", format = Markdown())