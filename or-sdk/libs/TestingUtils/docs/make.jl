using Pkg
Pkg.activate(@__DIR__)
Pkg.develop(path=dirname(@__DIR__)) # Add TestingUtils if not already added. This will update Project.toml

using Documenter, DocumenterMarkdown, TestingUtils

makedocs(sitename="TestingUtils", format = Markdown())