struct ExperimentManagerException <: Exception
    msg::String
end

function Base.showerror(io::IO, ex::ExperimentManagerException, bt; backtrace=true)
    printstyled(io, "ExperimentManagerException: " * ex.msg, color=Base.error_color())
end
