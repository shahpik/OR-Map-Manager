struct S3InterfaceException <: Exception
    msg::String
end

Base.showerror(io::IO, ex::S3InterfaceException; backtrace=true) = printstyled(io, "S3InterfaceException:\n\n" * ex.msg * "\n", color=Base.error_color())

struct S3GetObjectTypeError <: Exception
    msg::String
end

Base.showerror(io::IO, ex::S3GetObjectTypeError; backtrace=true) = printstyled(io, "S3GetObjectTypeError:\n\n" * ex.msg * "\n", color=Base.error_color())

struct S3ObjectDoesNotExist <: Exception
    msg::String
end

Base.showerror(io::IO, ex::S3ObjectDoesNotExist; backtrace=true) = printstyled(io, "S3ObjectDoesNotExist:\n\n" * ex.msg * "\n", color=Base.error_color())