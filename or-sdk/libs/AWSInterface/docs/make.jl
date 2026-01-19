using Pkg
Pkg.activate(@__DIR__)
Pkg.develop(path=dirname(@__DIR__)) # Add AWSInterface if not already added. This will update Project.toml

using Documenter, DocumenterMarkdown, AWSInterface

makedocs(sitename="AWSInterface", format = Markdown())