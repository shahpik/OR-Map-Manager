using Pkg
Pkg.activate(@__DIR__)
Pkg.develop(path=dirname(@__DIR__)) # Add PrometheusClient if not already added. This will update Project.toml

using Documenter, DocumenterMarkdown, PrometheusClient

makedocs(sitename="PrometheusClient", format = Markdown())