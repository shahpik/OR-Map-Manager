module AWSInterface

using AWS

export set_global_config,
       get_global_config,
       S3Interface,
       AthenaInterface,
       GlueInterface,
       StepFunctionInterface,
       S3InterfaceExtended

include("config.jl")

include("services/s3.jl")
using .S3Interface

include("services/s3_extended.jl")
using .S3InterfaceExtended

include("services/athena.jl")
using .AthenaInterface

include("services/glue.jl")
using .GlueInterface

include("services/step_function.jl")
using .StepFunctionInterface

end # module
