using Pkg
Pkg.activate(@__DIR__)
Pkg.develop(path=dirname(@__DIR__)) # Add JuliaLibraryTemplate if not already added. This will update Project.toml

using Documenter, DocumenterMarkdown, JuliaLibraryTemplate

makedocs(sitename="JuliaLibraryTemplate", format = Markdown())