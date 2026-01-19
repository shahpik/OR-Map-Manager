"""
    PSQLInterfaceException

A custom exception for this application.

This replaces generic use of `error` and should be used with `throw`:

```julia
throw(PSQLInterfaceException("Error message"))
```

Note, this should not replace more appropriate exception types such as
`ArgumentError` or `DimensionMismatch`.
"""
struct PSQLInterfaceException <: Exception
    msg::String
end

function Base.showerror(io::IO, ex::PSQLInterfaceException; backtrace=true)
    printstyled(io, "PSQLInterfaceException:\n\n" * ex.msg * "\n", color=Base.error_color())
end