using Pkg
Pkg.activate(@__DIR__)
Pkg.develop(path=dirname(@__DIR__)) # Add JiraInterface if not already added. This will update Project.toml

using Documenter, DocumenterMarkdown, JiraInterface

makedocs(sitename="JiraInterface", format = Markdown())