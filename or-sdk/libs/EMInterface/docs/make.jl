using Pkg
Pkg.activate(@__DIR__)
Pkg.develop(path=dirname(@__DIR__))  # Add dev version of EMInterface

using Documenter, DocumenterMarkdown, EMInterface

makedocs(
    modules = [EMInterface],
    sitename="EMInterface",
    format = Markdown()
)