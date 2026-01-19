struct GlueJobError <: Exception
    msg::String
end

Base.showerror(io::IO, ex::GlueJobError; backtrace=true) = printstyled(io, "GlueJobError:\n\n" * ex.msg * "\n", color=Base.error_color())
