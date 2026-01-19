"""
    MapEditorException

A custom exception for this application.

This replaces generic use of `error` and should be used with `throw`:

```julia
throw(MapEditorException("Error message"))
```

Note, this should not replace more appropriate exception types such as
`ArgumentError` or `DimensionMismatch`.
"""
struct MapEditorException <: Exception
    msg::String
end

function Base.showerror(io::IO, ex::MapEditorException; backtrace=true)
    printstyled(io, "MapEditorException:\n\n" * ex.msg * "\n", color=Base.error_color())
end