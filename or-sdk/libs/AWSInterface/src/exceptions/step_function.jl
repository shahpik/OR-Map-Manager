struct StepFunctionError <: Exception
    msg::String
end

Base.showerror(io::IO, ex::StepFunctionError; backtrace=true) = printstyled(io, "StepFunctionError:\n\n" * ex.msg * "\n", color=Base.error_color())
