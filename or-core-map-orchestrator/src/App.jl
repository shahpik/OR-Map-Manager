"`App` contains all application code."
module App

using EMInterface
using AWSInterface
using AWS

using ..AppTypes
using ..Workers

# All code included in specific files
include("exceptions.jl")
include("execution.jl")
include("aws.jl")

end # module