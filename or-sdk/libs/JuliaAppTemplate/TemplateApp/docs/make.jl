using Pkg
Pkg.activate(@__DIR__)
Pkg.develop(path=dirname(@__DIR__)) # Add JuliaAppTemplate if not already added. This will update Project.toml

using Documenter, DocumenterMarkdown, JuliaAppTemplate

makedocs(sitename="JuliaAppTemplate", format = Markdown())