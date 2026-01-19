struct AthenaQueryError <: Exception
    msg::String
end

Base.showerror(io::IO, ex::AthenaQueryError; backtrace=true) = printstyled(io, "AthenaQueryError:\n\n" * ex.msg * "\n", color=Base.error_color())

struct AthenaPathError <: Exception
    msg::String
end

Base.showerror(io::IO, ex::AthenaPathError; backtrace=true) = printstyled(io, "AthenaPathError:\n\n" * ex.msg * "\n", color=Base.error_color())
