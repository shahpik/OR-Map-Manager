"""
    SpatialUtilitiesException

A custom exception for this application.

This replaces generic use of `error` and should be used with `throw`:

```julia
throw(SpatialUtilitiesException("Error message"))
```

Note, this should not replace more appropriate exception types such as
`ArgumentError` or `DimensionMismatch`.
"""
struct SpatialUtilitiesException <: Exception
    msg::String
end

function Base.showerror(io::IO, ex::SpatialUtilitiesException; backtrace=true)
    printstyled(io, "SpatialUtilitiesException:\n\n" * ex.msg * "\n", color=Base.error_color())
end