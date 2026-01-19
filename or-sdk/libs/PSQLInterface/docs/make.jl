using Pkg
Pkg.activate(@__DIR__)
Pkg.develop(path=dirname(@__DIR__)) # Add PSQLInterface if not already added. This will update Project.toml

using Documenter, DocumenterMarkdown, PSQLInterface

makedocs(sitename="PSQLInterface", format = Markdown())